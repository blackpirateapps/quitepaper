import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
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

  group('NotesScreen Gestures (Swipe down to search & Swipe from left for sidebar)', () {
    testWidgets('pulling down on notes list triggers SearchScreen navigation',
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

      // Drag down on notes list
      await tester.drag(find.text('Morning Thoughts'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // SearchScreen should now be opened
      expect(find.byType(SearchScreen), findsOneWidget);

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
  });
}
