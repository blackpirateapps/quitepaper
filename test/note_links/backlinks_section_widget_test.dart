import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/editor/presentation/widgets/backlinks_section.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('BacklinksSection Widget Tests', () {
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

    testWidgets('renders completely empty (SizedBox.shrink) when zero backlinks exist', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            onOpenNote: (_) {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('LINKED FROM'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders two-line layout with tags and handles note tap', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Main concept',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Source Study Guide',
        content: 'Check out [Target Note](qp://note/$targetId)',
        tags: ['study', 'math'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      Note? tappedNote;

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            onOpenNote: (note) => tappedNote = note,
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LINKED FROM · 1'), findsOneWidget);
      expect(find.text('Source Study Guide'), findsOneWidget);
      expect(find.textContaining('#study'), findsOneWidget);
      expect(find.textContaining('#math'), findsOneWidget);

      await tester.tap(find.text('Source Study Guide'));

      await tester.pumpAndSettle();

      expect(tappedNote, isNotNull);
      expect(tappedNote!.id, sourceId);
      expect(tappedNote!.title, 'Source Study Guide');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders multiplier badge when multiple links exist from same source', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const sourceId = '99999999-8888-4777-8666-555544443333';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: sourceId,
        title: 'Multi Source',
        content: '[T](qp://note/$targetId) ... [T](qp://note/$targetId) ... [T](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            onOpenNote: (_) {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LINKED FROM · 1'), findsOneWidget);
      expect(find.text('Multi Source'), findsOneWidget);
      expect(find.text('×3'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('collapses to initial limit and expands with smooth animation', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Target Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      // Create 5 source notes
      for (int i = 1; i <= 5; i++) {
        await db.saveNote(
          id: '00000000-0000-4000-8000-00000000000$i',
          title: 'Source Note $i',
          content: 'Link: [Target](qp://note/$targetId)',
          createdAt: DateTime.now().subtract(Duration(minutes: i)),
          updatedAt: DateTime.now().subtract(Duration(minutes: i)),
          isPinned: false,
        );
      }

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            initialMaxVisible: 3,
            onOpenNote: (_) {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LINKED FROM · 5'), findsOneWidget);
      expect(find.text('Source Note 1'), findsOneWidget);
      expect(find.text('Source Note 2'), findsOneWidget);
      expect(find.text('Source Note 3'), findsOneWidget);
      expect(find.text('Source Note 4'), findsNothing);
      expect(find.text('Source Note 5'), findsNothing);
      expect(find.text('Show 2 more'), findsOneWidget);

      // Tap "Show 2 more"
      await tester.tap(find.text('Show 2 more'));
      await tester.pumpAndSettle();

      expect(find.text('Source Note 4'), findsOneWidget);
      expect(find.text('Source Note 5'), findsOneWidget);
      expect(find.text('Show less'), findsOneWidget);

      // Tap "Show less"
      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();

      expect(find.text('Source Note 4'), findsNothing);
      expect(find.text('Show 2 more'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('shows subtle indicator when trashed backlinks exist', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const activeSourceId = '99999999-8888-4777-8666-555544443333';
      const trashedSourceId = '88888888-7777-4666-8555-444433332222';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: activeSourceId,
        title: 'Active Source',
        content: 'Link: [Target](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: trashedSourceId,
        title: 'Trashed Source',
        content: 'Link: [Target](qp://note/$targetId)',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
        isTrashed: true,
        deletedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            onOpenNote: (_) {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('LINKED FROM · 1'), findsOneWidget);
      expect(find.text('Active Source'), findsOneWidget);
      expect(find.text('Trashed Source'), findsNothing);
      expect(find.text('+ 1 in Trash'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders lock icon and preserves privacy for password protected source note', (tester) async {
      const targetId = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
      const protectedSourceId = '99999999-8888-4777-8666-555544443333';
      const protectedContent = '''
<!-- quiet-paper-encrypted-note-v1:{"salt":"s","iv":"i","ct":"c","mac":"m"}-->
Secret body containing [Target](qp://note/$targetId)
''';

      await db.saveNote(
        id: targetId,
        title: 'Target Note',
        content: 'Content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );
      await db.saveNote(
        id: protectedSourceId,
        title: 'Protected Diary',
        content: protectedContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPinned: false,
      );

      await tester.pumpWidget(
        createTestApp(
          child: BacklinksSection(
            noteId: targetId,
            onOpenNote: (_) {},
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Protected Diary'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.textContaining('Secret body'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
