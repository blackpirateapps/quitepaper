import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/editor/presentation/widgets/backlinks_section.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('Note Link Navigation & Preview Mode Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.memory();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({
      required Widget child,
    }) {
      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child,
          ),
        ),
      );
    }

    testWidgets('clicking note link in QuietMarkdownPreview invokes onOpenLinkedNote with initialPreviewMode true', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      await db.saveNote(
        id: targetId,
        title: 'Target Architecture',
        content: 'Deep architectural details.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      Note? openedNote;
      bool? openedInPreview;

      await tester.pumpWidget(
        createTestApp(
          child: QuietMarkdownPreview(
            markdownData: 'Check [Target Architecture](qp://note/$targetId)',
            onOpenLinkedNote: (Note note, {bool initialPreviewMode = true}) {
              openedNote = note;
              openedInPreview = initialPreviewMode;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      final markdownBodies = tester.widgetList<MarkdownBody>(find.byType(MarkdownBody));
      expect(markdownBodies.isNotEmpty, isTrue);

      // Trigger link tap directly
      markdownBodies.first.onTapLink?.call('Target Architecture', 'qp://note/$targetId', '');
      await tester.pumpAndSettle();

      expect(openedNote, isNotNull);
      expect(openedNote!.id, targetId);
      expect(openedNote!.title, 'Target Architecture');
      expect(openedInPreview, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });


    testWidgets('EditorScreen does NOT display BacklinksSection in edit mode', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Main Topic',
        content: 'Main body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Referencing Note',
        content: 'References [Main Topic](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final note = Note(
        id: targetId,
        title: 'Main Topic',
        content: 'Main body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Render EditorScreen in edit mode (initialPreviewMode: false)
      await tester.pumpWidget(
        createTestApp(
          child: EditorScreen(
            note: note,
            initialPreviewMode: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // BacklinksSection should NOT exist in the widget tree in edit mode
      expect(find.byType(BacklinksSection), findsNothing);
      expect(find.textContaining('LINKED FROM'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('EditorScreen DOES display BacklinksSection in preview mode', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Main Topic',
        content: 'Main body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Referencing Note',
        content: 'References [Main Topic](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      final note = Note(
        id: targetId,
        title: 'Main Topic',
        content: 'Main body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );


      // Render EditorScreen in preview mode (initialPreviewMode: true)
      await tester.pumpWidget(
        createTestApp(
          child: EditorScreen(
            note: note,
            initialPreviewMode: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // BacklinksSection should be present in preview mode
      expect(find.byType(BacklinksSection), findsOneWidget);
      expect(find.text('LINKED FROM · 1'), findsOneWidget);
      expect(find.text('Referencing Note'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
