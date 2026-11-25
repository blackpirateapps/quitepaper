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

---

## 5. Dependency and Client-Key Alert Status (November 18, 2026)

The remaining GitHub dependency findings are remediated by Firebase Admin 14.5.1,
Zod 4.6.7 and a refreshed lockfile. Backend scripts now require Node 22 LTS 22.12+.

| GitHub alert | Package | Remediation |
| --- | --- | --- |
| #1 | uuid 9.0.1 | Removed by upgrading Firebase Admin and its Google Cloud dependencies. |
| #4, #5 | @grpc/grpc-js 1.14.4 | Resolves to 1.14.7. |
| #6 | @fastify/busboy 3.2.1 | Resolves to 3.2.6. |
| #16 | zod 3.25.76 | Resolves to 4.6.7; oversized bounded arrays fail before validating children. |
| #17 | fast-xml-parser 5.11.0 | Resolves to 5.12.1. |

Earlier critical Tinypool findings and the Vitest/Vite/source-map-js findings
were addressed by the Vitest 4.1.12 upgrade. `npm audit --omit=dev` now reports
zero vulnerabilities.

Vercel startup compatibility requires a scoped npm override:
`jwks-rsa > jose` resolves to **5.10.0**, which exports CommonJS as well as ESM.
Firebase Admin remains **14.5.1** and `jwks-rsa` remains **4.1.0**. The latter's
top-level `require('jose')` otherwise loads ESM-only jose 6 and crashes when the
runtime loader lacks `require(esm)` support. After this override, production
`npm audit --omit=dev` still reports zero vulnerabilities. Fresh-process tests
verify Firebase module loading and RSA signing-key resolution with Node's
`require(esm)` disabled; see engineering log 333. Revisit the override when
upstream supports this loader path without it.

### Remaining upstream development dependency finding

Full `npm audit` reports one underlying advisory,
[GHSA-fc5q-39xc-vjpf](https://github.com/advisories/GHSA-fc5q-39xc-vjpf), affecting
Picomatch through 4.0.7. It appears as **five high package findings** through
Picomatch, fdir, tinyglobby, Vite and Vitest. Picomatch 4.0.7 is the latest
published release and the advisory lists no patched version. The linked
[upstream PR #194](https://github.com/micromatch/picomatch/pull/194) remains open
and explicitly states that it leaves `+(*a)` exponential; it is not a complete
fix. This finding remains visible and is not dismissed or suppressed.

This dependency is part of development test tooling, not the production npm
dependency graph. Upgrade to a patched upstream release when available and
rerun the focused backend tests and full npm audit. Do not apply npm audit's
suggested Vitest 3.1.4 downgrade: it would restore the vulnerable worker/mocker
dependency chain removed by the critical-alert remediation.

### Firebase client-key finding

Secret-scanning alert #1 concerns the Firebase Authentication client API key,
not an Admin service-account private key. The repository owner explicitly
confirmed that its Google Cloud API restrictions allow only Firebase APIs.
[Firebase documents these restricted client keys as public configuration](https://firebase.google.com/docs/projects/api-keys).
The alert is resolved as `false_positive` with that evidence. No key rotation or
cloud restriction change was performed.

Removed the hardcoded Flutter fallback and redacted the two current archived
documentation copies. The original handoff backup therefore retains its text
except for this documented redaction; Git history is unchanged. The deployed
public `/api/v1/config` endpoint was verified to provide a non-empty client key
without logging its value. Flutter continues supporting that endpoint,
`--dart-define=FIREBASE_API_KEY=...` and explicit runtime configuration. If none
is available, sign-in, signup and password reset stop before sending credentials.
