import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/saved_filters_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/notes_filter.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/sidebar/presentation/sidebar_view.dart';

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
        activeNotesCountProvider.overrideWith((ref) => Stream.value(0)),
        pinnedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
        archivedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
        trashedNotesCountProvider.overrideWith((ref) => Stream.value(0)),
        allTagsStreamProvider.overrideWith((ref) => Stream.value([])),
        hasTodayJournalEntryProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child ?? const SidebarView(),
        ),
      ),
    );
  }

  group('SidebarView Smart Views Integration Tests', () {
    testWidgets('renders smart views section with manage button and opens SavedFiltersSheet', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      await container.read(savedFiltersProvider.notifier).create(
            name: 'Starred Ideas',
            query: const NotesQuery(
              filter: NotesFilter(pinnedOnly: true),
            ),
          );

      await tester.pumpAndSettle();

      expect(find.text('SMART VIEWS'), findsOneWidget);
      expect(find.text('Starred Ideas'), findsOneWidget);
      expect(find.byTooltip('Manage smart views'), findsOneWidget);

      // Tap manage button on header
      await tester.tap(find.byTooltip('Manage smart views'));
      await tester.pumpAndSettle();

      // SavedFiltersSheet opens
      expect(find.text('SAVED SMART VIEWS'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('long-pressing smart view item opens options and allows renaming', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      await container.read(savedFiltersProvider.notifier).create(
            name: 'Weekly Review',
            query: const NotesQuery(
              filter: NotesFilter(tags: {'review'}),
            ),
          );

      await tester.pumpAndSettle();

      // Long press on Weekly Review
      await tester.longPress(find.text('Weekly Review'));
      await tester.pumpAndSettle();

      // Action sheet appears with Rename and Delete
      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Rename
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      expect(find.text('Rename Smart View'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Monthly Review');
      await tester.tap(find.widgetWithText(QuietButton, 'Save'));
      await tester.pumpAndSettle();

      // Updated name appears in sidebar
      expect(find.text('Monthly Review'), findsOneWidget);
      expect(find.text('Weekly Review'), findsNothing);

      await finishTest(tester);
    });

    testWidgets('long-pressing smart view item opens options and allows deleting with confirmation', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createTestWidget());

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      await container.read(savedFiltersProvider.notifier).create(
            name: 'Temp View',
            query: const NotesQuery(
              filter: NotesFilter(untaggedOnly: true),
            ),
          );

      await tester.pumpAndSettle();

      expect(find.text('Temp View'), findsOneWidget);

      // Long press
      await tester.longPress(find.text('Temp View'));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete Smart View'), findsOneWidget);
      expect(find.text('Are you sure you want to delete "Temp View"? This cannot be undone.'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Item is still in sidebar
      expect(find.text('Temp View'), findsOneWidget);

      // Long press again and delete
      await tester.longPress(find.text('Temp View'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(QuietButton, 'Delete'));
      await tester.pumpAndSettle();

      // Item and section are removed
      expect(find.text('Temp View'), findsNothing);
      expect(find.text('SMART VIEWS'), findsNothing);
      expect(find.text('Smart view "Temp View" deleted'), findsOneWidget);

      await finishTest(tester);
    });
  });
}
