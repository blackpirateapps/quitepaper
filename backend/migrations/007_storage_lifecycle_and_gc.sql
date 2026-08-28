-- Quiet Paper Cloud Storage Lifecycle, Device Checkpoints, Reference Projections & Destruction Jobs (v7)

-- 1. Sync Devices table for tracking active device checkpoints
CREATE TABLE IF NOT EXISTS sync_devices (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  device_name TEXT,
  client_version TEXT,
  last_acknowledged_revision INTEGER NOT NULL DEFAULT 0,
  last_seen_at TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sync_devices_user ON sync_devices (user_id, last_seen_at);

-- 2. Attachment References table for crypto-blind client reference projections
CREATE TABLE IF NOT EXISTS attachment_references (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  resource_type TEXT NOT NULL, -- 'attachment' | 'document'
  resource_id TEXT NOT NULL,
  note_id TEXT NOT NULL,
  last_confirmed_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_attachment_refs_unique ON attachment_references (user_id, resource_type, resource_id, note_id);
CREATE INDEX IF NOT EXISTS idx_attachment_refs_res ON attachment_references (user_id, resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_attachment_refs_note ON attachment_references (user_id, note_id);

-- 3. Destruction Jobs table for durable, retryable external Cloudinary and DB deletions
CREATE TABLE IF NOT EXISTS destruction_jobs (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  resource_type TEXT NOT NULL, -- 'attachment' | 'document' | 'note'
  resource_id TEXT NOT NULL,
  cloudinary_public_id TEXT,
  operation TEXT NOT NULL, -- 'delete_cloudinary' | 'delete_document' | 'delete_attachment'
  state TEXT NOT NULL DEFAULT 'pending', -- 'pending' | 'processing' | 'retrying' | 'completed' | 'failed'
  attempt_count INTEGER NOT NULL DEFAULT 0,
  available_at TEXT NOT NULL,
  last_error TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_destruction_jobs_user_state ON destruction_jobs (user_id, state, available_at);

-- 4. Additional status columns for attachments and documents
ALTER TABLE attachments ADD COLUMN status TEXT NOT NULL DEFAULT 'referenced';
ALTER TABLE attachments ADD COLUMN orphaned_at TEXT;

ALTER TABLE documents ADD COLUMN status TEXT NOT NULL DEFAULT 'referenced';
ALTER TABLE documents ADD COLUMN orphaned_at TEXT;
