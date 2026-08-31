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


    testWidgets('renders backlinks section with count and handles note tap', (tester) async {
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

      await tester.tap(find.text('Source Study Guide'));
      await tester.pumpAndSettle();

      expect(tappedNote, isNotNull);
      expect(tappedNote!.id, sourceId);
      expect(tappedNote!.title, 'Source Study Guide');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

  });
}
