# Quiet Paper — Sync, Cryptography & Storage Architecture

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Zero-Knowledge Cryptography & Key Management

Quiet Paper is built around a zero-knowledge, end-to-end encrypted architecture. Plaintext notes, titles, tags, and document contents never leave the user's device unencrypted. The cloud backend and database are crypto-blind and operate purely on opaque ciphertext envelopes.

### Cryptographic Primitives
- **Key Derivation (KDF)**: `Argon2id`
  - Parameters: 19MB memory limit, 2 iterations, 16-byte cryptographically secure salt.
  - Derived from the user's Master Passphrase.
- **Authenticated Encryption (AEAD)**: `XChaCha20-Poly1305`
  - 256-bit encryption key, 192-bit (24-byte) random nonce per encryption envelope.
  - Provides authenticated integrity (tamper-proofing).
- **Master Key Envelope**:
  - The Master Encryption Key is generated randomly on the device.
  - Stored encrypted in `FlutterSecureStorage` (or Linux fallback).
  - Can be wrapped by the user's passphrase and synced to the cloud key vault for recovery on secondary devices.

### Key Lifecycle & Platform Resiliency
- Key management is handled by [`KeyManager`](file:///home/dog/git/quitepaper/lib/core/crypto/key_manager.dart) and [`CryptoService`](file:///home/dog/git/quitepaper/lib/core/crypto/crypto_service.dart).
- **Linux Fallback**: Linux desktop environments without an active SecretService daemon or KDE Wallet utilize an encrypted local fallback mechanism ([`LinuxSecureStorageFallback`](file:///home/dog/git/quitepaper/lib/core/crypto/key_manager.dart)) to prevent runtime crashes during startup.
- **Session Persistence**: Authentication session tokens and cryptographic master keys persist across app cold starts, background termination, and software updates.

---

## 2. Local Database & Persistence

The local persistence layer is powered by **SQLite** using **Drift** in offline-first mode.

### Schema & Tables (`lib/core/database/tables/`)
- [`NotesTable`](file:///home/dog/git/quitepaper/lib/core/database/tables/notes_table.dart):
  - Primary store for notes (`id`, `title`, `body`, `folder`, `is_pinned`, `is_archived`, `is_trashed`, `created_at`, `updated_at`, `synced_at`, `revision`, `dirty`).
  - Contains format indicator (`storage_format`: markdown vs. rich_ast).
- [`TagsTable`](file:///home/dog/git/quitepaper/lib/core/database/tables/tags_table.dart) & [`NoteTagsTable`](file:///home/dog/git/quitepaper/lib/core/database/tables/note_tags_table.dart):
  - Normalised tag relations with deterministic IDs for cross-device tag synchronization.
- [`SyncQueueTable`](file:///home/dog/git/quitepaper/lib/core/database/tables/sync_queue_table.dart):
  - Offline mutation queue storing pending creations, updates, and deletion tombstones while offline.
- [`SyncMetadataTable`](file:///home/dog/git/quitepaper/lib/core/database/tables/sync_metadata_table.dart):
  - Key-value metadata store tracking server sync cursors, device UUID, and last sync timestamps.

### Database Migrations
- Schema upgrades are managed in [`AppDatabase`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart).
- Migrations are defensive and idempotent (e.g. `duplicate column name: source` defensive alter queries).
- Startup analysis of local attachments is deferred to avoid freezing application launch.

---

## 3. Cloud Backend & Sync Protocol

### Serverless Backend (`backend/`)
- **Runtime**: TypeScript on Vercel Serverless Functions.
- **Database**: Turso (distributed libSQL / SQLite edge database).
- **Auth Verification**: Firebase Admin SDK (`requireFirebaseAuth` middleware).
- **Crypto-Blind Guarantee**: The backend database schema contains only opaque binary payloads (`ciphertext`, `nonce`, `salt`, `revision`, `device_id`). The backend has zero decryption keys, zero plaintext inspection logic, and no access to note contents.

### Synchronization Engine (`lib/core/sync/`)
- [`SyncEngine`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart): Coordinates synchronization between local SQLite and Turso.
  - Debounced autosync (triggers on note saves, app focus, or manual pull-to-refresh).
  - Mutex protection prevents race conditions between paginated note updates and incoming sync payloads.
- **3-Way Conflict Merge Pipeline**:
  - When concurrent edits occur across devices on the same revision, the sync engine applies a 3-way merge on note contents.
  - Deterministic conflict resolution preserves user data and avoids data loss.
- **Batch Chunking & Cursor Pagination**:
  - Large payloads and multiple changes are chunked into bounded batches.
  - Cursor-based pagination ensures incremental sync and handles fresh-device bootstrapping gracefully.
- **Resilient Auth & Token Refresh**:
  - Automatically intercepts HTTP 401 and refreshes Firebase ID tokens before retrying.
  - Structured error handling extracts server status codes and prevents infinite retry loops.

---

## 4. Local Backup & Scoped Storage

- **Auto-Backups**: Rolling automated backups stored on local storage (`lib/core/backup/`).
- **Scoped Storage Safe Export**: Uses Android Scoped Storage compliant APIs and desktop file pickers for clean `.qpbackup` JSON export and restoration.
- **Full Encryption**: Backups are encrypted with AES-GCM or XChaCha20, requiring the master passphrase to unpack.

---

## Key References & Logs
- Detailed sync push tombstone validation: [Historical Logs v1.0–v1.4, Section 12](archive/logs-v1.0-v1.4.md#12-sync-push-deletion-tombstone-validation--new-device-sync-fix)
- 3-Way merge engine specification: [Historical Logs v1.5, Section 59](archive/logs-v1.5.md#59-production-grade-conflict-aware-cloud-sync--3-way-merge-engine)
- Fresh device sync recovery: [Latest Logs, Section 237](latest-logs.md#237-note-reconciliation--pruned-sync-log-recovery-on-fresh-devices-october-2026)
- Foreign key sync race fix: [Latest Logs, Section 235](latest-logs.md#235-fix-zero-knowledge-ocr-sync-foreign-key-constraint-failure-and-defensive-note-pull-pagination-october-2026)
