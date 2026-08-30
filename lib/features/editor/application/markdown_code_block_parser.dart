import 'package:flutter/foundation.dart';

/// Metadata describing a fenced code block detected in a Markdown document.
@immutable
class MarkdownCodeBlockInfo {
  const MarkdownCodeBlockInfo({
    required this.openingFenceLineStart,
    required this.openingFenceLineEnd,
    required this.rawLanguage,
    required this.delimiter,
    required this.bodyStart,
    required this.bodyEnd,
    this.closingFenceLineStart,
    this.closingFenceLineEnd,
    required this.isClosed,
  });

  /// Character offset where opening fence line begins.
  final int openingFenceLineStart;

  /// Character offset where opening fence line ends (excluding newline).
  final int openingFenceLineEnd;

  /// Raw language identifier extracted from opening fence (e.g. 'dart', 'python', or empty string).
  final String rawLanguage;

  /// Delimiter used ('```' or '~~~').
  final String delimiter;

  /// Start offset of the code block body content.
  final int bodyStart;

  /// End offset of the code block body content.
  final int bodyEnd;

  /// Start offset of closing fence line if block is closed, null otherwise.
  final int? closingFenceLineStart;

  /// End offset of closing fence line if block is closed, null otherwise.
  final int? closingFenceLineEnd;

  /// Whether this block has a matching closing fence delimiter.
  final bool isClosed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownCodeBlockInfo &&
          runtimeType == other.runtimeType &&
          openingFenceLineStart == other.openingFenceLineStart &&
          openingFenceLineEnd == other.openingFenceLineEnd &&
          rawLanguage == other.rawLanguage &&
          delimiter == other.delimiter &&
          bodyStart == other.bodyStart &&
          bodyEnd == other.bodyEnd &&
          closingFenceLineStart == other.closingFenceLineStart &&
          closingFenceLineEnd == other.closingFenceLineEnd &&
          isClosed == other.isClosed;

  @override
  int get hashCode => Object.hash(
        openingFenceLineStart,
        openingFenceLineEnd,
        rawLanguage,
        delimiter,
        bodyStart,
        bodyEnd,
        closingFenceLineStart,
        closingFenceLineEnd,
        isClosed,
      );
}

/// A high-performance, deterministic scanner locating all fenced code blocks in Markdown text.
abstract final class MarkdownCodeBlockParser {
  static final RegExp _fenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');

  /// Parses [text] and returns all detected fenced code blocks.
  static List<MarkdownCodeBlockInfo> parse(String text) {
    if (text.isEmpty) return const [];

    final blocks = <MarkdownCodeBlockInfo>[];
    var lineStart = 0;

    while (lineStart < text.length) {
      final nextNewline = text.indexOf('\n', lineStart);
      final lineEnd = nextNewline == -1 ? text.length : nextNewline;
      final lineText = text.substring(lineStart, lineEnd);

      final match = _fenceRegex.firstMatch(lineText);
      if (match != null) {
        final delim = match.group(2)!;
        final rawLang = match.group(3)?.trim() ?? '';
        final openingStart = lineStart;
        final openingEnd = lineEnd;

        // Scan ahead for matching closing fence
        var searchStart = nextNewline == -1 ? text.length : nextNewline + 1;
        var foundClosing = false;
        var closingStart = -1;
        var closingEnd = -1;
        var bodyStart = searchStart;
        var bodyEnd = text.length;

        while (searchStart < text.length) {
          final scanNewline = text.indexOf('\n', searchStart);
          final scanLineEnd = scanNewline == -1 ? text.length : scanNewline;
          final candidateLine = text.substring(searchStart, scanLineEnd);

          final candidateMatch = _fenceRegex.firstMatch(candidateLine);
          if (candidateMatch != null && candidateMatch.group(2) == delim) {
            foundClosing = true;
            closingStart = searchStart;
            closingEnd = scanLineEnd;
            bodyEnd = searchStart > bodyStart ? searchStart - 1 : bodyStart;
            lineStart = scanNewline == -1 ? text.length : scanNewline + 1;
            break;
          }

          if (scanNewline == -1) break;
          searchStart = scanNewline + 1;
        }

        if (foundClosing) {
          blocks.add(MarkdownCodeBlockInfo(
            openingFenceLineStart: openingStart,
            openingFenceLineEnd: openingEnd,
            rawLanguage: rawLang,
            delimiter: delim,
            bodyStart: bodyStart,
            bodyEnd: bodyEnd,
            closingFenceLineStart: closingStart,
            closingFenceLineEnd: closingEnd,
            isClosed: true,
          ));
          continue;
        } else {
          // Unclosed code block spanning to end of document
          blocks.add(MarkdownCodeBlockInfo(
            openingFenceLineStart: openingStart,
            openingFenceLineEnd: openingEnd,
            rawLanguage: rawLang,
            delimiter: delim,
            bodyStart: bodyStart,
            bodyEnd: text.length,
            isClosed: false,
          ));
          break;
        }
      }

      if (nextNewline == -1) break;
      lineStart = nextNewline + 1;
    }

    return blocks;
  }
}
