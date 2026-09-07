import 'dart:math';
import 'package:flutter/services.dart';

/// Represents an active `#query` tag autocomplete trigger within editable text.
class TagAutocompleteTrigger {
  const TagAutocompleteTrigger({
    required this.triggerStart,
    required this.queryStart,
    required this.queryEnd,
    required this.query,
  });

  /// The UTF-16 starting index of `#` in the text.
  final int triggerStart;

  /// The UTF-16 starting index of the query text (immediately following `#`).
  final int queryStart;

  /// The UTF-16 ending index of the query text (usually current caret position).
  final int queryEnd;

  /// The query string typed by the user after `#`.
  final String query;

  /// Length of the entire trigger span (`#` + query).
  int get fullLength => queryEnd - triggerStart;

  /// Fast backward search to determine if [offset] is inside a fenced code block (``` or ~~~).
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

  /// Characters that terminate a hashtag query or indicate that it is not a hashtag.
  static final RegExp _tagTerminatorRegex = RegExp(r'''[\s.,!?()\[\]{}"`'><:;]''');

  /// Evaluates [value] and returns an active [TagAutocompleteTrigger] if the caret
  /// is positioned after an unclosed `#` trigger followed by 1 or more tag characters.
  ///
  /// Rule: `#` alone returns `null` (nothing appears).
  /// `# ` (hash followed by space) returns `null`.
  /// `#a` returns trigger with query `'a'`.
  static TagAutocompleteTrigger? detect(TextEditingValue value) {
    if (!value.selection.isValid || !value.selection.isCollapsed) {
      return null;
    }

    final text = value.text;
    final cursor = value.selection.start;
    if (cursor < 2 || cursor > text.length) {
      return null;
    }

    // Check if inside a code block
    if (_isInsideCodeBlock(text, cursor)) {
      return null;
    }

    // Find start of current line
    var lineStart = 0;
    if (cursor > 0) {
      lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    }

    final lineUpToCursor = text.substring(lineStart, cursor);
    final lastHash = lineUpToCursor.lastIndexOf('#');
    if (lastHash == -1) {
      return null;
    }

    final absoluteHashStart = lineStart + lastHash;

    // Check if preceded by an alphanumeric character (e.g. foo#bar is not a tag)
    if (lastHash > 0) {
      final prevChar = lineUpToCursor[lastHash - 1];
      if (RegExp(r'[a-zA-Z0-9]').hasMatch(prevChar)) {
        return null;
      }
    }

    // Check if hash was escaped with a backslash `\#`
    if (absoluteHashStart > 0 && text[absoluteHashStart - 1] == '\\') {
      var backslashCount = 0;
      var idx = absoluteHashStart - 1;
      while (idx >= 0 && text[idx] == '\\') {
        backslashCount++;
        idx--;
      }
      if (backslashCount % 2 == 1) {
        return null;
      }
    }

    final queryStart = absoluteHashStart + 1;
    final queryEnd = cursor;
    if (queryStart >= queryEnd) {
      // User typed `#` alone: nothing appears
      return null;
    }

    final query = text.substring(queryStart, queryEnd);

    // If query contains whitespace or punctuation, the tag trigger is terminated or invalid
    if (_tagTerminatorRegex.hasMatch(query)) {
      return null;
    }

    return TagAutocompleteTrigger(
      triggerStart: absoluteHashStart,
      queryStart: queryStart,
      queryEnd: queryEnd,
      query: query,
    );
  }
}
