# Quiet Paper — Security Review & Threat Model

---

## 1. Threat Model & Trust Assumptions

### Trusted
- **User Device & Secure Hardware**: Android Keystore / iOS Keychain / encrypted local storage, device memory during active use.
- **Client Application Code**: Flutter client running on user's device.

### Semi-Trusted / Untrusted
- **Cloud Backend (Vercel Serverless Functions)**: Handled as untrusted with respect to note content. Backend has zero cryptographic keys to decrypt user notes.
- **Cloud Database (Turso / libSQL)**: Stores only encrypted blobs, nonces, and metadata.
- **Identity Provider (Firebase Authentication)**: Authenticates identity, but has zero access to encryption passwords or note content.
- **Network / Transit**: HTTPS / TLS 1.3 encryption prevents eavesdropping in transit.

---

## 2. Metadata Leakage Analysis

| Data | Stored in Cloud DB | Privacy Consideration |
|---|---|---|
| Note Title | ❌ NO (Encrypted in blob) | Fully confidential |
| Note Body | ❌ NO (Encrypted in blob) | Fully confidential |
| Tags | ❌ NO (Encrypted in blob) | Fully confidential |
| Note ID | ✅ YES (UUIDv4) | Random identifier, leaks no content |
| Timestamps | ✅ YES (`createdAt`, `updatedAt`) | Necessary for sync order |
| Note Count | ✅ YES | Server knows number of notes per account |
| Approximate Size | ✅ YES (Ciphertext length) | XChaCha20 preserves plaintext size + 16-byte MAC |
| Lifecycle Flags | ✅ YES (`archived`, `trashed`, `pinned`) | Metadata for sync filtering |

---

## 3. Cryptographic Invariant Verification

- [x] Backend source code contains **zero** decryption functions or global keys.
- [x] Database schema contains **no** plaintext `title`, `body`, or `tags` columns.
- [x] Authenticated Associated Data (AAD) binds ciphertext to specific note IDs, preventing cross-note or cross-account ciphertext injection.
- [x] Nonce reuse is prevented by using 192-bit (24-byte) random nonces per XChaCha20 encryption.
- [x] Changing user encryption password re-wraps master key with fresh salt without re-encrypting notes.
- [x] Local search runs 100% offline with zero network requests.

---

## 4. Areas for Future Professional Security Audit

1. **Formal Penetration Testing**: Verification of Vercel serverless function isolation and Turso token revocation.
2. **Padding / Traffic Analysis Defense**: Adding fixed-size block padding to note payloads to obscure precise document lengths against statistical traffic analysis.
3. **Hardware Biometric Key Wrapping**: Optional local biometric gating (BiometricPrompt / LocalAuthentication) over the locally cached master key in `FlutterSecureStorage`.
