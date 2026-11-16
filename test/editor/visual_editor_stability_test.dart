import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/editor_editing_style.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';
import 'package:quitepaper/features/editor/presentation/widgets/rich_editor_surface.dart';

void main() {
  late RichDocumentController controller;
  late FocusNode focus;

  setUp(() {
    controller = RichDocumentController();
    focus = FocusNode();
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
  void cleanUp(WidgetTester tester) {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  Widget surface() =>
      app(RichEditorSurface(controller: controller, focusNode: focus));
  Finder field(String text) => find.byWidgetPredicate(
    (widget) => widget is EditableText && widget.controller.text == text,
  );
  void select(int index, int offset) {
    final block = controller.document.blocks[index];
    controller.updateSelection(
      RichDocumentSelection.collapsed(
        RichDocumentPosition(
          blockIndex: index,
          blockId: block.id,
          offset: offset,
        ),
      ),
    );
  }

  testWidgets('native tap publishes a selection made before field focus', (tester) async {
    cleanUp(tester);
    controller.setMarkdown('Before\n- [ ] task\nTail');
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    final tail = tester.widget<EditableText>(field('Tail'));
    expect(tail.focusNode.hasFocus, isFalse);
    tail.controller.selection = const TextSelection.collapsed(offset: 4);
    expect(controller.selection.extent.blockIndex, 0);
    final textField = find.ancestor(of: field('Tail'), matching: find.byType(TextField));
    tester.widget<TextField>(textField).onTap!();
    tail.focusNode.requestFocus();
    await tester.pump();
    expect(controller.selection.extent.blockIndex, 2);
    expect(controller.selection.extent.offset, 4);
    controller.insertHorizontalRule();
    await tester.pumpAndSettle();
    expect(controller.document.blocks[2].plainText, 'Tail');
    expect(controller.document.blocks[3], isA<HorizontalRuleBlock>());
    final continuation = tester.widget<EditableText>(field(''));
    expect(continuation.focusNode.hasPrimaryFocus, isTrue);
    tester.testTextInput.updateEditingValue(const TextEditingValue(text: 'after',
      selection: TextSelection.collapsed(offset: 5)));
    await tester.pumpAndSettle();
    expect(controller.document.blocks.last.plainText, 'after');
  });

  for (final suffix in ['', '\n- [ ] Next task']) {
    testWidgets('divider focuses its continuation paragraph before "$suffix"', (tester) async {
      cleanUp(tester);
      controller.setMarkdown('Before\n- [ ] task\nTail$suffix');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      await tester.tap(field('Tail'));
      select(2, 4);
      await tester.pump();
      controller.insertHorizontalRule();
      await tester.pumpAndSettle();
      expect(controller.document.blocks[3], isA<HorizontalRuleBlock>());
      expect(controller.document.blocks[4], isA<ParagraphBlock>());
      final continuation = tester.widget<EditableText>(field(''));
      expect(continuation.focusNode.hasPrimaryFocus, isTrue);
      expect(continuation.controller.selection, const TextSelection.collapsed(offset: 0));
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'after', selection: TextSelection.collapsed(offset: 5),
      ));
      await tester.pumpAndSettle();
      expect(controller.document.blocks[2].plainText, 'Tail');
      expect(controller.document.blocks[4].plainText, 'after');
      controller.undo(); // Typing
      controller.undo(); // Divider and its continuation paragraph
      await tester.pumpAndSettle();
      expect(controller.document.blocks.whereType<HorizontalRuleBlock>(), isEmpty);
      controller.redo();
      await tester.pumpAndSettle();
      expect(controller.selection.extent.blockId, controller.document.blocks[4].id);
      expect(tester.widget<EditableText>(field('')).focusNode.hasPrimaryFocus, isTrue);
    });
  }

  testWidgets(
    'typing below mixed lists retains focus, selection and composition',
    (tester) async {
      cleanUp(tester);
      controller.setMarkdown('- [ ] task\n1. first\n2. second\nTail');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      final target = field('1. first\n2. second\nTail');
      expect(target, findsOneWidget);
      await tester.tap(target);
      await tester.pump();
      final editor = tester.widget<EditableText>(target);
      final node = editor.focusNode;
      editor.controller.value = const TextEditingValue(
        text: '1. first\n2. second\nTail!',
        selection: TextSelection.collapsed(offset: 24),
        composing: TextRange(start: 18, end: 24),
      );
      await tester.pump();
      expect(editor.focusNode.hasPrimaryFocus, isTrue);
      expect(
        tester
            .widget<EditableText>(field('1. first\n2. second\nTail!'))
            .focusNode,
        same(node),
      );
      expect(editor.controller.selection.extentOffset, 24);
      expect(
        editor.controller.value.composing,
        const TextRange(start: 18, end: 24),
      );
      expect(controller.document.blocks.last.plainText, 'Tail!');
    },
  );

  testWidgets(
    'inserting in a checklist keeps later item callbacks tied to its ID',
    (tester) async {
      cleanUp(tester);
      controller.setMarkdown('- [ ] Alpha\n- [ ] Beta\n- [ ] Gamma');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      await tester.tap(field('Alpha'));
      await tester.pump();
      final alpha = tester.widget<EditableText>(field('Alpha'));
      alpha.controller.selection = const TextSelection.collapsed(offset: 5);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.tap(field('Gamma'));
      await tester.pump();
      final gamma = tester.widget<EditableText>(field('Gamma'));
      gamma.controller.value = const TextEditingValue(
        text: 'Gamma!',
        selection: TextSelection.collapsed(offset: 6),
      );
      await tester.pumpAndSettle();
      expect(controller.document.blocks.map((block) => block.plainText), [
        'Alpha',
        '',
        'Beta',
        'Gamma!',
      ]);
      expect(
        controller.selection.base.blockId,
        controller.document.blocks.last.id,
      );
    },
  );

  testWidgets(
    'checklist Enter exit transfers the input connection to the paragraph',
    (tester) async {
      cleanUp(tester);
      controller.setMarkdown('- [ ] task\n- [ ] ');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      await tester.tap(field(''));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final paragraph = tester.widget<EditableText>(field(''));
      expect(paragraph.focusNode.hasPrimaryFocus, isTrue);
      tester.testTextInput.updateEditingValue(
        const TextEditingValue(
          text: 'Continue',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump();
      expect(controller.document.blocks.last.plainText, 'Continue');
    },
  );

  testWidgets(
    'selection changes preserve a focused checklist range after formatting',
    (tester) async {
      cleanUp(tester);
      controller.setMarkdown('- [ ] Alpha Beta');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      final editor = tester.widget<EditableText>(field('Alpha Beta'));
      await tester.tap(field('Alpha Beta'));
      await tester.pump();
      final block = controller.document.blocks.first;
      controller.updateSelection(
        RichDocumentSelection(
          base: RichDocumentPosition(
            blockIndex: 0,
            blockId: block.id,
            offset: 0,
          ),
          extent: RichDocumentPosition(
            blockIndex: 0,
            blockId: block.id,
            offset: 5,
          ),
        ),
      );
      controller.toggleBold();
      await tester.pumpAndSettle();
      expect(
        editor.controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
    },
  );

  testWidgets('web links do not add phantom editing offsets', (tester) async {
    cleanUp(tester);
    controller.setMarkdown(
      'Before [site](https://example.com) after\n- [ ] [task](https://example.com) after',
    );
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    for (final editor in tester.widgetList<EditableText>(
      find.byType(EditableText),
    )) {
      final span = editor.controller.buildTextSpan(
        context: tester.element(find.byType(Scaffold)),
        withComposing: false,
      );
      expect(span.toPlainText(), editor.controller.text);
    }
  });

  testWidgets(
    'source selection cannot replace pending visual text with an older buffer',
    (tester) async {
      cleanUp(tester);
      final source = MarkdownEditingController(text: 'Start');
      await tester.pumpWidget(
        app(
          MarkdownEditor(
            controller: source,
            focusNode: focus,
            editingStyle: EditorEditingStyle.wysiwyg,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Start typing');
      // The source buffer has not yet received the debounced visual save.
      source.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(field('Start typing'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      source.dispose();
    },
  );

  testWidgets(
    'title body focus node remains connected for checklist-first documents',
    (tester) async {
      cleanUp(tester);
      controller.setMarkdown('- [ ] first\n- [ ] second');
      await tester.pumpWidget(surface());
      await tester.pumpAndSettle();
      focus.requestFocus();
      await tester.pump();
      final first = tester.widget<EditableText>(field('first'));
      expect(first.focusNode, same(focus));
      expect(first.focusNode.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets('unrelated rebuilds do not restore an old checklist caret', (
    tester,
  ) async {
    cleanUp(tester);
    controller.setMarkdown('- [ ] task\nParagraph');
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    await tester.tap(field('Paragraph'));
    await tester.pump();
    select(1, 4);
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(field('Paragraph')).focusNode.hasPrimaryFocus,
      isTrue,
    );
  });
  testWidgets('IME Enter in an ordered list retains the new item caret', (
    tester,
  ) async {
    cleanUp(tester);
    controller.setMarkdown('1. Alpha');
    await tester.pumpWidget(surface());
    await tester.pumpAndSettle();
    await tester.tap(field('1. Alpha'));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '1. Alpha\n',
        selection: TextSelection.collapsed(offset: 9),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<EditableText>(field('1. Alpha\n2. '));
    expect(
      editor.controller.selection.extentOffset,
      editor.controller.text.length,
    );
    expect(controller.selection.base.blockIndex, 1);
    expect(controller.selection.base.offset, 0);
  });

  testWidgets('arrow keys move within wrapped tasks before changing items', (
    tester,
  ) async {
    cleanUp(tester);
    controller.setMarkdown(
      '- [ ] first\n- [ ] ${'long task ' * 30}\n- [ ] last',
    );
    await tester.pumpWidget(
      app(
        SizedBox(
          width: 260,
          child: RichEditorSurface(controller: controller, focusNode: focus),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();
    final middle = fields[1];
    middle.focusNode.requestFocus();
    await tester.pump();
    middle.controller.selection = const TextSelection.collapsed(offset: 100);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(middle.focusNode.hasPrimaryFocus, isTrue);
    expect(middle.controller.selection.extentOffset, lessThan(100));
    expect(middle.controller.selection.extentOffset, greaterThan(0));
    middle.controller.selection = const TextSelection.collapsed(offset: 100);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(middle.focusNode.hasPrimaryFocus, isTrue);
    expect(middle.controller.selection.extentOffset, greaterThan(100));
  });

  testWidgets(
    'Markdown table segments keep their input connection while typing',
    (tester) async {
      cleanUp(tester);
      final source = MarkdownEditingController(
        text: 'Intro\n\n| A | B |\n| --- | --- |\n| one | two |\n\nTail',
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(
        app(MarkdownEditor(controller: source, focusNode: focus)),
      );
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(editable.focusNode, same(focus));
      focus.requestFocus();
      await tester.pump();
      for (var i = 1; i <= 3; i++) {
        final text = '${'X' * i}Intro\n\n';
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: i),
          ),
        );
        await tester.pump();
        final updated = tester.widget<EditableText>(
          find.byType(EditableText).first,
        );
        expect(updated.controller, same(editable.controller));
        expect(updated.focusNode.hasPrimaryFocus, isTrue);
        expect(updated.controller.selection.extentOffset, i);
        expect(source.text, startsWith('${'X' * i}Intro'));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('editing a title does not restore stale checklist focus', (
    tester,
  ) async {
    cleanUp(tester);
    controller.setMarkdown('- [ ] task');
    final title = TextEditingController();
    final titleFocus = FocusNode();
    addTearDown(title.dispose);
    addTearDown(titleFocus.dispose);
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, rebuild) {
            return Column(
              children: [
                TextField(
                  key: const ValueKey('title'),
                  controller: title,
                  focusNode: titleFocus,
                  onChanged: (_) => rebuild(() {}),
                ),
                RichEditorSurface(controller: controller, focusNode: focus),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('title')), 'New title');
    await tester.pumpAndSettle();
    expect(titleFocus.hasPrimaryFocus, isTrue);
    expect(title.text, 'New title');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
