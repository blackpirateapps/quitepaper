import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
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
    List<Override> overrides = const [],
    VoidCallback? onItemSelected,
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
        todayJournalEntryStreamProvider.overrideWith((ref) => Stream.value(null)),
        hasTodayJournalEntryProvider.overrideWithValue(false),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SidebarView(onItemSelected: onItemSelected),
        ),
      ),
    );
  }

  group('SidebarView Journal Section Widget Tests', () {
    testWidgets('renders JOURNAL section with Today and On This Day', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('JOURNAL'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('On This Day'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('tapping On This Day updates currentDestination to AppDestination.onThisDay', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      expect(container.read(currentDestinationProvider), AppDestination.allNotes);

      await tester.tap(find.text('On This Day'));
      await tester.pumpAndSettle();

      expect(container.read(currentDestinationProvider), AppDestination.onThisDay);

      await finishTest(tester);
    });

    testWidgets('tapping Today invokes openOrCreateToday and creates today note if not found', (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
      final todayDate = container.read(todayJournalDateProvider);

      // Tap Today
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // Today entry was created in database
      final entry = await repository.getJournalEntry(todayDate);
      expect(entry, isNotNull);
      expect(entry!.journalDate, todayDate);

      await finishTest(tester);
    });
  });
}

ProviderContainer containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(SidebarView)));
}
