import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/widgets/quiet_tag_chip.dart';
import 'package:quitepaper/features/editor/presentation/widgets/tag_editor_bar.dart';
import 'package:quitepaper/features/editor/presentation/widgets/tag_inline_menu.dart';
import 'package:quitepaper/features/tags/domain/tag_model.dart';

void main() {
  group('TagInlineMenu Widget Tests', () {
    final now = DateTime.now();
    final tag1 = Tag(
      id: '1',
      name: 'apple',
      createdAt: now,
      updatedAt: now,
      noteCount: 3,
    );
    final tag2 = Tag(
      id: '2',
      name: 'application',
      createdAt: now,
      updatedAt: now,
      noteCount: 7,
    );

    Widget createTestApp({required Widget child}) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders tags header and candidates list', (tester) async {
      Tag? selected;

      await tester.pumpWidget(
        createTestApp(
          child: TagInlineMenu(
            items: [tag1, tag2],
            selectedIndex: 0,
            query: 'app',
            onSelectTag: (t) => selected = t,
          ),
        ),
      );

      expect(find.text('TAGS'), findsOneWidget);
      expect(find.text('#apple'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('#application'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      // Tap on second tag
      await tester.tap(find.text('#application'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.name, 'application');
    });

    testWidgets('renders candidates list when query is empty (# typed alone)', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: TagInlineMenu(
            items: [tag1, tag2],
            selectedIndex: 0,
            query: '',
            onSelectTag: (_) {},
          ),
        ),
      );

      expect(find.text('TAGS'), findsOneWidget);
      expect(find.text('#apple'), findsOneWidget);
      expect(find.text('#application'), findsOneWidget);
    });

    testWidgets('TagEditorBar renders full nested path like #journal/daily', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: TagEditorBar(
            tags: const ['journal/daily', 'work'],
            onAddTag: (_) {},
            onRemoveTag: (_) {},
          ),
        ),
      );

      // Full path is visible
      expect(find.text('#journal/daily'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);
      // Leaf #daily alone is NOT rendered
      expect(find.text('#daily'), findsNothing);
    });

    testWidgets('QuietTagChip respects showFullPath property', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: Column(
            children: const [
              QuietTagChip(tag: 'journal/daily', showFullPath: true),
              QuietTagChip(tag: 'journal/daily', showFullPath: false),
            ],
          ),
        ),
      );

      expect(find.text('#journal/daily'), findsOneWidget);
      expect(find.text('#daily'), findsOneWidget);
    });
  });
}
