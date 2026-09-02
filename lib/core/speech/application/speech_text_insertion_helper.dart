import 'package:flutter/material.dart';

class SpeechTextInsertionHelper {
  /// Inserts [transcript] at [selection] in [currentText], applying minimal
  /// context-aware whitespace normalization so sentences flow naturally.
  static TextEditingValue insertTranscript({
    required String currentText,
    required TextSelection selection,
    required String transcript,
  }) {
    final cleanTranscript = transcript.trim();
    if (cleanTranscript.isEmpty) {
      return TextEditingValue(
        text: currentText,
        selection: selection,
      );
    }

    int start = selection.start;
    int end = selection.end;

    // Handle invalid selection by appending to text or placing at 0
    if (start < 0 || end < 0) {
      start = currentText.length;
      end = currentText.length;
    }
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }
    if (start > currentText.length) start = currentText.length;
    if (end > currentText.length) end = currentText.length;

    final before = currentText.substring(0, start);
    final after = currentText.substring(end);

    // Determine leading space requirement:
    // If there is text before and it doesn't end in whitespace or newline or opening bracket/quote/markdown delimiter
    String leadingSpace = '';
    if (before.isNotEmpty) {
      final lastChar = before[before.length - 1];
      if (!_isLeadingSeparator(lastChar)) {
        leadingSpace = ' ';
      }
    }

    // Determine trailing space requirement:
    // If there is text after and it doesn't start with whitespace, newline, or closing punctuation
    String trailingSpace = '';
    if (after.isNotEmpty) {
      final firstChar = after[0];
      if (!_isTrailingSeparator(firstChar)) {
        // If transcript does not end in whitespace or hyphen
        final lastTransChar = cleanTranscript[cleanTranscript.length - 1];
        if (lastTransChar != ' ' && lastTransChar != '-') {
          trailingSpace = ' ';
        }
      }
    }

    final formattedInsertion = '$leadingSpace$cleanTranscript$trailingSpace';
    final newText = '$before$formattedInsertion$after';
    final newCursorOffset = start + formattedInsertion.length;

    return TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorOffset),
    );
  }

  static bool _isLeadingSeparator(String char) {
    return char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        char == '(' ||
        char == '[' ||
        char == '{' ||
        char == '>' ||
        char == '"' ||
        char == "'" ||
        char == '`';
  }

  static bool _isTrailingSeparator(String char) {
    return char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        char == '.' ||
        char == ',' ||
        char == '!' ||
        char == '?' ||
        char == ';' ||
        char == ':' ||
        char == ')' ||
        char == ']' ||
        char == '}' ||
        char == '"' ||
        char == "'" ||
        char == '`';
  }
}
