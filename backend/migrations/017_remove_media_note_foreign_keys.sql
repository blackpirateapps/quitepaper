-- Migration 017: Decouple media tables (attachments and documents) from notes foreign key
-- In offline-first sync architectures, media files can be uploaded and confirmed ahead of,
-- concurrently with, or independently of note record synchronization.
-- Foreign keys referencing notes(id) cause SQLITE_CONSTRAINT failures on out-of-order confirmation.
-- Relational bindings and lifecycle/garbage collection are tracked via attachment_references.

-- 1. Recreate attachments table without FOREIGN KEY (note_id) REFERENCES notes(id)
CREATE TABLE IF NOT EXISTS attachments_new (
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
  file_name TEXT NOT NULL DEFAULT 'attachment',
  kind TEXT NOT NULL DEFAULT 'image',
  created_device_id TEXT,
  status TEXT NOT NULL DEFAULT 'referenced',
  orphaned_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO attachments_new
SELECT id, user_id, note_id, created_at, updated_at, mime_type,
       byte_size, width, height, sha256, encryption_key_version,
       server_revision, is_deleted, deleted_at, cloud_public_id,
       cloud_url, file_name, kind, created_device_id, status, orphaned_at
FROM attachments;

DROP TABLE attachments;
ALTER TABLE attachments_new RENAME TO attachments;

CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON attachments (user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_rev ON attachments (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON attachments (note_id);

-- 2. Recreate documents table without FOREIGN KEY (note_id) REFERENCES notes(id)
CREATE TABLE IF NOT EXISTS documents_new (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  note_id TEXT,
  title TEXT NOT NULL DEFAULT 'Scanned Document',
  source TEXT NOT NULL DEFAULT 'scanner',
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
  ocr_state TEXT NOT NULL DEFAULT 'not_requested',
  ocr_language TEXT NOT NULL DEFAULT 'en',
  created_device_id TEXT,
  status TEXT NOT NULL DEFAULT 'referenced',
  orphaned_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO documents_new
SELECT id, user_id, note_id, title, source, created_at, updated_at,
       mime_type, byte_size, page_count, sha256, encryption_key_version,
       server_revision, is_deleted, deleted_at, cloud_public_id,
       cloud_url, ocr_state, ocr_language, created_device_id, status, orphaned_at
FROM documents;

DROP TABLE documents;
ALTER TABLE documents_new RENAME TO documents;

CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents (user_id);
CREATE INDEX IF NOT EXISTS idx_documents_user_rev ON documents (user_id, server_revision);
CREATE INDEX IF NOT EXISTS idx_documents_note_id ON documents (note_id);
