import 'dart:math';
import 'package:flutter/services.dart';

/// Formatter that handles smart Markdown behaviors:
/// - Auto-continuation for checklists (`- [ ] `, `- [x] ` -> `- [ ] `)
/// - Auto-continuation for unordered lists (`- `, `* `, `+ `)
/// - Auto-increment continuation for ordered lists (`1. `, `2. `, etc.)
/// - Auto-continuation for blockquotes (`> `)
/// - Empty list/checklist/quote termination on Enter
/// - Code block safety (no list continuation inside fenced code blocks)
/// - Selection auto-wrapping when typing markdown delimiters (`*`, `_`, `~`, `` ` ``, `[`, `(`)
/// - Skipping closing delimiter when typing over existing closing character
class MarkdownTextInputFormatter extends TextInputFormatter {
  const MarkdownTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Auto-wrap selection when typing a delimiter over selected text
    if (oldValue.selection.isValid && !oldValue.selection.isCollapsed) {
      final selStart = min(oldValue.selection.start, oldValue.selection.end);
      final selEnd = max(oldValue.selection.start, oldValue.selection.end);
      final selLen = selEnd - selStart;

      if (newValue.text.length == oldValue.text.length - selLen + 1 &&
          selStart < newValue.text.length) {
        final typedChar = newValue.text[selStart];
        final selectedText = oldValue.text.substring(selStart, selEnd);

        if (typedChar == '*' ||
            typedChar == '_' ||
            typedChar == '`' ||
            typedChar == '~' ||
            typedChar == '[' ||
            typedChar == '(') {
          String prefix;
          String suffix;
          if (typedChar == '[') {
            prefix = '[';
            suffix = ']';
          } else if (typedChar == '(') {
            prefix = '(';
            suffix = ')';
          } else if (typedChar == '~') {
            prefix = '~~';
            suffix = '~~';
          } else {
            prefix = typedChar;
            suffix = typedChar;
          }

          final wrapped = '$prefix$selectedText$suffix';
          final newText = oldValue.text.replaceRange(selStart, selEnd, wrapped);
          return TextEditingValue(
            text: newText,
            selection: TextSelection(
              baseOffset: selStart + prefix.length,
              extentOffset: selStart + prefix.length + selectedText.length,
            ),
          );
        }
      }
    }

    // 2. Skip over duplicate closing character when typing delimiter immediately before matching char
    if (oldValue.selection.isValid &&
        oldValue.selection.isCollapsed &&
        newValue.text.length == oldValue.text.length + 1) {
      final cursor = oldValue.selection.start;
      if (cursor >= 0 && cursor < oldValue.text.length && cursor < newValue.text.length) {
        final typedChar = newValue.text[cursor];
        final nextCharInOld = oldValue.text[cursor];

        if (typedChar == nextCharInOld &&
            (typedChar == '*' ||
                typedChar == '_' ||
                typedChar == '`' ||
                typedChar == '~' ||
                typedChar == ']' ||
                typedChar == ')' ||
                typedChar == '}')) {
          // Simply advance cursor past existing closing delimiter
          return TextEditingValue(
            text: oldValue.text,
            selection: TextSelection.collapsed(offset: cursor + 1),
          );
        }
      }
    }

    // 3. Smart Enter behavior (only single-character newline insertion with collapsed selection)
    if (newValue.text.length != oldValue.text.length + 1) {
      return newValue;
    }

    final selection = oldValue.selection;
    if (!selection.isValid || !selection.isCollapsed) {
      return newValue;
    }

    final insertedOffset = selection.start;
    if (insertedOffset < 0 || insertedOffset >= newValue.text.length) {
      return newValue;
    }

    if (newValue.text[insertedOffset] != '\n') {
      return newValue;
    }

    // Check if cursor is inside a fenced code block (``` or ~~~)
    final textBeforeCursor = oldValue.text.substring(0, insertedOffset);
    final fenceMatches = RegExp(r'^\s*(```|~~~)', multiLine: true).allMatches(textBeforeCursor);
    if (fenceMatches.length % 2 != 0) {
      // Inside code block: standard Enter behavior with no list/quote continuation
      return newValue;
    }

    // Find the line preceding the newline insertion
    final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');
    final lineStart = lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1;
    final currentLine = textBeforeCursor.substring(lineStart);

    // 4. Empty checklist marker: "- [ ]", "- [x]", "* [ ]", "+ [ ]" -> clear checklist
    final emptyChecklistMatch =
        RegExp(r'^(\s*)([-*+]\s*\[[ xX]\])\s*$').firstMatch(currentLine);
    if (emptyChecklistMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 5. Empty unordered list bullet: "- ", "* ", "+ " -> clear bullet
    final emptyUnorderedMatch = RegExp(r'^(\s*)([-*+])\s*$').firstMatch(currentLine);
    if (emptyUnorderedMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 6. Empty ordered list marker: "1. ", "2. " -> clear marker
    final emptyOrderedMatch = RegExp(r'^(\s*)(\d+)[\.\)]\s*$').firstMatch(currentLine);
    if (emptyOrderedMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 7. Empty blockquote: "> " -> clear quote
    final emptyQuoteMatch = RegExp(r'^(\s*)>\s*$').firstMatch(currentLine);
    if (emptyQuoteMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 8. Non-empty checklist item: continue with uncompleted checklist "- [ ] "
    final checklistMatch =
        RegExp(r'^(\s*)([-*+]\s*\[)[ xX](\]\s+)').firstMatch(currentLine);
    if (checklistMatch != null) {
      final indent = checklistMatch.group(1) ?? '';
      final continuation = '$indent- [ ] ';
      final newText = oldValue.text.replaceRange(
        insertedOffset,
        insertedOffset,
        '\n$continuation',
      );
      final newCursor = insertedOffset + 1 + continuation.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    // 9. Non-empty unordered list item: continue "- "
    final unorderedMatch = RegExp(r'^(\s*)([-*+])\s+').firstMatch(currentLine);
    if (unorderedMatch != null) {
      final indent = unorderedMatch.group(1) ?? '';
      final marker = unorderedMatch.group(2) ?? '-';
      final continuation = '$indent$marker ';
      final newText = oldValue.text.replaceRange(
        insertedOffset,
        insertedOffset,
        '\n$continuation',
      );
      final newCursor = insertedOffset + 1 + continuation.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    // 10. Non-empty ordered list item: continue with incremented number
    final orderedMatch = RegExp(r'^(\s*)(\d+)([\.\)])\s+').firstMatch(currentLine);
    if (orderedMatch != null) {
      final indent = orderedMatch.group(1) ?? '';
      final numberStr = orderedMatch.group(2) ?? '1';
      final delimiter = orderedMatch.group(3) ?? '.';
      final nextNumber = (int.tryParse(numberStr) ?? 1) + 1;
      final continuation = '$indent$nextNumber$delimiter ';
      final newText = oldValue.text.replaceRange(
        insertedOffset,
        insertedOffset,
        '\n$continuation',
      );
      final newCursor = insertedOffset + 1 + continuation.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    // 11. Non-empty blockquote: continue "> "
    final quoteMatch = RegExp(r'^(\s*)>\s*').firstMatch(currentLine);
    if (quoteMatch != null) {
      final indent = quoteMatch.group(1) ?? '';
      final continuation = '$indent> ';
      final newText = oldValue.text.replaceRange(
        insertedOffset,
        insertedOffset,
        '\n$continuation',
      );
      final newCursor = insertedOffset + 1 + continuation.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    return newValue;
  }
}
