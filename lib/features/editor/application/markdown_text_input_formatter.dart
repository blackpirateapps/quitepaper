import 'package:flutter/services.dart';

/// Formatter that handles Markdown newline behaviors:
/// - Auto-continuation for unordered lists (`- `, `* `, `+ `)
/// - Auto-increment continuation for ordered lists (`1. `, `2. `, etc.)
/// - Auto-continuation for blockquotes (`> `)
/// - Auto-clearing when pressing Enter on an empty list or quote marker
class MarkdownTextInputFormatter extends TextInputFormatter {
  const MarkdownTextInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only intercept single-character newline insertions with collapsed selections
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

    // Find the line preceding the newline insertion
    final textBeforeCursor = oldValue.text.substring(0, insertedOffset);
    final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');
    final lineStart = lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1;
    final currentLine = textBeforeCursor.substring(lineStart);

    // 1. Empty unordered list bullet: e.g. "- ", "* ", "+ " -> clear bullet
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

    // 2. Empty ordered list marker: e.g. "1. ", "2. ", "1) " -> clear marker
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

    // 3. Empty blockquote: e.g. "> " -> clear quote
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

    // 4. Non-empty unordered list item: continue "- "
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

    // 5. Non-empty ordered list item: continue with incremented number
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

    // 6. Non-empty blockquote: continue "> "
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
