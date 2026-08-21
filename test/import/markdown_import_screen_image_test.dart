import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/import/application/markdown_import_service.dart';
import 'package:quitepaper/features/import/domain/import_image_reference.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';
import 'package:quitepaper/features/import/presentation/markdown_import_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  group('MarkdownImportScreen Image Workflow Tests', () {
    late AppDatabase db;
    late NotesRepository repository;

    setUp(() {
      db = AppDatabase.memory();
      repository = DriftNotesRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestScreen(List<MarkdownImportItem> items) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          notesRepositoryProvider.overrideWithValue(repository),
          markdownImportServiceProvider.overrideWithValue(
            MarkdownImportService(repository),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: MarkdownImportScreen(
            initialFolderPath: '/test/vault',
            initialItems: items,
          ),
        ),
      );
    }

    testWidgets('displays missing images alert banner when items contain missing images', (tester) async {
      final missingRef = ImportImageReference(
        originalSyntax: '![Missing](nonexistent.png)',
        rawTarget: 'nonexistent.png',
        altText: 'Missing',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/test/vault/note.md',
        relativePath: 'note.md',
        title: 'Note with Missing Image',
        content: '![Missing](nonexistent.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        isSelected: true,
        imageReferences: [missingRef],
      );

      await tester.pumpWidget(buildTestScreen([item]));
      await tester.pumpAndSettle();

      expect(find.text('1 missing image'), findsOneWidget);
      expect(find.text('Locate Images'), findsWidgets);
      expect(find.text('nonexistent.png'), findsOneWidget);
      expect(find.text('Missing on disk'), findsOneWidget);
    });

    testWidgets('prompts confirmation dialog when importing note with missing images', (tester) async {
      final missingRef = ImportImageReference(
        originalSyntax: '![Missing](nonexistent.png)',
        rawTarget: 'nonexistent.png',
        altText: 'Missing',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        id: 'note-with-missing',
        filePath: '/test/vault/note.md',
        relativePath: 'note.md',
        title: 'Note with Missing Image',
        content: '![Missing](nonexistent.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        isSelected: true,
        imageReferences: [missingRef],
      );

      await tester.pumpWidget(buildTestScreen([item]));
      await tester.pumpAndSettle();

      // Tap import button
      expect(find.text('Import 1 Note'), findsOneWidget);
      await tester.tap(find.text('Import 1 Note'));
      await tester.pumpAndSettle();

      // Should show confirmation dialog
      expect(find.text('Missing Images'), findsOneWidget);
      expect(find.text('Import Anyway'), findsOneWidget);

      // Tap Import Anyway
      await tester.tap(find.text('Import Anyway'));
      await tester.pumpAndSettle();

      // Note should be imported with original markdown intact
      final savedNote = await repository.getNoteById('note-with-missing');
      expect(savedNote, isNotNull);
      expect(savedNote!.content, equals('![Missing](nonexistent.png)'));
    });
  });
}
