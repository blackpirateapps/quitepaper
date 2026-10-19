-- Migration 015: OCR sync and conflict tracking schema
-- Adds revision tracking to document_ocr_pages and creates attachment_ocr_pages

ALTER TABLE document_ocr_pages ADD COLUMN revision INTEGER NOT NULL DEFAULT 1;
ALTER TABLE document_ocr_pages ADD COLUMN base_revision INTEGER NOT NULL DEFAULT 0;
ALTER TABLE document_ocr_pages ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0;
ALTER TABLE document_ocr_pages ADD COLUMN deleted_at TEXT;
ALTER TABLE document_ocr_pages ADD COLUMN updated_at TEXT;
ALTER TABLE document_ocr_pages ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0;
ALTER TABLE document_ocr_pages ADD COLUMN created_by_device TEXT;
ALTER TABLE document_ocr_pages ADD COLUMN updated_by_device TEXT;

CREATE INDEX IF NOT EXISTS idx_doc_ocr_user_rev ON document_ocr_pages (user_id, revision);

CREATE TABLE IF NOT EXISTS attachment_ocr_pages (
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
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (attachment_id) REFERENCES attachments(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_att_ocr_user ON attachment_ocr_pages (user_id);
CREATE INDEX IF NOT EXISTS idx_att_ocr_att ON attachment_ocr_pages (attachment_id);
CREATE INDEX IF NOT EXISTS idx_att_ocr_user_rev ON attachment_ocr_pages (user_id, revision);
