import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/note_links/note_link_search_service.dart';

void main() {
  group('NoteLinkSearchService', () {
    late AppDatabase db;
    late NoteLinkSearchService searchService;

    setUp(() {
      db = AppDatabase.memory();
      searchService = NoteLinkSearchService(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('empty query returns recent notes ordered by updatedAt excluding currentNoteId', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'note-1',
        title: 'Note 1',
        content: 'Content 1',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
        isPinned: false,
      );
      await db.saveNote(
        id: 'note-2',
        title: 'Note 2',
        content: 'Content 2',
        createdAt: now.subtract(const Duration(hours: 1)),
        updatedAt: now.subtract(const Duration(hours: 1)),
        isPinned: false,
      );
      await db.saveNote(
        id: 'current-note',
        title: 'Current Note',
        content: 'Editing',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final results = await searchService.searchNotes(
        query: '',
        currentNoteId: 'current-note',
      );

      expect(results.length, 2);
      expect(results[0].id, 'note-2');
      expect(results[1].id, 'note-1');
    });

    test('ranks exact title match ahead of partial or content match', () async {
      final now = DateTime.now();
      await db.saveNote(
        id: 'partial-note',
        title: 'Fourier Transform and Applications',
        content: 'Mathematics',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );
      await db.saveNote(
        id: 'exact-note',
        title: 'Fourier',
        content: 'Core theorem',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );
      await db.saveNote(
        id: 'content-note',
        title: 'Signal Processing',
        content: 'Mentions fourier series in section 2',
        createdAt: now,
        updatedAt: now,
        isPinned: false,
      );

      final results = await searchService.searchNotes(query: 'Fourier');
      expect(results.isNotEmpty, true);
      expect(results.first.id, 'exact-note');
      expect(results[1].id, 'partial-note');
    });

    test('masks snippet for password-protected note', () async {
      const protectedContent = '''
<!-- quiet-paper-encrypted-note-v1:{"salt":"s","iv":"i","ct":"c","mac":"m"}-->
Encrypted content
''';

      await db.saveNote(
        id: 'protected-note',
        title: 'Secret Plans',
        content: protectedContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final results = await searchService.searchNotes(query: 'Secret');
      expect(results.length, 1);
      expect(results.first.isPasswordProtected, true);
      expect(results.first.snippet, '🔒 Password protected note');
    });
  });
}
