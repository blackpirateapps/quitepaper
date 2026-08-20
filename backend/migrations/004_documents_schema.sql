-- Quiet Paper Documents Schema (v4)
-- Canonical representation for scanned multi-page PDF documents

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

CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents (user_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_rev ON documents (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_documents_note_id ON documents (note_id);
