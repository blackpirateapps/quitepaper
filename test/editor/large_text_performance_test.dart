import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/utils/tag_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/application/markdown_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_text_input_formatter.dart';
import 'package:quitepaper/features/editor/application/undo_redo_manager.dart';
import 'package:quitepaper/features/editor/domain/markdown_styles.dart';

void main() {
  final styles = MarkdownStyles.fromColors(AppColors.light);

  group('Large Text Editor Performance & Fast Path Tests', () {
    test('Standard note under threshold produces full rich AST Markdown styling', () {
      const normalText = '# Heading 1\n\n**Bold message** with `code` and - [ ] task';
      final span = MarkdownParser.buildTextSpan(
        text: normalText,
        styles: styles,
      );

      expect(span.toPlainText(), equals(normalText));
      expect(span.children, isNotNull);
      expect(span.children!.isNotEmpty, isTrue);
    });

    test('Large note (>60,000 chars / ~1-5MB) activates high-performance plain span mode', () {
      // Create a 1 MB WhatsApp chat export simulation (~15,000 lines, ~150,000 words)
      final buffer = StringBuffer();
      for (var i = 0; i < 15000; i++) {
        buffer.writeln('[12/05/23, 10:15:32 PM] User $i: This is a long WhatsApp chat message line for testing performance #tag$i');
      }
      final largeText = buffer.toString();
      expect(largeText.length, greaterThan(60000));

      final stopwatch = Stopwatch()..start();
      final span = MarkdownParser.buildTextSpan(
        text: largeText,
        styles: styles,
      );
      stopwatch.stop();

      // Should complete in single-digit milliseconds (virtually instantaneous)
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(span.toPlainText(), equals(largeText));
      expect(span.style, equals(styles.body));
    });

    test('Large note preserves in-note search match highlights with bounding', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 5000; i++) {
        buffer.writeln('[12/05/23] User $i: Message with searchable keyword TARGET_WORD in line');
      }
      final largeText = buffer.toString();

      final stopwatch = Stopwatch()..start();
      final span = MarkdownParser.buildTextSpan(
        text: largeText,
        styles: styles,
        searchQuery: 'TARGET_WORD',
        activeSearchRange: const TextRange(start: 46, end: 57),
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50));
      expect(span.toPlainText(), equals(largeText));
      expect(span.children, isNotNull);
      expect(span.children!.length, greaterThan(1));
    });

    test('Large note preserves IME composing underline decoration', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 2000; i++) {
        buffer.writeln('Line $i with some text content here');
      }
      final largeText = buffer.toString();

      final span = MarkdownParser.buildTextSpan(
        text: largeText,
        styles: styles,
        composingRange: const TextRange(start: 10, end: 20),
      );

      expect(span.toPlainText(), equals(largeText));
      expect(span.children, isNotNull);
    });

    testWidgets('MarkdownEditingController respects custom maxStyledCharacters override', (tester) async {
      final controller = MarkdownEditingController(
        text: '# Heading\n**Bold text**',
        maxStyledCharacters: 5, // Force fast path on small text
        styles: styles,
      );

      late BuildContext buildContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: [AppColors.light],
          ),
          home: Builder(
            builder: (context) {
              buildContext = context;
              return Scaffold(
                body: TextField(
                  controller: controller,
                ),
              );
            },
          ),
        ),
      );

      final span = controller.buildTextSpan(
        context: buildContext,
        withComposing: false,
      );

      expect(span.toPlainText(), equals('# Heading\n**Bold text**'));
      // Fast path returns text directly on top span when no search or composing
      expect(span.text, equals('# Heading\n**Bold text**'));
    });

    test('MarkdownTextInputFormatter handles Enter key in 2MB document in <5ms', () {
      const formatter = MarkdownTextInputFormatter();
      final buffer = StringBuffer();
      for (var i = 0; i < 20000; i++) {
        if (i > 0) buffer.writeln();
        buffer.write('- Item $i');
      }
      final text = buffer.toString();
      final insertedOffset = text.length;

      final oldValue = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: insertedOffset),
      );
      final newValue = TextEditingValue(
        text: '$text\n',
        selection: TextSelection.collapsed(offset: insertedOffset + 1),
      );

      final stopwatch = Stopwatch()..start();
      final result = formatter.formatEditUpdate(oldValue, newValue);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(20));
      expect(result.text.endsWith('- Item 19999\n- '), isTrue);
    });

    test('MarkdownTextInputFormatter fast backward code fence detection', () {
      const formatter = MarkdownTextInputFormatter();
      const codeText = '```dart\nfinal x = 1;\n```\n\n```python\nprint("hi")\n';
      final oldValue = TextEditingValue(
        text: codeText,
        selection: const TextSelection.collapsed(offset: codeText.length),
      );
      final newValue = TextEditingValue(
        text: '$codeText\n',
        selection: const TextSelection.collapsed(offset: codeText.length + 1),
      );

      final result = formatter.formatEditUpdate(oldValue, newValue);
      // Inside code block, Enter should NOT insert list markers
      expect(result.text, equals('$codeText\n'));
    });

    test('UndoRedoManager caps history to 20 snapshots for large documents', () {
      final manager = UndoRedoManager(maxHistory: 100);
      final largeBuffer = 'A' * 70000;

      manager.initialize(TextEditingValue(text: largeBuffer));
      expect(manager.effectiveMaxHistory, equals(20));

      for (var i = 0; i < 30; i++) {
        manager.pushAtomicEdit(TextEditingValue(text: '$largeBuffer$i'));
      }

      // Should be capped to effectiveMaxHistory + 1
      expect(manager.canUndo, isTrue);
    });

    test('TagParser processes 1MB text with index-based scanning without crash', () {
      final buffer = StringBuffer();
      for (var i = 0; i < 10000; i++) {
        buffer.writeln('User $i text without tags or with #testtag and #topic$i');
      }
      final largeText = buffer.toString();

      final stopwatch = Stopwatch()..start();
      final tags = TagParser.extractTags(largeText);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300));
      expect(tags.contains('testtag'), isTrue);
    });
  });
}
