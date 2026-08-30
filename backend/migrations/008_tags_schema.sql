-- Migration 008: Tags entity schema for zero-knowledge tag synchronization

CREATE TABLE IF NOT EXISTS tags (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  content_ciphertext TEXT NOT NULL,
  content_nonce TEXT NOT NULL,
  content_version INTEGER NOT NULL DEFAULT 1,
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  is_pinned INTEGER NOT NULL DEFAULT 0,
  pinned_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  created_by_device TEXT,
  updated_by_device TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags (user_id);
CREATE INDEX IF NOT EXISTS idx_tags_user_rev ON tags (user_id, revision);
