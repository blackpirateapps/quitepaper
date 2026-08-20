-- Quiet Paper OCR & Document Source Schema (v5)
-- Adds document source, OCR processing lifecycle state, language, and encrypted OCR pages

ALTER TABLE documents ADD COLUMN source TEXT NOT NULL DEFAULT 'scanner';
ALTER TABLE documents ADD COLUMN ocr_state TEXT NOT NULL DEFAULT 'not_requested';
ALTER TABLE documents ADD COLUMN ocr_language TEXT NOT NULL DEFAULT 'en';

CREATE TABLE IF NOT EXISTS document_ocr_pages (
  document_id TEXT NOT NULL,
  page_number INTEGER NOT NULL,
  user_id TEXT NOT NULL,
  encrypted_payload TEXT NOT NULL,
  ocr_schema_version INTEGER NOT NULL DEFAULT 1,
  ocr_engine TEXT NOT NULL DEFAULT 'quietpaper_ocr_v1',
  ocr_engine_version TEXT NOT NULL DEFAULT '1.0.0',
  language TEXT NOT NULL DEFAULT 'en',
  processed_at TEXT NOT NULL,
  PRIMARY KEY (document_id, page_number),
  FOREIGN KEY (document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_document_ocr_doc ON document_ocr_pages (document_id);
CREATE INDEX IF NOT EXISTS idx_document_ocr_user ON document_ocr_pages (user_id);
