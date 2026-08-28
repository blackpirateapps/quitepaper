import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/app.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/notes_query_provider.dart';
import 'package:quitepaper/features/notes/application/saved_filters_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/domain/notes_sort.dart';
import 'package:quitepaper/features/notes/presentation/widgets/active_filter_chips.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_filter_sheet.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_sort_sheet.dart';
import 'package:quitepaper/features/notes/presentation/widgets/saved_filters_sheet.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  late AppDatabase db;
  late DriftNotesRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({
    Widget? child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
        allTagsStreamProvider.overrideWith((ref) => Stream.value([])),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child ?? const QuietPaperApp(),
        ),
      ),
    );
  }

  group('NotesSortSheet Widget Tests', () {
    testWidgets('renders sort options and selects Recently Created', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NotesSortSheet.show(context),
              child: const Text('Open Sort'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sort'));
      await tester.pumpAndSettle();

      expect(find.text('SORT BY'), findsOneWidget);
      expect(find.text('Recently Updated'), findsOneWidget);
      expect(find.text('Recently Created'), findsOneWidget);
      expect(find.text('Title'), findsOneWidget);

      // Tap Recently Created
      await tester.tap(find.text('Recently Created'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(NotesSortSheet)));
      final currentSort = container.read(notesQueryProvider).sort;
      expect(currentSort.field, SortField.created);
    });
  });

  group('NotesFilterSheet Widget Tests', () {
    testWidgets('renders sections and allows toggling content filter and applying', (tester) async {
      final t0 = DateTime.now();
      await repository.saveNote(Note(
        id: 'n1',
        title: 'Note with Code',
        content: '```dart\nmain() {}\n```',
        createdAt: t0,
        updatedAt: t0,
        tags: const ['dev'],
      ));

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NotesFilterSheet.show(context),
              child: const Text('Open Filter'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Filter'));
      await tester.pumpAndSettle();

      expect(find.text('FILTERS'), findsOneWidget);
      expect(find.text('Has Checklists'), findsOneWidget);

      // Scroll to and toggle Has Code
      await tester.ensureVisible(find.text('Has Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Has Code'));
      await tester.pumpAndSettle();

      // Scroll to and tap Apply Filters
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Open Filter')));
      final currentFilter = container.read(notesQueryProvider).filter;
      expect(currentFilter.contentFilters.contains(ContentFilter.hasCode), true);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('ActiveFilterChips Widget Tests', () {
    testWidgets('renders active chips and removes individual filter on tap', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const Column(
            children: [
              ActiveFilterChips(),
            ],
          ),
        ),
      );

      final element = tester.element(find.byType(ActiveFilterChips));
      final container = ProviderScope.containerOf(element);

      // Set filter with Has Code and Untagged
      container.read(notesQueryProvider.notifier).setFilters(
            const NotesFilter(
              untaggedOnly: true,
              contentFilters: {ContentFilter.hasCode},
            ),
          );

      await tester.pumpAndSettle();

      expect(find.text('Untagged'), findsOneWidget);
      expect(find.text('Code'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      // Tap Clear to reset
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(container.read(notesQueryProvider).filter.isEmpty, true);
    });
  });

  group('SavedFiltersSheet & Service Tests', () {
    testWidgets('creates, lists, and applies saved smart view', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => SavedFiltersSheet.show(context),
              child: const Text('Open Saved Views'),
            ),
          ),
        ),
      );

      final element = tester.element(find.text('Open Saved Views'));
      final container = ProviderScope.containerOf(element);

      // Create a saved filter programmatically
      await container.read(savedFiltersProvider.notifier).create(
            name: 'Important Work',
            query: const NotesQuery(
              filter: NotesFilter(
                tags: {'work'},
                pinnedOnly: true,
              ),
            ),
          );

      await tester.tap(find.text('Open Saved Views'));
      await tester.pumpAndSettle();

      expect(find.text('SAVED SMART VIEWS'), findsOneWidget);
      expect(find.text('Important Work'), findsOneWidget);

      // Tap to apply
      await tester.tap(find.text('Important Work'));
      await tester.pumpAndSettle();

      final currentQuery = container.read(notesQueryProvider);
      expect(currentQuery.filter.tags, const {'work'});
      expect(currentQuery.filter.pinnedOnly, true);
    });
  });
}
