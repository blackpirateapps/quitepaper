-- Migration 013: Document annotation sidecar schema for zero-knowledge,
-- crypto-blind annotation synchronization (spec §9).
--
-- Mirrors the tags schema (008): per-user rows carrying an opaque base64
-- ciphertext blob plus a monotonically assigned revision for cursor paging.
-- Keyed by (user_id, document_id, page_number) — one encrypted QPAN envelope
-- per document page. The backend never merges annotation lists; it stores and
-- returns blobs by revision (merge is client-side union-by-id + LWW).

CREATE TABLE IF NOT EXISTS document_annotations (
  user_id TEXT NOT NULL,
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  content_ciphertext TEXT NOT NULL,
  annotation_count INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  revision INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  created_by_device TEXT,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, document_id, page_number),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_doc_annotations_user_id ON document_annotations (user_id);
CREATE INDEX IF NOT EXISTS idx_doc_annotations_user_rev ON document_annotations (user_id, revision);
