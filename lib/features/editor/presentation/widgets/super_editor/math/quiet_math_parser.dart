import 'package:super_editor/super_editor.dart';

import 'quiet_math_block_node.dart';

/// Parsed information about a block math match.
class ParsedBlockMath {
  const ParsedBlockMath({
    required this.latex,
    required this.delimiterType,
  });

  final String latex;
  final MathDelimiterType delimiterType;
}

/// Parsed information about an inline math match inside a text span.
class InlineMathMatch {
  const InlineMathMatch({
    required this.start,
    required this.end,
    required this.latex,
    required this.rawMatch,
    required this.isBracket,
  });

  /// Start offset in the original string (inclusive).
  final int start;

  /// End offset in the original string (exclusive).
  final int end;

  /// Cleaned LaTeX content without enclosing delimiters.
  final String latex;

  /// The full matched text including delimiters.
  final String rawMatch;

  /// Whether this used `\(...\)` delimiters (false if `$..$`).
  final bool isBracket;
}

/// Delimiter patterns for block and inline math.
class QuietMathParser {
  QuietMathParser._();

  static final RegExp _bracketBlockRegex = RegExp(
    r'^\s*(?:\\{1,2}\[|\[)([\s\S]*?)(?:\\{1,2}\]|\])\s*$',
  );

  static final RegExp _dollarBlockRegex = RegExp(
    r'^\s*\$\$([\s\S]*?)\$\$\s*$',
  );

  static final RegExp _inlineBracketRegex = RegExp(
    r'(?<!\\)\\{1,2}\(([\s\S]+?)(?<!\\)\\{1,2}\)',
  );

  static final RegExp _inlineDollarRegex = RegExp(
    r'(?<!\$)\$(?!\$)([^\$\n]+?)(?<!\$)\$(?!\$)',
  );

  /// Repairs legacy Markdown escaping artifacts (e.g. `\_` -> `_` or `\*` -> `*`)
  /// introduced by earlier CommonMark serialization passes.
  static String cleanCorruptedEscapes(String text) {
    if (!text.contains(r'\_') && !text.contains(r'\*')) {
      return text;
    }
    return text.replaceAll(r'\_', '_').replaceAll(r'\*', '*');
  }

  /// Attempts to parse [text] as a standalone block math expression.
  /// Returns `null` if [text] is not a block math expression.
  static ParsedBlockMath? parseBlockMath(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final bracketMatch = _bracketBlockRegex.firstMatch(trimmed);
    if (bracketMatch != null) {
      final raw = bracketMatch.group(1)?.trim() ?? '';
      // If it started with raw `[` without backslash, only treat as math if it contains LaTeX syntax (\, _, ^, =)
      if (RegExp(r'^\\{1,2}\[').hasMatch(trimmed) || raw.contains(r'\') || raw.contains('_') || raw.contains('^') || raw.contains('=')) {
        return ParsedBlockMath(
          latex: cleanCorruptedEscapes(raw),
          delimiterType: MathDelimiterType.brackets,
        );
      }
    }

    final dollarMatch = _dollarBlockRegex.firstMatch(trimmed);
    if (dollarMatch != null) {
      final raw = dollarMatch.group(1)?.trim() ?? '';
      return ParsedBlockMath(
        latex: cleanCorruptedEscapes(raw),
        delimiterType: MathDelimiterType.dollars,
      );
    }

    return null;
  }

  /// Finds all non-overlapping inline math spans (`\(...\)` and `$...$`) in [text].
  static List<InlineMathMatch> findInlineMathMatches(String text) {
    if (text.isEmpty) return const [];

    final matches = <InlineMathMatch>[];

    // 1. Find `\( ... \)` and `\\( ... \\)` matches
    for (final m in _inlineBracketRegex.allMatches(text)) {
      final raw = m.group(1)?.trim() ?? '';
      final full = m.group(0)!;
      if (raw.isNotEmpty) {
        matches.add(InlineMathMatch(
          start: m.start,
          end: m.end,
          latex: cleanCorruptedEscapes(raw),
          rawMatch: full,
          isBracket: true,
        ));
      }
    }

    // 2. Find `$ ... $` matches that do not overlap with bracket matches
    for (final m in _inlineDollarRegex.allMatches(text)) {
      final raw = m.group(1)?.trim() ?? '';
      if (raw.isNotEmpty) {
        final overlaps = matches.any(
          (existing) => !(m.end <= existing.start || m.start >= existing.end),
        );
        if (!overlaps) {
          matches.add(InlineMathMatch(
            start: m.start,
            end: m.end,
            latex: cleanCorruptedEscapes(raw),
            rawMatch: m.group(0)!,
            isBracket: false,
          ));
        }
      }
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    return matches;
  }
}

/// Post-deserialization promotion pass that detects math block paragraphs
/// and replaces them with [QuietMathBlockNode] instances.
void promoteQuietMathBlockNodes(MutableDocument document) {
  for (int i = 0; i < document.nodeCount; i++) {
    final node = document.getNodeAt(i);

    // Case 1: Code block with language "math"
    if (node is ParagraphNode &&
        node.metadata[NodeMetadata.blockType] == codeAttribution) {
      final lang = (node.metadata['language'] as String?)?.trim().toLowerCase();
      if (lang == 'math' || lang == 'latex' || lang == 'tex') {
        final mathNode = QuietMathBlockNode(
          id: node.id,
          latex: QuietMathParser.cleanCorruptedEscapes(node.text.toPlainText().trim()),
          delimiterType: MathDelimiterType.codeFence,
        );
        document.replaceNodeById(node.id, mathNode);
        continue;
      }
    }

    // Case 2: Standalone paragraph matching `\[ ... \]` or `$$ ... $$`
    if (node is ParagraphNode) {
      final parsed = QuietMathParser.parseBlockMath(node.text.toPlainText());
      if (parsed != null && parsed.latex.isNotEmpty) {
        final mathNode = QuietMathBlockNode(
          id: node.id,
          latex: parsed.latex,
          delimiterType: parsed.delimiterType,
        );
        document.replaceNodeById(node.id, mathNode);
        continue;
      }
    }
  }
}
