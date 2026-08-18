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

  /// Cycles heading levels on the current line:
  /// (No heading) -> `# ` (H1) -> `## ` (H2) -> `### ` (H3) -> (No heading)
  static TextEditingValue cycleHeading(TextEditingValue value) {
    final text = value.text;
    final selection = value.selection;

    final cursorPosition = selection.isValid ? selection.start : text.length;

    var lineStart = 0;
    if (cursorPosition > 0) {
      lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    }

    var lineEnd = text.indexOf('\n', cursorPosition);
    if (lineEnd == -1) {
      lineEnd = text.length;
    }

    final lineText = text.substring(lineStart, lineEnd);

    String newLineText;
    int cursorOffsetDelta;

    if (lineText.startsWith('### ')) {
      // Remove H3
      newLineText = lineText.substring(4);
      cursorOffsetDelta = -4;
    } else if (lineText.startsWith('## ')) {
      // H2 -> H3
      newLineText = '### ${lineText.substring(3)}';
      cursorOffsetDelta = 1;
    } else if (lineText.startsWith('# ')) {
      // H1 -> H2
      newLineText = '## ${lineText.substring(2)}';
      cursorOffsetDelta = 1;
    } else {
      // Check if any other heading exists
      final headingMatch = RegExp(r'^#{1,6}\s*').firstMatch(lineText);
      if (headingMatch != null) {
        newLineText = lineText.substring(headingMatch.group(0)!.length);
        cursorOffsetDelta = -headingMatch.group(0)!.length;
      } else {
        // (None) -> H1
        newLineText = '# $lineText';
        cursorOffsetDelta = 2;
      }
    }

    final newText = text.replaceRange(lineStart, lineEnd, newLineText);
    final newCursor = (cursorPosition + cursorOffsetDelta).clamp(0, newText.length);

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  /// Toggles or prefixes the current line with a given line prefix (e.g. `- `, `1. `, `> `).
  static TextEditingValue toggleLinePrefix({
    required TextEditingValue value,
    required String prefix,
  }) {
    final text = value.text;
    final selection = value.selection;

    final cursorPosition = selection.isValid ? selection.start : text.length;

    var lineStart = 0;
    if (cursorPosition > 0) {
      lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    }

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
      // Remove any other conflicting list or quote prefixes
      var cleanedLine = lineText;
      var removedLength = 0;

      final listMatch = RegExp(r'^([-*+]\s+|\d+\.\s+|> \s*)').firstMatch(lineText);
      if (listMatch != null) {
        final matchStr = listMatch.group(0)!;
        cleanedLine = lineText.substring(matchStr.length);
        removedLength = matchStr.length;
      }

      newLineText = prefix + cleanedLine;
      cursorOffsetDelta = prefix.length - removedLength;
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
    final text = value.text;
    final selection = value.selection;

    if (selection.isValid && !selection.isCollapsed) {
      final selectedText = text.substring(selection.start, selection.end);
      // If user selected an actual URL, make it [title](selected_url)
      if (selectedText.startsWith('http://') || selectedText.startsWith('https://')) {
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          '[title]($selectedText)',
        );
        return TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selection.start + 1,
            extentOffset: selection.start + 6,
          ),
        );
      }
    }

    return wrapSelection(
      value: value,
      prefix: '[',
      suffix: '](https://)',
      defaultText: 'title',
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
