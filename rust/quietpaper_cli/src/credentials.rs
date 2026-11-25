use crate::{crypto, database, process};
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use anyhow::{bail, Context, Result};
use sha2::{Digest, Sha256};
use std::{
    collections::BTreeMap,
    env, fs,
    io::{self, IsTerminal},
    path::Path,
    time::Duration,
};
use zeroize::Zeroizing;

pub struct Credentials {
    pub entries: BTreeMap<String, Zeroizing<String>>,
    key: Option<Zeroizing<[u8; 32]>>,
}

impl Credentials {
    #[cfg(test)]
    pub fn fixture(key: [u8; 32], session: serde_json::Value) -> Self {
        let entries = [(
            "quietpaper_auth_session_v1".into(),
            Zeroizing::new(session.to_string()),
        )]
        .into_iter()
        .collect();
        Self {
            entries,
            key: Some(Zeroizing::new(key)),
        }
    }
    pub fn read(database: &Path) -> Result<Self> {
        let mut entries = BTreeMap::new();
        let canonical = database::default_path()
            .ok()
            .and_then(|p| fs::canonicalize(p).ok());
        if canonical.is_some() && canonical == fs::canonicalize(database).ok() {
            if let Ok(bytes) = process::capture(
                "secret-tool",
                &[
                    "lookup",
                    "account",
                    "com.blackpiratex.quietpaper.secureStorage",
                ],
                1024 * 1024,
                Duration::from_secs(5),
            ) {
                let bytes = Zeroizing::new(bytes);
                if let Ok(values) = serde_json::from_slice::<BTreeMap<String, String>>(&bytes) {
                    entries.extend(values.into_iter().map(|(k, v)| (k, Zeroizing::new(v))));
                }
            }
        }
        let root = database.parent().unwrap_or(Path::new("."));
        let store = root.join(".secure_storage_fallback.enc");
        let salt = root.join(".secure_storage_key");
        if store.is_file() && salt.is_file() {
            let machine = ["/etc/machine-id", "/var/lib/dbus/machine-id"]
                .iter()
                .find_map(|path| {
                    fs::read_to_string(path)
                        .ok()
                        .filter(|s| !s.trim().is_empty())
                })
                .unwrap_or_default();
            let mut hash = Sha256::new();
            hash.update(fs::read(salt)?);
            hash.update(machine.trim().as_bytes());
            hash.update(env::var("USER").unwrap_or_default().as_bytes());
            let key = Zeroizing::new(<[u8; 32]>::from(hash.finalize()));
            let data = fs::read(store)?;
            if data.len() < 28 {
                bail!("Invalid encrypted credential store");
            }
            let decrypted = Zeroizing::new(
                Aes256Gcm::new((&*key).into())
                    .decrypt(Nonce::from_slice(&data[..12]), &data[12..])
                    .map_err(|_| {
                        anyhow::anyhow!("Cannot authenticate desktop fallback credentials")
                    })?,
            );
            let values: BTreeMap<String, String> =
                serde_json::from_slice(&decrypted).context("Invalid desktop credentials")?;
            for (key, value) in values {
                entries.entry(key).or_insert_with(|| Zeroizing::new(value));
            }
        }
        Ok(Self { entries, key: None })
    }

    pub fn master_key(&mut self) -> Result<&[u8; 32]> {
        if self.key.is_none() {
            if let Some(stored) = self.entries.get("quietpaper_master_key_v1") {
                let bytes = Zeroizing::new(crypto::decode(stored)?);
                self.key = Some(Zeroizing::new(
                    bytes
                        .as_slice()
                        .try_into()
                        .context("Invalid stored encryption key")?,
                ));
            } else {
                let wrapped=self.entries.get("quietpaper_wrapped_master_key_v1")
                    .context("Encryption credentials unavailable. Unlock the Linux keyring (secret-tool) or initialize this notebook in Quiet Paper.")?;
                let wrapped = serde_json::from_str(wrapped)?;
                if !io::stdin().is_terminal() {
                    bail!("Encryption keys are locked. Run interactively to enter your encryption password.");
                }
                let password = Zeroizing::new(rpassword::prompt_password("Encryption password: ")?);
                if password.is_empty() {
                    bail!("Unlock cancelled");
                }
                self.key = Some(crypto::unwrap(&password, &wrapped)?);
            }
        }
        Ok(self.key.as_ref().unwrap())
    }
}
