import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/app.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/onboarding/application/onboarding_provider.dart';
import 'package:quitepaper/features/onboarding/presentation/coach_marks/onboarding_coach_marks.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      OnboardingKeys.completed: true,
      OnboardingKeys.tourSeen: false,
    });
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

  Widget buildTestApp({SharedPreferences? prefs, bool showOnboardingTour = true}) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const QuietPaperApp(),
    );
  }

  group('Coach Marks & Editor Tips Tests', () {
    testWidgets('1. Shows three steps in sequence', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Step 1: YOUR LIBRARY
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('YOUR LIBRARY'), findsOneWidget);
      expect(find.text('Everything, in one place.'), findsOneWidget);
      expect(
        find.text(
          'All notes, pinned, archive, and tags live here. One list. No filing system required.',
        ),
        findsOneWidget,
      );

      // Advance to Step 2
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();

      // Step 2: FIND ANYTHING
      expect(find.text('2 of 3'), findsOneWidget);
      expect(find.text('FIND ANYTHING'), findsOneWidget);
      expect(find.text('Find it in a blink.'), findsOneWidget);
      expect(
        find.text(
          'Search titles, text, and tags—fully offline. Even the words inside your scans.',
        ),
        findsOneWidget,
      );

      // Advance to Step 3
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();

      // Step 3: THE FRONT DOOR
      expect(find.text('3 of 3'), findsOneWidget);
      expect(find.text('THE FRONT DOOR'), findsOneWidget);
      expect(find.text('This is where notes begin.'), findsOneWidget);
      expect(
        find.text(
          'Tap it whenever a thought arrives—or let us make the first one for you.',
        ),
        findsOneWidget,
      );
      expect(find.text('Create my first note'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('2. Skip tour dismisses overlay and persists tourSeen = true', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding-coach-skip')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-coach-skip')));
      await tester.pumpAndSettle();

      expect(find.text('YOUR LIBRARY'), findsNothing);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isTrue);

      await finishTest(tester);
    });

    testWidgets('3. Create my first note creates note in DB, opens editor with tips card', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Advance to Step 3
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();

      // Tap Create my first note
      await tester.tap(find.byKey(const Key('onboarding-coach-create')));
      await tester.pumpAndSettle();

      // Verify note is created in DB
      final notes = await db.getAllNotesRaw();
      expect(notes.length, 1);

      // Verify editor tips banner is displayed
      expect(find.text('A few quiet tricks'), findsOneWidget);
      expect(find.text('• No save button—everything saves as you type.'), findsOneWidget);
      expect(find.text('• Type #tag anywhere to organize.'), findsOneWidget);
      expect(find.text('• Skip the title? The first line becomes it.'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('4. Dismiss editor tips with "Got it"', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Advance to Step 3 and create note
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding-coach-create')));
      await tester.pumpAndSettle();

      expect(find.text('A few quiet tricks'), findsOneWidget);

      // Tap "Got it"
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      expect(find.text('A few quiet tricks'), findsNothing);

      await finishTest(tester);
    });

    testWidgets('5. Fallback: missing target keys does not crash and allows advancing', (tester) async {
      final sidebarKey = GlobalKey();
      final searchKey = GlobalKey();
      final createKey = GlobalKey();

      bool noteCreated = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingCoachMarks(
              sidebarTarget: sidebarKey,
              searchTarget: searchKey,
              createTarget: createKey,
              isTablet: false,
              onCreateFirstNote: () => noteCreated = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR LIBRARY'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();

      expect(find.text('FIND ANYTHING'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-coach-next')));
      await tester.pumpAndSettle();

      expect(find.text('THE FRONT DOOR'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-coach-create')));
      await tester.pumpAndSettle();

      expect(noteCreated, isTrue);
      expect(dismissed, isFalse);
    });
  });
}
