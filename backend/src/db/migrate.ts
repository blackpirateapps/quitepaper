import { Client } from '@libsql/client';

export const INITIAL_SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS encryption_keys (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  key_version INTEGER NOT NULL DEFAULT 1,
  wrapped_master_key TEXT NOT NULL,
  wrapped_nonce TEXT NOT NULL,
  kdf_algorithm TEXT NOT NULL,
  kdf_salt TEXT NOT NULL,
  kdf_parameters TEXT NOT NULL,
  encryption_format_version INTEGER NOT NULL DEFAULT 1,
  recovery_wrapped_master_key TEXT,
  recovery_nonce TEXT,
  recovery_salt TEXT,
  recovery_parameters TEXT,
  key_auth_commitment TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_name TEXT,
  client_version TEXT,
  last_seen_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS notes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  archived INTEGER NOT NULL DEFAULT 0,
  trashed INTEGER NOT NULL DEFAULT 0,
  pinned INTEGER NOT NULL DEFAULT 0,
  folder_id TEXT,
  sort_order REAL,
  content_ciphertext TEXT NOT NULL,
  content_nonce TEXT NOT NULL,
  content_version INTEGER NOT NULL DEFAULT 1,
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  revision INTEGER NOT NULL DEFAULT 1,
  deleted_at TEXT,
  created_by_device TEXT,
  updated_by_device TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS sync_changes (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  note_id TEXT NOT NULL,
  revision INTEGER NOT NULL,
  change_type TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS idempotency_keys (
  key TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  endpoint TEXT NOT NULL,
  response_code INTEGER NOT NULL,
  response_body TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS attachments (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  note_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  mime_type TEXT NOT NULL DEFAULT 'image/png',
  byte_size INTEGER NOT NULL DEFAULT 0,
  width INTEGER,
  height INTEGER,
  sha256 TEXT NOT NULL DEFAULT '',
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  server_revision INTEGER NOT NULL DEFAULT 1,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  cloud_public_id TEXT,
  cloud_url TEXT,
  created_device_id TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  note_id TEXT,
  title TEXT NOT NULL DEFAULT 'Scanned Document',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  mime_type TEXT NOT NULL DEFAULT 'application/pdf',
  byte_size INTEGER NOT NULL DEFAULT 0,
  page_count INTEGER NOT NULL DEFAULT 1,
  sha256 TEXT NOT NULL DEFAULT '',
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  server_revision INTEGER NOT NULL DEFAULT 1,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  cloud_public_id TEXT,
  cloud_url TEXT,
  created_device_id TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes (user_id);
CREATE INDEX IF NOT EXISTS idx_sync_changes_user_rev ON sync_changes (user_id, revision);
CREATE INDEX IF NOT EXISTS idx_idempotency_user ON idempotency_keys (user_id, key);
CREATE INDEX IF NOT EXISTS idx_encryption_keys_user ON encryption_keys (user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments (user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_rev ON attachments (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON attachments (note_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents (user_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_rev ON documents (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_documents_note_id ON documents (note_id);
`;

export async function runMigrations(db: Client): Promise<void> {
  const statements = INITIAL_SCHEMA_SQL
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0);

  for (const stmt of statements) {
    await db.execute(stmt);
  }

  // Ensure newly added columns exist on existing databases
  try {
    await db.execute('ALTER TABLE encryption_keys ADD COLUMN key_auth_commitment TEXT;');
  } catch (_) {
    // Column already exists
  }
}
