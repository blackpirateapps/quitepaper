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
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/active_filter_chips.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_filter_button.dart';
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

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

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

      await finishTest(tester);
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
      expect(find.text('TAGS'), findsOneWidget);

      // Scroll and Tap Has Code filter
      await tester.scrollUntilVisible(
        find.text('Has Code'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Has Code'));
      await tester.pumpAndSettle();

      // Scroll and Tap Apply Filters
      await tester.scrollUntilVisible(
        find.text('Apply Filters'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Open Filter')));
      final currentFilter = container.read(notesQueryProvider).filter;
      expect(currentFilter.contentFilters.contains(ContentFilter.hasCode), true);
      
      await finishTest(tester);
    });
  });

  group('NotesFilterButton Widget Tests', () {
    testWidgets('displays clean icon when count is 0 and badge when count > 0', (tester) async {
      var tapped = false;

      // Zero active filters
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesFilterButton(
              onPressed: () => tapped = true,
              advancedFilterCount: 0,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
      expect(find.text('0'), findsNothing);

      // Tap button
      await tester.tap(find.byType(NotesFilterButton));
      expect(tapped, true);

      // Two active filters
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotesFilterButton(
              onPressed: () {},
              advancedFilterCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.byTooltip('Filter notes, 2 active filters'), findsOneWidget);

      await finishTest(tester);
    });
  });

  group('ActiveFilterChips Widget Tests', () {
    testWidgets('takes 0 space when only standard tag is selected (no duplication)', (tester) async {
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

      // Set only 1 tag filter (from tag bar)
      container.read(notesQueryProvider.notifier).setTag('simplenote');
      await tester.pumpAndSettle();

      // Should not duplicate the tag or show Clear row
      expect(find.text('#simplenote'), findsNothing);
      expect(find.text('Clear'), findsNothing);

      await finishTest(tester);
    });

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
      expect(find.text('Clear'), findsNothing);

      // Remove Code filter by tapping close icon
      await tester.tap(find.bySemanticsLabel('Remove Code filter'));
      await tester.pumpAndSettle();

      expect(container.read(notesQueryProvider).filter.contentFilters.contains(ContentFilter.hasCode), false);
      expect(container.read(notesQueryProvider).filter.untaggedOnly, true);

      await finishTest(tester);
    });

    testWidgets('collapses to max 2 chips plus +N when many advanced filters active', (tester) async {
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

      // Set 4 advanced filters
      container.read(notesQueryProvider.notifier).setFilters(
            const NotesFilter(
              untaggedOnly: true,
              pinnedOnly: true,
              contentFilters: {ContentFilter.hasCode, ContentFilter.hasChecklist},
            ),
          );

      await tester.pumpAndSettle();

      // Should render at most 2 chips + '+2'
      expect(find.text('Untagged'), findsOneWidget);
      expect(find.text('Pinned only'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.byTooltip('2 additional filters active. Tap to view all filters.'), findsOneWidget);

      await finishTest(tester);
    });
  });

  group('Responsive NotesScreen Header Tests', () {
    testWidgets('header title remains Notes when a tag filter is active', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          child: const NotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(NotesScreen)));
      container.read(selectedTagFilterProvider.notifier).state = 'simplenote';
      container.read(notesQueryProvider.notifier).setTag('simplenote');
      await tester.pumpAndSettle();

      // Title must remain Notes, not #simplenote
      expect(find.text('Notes'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await finishTest(tester);
    });

    testWidgets('tablet middle pane collapses gracefully on narrow constraints', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          child: const NotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notes'), findsWidgets);
      expect(find.byType(NotesFilterButton), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

      await finishTest(tester);
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

      await finishTest(tester);
    });
  });
}
