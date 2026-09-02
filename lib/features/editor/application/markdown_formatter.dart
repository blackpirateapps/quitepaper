import 'dart:math';
import 'package:flutter/services.dart';

/// Reusable, pure-function Markdown formatting operations for selections and cursors.
abstract final class MarkdownFormatter {
  /// Checks if bold formatting is active at current selection or cursor.
  static bool isBoldAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final sel = value.selection;
    if (!sel.isCollapsed) {
      final start = min(sel.start, sel.end);
      final end = max(sel.start, sel.end);
      final selText = text.substring(start, end);
      if ((selText.startsWith('**') && selText.endsWith('**') && selText.length >= 4) ||
          (selText.startsWith('__') && selText.endsWith('__') && selText.length >= 4)) {
        return true;
      }
      if (start >= 2 && end + 2 <= text.length) {
        if ((text.substring(start - 2, start) == '**' && text.substring(end, end + 2) == '**') ||
            (text.substring(start - 2, start) == '__' && text.substring(end, end + 2) == '__')) {
          return true;
        }
      }
      return false;
    }
    final cursor = sel.start;
    if (cursor >= 2 && cursor + 2 <= text.length) {
      if ((text.substring(cursor - 2, cursor) == '**' && text.substring(cursor, cursor + 2) == '**') ||
          (text.substring(cursor - 2, cursor) == '__' && text.substring(cursor, cursor + 2) == '__')) {
        return true;
      }
    }
    return _findSpanAroundOffset(text, cursor, '**') != null;
  }

  /// Checks if italic formatting is active at current selection or cursor.
  static bool isItalicAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final sel = value.selection;
    if (!sel.isCollapsed) {
      final start = min(sel.start, sel.end);
      final end = max(sel.start, sel.end);
      final selText = text.substring(start, end);
      if ((selText.startsWith('*') && selText.endsWith('*') && !selText.startsWith('**') && selText.length >= 2) ||
          (selText.startsWith('_') && selText.endsWith('_') && !selText.startsWith('__') && selText.length >= 2)) {
        return true;
      }
      if (start >= 1 && end + 1 <= text.length) {
        final before = text.substring(start - 1, start);
        final after = text.substring(end, end + 1);
        if ((before == '*' && after == '*') || (before == '_' && after == '_')) {
          if ((start < 2 || text.substring(start - 2, start) != '**') &&
              (end + 2 > text.length || text.substring(end, end + 2) != '**')) {
            return true;
          }
        }
      }
      return false;
    }
    final cursor = sel.start;
    if (cursor >= 1 && cursor + 1 <= text.length) {
      if ((text.substring(cursor - 1, cursor) == '*' && text.substring(cursor, cursor + 1) == '*') ||
          (text.substring(cursor - 1, cursor) == '_' && text.substring(cursor, cursor + 1) == '_')) {
        if ((cursor < 2 || text.substring(cursor - 2, cursor) != '**') &&
            (cursor + 2 > text.length || text.substring(cursor, cursor + 2) != '**')) {
          return true;
        }
      }
    }
    return _findSpanAroundOffset(text, cursor, '*', disallowDouble: true) != null;
  }

  /// Checks if strikethrough formatting is active at current selection or cursor.
  static bool isStrikethroughAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final sel = value.selection;
    if (!sel.isCollapsed) {
      final start = min(sel.start, sel.end);
      final end = max(sel.start, sel.end);
      final selText = text.substring(start, end);
      if (selText.startsWith('~~') && selText.endsWith('~~') && selText.length >= 4) {
        return true;
      }
      if (start >= 2 && end + 2 <= text.length) {
        if (text.substring(start - 2, start) == '~~' && text.substring(end, end + 2) == '~~') {
          return true;
        }
      }
      return false;
    }
    final cursor = sel.start;
    if (cursor >= 2 && cursor + 2 <= text.length) {
      if (text.substring(cursor - 2, cursor) == '~~' && text.substring(cursor, cursor + 2) == '~~') {
        return true;
      }
    }
    return _findSpanAroundOffset(text, cursor, '~~') != null;
  }

  /// Checks if inline code formatting is active at current selection or cursor.
  static bool isInlineCodeAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final sel = value.selection;
    if (!sel.isCollapsed) {
      final start = min(sel.start, sel.end);
      final end = max(sel.start, sel.end);
      final selText = text.substring(start, end);
      if (selText.startsWith('`') && selText.endsWith('`') && selText.length >= 2) {
        return true;
      }
      if (start >= 1 && end + 1 <= text.length) {
        if (text.substring(start - 1, start) == '`' && text.substring(end, end + 1) == '`') {
          return true;
        }
      }
      return false;
    }
    final cursor = sel.start;
    if (cursor >= 1 && cursor + 1 <= text.length) {
      if (text.substring(cursor - 1, cursor) == '`' && text.substring(cursor, cursor + 1) == '`') {
        return true;
      }
    }
    return _findSpanAroundOffset(text, cursor, '`') != null;
  }

  /// Checks if the cursor or selection is on a heading line.
  static bool isHeadingAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final cursor = value.selection.start.clamp(0, text.length);
    final lineStart = cursor > 0 ? (text.lastIndexOf('\n', cursor - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', cursor);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    return RegExp(r'^(\s*)#{1,6}(\s|$)').hasMatch(lineText);
  }

  /// Checks if the cursor or selection is on a checklist item.
  static bool isChecklistAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final cursor = value.selection.start.clamp(0, text.length);
    final lineStart = cursor > 0 ? (text.lastIndexOf('\n', cursor - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', cursor);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    return RegExp(r'^\s*[-*+]\s*\[[ xX]\]').hasMatch(lineText);
  }

  /// Checks if the cursor or selection is on an unordered bullet list item.
  static bool isBulletListAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final cursor = value.selection.start.clamp(0, text.length);
    final lineStart = cursor > 0 ? (text.lastIndexOf('\n', cursor - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', cursor);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    return RegExp(r'^\s*[-*+]\s+(?!\[[ xX]\])').hasMatch(lineText);
  }

  /// Checks if the cursor or selection is on an ordered numbered list item.
  static bool isOrderedListAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final cursor = value.selection.start.clamp(0, text.length);
    final lineStart = cursor > 0 ? (text.lastIndexOf('\n', cursor - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', cursor);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    return RegExp(r'^\s*\d+[\.\)]\s+').hasMatch(lineText);
  }

  /// Checks if the cursor or selection is on a blockquote.
  static bool isQuoteAt(TextEditingValue value) {
    if (!value.selection.isValid) return false;
    final text = value.text;
    final cursor = value.selection.start.clamp(0, text.length);
    final lineStart = cursor > 0 ? (text.lastIndexOf('\n', cursor - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', cursor);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    return RegExp(r'^\s*>\s*').hasMatch(lineText);
  }

  /// Toggles bold (`**text**`) on the current selection or inserts/exits `****` at cursor.
  static TextEditingValue toggleBold({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '**',
      defaultPlaceholder: '',
    );
  }

  /// Toggles italic (`*text*`) on the current selection or inserts/exits `**` at cursor.
  static TextEditingValue toggleItalic({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '*',
      defaultPlaceholder: '',
      disallowDoubleMarker: true,
    );
  }

  /// Toggles strikethrough (`~~text~~`) on current selection or inserts/exits `~~~~` at cursor.
  static TextEditingValue toggleStrikethrough({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '~~',
      defaultPlaceholder: '',
    );
  }

  /// Toggles inline code (`` `code` ``) on current selection or inserts/exits ```` `` ```` at cursor.
  static TextEditingValue toggleInlineCode({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '`',
      defaultPlaceholder: '',
    );
  }

  /// Creates a Markdown link `[title](url)`.
  static TextEditingValue createLink({
    required TextEditingValue value,
    required String url,
    String? title,
  }) {
    final text = value.text;
    final selection = value.selection;

    final effectiveUrl = url.trim().isEmpty ? 'https://' : url.trim();

    if (!selection.isValid || selection.isCollapsed) {
      final start = selection.isValid ? selection.start : text.length;
      final effectiveTitle = (title != null && title.isNotEmpty) ? title : 'title';
      final linkMd = '[$effectiveTitle]($effectiveUrl)';
      final newText = text.replaceRange(start, start, linkMd);
      final newCursor = start + linkMd.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    } else {
      final selStart = min(selection.start, selection.end);
      final selEnd = max(selection.start, selection.end);
      final selectedText = text.substring(selStart, selEnd);
      final effectiveTitle = (title != null && title.isNotEmpty) ? title : selectedText;
      final linkMd = '[$effectiveTitle]($effectiveUrl)';
      final newText = text.replaceRange(selStart, selEnd, linkMd);
      final newCursor = selStart + linkMd.length;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }
  }

  /// Inserts or replaces a canonical internal note link `[displayText](qp://note/<noteId>)`.
  ///
  /// - If [replaceStart] and [replaceEnd] are provided (e.g. from `[[query` autocomplete),
  ///   the range `[replaceStart, replaceEnd]` is replaced.
  /// - If text was selected, the selected text is wrapped as display text: `[selected text](qp://note/<noteId>)`.
  /// - If no text was selected, `[targetTitle](qp://note/<noteId>)` is inserted at cursor.
  /// - Caret is positioned immediately after the closing parenthesis `)`.
  static TextEditingValue insertNoteLink({
    required TextEditingValue value,
    required String noteId,
    required String targetTitle,
    int? replaceStart,
    int? replaceEnd,
    String? displayTextOverride,
  }) {
    final text = value.text;
    final selection = value.selection;

    final hasSelection = selection.isValid && !selection.isCollapsed;
    final selectedText = hasSelection
        ? text.substring(min(selection.start, selection.end), max(selection.start, selection.end))
        : null;

    final effectiveTitle = displayTextOverride?.trim().isNotEmpty == true
        ? displayTextOverride!.trim()
        : (hasSelection && selectedText != null && selectedText.trim().isNotEmpty
            ? selectedText.trim()
            : (targetTitle.trim().isNotEmpty ? targetTitle.trim() : 'Untitled'));
    final noteUri = 'qp://note/$noteId';
    final linkMd = '[$effectiveTitle]($noteUri)';


    int start;
    int end;

    if (replaceStart != null && replaceEnd != null) {
      start = replaceStart.clamp(0, text.length);
      end = replaceEnd.clamp(start, text.length);
    } else if (selection.isValid && !selection.isCollapsed) {
      start = min(selection.start, selection.end);
      end = max(selection.start, selection.end);
    } else if (selection.isValid) {
      start = selection.start.clamp(0, text.length);
      end = start;
    } else {
      start = text.length;
      end = text.length;
    }

    final newText = text.replaceRange(start, end, linkMd);
    final newCursor = start + linkMd.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }


  /// Toggles checklist (`- [ ] `) across selected lines.
  static TextEditingValue toggleChecklist({required TextEditingValue value}) {
    return _transformSelectedLines(
      value: value,
      transformer: (lines) {
        // Check if all lines are already checklists
        final allChecklists = lines.every((line) =>
            RegExp(r'^\s*[-*+]\s*\[[ xX]\]\s*').hasMatch(line));

        if (allChecklists) {
          // If all checked, uncheck them. If any unchecked, check all.
          final allChecked = lines.every((line) =>
              RegExp(r'^\s*[-*+]\s*\[[xX]\]\s*').hasMatch(line));

          return lines.map((line) {
            if (allChecked) {
              return line.replaceFirst(RegExp(r'\[[xX]\]'), '[ ]');
            } else {
              return line.replaceFirst(RegExp(r'\[ \]'), '[x]');
            }
          }).toList();
        } else {
          // Convert lines to checklist items
          return lines.map((line) {
            final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
            final indent = indentMatch?.group(1) ?? '';
            final trimmed = line.substring(indent.length);

            // Strip existing list or quote markers
            final stripped = trimmed.replaceFirst(
                RegExp(r'^([-*+]\s*(\[[ xX]\]\s*)?|\d+[\.\)]\s+|> \s*)'), '');
            return '$indent- [ ] $stripped';
          }).toList();
        }
      },
    );
  }

  /// Toggles unordered bullet list (`- `) across selected lines.
  static TextEditingValue toggleBulletList({required TextEditingValue value}) {
    return _transformSelectedLines(
      value: value,
      transformer: (lines) {
        final allBullets = lines.every((line) =>
            RegExp(r'^\s*[-*+]\s+(?!\[[ xX]\])').hasMatch(line));

        if (allBullets) {
          // Remove bullets
          return lines.map((line) {
            final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
            final indent = indentMatch?.group(1) ?? '';
            final trimmed = line.substring(indent.length);
            final stripped = trimmed.replaceFirst(RegExp(r'^[-*+]\s+'), '');
            return '$indent$stripped';
          }).toList();
        } else {
          // Add bullets
          return lines.map((line) {
            final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
            final indent = indentMatch?.group(1) ?? '';
            final trimmed = line.substring(indent.length);
            final stripped = trimmed.replaceFirst(
                RegExp(r'^([-*+]\s*(\[[ xX]\]\s*)?|\d+[\.\)]\s+|> \s*)'), '');
            return '$indent- $stripped';
          }).toList();
        }
      },
    );
  }

  /// Toggles ordered numbered list (`1. `, `2. `) across selected lines.
  static TextEditingValue toggleOrderedList({required TextEditingValue value}) {
    return _transformSelectedLines(
      value: value,
      transformer: (lines) {
        final allOrdered = lines.every((line) =>
            RegExp(r'^\s*\d+[\.\)]\s+').hasMatch(line));

        if (allOrdered) {
          // Remove numbering
          return lines.map((line) {
            final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
            final indent = indentMatch?.group(1) ?? '';
            final trimmed = line.substring(indent.length);
            final stripped = trimmed.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '');
            return '$indent$stripped';
          }).toList();
        } else {
          // Add numbering
          var num = 1;
          return lines.map((line) {
            final indentMatch = RegExp(r'^(\s*)').firstMatch(line);
            final indent = indentMatch?.group(1) ?? '';
            final trimmed = line.substring(indent.length);
            final stripped = trimmed.replaceFirst(
                RegExp(r'^([-*+]\s*(\[[ xX]\]\s*)?|\d+[\.\)]\s+|> \s*)'), '');
            final result = '$indent$num. $stripped';
            num++;
            return result;
          }).toList();
        }
      },
    );
  }

  // --- Internal Helpers ---

  static TextEditingValue _toggleInlineWrapper({
    required TextEditingValue value,
    required String marker,
    required String defaultPlaceholder,
    bool disallowDoubleMarker = false,
  }) {
    final text = value.text;
    final selection = value.selection;
    final mLen = marker.length;

    if (!selection.isValid || selection.isCollapsed) {
      final cursor = selection.isValid ? selection.start : text.length;

      // 1. Check if cursor is directly inside an empty marker pair: e.g. "**|**"
      if (cursor >= mLen &&
          cursor + mLen <= text.length &&
          text.substring(cursor - mLen, cursor) == marker &&
          text.substring(cursor, cursor + mLen) == marker) {
        // Remove the empty marker pair
        final newText = text.replaceRange(cursor - mLen, cursor + mLen, '');
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: cursor - mLen),
        );
      }

      // 2. Check if cursor is inside an existing formatted span on the line
      final span = _findSpanAroundOffset(text, cursor, marker, disallowDouble: disallowDoubleMarker);
      if (span != null) {
        // If cursor is inside, toggle OFF by advancing cursor to after the closing delimiter
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: span.end),
        );
      }

      // 3. Otherwise, insert new empty marker pair and position cursor inside
      final newText = text.replaceRange(cursor, cursor, '$marker$marker');
      final newCursor = cursor + mLen;
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    final selStart = min(selection.start, selection.end);
    final selEnd = max(selection.start, selection.end);
    final selectedText = text.substring(selStart, selEnd);

    // 1. Check if selection itself starts and ends with marker
    if (selectedText.length >= mLen * 2 &&
        selectedText.startsWith(marker) &&
        selectedText.endsWith(marker)) {
      if (!disallowDoubleMarker ||
          (!selectedText.startsWith('**') && !selectedText.endsWith('**'))) {
        final unwrapped = selectedText.substring(mLen, selectedText.length - mLen);
        final newText = text.replaceRange(selStart, selEnd, unwrapped);
        return TextEditingValue(
          text: newText,
          selection: TextSelection(
            baseOffset: selStart,
            extentOffset: selStart + unwrapped.length,
          ),
        );
      }
    }

    // 2. Check if selection is immediately wrapped by marker outside selection
    if (selStart >= mLen &&
        selEnd + mLen <= text.length &&
        text.substring(selStart - mLen, selStart) == marker &&
        text.substring(selEnd, selEnd + mLen) == marker) {
      if (!disallowDoubleMarker ||
          (selStart < 2 || text.substring(selStart - 2, selStart) != '**')) {
        final newText = text.replaceRange(selEnd, selEnd + mLen, '');
        final cleanedText = newText.replaceRange(selStart - mLen, selStart, '');
        return TextEditingValue(
          text: cleanedText,
          selection: TextSelection(
            baseOffset: selStart - mLen,
            extentOffset: selEnd - mLen,
          ),
        );
      }
    }

    // 3. Otherwise, wrap the selection with marker
    final wrapped = '$marker$selectedText$marker';
    final newText = text.replaceRange(selStart, selEnd, wrapped);
    return TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: selStart + mLen,
        extentOffset: selStart + mLen + selectedText.length,
      ),
    );
  }

  static _SpanMatch? _findSpanAroundOffset(
    String text,
    int offset,
    String marker, {
    bool disallowDouble = false,
  }) {
    if (text.isEmpty) return null;
    final clampedOffset = offset.clamp(0, text.length);
    final lineStart = clampedOffset > 0 ? (text.lastIndexOf('\n', clampedOffset - 1) + 1) : 0;
    final nextNewline = text.indexOf('\n', clampedOffset);
    final lineEnd = nextNewline == -1 ? text.length : nextNewline;
    final lineText = text.substring(lineStart, lineEnd);
    final relOffset = clampedOffset - lineStart;
    final mLen = marker.length;

    var idx = 0;
    while (idx < lineText.length) {
      final openIdx = lineText.indexOf(marker, idx);
      if (openIdx == -1) break;

      if (disallowDouble && marker == '*') {
        if ((openIdx > 0 && lineText[openIdx - 1] == '*') ||
            (openIdx + 1 < lineText.length && lineText[openIdx + 1] == '*')) {
          idx = openIdx + 1;
          continue;
        }
      }

      var searchClose = openIdx + mLen;
      var closeIdx = -1;
      while (searchClose < lineText.length) {
        final candidate = lineText.indexOf(marker, searchClose);
        if (candidate == -1) break;
        if (disallowDouble && marker == '*') {
          if ((candidate > 0 && lineText[candidate - 1] == '*') ||
              (candidate + 1 < lineText.length && lineText[candidate + 1] == '*')) {
            searchClose = candidate + 1;
            continue;
          }
        }
        closeIdx = candidate;
        break;
      }

      if (closeIdx != -1) {
        final spanStart = openIdx;
        final spanEnd = closeIdx + mLen;
        final contentStart = openIdx + mLen;
        final contentEnd = closeIdx;

        if (relOffset >= contentStart && relOffset <= contentEnd) {
          return _SpanMatch(
            start: lineStart + spanStart,
            end: lineStart + spanEnd,
            contentStart: lineStart + contentStart,
            contentEnd: lineStart + contentEnd,
          );
        }
        idx = spanEnd;
      } else {
        idx = openIdx + mLen;
      }
    }

    if (marker == '**') {
      return _findSpanAroundOffset(text, clampedOffset, '__', disallowDouble: disallowDouble);
    }
    if (marker == '*' && !disallowDouble) {
      return _findSpanAroundOffset(text, clampedOffset, '_', disallowDouble: true);
    }

    return null;
  }

  static TextEditingValue _transformSelectedLines({
    required TextEditingValue value,
    required List<String> Function(List<String>) transformer,
  }) {
    final text = value.text;
    final selection = value.selection;

    final cursorPosition = selection.isValid ? selection.start : text.length;
    final selEnd = selection.isValid ? selection.end : text.length;
    final minOffset = min(cursorPosition, selEnd);
    final maxOffset = max(cursorPosition, selEnd);

    // Find block boundaries covering all selected lines
    var blockStart = 0;
    if (minOffset > 0) {
      blockStart = text.lastIndexOf('\n', minOffset - 1) + 1;
    }

    var blockEnd = text.indexOf('\n', maxOffset);
    if (blockEnd == -1) {
      blockEnd = text.length;
    }

    final blockText = text.substring(blockStart, blockEnd);
    final lines = blockText.split('\n');
    final transformedLines = transformer(lines);
    final newBlockText = transformedLines.join('\n');

    final newText = text.replaceRange(blockStart, blockEnd, newBlockText);
    final newEnd = blockStart + newBlockText.length;

    if (!selection.isValid || selection.isCollapsed) {
      final delta = newBlockText.length - blockText.length;
      final newCursor = (minOffset + delta).clamp(blockStart, newEnd);
      return TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newCursor),
      );
    }

    return TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: blockStart,
        extentOffset: newEnd,
      ),
    );
  }
}

class _SpanMatch {
  final int start;
  final int end;
  final int contentStart;
  final int contentEnd;

  const _SpanMatch({
    required this.start,
    required this.end,
    required this.contentStart,
    required this.contentEnd,
  });
}

