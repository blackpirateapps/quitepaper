import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/note_links/note_link_search_service.dart';
import 'package:quitepaper/features/editor/presentation/widgets/note_link_inline_menu.dart';


void main() {
  group('NoteLinkInlineMenu Widget Tests', () {
    final candidate1 = NoteLinkSearchResultItem(
      id: 'note-1',
      title: 'Quantum Computing',
      snippet: 'Physics notes',
      tags: const ['physics'],
      updatedAt: DateTime.now(),
    );

    final candidate2 = NoteLinkSearchResultItem(
      id: 'note-2',
      title: 'Quantum Mechanics',
      snippet: 'Wave equations',
      tags: const ['physics', 'advanced'],
      updatedAt: DateTime.now(),
    );

    Widget createTestApp({
      required Widget child,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders candidates list and create option', (tester) async {
      NoteLinkSearchResultItem? selected;
      String? created;

      await tester.pumpWidget(
        createTestApp(
          child: NoteLinkInlineMenu(
            items: [candidate1, candidate2],
            selectedIndex: 0,
            query: 'quantum',
            onSelectNote: (item) => selected = item,
            onCreateNote: (title) => created = title,
          ),
        ),
      );

      expect(find.text('LINK TO NOTE'), findsOneWidget);
      expect(find.text('Quantum Computing'), findsOneWidget);
      expect(find.text('Quantum Mechanics'), findsOneWidget);
      expect(find.textContaining('Create'), findsOneWidget);
      expect(find.textContaining('“quantum”'), findsOneWidget);

      // Tap on second candidate
      await tester.tap(find.text('Quantum Mechanics'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.id, 'note-2');
      expect(selected!.title, 'Quantum Mechanics');
      expect(created, isNull);
    });

    testWidgets('tapping create option triggers onCreateNote', (tester) async {
      String? created;

      await tester.pumpWidget(
        createTestApp(
          child: NoteLinkInlineMenu(
            items: [candidate1],
            selectedIndex: 1, // "+ Create" is index 1
            query: 'Superconductivity',
            onSelectNote: (_) {},
            onCreateNote: (title) => created = title,
          ),
        ),
      );

      expect(find.textContaining('“Superconductivity”'), findsOneWidget);

      await tester.tap(find.textContaining('Superconductivity'));
      await tester.pump();

      expect(created, 'Superconductivity');
    });

    testWidgets('hides create option when query is empty', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          child: NoteLinkInlineMenu(
            items: [candidate1],
            selectedIndex: 0,
            query: '',
            onSelectNote: (_) {},
            onCreateNote: (_) {},
          ),
        ),
      );

      expect(find.text('Quantum Computing'), findsOneWidget);
      expect(find.textContaining('Create'), findsNothing);
    });
  });
}
