-- Quiet Paper Note Versions Schema (v3)

CREATE TABLE IF NOT EXISTS note_versions (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  note_id TEXT NOT NULL,
  version_number INTEGER NOT NULL,
  content_ciphertext TEXT NOT NULL,
  content_nonce TEXT NOT NULL,
  char_count INTEGER NOT NULL DEFAULT 0,
  word_count INTEGER NOT NULL DEFAULT 0,
  delta_summary TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_note_versions_user_note ON note_versions (user_id, note_id, version_number);
CREATE INDEX IF NOT EXISTS idx_note_versions_user_rev ON note_versions (user_id, revision);
