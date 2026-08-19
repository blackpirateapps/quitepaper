import '../domain/markdown_token.dart';

/// Lightweight, deterministic Markdown tokenizer designed specifically for the editor.
/// Produces semantic tokens without modifying or dropping source characters.
class MarkdownTokenizer {
  const MarkdownTokenizer();

  /// Tokenizes a full Markdown document [text] into a list of [MarkdownToken]s.
  List<MarkdownToken> tokenize(String text) {
    if (text.isEmpty) return const [];

    final tokens = <MarkdownToken>[];
    final lines = _splitLinesWithOffsets(text);

    var inFrontmatter = false;
    var inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      final lineInfo = lines[i];
      final lineText = lineInfo.text;
      final lineStart = lineInfo.start;
      final lineEnd = lineInfo.end;

      // 1. YAML Frontmatter check (only starts at document index 0)
      if (i == 0 && lineText.trim() == '---') {
        inFrontmatter = true;
        tokens.add(MarkdownToken(
          start: lineStart,
          end: lineEnd,
          type: MarkdownTokenType.frontmatterDelimiter,
          text: lineText,
        ));
        continue;
      }

      if (inFrontmatter) {
        if (lineText.trim() == '---') {
          inFrontmatter = false;
          tokens.add(MarkdownToken(
            start: lineStart,
            end: lineEnd,
            type: MarkdownTokenType.frontmatterDelimiter,
            text: lineText,
          ));
        } else {
          tokens.add(MarkdownToken(
            start: lineStart,
            end: lineEnd,
            type: MarkdownTokenType.frontmatter,
            text: lineText,
          ));
        }
        continue;
      }

      // 2. Fenced Code Blocks (``` or ~~~)
      final codeFenceMatch = RegExp(r'^(\s*)(```|~~~)(.*)$').firstMatch(lineText);
      if (codeFenceMatch != null) {
        if (!inCodeBlock) {
          inCodeBlock = true;
          tokens.add(MarkdownToken(
            start: lineStart,
            end: lineEnd,
            type: MarkdownTokenType.codeBlockFence,
            text: lineText,
          ));
          continue;
        } else {
          inCodeBlock = false;
          tokens.add(MarkdownToken(
            start: lineStart,
            end: lineEnd,
            type: MarkdownTokenType.codeBlockFence,
            text: lineText,
          ));
          continue;
        }
      }

      if (inCodeBlock) {
        tokens.add(MarkdownToken(
          start: lineStart,
          end: lineEnd,
          type: MarkdownTokenType.codeBlock,
          text: lineText,
        ));
        continue;
      }

      // 3. Horizontal Rules (---, ***, ___)
      if (RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$').hasMatch(lineText)) {
        tokens.add(MarkdownToken(
          start: lineStart,
          end: lineEnd,
          type: MarkdownTokenType.horizontalRule,
          text: lineText,
        ));
        continue;
      }

      // 4. Headings (# to ######)
      final headingMatch = RegExp(r'^(\s*)(#{1,6})(?:([ \t])(.*)|$)').firstMatch(lineText);
      if (headingMatch != null) {
        final indent = headingMatch.group(1) ?? '';
        final hashes = headingMatch.group(2) ?? '#';
        final space = headingMatch.group(3);
        final content = headingMatch.group(4);

        final level = hashes.length.clamp(1, 6);
        final markerType = MarkdownTokenType.headingMarker;
        final headingType = _headingTypeFromLevel(level);

        final markerStart = lineStart + indent.length;
        final markerEnd = markerStart + hashes.length;

        tokens.add(MarkdownToken(
          start: markerStart,
          end: markerEnd,
          type: markerType,
          text: hashes,
        ));

        if (content != null && content.isNotEmpty) {
          final contentStart = markerEnd + (space?.length ?? 1);
          final contentEnd = lineEnd;
          tokens.add(MarkdownToken(
            start: contentStart,
            end: contentEnd,
            type: headingType,
            text: content,
          ));
          _tokenizeInline(content, contentStart, tokens);
        }
        continue;
      }

      // 5. Blockquotes (> or >>)
      final quoteMatch = RegExp(r'^(\s*)(>{1,3})(?:([ \t]?)(.*)|$)').firstMatch(lineText);
      if (quoteMatch != null) {
        final indent = quoteMatch.group(1) ?? '';
        final marker = quoteMatch.group(2) ?? '>';
        final space = quoteMatch.group(3) ?? '';
        final content = quoteMatch.group(4) ?? '';

        final markerStart = lineStart + indent.length;
        final markerEnd = markerStart + marker.length;

        tokens.add(MarkdownToken(
          start: markerStart,
          end: markerEnd,
          type: MarkdownTokenType.blockquoteMarker,
          text: marker,
        ));

        if (content.isNotEmpty) {
          final contentStart = markerEnd + space.length;
          final contentEnd = lineEnd;
          tokens.add(MarkdownToken(
            start: contentStart,
            end: contentEnd,
            type: MarkdownTokenType.blockquote,
            text: content,
          ));
          _tokenizeInline(content, contentStart, tokens);
        }
        continue;
      }

      // 6. Checklists (- [ ] , - [x] , * [ ] , + [ ] )
      final checklistMatch = RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:\s+(.*)|$)').firstMatch(lineText);
      if (checklistMatch != null) {
        final indent = checklistMatch.group(1) ?? '';
        final prefix = checklistMatch.group(2) ?? '- [';
        final stateChar = checklistMatch.group(3) ?? ' ';
        final closeBracket = checklistMatch.group(4) ?? ']';
        final content = checklistMatch.group(5) ?? '';
        final isChecked = (stateChar == 'x' || stateChar == 'X');

        final markerStart = lineStart + indent.length;
        final markerText = '$prefix$stateChar$closeBracket';
        final markerEnd = markerStart + markerText.length;

        tokens.add(MarkdownToken(
          start: markerStart,
          end: markerEnd,
          type: isChecked
              ? MarkdownTokenType.checklistMarkerChecked
              : MarkdownTokenType.checklistMarkerUnchecked,
          text: markerText,
        ));

        if (content.isNotEmpty) {
          final spaceLength = lineText.substring(indent.length + markerText.length).indexOf(content);
          final contentStart = markerEnd + (spaceLength >= 0 ? spaceLength : 1);
          final contentEnd = lineEnd;
          tokens.add(MarkdownToken(
            start: contentStart,
            end: contentEnd,
            type: isChecked ? MarkdownTokenType.taskTextCompleted : MarkdownTokenType.taskText,
            text: content,
          ));
          _tokenizeInline(content, contentStart, tokens);
        }
        continue;
      }

      // 7. Unordered Lists (- , * , + )
      final unorderedMatch = RegExp(r'^(\s*)([-*+])(\s+)(.*)$').firstMatch(lineText);
      if (unorderedMatch != null) {
        final indent = unorderedMatch.group(1) ?? '';
        final marker = unorderedMatch.group(2) ?? '-';
        final space = unorderedMatch.group(3) ?? ' ';
        final content = unorderedMatch.group(4) ?? '';

        final markerStart = lineStart + indent.length;
        final markerEnd = markerStart + marker.length;

        tokens.add(MarkdownToken(
          start: markerStart,
          end: markerEnd,
          type: MarkdownTokenType.unorderedListMarker,
          text: marker,
        ));

        if (content.isNotEmpty) {
          final contentStart = markerEnd + space.length;
          final contentEnd = lineEnd;
          tokens.add(MarkdownToken(
            start: contentStart,
            end: contentEnd,
            type: MarkdownTokenType.unorderedList,
            text: content,
          ));
          _tokenizeInline(content, contentStart, tokens);
        }
        continue;
      }

      // 8. Ordered Lists (1. , 2. , 1) )
      final orderedMatch = RegExp(r'^(\s*)(\d+[\.\)])(\s+)(.*)$').firstMatch(lineText);
      if (orderedMatch != null) {
        final indent = orderedMatch.group(1) ?? '';
        final marker = orderedMatch.group(2) ?? '1.';
        final space = orderedMatch.group(3) ?? ' ';
        final content = orderedMatch.group(4) ?? '';

        final markerStart = lineStart + indent.length;
        final markerEnd = markerStart + marker.length;

        tokens.add(MarkdownToken(
          start: markerStart,
          end: markerEnd,
          type: MarkdownTokenType.orderedListMarker,
          text: marker,
        ));

        if (content.isNotEmpty) {
          final contentStart = markerEnd + space.length;
          final contentEnd = lineEnd;
          tokens.add(MarkdownToken(
            start: contentStart,
            end: contentEnd,
            type: MarkdownTokenType.orderedList,
            text: content,
          ));
          _tokenizeInline(content, contentStart, tokens);
        }
        continue;
      }

      // 8. Normal Body line
      if (lineText.isNotEmpty) {
        _tokenizeInline(lineText, lineStart, tokens);
      }
    }

    return tokens;
  }

  /// Scans inline tokens (bold, italic, code, links, tags, etc.) within a line.
  void _tokenizeInline(String text, int baseOffset, List<MarkdownToken> tokens) {
    var i = 0;
    final len = text.length;

    while (i < len) {
      final char = text[i];

      // Inline Escape: \c
      if (char == '\\' && i + 1 < len) {
        final nextChar = text[i + 1];
        if (_isEscapableChar(nextChar)) {
          tokens.add(MarkdownToken(
            start: baseOffset + i,
            end: baseOffset + i + 1,
            type: MarkdownTokenType.syntaxMarker,
            text: '\\',
          ));
          i += 2;
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
          // Opening backtick(s)
          tokens.add(MarkdownToken(
            start: baseOffset + i,
            end: baseOffset + i + delimLen,
            type: MarkdownTokenType.inlineCodeMarker,
            text: delimiter,
          ));

          // Code text
          tokens.add(MarkdownToken(
            start: baseOffset + i + delimLen,
            end: baseOffset + closeIndex,
            type: MarkdownTokenType.inlineCode,
            text: text.substring(i + delimLen, closeIndex),
          ));

          // Closing backtick(s)
          tokens.add(MarkdownToken(
            start: baseOffset + closeIndex,
            end: baseOffset + closeIndex + delimLen,
            type: MarkdownTokenType.inlineCodeMarker,
            text: delimiter,
          ));

          i = closeIndex + delimLen;
          continue;
        }
      }

      // Links: [title](url)
      if (char == '[') {
        final linkMatch = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)').matchAsPrefix(text, i);
        if (linkMatch != null) {
          final fullMatch = linkMatch.group(0)!;
          final title = linkMatch.group(1)!;
          final url = linkMatch.group(2)!;

          final openBracketEnd = i + 1;
          final titleEnd = openBracketEnd + title.length;
          final closeBracketParenEnd = titleEnd + 2; // "]("
          final urlEnd = closeBracketParenEnd + url.length;
          final matchEnd = i + fullMatch.length;

          // "["
          tokens.add(MarkdownToken(
            start: baseOffset + i,
            end: baseOffset + openBracketEnd,
            type: MarkdownTokenType.syntaxMarker,
            text: '[',
          ));

          // Title
          tokens.add(MarkdownToken(
            start: baseOffset + openBracketEnd,
            end: baseOffset + titleEnd,
            type: MarkdownTokenType.linkText,
            text: title,
          ));
          // Sub-parse inline styles inside link title (e.g. bold link)
          _tokenizeInline(title, baseOffset + openBracketEnd, tokens);

          // "]("
          tokens.add(MarkdownToken(
            start: baseOffset + titleEnd,
            end: baseOffset + closeBracketParenEnd,
            type: MarkdownTokenType.syntaxMarker,
            text: '](',
          ));

          // URL
          if (url.isNotEmpty) {
            tokens.add(MarkdownToken(
              start: baseOffset + closeBracketParenEnd,
              end: baseOffset + urlEnd,
              type: MarkdownTokenType.linkUrl,
              text: url,
            ));
          }

          // ")"
          tokens.add(MarkdownToken(
            start: baseOffset + urlEnd,
            end: baseOffset + matchEnd,
            type: MarkdownTokenType.syntaxMarker,
            text: ')',
          ));

          i = matchEnd;
          continue;
        }
      }

      // Bare URLs: https://... or http://...
      if (text.startsWith('http://', i) || text.startsWith('https://', i)) {
        final urlMatch = RegExp(r'https?://[^\s<]+').matchAsPrefix(text, i);
        if (urlMatch != null) {
          final url = urlMatch.group(0)!;
          tokens.add(MarkdownToken(
            start: baseOffset + i,
            end: baseOffset + i + url.length,
            type: MarkdownTokenType.link,
            text: url,
          ));
          i += url.length;
          continue;
        }
      }

      // Tags: #tag (must be preceded by start of line or whitespace)
      if (char == '#' && (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\t')) {
        final tagMatch = RegExp(r'#([a-zA-Z0-9_\-\/]+)').matchAsPrefix(text, i);
        if (tagMatch != null) {
          final fullTag = tagMatch.group(0)!;
          tokens.add(MarkdownToken(
            start: baseOffset + i,
            end: baseOffset + i + fullTag.length,
            type: MarkdownTokenType.tag,
            text: fullTag,
          ));
          i += fullTag.length;
          continue;
        }
      }

      // Bold + Italic: ***text*** or ___text___
      if (text.startsWith('***', i) || text.startsWith('___', i)) {
        final delimiter = text.substring(i, i + 3);
        final closeIndex = _findClosingDelimiter(text, delimiter, i + 3);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 3, closeIndex);
          if (innerContent.isNotEmpty && !innerContent.startsWith(' ') && !innerContent.endsWith(' ')) {
            tokens.add(MarkdownToken(
              start: baseOffset + i,
              end: baseOffset + i + 3,
              type: MarkdownTokenType.syntaxMarker,
              text: delimiter,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + i + 3,
              end: baseOffset + closeIndex,
              type: MarkdownTokenType.boldItalic,
              text: innerContent,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 3,
              type: MarkdownTokenType.syntaxMarker,
              text: delimiter,
            ));

            _tokenizeInline(innerContent, baseOffset + i + 3, tokens);
            i = closeIndex + 3;
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
          if (innerContent.isNotEmpty && !innerContent.startsWith(' ') && !innerContent.endsWith(' ')) {
            tokens.add(MarkdownToken(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: delimiter,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + i + 2,
              end: baseOffset + closeIndex,
              type: MarkdownTokenType.bold,
              text: innerContent,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: delimiter,
            ));

            _tokenizeInline(innerContent, baseOffset + i + 2, tokens);
            i = closeIndex + 2;
            continue;
          }
        }
      }

      // Strikethrough: ~~text~~
      if (text.startsWith('~~', i)) {
        final closeIndex = _findClosingDelimiter(text, '~~', i + 2);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 2, closeIndex);
          if (innerContent.isNotEmpty && !innerContent.startsWith(' ') && !innerContent.endsWith(' ')) {
            tokens.add(MarkdownToken(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: '~~',
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + i + 2,
              end: baseOffset + closeIndex,
              type: MarkdownTokenType.strikethrough,
              text: innerContent,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: '~~',
            ));

            _tokenizeInline(innerContent, baseOffset + i + 2, tokens);
            i = closeIndex + 2;
            continue;
          }
        }
      }

      // Highlight: ==text==
      if (text.startsWith('==', i)) {
        final closeIndex = _findClosingDelimiter(text, '==', i + 2);
        if (closeIndex != -1) {
          final innerContent = text.substring(i + 2, closeIndex);
          if (innerContent.isNotEmpty && !innerContent.startsWith(' ') && !innerContent.endsWith(' ')) {
            tokens.add(MarkdownToken(
              start: baseOffset + i,
              end: baseOffset + i + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: '==',
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + i + 2,
              end: baseOffset + closeIndex,
              type: MarkdownTokenType.highlight,
              text: innerContent,
            ));

            tokens.add(MarkdownToken(
              start: baseOffset + closeIndex,
              end: baseOffset + closeIndex + 2,
              type: MarkdownTokenType.syntaxMarker,
              text: '==',
            ));

            _tokenizeInline(innerContent, baseOffset + i + 2, tokens);
            i = closeIndex + 2;
            continue;
          }
        }
      }

      // Italic: *text* or _text_
      if (char == '*' || char == '_') {
        final delimiter = char;
        // If delimiter is '_', avoid triggering inside words (e.g. variable_name)
        final isWordFlanked = (char == '_' && i > 0 && _isAlphanumeric(text[i - 1]));
        if (!isWordFlanked) {
          final closeIndex = _findClosingDelimiter(text, delimiter, i + 1);
          if (closeIndex != -1) {
            final innerContent = text.substring(i + 1, closeIndex);
            if (innerContent.isNotEmpty && !innerContent.startsWith(' ') && !innerContent.endsWith(' ')) {
              tokens.add(MarkdownToken(
                start: baseOffset + i,
                end: baseOffset + i + 1,
                type: MarkdownTokenType.syntaxMarker,
                text: delimiter,
              ));

              tokens.add(MarkdownToken(
                start: baseOffset + i + 1,
                end: baseOffset + closeIndex,
                type: MarkdownTokenType.italic,
                text: innerContent,
              ));

              tokens.add(MarkdownToken(
                start: baseOffset + closeIndex,
                end: baseOffset + closeIndex + 1,
                type: MarkdownTokenType.syntaxMarker,
                text: delimiter,
              ));

              _tokenizeInline(innerContent, baseOffset + i + 1, tokens);
              i = closeIndex + 1;
              continue;
            }
          }
        }
      }

      i++;
    }
  }

  int _findClosingDelimiter(String text, String delimiter, int startIndex) {
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

  bool _isEscapableChar(String char) {
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

  bool _isAlphanumeric(String char) {
    final code = char.codeUnitAt(0);
    return (code >= 48 && code <= 57) || // 0-9
        (code >= 65 && code <= 90) || // A-Z
        (code >= 97 && code <= 122); // a-z
  }

  MarkdownTokenType _headingTypeFromLevel(int level) {
    switch (level) {
      case 1:
        return MarkdownTokenType.heading1;
      case 2:
        return MarkdownTokenType.heading2;
      case 3:
        return MarkdownTokenType.heading3;
      case 4:
        return MarkdownTokenType.heading4;
      case 5:
        return MarkdownTokenType.heading5;
      case 6:
        return MarkdownTokenType.heading6;
      default:
        return MarkdownTokenType.heading1;
    }
  }

  List<_LineInfo> _splitLinesWithOffsets(String text) {
    final result = <_LineInfo>[];
    var start = 0;
    while (start <= text.length) {
      final newline = text.indexOf('\n', start);
      if (newline == -1) {
        result.add(_LineInfo(start: start, end: text.length, text: text.substring(start)));
        break;
      } else {
        result.add(_LineInfo(start: start, end: newline, text: text.substring(start, newline)));
        start = newline + 1;
      }
    }
    return result;
  }
}

class _LineInfo {
  final int start;
  final int end;
  final String text;

  const _LineInfo({
    required this.start,
    required this.end,
    required this.text,
  });
}
