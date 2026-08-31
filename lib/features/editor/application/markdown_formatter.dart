import 'dart:math';
import 'package:flutter/services.dart';

/// Reusable, pure-function Markdown formatting operations for selections and cursors.
abstract final class MarkdownFormatter {
  /// Toggles bold (`**text**`) on the current selection or inserts `****` at cursor.
  static TextEditingValue toggleBold({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '**',
      defaultPlaceholder: '',
    );
  }

  /// Toggles italic (`*text*`) on the current selection or inserts `**` at cursor.
  static TextEditingValue toggleItalic({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '*',
      defaultPlaceholder: '',
      disallowDoubleMarker: true,
    );
  }

  /// Toggles strikethrough (`~~text~~`) on current selection or inserts `~~~~` at cursor.
  static TextEditingValue toggleStrikethrough({required TextEditingValue value}) {
    return _toggleInlineWrapper(
      value: value,
      marker: '~~',
      defaultPlaceholder: '',
    );
  }

  /// Toggles inline code (`` `code` ``) on current selection or inserts ```` `` ```` at cursor.
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
      final start = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(start, start, '$marker$marker');
      final newCursor = start + mLen;
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

    return TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: blockStart,
        extentOffset: newEnd,
      ),
    );
  }
}
