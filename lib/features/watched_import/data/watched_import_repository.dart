import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../native/api/engine.dart';
import '../domain/watched_file_type.dart';

const watchedTerminalStatuses = {
  'imported',
  'duplicate_skipped',
  'baseline_skipped',
  'unsupported',
  'missing_source',
  'cancelled',
  'failed',
  'needs_attention',
};

/// The sole authoritative job/receipt store; Rust never opens this database.
class WatchedImportRepositoryAdapter {
  WatchedImportRepositoryAdapter(this.database);
  final AppDatabase database;
  static const uuid = Uuid();
  int get now => DateTime.now().millisecondsSinceEpoch;

  Future<List<QueryRow>> rows(String sql, [List<Object?> args = const []]) =>
      database
          .customSelect(
            sql,
            variables: args
                .map<Variable>(
                  (v) => switch (v) {
                    int n => Variable<int>(n),
                    Uint8List b => Variable<Uint8List>(b),
                    String s => Variable<String>(s),
                    null => const Variable<String>(null),
                    _ => throw ArgumentError('Unsupported SQL argument'),
                  },
                )
                .toList(),
          )
          .get();
  Future<void> write(String sql, [List<Object?> args = const []]) =>
      database.customStatement(sql, args);

  Future<List<QueryRow>> folders() =>
      rows('SELECT * FROM watched_folders ORDER BY created_at,rowid');
  Future<QueryRow?> folder([String? id]) async => (await rows(
    id == null
        ? 'SELECT * FROM watched_folders ORDER BY created_at,rowid LIMIT 1'
        : 'SELECT * FROM watched_folders WHERE id=?',
    id == null ? [] : [id],
  )).firstOrNull;

  Future<void> setFileTypes(String id, Set<WatchedFileType> types) => write(
    'UPDATE watched_folders SET file_types=?,updated_at=? WHERE id=?',
    [WatchedFileType.encode(types), now, id],
  );
  Future<String> deviceScope() async {
    var value = await database.getSyncMetadata('watched_installation_scope');
    if (value == null) {
      value = 'device:${uuid.v4()}';
      await database.setSyncMetadata('watched_installation_scope', value);
    }
    return value;
  }

  Future<String> enroll(
    RootInfo root,
    String scope,
  ) => database.transaction(() async {
    final id = uuid.v4();
    if ((await rows(
      'SELECT 1 FROM watched_folders WHERE vault_scope=? AND (canonical_root=? OR root_identity=?)',
      [scope, root.canonicalPath, root.identity],
    )).isNotEmpty) {
      throw StateError('folder_already_watched');
    }
    await write(
      '''INSERT INTO watched_folders
      (id,canonical_root,root_identity,vault_scope,decision_generation,created_at,updated_at)
      VALUES (?,?,?,?,?,?,?)''',
      [id, root.canonicalPath, root.identity, scope, uuid.v4(), now, now],
    );
    return id;
  });
  Future<void> removeFolder([
    String? folderId,
  ]) => database.transaction(() async {
    final id = folderId ?? (await folder())?.read<String>('id');
    if (id == null) return;
    await write(
      "UPDATE watched_import_jobs SET status='cancelled',updated_at=? WHERE folder_id=? AND status NOT IN ('imported','duplicate_skipped','baseline_skipped')",
      [now, id],
    );
    await write('DELETE FROM watched_import_baseline WHERE folder_id=?', [id]);
    await write('DELETE FROM watched_folders WHERE id=?', [id]);
  });
  Future<void> inventoryDone(String id, String? error) async {
    final f = await folder(id);
    if (f?.readNullable<String>('inventory_error') == 'review_interrupted') {
      return;
    }
    await write(
      '''UPDATE watched_folders
    SET inventory_complete=?,inventory_error=?,last_reconcile=?,updated_at=? WHERE id=?''',
      [error == null ? 1 : 0, error, now, now, id],
    );
  }

  Future<void> decide(
    String id,
    bool existing,
  ) => database.transaction(() async {
    final f = await folder(id);
    if (f == null ||
        f.read<String>('id') != id ||
        f.read<int>('inventory_complete') != 1) {
      throw StateError('inventory_incomplete');
    }
    await write(
      "UPDATE watched_folders SET review_state='accepted',existing_policy=?,decision_time=?,updated_at=? WHERE id=?",
      [existing ? 'import_existing' : 'only_new', now, now, id],
    );
    if (!existing) {
      await write(
        "UPDATE watched_import_jobs SET status='baseline_skipped',updated_at=? WHERE folder_id=? AND status='awaiting_review' AND EXISTS (SELECT 1 FROM watched_import_baseline b WHERE b.folder_id=watched_import_jobs.folder_id AND b.source_path=watched_import_jobs.source_path AND b.revision=watched_import_jobs.revision)",
        [now, id],
      );
    }
    await write(
      "UPDATE watched_import_jobs SET status='ready',updated_at=? WHERE folder_id=? AND status='awaiting_review'",
      [now, id],
    );
  });
  Future<void> baseline(Candidate c, QueryRow f) => write(
    '''INSERT OR IGNORE INTO watched_import_baseline
    (folder_id,source_path,revision,sha256,size,captured_at,decision_generation) VALUES (?,?,?,?,?,?,?)''',
    [
      c.folderId,
      c.relativePath,
      c.revision,
      c.sha256,
      c.size,
      now,
      f.read<String>('decision_generation'),
    ],
  );
  Future<bool> isBaseline(Candidate c) async => (await rows(
    'SELECT 1 FROM watched_import_baseline WHERE folder_id=? AND sha256=? AND size=? LIMIT 1',
    [c.folderId, c.sha256, c.size],
  )).isNotEmpty;
  Future<QueryRow?> receipt(String scope, Candidate c) async => (await rows(
    "SELECT * FROM watched_import_receipts WHERE vault_scope=? AND sha256=? AND size=? AND override_id=''",
    [scope, c.sha256, c.size],
  )).firstOrNull;
  Future<bool> hasMessageId(String scope, String? messageId) async =>
      messageId != null &&
      (await rows(
        'SELECT 1 FROM watched_import_receipts WHERE vault_scope=? AND message_id=? LIMIT 1',
        [scope, messageId],
      )).isNotEmpty;

  Future<QueryRow> reserve(
    Candidate c,
    String scope, {
    String overrideId = '',
  }) => database.transaction(() async {
    await write(
      '''INSERT OR IGNORE INTO watched_import_jobs
      (id,folder_id,vault_scope,source_path,source_root,display_name,revision,size,sha256,format,status,
      planned_note_id,generation,override_id,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,'ready',?,?,?,?,?)''',
      [
        c.jobId,
        c.folderId,
        scope,
        c.relativePath,
        (await folder(c.folderId))?.read<String>('canonical_root') ?? '',
        c.displayName,
        c.revision,
        c.size,
        c.sha256,
        c.format,
        uuid.v4(),
        c.generation,
        overrideId,
        now,
        now,
      ],
    );
    return (await rows(
      'SELECT * FROM watched_import_jobs WHERE folder_id=? AND source_path=? AND revision=? AND override_id=?',
      [c.folderId, c.relativePath, c.revision, overrideId],
    )).single;
  });
  Future<void> transition(
    String jobId,
    String status, {
    String? code,
    String? noteId,
    bool event = true,
  }) => database.transaction(() async {
    final prior = (await rows('SELECT * FROM watched_import_jobs WHERE id=?', [
      jobId,
    ])).single;
    final previous = prior.read<String>('status');
    if (previous == status) return;
    const allowed = {
      'ready': {
        'awaiting_review',
        'stabilizing',
        'importing',
        'duplicate_skipped',
        'baseline_skipped',
        'unsupported',
        'missing_source',
        'waiting_for_unlock',
        'cancelled',
        'failed',
      },
      'awaiting_review': {'ready', 'baseline_skipped', 'cancelled'},
      'stabilizing': {
        'ready',
        'importing',
        'missing_source',
        'cancelled',
        'failed',
      },
      'importing': {
        'imported',
        'retry_scheduled',
        'waiting_for_unlock',
        'needs_attention',
        'missing_source',
        'failed',
        'cancelled',
      },
      'waiting_for_unlock': {
        'importing',
        'retry_scheduled',
        'duplicate_skipped',
        'baseline_skipped',
        'cancelled',
        'failed',
      },
      'retry_scheduled': {
        'importing',
        'waiting_for_unlock',
        'duplicate_skipped',
        'baseline_skipped',
        'needs_attention',
        'failed',
        'cancelled',
      },
    };
    if (!(allowed[previous]?.contains(status) ?? false)) {
      throw StateError('invalid_job_transition');
    }
    if (watchedTerminalStatuses.contains(previous)) {
      throw StateError('terminal_job_transition');
    }
    if (status == 'importing') {
      await write('UPDATE watched_import_jobs SET next_retry=NULL WHERE id=?', [
        jobId,
      ]);
    }
    await write(
      'UPDATE watched_import_jobs SET status=?,last_error=?,updated_at=?,attempt_count=attempt_count+? WHERE id=?',
      [status, code, now, status == 'importing' ? 1 : 0, jobId],
    );
    if (event && status != 'importing' && status != 'awaiting_review') {
      await write(
        '''INSERT INTO watched_import_events(vault_scope,job_id,type,display_name,format,error_code,note_id,time)
        VALUES (?,?,?,?,?,?,?,?)''',
        [
          prior.read<String>('vault_scope'),
          jobId,
          status,
          prior.read<String>('display_name'),
          prior.read<String>('format'),
          code,
          noteId,
          now,
        ],
      );
      await write(
        'DELETE FROM watched_import_events WHERE id NOT IN (SELECT id FROM watched_import_events ORDER BY id DESC LIMIT 500)',
      );
    }
  });

  /// Must run INSIDE the canonical importer's transaction, after saveNote.
  Future<void> commitReceipt(
    QueryRow job,
    Candidate c, {
    String? messageId,
  }) async {
    final id = job.read<String>('planned_note_id');
    if ((await database.getNoteWithTags(id)) == null) {
      throw StateError('receipt_without_note');
    }
    await write(
      '''INSERT INTO watched_import_receipts
      (vault_scope,sha256,size,override_id,note_id,folder_id,source_root,source_path,display_name,committed_at,message_id)
      VALUES (?,?,?,?,?,?,?,?,?,?,?)''',
      [
        job.read<String>('vault_scope'),
        c.sha256,
        c.size,
        job.read<String>('override_id'),
        id,
        c.folderId,
        job.read<String>('source_root'),
        c.relativePath,
        c.displayName,
        now,
        messageId,
      ],
    );
    await transition(job.read<String>('id'), 'imported', noteId: id);
    await write('DELETE FROM watched_import_stages WHERE job_id=?', [
      job.read<String>('id'),
    ]);
  }

  Future<void> retry(String jobId) => write(
    "UPDATE watched_import_jobs SET status='ready',last_error=NULL,attempt_count=0,next_retry=NULL,generation=generation+1,updated_at=? WHERE id=? AND status IN ('failed','needs_attention','retry_scheduled','waiting_for_unlock','missing_source')",
    [now, jobId],
  );
  Future<List<QueryRow>> history(String scope) => rows(
    'SELECT e.*,j.folder_id FROM watched_import_events e LEFT JOIN watched_import_jobs j ON j.id=e.job_id WHERE e.vault_scope=? ORDER BY e.id DESC LIMIT 100',
    [scope],
  );
}
