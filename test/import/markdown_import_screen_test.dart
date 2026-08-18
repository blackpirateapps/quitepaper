import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';
import 'package:quitepaper/features/import/presentation/markdown_import_screen.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MarkdownImportScreen(
          initialFolderPath: '/mock/path/notes',
          initialItems: items,
        ),
      ),
    );
  }

  testWidgets('MarkdownImportScreen displays items, allows tag modification, selection and import', (tester) async {
    final item1 = MarkdownImportItem(
      id: 'item-1',
      filePath: '/mock/path/notes/Articles/Wikipedia/DeepLearning.md',
      relativePath: 'Articles/Wikipedia/DeepLearning.md',
      title: 'Deep Learning',
      content: '# Deep Learning Content\n\nSome text.',
      tags: ['articles', 'wikipedia'],
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 2),
      fileSizeBytes: 1024,
      isSelected: true,
    );

    final item2 = MarkdownImportItem(
      id: 'item-2',
      filePath: '/mock/path/notes/QuickNote.md',
      relativePath: 'QuickNote.md',
      title: 'Quick Note',
      content: 'Short content',
      tags: const [],
      createdAt: DateTime(2024, 2, 1),
      updatedAt: DateTime(2024, 2, 2),
      fileSizeBytes: 256,
      isSelected: true,
    );

    await tester.pumpWidget(buildTestScreen([item1, item2]));
    await tester.pumpAndSettle();

    // Verify titles and paths are visible
    expect(find.text('Deep Learning'), findsOneWidget);
    expect(find.text('Quick Note'), findsOneWidget);
    expect(find.text('Articles/Wikipedia/DeepLearning.md'), findsOneWidget);
    expect(find.text('#articles'), findsOneWidget);
    expect(find.text('#wikipedia'), findsOneWidget);
    expect(find.text('2 of 2 selected'), findsOneWidget);
    expect(find.text('Import 2 Notes'), findsOneWidget);

    // Uncheck item2 (the second checkbox in the list)
    final checkboxes = find.byType(Checkbox);
    // index 0 is the "select all" checkbox, index 1 is item1, index 2 is item2
    await tester.tap(checkboxes.at(2));
    await tester.pumpAndSettle();

    expect(find.text('1 of 2 selected'), findsOneWidget);
    expect(find.text('Import 1 Note'), findsOneWidget);

    // Tap "+ Tag" on item1 to add a new tag
    final tagButtons = find.text('Tag');
    expect(tagButtons, findsWidgets);
    await tester.tap(tagButtons.first);
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Add Tag to "Deep Learning"'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'machine-learning');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify new tag chip is visible
    expect(find.text('#machine-learning'), findsOneWidget);

    // Tap "Import 1 Note"
    await tester.tap(find.text('Import 1 Note'));
    await tester.pumpAndSettle();

    // Verify item1 was saved into repository
    final savedNote = await repository.getNoteById('item-1');
    expect(savedNote, isNotNull);
    expect(savedNote!.title, equals('Deep Learning'));
    expect(savedNote.tags, containsAll(['articles', 'wikipedia', 'machine-learning']));

    // Verify item2 was not imported
    final skippedNote = await repository.getNoteById('item-2');
    expect(skippedNote, isNull);
  });

  testWidgets('MarkdownImportScreen displays empty state when items list is empty', (tester) async {
    await tester.pumpWidget(buildTestScreen([]));
    await tester.pumpAndSettle();

    expect(find.text('No Markdown Files Found'), findsOneWidget);
  });
}
