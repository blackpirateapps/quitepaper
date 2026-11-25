part of 'app_database.dart';

const _taskSchema = [
  '''CREATE TABLE IF NOT EXISTS task_index (
    note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
    ordinal INTEGER NOT NULL, task_id TEXT, version TEXT NOT NULL,
    text TEXT NOT NULL, heading TEXT, note_title TEXT NOT NULL, completed INTEGER NOT NULL,
    due TEXT, search_text TEXT NOT NULL,
    PRIMARY KEY(note_id,ordinal))''',
  'CREATE INDEX IF NOT EXISTS task_status_date ON task_index(completed,due,note_id,ordinal)',
  'CREATE TABLE IF NOT EXISTS task_index_failures (note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE)',
  'CREATE INDEX IF NOT EXISTS task_identity ON task_index(note_id,task_id)',
  'CREATE TABLE IF NOT EXISTS task_dirty (note_id TEXT PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE)',
  // A trigger's OR IGNORE inherits the outer note UPSERT's conflict policy.
  // Keep queue deduplication explicit so repeated saves cannot abort the note.
  '''CREATE TRIGGER IF NOT EXISTS task_note_insert AFTER INSERT ON notes BEGIN
    INSERT INTO task_dirty(note_id) VALUES(new.id) ON CONFLICT(note_id) DO NOTHING; END''',
  '''CREATE TRIGGER IF NOT EXISTS task_note_update AFTER UPDATE OF content,is_archived,is_trashed,deleted_at ON notes BEGIN
    INSERT INTO task_dirty(note_id) VALUES(new.id) ON CONFLICT(note_id) DO NOTHING;
    DELETE FROM task_index WHERE note_id=new.id AND
      (new.is_archived=1 OR new.is_trashed=1 OR new.deleted_at IS NOT NULL OR ltrim(new.content) LIKE '<!-- quiet-paper-encrypted-note-v1:%'); END''',
  '''CREATE TRIGGER IF NOT EXISTS task_note_delete AFTER DELETE ON notes BEGIN
    DELETE FROM task_index WHERE note_id=old.id;
    DELETE FROM task_dirty WHERE note_id=old.id;
    DELETE FROM task_index_failures WHERE note_id=old.id; END''',
];

extension TaskIndexDatabase on AppDatabase {
  Future<void> createTaskIndex() async {
    for (final sql in _taskSchema) {
      await customStatement(sql);
    }
    await customStatement(
      'INSERT OR IGNORE INTO task_dirty SELECT id FROM notes',
    );
  }

  Future<void> indexNoteTasks(
    String id,
    String content, {
    required bool eligible,
  }) async {
    await customStatement('DELETE FROM task_index WHERE note_id=?', [id]);
    await customStatement('DELETE FROM task_index_failures WHERE note_id=?', [
      id,
    ]);
    if (eligible &&
        !content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
      final version = TaskDocument.version(content);
      List<TaskOccurrence> tasks;
      try {
        tasks = TaskDocument.extract(content);
      } on FormatException {
        await _taskParseFailure(id);
        return;
      } on TypeError {
        await _taskParseFailure(id);
        return;
      }
      final derivedTitle = Note.deriveTitle(content);
      for (final task in tasks) {
        await customStatement(
          'INSERT INTO task_index(note_id,ordinal,task_id,version,text,heading,completed,due,search_text,note_title) VALUES(?,?,?,?,?,?,?,?,?,?)',
          [
            id,
            task.ordinal,
            task.metadata?.id,
            version,
            task.text,
            task.heading,
            task.completed ? 1 : 0,
            task.metadata?.due?.toString(),
            SearchTokenizer.tokenize(task.text).join(' '),
            derivedTitle,
          ],
        );
      }
    }
    await customStatement('DELETE FROM task_dirty WHERE note_id=?', [id]);
  }

  Future<void> _taskParseFailure(String id) async {
    // No source text or parser exception is retained or logged.
    await customStatement(
      'INSERT OR IGNORE INTO task_index_failures VALUES(?)',
      [id],
    );
    await customStatement('DELETE FROM task_dirty WHERE note_id=?', [id]);
  }

  Stream<int> watchTaskIndexFailures() => customSelect(
    'SELECT count(*) AS count FROM task_index_failures',
    readsFrom: {notesTable},
  ).watch().map((rows) => rows.single.read<int>('count'));
  Future<void> retryTaskIndexFailures() async {
    await customStatement(
      'INSERT OR IGNORE INTO task_dirty SELECT note_id FROM task_index_failures',
    );
    markTablesUpdated({notesTable});
  }

  /// Each batch reads and indexes under the same transaction. SQL triggers leave
  /// direct/import/restore writes durably dirty; interrupted rebuilds resume.
  Future<int> repairTaskIndex({int batchSize = 32}) => transaction(() async {
    final rows = await customSelect(
      'SELECT n.* FROM notes n JOIN task_dirty d ON d.note_id=n.id ORDER BY n.id LIMIT ?',
      variables: [Variable(batchSize)],
    ).get();
    for (final row in rows) {
      await indexNoteTasks(
        row.read<String>('id'),
        row.read<String>('content'),
        eligible:
            !row.read<bool>('is_archived') &&
            !row.read<bool>('is_trashed') &&
            row.readNullable<DateTime>('deleted_at') == null,
      );
    }
    if (rows.isNotEmpty) markTablesUpdated({notesTable});
    return rows.length;
  });

  /// The database belongs to one active local vault. All projections join live
  /// eligibility; no result from a dirty source is ever served as current.
  Stream<List<QueryRow>> watchTaskRows() => customSelect(
    '''SELECT t.*, CASE WHEN trim(n.title)='' THEN t.note_title ELSE n.title END AS title FROM task_index t
    JOIN notes n ON n.id=t.note_id
    WHERE n.is_archived=0 AND n.is_trashed=0 AND n.deleted_at IS NULL
    AND NOT EXISTS(SELECT 1 FROM task_dirty d WHERE d.note_id=n.id)
    ORDER BY lower(n.title),n.id,t.ordinal''',
    readsFrom: {notesTable, noteTagsTable, tagsTable},
  ).watch();
}
