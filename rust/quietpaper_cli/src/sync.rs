use crate::{attachments, credentials::Credentials, crypto, database::Database, editor, writes};
use anyhow::{bail, Context, Result};
use rusqlite::{params, OptionalExtension};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{env, io::Read, path::Path, time::Duration};
use uuid::Uuid;
use zeroize::Zeroizing;

pub enum Body {
    Json(Value),
    Form(Vec<(String, String)>),
    Multipart {
        fields: Vec<(String, String)>,
        filename: String,
        bytes: Vec<u8>,
    },
}
pub struct Response {
    pub status: u16,
    pub value: Value,
}
pub trait Transport {
    fn send(&self, url: &str, headers: &[(String, String)], body: Option<Body>)
        -> Result<Response>;
}
pub struct Http(reqwest::blocking::Client);
impl Http {
    pub fn new() -> Result<Self> {
        Ok(Self(
            reqwest::blocking::Client::builder()
                .timeout(Duration::from_secs(30))
                .connect_timeout(Duration::from_secs(10))
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .context("Could not initialize HTTPS client")?,
        ))
    }
}
impl Transport for Http {
    fn send(
        &self,
        url: &str,
        headers: &[(String, String)],
        body: Option<Body>,
    ) -> Result<Response> {
        let mut request = if body.is_some() {
            self.0.post(url)
        } else {
            self.0.get(url)
        };
        for (key, value) in headers {
            request = request.header(key, value);
        }
        request = match body {
            Some(Body::Json(value)) => request.json(&value),
            Some(Body::Form(value)) => request.form(&value),
            Some(Body::Multipart {
                fields,
                filename,
                bytes,
            }) => {
                let mut form = reqwest::blocking::multipart::Form::new().part(
                    "file",
                    reqwest::blocking::multipart::Part::bytes(bytes).file_name(filename),
                );
                for (key, value) in fields {
                    form = form.text(key, value);
                }
                request.multipart(form)
            }
            None => request,
        };
        // Do not propagate reqwest errors containing URLs, API keys, credentials
        // or private server bodies to terminal diagnostics.
        let response = request.send().map_err(|error| {
            anyhow::anyhow!(if error.is_timeout() {
                "Request timed out; changes remain pending"
            } else {
                "Network request failed; changes remain pending"
            })
        })?;
        let status = response.status().as_u16();
        if !(200..300).contains(&status) {
            return Ok(Response {
                status,
                value: Value::Null,
            });
        }
        let mut bytes = Vec::new();
        response
            .take(16 * 1024 * 1024 + 1)
            .read_to_end(&mut bytes)
            .map_err(|_| anyhow::anyhow!("Could not read server response"))?;
        if bytes.len() > 16 * 1024 * 1024 {
            bail!("Server response exceeds size limit");
        }
        let value = serde_json::from_slice(&bytes).context("Invalid server JSON response")?;
        Ok(Response { status, value })
    }
}
fn accepted(response: Response) -> Result<Value> {
    if !(200..300).contains(&response.status) {
        bail!("Request failed (HTTP {})", response.status);
    }
    Ok(response.value)
}
fn string<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value[key]
        .as_str()
        .with_context(|| format!("Missing server field: {key}"))
}
fn iso(seconds: i64) -> Result<String> {
    Ok(jiff::Timestamp::from_second(seconds)?
        .strftime("%Y-%m-%dT%H:%M:%S.000Z")
        .to_string())
}
fn check_url(value: &str, allow_local: bool) -> Result<url::Url> {
    let url = url::Url::parse(value).context("Invalid API URL")?;
    let local = url.host_str().is_some_and(|h| {
        h == "localhost"
            || h.parse::<std::net::IpAddr>()
                .is_ok_and(|ip| ip.is_loopback())
    });
    if url.scheme() != "https" && !(allow_local && local && url.scheme() == "http") {
        bail!("Network endpoint requires HTTPS (loopback HTTP is supported for development)");
    }
    if !url.username().is_empty() || url.password().is_some() {
        bail!("Endpoint URLs cannot contain credentials");
    }
    Ok(url)
}

pub struct Sync<'a, T: Transport> {
    db: &'a Database,
    credentials: &'a mut Credentials,
    transport: T,
    base: String,
    token: Option<Zeroizing<String>>,
    session: Option<Value>,
    device: Option<String>,
}
impl<'a, T: Transport> Sync<'a, T> {
    pub fn new(
        db: &'a Database,
        credentials: &'a mut Credentials,
        transport: T,
        base: String,
    ) -> Result<Self> {
        check_url(&base, true)?;
        let device =
            db.0.query_row(
                "SELECT value FROM sync_metadata WHERE key='device_id'",
                [],
                |r| r.get(0),
            )
            .optional()?;
        Ok(Self {
            db,
            credentials,
            transport,
            base: base.trim_end_matches('/').to_owned(),
            token: None,
            session: None,
            device,
        })
    }
    fn authenticate(&mut self, refresh: bool) -> Result<()> {
        if self.session.is_none() {
            self.session = Some(serde_json::from_str(
                self.credentials
                    .entries
                    .get("quietpaper_auth_session_v1")
                    .context(
                        "No account session. Sign in to Quiet Paper on this Linux account first.",
                    )?,
            )?);
        }
        let session = self.session.as_ref().unwrap();
        let valid = session["tokenExpiresAt"]
            .as_str()
            .and_then(|s| s.parse::<jiff::Timestamp>().ok())
            .is_some_and(|v| v.as_second() > writes::now() + 300);
        if !refresh && valid {
            self.token = Some(Zeroizing::new(string(session, "idToken")?.to_owned()));
            return Ok(());
        }
        let refresh = Zeroizing::new(
            string(session, "refreshToken")
                .context("Session expired. Sign in to Quiet Paper again.")?
                .to_owned(),
        );
        let id = string(session, "id")?.to_owned();
        let config = accepted(self.transport.send(
            &format!("{}/api/v1/config", self.base),
            &[],
            None,
        )?)?;
        let api_key = string(&config, "firebaseApiKey")?;
        let mut endpoint = url::Url::parse("https://securetoken.googleapis.com/v1/token")?;
        endpoint.query_pairs_mut().append_pair("key", api_key);
        let response = accepted(self.transport.send(
            endpoint.as_str(),
            &[],
            Some(Body::Form(vec![
                ("grant_type".into(), "refresh_token".into()),
                ("refresh_token".into(), refresh.to_string()),
            ])),
        )?)?;
        if response["user_id"].as_str() != Some(&id) {
            bail!("Authentication account mismatch");
        }
        self.token = Some(Zeroizing::new(string(&response, "id_token")?.to_owned()));
        Ok(())
    }
    fn request(&mut self, path: &str, body: Option<Value>) -> Result<Value> {
        if self.token.is_none() {
            self.authenticate(false)?;
        }
        let mut response = None;
        for attempt in 0..2 {
            let mut headers = vec![(
                "Authorization".into(),
                format!("Bearer {}", self.token.as_ref().unwrap().as_str()),
            )];
            if let Some(device) = &self.device {
                headers.push(("X-Device-Id".into(), device.clone()));
            }
            let sent = self.transport.send(
                &format!("{}{path}", self.base),
                &headers,
                body.clone().map(Body::Json),
            )?;
            if sent.status == 401 && attempt == 0 {
                self.authenticate(true)?;
                continue;
            }
            response = Some(sent);
            break;
        }
        accepted(response.context("Authentication retry failed")?)
    }
    fn verify_key(&mut self) -> Result<()> {
        let key = Zeroizing::new(*self.credentials.master_key()?);
        let remote = self.request("/api/v1/keys", None)?;
        let matches = if let Some(commitment) = remote["keyAuthCommitment"].as_str() {
            commitment == format!("{:x}", Sha256::digest(&key))
        } else {
            self.credentials
                .entries
                .get("quietpaper_wrapped_master_key_v1")
                .and_then(|v| serde_json::from_str::<Value>(v).ok())
                .is_some_and(|v| {
                    v["wrappedMasterKey"].is_string()
                        && v["wrappedMasterKey"] == remote["wrappedMasterKey"]
                })
        };
        if !matches {
            bail!("Local encryption keys do not match this cloud account. Unlock/sync in the desktop app first.");
        }
        Ok(())
    }
    pub fn upload(&mut self, row: &Value) -> Result<()> {
        let id = string(row, "id")?;
        let bytes = attachments::read_bounded(
            Path::new(
                string(row, "local_path")
                    .context("An attachment has no local encrypted payload")?,
            ),
            attachments::MAX_BYTES + 48,
        )?;
        // Authenticate local ciphertext before uploading even when the cloud key
        // matches, catching wrong-key/partial-migration files without data loss.
        let plaintext = crypto::decrypt_attachment(self.credentials.master_key()?, id, &bytes)?;
        if row["byte_size"].as_u64() != Some(plaintext.len() as u64)
            || row["sha256"].as_str() != Some(format!("{:x}", Sha256::digest(&plaintext)).as_str())
        {
            bail!("Attachment payload does not match its stored size/hash; changes remain pending");
        }
        let metadata = json!({"attachmentId":id,"noteId":row["note_id"],"mimeType":row["mime_type"],"byteSize":row["byte_size"],"sha256":row["sha256"]});
        let mut auth_body = metadata.clone();
        auth_body["variant"] = json!("original");
        let auth = self.request("/api/v1/attachments/upload-auth", Some(auth_body))?;
        let upload = auth["uploadUrl"]
            .as_str()
            .map(str::to_owned)
            .unwrap_or_else(|| {
                format!(
                    "https://api.cloudinary.com/v1_1/{}/raw/upload",
                    auth["cloudName"].as_str().unwrap_or_default()
                )
            });
        check_url(&upload, false)?;
        let mut fields = Vec::new();
        for (field, key) in [
            ("api_key", "apiKey"),
            ("timestamp", "timestamp"),
            ("signature", "signature"),
            ("public_id", "publicId"),
        ] {
            let value = &auth[key];
            if value.is_null() {
                bail!("Missing image upload authorization field");
            }
            fields.push((
                field.into(),
                value
                    .as_str()
                    .map(str::to_owned)
                    .unwrap_or_else(|| value.to_string()),
            ));
        }
        if let Some(folder) = auth["folder"].as_str() {
            fields.push(("folder".into(), folder.into()));
        }
        // A separate request with no account Authorization/device headers.
        let uploaded = accepted(self.transport.send(
            &upload,
            &[],
            Some(Body::Multipart {
                fields,
                filename: string(&auth, "publicId")?.into(),
                bytes: bytes.to_vec(),
            }),
        )?)?;
        let cloud_id = string(&uploaded, "public_id")?;
        let cloud_url = string(&uploaded, "secure_url")?;
        check_url(cloud_url, false)?;
        let mut confirmation = metadata;
        confirmation["fileName"] = row["file_name"].clone();
        confirmation["kind"] = row["kind"].clone();
        confirmation["cloudPublicId"] = json!(cloud_id);
        confirmation["cloudUrl"] = json!(cloud_url);
        let confirmed = self.request("/api/v1/attachments/confirm", Some(confirmation))?;
        let revision = confirmed["attachment"]["serverRevision"]
            .as_i64()
            .filter(|v| *v > 0)
            .context("Server did not acknowledge attachment metadata")?;
        self.db.transaction(||{
            if self.db.row("attachments",id)?!=*row{bail!("Attachment changed during upload; newer changes remain pending");}
            self.db.0.execute("UPDATE attachments SET is_dirty=0,upload_state='synced',server_revision=?,synced_at=?,cloud_public_id=?,cloud_url=? WHERE id=?",params![revision,writes::now(),cloud_id,cloud_url,id])?;
            Ok(())
        })
    }

    pub fn sync_one(&mut self, id: &str) -> Result<()> {
        self.verify_key()?;
        let journal_key = format!("cli_push:{id}");
        let journal = metadata(self.db, &journal_key)?;
        let journal = if let Some(value) = journal {
            serde_json::from_str::<Value>(&value).context("Invalid pending CLI push journal")?
        } else {
            let (row, note, queue, hash) = self.db.transaction(|| {
                let row = self.db.row("notes", id)?;
                let note = if row.is_null() {
                    None
                } else {
                    Some(self.db.find(id)?)
                };
                let queue = queue_ids(self.db, id)?;
                let hash = fingerprint(self.db, id)?;
                Ok((row, note, queue, hash))
            })?;
            let mut references = Vec::new();
            let change = if let Some(note) = note {
                for attachment in attachments::list(self.db, &note)? {
                    if attachment["is_dirty"] == 1 || attachment["upload_state"] != "synced" {
                        self.upload(&attachment)?;
                    }
                }
                let mut plaintext =
                    json!({"title":row["title"],"body":note.content,"tags":note.tags});
                for (column, key) in [
                    ("pinned_tags", "pinnedTags"),
                    ("import_sources", "importSources"),
                ] {
                    if let Some(text) = row[column].as_str() {
                        let value: Value = serde_json::from_str(text)
                            .context("Invalid local encrypted-note metadata")?;
                        if value.as_array().is_some_and(|a| !a.is_empty()) {
                            plaintext[key] = value;
                        }
                    }
                }
                let nonce = crypto::random::<24>()?;
                let serialized = Zeroizing::new(serde_json::to_vec(&plaintext)?);
                let ciphertext = crypto::encrypt(
                    self.credentials.master_key()?,
                    &nonce,
                    &serialized,
                    format!("quietpaper:note:{id}:v1").as_bytes(),
                )?;
                for (scheme, kind) in [("asset", "attachment"), ("document", "document")] {
                    for part in note.content.split(&format!("qp://{scheme}/")).skip(1) {
                        let resource = part
                            .chars()
                            .take_while(|c| c.is_ascii_hexdigit() || *c == '-')
                            .collect::<String>();
                        if Uuid::parse_str(&resource).is_ok() {
                            references.push(
                                json!({"resourceType":kind,"resourceId":resource,"noteId":id}),
                            );
                        }
                    }
                }
                let mut change = json!({"id":id,"createdAt":iso(row["created_at"].as_i64().context("Missing note timestamp")?)?,"updatedAt":iso(row["updated_at"].as_i64().context("Missing note timestamp")?)?,"archived":note.is_archived,"trashed":note.is_trashed,"pinned":note.is_pinned,"contentCiphertext":crypto::encode(&ciphertext),"contentNonce":crypto::encode(&nonce),"contentVersion":1,"encryptionKeyVersion":1,"baseRevision":row["server_revision"],"isDeleted":false});
                if let Some(deleted) = row["deleted_at"].as_i64() {
                    change["deletedAt"] = json!(iso(deleted)?);
                }
                change
            } else {
                let tombstone = metadata(self.db, &format!("cli_delete:{id}"))?
                    .map(|s| serde_json::from_str::<Value>(&s))
                    .transpose()?
                    .unwrap_or(json!({"baseRevision":null,"time":writes::now()}));
                if queue.is_empty() {
                    return Ok(());
                }
                json!({"id":id,"createdAt":iso(tombstone["time"].as_i64().unwrap_or(writes::now()))?,"updatedAt":iso(tombstone["time"].as_i64().unwrap_or(writes::now()))?,"deletedAt":iso(tombstone["time"].as_i64().unwrap_or(writes::now()))?,"isDeleted":true,"archived":false,"trashed":true,"pinned":false,"contentCiphertext":"","contentNonce":"","contentVersion":1,"encryptionKeyVersion":1,"baseRevision":tombstone["baseRevision"]})
            };
            let mut body =
                json!({"idempotencyKey":format!("cli_{}",Uuid::new_v4()),"changes":[change]});
            if let Some(device) = &self.device {
                body["deviceId"] = json!(device);
            }
            let journal = json!({"body":body,"hash":hash,"queue":queue,"references":references,"account":self.session.as_ref().and_then(|s|s["id"].as_str())});
            self.db.transaction(|| {
                if fingerprint(self.db, id)? != hash {
                    bail!("Note changed before upload; changes remain pending");
                }
                set_metadata(self.db, &journal_key, &journal.to_string())
            })?;
            journal
        };
        if journal["account"].as_str() != self.session.as_ref().and_then(|s| s["id"].as_str()) {
            bail!("Pending upload belongs to a different account; resolve it in the desktop app");
        }
        let response = self.request("/api/v1/sync/push", Some(journal["body"].clone()))?;
        if response["conflicts"]
            .as_array()
            .is_some_and(|a| !a.is_empty())
        {
            self.db
                .0
                .execute("DELETE FROM sync_metadata WHERE key=?", [&journal_key])?;
            bail!("Remote note conflict. Local changes remain pending; resolve it in the desktop app.");
        }
        let result = response["results"]
            .as_array()
            .and_then(|a| a.iter().find(|r| r["id"].as_str() == Some(id)))
            .context("Server did not acknowledge the note")?;
        let revision = result["revision"]
            .as_i64()
            .filter(|v| *v > 0)
            .context("Invalid server note revision")?;
        if result["status"].as_str().is_some_and(|s| s != "applied") {
            bail!("Server did not apply the note; changes remain pending");
        }
        let base = journal["body"]["changes"][0]["baseRevision"]
            .as_i64()
            .unwrap_or(0);
        // Advance this snapshot's base without clearing newer GUI mutations.
        self.db.0.execute(
            "UPDATE notes SET server_revision=? WHERE id=? AND server_revision=?",
            params![revision, id, base],
        )?;
        if self.db.row("notes", id)?.is_null() {
            let key = format!("cli_delete:{id}");
            if let Some(value) = metadata(self.db, &key)? {
                let mut tombstone: Value = serde_json::from_str(&value)?;
                if tombstone["baseRevision"].as_i64() == Some(base) {
                    tombstone["baseRevision"] = json!(revision);
                    set_metadata(self.db, &key, &tombstone.to_string())?;
                }
            }
        }
        if journal["references"]
            .as_array()
            .is_some_and(|a| !a.is_empty())
        {
            for chunk in journal["references"].as_array().unwrap().chunks(500) {
                let mut references = json!({"references":chunk});
                if let Some(device) = &self.device {
                    references["deviceId"] = json!(device);
                }
                let result = self.request("/api/v1/sync/references", Some(references))?;
                if result["success"] != true {
                    bail!("Server did not acknowledge attachment references");
                }
            }
        }
        let clean = self.db.transaction(|| {
            let same = fingerprint(self.db, id)? == journal["hash"].as_str().unwrap_or_default();
            let row = self.db.row("notes", id)?;
            let same = same && (row.is_null() || row["server_revision"].as_i64() == Some(revision));
            if same {
                self.db.0.execute(
                    "UPDATE notes SET is_dirty=0,synced_at=? WHERE id=?",
                    params![writes::now(), id],
                )?;
                for queue in journal["queue"]
                    .as_array()
                    .context("Invalid pending queue")?
                {
                    self.db.0.execute(
                        "DELETE FROM sync_queue WHERE id=?",
                        [queue.as_str().context("Invalid queue identity")?],
                    )?;
                }
                self.db.0.execute(
                    "DELETE FROM sync_metadata WHERE key=?",
                    [format!("cli_delete:{id}")],
                )?;
            }
            self.db
                .0
                .execute("DELETE FROM sync_metadata WHERE key=?", [&journal_key])?;
            Ok(same)
        })?;
        if !clean {
            bail!("Snapshot uploaded; newer local changes remain pending");
        }
        Ok(())
    }
}

fn queue_ids(db: &Database, id: &str) -> Result<Vec<String>> {
    let mut statement =
        db.0.prepare("SELECT id FROM sync_queue WHERE note_id=? ORDER BY id")?;
    let ids = statement
        .query_map([id], |r| r.get(0))?
        .collect::<rusqlite::Result<Vec<_>>>()?;
    Ok(ids)
}
fn fingerprint(db: &Database, id: &str) -> Result<String> {
    let mut row = db.row("notes", id)?;
    if let Some(row) = row.as_object_mut() {
        row.remove("server_revision");
    }
    let tags = if row.is_null() {
        Vec::new()
    } else {
        db.find(id)?.tags
    };
    Ok(format!(
        "{:x}",
        Sha256::digest(serde_json::to_vec(
            &json!({"row":row,"tags":tags,"queue":queue_ids(db,id)?})
        )?)
    ))
}
pub fn metadata(db: &Database, key: &str) -> Result<Option<String>> {
    Ok(db
        .0
        .query_row("SELECT value FROM sync_metadata WHERE key=?", [key], |r| {
            r.get(0)
        })
        .optional()?)
}
pub fn set_metadata(db: &Database, key: &str, value: &str) -> Result<()> {
    db.0.execute("INSERT INTO sync_metadata (key,value,updated_at) VALUES (?,?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value,updated_at=excluded.updated_at",params![key,value,writes::now()])?;
    Ok(())
}

pub fn run(db: &Database, path: &Path, queries: &[String]) -> Result<()> {
    let ids = if !queries.is_empty() {
        let query = queries.join(" ");
        if db.row("notes", &query)?.is_null()
            && db.0.query_row(
                "SELECT EXISTS(SELECT 1 FROM sync_queue WHERE note_id=? AND operation='delete')",
                [&query],
                |r| r.get::<_, bool>(0),
            )?
        {
            vec![query]
        } else {
            editor::resolve(db, queries, false)?
                .map(|n| vec![n.id])
                .unwrap_or_default()
        }
    } else {
        let mut stmt=db.0.prepare("SELECT id FROM notes WHERE is_dirty=1 OR EXISTS (SELECT 1 FROM attachments a WHERE a.is_deleted=0 AND (a.is_dirty=1 OR a.upload_state!='synced') AND instr(notes.content,'qp://asset/'||a.id)>0) UNION SELECT note_id FROM sync_queue WHERE operation='delete' UNION SELECT substr(key,10) FROM sync_metadata WHERE key LIKE 'cli_push:%'")?;
        let ids = stmt
            .query_map([], |r| r.get::<_, String>(0))?
            .collect::<rusqlite::Result<Vec<_>>>()?;
        ids
    };
    if ids.is_empty() {
        println!("No pending notes.");
        return Ok(());
    }
    let _lock = lock(path)?;
    let mut credentials = Credentials::read(path)?;
    let mut sync = Sync::new(
        db,
        &mut credentials,
        Http::new()?,
        env::var("QP_API_URL").unwrap_or_else(|_| "https://quitepaper.vercel.app".into()),
    )?;
    let mut failed = false;
    for id in ids {
        match sync.sync_one(&id) {
            Ok(()) => println!("Synced note and attachments [{id}]"),
            Err(error) => {
                eprintln!("Sync pending [{id}]: {error:#}");
                failed = true;
            }
        }
    }
    if failed {
        bail!("Some changes remain pending");
    }
    Ok(())
}
pub fn after_save(db: &Database, path: &Path, id: &str) {
    let result = (|| {
        let _lock = lock(path)?;
        let mut credentials = Credentials::read(path)?;
        if !credentials
            .entries
            .contains_key("quietpaper_auth_session_v1")
        {
            bail!("Sign in to the desktop app to enable CLI sync");
        }
        Sync::new(
            db,
            &mut credentials,
            Http::new()?,
            env::var("QP_API_URL").unwrap_or_else(|_| "https://quitepaper.vercel.app".into()),
        )?
        .sync_one(id)
    })();
    match result {
        Ok(()) => eprintln!("Synced note and attachments."),
        Err(error) => eprintln!("Saved locally; sync pending: {error:#}"),
    }
}

fn lock(database: &Path) -> Result<std::fs::File> {
    use std::{fs::OpenOptions, os::unix::fs::OpenOptionsExt};
    let mut name = std::ffi::OsString::from(".");
    name.push(
        database
            .file_name()
            .unwrap_or(std::ffi::OsStr::new("notebook")),
    );
    name.push(".cli-sync.lock");
    let path = database.parent().unwrap_or(Path::new(".")).join(name);
    let file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .mode(0o600)
        .open(path)?;
    file.try_lock().map_err(|_| {
        anyhow::anyhow!("Another CLI sync is running; local changes remain pending")
    })?;
    Ok(file)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    type Handler<'a> = dyn Fn(&str, &[(String, String)], Option<Body>) -> Result<Response> + 'a;
    struct Mock<'a>(Box<Handler<'a>>);
    impl Transport for Mock<'_> {
        fn send(
            &self,
            url: &str,
            headers: &[(String, String)],
            body: Option<Body>,
        ) -> Result<Response> {
            (self.0)(url, headers, body)
        }
    }
    fn session() -> Value {
        json!({"id":"fixture-user","idToken":"old-token","refreshToken":"refresh-token","tokenExpiresAt":"2099-01-01T00:00:00Z"})
    }
    fn db() -> Database {
        let db = Database(rusqlite::Connection::open_in_memory().unwrap());
        db.0.execute_batch("CREATE TABLE sync_metadata(key TEXT PRIMARY KEY,value TEXT,updated_at INTEGER); CREATE TABLE attachments(id TEXT PRIMARY KEY,note_id TEXT,file_name TEXT,kind TEXT,mime_type TEXT,byte_size INTEGER,sha256 TEXT,local_path TEXT,is_dirty INTEGER,upload_state TEXT,server_revision INTEGER,synced_at INTEGER,cloud_public_id TEXT,cloud_url TEXT);").unwrap();
        db
    }
    #[test]
    fn upload_uses_encrypted_multipart_without_account_headers_and_preserves_races() {
        for race in [false, true] {
            let db = db();
            let dir = tempfile::tempdir().unwrap();
            let key = [9; 32];
            let id = "11111111-2222-4333-8444-555555555555";
            let file = dir.path().join("payload.enc");
            std::fs::write(
                &file,
                crypto::encrypt_attachment(&key, id, b"secret image pixels").unwrap(),
            )
            .unwrap();
            db.0.execute("INSERT INTO attachments (id,note_id,file_name,kind,mime_type,byte_size,sha256,local_path,is_dirty,upload_state,server_revision) VALUES (?,'note','photo.png','image','image/png',19,?,?,1,'upload_pending',0)",params![id,format!("{:x}",Sha256::digest(b"secret image pixels")),file.to_str()]).unwrap();
            let row = db.row("attachments", id).unwrap();
            let calls = RefCell::new(Vec::new());
            let transport = Mock(Box::new(|url, headers, body| {
                calls.borrow_mut().push(url.to_owned());
                let value = if url.ends_with("upload-auth") {
                    assert!(headers
                        .iter()
                        .any(|(k, v)| k == "Authorization" && v == "Bearer old-token"));
                    json!({"uploadUrl":"https://upload.example/raw","publicId":"asset","apiKey":"public","timestamp":123,"signature":"signed"})
                } else if url == "https://upload.example/raw" {
                    assert!(headers.is_empty());
                    let Some(Body::Multipart {
                        fields,
                        bytes,
                        filename,
                    }) = body
                    else {
                        panic!("Expected multipart");
                    };
                    assert_eq!(filename, "asset");
                    assert_eq!(fields.len(), 4);
                    assert!(bytes.starts_with(b"QPA1"));
                    assert_eq!(
                        &**crypto::decrypt_attachment(&key, id, &bytes).unwrap(),
                        b"secret image pixels"
                    );
                    if race {
                        db.0.execute(
                            "UPDATE attachments SET sha256='new-content' WHERE id=?",
                            [id],
                        )
                        .unwrap();
                    }
                    json!({"public_id":"asset","secure_url":"https://upload.example/asset"})
                } else {
                    assert!(url.ends_with("/confirm"));
                    json!({"attachment":{"serverRevision":4}})
                };
                Ok(Response { status: 200, value })
            }));
            let mut credentials = Credentials::fixture(key, session());
            let result = Sync::new(
                &db,
                &mut credentials,
                transport,
                "https://api.example".into(),
            )
            .unwrap()
            .upload(&row);
            assert_eq!(result.is_err(), race);
            assert_eq!(calls.borrow().len(), 3);
            let current = db.row("attachments", id).unwrap();
            assert_eq!(current["is_dirty"], if race { 1 } else { 0 });
            if !race {
                assert_eq!(current["server_revision"], 4);
                assert_eq!(current["upload_state"], "synced");
            }
        }
    }
    #[test]
    fn unauthorized_requests_refresh_once_and_check_account_identity() {
        for mismatch in [false, true] {
            let db = db();
            let key = [8; 32];
            let calls = RefCell::new(Vec::new());
            let transport = Mock(Box::new(|url, headers, body| {
                let count = calls.borrow().len();
                calls.borrow_mut().push(url.to_owned());
                if count == 0 {
                    return Ok(Response {
                        status: 401,
                        value: json!({}),
                    });
                }
                let value = if url.ends_with("/config") {
                    assert!(headers.is_empty());
                    json!({"firebaseApiKey":"public-api-key"})
                } else if url.starts_with("https://securetoken.googleapis.com") {
                    assert!(headers.is_empty());
                    let Some(Body::Form(fields)) = body else {
                        panic!("Expected form");
                    };
                    assert!(fields.contains(&("refresh_token".into(), "refresh-token".into())));
                    json!({"user_id":if mismatch{"wrong-user"}else{"fixture-user"},"id_token":"refreshed"})
                } else {
                    assert!(headers
                        .iter()
                        .any(|(k, v)| k == "Authorization" && v == "Bearer refreshed"));
                    json!({"keyAuthCommitment":format!("{:x}",Sha256::digest(key))})
                };
                Ok(Response { status: 200, value })
            }));
            let mut credentials = Credentials::fixture(key, session());
            let result = Sync::new(
                &db,
                &mut credentials,
                transport,
                "https://api.example".into(),
            )
            .unwrap()
            .verify_key();
            assert_eq!(result.is_err(), mismatch);
            assert_eq!(calls.borrow().len(), if mismatch { 3 } else { 4 });
        }
    }
}
