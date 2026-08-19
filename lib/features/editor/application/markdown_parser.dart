import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/markdown_styles.dart';

/// High-performance Markdown parser that builds a styled [TextSpan] tree
/// without modifying or dropping source characters.
abstract final class MarkdownParser {
  /// Builds a [TextSpan] tree representing [text] styled with [styles].
  ///
  /// If [composingRange] is valid and active, underline decoration is applied
  /// to the composing substring for seamless Android IME compatibility.
  static TextSpan buildTextSpan({
    required String text,
    required MarkdownStyles styles,
    TextRange? composingRange,
  }) {
    if (text.isEmpty) {
      return const TextSpan(text: '');
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
      else if (RegExp(r'^(\s*)(```|~~~)(.*)$').hasMatch(lineText)) {
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
      else if (RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$').hasMatch(lineText)) {
        rawSpans.add(_RawSpan(
          start: lineStart,
          end: lineStart + lineText.length,
          text: lineText,
          style: styles.horizontalRule,
        ));
      }
      // 4. Headings (# to ######)
      else if (RegExp(r'^(\s*)(#{1,6})(?:([ \t])(.*)|$)').hasMatch(lineText)) {
        final headingMatch =
            RegExp(r'^(\s*)(#{1,6})(?:([ \t])(.*)|$)').firstMatch(lineText)!;
        final indent = headingMatch.group(1) ?? '';
        final hashes = headingMatch.group(2) ?? '#';

        final level = hashes.length.clamp(1, 6);
        final headingStyle = styles.getHeadingStyle(level);

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

        // Heading marker (e.g. "##") - inherits heading font metrics to prevent baseline shifts
        final markerStyle = headingStyle.copyWith(
          color: styles.headingMarker.color,
          fontWeight: styles.headingMarker.fontWeight,
        );
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + hashes.length,
          text: hashes,
          style: markerStyle,
        ));
        currentOffset += hashes.length;

        final remainder = lineText.substring(indent.length + hashes.length);
        if (remainder.isNotEmpty) {
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
      else if (RegExp(r'^(\s*)(>{1,3})(?:([ \t]?)(.*)|$)').hasMatch(lineText)) {
        final quoteMatch =
            RegExp(r'^(\s*)(>{1,3})(?:([ \t]?)(.*)|$)').firstMatch(lineText)!;
        final indent = quoteMatch.group(1) ?? '';
        final marker = quoteMatch.group(2) ?? '>';
        final space = quoteMatch.group(3) ?? '';
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
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + marker.length,
          text: marker,
          style: markerStyle,
        ));
        currentOffset += marker.length;

        if (space.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + space.length,
            text: space,
            style: styles.blockquote,
          ));
          currentOffset += space.length;
        }

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
      else if (RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:\s+(.*)|$)').hasMatch(lineText)) {
        final checkMatch =
            RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:\s+(.*)|$)').firstMatch(lineText)!;
        final indent = checkMatch.group(1) ?? '';
        final prefix = checkMatch.group(2) ?? '- [';
        final stateChar = checkMatch.group(3) ?? ' ';
        final closeBracket = checkMatch.group(4) ?? ']';
        final content = checkMatch.group(5) ?? '';
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

        final markerText = '$prefix$stateChar$closeBracket';
        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + markerText.length,
          text: markerText,
          style: isChecked ? styles.checklistMarkerChecked : styles.checklistMarker,
        ));
        currentOffset += markerText.length;

        if (content.isNotEmpty) {
          final spaceIndex = lineText.substring(indent.length + markerText.length).indexOf(content);
          final spaceStr = spaceIndex > 0
              ? lineText.substring(indent.length + markerText.length, indent.length + markerText.length + spaceIndex)
              : ' ';
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + spaceStr.length,
            text: spaceStr,
            style: styles.body,
          ));
          currentOffset += spaceStr.length;

          _parseInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: isChecked ? styles.taskTextCompleted : styles.body,
            styles: styles,
            spans: rawSpans,
          );
        }
      }
      // 7. Unordered Lists (- , * , + )
      else if (RegExp(r'^(\s*)([-*+])(\s+)(.*)$').hasMatch(lineText)) {
        final listMatch =
            RegExp(r'^(\s*)([-*+])(\s+)(.*)$').firstMatch(lineText)!;
        final indent = listMatch.group(1) ?? '';
        final marker = listMatch.group(2) ?? '-';
        final space = listMatch.group(3) ?? ' ';
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

        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + marker.length,
          text: marker,
          style: styles.listMarker,
        ));
        currentOffset += marker.length;

        if (space.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + space.length,
            text: space,
            style: styles.body,
          ));
          currentOffset += space.length;
        }

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
      // 7. Ordered Lists (1. , 2. , 1) )
      else if (RegExp(r'^(\s*)(\d+[\.\)])(\s+)(.*)$').hasMatch(lineText)) {
        final listMatch =
            RegExp(r'^(\s*)(\d+[\.\)])(\s+)(.*)$').firstMatch(lineText)!;
        final indent = listMatch.group(1) ?? '';
        final marker = listMatch.group(2) ?? '1.';
        final space = listMatch.group(3) ?? ' ';
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

        rawSpans.add(_RawSpan(
          start: currentOffset,
          end: currentOffset + marker.length,
          text: marker,
          style: styles.listMarker,
        ));
        currentOffset += marker.length;

        if (space.isNotEmpty) {
          rawSpans.add(_RawSpan(
            start: currentOffset,
            end: currentOffset + space.length,
            text: space,
            style: styles.body,
          ));
          currentOffset += space.length;
        }

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
      // 8. Normal Body line
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

    // Convert raw spans to TextSpan list, applying composing underline if active
    final textSpans = <TextSpan>[];
    final isComposingValid = composingRange != null &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.start >= 0 &&
        composingRange.end <= text.length;

    for (final raw in mergedSpans) {
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
            style: styles.syntaxMarker,
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

      // Links: [title](url)
      if (char == '[') {
        final linkMatch =
            RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)').matchAsPrefix(text, i);
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
            style: styles.syntaxMarker,
          ));

          // Link Title with link styling and nested inline parsing
          _parseInlineSegments(
            text: title,
            baseOffset: baseOffset + openBracketEnd,
            baseStyle: baseStyle.merge(styles.link),
            styles: styles,
            spans: spans,
          );

          // "]("
          spans.add(_RawSpan(
            start: baseOffset + titleEnd,
            end: baseOffset + closeBracketParenEnd,
            text: '](',
            style: styles.syntaxMarker,
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
            style: styles.syntaxMarker,
          ));

          i = matchEnd;
          plainStart = i;
          continue;
        }
      }

      // Bare URLs: https://... or http://...
      if (text.startsWith('http://', i) || text.startsWith('https://', i)) {
        final urlMatch = RegExp(r'https?://[^\s<]+').matchAsPrefix(text, i);
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
        final tagMatch =
            RegExp(r'#([a-zA-Z0-9_\-\/]+)').matchAsPrefix(text, i);
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
              style: styles.syntaxMarker,
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
                style: styles.syntaxMarker,
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
                style: styles.syntaxMarker,
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
