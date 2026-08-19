-- Quiet Paper Attachments Schema (v2)

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

CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments (user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_rev ON attachments (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON attachments (note_id);
