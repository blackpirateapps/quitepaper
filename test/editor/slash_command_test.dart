import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/slash_command_trigger.dart';
import 'package:quitepaper/features/editor/presentation/widgets/slash_command/slash_command_item.dart';
import 'package:quitepaper/features/editor/presentation/widgets/slash_command/slash_command_menu.dart';
import 'package:quitepaper/features/editor/presentation/widgets/slash_command/slash_command_overlay_controller.dart';

void main() {
  group('SlashCommandTrigger Unit Tests', () {
    test('detects trigger at beginning of document', () {
      const value = TextEditingValue(
        text: '/',
        selection: TextSelection.collapsed(offset: 1),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 0);
      expect(trigger.query, '');
      expect(trigger.queryEnd, 1);
    });

    test('detects trigger with query at start of document', () {
      const value = TextEditingValue(
        text: '/h1',
        selection: TextSelection.collapsed(offset: 3),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 0);
      expect(trigger.query, 'h1');
      expect(trigger.queryEnd, 3);
    });

    test('detects trigger on a new line', () {
      const value = TextEditingValue(
        text: 'Hello\n/todo',
        selection: TextSelection.collapsed(offset: 11),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 6);
      expect(trigger.query, 'todo');
      expect(trigger.queryEnd, 11);
    });

    test('detects trigger with leading whitespace indentation', () {
      const value = TextEditingValue(
        text: '  /code',
        selection: TextSelection.collapsed(offset: 7),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNotNull);
      expect(trigger!.triggerStart, 2);
      expect(trigger.query, 'code');
      expect(trigger.queryEnd, 7);
    });

    test('ignores slash preceded by alphanumeric characters (e.g. URL or path)', () {
      const value = TextEditingValue(
        text: 'https://example.com/test',
        selection: TextSelection.collapsed(offset: 24),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('ignores when selection is not collapsed', () {
      const value = TextEditingValue(
        text: '/heading',
        selection: TextSelection(baseOffset: 1, extentOffset: 8),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNull);
    });

    test('ignores slash followed by a space', () {
      const value = TextEditingValue(
        text: '/ note',
        selection: TextSelection.collapsed(offset: 6),
      );
      final trigger = SlashCommandTrigger.detect(value);
      expect(trigger, isNull);
    });
  });

  group('SlashCommandItem Match Tests', () {
    test('SlashCommandItem.all includes headings, lists, quotes, code, divider, table', () {
      final types = SlashCommandItem.all.map((item) => item.type).toSet();
      expect(types, contains(SlashCommandType.h1));
      expect(types, contains(SlashCommandType.h2));
      expect(types, contains(SlashCommandType.h3));
      expect(types, contains(SlashCommandType.todo));
      expect(types, contains(SlashCommandType.bullet));
      expect(types, contains(SlashCommandType.number));
      expect(types, contains(SlashCommandType.quote));
      expect(types, contains(SlashCommandType.code));
      expect(types, contains(SlashCommandType.divider));
      expect(types, contains(SlashCommandType.table));
      expect(types, contains(SlashCommandType.paragraph));
    });

    test('matches filtering by title and keywords', () {
      final h1Item = SlashCommandItem.all.firstWhere((i) => i.type == SlashCommandType.h1);
      expect(h1Item.matches('h1'), isTrue);
      expect(h1Item.matches('heading'), isTrue);
      expect(h1Item.matches('code'), isFalse);

      final checklistItem = SlashCommandItem.all.firstWhere((i) => i.type == SlashCommandType.todo);
      expect(checklistItem.matches('check'), isTrue);
      expect(checklistItem.matches('todo'), isTrue);
      expect(checklistItem.matches('task'), isTrue);
    });
  });

  group('SlashCommandMenu Widget Tests', () {
    testWidgets('renders items and responds to tap', (tester) async {
      SlashCommandItem? selectedItem;
      final items = [
        SlashCommandItem.all.firstWhere((i) => i.type == SlashCommandType.h1),
        SlashCommandItem.all.firstWhere((i) => i.type == SlashCommandType.todo),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SlashCommandMenu(
              items: items,
              selectedIndex: 0,
              onSelectCommand: (item) {
                selectedItem = item;
              },
            ),
          ),
        ),
      );

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('To-do List'), findsOneWidget);

      await tester.tap(find.text('To-do List'));
      await tester.pumpAndSettle();

      expect(selectedItem, isNotNull);
      expect(selectedItem!.type, equals(SlashCommandType.todo));
    });

    testWidgets('renders empty state when no items match', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SlashCommandMenu(
              items: const [],
              selectedIndex: 0,
              onSelectCommand: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('No matching commands'), findsOneWidget);
    });
  });

  group('SlashCommandOverlayController Lifecycle Tests', () {
    testWidgets('shows overlay, handles arrow keys, and closes', (tester) async {
      SlashCommandOverlayController? controller;
      SlashCommandType? executedType;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                controller ??= SlashCommandOverlayController(
                  context: context,
                  onSelectCommand: (item, start, end) {
                    executedType = item.type;
                  },
                );
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      controller!.showOrUpdate(
                        caretRect: const Rect.fromLTWH(100, 100, 20, 20),
                        query: '',
                        triggerStart: 0,
                        queryEnd: 1,
                      );
                    },
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(controller!.isOpen, isFalse);

      // Open
      await tester.tap(find.text('Open'));
      await tester.pump();
      expect(controller!.isOpen, isTrue);
      expect(find.text('Heading 1'), findsOneWidget);

      // Handle ArrowDown
      final handledDown = controller!.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.arrowDown,
          logicalKey: LogicalKeyboardKey.arrowDown,
          timeStamp: Duration.zero,
        ),
      );
      expect(handledDown, equals(KeyEventResult.handled));
      await tester.pump();

      // Handle Enter
      final handledEnter = controller!.handleKeyEvent(
        const KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.enter,
          logicalKey: LogicalKeyboardKey.enter,
          timeStamp: Duration.zero,
        ),
      );
      expect(handledEnter, equals(KeyEventResult.handled));
      expect(executedType, equals(SlashCommandType.h2));
      expect(controller!.isOpen, isFalse);

      controller!.dispose();
    });
  });
}
