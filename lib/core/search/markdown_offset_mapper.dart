import 'dart:math';
import 'search_models.dart';

/// Normalized text bundle retaining 1:1 character mapping back to canonical Markdown source.
class NormalizedSearchText {
  final String normalizedText;
  final String sourceText;
  final List<int> normalizedToSourceMap;

  const NormalizedSearchText({
    required this.normalizedText,
    required this.sourceText,
    required this.normalizedToSourceMap,
  });

  static const NormalizedSearchText empty = NormalizedSearchText(
    normalizedText: '',
    sourceText: '',
    normalizedToSourceMap: [],
  );

  /// Maps a start/end span from normalized text back to original Markdown source character offsets.
  TokenSpanDto mapToSourceSpan(TokenSpanDto normalizedSpan) {
    if (normalizedToSourceMap.isEmpty || normalizedText.isEmpty) {
      return normalizedSpan;
    }

    final startIdx = normalizedSpan.start.clamp(0, normalizedToSourceMap.length - 1);
    final endIdx = (normalizedSpan.end - 1).clamp(0, normalizedToSourceMap.length - 1);

    final sourceStart = normalizedToSourceMap[startIdx];
    final sourceEnd = normalizedToSourceMap[endIdx] + 1;

    return TokenSpanDto(
      start: sourceStart,
      end: max(sourceStart, sourceEnd),
      isExact: normalizedSpan.isExact,
    );
  }
}

/// Result of snippet extraction containing formatted snippet string and adjusted relative highlight spans.
class SnippetResult {
  final String snippet;
  final List<TokenSpanDto> highlightSpans;

  const SnippetResult({
    required this.snippet,
    required this.highlightSpans,
  });

  static const SnippetResult empty = SnippetResult(
    snippet: '',
    highlightSpans: [],
  );
}

/// High-performance Markdown stripper and offset mapper for search indexing, snippet extraction,
/// and highlight positioning.
class MarkdownOffsetMapper {
  const MarkdownOffsetMapper();

  /// Normalizes markdown text to searchable text while maintaining an exact character offset map.
  static NormalizedSearchText normalize(String markdown) {
    if (markdown.isEmpty) return NormalizedSearchText.empty;

    final normBuffer = StringBuffer();
    final map = <int>[];
    final len = markdown.length;

    var i = 0;
    var inFrontmatter = false;
    var lineStart = true;

    // Check frontmatter at index 0
    if (markdown.startsWith('---')) {
      inFrontmatter = true;
      i = 3;
    }

    while (i < len) {
      // 1. Handle frontmatter
      if (inFrontmatter) {
        if (markdown.startsWith('\n---', i) || markdown.startsWith('\r\n---', i)) {
          final jump = markdown.startsWith('\r\n---', i) ? 5 : 4;
          i += jump;
          inFrontmatter = false;
          lineStart = true;
        } else {
          i++;
        }
        continue;
      }

      // 2. Line start markers (headings, blockquotes, list bullets, checkboxes)
      if (lineStart) {
        // Skip leading whitespace
        while (i < len && (markdown[i] == ' ' || markdown[i] == '\t')) {
          i++;
        }
        if (i >= len) break;

        // Skip heading hashes (# to ######)
        if (markdown[i] == '#') {
          while (i < len && markdown[i] == '#') {
            i++;
          }
          while (i < len && (markdown[i] == ' ' || markdown[i] == '\t')) {
            i++;
          }
        }
        // Skip blockquotes (> or >>)
        else if (markdown[i] == '>') {
          while (i < len && (markdown[i] == '>' || markdown[i] == ' ' || markdown[i] == '\t')) {
            i++;
          }
        }
        // Skip list bullets and checklists: - [ ] , - [x] , * , - , + , 1.
        else if (markdown.startsWith('- [ ] ', i) || markdown.startsWith('- [x] ', i) || markdown.startsWith('- [X] ', i)) {
          i += 6;
        } else if ((markdown[i] == '-' || markdown[i] == '*' || markdown[i] == '+') && i + 1 < len && markdown[i + 1] == ' ') {
          i += 2;
        } else if (RegExp(r'^\d+\.\s').matchAsPrefix(markdown, i) case final m?) {
          i += m.end - m.start;
        }
        lineStart = false;
        if (i >= len) break;
      }

      if (i >= len) break;
      final c = markdown[i];

      if (c == '\n' || c == '\r') {
        if (normBuffer.isNotEmpty && !normBuffer.toString().endsWith(' ')) {
          normBuffer.write(' ');
          map.add(i);
        }
        lineStart = true;
        i++;
        continue;
      }

      // 3. Skip Markdown Images: ![alt](url) -> replace with 'image'
      if (markdown.startsWith('![', i)) {
        final closeBracket = markdown.indexOf(']', i + 2);
        if (closeBracket != -1 && closeBracket + 1 < len && markdown[closeBracket + 1] == '(') {
          final closeParen = markdown.indexOf(')', closeBracket + 2);
          if (closeParen != -1) {
            const replacement = 'image';
            for (var k = 0; k < replacement.length; k++) {
              normBuffer.write(replacement[k]);
              map.add(i); // Map back to start of image token
            }
            i = closeParen + 1;
            continue;
          }
        }
      }

      // 4. Skip Markdown Links: [link text](url) -> keep 'link text'
      if (c == '[') {
        final closeBracket = markdown.indexOf(']', i + 1);
        if (closeBracket != -1 && closeBracket + 1 < len && markdown[closeBracket + 1] == '(') {
          final closeParen = markdown.indexOf(')', closeBracket + 2);
          if (closeParen != -1) {
            // Process inner link text character by character
            for (var j = i + 1; j < closeBracket; j++) {
              final innerChar = markdown[j];
              // Skip formatting delimiters inside link text
              if (innerChar == '*' || innerChar == '_' || innerChar == '~' || innerChar == '`' || innerChar == '=') {
                continue;
              }
              normBuffer.write(innerChar);
              map.add(j);
            }
            i = closeParen + 1;
            continue;
          }
        }
      }

      // 5. Delimiters: **, __, *, _, ~~, ``, ==
      if (c == '*' || c == '_' || c == '~' || c == '`' || c == '=') {
        i++;
        continue;
      }

      // 6. Normal character
      normBuffer.write(c);
      map.add(i);
      i++;
    }

    final normalizedStr = normBuffer.toString();
    return NormalizedSearchText(
      normalizedText: normalizedStr,
      sourceText: markdown,
      normalizedToSourceMap: map,
    );
  }

  /// Extracts a context-aware snippet around focusOffset and computes relative highlight spans.
  static SnippetResult extractSnippet({
    required String text,
    required int focusOffset,
    required int focusLength,
    required List<TokenSpanDto> normalizedSpans,
    int contextRadius = 45,
  }) {
    if (text.trim().isEmpty) return SnippetResult.empty;

    final textLen = text.length;
    var start = (focusOffset - contextRadius).clamp(0, textLen);
    var end = (focusOffset + focusLength + contextRadius).clamp(0, textLen);

    // Expand boundaries to nearest space if possible to avoid word slicing
    if (start > 0) {
      final spaceIdx = text.indexOf(' ', start);
      if (spaceIdx != -1 && spaceIdx < focusOffset) {
        start = spaceIdx + 1;
      }
    }
    if (end < textLen) {
      final spaceIdx = text.lastIndexOf(' ', end);
      if (spaceIdx != -1 && spaceIdx > (focusOffset + focusLength)) {
        end = spaceIdx;
      }
    }

    final rawSlice = text.substring(start, end).trim();
    if (rawSlice.isEmpty) return SnippetResult.empty;

    final prefix = start > 0 ? '… ' : '';
    final suffix = end < textLen ? ' …' : '';
    final formattedSnippet = '$prefix$rawSlice$suffix';

    final prefixOffset = prefix.length;
    final snippetSpans = <TokenSpanDto>[];

    for (final span in normalizedSpans) {
      if (span.end <= start || span.start >= end) continue;

      final relStart = (max(span.start, start) - start + prefixOffset).clamp(0, formattedSnippet.length);
      final relEnd = (min(span.end, end) - start + prefixOffset).clamp(0, formattedSnippet.length);

      if (relEnd > relStart) {
        snippetSpans.add(TokenSpanDto(
          start: relStart,
          end: relEnd,
          isExact: span.isExact,
        ));
      }
    }

    return SnippetResult(
      snippet: formattedSnippet,
      highlightSpans: snippetSpans,
    );
  }
}
