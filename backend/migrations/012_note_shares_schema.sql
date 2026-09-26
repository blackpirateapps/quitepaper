-- Quiet Paper Public Note Sharing — Server-Rendered Share Links (v12)
--
-- Adds opt-in public sharing of a single note as a URL (quietpaper.blackpiratex.com/note/<slug>).
-- Unlike the rest of the schema, share content is stored UNENCRYPTED (public/unlisted) so the
-- server can render it as HTML. Password-protected shares are encrypted at rest with a key
-- derived from the visitor password (scrypt + AES-256-GCM); the server decrypts in-memory only
-- to render and never stores the password. Shares auto-expire after 30 days and are cleaned up
-- by the existing garbage collector (see src/gc/garbageCollector.ts) and destruction_jobs queue.
--
-- NOTE: The authoritative runtime schema lives in src/db/migrate.ts (INITIAL_SCHEMA_SQL + the
-- idempotent ALTER/CREATE guards in runMigrations). This file documents the v12 delta.

-- 1. Public note shares
CREATE TABLE IF NOT EXISTS note_shares (
  id TEXT PRIMARY KEY,                          -- public share slug (unguessable, base62)
  user_id TEXT NOT NULL,                        -- owner (internal users.id)
  note_id TEXT NOT NULL,                         -- source note id (client UUID, owner reference)
  title TEXT NOT NULL DEFAULT '',
  content_markdown TEXT,                         -- plaintext markdown (public/unlisted); NULL for password tier
  content_ciphertext TEXT,                       -- base64 AES-256-GCM ciphertext (password tier)
  content_salt TEXT,                             -- base64 scrypt salt (password tier)
  content_iv TEXT,                               -- base64 GCM iv (password tier)
  content_tag TEXT,                              -- base64 GCM auth tag (password tier)
  visibility TEXT NOT NULL DEFAULT 'public',     -- 'public' | 'unlisted' | 'password'
  view_count INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',         -- 'active' | 'expired' | 'deleted'
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_note_shares_user ON note_shares (user_id, status);
CREATE INDEX IF NOT EXISTS idx_note_shares_note ON note_shares (user_id, note_id);
CREATE INDEX IF NOT EXISTS idx_note_shares_expiry ON note_shares (status, expires_at);

-- 2. Public (plaintext) Cloudinary copies referenced by a share, tracked so GC can destroy them
CREATE TABLE IF NOT EXISTS note_share_attachments (
  id TEXT PRIMARY KEY,
  share_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  cloud_public_id TEXT NOT NULL,
  cloud_url TEXT NOT NULL,
  resource_type TEXT NOT NULL DEFAULT 'image',   -- cloudinary resource type: 'image' | 'raw' | 'video'
  byte_size INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (share_id) REFERENCES note_shares(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_note_share_attachments_share ON note_share_attachments (share_id);
CREATE INDEX IF NOT EXISTS idx_note_share_attachments_user ON note_share_attachments (user_id);
