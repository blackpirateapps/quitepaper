import 'package:flutter/services.dart';

abstract final class MarkdownHelper {
  /// Wraps the current text selection with prefix and suffix.
  /// If selection is collapsed, inserts prefix and suffix with cursor between them.
  static TextEditingValue wrapSelection({
    required TextEditingValue value,
    required String prefix,
    required String suffix,
    String defaultText = '',
  }) {
    final text = value.text;
    final selection = value.selection;

    if (!selection.isValid) {
      final newText = '$text$prefix$defaultText$suffix';
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: text.length + prefix.length + defaultText.length,
        ),
      );
    }

    if (selection.isCollapsed) {
      final start = selection.start;
      final newText = text.replaceRange(start, start, '$prefix$defaultText$suffix');
      final newCursorPosition = start + prefix.length + defaultText.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursorPosition),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selectedText$suffix',
      );
      return TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.start + prefix.length + selectedText.length,
        ),
      );
    }
  }

  /// Toggles or prefixes the current line with a given line prefix (e.g. `# `, `## `, `- `, `> `).
  static TextEditingValue toggleLinePrefix({
    required TextEditingValue value,
    required String prefix,
  }) {
    final text = value.text;
    final selection = value.selection;

    final cursorPosition = selection.isValid ? selection.start : text.length;

    // Find the start of the current line
    var lineStart = 0;
    if (cursorPosition > 0) {
      lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    }

    // Find the end of the current line
    var lineEnd = text.indexOf('\n', cursorPosition);
    if (lineEnd == -1) {
      lineEnd = text.length;
    }

    final lineText = text.substring(lineStart, lineEnd);

    String newLineText;
    int cursorOffsetDelta;

    if (lineText.startsWith(prefix)) {
      // Remove prefix
      newLineText = lineText.substring(prefix.length);
      cursorOffsetDelta = -prefix.length;
    } else {
      // If line has another heading prefix (like `# ` or `## `), cycle or replace
      if (prefix.startsWith('#')) {
        final headingMatch = RegExp(r'^#{1,6}\s*').firstMatch(lineText);
        if (headingMatch != null) {
          final matched = headingMatch.group(0)!;
          newLineText = prefix + lineText.substring(matched.length);
          cursorOffsetDelta = prefix.length - matched.length;
        } else {
          newLineText = prefix + lineText;
          cursorOffsetDelta = prefix.length;
        }
      } else {
        newLineText = prefix + lineText;
        cursorOffsetDelta = prefix.length;
      }
    }

    final newText = text.replaceRange(lineStart, lineEnd, newLineText);
    final newCursor = (cursorPosition + cursorOffsetDelta).clamp(0, newText.length);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Inserts a link template `[text](url)`
  static TextEditingValue insertLink(TextEditingValue value) {
    return wrapSelection(
      value: value,
      prefix: '[',
      suffix: '](https://)',
      defaultText: 'link',
    );
  }

  /// Inserts a code block
  static TextEditingValue insertCodeBlock(TextEditingValue value) {
    return wrapSelection(
      value: value,
      prefix: '\n```\n',
      suffix: '\n```\n',
      defaultText: 'code',
    );
  }
}
