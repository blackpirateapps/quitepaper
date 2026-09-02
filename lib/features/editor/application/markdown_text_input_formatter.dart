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

  static final _emptyChecklistRegex =
      RegExp(r'^(\s*)([-*+]\s*\[[ xX]\]|[☐☑\ue45e\ue186\ue188])\s*$');
  static final _emptyUnorderedRegex = RegExp(r'^(\s*)([-*+]|•)\s*$');
  static final _emptyOrderedRegex = RegExp(r'^(\s*)(\d+)[\.\)]\s*$');
  static final _emptyQuoteRegex = RegExp(r'^(\s*)>\s*$');
  static final _checklistRegex =
      RegExp(r'^(\s*)([-*+]\s*\[[ xX]\]|[☐☑\ue45e\ue186\ue188])(\s+)');
  static final _unorderedRegex = RegExp(r'^(\s*)([-*+]|•)\s+');
  static final _orderedRegex = RegExp(r'^(\s*)(\d+)([\.\)])\s+');
  static final _quoteRegex = RegExp(r'^(\s*)>\s*');
  static final _horizontalRuleRegex = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');

  /// Fast backward search to determine if [offset] is inside a fenced code block (``` or ~~~).
  /// Avoids scanning multi-megabyte document substrings with multiline RegExp on every Enter keypress.
  static bool _isInsideCodeBlock(String text, int offset) {
    if (offset <= 0 || text.isEmpty) return false;
    if (!text.contains('```') && !text.contains('~~~')) return false;

    var fenceCount = 0;
    var pos = offset - 1;
    while (pos >= 0) {
      final idxBacktick = text.lastIndexOf('```', pos);
      final idxTilde = text.lastIndexOf('~~~', pos);
      final nextIdx = max(idxBacktick, idxTilde);
      if (nextIdx == -1) break;

      // Check if nextIdx is at the start of its line (preceded only by optional whitespace)
      var lineStart = 0;
      if (nextIdx > 0) {
        final prevNewline = text.lastIndexOf('\n', nextIdx - 1);
        if (prevNewline != -1) {
          lineStart = prevNewline + 1;
        }
      }
      var isValidFence = true;
      for (var i = lineStart; i < nextIdx; i++) {
        if (text[i] != ' ' && text[i] != '\t') {
          isValidFence = false;
          break;
        }
      }

      if (isValidFence) {
        fenceCount++;
      }

      if (lineStart == 0) break;
      pos = lineStart - 1;
    }

    return fenceCount % 2 != 0;
  }

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

    // 3. Auto-convert divider shortcut (typing 3rd '-', '*', or '_' on empty line)
    if (oldValue.selection.isValid &&
        oldValue.selection.isCollapsed &&
        newValue.text.length == oldValue.text.length + 1) {
      final cursor = oldValue.selection.start;
      if (cursor >= 0 && cursor < newValue.text.length) {
        final typedChar = newValue.text[cursor];
        if (typedChar == '-' || typedChar == '*' || typedChar == '_') {
          final lastNewline = oldValue.text.lastIndexOf('\n', cursor > 0 ? cursor - 1 : 0);
          final lineStart = lastNewline == -1 ? 0 : lastNewline + 1;
          final lineBefore = oldValue.text.substring(lineStart, cursor);
          if (lineBefore == '$typedChar$typedChar') {
            final nextNewline = oldValue.text.indexOf('\n', cursor);
            final lineEnd = nextNewline == -1 ? oldValue.text.length : nextNewline;
            final lineAfter = oldValue.text.substring(cursor, lineEnd);
            if (lineAfter.trim().isEmpty) {
              // Convert "---", "***", "___" into divider followed by newline
              final dividerText = '$typedChar$typedChar$typedChar\n';
              final newText = oldValue.text.replaceRange(lineStart, lineEnd, dividerText);
              final newCursor = lineStart + dividerText.length;
              return TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(offset: newCursor),
              );
            }
          }
        }
      }
    }

    // 4. Smart Enter behavior (only single-character newline insertion with collapsed selection)
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
    if (_isInsideCodeBlock(oldValue.text, insertedOffset)) {
      // Inside code block: standard Enter behavior with no list/quote continuation
      return newValue;
    }

    // Find the line preceding the newline insertion
    final lastNewlineIndex = oldValue.text.lastIndexOf('\n', insertedOffset > 0 ? insertedOffset - 1 : 0);
    final lineStart = lastNewlineIndex == -1 ? 0 : lastNewlineIndex + 1;
    final currentLine = oldValue.text.substring(lineStart, insertedOffset);

    // 5. Horizontal rule on line: "---", "***", "___" -> insert clean newline after divider
    if (_horizontalRuleRegex.hasMatch(currentLine)) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '${currentLine.trim()}\n');
      final newCursor = lineStart + currentLine.trim().length + 1;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    // 6. Empty checklist marker: "- [ ]", "- [x]", "☐", "☑", Phosphor glyph -> clear checklist
    final emptyChecklistMatch = _emptyChecklistRegex.firstMatch(currentLine);
    if (emptyChecklistMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 7. Empty unordered list bullet: "- ", "* ", "+ ", "• " -> clear bullet
    final emptyUnorderedMatch = _emptyUnorderedRegex.firstMatch(currentLine);
    if (emptyUnorderedMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 8. Empty ordered list marker: "1. ", "2. " -> clear marker
    final emptyOrderedMatch = _emptyOrderedRegex.firstMatch(currentLine);
    if (emptyOrderedMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 9. Empty blockquote: "> " -> clear quote
    final emptyQuoteMatch = _emptyQuoteRegex.firstMatch(currentLine);
    if (emptyQuoteMatch != null) {
      final lineEnd = oldValue.text.indexOf('\n', lineStart);
      final actualLineEnd = lineEnd == -1 ? oldValue.text.length : lineEnd;
      final newText = oldValue.text.replaceRange(lineStart, actualLineEnd, '');
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    // 10. Non-empty checklist item: continue with uncompleted checklist
    final checklistMatch = _checklistRegex.firstMatch(currentLine);
    if (checklistMatch != null) {
      final indent = checklistMatch.group(1) ?? '';
      final marker = checklistMatch.group(2) ?? '- [ ]';
      final isPhosphor = marker.contains('\uE45E') || marker.contains('\uE186') || marker.contains('\uE188');
      final isVisual = marker == '☐' || marker == '☑' || isPhosphor;
      final continuation = isVisual
          ? '$indent${isPhosphor ? '\uE45E' : '☐'} '
          : '$indent- [ ] ';
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

    // 11. Non-empty unordered list item: continue "- " or "• "
    final unorderedMatch = _unorderedRegex.firstMatch(currentLine);
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

    // 12. Non-empty ordered list item: continue with incremented number
    final orderedMatch = _orderedRegex.firstMatch(currentLine);
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

    // 13. Non-empty blockquote: continue "> "
    final quoteMatch = _quoteRegex.firstMatch(currentLine);
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
