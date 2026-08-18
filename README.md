# Quiet Paper

An offline-first, privacy-focused Markdown notes application inspired by the calm editorial aesthetic of Bear Notes, featuring zero-knowledge end-to-end encrypted cloud synchronization.

---

## Architecture Overview

- **Frontend / Client**: Flutter & Dart with Drift SQLite (local offline persistence) and Riverpod state management.
- **Backend**: TypeScript serverless functions deployed to Vercel (`backend/`).
- **Cloud Database**: Turso / libSQL SQLite-compatible distributed database.
- **Authentication**: Firebase Authentication for identity and access authorization.
- **Cryptography**: Client-side Argon2id key derivation and XChaCha20-Poly1305 AEAD authenticated encryption. The backend and cloud database are crypto-blind and never possess plaintext note content or master decryption keys.

---

## Environment Variables & Configuration

### 1. Backend Environment Variables (`backend/.env` or Vercel Dashboard)

Copy `backend/.env.example` to `backend/.env`:

```bash
cp backend/.env.example backend/.env
```

Set the following variables:

```env
# -------------------------------------------------------------
# Turso / libSQL Database
# -------------------------------------------------------------
# Obtain from https://turso.tech (CLI: turso db show <db-name> --url)
TURSO_DATABASE_URL=libsql://your-database-name.turso.io

# Obtain via: turso db tokens create <db-name>
TURSO_AUTH_TOKEN=your-turso-auth-token

# -------------------------------------------------------------
# Firebase Admin SDK Configuration
# -------------------------------------------------------------
# Obtain from Firebase Console -> Project Settings -> Service Accounts -> Generate New Private Key
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxx@your-firebase-project-id.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

# Optional: Port for local testing server
PORT=3000
```

### 2. Flutter Client Configuration (`--dart-define`)

When building or running the Flutter application, pass the Firebase Web API Key and backend sync URL via `--dart-define`:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=AIzaSy... \
  --dart-define=SYNC_API_URL=https://your-vercel-deployment.vercel.app
```

| Variable | Description | Default |
|---|---|---|
| `FIREBASE_API_KEY` | Firebase Web API Key (from Firebase Console -> Project Settings) | `""` |
| `SYNC_API_URL` | Base URL of deployed Vercel backend | `http://localhost:3000` |

---

## Development & Testing

### Backend (TypeScript)
```bash
cd backend
npm install
npm test          # Run Vitest test suite (13 unit & crypto-blindness tests)
npm run build     # Compile TypeScript
```

### Flutter Client
```bash
flutter pub get
flutter analyze   # Static analysis (0 errors/warnings)
flutter test      # Run full test suite (70 tests)
```

---

## Documentation

- [End-to-End Encryption Specification](docs/encryption.md)
- [Authentication Architecture](docs/authentication.md)
- [Cloud Sync Protocol](docs/sync-protocol.md)
- [Security Review & Threat Model](docs/security-review.md)
- [Engineering Handoff Document](HANDOFF.md)
