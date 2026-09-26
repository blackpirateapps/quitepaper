import 'package:flutter/services.dart';

import 'code_block_scanner.dart';

/// Represents a detected slash command trigger (`/query`) within an active text buffer.
class SlashCommandTrigger {
  const SlashCommandTrigger({
    required this.query,
    required this.triggerStart,
    required this.queryEnd,
  });

  /// The filtered search query following the '/' character (e.g. 'h1', 'todo', 'table').
  final String query;

  /// The character offset where the '/' begins.
  final int triggerStart;

  /// The character offset where the trigger ends (at caret).
  final int queryEnd;

  /// Analyzes the given [value] and returns a [SlashCommandTrigger] if the caret is
  /// positioned immediately after a '/' command prefix at the start of a line or after empty space.
  static SlashCommandTrigger? detect(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final text = value.text;
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) return null;

    // P3-1: suppress slash commands inside a fenced code block, matching the
    // tag and note-link triggers.
    if (isInsideFencedCodeBlock(text, cursor)) return null;

    // Determine the current line start
    final lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    final lineText = text.substring(lineStart, cursor);

    // Look for '/' on this line
    final slashIndexInLine = lineText.lastIndexOf('/');
    if (slashIndexInLine == -1) return null;

    final prefix = lineText.substring(0, slashIndexInLine);
    // Ensure prefix on this line is only whitespace (e.g. at line start or indentation)
    if (prefix.trim().isNotEmpty) return null;

    final query = lineText.substring(slashIndexInLine + 1);
    // Dismiss if query contains whitespace or newlines
    if (query.contains(' ') || query.contains('\t') || query.contains('\n')) {
      return null;
    }

    final triggerStart = lineStart + slashIndexInLine;
    return SlashCommandTrigger(
      query: query,
      triggerStart: triggerStart,
      queryEnd: cursor,
    );
  }
}
