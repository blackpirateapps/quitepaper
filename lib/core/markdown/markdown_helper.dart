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

  /// Returns heading level (1..6) at current selection/cursor position, or null if not a heading.
  static int? getHeadingLevelAt(TextEditingValue value) {
    final text = value.text;
    final selection = value.selection;
    final cursorPosition = selection.isValid ? selection.start : text.length;

    var lineStart = 0;
    if (cursorPosition > 0 && cursorPosition <= text.length) {
      lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    }
    var lineEnd = text.indexOf('\n', cursorPosition.clamp(0, text.length));
    if (lineEnd == -1) lineEnd = text.length;

    final lineText = text.substring(lineStart, lineEnd);
    final match = RegExp(r'^(#{1,6})\s+').firstMatch(lineText);
    if (match != null) {
      return match.group(1)!.length;
    }
    return null;
  }

  /// Sets heading level (1..6) or removes heading (0) on the current line.
  static TextEditingValue setHeadingLevelAt({
    required TextEditingValue value,
    required int level,
  }) {
    final text = value.text;
    final selection = value.selection;
    final cursorPosition = selection.isValid ? selection.start : text.length;

    var lineStart = 0;
    if (cursorPosition > 0 && cursorPosition <= text.length) {
      lineStart = text.lastIndexOf('\n', cursorPosition - 1) + 1;
    }
    var lineEnd = text.indexOf('\n', cursorPosition.clamp(0, text.length));
    if (lineEnd == -1) lineEnd = text.length;

    final lineText = text.substring(lineStart, lineEnd);
    var cleanLine = lineText;
    var removedLength = 0;

    final match = RegExp(r'^#{1,6}\s*').firstMatch(lineText);
    if (match != null) {
      cleanLine = lineText.substring(match.group(0)!.length);
      removedLength = match.group(0)!.length;
    }

    final prefix = level > 0 ? '${'#' * level} ' : '';
    final newLineText = '$prefix$cleanLine';
    final cursorOffsetDelta = prefix.length - removedLength;

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
  static TextEditingValue insertCodeBlock(TextEditingValue value, {String language = ''}) {
    return wrapSelection(
      value: value,
      prefix: '\n```$language\n',
      suffix: '\n```\n',
      defaultText: 'code',
    );
  }

  /// Returns the current language identifier of the code block at cursor, or null if cursor is not inside a code block.
  static String? getCodeBlockLanguageAtCursor(TextEditingValue value) {
    final text = value.text;
    final cursor = value.selection.isValid ? value.selection.baseOffset : text.length;
    final fenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');

    var inCodeBlock = false;
    var currentFenceDelimiter = '';
    String? currentLanguage;
    var lineStart = 0;

    while (lineStart <= text.length) {
      final nextNewline = text.indexOf('\n', lineStart);
      final lineEnd = nextNewline == -1 ? text.length : nextNewline;
      final lineText = text.substring(lineStart, lineEnd);

      final match = fenceRegex.firstMatch(lineText);
      if (match != null) {
        final delim = match.group(2)!;
        if (!inCodeBlock) {
          inCodeBlock = true;
          currentFenceDelimiter = delim;
          currentLanguage = match.group(3)?.trim();
        } else if (delim == currentFenceDelimiter) {
          if (cursor >= lineStart && cursor <= lineEnd) {
            return currentLanguage ?? '';
          }
          inCodeBlock = false;
          currentLanguage = null;
        }
      }

      if (cursor >= lineStart && cursor <= lineEnd + 1 && inCodeBlock) {
        return currentLanguage ?? '';
      }

      if (nextNewline == -1) break;
      lineStart = nextNewline + 1;
    }

    return inCodeBlock ? (currentLanguage ?? '') : null;
  }

  /// Sets or changes the language identifier of the code block at cursor.
  static TextEditingValue changeCodeBlockLanguage({
    required TextEditingValue value,
    required String newLanguage,
  }) {
    final text = value.text;
    final cursor = value.selection.isValid ? value.selection.baseOffset : text.length;
    final fenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');

    var lineStart = 0;
    var inCodeBlock = false;
    var currentFenceDelimiter = '';
    var openingFenceLineStart = -1;
    var openingFenceLineEnd = -1;
    Match? openingFenceMatch;

    while (lineStart <= text.length) {
      final nextNewline = text.indexOf('\n', lineStart);
      final lineEnd = nextNewline == -1 ? text.length : nextNewline;
      final lineText = text.substring(lineStart, lineEnd);

      final match = fenceRegex.firstMatch(lineText);
      if (match != null) {
        final delim = match.group(2)!;
        if (!inCodeBlock) {
          inCodeBlock = true;
          currentFenceDelimiter = delim;
          openingFenceLineStart = lineStart;
          openingFenceLineEnd = lineEnd;
          openingFenceMatch = match;
        } else if (delim == currentFenceDelimiter) {
          if (cursor >= openingFenceLineStart && cursor <= lineEnd) {
            break;
          }
          inCodeBlock = false;
          openingFenceMatch = null;
        }
      }

      if (nextNewline == -1) break;
      lineStart = nextNewline + 1;
    }

    if (openingFenceMatch != null && openingFenceLineStart != -1) {
      final indent = openingFenceMatch.group(1) ?? '';
      final delimiter = openingFenceMatch.group(2) ?? '```';
      final newLineText = '$indent$delimiter$newLanguage';

      final delta = newLineText.length - (openingFenceLineEnd - openingFenceLineStart);
      final newText = text.replaceRange(openingFenceLineStart, openingFenceLineEnd, newLineText);
      final newCursor = (cursor + (cursor > openingFenceLineEnd ? delta : 0)).clamp(0, newText.length);

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    return value;
  }

  /// Sets or changes the language identifier of the code block whose opening fence line
  /// spans from [openingFenceLineStart] to [openingFenceLineEnd].
  static TextEditingValue replaceCodeBlockLanguageAtLine({
    required TextEditingValue value,
    required int openingFenceLineStart,
    required int openingFenceLineEnd,
    required String newLanguage,
  }) {
    final text = value.text;
    if (openingFenceLineStart < 0 ||
        openingFenceLineEnd > text.length ||
        openingFenceLineStart > openingFenceLineEnd) {
      return value;
    }

    final cursor = value.selection.isValid ? value.selection.baseOffset : text.length;
    final lineText = text.substring(openingFenceLineStart, openingFenceLineEnd);
    final fenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');
    final match = fenceRegex.firstMatch(lineText);

    if (match != null) {
      final indent = match.group(1) ?? '';
      final delim = match.group(2) ?? '```';
      final newLineText = '$indent$delim$newLanguage';

      final delta = newLineText.length - (openingFenceLineEnd - openingFenceLineStart);
      final newText = text.replaceRange(openingFenceLineStart, openingFenceLineEnd, newLineText);
      final newCursor = (cursor + (cursor > openingFenceLineEnd ? delta : 0)).clamp(0, newText.length);

      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    return value;
  }
}
