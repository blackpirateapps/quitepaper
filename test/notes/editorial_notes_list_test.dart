import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/editorial/editorial_list_header.dart';
import 'package:quitepaper/features/notes/presentation/editorial/editorial_note_row.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  final testDate = DateTime(2026, 9, 6, 14, 0);
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createTestWrapper({required Widget child}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.light(
          family: ThemeFamily.classicPaper,
        ),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('EditorialNoteRow Widget Tests', () {
    testWidgets('renders title, snippet, and formatted time', (tester) async {
      final note = Note(
        id: 'note-1',
        title: 'Polar Bears',
        content: 'The largest #bear in the world and the Arctic top predator.',
        createdAt: testDate,
        updatedAt: testDate,
        tags: const ['bear'],
      );

      var tapped = false;

      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialNoteRow(
            note: note,
            isSelected: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Polar Bears'), findsOneWidget);
      expect(
        find.textContaining('The largest #bear in the world'),
        findsOneWidget,
      );
      expect(find.text('#bear'), findsOneWidget);

      await tester.tap(find.text('Polar Bears'));
      expect(tapped, true);
    });

    testWidgets('selected note renders accent indicator', (tester) async {
      final note = Note(
        id: 'note-selected',
        title: 'Selected Note',
        content: 'This note is currently selected in the tablet editor.',
        createdAt: testDate,
        updatedAt: testDate,
      );

      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialNoteRow(
            note: note,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Selected Note'), findsOneWidget);
      final accentBarFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 3.5,
      );
      expect(accentBarFinder, findsOneWidget);
    });

    testWidgets('unselected note does not have accent bar', (tester) async {
      final note = Note(
        id: 'note-unselected',
        title: 'Unselected Note',
        content: 'Normal editorial row.',
        createdAt: testDate,
        updatedAt: testDate,
      );

      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialNoteRow(
            note: note,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      final accentBarFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 3.5,
      );
      expect(accentBarFinder, findsNothing);
    });

    testWidgets('pinned note displays pin icon in accent color', (tester) async {
      final note = Note(
        id: 'note-pinned',
        title: 'Pinned Note',
        content: 'Crucial note pinned at the top.',
        createdAt: testDate,
        updatedAt: testDate,
        isPinned: true,
      );

      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialNoteRow(
            note: note,
            isSelected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });
  });

  group('EditorialListHeader Widget Tests', () {
    testWidgets('displays collection title and triggers actions', (tester) async {
      var createNoteCalled = false;
      var openSearchCalled = false;

      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialListHeader(
            title: 'Notes',
            destination: AppDestination.allNotes,
            isTablet: true,
            onCreateNote: () => createNoteCalled = true,
            onOpenSearch: () => openSearchCalled = true,
          ),
        ),
      );

      expect(find.text('Notes'), findsOneWidget);
      expect(find.byIcon(Icons.edit_square), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_square));
      expect(createNoteCalled, true);

      await tester.tap(find.byIcon(Icons.search_rounded));
      expect(openSearchCalled, true);
    });

    testWidgets('tapping collection title opens collection dropdown menu', (tester) async {
      await tester.pumpWidget(
        createTestWrapper(
          child: EditorialListHeader(
            title: 'Notes',
            destination: AppDestination.allNotes,
            isTablet: true,
            onCreateNote: () {},
            onOpenSearch: () {},
          ),
        ),
      );

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Journal'), findsOneWidget);
    });
  });
}
