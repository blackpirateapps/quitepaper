import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';

void main() {
  final testNow = DateTime(2026, 11, 5, 12, 0, 0);

  group('Notes Scroll Performance & Pre-warming Tests', () {
    setUp(() {
      NoteMetadataExtractor.clearCache();
    });

    test('NoteMetadataExtractor.prewarmAll pre-populates LRU cache for all notes', () {
      final notes = List.generate(
        10,
        (i) => Note(
          id: 'perf-note-$i',
          title: 'Performance Note $i',
          content: 'Body content for performance test $i with some metadata.',
          createdAt: testNow,
          updatedAt: testNow,
        ),
      );

      expect(NoteMetadataExtractor.cacheSize, equals(0));

      // Prewarm all notes
      NoteMetadataExtractor.prewarmAll(notes);

      expect(NoteMetadataExtractor.cacheSize, equals(10));

      // Calling extract on any prewarmed note should hit the cache immediately
      for (final note in notes) {
        final meta = NoteMetadataExtractor.extract(note);
        expect(meta.displayTitle, note.title);
      }

      // Cache size remains 10 (no new entries created)
      expect(NoteMetadataExtractor.cacheSize, equals(10));
    });

    testWidgets('NoteListTile uses localized hover notifier and RepaintBoundary', (tester) async {
      final note = Note(
        id: 'hover-perf-note',
        title: 'Hover Performance',
        content: 'Testing localized hover state management without full rebuilds.',
        createdAt: testNow,
        updatedAt: testNow,
      );

      NoteMetadataExtractor.clearCache();
      NoteMetadataExtractor.extract(note);
      expect(NoteMetadataExtractor.cacheSize, equals(1));

      final themeData = AppTheme.light(family: ThemeFamily.classicPaper);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: NoteListTile(
                note: note,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify that RepaintBoundary wraps the tile
      expect(find.byType(RepaintBoundary), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(NoteListTile),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );

      // Verify ValueListenableBuilder exists for localized hover
      expect(
        find.descendant(
          of: find.byType(NoteListTile),
          matching: find.byType(ValueListenableBuilder<bool>),
        ),
        findsOneWidget,
      );

      // Simulate mouse pointer entering and exiting
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final tileCenter = tester.getCenter(find.byType(NoteListTile));

      // Move into tile
      await gesture.moveTo(tileCenter);
      await tester.pump();

      // Move out of tile
      await gesture.moveTo(Offset.zero);
      await tester.pump();

      // Ensure cache was not dirtied or recomputed
      expect(NoteMetadataExtractor.cacheSize, equals(1));
    });
  });
}
