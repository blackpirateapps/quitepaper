# Quiet Paper — End-to-End Encryption Specification

Quiet Paper implements a zero-knowledge, client-side end-to-end encryption architecture inspired by the security principles of modern cryptographic password managers and private note apps.

---

## 1. The Core Security Property

> **The backend server (Vercel) and database (Turso/libSQL) NEVER have access to plaintext note content or the user's note-encryption keys.**

All encryption and decryption happens exclusively on the client device before note content is transmitted over the network or persisted to cloud storage.

---

## 2. Encryption Boundary

| Field | Server-Readable | Encrypted Client-Side | Notes |
|---|---|---|---|
| `title` | ❌ No | ✅ Yes | Plaintext never leaves device |
| `body` (content) | ❌ No | ✅ Yes | Plaintext never leaves device |
| `tags` | ❌ No | ✅ Yes | Plaintext never leaves device |
| `id` | ✅ Yes | ❌ No | Client-generated UUIDv4/v7 |
| `created_at` / `updated_at` | ✅ Yes | ❌ No | Required for sorting & sync |
| `archived` / `trashed` / `pinned` | ✅ Yes | ❌ No | Boolean lifecycle flags |
| `revision` | ✅ Yes | ❌ No | Monotonic server revision counter |
| `deleted_at` | ✅ Yes | ❌ No | Soft-delete timestamp for sync |
| `encryption_key_version` | ✅ Yes | ❌ No | Identifies master key version |

The server database schema contains **no plaintext title, body, or tags columns**.

---

## 3. Cryptographic Primitives

Quiet Paper uses established, modern cryptographic algorithms via `package:cryptography`:

- **Password Key Derivation Function (KDF)**: **Argon2id** (RFC 9106)
  - Memory: `19,456 KB` (19 MB)
  - Iterations: `2`
  - Parallelism: `1`
  - Output Key Length: `32 bytes` (256 bits)
  - Cryptographically secure 16-byte random salt per wrapping
- **Authenticated Content Encryption**: **XChaCha20-Poly1305** (AEAD)
  - Key: 32-byte Master Key
  - Nonce: 24-byte cryptographically secure random nonce per operation (immune to collision risks)
  - Authentication Tag: 16-byte Poly1305 MAC tag
- **Authenticated Associated Data (AAD)**:
  - Note Payload: `quietpaper:note:<noteId>:v<version>`
  - Key Wrapping: `quietpaper:key-wrap:v1`
  - *Prevents ciphertext swapping across note IDs or user accounts.*

---

## 4. Key Hierarchy

```text
Quiet Paper Encryption Password (User-Held)
            │
            ▼ (Argon2id + 16-byte Salt)
   Password-Derived Key (32 bytes)
            │
            ▼ (XChaCha20-Poly1305 Unwrapping)
   MASTER KEY (256-bit Random Secret)
            │
            ▼ (XChaCha20-Poly1305 + AAD)
   Encrypted Note Payload {"title": "...", "body": "...", "tags": [...]}
```

---

## 5. Password Changes (Re-Wrapping Without Re-Encryption)

When a user changes their Quiet Paper encryption password:
1. The device unwraps the active Master Key using the old password key.
2. The device derives a new key from the new password with a fresh random salt.
3. The device re-wraps the **same Master Key** with the new key.
4. The device uploads the newly wrapped master key metadata to the server (`PUT /api/v1/keys`).

**Result**: Note ciphertexts on the server remain completely unchanged! The user does not need to re-encrypt or re-upload gigabytes of notes.

---

## 6. Emergency Recovery Key

During account setup, a 256-bit random recovery key is generated:
- Format: `qp-xxxx-xxxx-xxxx-xxxx-xxxx-xxxx-xxxx-xxxx` (human-readable hex chunks).
- The Master Key is wrapped with a key derived from the recovery key and uploaded as `recovery_wrapped_master_key`.
- If the user forgets their encryption password, they can supply the recovery key on a new or existing device to unwrap the Master Key and choose a new password.

---

## 7. Local Key Storage

- Decrypted Master Key is held in volatile memory only while unlocked.
- Locked / backgrounded state wipes key bytes (`fillRange(0, length, 0)`).
- Wrapped key metadata is stored locally using `FlutterSecureStorage` (Android Keystore / iOS Keychain).
