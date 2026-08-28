import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/markdown_styles.dart';

/// High-performance Markdown parser that builds a styled [TextSpan] tree
/// without modifying or dropping source characters.
abstract final class MarkdownParser {
  /// Maximum document character count for full recursive inline Markdown styling.
  /// When text exceeds this threshold (e.g. 100k-5M words / 1-5MB text files),
  /// high-performance plain-span rendering is used to maintain 60/120 FPS.
  static const int defaultMaxStyledCharacters = 60000;

  // Pre-compiled block-level regular expressions
  static final _codeFenceRegex = RegExp(r'^(\s*)(```|~~~)(.*)$');
  static final _horizontalRuleRegex = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');
  static final _blockquoteCheckRegex = RegExp(r'^(\s*)(>{1,3})(?:([ \t]?)(.*)|$)');
  static final _blockquoteParseRegex = RegExp(r'^(\s*)(>{1,3})([ \t]?)(.*)$');
  static final _checklistCheckRegex = RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:([ \t]+.*)|$)');
  static final _checklistParseRegex = RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])([ \t]*)(.*)$');
  static final _unorderedListCheckRegex = RegExp(r'^(\s*)([-*+])(?:([ \t]+.*)|$)');
  static final _unorderedListParseRegex = RegExp(r'^(\s*)([-*+])([ \t]*)(.*)$');
  static final _orderedListCheckRegex = RegExp(r'^(\s*)(\d+[\.\)])(?:([ \t]+.*)|$)');
  static final _orderedListParseRegex = RegExp(r'^(\s*)(\d+[\.\)])([ \t]*)(.*)$');

  // Pre-compiled inline regular expressions
  static final _imageRegex = RegExp(r'!\[([^\]\n]*)\]\(([^)\n]*)\)');
  static final _linkRegex = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)');
  static final _urlRegex = RegExp(r'https?://[^\s<]+');
  static final _tagRegex = RegExp(r'#([a-zA-Z0-9_\-\/]+)');

  /// Builds a [TextSpan] tree representing [text] styled with [styles].
  ///
  /// If [composingRange] is valid and active, underline decoration is applied
  /// to the composing substring for seamless Android IME compatibility.
  static TextSpan buildTextSpan({
    required String text,
    required MarkdownStyles styles,
    TextRange? composingRange,
    String? searchQuery,
    TextRange? activeSearchRange,
    int maxStyledCharacters = defaultMaxStyledCharacters,
  }) {
    if (text.isEmpty) {
      return const TextSpan(text: '');
    }

    // High-performance plain span fast path for massive documents (1-5MB / 100k-5M words)
    if (text.length > maxStyledCharacters) {
      return _buildLargeDocumentTextSpan(
        text: text,
        styles: styles,
        composingRange: composingRange,
        searchQuery: searchQuery,
        activeSearchRange: activeSearchRange,
      );
    }

    final rawSpans = <_RawSpan>[];
    final lines = _splitLinesWithOffsets(text);

    var inFrontmatter = false;
    var inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final lineInfo = lines[i];
      final lineText = lineInfo.text;
      final lineStart = lineInfo.start;

      // 1. YAML Frontmatter check (only starts at document index 0)
      if (i == 0 && lineText.trim() == '---') {
        inFrontmatter = true;
        rawSpans.add(_RawSpan(
          start: lineStart,
          end: lineStart + lineText.length,
          text: lineText,
          style: styles.frontmatterDelimiter,
        ));
      } else if (inFrontmatter) {
        if (lineText.trim() == '---') {
          inFrontmatter = false;
          rawSpans.add(_RawSpan(
            start: lineStart,
            end: lineStart + lineText.length,
            text: lineText,
            style: styles.frontmatterDelimiter,
          ));
        } else {
          rawSpans.add(_RawSpan(
            start: lineStart,
            end: lineStart + lineText.length,
            text: lineText,
            style: styles.frontmatter,
          ));
        }
      }
      // 2. Fenced Code Blocks (``` or ~~~)
      else if (_codeFenceRegex.hasMatch(lineText)) {
        if (!inCodeBlock) {
          inCodeBlock = true;
        } else {
          inCodeBlock = false;
        }
        rawSpans.add(_RawSpan(
          start: lineStart,
          end: lineStart + lineText.length,
          text: lineText,
          style: styles.codeBlockFence,
        ));
      } else if (inCodeBlock) {
        rawSpans.add(_RawSpan(
          start: lineStart,
          end: lineStart + lineText.length,
          text: lineText,
          style: styles.codeBlock,
        ));
      }
      // 3. Horizontal Rules (---, ***, ___)
      else if (_horizontalRuleRegex.hasMatch(lineText)) {
        rawSpans.add(_RawSpan(
          start: lineStart,
          end: lineStart + lineText.length,
          text: lineText,
          style: styles.horizontalRule,
        ));
      }
      // 4. Headings (# to ######)
      else if (_tryParseHeading(lineText) case final headingInfo?) {
        final indentLen = headingInfo.indentLength;
        final hashCount = headingInfo.hashCount;
        final sepLen = headingInfo.separatorLength;
        final level = hashCount;
        final headingStyle = styles.getHeadingStyle(level);

        var currentOffset = lineStart;
        if (indentLen > 0) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + indentLen,
            text: lineText.substring(0, indentLen),
            style: styles.body,
          ));
          currentOffset += indentLen;
        }

        // Heading marker (e.g. "## ") - inherits exact heading font metrics to prevent baseline and font-instance shifts
        final markerStyle = headingStyle.copyWith(
          color: styles.headingMarker.color,
        );
        final totalMarkerLen = hashCount + sepLen;
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + totalMarkerLen,
          text: lineText.substring(indentLen, indentLen + totalMarkerLen),
          style: markerStyle,
        ));
        currentOffset += totalMarkerLen;

        final remainderStart = indentLen + totalMarkerLen;
        if (remainderStart < lineText.length) {
          final remainder = lineText.substring(remainderStart);
          _parseInlineSegments(
            text: remainder,
            baseOffset: currentOffset,
            baseStyle: headingStyle,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 5. Blockquotes (> or >>)
      else if (_blockquoteCheckRegex.hasMatch(lineText)) {
        final quoteMatch = _blockquoteParseRegex.firstMatch(lineText)!;
        final indent = quoteMatch.group(1) ?? '';
        final marker = quoteMatch.group(2) ?? '>';
        final sep = quoteMatch.group(3) ?? '';
        final content = quoteMatch.group(4) ?? '';

        var currentOffset = lineStart;
        if (indent.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + indent.length,
            text: indent,
            style: styles.body,
          ));
          currentOffset += indent.length;
        }

        final markerStyle = styles.blockquote.copyWith(
          color: styles.blockquoteMarker.color,
          fontWeight: styles.blockquoteMarker.fontWeight,
        );
        final markerWithSep = '$marker$sep';
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + markerWithSep.length,
          text: markerWithSep,
          style: markerStyle,
        ));
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _parseInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.blockquote,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 6. Checklists (- [ ] , - [x] , * [ ] , + [ ] )
      else if (_checklistCheckRegex.hasMatch(lineText)) {
        final checkMatch = _checklistParseRegex.firstMatch(lineText)!;
        final indent = checkMatch.group(1) ?? '';
        final prefix = checkMatch.group(2) ?? '- [';
        final stateChar = checkMatch.group(3) ?? ' ';
        final closeBracket = checkMatch.group(4) ?? ']';
        final sep = checkMatch.group(5) ?? '';
        final content = checkMatch.group(6) ?? '';
        final isChecked = (stateChar == 'x' || stateChar == 'X');

        var currentOffset = lineStart;
        if (indent.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + indent.length,
            text: indent,
            style: styles.body,
          ));
          currentOffset += indent.length;
        }

        final markerBaseStyle = isChecked ? styles.taskTextCompleted : styles.body;
        final markerColor = isChecked
            ? styles.checklistMarkerChecked.color
            : styles.checklistMarker.color;
        final markerFontWeight = isChecked
            ? (styles.checklistMarkerChecked.fontWeight ?? FontWeight.w600)
            : (styles.checklistMarker.fontWeight ?? FontWeight.w600);

        final markerText = '$prefix$stateChar$closeBracket$sep';
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + markerText.length,
          text: markerText,
          style: markerBaseStyle.copyWith(
            color: markerColor,
            fontWeight: markerFontWeight,
          ),
        ));
        currentOffset += markerText.length;

        if (content.isNotEmpty) {
          _parseInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: markerBaseStyle,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 7. Unordered Lists (- , * , + )
      else if (_unorderedListCheckRegex.hasMatch(lineText)) {
        final listMatch = _unorderedListParseRegex.firstMatch(lineText)!;
        final indent = listMatch.group(1) ?? '';
        final marker = listMatch.group(2) ?? '-';
        final sep = listMatch.group(3) ?? '';
        final content = listMatch.group(4) ?? '';

        var currentOffset = lineStart;
        if (indent.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + indent.length,
            text: indent,
            style: styles.body,
          ));
          currentOffset += indent.length;
        }

        final markerStyle = styles.body.copyWith(
          color: styles.listMarker.color,
          fontWeight: styles.listMarker.fontWeight ?? FontWeight.w600,
        );
        final markerWithSep = '$marker$sep';
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + markerWithSep.length,
          text: markerWithSep,
          style: markerStyle,
        ));
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _parseInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.body,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 8. Ordered Lists (1. , 2. , 1) )
      else if (_orderedListCheckRegex.hasMatch(lineText)) {
        final listMatch = _orderedListParseRegex.firstMatch(lineText)!;
        final indent = listMatch.group(1) ?? '';
        final marker = listMatch.group(2) ?? '1.';
        final sep = listMatch.group(3) ?? '';
        final content = listMatch.group(4) ?? '';

        var currentOffset = lineStart;
        if (indent.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + indent.length,
            text: indent,
            style: styles.body,
          ));
          currentOffset += indent.length;
        }

        final markerStyle = styles.body.copyWith(
          color: styles.listMarker.color,
          fontWeight: styles.listMarker.fontWeight ?? FontWeight.w600,
        );
        final markerWithSep = '$marker$sep';
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + markerWithSep.length,
          text: markerWithSep,
          style: markerStyle,
        ));
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _parseInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.body,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 9. Normal Body line
      else {
        if (lineText.isNotEmpty) {
          _parseInlineSegments(
            text: lineText,
            baseOffset: lineStart,
            baseStyle: styles.body,
            styles: styles,
            spans: rawSpans,
          );
        }
      }

      // Append newline if not at end of document
      if (i < lines.length - 1) {
        final newlineOffset = lineStart + lineText.length;
        rawSpans.add(_RawSpan(
          start: newlineOffset,
          end: newlineOffset + 1,
          text: '\n',
          style: styles.body,
        ));
      }
    }

    // Merge adjacent raw spans with identical styles to avoid fragmented text spans
    final mergedSpans = <_RawSpan>[];
    for (final raw in rawSpans) {
      if (raw.text.isEmpty) continue;
      if (mergedSpans.isNotEmpty &&
          mergedSpans.last.end == raw.start &&
          mergedSpans.last.style == raw.style) {
        final prev = mergedSpans.removeLast();
        mergedSpans.add(_RawSpan(
          start: prev.start,
          end: raw.end,
          text: prev.text + raw.text,
          style: prev.style,
        ));
      } else {
        mergedSpans.add(raw);
      }
    }

    // 1. Process search matches if searchQuery is provided
    final searchSpans = <_RawSpan>[];
    final hasSearch = searchQuery != null && searchQuery.isNotEmpty;

    if (!hasSearch) {
      searchSpans.addAll(mergedSpans);
    } else {
      final lowerText = text.toLowerCase();
      final lowerQuery = searchQuery.toLowerCase();
      final searchMatches = <TextRange>[];
      var searchIdx = 0;
      while (searchIdx < lowerText.length) {
        final found = lowerText.indexOf(lowerQuery, searchIdx);
        if (found == -1) break;
        searchMatches.add(TextRange(start: found, end: found + searchQuery.length));
        searchIdx = found + searchQuery.length;
      }

      for (final raw in mergedSpans) {
        if (raw.text.isEmpty) continue;

        // Find matches that overlap this span
        final overlapping = searchMatches
            .where((m) => m.end > raw.start && m.start < raw.end)
            .toList();

        if (overlapping.isEmpty) {
          searchSpans.add(raw);
        } else {
          var currOffset = raw.start;
          for (final match in overlapping) {
            final matchStart = max(currOffset, match.start);
            final matchEnd = min(raw.end, match.end);

            // Plain segment before match
            if (matchStart > currOffset) {
              final beforeText = raw.text.substring(
                currOffset - raw.start,
                matchStart - raw.start,
              );
              searchSpans.add(_RawSpan(
                start: currOffset,
                end: matchStart,
                text: beforeText,
                style: raw.style,
              ));
            }

            // Matching segment
            if (matchEnd > matchStart) {
              final matchText = raw.text.substring(
                matchStart - raw.start,
                matchEnd - raw.start,
              );
              final isActive = activeSearchRange != null &&
                  activeSearchRange.start == match.start &&
                  activeSearchRange.end == match.end;

              final highlightStyle =
                  isActive ? styles.activeSearchHighlight : styles.searchHighlight;

              searchSpans.add(_RawSpan(
                start: matchStart,
                end: matchEnd,
                text: matchText,
                style: raw.style.merge(highlightStyle),
              ));
              currOffset = matchEnd;
            }
          }

          // Plain segment after all matches
          if (currOffset < raw.end) {
            final afterText = raw.text.substring(currOffset - raw.start);
            searchSpans.add(_RawSpan(
              start: currOffset,
              end: raw.end,
              text: afterText,
              style: raw.style,
            ));
          }
        }
      }
    }

    final textSpans = <TextSpan>[];
    final isComposingValid = composingRange != null &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.start >= 0 &&
        composingRange.end <= text.length;

    for (final raw in searchSpans) {
      if (raw.text.isEmpty) continue;

      if (!isComposingValid ||
          raw.end <= composingRange.start ||
          raw.start >= composingRange.end) {
        textSpans.add(TextSpan(text: raw.text, style: raw.style));
      } else {
        // Overlaps composing range: split into segments
        final spanStart = raw.start;
        final spanEnd = raw.end;
        final compStart = composingRange.start;
        final compEnd = composingRange.end;

        // 1. Before composing
        if (spanStart < compStart) {
          final beforeText =
              raw.text.substring(0, compStart - spanStart);
          textSpans.add(TextSpan(text: beforeText, style: raw.style));
        }

        // 2. Composing range part
        final compInSpanStart = max(spanStart, compStart) - spanStart;
        final compInSpanEnd = min(spanEnd, compEnd) - spanStart;
        if (compInSpanEnd > compInSpanStart) {
          final compText =
              raw.text.substring(compInSpanStart, compInSpanEnd);
          textSpans.add(TextSpan(
            text: compText,
            style: raw.style.copyWith(
              decoration: TextDecoration.underline,
            ),
          ));
        }

        // 3. After composing
        if (spanEnd > compEnd) {
          final afterText =
              raw.text.substring(compEnd - spanStart);
          textSpans.add(TextSpan(text: afterText, style: raw.style));
        }
      }
    }

    return TextSpan(style: styles.body, children: textSpans);
  }

  /// High-performance plain-span builder for large documents (1-5MB / 100k-5M words).
  /// Renders plain body style with search highlights and IME composing decorations
  /// without full AST node tree generation, maintaining locked 60/120 FPS.
  static TextSpan _buildLargeDocumentTextSpan({
    required String text,
    required MarkdownStyles styles,
    TextRange? composingRange,
    String? searchQuery,
    TextRange? activeSearchRange,
  }) {
    final hasSearch = searchQuery != null && searchQuery.isNotEmpty;
    final isComposingValid = composingRange != null &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.start >= 0 &&
        composingRange.end <= text.length;

    if (!hasSearch && !isComposingValid) {
      return TextSpan(text: text, style: styles.body);
    }

    // Collect search matches (bounded up to 1000 matches to prevent UI lag)
    final searchMatches = <TextRange>[];
    if (hasSearch) {
      final lowerText = text.toLowerCase();
      final lowerQuery = searchQuery.toLowerCase();
      var searchIdx = 0;
      const maxMatches = 1000;
      while (searchIdx < lowerText.length && searchMatches.length < maxMatches) {
        final found = lowerText.indexOf(lowerQuery, searchIdx);
        if (found == -1) break;
        searchMatches.add(TextRange(start: found, end: found + searchQuery.length));
        searchIdx = found + searchQuery.length;
      }
    }

    // Overlay search highlights and composing range
    final spans = <TextSpan>[];
    var currentOffset = 0;

    void addSegment(int start, int end, {TextStyle? styleOverride}) {
      if (end <= start) return;
      final segText = text.substring(start, end);
      final baseStyle = styleOverride ?? styles.body;

      if (!isComposingValid ||
          end <= composingRange.start ||
          start >= composingRange.end) {
        spans.add(TextSpan(text: segText, style: baseStyle));
      } else {
        final compStart = composingRange.start;
        final compEnd = composingRange.end;

        if (start < compStart) {
          spans.add(TextSpan(
            text: text.substring(start, compStart),
            style: baseStyle,
          ));
        }

        final inCompStart = max(start, compStart);
        final inCompEnd = min(end, compEnd);
        if (inCompEnd > inCompStart) {
          spans.add(TextSpan(
            text: text.substring(inCompStart, inCompEnd),
            style: baseStyle.copyWith(decoration: TextDecoration.underline),
          ));
        }

        if (end > compEnd) {
          spans.add(TextSpan(
            text: text.substring(compEnd, end),
            style: baseStyle,
          ));
        }
      }
    }

    for (final match in searchMatches) {
      if (match.start > currentOffset) {
        addSegment(currentOffset, match.start);
      }

      final isActive = activeSearchRange != null &&
          activeSearchRange.start == match.start &&
          activeSearchRange.end == match.end;
      final highlightStyle =
          isActive ? styles.activeSearchHighlight : styles.searchHighlight;

      addSegment(
        match.start,
        match.end,
        styleOverride: styles.body.merge(highlightStyle),
      );
      currentOffset = match.end;
    }

    if (currentOffset < text.length) {
      addSegment(currentOffset, text.length);
    }

    return TextSpan(style: styles.body, children: spans);
  }

  /// Scans inline tokens and appends styled [_RawSpan]s.
  static void _parseInlineSegments({
    required String text,
    required int baseOffset,
    required TextStyle baseStyle,
    required MarkdownStyles styles,
    required List<_RawSpan> spans,
  }) {
    var i = 0;
    final len = text.length;
    var plainStart = 0;
    final syntaxMarkerStyle =
        baseStyle.copyWith(color: styles.syntaxMarker.color);

    void flushPlain(int end) {
      if (end > plainStart) {
        spans.add(_RawSpan(
          start: baseOffset + plainStart,
          end: baseOffset + end,
          text: text.substring(plainStart, end),
          style: baseStyle,
        ));
      }
      plainStart = end;
    }

    while (i < len) {
      final char = text[i];

      // Inline Escape: \c
      if (char == '\\' && i + 1 < len) {
        final nextChar = text[i + 1];
        if (_isEscapableChar(nextChar)) {
          flushPlain(i);
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + i + 1,
            text: '\\',
            style: syntaxMarkerStyle,
          ));
          spans.add(_RawSpan(
            start: baseOffset + i + 1,
            end: baseOffset + i + 2,
            text: nextChar,
            style: baseStyle,
          ));
          i += 2;
          plainStart = i;
          continue;
        }
      }

      // Inline Code: `code` or ``code``
      if (char == '`') {
        final isDouble = (i + 1 < len && text[i + 1] == '`');
        final delimiter = isDouble ? '``' : '`';
        final delimLen = delimiter.length;
        final closeIndex = text.indexOf(delimiter, i + delimLen);

        if (closeIndex != -1) {
          flushPlain(i);

          // Opening backtick
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + i + delimLen,
            text: delimiter,
            style: styles.inlineCodeMarker,
          ));

          // Code text
          spans.add(_RawSpan(
            start: baseOffset + i + delimLen,
            end: baseOffset + closeIndex,
            text: text.substring(i + delimLen, closeIndex),
            style: styles.inlineCode,
          ));

          // Closing backtick
          spans.add(_RawSpan(
            start: baseOffset + closeIndex,
            end: baseOffset + closeIndex + delimLen,
            text: delimiter,
            style: styles.inlineCodeMarker,
          ));

          i = closeIndex + delimLen;
          plainStart = i;
          continue;
        }
      }

      // Images: ![alt](url)
      if (char == '!' && i + 1 < len && text[i + 1] == '[') {
        final imageMatch = _imageRegex.matchAsPrefix(text, i);
        if (imageMatch != null) {
          final fullMatch = imageMatch.group(0)!;
          final alt = imageMatch.group(1)!;
          final url = imageMatch.group(2)!;

          final openParenStart = i + 2 + alt.length;
          final urlStart = openParenStart + 2;
          final urlEnd = urlStart + url.length;
          final matchEnd = i + fullMatch.length;

          flushPlain(i);

          // "!["
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + i + 2,
            text: '![',
            style: syntaxMarkerStyle,
          ));

          // Alt text
          if (alt.isNotEmpty) {
            spans.add(_RawSpan(
              start: baseOffset + i + 2,
              end: baseOffset + openParenStart,
              text: alt,
              style: styles.body.copyWith(
                color: styles.body.color?.withValues(alpha: 0.85),
                fontStyle: FontStyle.italic,
              ),
            ));
          }

          // "]("
          spans.add(_RawSpan(
            start: baseOffset + openParenStart,
            end: baseOffset + urlStart,
            text: '](',
            style: syntaxMarkerStyle,
          ));

          // URL / Asset URI
          if (url.isNotEmpty) {
            spans.add(_RawSpan(
              start: baseOffset + urlStart,
              end: baseOffset + urlEnd,
              text: url,
              style: styles.linkUrl,
            ));
          }

          // ")"
          spans.add(_RawSpan(
            start: baseOffset + urlEnd,
            end: baseOffset + matchEnd,
            text: ')',
            style: syntaxMarkerStyle,
          ));

          i = matchEnd;
          plainStart = i;
          continue;
        }
      }

      // Links: [title](url)
      if (char == '[') {
        final linkMatch = _linkRegex.matchAsPrefix(text, i);
        if (linkMatch != null) {
          final fullMatch = linkMatch.group(0)!;
          final title = linkMatch.group(1)!;
          final url = linkMatch.group(2)!;

          final openBracketEnd = i + 1;
          final titleEnd = openBracketEnd + title.length;
          final closeBracketParenEnd = titleEnd + 2; // "]("
          final urlEnd = closeBracketParenEnd + url.length;
          final matchEnd = i + fullMatch.length;

          flushPlain(i);

          // "["
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + openBracketEnd,
            text: '[',
            style: syntaxMarkerStyle,
          ));

          final isDocumentLink = url.startsWith('qp://document/');
          final linkStyle = isDocumentLink
              ? baseStyle.merge(styles.link.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ))
              : baseStyle.merge(styles.link);

          // Link Title with link styling and nested inline parsing
          _parseInlineSegments(
            text: title,
            baseOffset: baseOffset + openBracketEnd,
            baseStyle: linkStyle,
            styles: styles,
            spans: spans,
          );

          // "]("
          spans.add(_RawSpan(
            start: baseOffset + titleEnd,
            end: baseOffset + closeBracketParenEnd,
            text: '](',
            style: syntaxMarkerStyle,
          ));

          // URL
          if (url.isNotEmpty) {
            spans.add(_RawSpan(
              start: baseOffset + closeBracketParenEnd,
              end: baseOffset + urlEnd,
              text: url,
              style: styles.linkUrl,
            ));
          }

          // ")"
          spans.add(_RawSpan(
            start: baseOffset + urlEnd,
            end: baseOffset + matchEnd,
            text: ')',
            style: syntaxMarkerStyle,
          ));

          i = matchEnd;
          plainStart = i;
          continue;
        }
      }

      // Bare URLs: https://... or http://...
      if (text.startsWith('http://', i) || text.startsWith('https://', i)) {
        final urlMatch = _urlRegex.matchAsPrefix(text, i);
        if (urlMatch != null) {
          final url = urlMatch.group(0)!;
          flushPlain(i);
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + i + url.length,
            text: url,
            style: baseStyle.merge(styles.link),
          ));
          i += url.length;
          plainStart = i;
          continue;
        }
      }

      // Tags: #tag (must be preceded by start of line or whitespace)
      if (char == '#' &&
          (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\t')) {
        final tagMatch = _tagRegex.matchAsPrefix(text, i);
        if (tagMatch != null) {
          final fullTag = tagMatch.group(0)!;
          flushPlain(i);
          spans.add(_RawSpan(
            start: baseOffset + i,
            end: baseOffset + i + fullTag.length,
            text: fullTag,
            style: styles.tag,
          ));
          i += fullTag.length;
          plainStart = i;
          continue;
        }
      }

      // Bold + Italic: ***text*** or ___text___
      if (text.startsWith('***', i) || text.startsWith('___', i)) {
        final delimiter = text.substring(i, i + 3);
        final closeIndex = _findClosingDelimiter(text, delimiter, i + 3);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 3, closeIndex);
          if (innerContent.isNotEmpty &&
              !innerContent.startsWith(' ') &&
              !innerContent.endsWith(' ')) {
            flushPlain(i);

            spans.add(_RawSpan(
              start: baseOffset + i,
              end: baseOffset + i + 3,
              text: delimiter,
              style: syntaxMarkerStyle,
            ));

            _parseInlineSegments(
              text: innerContent,
              baseOffset: baseOffset + i + 3,
              baseStyle: baseStyle.merge(styles.boldItalic),
              styles: styles,
              spans: spans,
            );

            spans.add(_RawSpan(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 3,
              text: delimiter,
              style: syntaxMarkerStyle,
            ));

            i = closeIndex + 3;
            plainStart = i;
            continue;
          }
        }
      }

      // Bold: **text** or __text__
      if (text.startsWith('**', i) || text.startsWith('__', i)) {
        final delimiter = text.substring(i, i + 2);
        final closeIndex = _findClosingDelimiter(text, delimiter, i + 2);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 2, closeIndex);
          if (innerContent.isNotEmpty &&
              !innerContent.startsWith(' ') &&
              !innerContent.endsWith(' ')) {
            flushPlain(i);

            spans.add(_RawSpan(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              text: delimiter,
              style: syntaxMarkerStyle,
            ));

            _parseInlineSegments(
              text: innerContent,
              baseOffset: baseOffset + i + 2,
              baseStyle: baseStyle.merge(styles.bold),
              styles: styles,
              spans: spans,
            );

            spans.add(_RawSpan(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              text: delimiter,
              style: syntaxMarkerStyle,
            ));

            i = closeIndex + 2;
            plainStart = i;
            continue;
          }
        }
      }

      // Strikethrough: ~~text~~
      if (text.startsWith('~~', i)) {
        final closeIndex = _findClosingDelimiter(text, '~~', i + 2);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 2, closeIndex);
          if (innerContent.isNotEmpty &&
              !innerContent.startsWith(' ') &&
              !innerContent.endsWith(' ')) {
            flushPlain(i);

            spans.add(_RawSpan(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              text: '~~',
              style: syntaxMarkerStyle,
            ));

            _parseInlineSegments(
              text: innerContent,
              baseOffset: baseOffset + i + 2,
              baseStyle: baseStyle.merge(styles.strikethrough),
              styles: styles,
              spans: spans,
            );

            spans.add(_RawSpan(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              text: '~~',
              style: syntaxMarkerStyle,
            ));

            i = closeIndex + 2;
            plainStart = i;
            continue;
          }
        }
      }

      // Highlight: ==text==
      if (text.startsWith('==', i)) {
        final closeIndex = _findClosingDelimiter(text, '==', i + 2);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 2, closeIndex);
          if (innerContent.isNotEmpty &&
              !innerContent.startsWith(' ') &&
              !innerContent.endsWith(' ')) {
            flushPlain(i);

            spans.add(_RawSpan(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              text: '==',
              style: syntaxMarkerStyle,
            ));

            _parseInlineSegments(
              text: innerContent,
              baseOffset: baseOffset + i + 2,
              baseStyle: baseStyle.merge(styles.highlight),
              styles: styles,
              spans: spans,
            );

            spans.add(_RawSpan(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              text: '==',
              style: syntaxMarkerStyle,
            ));

            i = closeIndex + 2;
            plainStart = i;
            continue;
          }
        }
      }

      // Italic: *text* or _text_
      if (char == '*' || char == '_') {
        final delimiter = char;
        // If delimiter is '_', avoid triggering inside words (e.g. variable_name)
        final isWordFlanked =
            (char == '_' && i > 0 && _isAlphanumeric(text[i - 1]));
        if (!isWordFlanked) {
          final closeIndex = _findClosingDelimiter(text, delimiter, i + 1);
          if (closeIndex != -1) {
            final innerContent = text.substring(i + 1, closeIndex);
            if (innerContent.isNotEmpty &&
                !innerContent.startsWith(' ') &&
                !innerContent.endsWith(' ')) {
              flushPlain(i);

              spans.add(_RawSpan(
                start: baseOffset + i,
                end: baseOffset + i + 1,
                text: delimiter,
                style: syntaxMarkerStyle,
              ));

              _parseInlineSegments(
                text: innerContent,
                baseOffset: baseOffset + i + 1,
                baseStyle: baseStyle.merge(styles.italic),
                styles: styles,
                spans: spans,
              );

              spans.add(_RawSpan(
                start: baseOffset + closeIndex,
                end: baseOffset + closeIndex + 1,
                text: delimiter,
                style: syntaxMarkerStyle,
              ));

              i = closeIndex + 1;
              plainStart = i;
              continue;
            }
          }
        }
      }

      i++;
    }

    flushPlain(len);
  }

  static int _findClosingDelimiter(
      String text, String delimiter, int startIndex) {
    var searchIndex = startIndex;
    while (searchIndex < text.length) {
      final found = text.indexOf(delimiter, searchIndex);
      if (found == -1) return -1;
      // Ensure it is not escaped
      if (found > 0 && text[found - 1] == '\\') {
        searchIndex = found + delimiter.length;
        continue;
      }
      return found;
    }
    return -1;
  }

  static bool _isEscapableChar(String char) {
    return char == '*' ||
        char == '_' ||
        char == '`' ||
        char == '#' ||
        char == '~' ||
        char == '=' ||
        char == '[' ||
        char == ']' ||
        char == '(' ||
        char == ')' ||
        char == '+' ||
        char == '-' ||
        char == '.' ||
        char == '!' ||
        char == '>' ||
        char == '\\';
  }

  static bool _isAlphanumeric(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122); // a-z
  }

  static List<_LineSpan> _splitLinesWithOffsets(String text) {
    final result = <_LineSpan>[];
    var start = 0;
    while (start <= text.length) {
      final newline = text.indexOf('\n', start);
      if (newline == -1) {
        result.add(_LineSpan(
          start: start,
          end: text.length,
          text: text.substring(start),
        ));
        break;
      } else {
        result.add(_LineSpan(
          start: start,
          end: newline,
          text: text.substring(start, newline),
        ));
        start = newline + 1;
      }
    }
    return result;
  }

  static _HeadingLineInfo? _tryParseHeading(String lineText) {
    final len = lineText.length;
    var i = 0;
    while (i < len && (lineText[i] == ' ' || lineText[i] == '\t')) {
      i++;
    }
    final indentEnd = i;
    var hashCount = 0;
    while (i < len && lineText[i] == '#') {
      hashCount++;
      i++;
    }
    if (hashCount >= 1 &&
        hashCount <= 6 &&
        (i == len || lineText[i] == ' ' || lineText[i] == '\t')) {
      var sepEnd = i;
      while (sepEnd < len && (lineText[sepEnd] == ' ' || lineText[sepEnd] == '\t')) {
        sepEnd++;
      }
      return _HeadingLineInfo(
        indentLength: indentEnd,
        hashCount: hashCount,
        separatorLength: sepEnd - i,
      );
    }
    return null;
  }
}

class _HeadingLineInfo {
  final int indentLength;
  final int hashCount;
  final int separatorLength;

  const _HeadingLineInfo({
    required this.indentLength,
    required this.hashCount,
    required this.separatorLength,
  });
}

class _LineSpan {
  final int start;
  final int end;
  final String text;

  const _LineSpan({
    required this.start,
    required this.end,
    required this.text,
  });
}

class _RawSpan {
  final int start;
  final int end;
  final String text;
  final TextStyle style;

  const _RawSpan({
    required this.start,
    required this.end,
    required this.text,
    required this.style,
  });
}
