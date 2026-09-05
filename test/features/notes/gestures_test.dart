import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/pull_down_search_reveal.dart';
import 'package:quitepaper/features/search/presentation/search_screen.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/sidebar/presentation/sidebar_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 360 x 800 logical dp
  }

  void setTabletSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(2048, 1536);
    tester.view.devicePixelRatio = 2.0; // 1024 x 768 logical dp
  }

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Widget buildNotesApp({SharedPreferences? prefs}) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        home: NotesScreen(),
      ),
    );
  }

  group('NotesScreen Gestures (Bear Notes Pull-Down Search & Sidebar)', () {
    testWidgets('pulling down on notes list past threshold triggers SearchScreen navigation',
        (tester) async {
      setPhoneSize(tester);

      final now = DateTime.now();
      await repository.saveNote(
        Note(
          id: 'gesture-note-1',
          title: 'Morning Thoughts',
          content: 'Quiet reflections in the morning.',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Morning Thoughts'), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.byType(PullDownSearchReveal), findsOneWidget);

      // Drag down on notes list past threshold
      await tester.drag(find.text('Morning Thoughts'), const Offset(0, 250));
      await tester.pumpAndSettle();

      // SearchScreen should now be opened
      expect(find.byType(SearchScreen), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('pulling down below threshold springs back and does not open SearchScreen',
        (tester) async {
      setPhoneSize(tester);

      final now = DateTime.now();
      await repository.saveNote(
        Note(
          id: 'gesture-note-spring',
          title: 'Spring Test',
          content: 'Should spring back when small pull.',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Spring Test'), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);

      // Micro drag down (small offset < threshold of 70)
      await tester.drag(find.text('Spring Test'), const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // SearchScreen should not be opened
      expect(find.byType(SearchScreen), findsNothing);
      expect(find.text('Spring Test'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('pulling down on empty state triggers SearchScreen navigation',
        (tester) async {
      setPhoneSize(tester);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);

      // Drag down on empty state
      await tester.drag(find.text('No notes yet'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // SearchScreen should be opened
      expect(find.byType(SearchScreen), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('verifies zero RefreshIndicator widgets are present on NotesScreen',
        (tester) async {
      setPhoneSize(tester);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Confirm no Material RefreshIndicator spinner exists on NotesScreen
      expect(find.byType(RefreshIndicator), findsNothing);

      await finishTest(tester);
    });

    testWidgets('pulling down on tablet split-view triggers SearchScreen navigation',
        (tester) async {
      setTabletSize(tester);

      final now = DateTime.now();
      await repository.saveNote(
        Note(
          id: 'gesture-note-tablet',
          title: 'Tablet Note',
          content: 'Tablet layout testing.',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Tablet Note'), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);

      // Drag down on tablet notes column
      await tester.drag(find.text('Tablet Note'), const Offset(0, 250));
      await tester.pumpAndSettle();

      // SearchScreen should be opened
      expect(find.byType(SearchScreen), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('tapping Search icon in AppBar opens SearchScreen',
        (tester) async {
      setPhoneSize(tester);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsNothing);

      // Tap search icon in AppBar
      await tester.tap(find.byTooltip('Search notes'));
      await tester.pumpAndSettle();

      expect(find.byType(SearchScreen), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('swiping from left edge on phone opens sidebar navigation drawer',
        (tester) async {
      setPhoneSize(tester);

      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Drawer is initially closed (SidebarView not visible in render tree)
      expect(find.text('LIBRARY'), findsNothing);

      // Swipe / fling from left edge
      await tester.flingFrom(const Offset(0, 300), const Offset(300, 0), 1000);
      await tester.pumpAndSettle();

      // SidebarView drawer is now opened and visible
      expect(find.byType(SidebarView), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets(
        'pulling down on notes list when swipeDownToSearchNotes is disabled does not open SearchScreen',
        (tester) async {
      setPhoneSize(tester);

      final now = DateTime.now();
      await repository.saveNote(
        Note(
          id: 'gesture-disabled-search',
          title: 'Disabled Gesture Note',
          content: 'Swipe down should not trigger search.',
          createdAt: now,
          updatedAt: now,
        ),
      );

      SharedPreferences.setMockInitialValues({
        'setting_swipe_down_to_search_notes': false,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(buildNotesApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('Disabled Gesture Note'), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);

      // Drag down on notes list past threshold
      await tester.drag(find.text('Disabled Gesture Note'), const Offset(0, 250));
      await tester.pumpAndSettle();

      // SearchScreen should NOT be opened
      expect(find.byType(SearchScreen), findsNothing);

      await finishTest(tester);
    });
  });
}
