use anyhow::{bail, Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use chacha20poly1305::{
    aead::{Aead, KeyInit, Payload},
    XChaCha20Poly1305, XNonce,
};
use zeroize::Zeroizing;

pub fn random<const N: usize>() -> Result<[u8; N]> {
    let mut bytes = [0; N];
    getrandom::fill(&mut bytes).map_err(|_| anyhow::anyhow!("Secure random source unavailable"))?;
    Ok(bytes)
}
pub fn decode(text: &str) -> Result<Vec<u8>> {
    STANDARD
        .decode(text)
        .context("Invalid base64 encryption data")
}

pub fn encrypt(key: &[u8; 32], nonce: &[u8; 24], plaintext: &[u8], aad: &[u8]) -> Result<Vec<u8>> {
    XChaCha20Poly1305::new(key.into())
        .encrypt(
            XNonce::from_slice(nonce),
            Payload {
                msg: plaintext,
                aad,
            },
        )
        .map_err(|_| anyhow::anyhow!("Encryption failed"))
}
pub fn decrypt(
    key: &[u8; 32],
    nonce: &[u8],
    ciphertext: &[u8],
    aad: &[u8],
) -> Result<Zeroizing<Vec<u8>>> {
    if nonce.len() != 24 {
        bail!("Invalid encryption nonce");
    }
    XChaCha20Poly1305::new(key.into())
        .decrypt(
            XNonce::from_slice(nonce),
            Payload {
                msg: ciphertext,
                aad,
            },
        )
        .map(Zeroizing::new)
        .map_err(|_| anyhow::anyhow!("Authentication failed: wrong key or damaged ciphertext"))
}
pub fn encrypt_attachment(key: &[u8; 32], id: &str, bytes: &[u8]) -> Result<Vec<u8>> {
    let nonce = random::<24>()?;
    let mut envelope = b"QPA1\x00\x01\x00\x01".to_vec();
    envelope.extend(nonce);
    envelope.extend(encrypt(
        key,
        &nonce,
        bytes,
        format!("quietpaper:asset:{id}:original:v1").as_bytes(),
    )?);
    Ok(envelope)
}
pub fn decrypt_attachment(key: &[u8; 32], id: &str, bytes: &[u8]) -> Result<Zeroizing<Vec<u8>>> {
    if bytes.len() < 48 || &bytes[..4] != b"QPA1" || bytes[4..6] != [0, 1] || bytes[6..8] != [0, 1]
    {
        bail!("Invalid or unsupported QPA1 attachment envelope");
    }
    decrypt(
        key,
        &bytes[8..32],
        &bytes[32..],
        format!("quietpaper:asset:{id}:original:v1").as_bytes(),
    )
}

pub fn unwrap(password: &str, wrapped: &serde_json::Value) -> Result<Zeroizing<[u8; 32]>> {
    let string = |key: &str| {
        wrapped[key]
            .as_str()
            .with_context(|| format!("Missing wrapped key field: {key}"))
    };
    if wrapped["kdfAlgorithm"].as_str().unwrap_or("argon2id") != "argon2id" {
        bail!("Unsupported key derivation algorithm");
    }
    let params = &wrapped["kdfParameters"];
    let memory = params["memory"].as_u64().unwrap_or(19 * 1024);
    let iterations = params["iterations"].as_u64().unwrap_or(2);
    let parallelism = params["parallelism"].as_u64().unwrap_or(1);
    if memory > 262144
        || iterations > 10
        || parallelism > 8
        || params["hashLength"].as_u64().unwrap_or(32) != 32
    {
        bail!("Unsupported key derivation parameters");
    }
    let parameters = argon2::Params::new(
        memory as u32,
        iterations as u32,
        parallelism as u32,
        Some(32),
    )
    .map_err(|_| anyhow::anyhow!("Invalid key derivation parameters"))?;
    let mut key = Zeroizing::new([0; 32]);
    argon2::Argon2::new(
        argon2::Algorithm::Argon2id,
        argon2::Version::V0x13,
        parameters,
    )
    .hash_password_into(
        password.as_bytes(),
        &decode(string("kdfSalt")?)?,
        key.as_mut(),
    )
    .map_err(|_| anyhow::anyhow!("Password derivation failed"))?;
    let plaintext = decrypt(
        &key,
        &decode(string("wrappedNonce")?)?,
        &decode(string("wrappedMasterKey")?)?,
        b"quietpaper:key-wrap:v1",
    )?;
    Ok(Zeroizing::new(
        plaintext
            .as_slice()
            .try_into()
            .context("Invalid unwrapped master key length")?,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn attachment_binds_identity_and_rejects_tampering() {
        let key = [7; 32];
        let mut bytes = encrypt_attachment(&key, "one", b"private pixels").unwrap();
        assert_eq!(
            &**decrypt_attachment(&key, "one", &bytes).unwrap(),
            b"private pixels"
        );
        assert!(decrypt_attachment(&key, "two", &bytes).is_err());
        bytes[35] ^= 1;
        assert!(decrypt_attachment(&key, "one", &bytes).is_err());
        assert!(decrypt_attachment(&key, "one", b"QPA1").is_err());
    }
}
