import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/import/application/markdown_import_service.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  group('MarkdownImportService', () {
    late AppDatabase db;
    late NotesRepository repository;
    late MarkdownImportService importService;

    setUp(() {
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
      importService = MarkdownImportService(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('imports only selected items and preserves custom dates and tags', () async {
      final customCreated = DateTime(2023, 4, 12, 10, 30);
      final customUpdated = DateTime(2023, 5, 15, 14, 20);

      final item1 = MarkdownImportItem(
        id: 'import-1',
        filePath: '/path/Articles/Wikipedia/Flutter.md',
        relativePath: 'Articles/Wikipedia/Flutter.md',
        title: 'Flutter Architecture',
        content: '# Flutter Overview\n\nCross platform framework.',
        tags: ['articles', 'wikipedia', 'flutter', 'dart'],
        createdAt: customCreated,
        updatedAt: customUpdated,
        fileSizeBytes: 1024,
        isSelected: true,
      );

      final item2 = MarkdownImportItem(
        id: 'import-2',
        filePath: '/path/Unselected.md',
        relativePath: 'Unselected.md',
        title: 'Skipped Note',
        content: 'This note should not be imported.',
        tags: ['skipped'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 512,
        isSelected: false,
      );

      final count = await importService.importNotes([item1, item2]);
      expect(count, equals(1));

      final note1 = await repository.getNoteById('import-1');
      expect(note1, isNotNull);
      expect(note1!.title, equals('Flutter Architecture'));
      expect(note1.content, equals('# Flutter Overview\n\nCross platform framework.'));
      expect(note1.createdAt, equals(customCreated));
      expect(note1.updatedAt, equals(customUpdated));
      expect(note1.tags, containsAll(['articles', 'wikipedia', 'flutter', 'dart']));

      final note2 = await repository.getNoteById('import-2');
      expect(note2, isNull);
    });
  });
}
