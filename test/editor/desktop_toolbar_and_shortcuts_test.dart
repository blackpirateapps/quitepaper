import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_helper.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_formatter.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  Widget buildTestWidget({
    required TextEditingController controller,
    required FocusNode focusNode,
    bool isTopDocked = false,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Column(
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
            ),
            FormattingToolbar(
              controller: controller,
              focusNode: focusNode,
              isTopDocked: isTopDocked,
              onTagPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  group('Desktop FormattingToolbar Tests', () {
    testWidgets('renders top-docked border when isTopDocked is true', (tester) async {
      final controller = MarkdownEditingController(text: 'sample');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestWidget(
        controller: controller,
        focusNode: focusNode,
        isTopDocked: true,
      ));

      final containerFinder = find.descendant(
        of: find.byType(FormattingToolbar),
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      // Top docked has bottom border
      expect(decoration.border!.bottom, isNotNull);
      expect(decoration.border!.top.width, equals(0.0));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('renders bottom-docked border when isTopDocked is false', (tester) async {
      final controller = MarkdownEditingController(text: 'sample');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestWidget(
        controller: controller,
        focusNode: focusNode,
        isTopDocked: false,
      ));

      final containerFinder = find.descendant(
        of: find.byType(FormattingToolbar),
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(containerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      // Bottom docked has top border
      expect(decoration.border!.top, isNotNull);
      expect(decoration.border!.bottom.width, equals(0.0));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('opens heading dropdown popup on click on desktop', (tester) async {
      final controller = MarkdownEditingController(text: 'Heading line');
      controller.selection = const TextSelection.collapsed(offset: 4);
      final focusNode = FocusNode();

      await tester.pumpWidget(buildTestWidget(
        controller: controller,
        focusNode: focusNode,
        isTopDocked: true,
      ));

      // Find heading button by icon
      final headingFinder = find.descendant(
        of: find.byType(FormattingToolbar),
        matching: find.byIcon(PhosphorIconsRegular.textH),
      );
      expect(headingFinder, findsOneWidget);

      // On desktop, clicking opens dropdown menu with H1..H6 and Paragraph
      await tester.tap(headingFinder);
      await tester.pumpAndSettle();

      expect(find.text('Heading 1'), findsOneWidget);
      expect(find.text('Heading 2'), findsOneWidget);
      expect(find.text('Heading 3'), findsOneWidget);
      expect(find.text('Paragraph (Normal)'), findsOneWidget);

      // Tap Heading 2 in dropdown
      await tester.tap(find.text('Heading 2'));
      await tester.pumpAndSettle();

      expect(controller.text, equals('## Heading line'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('horizontal mouse scroll event translates to toolbar scroll', (tester) async {
      final controller = MarkdownEditingController(text: 'sample');
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: FormattingToolbar(
                controller: controller,
                focusNode: focusNode,
                isTopDocked: true,
                onTagPressed: () {},
              ),
            ),
          ),
        ),
      );

      final listViewFinder = find.descendant(
        of: find.byType(FormattingToolbar),
        matching: find.byType(ListView),
      );
      expect(listViewFinder, findsOneWidget);

      final scrollable = tester.widget<ListView>(listViewFinder);
      final scrollController = scrollable.controller!;

      expect(scrollController.offset, equals(0.0));
      expect(scrollController.position.maxScrollExtent, greaterThan(0.0));

      // Send a pointer scroll event on the toolbar
      final center = tester.getCenter(listViewFinder);
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0.0, 50.0), // vertical wheel scroll
      );

      tester.binding.handlePointerEvent(pointerSignal);
      await tester.pumpAndSettle();

      // Horizontal offset should have increased due to pointer scroll translation
      expect(scrollController.offset, greaterThan(0.0));

      focusNode.dispose();
      controller.dispose();
    });
  });

  group('Desktop Keyboard Shortcuts Tests', () {
    Widget buildShortcutsApp({
      required TextEditingController controller,
      required FocusNode focusNode,
    }) {
      void applyHelper(TextEditingValue Function(TextEditingValue) transform) {
        controller.value = transform(controller.value);
      }

      return MaterialApp(
        home: Scaffold(
          body: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.digit1, control: true, alt: true): () {
                applyHelper((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: 1));
              },
              const SingleActivator(LogicalKeyboardKey.digit2, control: true, alt: true): () {
                applyHelper((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: 2));
              },
              const SingleActivator(LogicalKeyboardKey.digit0, control: true, alt: true): () {
                applyHelper((val) => MarkdownHelper.setHeadingLevelAt(value: val, level: 0));
              },
              const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): () {
                controller.value = MarkdownFormatter.toggleChecklist(value: controller.value);
              },
              const SingleActivator(LogicalKeyboardKey.digit8, control: true, shift: true): () {
                controller.value = MarkdownFormatter.toggleBulletList(value: controller.value);
              },
              const SingleActivator(LogicalKeyboardKey.digit7, control: true, shift: true): () {
                controller.value = MarkdownFormatter.toggleOrderedList(value: controller.value);
              },
              const SingleActivator(LogicalKeyboardKey.period, control: true, shift: true): () {
                applyHelper((val) => MarkdownHelper.toggleLinePrefix(value: val, prefix: '> '));
              },
              const SingleActivator(LogicalKeyboardKey.minus, control: true, alt: true): () {
                applyHelper(MarkdownHelper.insertHorizontalRule);
              },
            },
            child: TextField(
              controller: controller,
              focusNode: focusNode,
            ),
          ),
        ),
      );
    }

    testWidgets('Ctrl+Alt+1 converts line to H1, and Ctrl+Alt+0 clears it', (tester) async {
      final controller = MarkdownEditingController(text: 'My Header');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildShortcutsApp(
        controller: controller,
        focusNode: focusNode,
      ));

      focusNode.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();

      // Trigger Ctrl+Alt+1
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, equals('# My Header'));

      // Trigger Ctrl+Alt+0 to return to normal paragraph
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, equals('My Header'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Ctrl+Shift+C toggles checklist', (tester) async {
      final controller = MarkdownEditingController(text: 'Buy milk');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildShortcutsApp(
        controller: controller,
        focusNode: focusNode,
      ));

      focusNode.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tester.pump();

      // Trigger Ctrl+Shift+C
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, equals('- [ ] Buy milk'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Ctrl+Shift+8 toggles bullet list', (tester) async {
      final controller = MarkdownEditingController(text: 'Item one');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildShortcutsApp(
        controller: controller,
        focusNode: focusNode,
      ));

      focusNode.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.pump();

      // Trigger Ctrl+Shift+8
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit8);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, equals('- Item one'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Ctrl+Shift+. toggles quote', (tester) async {
      final controller = MarkdownEditingController(text: 'A profound quote');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildShortcutsApp(
        controller: controller,
        focusNode: focusNode,
      ));

      focusNode.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.pump();

      // Trigger Ctrl+Shift+.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.period);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, equals('> A profound quote'));

      focusNode.dispose();
      controller.dispose();
    });

    testWidgets('Ctrl+Alt+- inserts divider', (tester) async {
      final controller = MarkdownEditingController(text: 'Section');
      final focusNode = FocusNode();

      await tester.pumpWidget(buildShortcutsApp(
        controller: controller,
        focusNode: focusNode,
      ));

      focusNode.requestFocus();
      controller.selection = const TextSelection.collapsed(offset: 7);
      await tester.pump();

      // Trigger Ctrl+Alt+-
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(controller.text, contains('---'));

      focusNode.dispose();
      controller.dispose();
    });
  });
}
