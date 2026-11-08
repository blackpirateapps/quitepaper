import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import '../utils/tag_parser.dart';

/// Lightweight representation of a note for CLI operations.
class CliNote {
  const CliNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isTrashed = false,
    this.tags = const [],
    this.journalDate,
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isTrashed;
  final List<String> tags;
  final String? journalDate;

  /// Short 8-character hexadecimal identifier prefix (like git commit short hash).
  String get shortId => id.length >= 8 ? id.substring(0, 8) : id;

  /// Clean display title.
  String get displayTitle {
    final t = title.trim();
    if (t.isNotEmpty) return t;
    final derived = deriveTitle(content);
    return derived.isNotEmpty ? derived : 'Untitled';
  }

  /// Derives title from Markdown content (e.g. first # Heading or first non-empty line).
  static String deriveTitle(String content) {
    if (content.trim().isEmpty) return '';
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#')) {
        final clean = trimmed.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        if (clean.isNotEmpty) return clean;
      } else {
        return trimmed.length > 80 ? '${trimmed.substring(0, 77)}...' : trimmed;
      }
    }
    return '';
  }

  /// Extracts a 1-line preview snippet.
  String get previewSnippet {
    final lines = const LineSplitter().convert(content);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#') || trimmed.startsWith('---')) continue;
      return trimmed.length > 100 ? '${trimmed.substring(0, 97)}...' : trimmed;
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shortId': shortId,
        'title': displayTitle,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPinned': isPinned,
        'isArchived': isArchived,
        'isTrashed': isTrashed,
        'tags': tags,
        'journalDate': journalDate,
      };
}

/// Tag with note count for CLI display.
class CliTag {
  const CliTag({
    required this.id,
    required this.name,
    required this.noteCount,
    this.color,
    this.icon,
    this.isPinned = false,
  });

  final String id;
  final String name;
  final int noteCount;
  final String? color;
  final String? icon;
  final bool isPinned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'noteCount': noteCount,
        'color': color,
        'icon': icon,
        'isPinned': isPinned,
      };
}

/// Direct SQLite database service for the Quiet Paper CLI (`qp`).
///
/// Connects directly to `quiet_paper.sqlite` in WAL mode, ensuring zero interference
/// with the running Flutter desktop GUI while maintaining tags, version history,
/// FTS5 search indexes, and cloud sync queue mutations.
class CliDatabase {
  CliDatabase(this._db);

  final Database _db;

  /// Resolves canonical database path conforming to XDG specification on Linux.
  static String resolveDefaultDbPath() {
    final xdgData = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'] ?? '';
    final dir = (xdgData != null && xdgData.trim().isNotEmpty)
        ? '$xdgData/quitepaper'
        : '$home/.local/share/quitepaper';
    return '$dir/quiet_paper.sqlite';
  }

  /// Opens the database from a given file path (or default Linux path).
  static CliDatabase open([String? customPath]) {
    final path = customPath ?? resolveDefaultDbPath();
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final db = sqlite3.open(path);
    final cliDb = CliDatabase(db);
    cliDb._configurePragmas();
    cliDb.ensureTables();
    return cliDb;
  }

  /// Opens an in-memory database (primarily for automated unit testing).
  static CliDatabase openInMemory() {
    final db = sqlite3.openInMemory();
    final cliDb = CliDatabase(db);
    cliDb._configurePragmas();
    cliDb.ensureTables();
    return cliDb;
  }

  void _configurePragmas() {
    try {
      _db.execute('PRAGMA journal_mode = WAL;');
      _db.execute('PRAGMA busy_timeout = 5000;');
      _db.execute('PRAGMA foreign_keys = ON;');
    } catch (_) {}
  }

  /// Ensures necessary database tables and indices exist.
  void ensureTables() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        is_trashed INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER,
        server_revision INTEGER NOT NULL DEFAULT 0,
        is_dirty INTEGER NOT NULL DEFAULT 1,
        synced_at INTEGER,
        journal_date TEXT,
        share_id TEXT,
        share_url TEXT,
        pinned_tags TEXT
      );

      CREATE TABLE IF NOT EXISTS tags (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        icon TEXT,
        color TEXT,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        pinned_order INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER,
        is_dirty INTEGER NOT NULL DEFAULT 1,
        server_revision INTEGER NOT NULL DEFAULT 0,
        synced_at INTEGER,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        deleted_at INTEGER
      );

      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (note_id, tag_id)
      );

      CREATE TABLE IF NOT EXISTS note_versions (
        id TEXT NOT NULL PRIMARY KEY,
        note_id TEXT NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
        version_number INTEGER NOT NULL,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        tags_json TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL,
        char_count INTEGER NOT NULL DEFAULT 0,
        word_count INTEGER NOT NULL DEFAULT 0,
        delta_summary TEXT,
        server_revision INTEGER NOT NULL DEFAULT 0,
        is_dirty INTEGER NOT NULL DEFAULT 1,
        synced_at INTEGER,
        base_revision INTEGER,
        local_parent_revision INTEGER,
        remote_parent_revision INTEGER,
        merge_type TEXT,
        resolution_summary TEXT
      );

      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT NOT NULL PRIMARY KEY,
        note_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT
      );
    ''');

    // Attempt to initialize FTS5 tables defensively
    try {
      _db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS note_search_prefix USING fts5(
          note_id UNINDEXED,
          title,
          body_text,
          tags,
          tokenize='unicode61 remove_diacritics 2'
        );
      ''');
    } catch (_) {}

    try {
      _db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS note_search_trigram USING fts5(
          note_id UNINDEXED,
          title,
          body_text,
          tags,
          tokenize='trigram'
        );
      ''');
    } catch (_) {}
  }

  /// Lists notes according to filter parameters.
  List<CliNote> listNotes({
    String? tag,
    String? query,
    bool? pinnedOnly,
    bool showArchived = false,
    bool showTrash = false,
    int? limit,
  }) {
    final conditions = <String>[];
    final params = <dynamic>[];

    if (showTrash) {
      conditions.add('n.is_trashed = 1');
    } else if (showArchived) {
      conditions.add('n.is_archived = 1 AND n.is_trashed = 0');
    } else {
      conditions.add('n.is_archived = 0 AND n.is_trashed = 0');
    }

    if (pinnedOnly == true) {
      conditions.add('n.is_pinned = 1');
    }

    if (tag != null && tag.trim().isNotEmpty) {
      final cleanTag = TagParser.normalizeTag(tag.trim().replaceFirst(RegExp(r'^#'), ''));
      conditions.add('''
        n.id IN (
          SELECT nt.note_id FROM note_tags nt
          INNER JOIN tags t ON t.id = nt.tag_id
          WHERE t.name = ? OR t.name LIKE ?
        )
      ''');
      params.add(cleanTag);
      params.add('$cleanTag/%');
    }

    if (query != null && query.trim().isNotEmpty) {
      final cleanQuery = '%${query.trim()}%';
      conditions.add('(n.title LIKE ? OR n.content LIKE ?)');
      params.add(cleanQuery);
      params.add(cleanQuery);
    }

    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final limitClause = (limit != null && limit > 0) ? 'LIMIT $limit' : '';

    final sql = '''
      SELECT n.id, n.title, n.content, n.created_at, n.updated_at,
             n.is_pinned, n.is_archived, n.is_trashed, n.journal_date
      FROM notes n
      $whereClause
      ORDER BY n.is_pinned DESC, n.updated_at DESC
      $limitClause;
    ''';

    final stmt = _db.prepare(sql);
    try {
      final rows = stmt.select(params);
      final notes = <CliNote>[];
      for (final row in rows) {
        final noteId = row['id'] as String;
        final tags = _getTagsForNote(noteId);
        notes.add(CliNote(
          id: noteId,
          title: (row['title'] as String?) ?? '',
          content: (row['content'] as String?) ?? '',
          createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as int) * 1000),
          updatedAt: DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as int) * 1000),
          isPinned: (row['is_pinned'] as int? ?? 0) == 1,
          isArchived: (row['is_archived'] as int? ?? 0) == 1,
          isTrashed: (row['is_trashed'] as int? ?? 0) == 1,
          journalDate: row['journal_date'] as String?,
          tags: tags,
        ));
      }
      return notes;
    } finally {
      stmt.close();
    }
  }

  /// Fetches a note by its exact ID or an 8+ character hexadecimal prefix.
  CliNote? getNoteByIdOrPrefix(String idOrPrefix) {
    final clean = idOrPrefix.trim().toLowerCase();
    if (clean.isEmpty) return null;

    final stmt = _db.prepare('''
      SELECT n.id, n.title, n.content, n.created_at, n.updated_at,
             n.is_pinned, n.is_archived, n.is_trashed, n.journal_date
      FROM notes n
      WHERE LOWER(n.id) = ? OR LOWER(n.id) LIKE ?
      ORDER BY n.updated_at DESC
      LIMIT 1;
    ''');
    try {
      final rows = stmt.select([clean, '$clean%']);
      if (rows.isEmpty) return null;
      final row = rows.first;
      final noteId = row['id'] as String;
      final tags = _getTagsForNote(noteId);
      return CliNote(
        id: noteId,
        title: (row['title'] as String?) ?? '',
        content: (row['content'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch((row['created_at'] as int) * 1000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as int) * 1000),
        isPinned: (row['is_pinned'] as int? ?? 0) == 1,
        isArchived: (row['is_archived'] as int? ?? 0) == 1,
        isTrashed: (row['is_trashed'] as int? ?? 0) == 1,
        journalDate: row['journal_date'] as String?,
        tags: tags,
      );
    } finally {
      stmt.close();
    }
  }

  /// Finds notes matching a title substring query.
  List<CliNote> findNotesByTitle(String titleQuery) {
    final clean = titleQuery.trim();
    if (clean.isEmpty) return const [];
    return listNotes(query: clean, limit: 10);
  }

  /// Creates a new note, extracting tags, updating FTS, and registering a sync mutation.
  CliNote createNote({
    required String title,
    required String content,
    List<String>? tags,
    bool isPinned = false,
  }) {
    const uuid = Uuid();
    final id = uuid.v4();
    final now = DateTime.now();
    final nowEpoch = (now.millisecondsSinceEpoch / 1000).round();

    final effectiveTitle = title.trim().isNotEmpty
        ? title.trim()
        : CliNote.deriveTitle(content);

    // Auto-extract tags from content + title + explicit tags
    final extractedTags = <String>{};
    if (tags != null) {
      for (final t in tags) {
        final norm = TagParser.normalizeTag(t.replaceFirst(RegExp(r'^#'), ''));
        if (TagParser.isValidTag(norm)) extractedTags.add(norm);
      }
    }
    for (final t in TagParser.extractTags('$effectiveTitle\n$content')) {
      extractedTags.add(t);
    }

    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute(
        '''
        INSERT INTO notes (
          id, title, content, created_at, updated_at, is_pinned, is_archived,
          is_trashed, is_dirty, server_revision
        ) VALUES (?, ?, ?, ?, ?, ?, 0, 0, 1, 0);
        ''',
        [id, effectiveTitle, content, nowEpoch, nowEpoch, isPinned ? 1 : 0],
      );

      _syncTagsForNote(id, extractedTags.toList(), nowEpoch);
      _createVersionSnapshot(id, effectiveTitle, content, extractedTags.toList(), nowEpoch);
      _queueSyncMutation(id, 'upsert', nowEpoch);
      _updateSearchIndex(id, effectiveTitle, content, extractedTags.toList());

      _db.execute('COMMIT;');

      return CliNote(
        id: id,
        title: effectiveTitle,
        content: content,
        createdAt: now,
        updatedAt: now,
        isPinned: isPinned,
        tags: extractedTags.toList()..sort(),
      );
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Modifies an existing note, updates version history, FTS index, and registers a sync mutation.
  CliNote updateNote({
    required String id,
    required String title,
    required String content,
    List<String>? tags,
    bool? isPinned,
  }) {
    final existing = getNoteByIdOrPrefix(id);
    if (existing == null) {
      throw ArgumentError('Note not found with id: $id');
    }

    final now = DateTime.now();
    final nowEpoch = (now.millisecondsSinceEpoch / 1000).round();

    final effectiveTitle = title.trim().isNotEmpty
        ? title.trim()
        : CliNote.deriveTitle(content);

    final extractedTags = <String>{};
    if (tags != null) {
      for (final t in tags) {
        final norm = TagParser.normalizeTag(t.replaceFirst(RegExp(r'^#'), ''));
        if (TagParser.isValidTag(norm)) extractedTags.add(norm);
      }
    }
    for (final t in TagParser.extractTags('$effectiveTitle\n$content')) {
      extractedTags.add(t);
    }

    final effectivePinned = isPinned ?? existing.isPinned;

    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute(
        '''
        UPDATE notes
        SET title = ?, content = ?, updated_at = ?, is_pinned = ?, is_dirty = 1
        WHERE id = ?;
        ''',
        [effectiveTitle, content, nowEpoch, effectivePinned ? 1 : 0, existing.id],
      );

      _syncTagsForNote(existing.id, extractedTags.toList(), nowEpoch);
      _createVersionSnapshot(existing.id, effectiveTitle, content, extractedTags.toList(), nowEpoch);
      _queueSyncMutation(existing.id, 'upsert', nowEpoch);
      _updateSearchIndex(existing.id, effectiveTitle, content, extractedTags.toList());

      _db.execute('COMMIT;');

      return CliNote(
        id: existing.id,
        title: effectiveTitle,
        content: content,
        createdAt: existing.createdAt,
        updatedAt: now,
        isPinned: effectivePinned,
        isArchived: existing.isArchived,
        isTrashed: existing.isTrashed,
        journalDate: existing.journalDate,
        tags: extractedTags.toList()..sort(),
      );
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Moves a note to the trash.
  void trashNote(String id) {
    final existing = getNoteByIdOrPrefix(id);
    if (existing == null) throw ArgumentError('Note not found: $id');
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute(
        'UPDATE notes SET is_trashed = 1, deleted_at = ?, is_dirty = 1, updated_at = ? WHERE id = ?;',
        [now, now, existing.id],
      );
      _deleteSearchIndex(existing.id);
      _queueSyncMutation(existing.id, 'upsert', now);
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Restores a note from the trash.
  void restoreNote(String id) {
    final existing = getNoteByIdOrPrefix(id);
    if (existing == null) throw ArgumentError('Note not found: $id');
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute(
        'UPDATE notes SET is_trashed = 0, deleted_at = NULL, is_dirty = 1, updated_at = ? WHERE id = ?;',
        [now, existing.id],
      );
      _updateSearchIndex(existing.id, existing.title, existing.content, existing.tags);
      _queueSyncMutation(existing.id, 'upsert', now);
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Permanently deletes a note and records a sync tombstone.
  void deletePermanently(String id) {
    final existing = getNoteByIdOrPrefix(id);
    if (existing == null) throw ArgumentError('Note not found: $id');
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    _db.execute('BEGIN TRANSACTION;');
    try {
      _db.execute('DELETE FROM notes WHERE id = ?;', [existing.id]);
      _deleteSearchIndex(existing.id);
      _queueSyncMutation(existing.id, 'delete', now);
      _db.execute('COMMIT;');
    } catch (e) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  /// Lists all tags with active note counts.
  List<CliTag> listTags() {
    final rows = _db.select('''
      SELECT t.id, t.name, t.color, t.icon, t.is_pinned, COUNT(nt.note_id) AS note_count
      FROM tags t
      LEFT JOIN note_tags nt ON nt.tag_id = t.id
      LEFT JOIN notes n ON n.id = nt.note_id AND n.is_trashed = 0 AND n.is_archived = 0
      WHERE t.is_deleted = 0
      GROUP BY t.id, t.name
      ORDER BY t.is_pinned DESC, t.name ASC;
    ''');

    return rows.map((r) => CliTag(
      id: r['id'] as String,
      name: r['name'] as String,
      noteCount: (r['note_count'] as int?) ?? 0,
      color: r['color'] as String?,
      icon: r['icon'] as String?,
      isPinned: (r['is_pinned'] as int? ?? 0) == 1,
    )).toList();
  }

  List<String> _getTagsForNote(String noteId) {
    final rows = _db.select('''
      SELECT t.name FROM tags t
      INNER JOIN note_tags nt ON nt.tag_id = t.id
      WHERE nt.note_id = ? AND t.is_deleted = 0
      ORDER BY t.name ASC;
    ''', [noteId]);
    return rows.map((r) => r['name'] as String).toList();
  }

  void _syncTagsForNote(String noteId, List<String> tagNames, int nowEpoch) {
    _db.execute('DELETE FROM note_tags WHERE note_id = ?;', [noteId]);

    const uuid = Uuid();
    for (final name in tagNames) {
      final normalized = TagParser.normalizeTag(name);
      if (!TagParser.isValidTag(normalized)) continue;

      final existing = _db.select('SELECT id FROM tags WHERE name = ? LIMIT 1;', [normalized]);
      final String tagId;
      if (existing.isNotEmpty) {
        tagId = existing.first['id'] as String;
      } else {
        tagId = uuid.v4();
        _db.execute(
          '''
          INSERT INTO tags (id, name, created_at, updated_at, is_dirty)
          VALUES (?, ?, ?, ?, 1);
          ''',
          [tagId, normalized, nowEpoch, nowEpoch],
        );
      }

      _db.execute(
        'INSERT OR IGNORE INTO note_tags (note_id, tag_id) VALUES (?, ?);',
        [noteId, tagId],
      );
    }
  }

  void _createVersionSnapshot(
    String noteId,
    String title,
    String content,
    List<String> tags,
    int nowEpoch,
  ) {
    try {
      final last = _db.select(
        'SELECT MAX(version_number) AS max_v FROM note_versions WHERE note_id = ?;',
        [noteId],
      );
      final nextNumber = ((last.first['max_v'] as int?) ?? 0) + 1;
      const uuid = Uuid();
      final words = content.trim().isEmpty ? 0 : content.trim().split(RegExp(r'\s+')).length;

      _db.execute(
        '''
        INSERT INTO note_versions (
          id, note_id, version_number, title, content, tags_json,
          created_at, char_count, word_count, is_dirty
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 1);
        ''',
        [
          uuid.v4(),
          noteId,
          nextNumber,
          title,
          content,
          jsonEncode(tags),
          nowEpoch,
          content.length,
          words,
        ],
      );
    } catch (_) {}
  }

  void _queueSyncMutation(String noteId, String operation, int nowEpoch) {
    try {
      const uuid = Uuid();
      _db.execute(
        '''
        INSERT INTO sync_queue (id, note_id, operation, created_at, attempts)
        VALUES (?, ?, ?, ?, 0);
        ''',
        [uuid.v4(), noteId, operation, nowEpoch],
      );
    } catch (_) {}
  }

  void _updateSearchIndex(String noteId, String title, String content, List<String> tags) {
    _deleteSearchIndex(noteId);
    final tagsText = tags.map((t) => '#$t').join(' ');
    try {
      _db.execute(
        'INSERT INTO note_search_prefix (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
        [noteId, title, content, tagsText],
      );
      _db.execute(
        'INSERT INTO note_search_trigram (note_id, title, body_text, tags) VALUES (?, ?, ?, ?);',
        [noteId, title, content, tagsText],
      );
    } catch (_) {}
  }

  void _deleteSearchIndex(String noteId) {
    try {
      _db.execute('DELETE FROM note_search_prefix WHERE note_id = ?;', [noteId]);
      _db.execute('DELETE FROM note_search_trigram WHERE note_id = ?;', [noteId]);
    } catch (_) {}
  }

  /// Closes database connection.
  void close() {
    _db.close();
  }
}
