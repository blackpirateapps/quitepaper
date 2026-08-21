-- Quiet Paper Conflict Revisions & Note Index Schema (v6)

CREATE INDEX IF NOT EXISTS idx_sync_changes_user_note_rev ON sync_changes (user_id, note_id, revision);
