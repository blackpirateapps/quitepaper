import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_helper.dart';
import 'package:quitepaper/core/syntax/presentation/language_selector_sheet.dart';
import 'package:quitepaper/features/editor/application/markdown_code_block_parser.dart';
import 'package:quitepaper/features/editor/application/markdown_editing_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/code_block_language_pill.dart';
import 'package:quitepaper/features/editor/presentation/widgets/markdown_editor.dart';

void main() {
  Widget buildWrapper(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('MarkdownCodeBlockParser', () {
    test('extracts single closed fenced code block with language', () {
      const doc = '# Title\n\n```dart\nvoid main() {}\n```\n\nFooter.';
      final blocks = MarkdownCodeBlockParser.parse(doc);

      expect(blocks.length, equals(1));
      final b = blocks.first;
      expect(b.rawLanguage, equals('dart'));
      expect(b.delimiter, equals('```'));
      expect(b.isClosed, isTrue);
      expect(doc.substring(b.openingFenceLineStart, b.openingFenceLineEnd), equals('```dart'));
      expect(doc.substring(b.closingFenceLineStart!, b.closingFenceLineEnd!), equals('```'));
    });

    test('extracts code block without language as empty rawLanguage', () {
      const doc = '```\nplain text code\n```';
      final blocks = MarkdownCodeBlockParser.parse(doc);

      expect(blocks.length, equals(1));
      expect(blocks.first.rawLanguage, isEmpty);
      expect(blocks.first.isClosed, isTrue);
    });

    test('extracts multiple code blocks with different languages', () {
      const doc = '```python\nprint("hi")\n```\nSome text\n~~~sql\nSELECT 1;\n~~~';
      final blocks = MarkdownCodeBlockParser.parse(doc);

      expect(blocks.length, equals(2));
      expect(blocks[0].rawLanguage, equals('python'));
      expect(blocks[0].delimiter, equals('```'));
      expect(blocks[1].rawLanguage, equals('sql'));
      expect(blocks[1].delimiter, equals('~~~'));
    });

    test('handles unclosed code block gracefully', () {
      const doc = '```rust\nfn main() {';
      final blocks = MarkdownCodeBlockParser.parse(doc);

      expect(blocks.length, equals(1));
      expect(blocks.first.rawLanguage, equals('rust'));
      expect(blocks.first.isClosed, isFalse);
    });
  });

  group('MarkdownHelper.replaceCodeBlockLanguageAtLine', () {
    test('replaces language on opening fence line', () {
      const initialText = '# Intro\n```\nvoid main() {}\n```';
      final val = const TextEditingValue(text: initialText, selection: TextSelection.collapsed(offset: 12));
      final updated = MarkdownHelper.replaceCodeBlockLanguageAtLine(
        value: val,
        openingFenceLineStart: 8,
        openingFenceLineEnd: 11,
        newLanguage: 'dart',
      );

      expect(updated.text, equals('# Intro\n```dart\nvoid main() {}\n```'));
    });

    test('swaps existing language identifier', () {
      const initialText = '```python\nprint("hi")\n```';
      final val = const TextEditingValue(text: initialText, selection: TextSelection.collapsed(offset: 5));
      final updated = MarkdownHelper.replaceCodeBlockLanguageAtLine(
        value: val,
        openingFenceLineStart: 0,
        openingFenceLineEnd: 9,
        newLanguage: 'ruby',
      );

      expect(updated.text, equals('```ruby\nprint("hi")\n```'));
    });
  });

  group('CodeBlockLanguagePill Widget', () {
    testWidgets('renders language display name and handles tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildWrapper(
          CodeBlockLanguagePill(
            language: 'dart',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.byType(CodeBlockLanguagePill));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders Plain text fallback when language is empty', (tester) async {
      await tester.pumpWidget(
        buildWrapper(
          CodeBlockLanguagePill(
            language: '',
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plain text'), findsOneWidget);
    });
  });

  group('CodeBlockOverlay and MarkdownEditor Integration', () {
    testWidgets('renders language pill on code block in editor', (tester) async {
      final controller = MarkdownEditingController(
        text: '# Note\n\n```python\nprint("Hello")\n```\n',
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildWrapper(
          MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify pill renders with Python
      expect(find.byType(CodeBlockLanguagePill), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
    });

    testWidgets('renders Plain text pill on unassigned code block', (tester) async {
      final controller = MarkdownEditingController(
        text: '```\nplain content\n```\n',
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildWrapper(
          MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CodeBlockLanguagePill), findsOneWidget);
      expect(find.text('Plain text'), findsOneWidget);
    });

    testWidgets('tapping pill opens LanguageSelectorSheet and updates language', (tester) async {
      final controller = MarkdownEditingController(
        text: '```\ncode here\n```\n',
      );
      final focusNode = FocusNode();
      String? changedText;

      await tester.pumpWidget(
        buildWrapper(
          MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
            onChanged: (val) => changedText = val,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the Plain text pill
      await tester.tap(find.byType(CodeBlockLanguagePill));
      await tester.pumpAndSettle();

      // Search for "rust" in the sheet
      final searchField = find.descendant(
        of: find.byType(LanguageSelectorSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'rust');
      await tester.pumpAndSettle();

      // Tap "Rust" in the sheet
      await tester.tap(find.text('Rust'));
      await tester.pumpAndSettle();

      // Controller update occurred upon sheet dismissal; pump and settle layout
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelectorSheet), findsNothing);
      expect(controller.text.startsWith('```rust\n'), isTrue);
      expect(changedText?.startsWith('```rust\n'), isTrue);
      expect(find.byType(CodeBlockLanguagePill), findsOneWidget);
      expect(find.text('Rust'), findsOneWidget);
    });

    testWidgets('detects language at cursor when inside code block for context menu', (tester) async {
      final controller = MarkdownEditingController(
        text: '```python\nprint("hello")\n```\n',
      );
      final focusNode = FocusNode();

      await tester.pumpWidget(
        buildWrapper(
          MarkdownEditor(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cursor inside code block body
      controller.selection = const TextSelection.collapsed(offset: 15);
      await tester.pumpAndSettle();

      final langAtCursor = MarkdownHelper.getCodeBlockLanguageAtCursor(controller.value);
      expect(langAtCursor, equals('python'));

      // Change language via MarkdownHelper
      final changed = MarkdownHelper.changeCodeBlockLanguage(
        value: controller.value,
        newLanguage: 'typescript',
      );
      expect(changed.text.startsWith('```typescript\n'), isTrue);
    });
  });
}
