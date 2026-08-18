# Quiet Paper — Authentication Architecture

Quiet Paper uses Firebase Authentication strictly for **account identity and access authorization**, maintaining an absolute separation from note encryption.

---

## 1. Authentication vs Encryption Separation

| Domain | Firebase Authentication | Quiet Paper Encryption |
|---|---|---|
| **Question** | "Who is this user?" | "Can this user decrypt their notes?" |
| **Credential** | Firebase Account Password / Provider | Quiet Paper Encryption Password |
| **Server Knowledge** | Firebase verifies user identity | Zero-knowledge (Server never sees keys) |
| **Password Reset** | Firebase sends email reset link | Firebase reset **CANNOT** decrypt notes |
| **Key Derivation** | Never used for note encryption | Argon2id derives key to unwrap master key |

---

## 2. Authentication Flow

```text
Flutter Client                              Vercel Backend                     Firebase Admin SDK
      │                                            │                                  │
      │── 1. Sign in (Email/Password) ────────────►│                                  │
      │   (Receives Firebase ID Token)             │                                  │
      │                                            │                                  │
      │── 2. Request with Bearer <ID Token> ──────►│                                  │
      │                                            │── 3. verifyIdToken(token) ──────►│
      │                                            │◄─ 4. Valid UID returned ─────────│
      │                                            │                                  │
      │                                            │── 5. Scope DB to verified UID    │
      │◄─ 6. Return authorized response ───────────│
```

---

## 3. Server-Side Token Verification

All protected backend endpoints (`/api/v1/...`) enforce the `requireFirebaseAuth()` middleware:
- Extracts `Authorization: Bearer <token>`.
- Calls Firebase Admin SDK `verifyIdToken(token, true)`.
- Validates signature, issuer, audience, and expiration.
- Resolves the stable external `firebase_uid`.
- Derives internal canonical user ID from the `users` table:
  ```sql
  SELECT id FROM users WHERE firebase_uid = ?
  ```
- **Never trusts client-supplied user IDs in request bodies.**
