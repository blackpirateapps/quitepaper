import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
