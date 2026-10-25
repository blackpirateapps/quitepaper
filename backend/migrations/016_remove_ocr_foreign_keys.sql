-- Migration 016: Decouple OCR pages from media control tables (attachments and documents)
-- OCR text is end-to-end encrypted sidecar metadata synchronized directly over the Turso
-- control plane, independent of whether binary media files have been uploaded or confirmed.

-- 1. Recreate attachment_ocr_pages without FOREIGN KEY (attachment_id)
CREATE TABLE IF NOT EXISTS attachment_ocr_pages_new (
  user_id TEXT NOT NULL,
  attachment_id TEXT NOT NULL,
  page_number INTEGER NOT NULL DEFAULT 1,
  encrypted_payload TEXT NOT NULL,
  ocr_schema_version INTEGER NOT NULL DEFAULT 1,
  ocr_engine TEXT NOT NULL DEFAULT 'quietpaper_ocr_v1',
  ocr_engine_version TEXT NOT NULL DEFAULT '1.0.0',
  language TEXT NOT NULL DEFAULT 'en',
  processed_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  base_revision INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
  created_by_device TEXT,
  updated_by_device TEXT,
  PRIMARY KEY (user_id, attachment_id, page_number),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO attachment_ocr_pages_new
SELECT user_id, attachment_id, page_number, encrypted_payload,
       ocr_schema_version, ocr_engine, ocr_engine_version, language,
       processed_at, revision, base_revision, is_deleted, deleted_at,
       created_at, updated_at, updated_at_ms, created_by_device, updated_by_device
FROM attachment_ocr_pages;

DROP TABLE attachment_ocr_pages;
ALTER TABLE attachment_ocr_pages_new RENAME TO attachment_ocr_pages;

CREATE INDEX IF NOT EXISTS idx_att_ocr_user ON attachment_ocr_pages (user_id);
CREATE INDEX IF NOT EXISTS idx_att_ocr_att ON attachment_ocr_pages (attachment_id);
CREATE INDEX IF NOT EXISTS idx_att_ocr_user_rev ON attachment_ocr_pages (user_id, revision);

-- 2. Recreate document_ocr_pages without FOREIGN KEY (document_id)
CREATE TABLE IF NOT EXISTS document_ocr_pages_new (
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  encrypted_payload TEXT NOT NULL,
  ocr_schema_version INTEGER NOT NULL DEFAULT 1,
  ocr_engine TEXT NOT NULL DEFAULT 'quietpaper_ocr_v1',
  ocr_engine_version TEXT NOT NULL DEFAULT '1.0.0',
  language TEXT NOT NULL DEFAULT 'en',
  processed_at TEXT NOT NULL,
  revision INTEGER NOT NULL DEFAULT 1,
  base_revision INTEGER NOT NULL DEFAULT 0,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  deleted_at TEXT,
  created_at TEXT,
  updated_at TEXT,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
  created_by_device TEXT,
  updated_by_device TEXT,
  PRIMARY KEY (document_id, page_number),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

INSERT OR IGNORE INTO document_ocr_pages_new
SELECT document_id, page_number, user_id, encrypted_payload,
       ocr_schema_version, ocr_engine, ocr_engine_version, language,
       processed_at, revision, base_revision, is_deleted, deleted_at,
       created_at, updated_at, updated_at_ms, created_by_device, updated_by_device
FROM document_ocr_pages;

DROP TABLE document_ocr_pages;
ALTER TABLE document_ocr_pages_new RENAME TO document_ocr_pages;

CREATE INDEX IF NOT EXISTS idx_doc_ocr_user_rev ON document_ocr_pages (user_id, revision);
CREATE INDEX IF NOT EXISTS idx_document_ocr_doc ON document_ocr_pages (document_id);
CREATE INDEX IF NOT EXISTS idx_document_ocr_user ON document_ocr_pages (user_id);
