import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/domain/rich_document.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/editor_stats_dialog.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EditorStatsDialog Note Details Format Tests', () {
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

    Future<void> finishTest(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('EditorStatsDialog displays Rich text format for RichDocument JSON note', (tester) async {
      final jsonNote = Note(
        id: 'json-1',
        title: 'Rich Note',
        content: jsonEncode({
          '\$schema': RichDocument.schemaId,
          'blocks': [
            {
              'type': 'paragraph',
              'spans': [{'text': 'Hello visual world'}],
            },
          ],
        }),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
        tags: ['rich', 'visual'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
          home: Scaffold(
            body: EditorStatsDialog(note: jsonNote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note details'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Rich text'), findsOneWidget);
      expect(find.text('Plain markdown'), findsNothing);
      expect(find.text('#rich, #visual'), findsOneWidget);
    });

    testWidgets('EditorStatsDialog displays Plain markdown format for Markdown note', (tester) async {
      final mdNote = Note(
        id: 'md-1',
        title: 'Markdown Note',
        content: '# Heading\nThis is plain markdown text.',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 2),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [AppColors.light]),
          home: Scaffold(
            body: EditorStatsDialog(note: mdNote),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Note details'), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Plain markdown'), findsOneWidget);
      expect(find.text('Rich text'), findsNothing);
    });

    testWidgets('Editor overflow menu "Note details" shows format in dialog', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'details-dialog-test',
        title: 'Markdown Note',
        content: 'Testing note details from 3-dot overflow menu.',
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: EditorScreen(note: note),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open 3-dot overflow menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Scroll into view if needed and tap "Note details"
      final noteDetailsTile = find.text('Note details');
      expect(noteDetailsTile, findsOneWidget);
      await tester.ensureVisible(noteDetailsTile);
      await tester.pumpAndSettle();
      await tester.tap(noteDetailsTile);
      await tester.pumpAndSettle();

      // Dialog is shown with Note details and Format
      expect(find.byType(EditorStatsDialog), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Plain markdown'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorStatsDialog), findsNothing);

      await finishTest(tester);
    });

    testWidgets('Editor overflow menu "Note details" shows Rich text for rich note', (tester) async {
      final now = DateTime.now();
      final note = Note(
        id: 'details-dialog-rich-test',
        title: 'Rich Text Note',
        content: jsonEncode({
          '\$schema': RichDocument.schemaId,
          'blocks': [
            {
              'type': 'paragraph',
              'spans': [{'text': 'Rich content body'}],
            },
          ],
        }),
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveNote(note);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            home: EditorScreen(note: note),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open 3-dot overflow menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      // Scroll into view if needed and tap "Note details"
      final noteDetailsTile = find.text('Note details');
      expect(noteDetailsTile, findsOneWidget);
      await tester.ensureVisible(noteDetailsTile);
      await tester.pumpAndSettle();
      await tester.tap(noteDetailsTile);
      await tester.pumpAndSettle();

      // Dialog is shown with Note details and Rich text
      expect(find.byType(EditorStatsDialog), findsOneWidget);
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('Rich text'), findsOneWidget);
      expect(find.text('Plain markdown'), findsNothing);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorStatsDialog), findsNothing);

      await finishTest(tester);
    });
  });
}
