import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/app.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/onboarding/application/onboarding_provider.dart';
import 'package:quitepaper/features/onboarding/presentation/widgets/onboarding_success_page.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
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

  void setPhoneSize(WidgetTester tester, {double width = 360, double height = 800}) {
    tester.view.physicalSize = Size(width * 3.0, height * 3.0);
    tester.view.devicePixelRatio = 3.0;
  }

  Future<void> finishTest(WidgetTester tester) async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  }

  Widget buildTestApp({SharedPreferences? prefs, Widget? home}) {
    return ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: home != null
          ? MaterialApp(
              home: home,
            )
          : const QuietPaperApp(),
    );
  }

  group('OnboardingScreen Widget Tests', () {
    testWidgets('1. Fresh prefs shows Welcome page with all links and Skip', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      expect(find.text('A quiet place to think.'), findsOneWidget);
      expect(find.text('Come on in'), findsOneWidget);
      expect(find.text('Restore a backup'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.byKey(const Key('onboarding-skip')), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('2. All eight pages advance with correct primary labels and titles', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Page 1: Welcome
      expect(find.text('A quiet place to think.'), findsOneWidget);
      expect(find.text('Come on in'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 2: Privacy
      expect(find.text('Your words. Your business.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 3: Voice
      expect(find.text('Talk. We’ll take notes.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 4: Simplicity
      expect(find.text('No folders. No filing. No guilt.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 5: OCR
      expect(find.text('Paper in. Words out.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 6: Optional sync (signed out)
      expect(find.text('Same notes. Every device. Still private.'), findsOneWidget);
      expect(find.text('Keep it local'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 7: Make it yours
      expect(find.text('A desk that feels like yours.'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding-primary')));
      await tester.pumpAndSettle();

      // Page 8: Ready when you are
      expect(find.text('Ready when you are.'), findsOneWidget);
      expect(find.text('Show me around'), findsOneWidget);
      expect(find.text("I'll find my way"), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('3. Skip persists and lands on NotesScreen', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap Skip
      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();

      expect(find.text('All Notes'), findsOneWidget);
      expect(find.text('No notes yet'), findsOneWidget);
      expect(prefs.getBool(OnboardingKeys.completed), isTrue);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isTrue);

      await finishTest(tester);
    });

    testWidgets('4. Show me around persists completed: true, tourSeen: false and shows coach marks', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to page 8 (7 next taps)
      for (int i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Ready when you are.'), findsOneWidget);
      await tester.tap(find.text('Show me around'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(OnboardingKeys.completed), isTrue);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isFalse);
      expect(find.text('YOUR LIBRARY'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('5. Theme choices persist', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to page 7 (6 next taps)
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
      }

      expect(find.text('A desk that feels like yours.'), findsOneWidget);

      // Tap Warm Paper
      final warmBtn = find.byKey(const Key('onboarding-paper-warm'));
      await tester.ensureVisible(warmBtn);
      await tester.tap(warmBtn);
      await tester.pumpAndSettle();
      expect(prefs.getString('app_theme_family'), 'warm_paper');

      // Tap Dark
      final darkBtn = find.byKey(const Key('onboarding-appearance-dark'));
      await tester.ensureVisible(darkBtn);
      await tester.tap(darkBtn);
      await tester.pumpAndSettle();
      expect(prefs.getString('app_appearance_mode'), 'dark');

      await finishTest(tester);
    });

    testWidgets('6. Sample notes load when DB is empty', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to page 7
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
      }

      final loadBtn = find.byKey(const Key('onboarding-sample-load'));
      expect(loadBtn, findsOneWidget);
      await tester.ensureVisible(loadBtn);
      await tester.tap(loadBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sample notes are on the desk.'), findsOneWidget);
      expect(find.text('Five little examples, ready to poke around in.'), findsOneWidget);

      final notes = await db.getAllNotesRaw();
      expect(notes.length, 5);

      await finishTest(tester);
    });

    testWidgets('7. Sample block shows "Your desk already has notes." when notes exist', (tester) async {
      // Seed one note
      final now = DateTime.now();
      await repository.saveNote(
        Note(
          id: 'note-1',
          title: 'Existing Note',
          content: 'Hello world',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Navigate to page 7
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const Key('onboarding-primary')));
        await tester.pumpAndSettle();
      }

      expect(find.text('Your desk already has notes.'), findsOneWidget);
      expect(find.text("We'll leave your library just as it is."), findsOneWidget);
      expect(find.byKey(const Key('onboarding-sample-load')), findsNothing);

      await finishTest(tester);
    });

    testWidgets('8. Welcome auth links open correct auth views', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      // Tap Sign in
      final signInBtn = find.byKey(const Key('onboarding-welcome-sign-in'));
      await tester.ensureVisible(signInBtn);
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();
      expect(find.text('Sign In to Quiet Paper'), findsOneWidget);

      // Back to onboarding
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('A quiet place to think.'), findsOneWidget);

      // Tap Create account
      final createAccountBtn = find.byKey(const Key('onboarding-welcome-create-account'));
      await tester.ensureVisible(createAccountBtn);
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();
      expect(find.text('What is your email address?'), findsOneWidget);

      // Back to onboarding
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('A quiet place to think.'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('9. Success page copy for sync and restore variants', (tester) async {
      // Sync success
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingSuccessPage(
              kind: OnboardingSuccessKind.sync,
              email: 'writer@quietpaper.app',
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ALL SET'), findsOneWidget);
      expect(find.text('You’re in.'), findsOneWidget);
      expect(
        find.text(
          'Your notes will sync quietly in the background. Pick up on another device whenever you like.',
        ),
        findsOneWidget,
      );
      expect(find.text('Signed in as writer@quietpaper.app.'), findsOneWidget);

      // Restore 1 note (singular)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingSuccessPage(
              kind: OnboardingSuccessKind.restore,
              restoredCount: 1,
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome back.'), findsOneWidget);
      expect(find.text('Your backup is home. We put back 1 note and their tags.'), findsOneWidget);

      // Restore multiple notes (plural)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingSuccessPage(
              kind: OnboardingSuccessKind.restore,
              restoredCount: 42,
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your backup is home. We put back 42 notes and their tags.'), findsOneWidget);

      // Restore 0 notes
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnboardingSuccessPage(
              kind: OnboardingSuccessKind.restore,
              restoredCount: 0,
              onContinue: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your backup is home. Everything is right where you left it.'), findsOneWidget);
    });

    testWidgets('10. Small-phone layout (320x568) has no overflow across all 8 pages', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      setPhoneSize(tester, width: 320, height: 568);

      await tester.pumpWidget(buildTestApp(prefs: prefs));
      await tester.pumpAndSettle();

      for (int i = 0; i < 8; i++) {
        expect(tester.takeException(), isNull);
        if (i < 7) {
          await tester.tap(find.byKey(const Key('onboarding-primary')));
          await tester.pumpAndSettle();
        }
      }

      await finishTest(tester);
    });
  });
}
