-- Generated from AppDatabase by test/cli/schema_contract_test.dart.
-- Regenerate with QP_EXPORT_CLI_SCHEMA=1 flutter test test/cli/schema_contract_test.dart
CREATE TABLE "attachment_ocr_pages" ("attachment_id" TEXT NOT NULL, "page_number" INTEGER NOT NULL DEFAULT 1, "encrypted_payload" TEXT NOT NULL, "ocr_schema_version" INTEGER NOT NULL DEFAULT 1, "ocr_engine" TEXT NOT NULL DEFAULT 'quietpaper_ocr_v1', "ocr_engine_version" TEXT NOT NULL DEFAULT '1.0.0', "language" TEXT NOT NULL DEFAULT 'en', "processed_at" INTEGER NOT NULL, "revision" INTEGER NOT NULL DEFAULT 0, "base_revision" INTEGER NOT NULL DEFAULT 0, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NULL, PRIMARY KEY ("attachment_id", "page_number"));

CREATE TABLE "attachment_variants" ("id" TEXT NOT NULL, "attachment_id" TEXT NOT NULL, "variant_type" TEXT NOT NULL, "byte_size" INTEGER NOT NULL DEFAULT 0, "width" INTEGER NULL, "height" INTEGER NULL, "local_path" TEXT NULL, "cloud_public_id" TEXT NULL, "cloud_url" TEXT NULL, "created_at" INTEGER NOT NULL, PRIMARY KEY ("id"));

CREATE TABLE "attachments" ("id" TEXT NOT NULL, "note_id" TEXT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "file_name" TEXT NOT NULL DEFAULT 'attachment', "kind" TEXT NOT NULL DEFAULT 'image', "mime_type" TEXT NOT NULL DEFAULT 'image/png', "byte_size" INTEGER NOT NULL DEFAULT 0, "width" INTEGER NULL, "height" INTEGER NULL, "sha256" TEXT NOT NULL DEFAULT '', "encryption_key_version" INTEGER NOT NULL DEFAULT 1, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "deleted_at" INTEGER NULL, "server_revision" INTEGER NOT NULL DEFAULT 0, "synced_at" INTEGER NULL, "upload_state" TEXT NOT NULL DEFAULT 'local_only', "cloud_public_id" TEXT NULL, "cloud_url" TEXT NULL, "local_path" TEXT NULL, "ocr_state" TEXT NOT NULL DEFAULT 'not_requested', "ocr_language" TEXT NOT NULL DEFAULT 'en', PRIMARY KEY ("id"));

CREATE TABLE "document_annotations" ("document_id" TEXT NOT NULL, "page_number" INTEGER NOT NULL, "encrypted_payload" TEXT NOT NULL, "annotation_count" INTEGER NOT NULL DEFAULT 0, "revision" INTEGER NOT NULL DEFAULT 0, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "updated_at" INTEGER NOT NULL, PRIMARY KEY ("document_id", "page_number"));

CREATE TABLE "document_ocr_pages" ("document_id" TEXT NOT NULL, "page_number" INTEGER NOT NULL, "encrypted_payload" TEXT NOT NULL, "ocr_schema_version" INTEGER NOT NULL DEFAULT 1, "ocr_engine" TEXT NOT NULL DEFAULT 'quietpaper_ocr_v1', "ocr_engine_version" TEXT NOT NULL DEFAULT '1.0.0', "language" TEXT NOT NULL DEFAULT 'en', "processed_at" INTEGER NOT NULL, "revision" INTEGER NOT NULL DEFAULT 0, "base_revision" INTEGER NOT NULL DEFAULT 0, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "updated_at" INTEGER NULL, PRIMARY KEY ("document_id", "page_number"));

CREATE TABLE "documents" ("id" TEXT NOT NULL, "note_id" TEXT NULL, "title" TEXT NOT NULL DEFAULT 'Scanned Document', "source" TEXT NOT NULL DEFAULT 'scanner', "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "mime_type" TEXT NOT NULL DEFAULT 'application/pdf', "byte_size" INTEGER NOT NULL DEFAULT 0, "page_count" INTEGER NOT NULL DEFAULT 1, "sha256" TEXT NOT NULL DEFAULT '', "encryption_key_version" INTEGER NOT NULL DEFAULT 1, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "deleted_at" INTEGER NULL, "server_revision" INTEGER NOT NULL DEFAULT 0, "synced_at" INTEGER NULL, "upload_state" TEXT NOT NULL DEFAULT 'local_only', "cloud_public_id" TEXT NULL, "cloud_url" TEXT NULL, "local_path" TEXT NULL, "thumbnail_path" TEXT NULL, "ocr_state" TEXT NOT NULL DEFAULT 'not_requested', "ocr_language" TEXT NOT NULL DEFAULT 'en', PRIMARY KEY ("id"));

CREATE TABLE email_import_preparations (asset_id TEXT PRIMARY KEY);

CREATE TABLE note_import_source_index (note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE, identity TEXT NOT NULL, raw_hash TEXT, fingerprint TEXT NOT NULL, message_id TEXT, PRIMARY KEY(note_id, identity));

CREATE TABLE "note_links" ("id" TEXT NOT NULL, "source_note_id" TEXT NOT NULL REFERENCES notes (id) ON DELETE CASCADE, "target_note_id" TEXT NOT NULL, "display_text" TEXT NOT NULL, "source_offset" INTEGER NOT NULL, "created_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), "updated_at" INTEGER NOT NULL DEFAULT (CAST(strftime('%s', CURRENT_TIMESTAMP) AS INTEGER)), PRIMARY KEY ("id"));

CREATE VIRTUAL TABLE note_search_prefix USING fts5(
            note_id UNINDEXED,
            title,
            body_text,
            tags,
            tokenize = 'unicode61 remove_diacritics 2'
        );

CREATE VIRTUAL TABLE note_search_trigram USING fts5(
            note_id UNINDEXED,
            title,
            body_text,
            tags,
            tokenize = 'trigram'
        );

CREATE TABLE "note_tags" ("note_id" TEXT NOT NULL REFERENCES notes (id) ON DELETE CASCADE, "tag_id" TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE, "is_pinned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_pinned" IN (0, 1)), PRIMARY KEY ("note_id", "tag_id"));

CREATE TABLE "note_templates" ("id" TEXT NOT NULL, "display_name" TEXT NOT NULL, "content" TEXT NOT NULL, "storage_format" TEXT NOT NULL, "default_tags_json" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "schema_version" INTEGER NOT NULL DEFAULT 1, PRIMARY KEY ("id"));

CREATE TABLE "note_versions" ("id" TEXT NOT NULL, "note_id" TEXT NOT NULL REFERENCES notes (id) ON DELETE CASCADE, "version_number" INTEGER NOT NULL, "title" TEXT NOT NULL DEFAULT '', "content" TEXT NOT NULL DEFAULT '', "tags_json" TEXT NOT NULL DEFAULT '[]', "created_at" INTEGER NOT NULL, "char_count" INTEGER NOT NULL DEFAULT 0, "word_count" INTEGER NOT NULL DEFAULT 0, "delta_summary" TEXT NULL, "server_revision" INTEGER NOT NULL DEFAULT 0, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "synced_at" INTEGER NULL, "base_revision" INTEGER NULL, "local_parent_revision" INTEGER NULL, "remote_parent_revision" INTEGER NULL, "merge_type" TEXT NULL, "resolution_summary" TEXT NULL, PRIMARY KEY ("id"));

CREATE TABLE "notes" ("id" TEXT NOT NULL, "title" TEXT NOT NULL DEFAULT '', "content" TEXT NOT NULL DEFAULT '', "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "is_pinned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_pinned" IN (0, 1)), "is_archived" INTEGER NOT NULL DEFAULT 0 CHECK ("is_archived" IN (0, 1)), "is_trashed" INTEGER NOT NULL DEFAULT 0 CHECK ("is_trashed" IN (0, 1)), "deleted_at" INTEGER NULL, "server_revision" INTEGER NOT NULL DEFAULT 0, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "synced_at" INTEGER NULL, "journal_date" TEXT NULL, "share_id" TEXT NULL, "share_url" TEXT NULL, "import_sources" TEXT NOT NULL DEFAULT '[]', "pinned_tags" TEXT NULL, PRIMARY KEY ("id"));

CREATE TABLE "place_aliases" ("id" TEXT NOT NULL, "content_ciphertext" TEXT NOT NULL DEFAULT '', "content_nonce" TEXT NOT NULL DEFAULT '', "content_version" INTEGER NOT NULL DEFAULT 1, "encryption_key_version" INTEGER NOT NULL DEFAULT 1, "created_at" INTEGER NULL, "updated_at" INTEGER NULL, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "server_revision" INTEGER NOT NULL DEFAULT 0, "synced_at" INTEGER NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "deleted_at" INTEGER NULL, PRIMARY KEY ("id"));

CREATE TABLE "quick_capture_drafts" ("id" TEXT NOT NULL, "target_note_id" TEXT NOT NULL, "content" TEXT NOT NULL, "source" TEXT NOT NULL DEFAULT 'widget', "source_url" TEXT NULL, "title_hint" TEXT NULL, "cursor_position" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("id"));

CREATE TABLE "sync_conflicts" ("id" TEXT NOT NULL, "note_id" TEXT NOT NULL REFERENCES notes (id) ON DELETE CASCADE, "base_revision" INTEGER NOT NULL DEFAULT 0, "local_revision" INTEGER NOT NULL DEFAULT 0, "remote_revision" INTEGER NOT NULL DEFAULT 0, "conflict_type" TEXT NOT NULL DEFAULT 'content', "state" TEXT NOT NULL DEFAULT 'detected', "created_at" INTEGER NOT NULL, "resolved_at" INTEGER NULL, "resolution_revision" INTEGER NULL, "resolution_type" TEXT NULL, "data_json" TEXT NOT NULL DEFAULT '{}', PRIMARY KEY ("id"));

CREATE TABLE "sync_metadata" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, "updated_at" INTEGER NOT NULL, PRIMARY KEY ("key"));

CREATE TABLE "sync_queue" ("id" TEXT NOT NULL, "note_id" TEXT NOT NULL, "operation" TEXT NOT NULL, "created_at" INTEGER NOT NULL, "attempts" INTEGER NOT NULL DEFAULT 0, "last_error" TEXT NULL, PRIMARY KEY ("id"));

CREATE TABLE "tags" ("id" TEXT NOT NULL, "name" TEXT NOT NULL UNIQUE, "icon" TEXT NULL, "color" TEXT NULL, "is_pinned" INTEGER NOT NULL DEFAULT 0 CHECK ("is_pinned" IN (0, 1)), "pinned_order" INTEGER NOT NULL DEFAULT 0, "created_at" INTEGER NULL, "updated_at" INTEGER NULL, "is_dirty" INTEGER NOT NULL DEFAULT 1 CHECK ("is_dirty" IN (0, 1)), "server_revision" INTEGER NOT NULL DEFAULT 0, "synced_at" INTEGER NULL, "is_deleted" INTEGER NOT NULL DEFAULT 0 CHECK ("is_deleted" IN (0, 1)), "deleted_at" INTEGER NULL, PRIMARY KEY ("id"));

CREATE TABLE task_dirty (note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE);

CREATE TABLE task_index (
    note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL, task_id TEXT, version TEXT NOT NULL,
    text TEXT NOT NULL, heading TEXT, note_title TEXT NOT NULL, completed INTEGER NOT NULL,
    due TEXT, search_text TEXT NOT NULL,
    PRIMARY KEY(note_id,ordinal));

CREATE TABLE task_index_failures (note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE);

CREATE TABLE "template_favorites" ("template_id" TEXT NOT NULL, PRIMARY KEY ("template_id"));

CREATE TABLE watched_folders (
    id TEXT PRIMARY KEY, canonical_root TEXT NOT NULL, root_identity TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    vault_scope TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,
    file_types TEXT NOT NULL DEFAULT '["email","pdf","markdown","text","png","jpeg","webp"]',
    include_subfolders INTEGER NOT NULL DEFAULT 1 CHECK(include_subfolders=1),
    skip_duplicates INTEGER NOT NULL DEFAULT 1 CHECK(skip_duplicates=1),
    existing_policy TEXT NOT NULL DEFAULT 'ask', review_state TEXT NOT NULL DEFAULT 'pending',
    inventory_complete INTEGER NOT NULL DEFAULT 0, inventory_error TEXT,
    decision_generation TEXT NOT NULL, decision_time INTEGER,
    health TEXT NOT NULL DEFAULT 'Scanning', last_reconcile INTEGER,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL);

CREATE TABLE watched_import_baseline (
    folder_id TEXT NOT NULL, source_path BLOB NOT NULL, revision TEXT NOT NULL,
    sha256 TEXT NOT NULL, size INTEGER NOT NULL, captured_at INTEGER NOT NULL,
    decision_generation TEXT NOT NULL, PRIMARY KEY(folder_id,source_path,revision));

CREATE TABLE watched_import_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT, vault_scope TEXT NOT NULL,
    job_id TEXT NOT NULL, type TEXT NOT NULL, display_name TEXT NOT NULL,
    format TEXT NOT NULL, error_code TEXT, note_id TEXT, time INTEGER NOT NULL);

CREATE TABLE watched_import_jobs (
    id TEXT PRIMARY KEY, folder_id TEXT NOT NULL, vault_scope TEXT NOT NULL,
    source_path BLOB NOT NULL, source_root TEXT NOT NULL DEFAULT '', display_name TEXT NOT NULL, revision TEXT NOT NULL,
    size INTEGER NOT NULL, sha256 TEXT NOT NULL, format TEXT NOT NULL,
    status TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0,
    next_retry INTEGER, planned_note_id TEXT NOT NULL, generation INTEGER NOT NULL,
    last_error TEXT, override_id TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
    UNIQUE(folder_id, source_path, revision, override_id));

CREATE TABLE watched_import_receipts (
    vault_scope TEXT NOT NULL, sha256 TEXT NOT NULL, size INTEGER NOT NULL,
    override_id TEXT NOT NULL DEFAULT '', note_id TEXT NOT NULL,
    folder_id TEXT NOT NULL, source_root TEXT NOT NULL DEFAULT '', source_path BLOB NOT NULL DEFAULT X'', display_name TEXT NOT NULL, committed_at INTEGER NOT NULL,
    format_version INTEGER NOT NULL DEFAULT 1, message_id TEXT,
    PRIMARY KEY(vault_scope,sha256,size,override_id));

CREATE TABLE watched_import_stages (
    asset_id TEXT PRIMARY KEY, kind TEXT NOT NULL, job_id TEXT NOT NULL);

CREATE INDEX attachment_ocr_att_idx ON attachment_ocr_pages (attachment_id);

CREATE INDEX attachment_ocr_dirty_idx ON attachment_ocr_pages (is_dirty);

CREATE INDEX attachment_variants_att_idx ON attachment_variants (attachment_id);

CREATE INDEX attachments_dirty_idx ON attachments (is_dirty);

CREATE INDEX attachments_kind_idx ON attachments (kind);

CREATE INDEX attachments_note_idx ON attachments (note_id);

CREATE INDEX attachments_upload_state_idx ON attachments (upload_state);

CREATE INDEX document_annotations_dirty_idx ON document_annotations (is_dirty);

CREATE INDEX document_annotations_doc_idx ON document_annotations (document_id);

CREATE INDEX document_ocr_dirty_idx ON document_ocr_pages (is_dirty);

CREATE INDEX document_ocr_doc_idx ON document_ocr_pages (document_id);

CREATE INDEX documents_dirty_idx ON documents (is_dirty);

CREATE INDEX documents_note_idx ON documents (note_id);

CREATE INDEX documents_upload_state_idx ON documents (upload_state);

CREATE INDEX email_source_fingerprint_idx ON note_import_source_index (fingerprint);

CREATE INDEX email_source_message_id_idx ON note_import_source_index (message_id);

CREATE INDEX email_source_raw_hash_idx ON note_import_source_index (raw_hash);

CREATE INDEX note_links_source_idx ON note_links (source_note_id);

CREATE INDEX note_links_target_idx ON note_links (target_note_id);

CREATE INDEX note_links_target_source_idx ON note_links (target_note_id, source_note_id);

CREATE INDEX note_tags_pinned_idx ON note_tags (note_id, is_pinned);

CREATE INDEX note_tags_tag_idx ON note_tags (tag_id, note_id);

CREATE INDEX note_versions_dirty_idx ON note_versions (is_dirty);

CREATE INDEX note_versions_note_idx ON note_versions (note_id, version_number DESC);

CREATE INDEX notes_deleted_idx ON notes (is_trashed, deleted_at);

CREATE INDEX notes_dirty_idx ON notes (is_dirty);

CREATE INDEX notes_journal_date_lookup_idx ON notes (journal_date);

CREATE UNIQUE INDEX notes_journal_date_unique_idx ON notes (journal_date) WHERE journal_date IS NOT NULL;

CREATE INDEX notes_lifecycle_idx ON notes (is_archived, is_trashed, is_pinned, updated_at);

CREATE INDEX quick_capture_drafts_updated_idx ON quick_capture_drafts (updated_at DESC);

CREATE INDEX sync_conflicts_note_idx ON sync_conflicts (note_id, state);

CREATE INDEX sync_conflicts_state_idx ON sync_conflicts (state);

CREATE INDEX tags_dirty_idx ON tags (is_dirty);

CREATE INDEX tags_name_idx ON tags (name);

CREATE INDEX tags_pinned_idx ON tags (is_pinned, pinned_order);

CREATE INDEX task_identity ON task_index(note_id,task_id);

CREATE INDEX task_status_date ON task_index(completed,due,note_id,ordinal);

CREATE INDEX watched_active_jobs ON watched_import_jobs (vault_scope,status,next_retry);

CREATE INDEX watched_baseline_content ON watched_import_baseline(folder_id,sha256,size);

CREATE UNIQUE INDEX watched_folder_root ON watched_folders (vault_scope,canonical_root);

CREATE INDEX watched_message_ids ON watched_import_receipts(vault_scope,message_id);

CREATE TRIGGER task_note_delete AFTER DELETE ON notes BEGIN
    DELETE FROM task_index WHERE note_id=old.id;
    DELETE FROM task_dirty WHERE note_id=old.id;
    DELETE FROM task_index_failures WHERE note_id=old.id; END;

CREATE TRIGGER task_note_insert AFTER INSERT ON notes BEGIN
    INSERT INTO task_dirty(note_id) VALUES(new.id) ON CONFLICT(note_id) DO NOTHING; END;

CREATE TRIGGER task_note_update AFTER UPDATE OF content,is_archived,is_trashed,deleted_at ON notes BEGIN
    INSERT INTO task_dirty(note_id) VALUES(new.id) ON CONFLICT(note_id) DO NOTHING;
    DELETE FROM task_index WHERE note_id=new.id AND
      (new.is_archived=1 OR new.is_trashed=1 OR new.deleted_at IS NOT NULL OR ltrim(new.content) LIKE '<!-- quiet-paper-encrypted-note-v1:%'); END;

CREATE TRIGGER trg_notes_fts_delete AFTER DELETE ON notes
        BEGIN
          DELETE FROM note_search_prefix WHERE note_id = old.id;
          DELETE FROM note_search_trigram WHERE note_id = old.id;
        END;

PRAGMA user_version = 26;
