-- Migration 014: place_aliases schema (spec §2.3)
--
-- REFERENCE ONLY. The runtime schema is applied from
-- backend/src/db/migrate.ts (INITIAL_SCHEMA_SQL); the files in
-- backend/migrations/*.sql are NOT executed at runtime. This file mirrors the
-- CREATE TABLE added there so the migration history stays legible.
--
-- The journal Places merge/rename/unmerge map, synced as a per-alias,
-- crypto-blind, encrypted collection modeled on `tags`. The server only ever
-- sees an opaque deterministic id (HMAC-SHA256(masterKey, "placealias:"+match
-- key)), a revision, and ciphertext — never place names, canonical keys or
-- display names. There is no pinned concept, so those columns are omitted.

CREATE TABLE IF NOT EXISTS place_aliases (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  content_ciphertext TEXT NOT NULL,
  content_nonce TEXT NOT NULL,
  content_version INTEGER NOT NULL DEFAULT 1,
  encryption_key_version INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  created_by_device TEXT,
  updated_by_device TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_place_aliases_user_id ON place_aliases (user_id);
CREATE INDEX IF NOT EXISTS idx_place_aliases_user_rev ON place_aliases (user_id, revision);
