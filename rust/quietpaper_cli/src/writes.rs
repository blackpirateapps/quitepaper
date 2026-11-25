use crate::{database::Database, markdown, model::Note};
use anyhow::{bail, Context, Result};
use rusqlite::{params, types::ValueRef, OptionalExtension, Transaction, TransactionBehavior};
use serde_json::{json, Value};
use std::{collections::BTreeMap, path::Path};
use uuid::Uuid;

pub struct Save<'a> {
    pub id: &'a str,
    pub title: &'a str,
    pub content: &'a str,
    pub tags: &'a [String],
    pub pinned: bool,
    pub expected: Option<&'a Value>,
}

pub fn now() -> i64 {
    jiff::Timestamp::now().as_second()
}

impl Database {
    pub fn transaction<T>(&self, action: impl FnOnce() -> Result<T>) -> Result<T> {
        let transaction = Transaction::new_unchecked(&self.0, TransactionBehavior::Immediate)?;
        let result = action()?;
        transaction.commit()?;
        Ok(result)
    }

    pub fn row(&self, table: &str, id: &str) -> Result<Value> {
        // Table names are internal constants, never CLI input.
        let mut stmt = self
            .0
            .prepare(&format!("SELECT * FROM {table} WHERE id = ?"))?;
        let names: Vec<String> = stmt.column_names().map(|s| s.to_string()).collect();
        let mut rows = stmt.query([id])?;
        let Some(row) = rows.next()? else {
            return Ok(Value::Null);
        };
        let mut map = serde_json::Map::new();
        for (i, name) in names.into_iter().enumerate() {
            let value = match row.get_ref(i)? {
                ValueRef::Null => Value::Null,
                ValueRef::Integer(v) => json!(v),
                ValueRef::Real(v) => json!(v),
                ValueRef::Text(v) => json!(std::str::from_utf8(v)?),
                ValueRef::Blob(_) => bail!("Unsupported binary field in {table}"),
            };
            map.insert(name, value);
        }
        Ok(Value::Object(map))
    }

    pub fn snapshot(&self, id: &str) -> Result<Value> {
        Ok(json!({"row": self.row("notes", id)?, "tags": self.find(id)?.tags}))
    }

    pub fn check_snapshot(&self, id: &str, expected: &Value) -> Result<()> {
        if self.snapshot(id).ok().as_ref() != Some(expected) {
            bail!(
                "The note changed while you were editing. Save cancelled; your draft is preserved."
            );
        }
        Ok(())
    }

    pub fn save_inner(&self, save: &Save<'_>) -> Result<Note> {
        if let Some(expected) = save.expected {
            self.check_snapshot(save.id, expected)?;
        }
        let now = now();
        let fm = markdown::frontmatter(save.content);
        let tags = markdown::tags(save.title, save.content, save.tags);
        if save.expected.is_some() {
            self.0.execute("UPDATE notes SET title=?, content=?, updated_at=?, is_pinned=?, is_dirty=1, journal_date=COALESCE(?,journal_date) WHERE id=?", params![save.title, save.content, now, save.pinned, fm.journal_date, save.id])?;
        } else {
            self.0.execute("INSERT INTO notes (id,title,content,created_at,updated_at,is_pinned,is_dirty,journal_date) VALUES (?,?,?,?,?,?,1,?)", params![save.id, save.title, save.content, now, now, save.pinned, fm.journal_date])?;
        }
        let pinned: Vec<String> = self
            .0
            .query_row("SELECT pinned_tags FROM notes WHERE id=?", [save.id], |r| {
                r.get::<_, Option<String>>(0)
            })?
            .and_then(|v| serde_json::from_str(&v).ok())
            .unwrap_or_default();
        self.0
            .execute("DELETE FROM note_tags WHERE note_id=?", [save.id])?;
        for tag in &tags {
            let existing: Option<String> = self
                .0
                .query_row("SELECT id FROM tags WHERE name=?", [tag], |r| r.get(0))
                .optional()?;
            let id = existing.unwrap_or_else(|| {
                Uuid::new_v5(
                    &Uuid::NAMESPACE_URL,
                    format!("quitepaper:tag:{tag}").as_bytes(),
                )
                .to_string()
            });
            self.0.execute("INSERT INTO tags (id,name,created_at,updated_at,is_dirty) VALUES (?,?,?,?,1) ON CONFLICT(name) DO UPDATE SET is_deleted=0,deleted_at=NULL,updated_at=excluded.updated_at,is_dirty=1 WHERE tags.is_deleted=1", params![id,tag,now,now])?;
            self.0.execute(
                "INSERT INTO note_tags (note_id,tag_id,is_pinned) VALUES (?,?,?)",
                params![save.id, id, pinned.contains(tag)],
            )?;
        }
        self.0.execute("INSERT INTO note_versions (id,note_id,version_number,title,content,tags_json,created_at,char_count,word_count,is_dirty) SELECT ?,?,COALESCE(MAX(version_number),0)+1,?,?,?,?,?,?,1 FROM note_versions WHERE note_id=?", params![Uuid::new_v4().to_string(),save.id,save.title,save.content,serde_json::to_string(&tags)?,now,save.content.encode_utf16().count() as i64,save.content.split_whitespace().count() as i64,save.id])?;
        self.queue(save.id, "upsert")?;
        self.update_search(save.id)?;
        self.find(save.id)
    }

    pub fn queue(&self, id: &str, operation: &str) -> Result<()> {
        self.0.execute(
            "INSERT INTO sync_queue (id,note_id,operation,created_at,attempts) VALUES (?,?,?,?,0)",
            params![Uuid::new_v4().to_string(), id, operation, now()],
        )?;
        Ok(())
    }

    fn delete_search(&self, id: &str) -> Result<()> {
        for table in ["note_search_prefix", "note_search_trigram"] {
            self.0
                .execute(&format!("DELETE FROM {table} WHERE note_id=?"), [id])?;
        }
        Ok(())
    }

    pub fn update_search(&self, id: &str) -> Result<()> {
        self.delete_search(id)?;
        let note = self.find(id)?;
        let row = self.row("notes", id)?;
        if note.is_trashed || !row["deleted_at"].is_null() {
            return Ok(());
        }
        let body = if note
            .content
            .trim_start()
            .starts_with("<!-- quiet-paper-encrypted-note-v1:")
        {
            String::new()
        } else {
            markdown::plain_text(&note.content)
        };
        let tags = note
            .tags
            .iter()
            .map(|t| format!("{t} #{t}"))
            .collect::<Vec<_>>()
            .join(" ");
        for table in ["note_search_prefix", "note_search_trigram"] {
            self.0.execute(
                &format!("INSERT INTO {table} (note_id,title,body_text,tags) VALUES (?,?,?,?)"),
                params![id, note.title, body, tags],
            )?;
        }
        Ok(())
    }

    pub fn delete(&self, note: &Note, restore: bool, permanent: bool) -> Result<()> {
        self.transaction(|| {
            if permanent {
                let row=self.row("notes",&note.id)?;
                crate::sync::set_metadata(self,&format!("cli_delete:{}",note.id),&serde_json::json!({"baseRevision":row["server_revision"],"time":now()}).to_string())?;
                self.0.execute("DELETE FROM notes WHERE id=?", [&note.id])?;
                self.delete_search(&note.id)?;
                self.queue(&note.id,"delete")?;
            } else {
                self.0.execute("UPDATE notes SET is_trashed=?, deleted_at=?, updated_at=?, is_dirty=1 WHERE id=?", params![!restore, if restore {None} else {Some(now())}, now(), note.id])?;
                self.update_search(&note.id)?;
                self.queue(&note.id,"upsert")?;
            }
            Ok(())
        })
    }
}

pub fn preserve_draft(database: &Path, text: &str) -> Result<std::path::PathBuf> {
    use std::{
        fs::{self, DirBuilder, OpenOptions},
        io::Write,
        os::unix::fs::{DirBuilderExt, OpenOptionsExt, PermissionsExt},
    };
    let root = database
        .parent()
        .unwrap_or(Path::new("."))
        .join("cli-drafts");
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(&root)?;
    fs::set_permissions(&root, fs::Permissions::from_mode(0o700))?;
    let path = root.join(format!("{}.md", Uuid::new_v4()));
    let mut file = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(&path)?;
    file.write_all(text.as_bytes())
        .context("Could not preserve editor draft")?;
    file.sync_all()?;
    Ok(path)
}

pub fn guard_editor(content: &str) -> Result<()> {
    if content
        .trim_start()
        .starts_with("<!-- quiet-paper-encrypted-note-v1:")
    {
        bail!("Unlock password-protected notes in the desktop app before editing.");
    }
    if serde_json::from_str::<BTreeMap<String, Value>>(content).is_ok() {
        bail!("Edit rich documents in the desktop app; the CLI editor accepts Markdown.");
    }
    Ok(())
}
