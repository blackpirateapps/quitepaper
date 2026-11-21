/// Installation-local watcher state. Deliberately excluded from sync/backup.
/// Receipts have no note FK: deleting a note must not resurrect its source.
const watchedImportSchema = <String>[
  '''CREATE TABLE IF NOT EXISTS watched_folders (
    id TEXT PRIMARY KEY, canonical_root TEXT NOT NULL, root_identity TEXT NOT NULL,
    vault_scope TEXT NOT NULL, enabled INTEGER NOT NULL DEFAULT 1,
    include_subfolders INTEGER NOT NULL DEFAULT 1 CHECK(include_subfolders=1),
    skip_duplicates INTEGER NOT NULL DEFAULT 1 CHECK(skip_duplicates=1),
    existing_policy TEXT NOT NULL DEFAULT 'ask', review_state TEXT NOT NULL DEFAULT 'pending',
    inventory_complete INTEGER NOT NULL DEFAULT 0, inventory_error TEXT,
    decision_generation TEXT NOT NULL, decision_time INTEGER,
    health TEXT NOT NULL DEFAULT 'Scanning', last_reconcile INTEGER,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)''',
  'CREATE UNIQUE INDEX IF NOT EXISTS watched_single_root ON watched_folders ((1))',
  '''CREATE TABLE IF NOT EXISTS watched_import_jobs (
    id TEXT PRIMARY KEY, folder_id TEXT NOT NULL, vault_scope TEXT NOT NULL,
    source_path BLOB NOT NULL, source_root TEXT NOT NULL DEFAULT '', display_name TEXT NOT NULL, revision TEXT NOT NULL,
    size INTEGER NOT NULL, sha256 TEXT NOT NULL, format TEXT NOT NULL,
    status TEXT NOT NULL, attempt_count INTEGER NOT NULL DEFAULT 0,
    next_retry INTEGER, planned_note_id TEXT NOT NULL, generation INTEGER NOT NULL,
    last_error TEXT, override_id TEXT NOT NULL DEFAULT '',
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
    UNIQUE(folder_id, source_path, revision, override_id))''',
  'CREATE INDEX IF NOT EXISTS watched_active_jobs ON watched_import_jobs (vault_scope,status,next_retry)',
  '''CREATE TABLE IF NOT EXISTS watched_import_receipts (
    vault_scope TEXT NOT NULL, sha256 TEXT NOT NULL, size INTEGER NOT NULL,
    override_id TEXT NOT NULL DEFAULT '', note_id TEXT NOT NULL,
    folder_id TEXT NOT NULL, source_root TEXT NOT NULL DEFAULT '', source_path BLOB NOT NULL DEFAULT X'', display_name TEXT NOT NULL, committed_at INTEGER NOT NULL,
    format_version INTEGER NOT NULL DEFAULT 1, message_id TEXT,
    PRIMARY KEY(vault_scope,sha256,size,override_id))''',
  'CREATE INDEX IF NOT EXISTS watched_message_ids ON watched_import_receipts(vault_scope,message_id)',
  '''CREATE TABLE IF NOT EXISTS watched_import_baseline (
    folder_id TEXT NOT NULL, source_path BLOB NOT NULL, revision TEXT NOT NULL,
    sha256 TEXT NOT NULL, size INTEGER NOT NULL, captured_at INTEGER NOT NULL,
    decision_generation TEXT NOT NULL, PRIMARY KEY(folder_id,source_path,revision))''',
  'CREATE INDEX IF NOT EXISTS watched_baseline_content ON watched_import_baseline(folder_id,sha256,size)',
  '''CREATE TABLE IF NOT EXISTS watched_import_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT, vault_scope TEXT NOT NULL,
    job_id TEXT NOT NULL, type TEXT NOT NULL, display_name TEXT NOT NULL,
    format TEXT NOT NULL, error_code TEXT, note_id TEXT, time INTEGER NOT NULL)''',
  '''CREATE TABLE IF NOT EXISTS watched_import_stages (
    asset_id TEXT PRIMARY KEY, kind TEXT NOT NULL, job_id TEXT NOT NULL)''',
];

const watchedImportTables = [
  'watched_import_stages',
  'watched_import_events',
  'watched_import_baseline',
  'watched_import_receipts',
  'watched_import_jobs',
  'watched_folders',
];
