import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/domain/notes_query.dart';
import 'package:quitepaper/features/notes/presentation/notes_screen.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  void setPhoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
  }

  Widget buildNotesApp() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: NotesScreen()),
    );
  }

  Future<void> seedNotes() async {
    final now = DateTime.now();
    await repository.saveNote(
      Note(
        id: 'ms-1',
        title: 'Alpha Note',
        content: 'First note body',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveNote(
      Note(
        id: 'ms-2',
        title: 'Beta Note',
        content: 'Second note body',
        createdAt: now.subtract(const Duration(minutes: 1)),
        updatedAt: now.subtract(const Duration(minutes: 1)),
      ),
    );
    await repository.saveNote(
      Note(
        id: 'ms-3',
        title: 'Gamma Note',
        content: 'Third note body',
        createdAt: now.subtract(const Duration(minutes: 2)),
        updatedAt: now.subtract(const Duration(minutes: 2)),
      ),
    );
  }

  group('Notes multi-select entry & batch actions', () {
    testWidgets('no Select text action in the app bar', (tester) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      expect(find.text('Select'), findsNothing);
      expect(find.byIcon(PhosphorIconsRegular.plus), findsOneWidget);
      expect(find.byIcon(PhosphorIconsRegular.magnifyingGlass), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('long-press on mobile enters multi-select with note selected', (
      tester,
    ) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Note'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Tap another note to toggle selection
      await tester.tap(find.text('Beta Note'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('Escape exits multi-select', (tester) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Note'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.text('All Notes'), findsOneWidget);

      await finishTest(tester);
    });

    testWidgets('destination change clears multi-select', (tester) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Note'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // Multi-select replaces the app bar (including the drawer button), so
      // simulate a destination change from navigation elsewhere in the app.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(NotesScreen)),
      );
      container.read(currentDestinationProvider.notifier).state =
          AppDestination.archive;
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.text('Archive'), findsWidgets);

      await finishTest(tester);
    });

    testWidgets('batch archive moves selected notes out of All Notes', (
      tester,
    ) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Note'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beta Note'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.byTooltip('Archive selected'));
      await tester.pumpAndSettle();

      expect(find.text('2 notes archived'), findsOneWidget);
      expect(find.text('Alpha Note'), findsNothing);
      expect(find.text('Beta Note'), findsNothing);
      expect(find.text('Gamma Note'), findsOneWidget);

      final remaining = await repository.executeNotesQuery(
        NotesQuery.defaultQuery,
      );
      expect(remaining.notes.length, 1);
      expect(remaining.notes.first.title, 'Gamma Note');

      final alpha = await repository.getNoteById('ms-1');
      expect(alpha?.isArchived, isTrue);

      await finishTest(tester);
    });

    testWidgets('batch trash moves selected notes to trash', (tester) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Alpha Note'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Move to Trash'));
      await tester.pumpAndSettle();

      expect(find.text('Note moved to Trash'), findsOneWidget);
      expect(find.text('Alpha Note'), findsNothing);

      final trashed = await repository.getNoteById('ms-1');
      expect(trashed?.isTrashed, isTrue);

      await finishTest(tester);
    });

    testWidgets('More menu Select notes enters multi-select', (tester) async {
      setPhoneSize(tester);
      await seedNotes();

      await tester.pumpWidget(buildNotesApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(PhosphorIconsRegular.dotsThreeVertical));
      await tester.pumpAndSettle();
      expect(find.text('Select notes'), findsOneWidget);

      await tester.tap(find.text('Select notes'));
      await tester.pumpAndSettle();

      expect(find.text('Select notes'), findsOneWidget); // multi-select title
      expect(find.byIcon(PhosphorIconsRegular.x), findsOneWidget);

      await finishTest(tester);
    });
  });

  group('NoteListTile multi-select gestures', () {
    testWidgets(
      'desktop context menu includes Select and enters via callback',
      (tester) async {
        final themeData = AppTheme.light(family: ThemeFamily.classicPaper);
        final note = Note(
          id: 'note-select-1',
          title: 'Selectable Note',
          content: 'Body',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

        var enterCalled = false;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: themeData,
              home: Scaffold(
                body: NoteListTile(
                  note: note,
                  onTap: () {},
                  onEnterMultiSelect: () => enterCalled = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Selectable Note'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();

        expect(find.text('Select'), findsOneWidget);
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();

        expect(enterCalled, isTrue);
      },
    );

    testWidgets('long-press calls onEnterMultiSelect on non-desktop', (
      tester,
    ) async {
      // Force Android platform so long-press enters selection instead of menu.
      final themeData = AppTheme.light(
        family: ThemeFamily.classicPaper,
      ).copyWith(platform: TargetPlatform.android);
      final note = Note(
        id: 'note-lp-1',
        title: 'Long Press Note',
        content: 'Body',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      var enterCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: NoteListTile(
                note: note,
                onTap: () {},
                onEnterMultiSelect: () => enterCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Long Press Note'));
      await tester.pumpAndSettle();

      expect(enterCalled, isTrue);
      expect(find.text('Archive note'), findsNothing);
    });
  });
}
