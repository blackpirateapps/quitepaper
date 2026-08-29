import 'dart:typed_data';
import 'pdf_markdown_models.dart';

/// Semantic parser transforming canonical Markdown into structured [PdfBlock] components.
class PdfMarkdownParser {
  const PdfMarkdownParser();

  /// Parses a complete Markdown document [markdown] into a list of [PdfBlock] items.
  List<PdfBlock> parse({
    required String markdown,
    Map<String, Uint8List> imageMap = const {},
    bool includeAttachments = true,
  }) {
    var text = markdown;

    // 1. Strip YAML frontmatter at document start
    if (text.startsWith('---')) {
      final endIndex = text.indexOf('\n---', 3);
      if (endIndex != -1) {
        text = text.substring(endIndex + 4).trimLeft();
      }
    }

    final blocks = <PdfBlock>[];
    final lines = text.split('\n');
    final count = lines.length;
    var i = 0;

    while (i < count) {
      final line = lines[i];
      final trimmed = line.trim();

      // Empty line / whitespace
      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // 2. Fenced Code Blocks (``` or ~~~)
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.substring(0, 3);
        final language = trimmed.substring(3).trim();
        final codeLines = <String>[];
        i++;

        while (i < count) {
          final codeLine = lines[i];
          if (codeLine.trim().startsWith(fence)) {
            i++;
            break;
          }
          codeLines.add(codeLine);
          i++;
        }

        blocks.add(
          PdfCodeBlock(
            code: codeLines.join('\n'),
            language: language,
          ),
        );
        continue;
      }

      // 3. Horizontal Rule (---, ***, ___)
      if (RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$').hasMatch(line)) {
        blocks.add(const PdfHorizontalRuleBlock());
        i++;
        continue;
      }

      // 4. Standalone Image: ![alt](url)
      final imgMatch = RegExp(r'^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$').firstMatch(line);
      if (imgMatch != null) {
        final alt = imgMatch.group(1) ?? '';
        final uri = imgMatch.group(2)!.trim();
        Uint8List? bytes;

        if (includeAttachments) {
          bytes = imageMap[uri] ?? imageMap['qp://asset/$uri'];
          if (bytes == null && uri.startsWith('qp://asset/')) {
            final assetId = uri.replaceFirst('qp://asset/', '').trim();
            bytes = imageMap[assetId] ?? imageMap[uri];
          }
        }

        blocks.add(
          PdfImageBlock(
            uri: uri,
            alt: alt,
            bytes: bytes,
          ),
        );
        i++;
        continue;
      }

      // 5. Headings (# to ######)
      final headingMatch = RegExp(r'^(\s*)(#{1,6})(?:\s+(.*)|$)').firstMatch(line);
      if (headingMatch != null) {
        final hashes = headingMatch.group(2)!;
        final content = headingMatch.group(3) ?? '';
        final level = hashes.length.clamp(1, 6);

        blocks.add(
          PdfHeadingBlock(
            level: level,
            inlines: parseInline(content.trim()),
          ),
        );
        i++;
        continue;
      }

      // 6. GFM Tables (| Col1 | Col2 |)
      if (line.contains('|') && i + 1 < count && _isTableDelimiterLine(lines[i + 1])) {
        final tableBlock = _parseTable(lines, i);
        if (tableBlock != null) {
          blocks.add(tableBlock.block);
          i = tableBlock.nextIndex;
          continue;
        }
      }

      // 7. Blockquotes (> quote)
      if (line.trim().startsWith('>')) {
        final quoteLines = <String>[];
        while (i < count && lines[i].trim().startsWith('>')) {
          var qLine = lines[i].trim();
          qLine = qLine.replaceFirst(RegExp(r'^>+\s?'), '');
          quoteLines.add(qLine);
          i++;
        }

        final combined = quoteLines.join('\n');
        blocks.add(
          PdfBlockquoteBlock(
            inlines: parseInline(combined),
          ),
        );
        continue;
      }

      // 8. Checklists (- [ ] or - [x] or * [ ] or + [ ])
      final checkMatch = RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:\s+(.*)|$)').firstMatch(line);
      if (checkMatch != null) {
        final checklistItems = <PdfChecklistItem>[];

        while (i < count) {
          final cMatch = RegExp(r'^(\s*)([-*+]\s*\[)([ xX])(\])(?:\s+(.*)|$)').firstMatch(lines[i]);
          if (cMatch == null) break;

          final indentStr = cMatch.group(1) ?? '';
          final stateChar = cMatch.group(3) ?? ' ';
          final content = cMatch.group(5) ?? '';
          final isChecked = stateChar == 'x' || stateChar == 'X';
          final indentLevel = (indentStr.length / 2).floor();

          checklistItems.add(
            PdfChecklistItem(
              isChecked: isChecked,
              inlines: parseInline(content),
              indentLevel: indentLevel,
            ),
          );
          i++;
        }

        blocks.add(PdfChecklistBlock(items: checklistItems));
        continue;
      }

      // 9. Ordered / Unordered Lists
      final bulletMatch = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(line);
      final orderedMatch = RegExp(r'^(\s*)(\d+)[\.\)]\s+(.*)$').firstMatch(line);

      if (bulletMatch != null || orderedMatch != null) {
        final isOrdered = orderedMatch != null;
        final listItems = <PdfListItem>[];

        while (i < count) {
          final curLine = lines[i];
          final curBullet = RegExp(r'^(\s*)([-*+])\s+(.*)$').firstMatch(curLine);
          final curOrdered = RegExp(r'^(\s*)(\d+)[\.\)]\s+(.*)$').firstMatch(curLine);

          // Check if checklist item
          if (RegExp(r'^\s*[-*+]\s*\[[ xX]\]').hasMatch(curLine)) {
            break;
          }

          if (isOrdered && curOrdered != null) {
            final indentStr = curOrdered.group(1) ?? '';
            final numVal = int.tryParse(curOrdered.group(2)!) ?? (listItems.length + 1);
            final content = curOrdered.group(3) ?? '';
            final indentLevel = (indentStr.length / 2).floor();

            listItems.add(
              PdfListItem(
                inlines: parseInline(content),
                number: numVal,
                indentLevel: indentLevel,
              ),
            );
            i++;
          } else if (!isOrdered && curBullet != null) {
            final indentStr = curBullet.group(1) ?? '';
            final content = curBullet.group(3) ?? '';
            final indentLevel = (indentStr.length / 2).floor();

            listItems.add(
              PdfListItem(
                inlines: parseInline(content),
                indentLevel: indentLevel,
              ),
            );
            i++;
          } else {
            break;
          }
        }

        if (listItems.isNotEmpty) {
          blocks.add(
            PdfListBlock(
              items: listItems,
              isOrdered: isOrdered,
            ),
          );
        }
        continue;
      }

      // 10. Standard Paragraph (groups non-empty consecutive lines preserving soft line breaks)
      final paragraphLines = <String>[];
      while (i < count) {
        final pLine = lines[i];
        final pTrim = pLine.trim();
        if (pTrim.isEmpty) break;

        // Check if starting a new block construct
        if (pTrim.startsWith('```') ||
            pTrim.startsWith('~~~') ||
            pTrim.startsWith('>') ||
            RegExp(r'^\s*#{1,6}\s+').hasMatch(pLine) ||
            RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$').hasMatch(pLine) ||
            RegExp(r'^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$').hasMatch(pLine) ||
            RegExp(r'^\s*[-*+]\s+').hasMatch(pLine) ||
            RegExp(r'^\s*\d+[\.\)]\s+').hasMatch(pLine) ||
            (pLine.contains('|') && i + 1 < count && _isTableDelimiterLine(lines[i + 1]))) {
          break;
        }

        paragraphLines.add(pLine);
        i++;
      }

      if (paragraphLines.isNotEmpty) {
        final combinedParagraph = paragraphLines.join('\n');
        blocks.add(
          PdfParagraphBlock(
            inlines: parseInline(combinedParagraph),
          ),
        );
      }
    }

    return blocks;
  }

  static bool _isTableDelimiterLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.contains('|')) return false;
    return RegExp(r'^\|?(\s*:?-+:?\s*\|)+\s*:?-+:?\s*\|?$').hasMatch(trimmed);
  }

  static _ParsedTableResult? _parseTable(List<String> lines, int startIndex) {
    final headerLine = lines[startIndex].trim();
    final delimiterLine = lines[startIndex + 1].trim();

    final headerCells = _splitTableRow(headerLine);
    final delimiterCells = _splitTableRow(delimiterLine);

    if (headerCells.isEmpty || delimiterCells.isEmpty) return null;

    final alignments = <PdfTableCellAlignment>[];
    for (final delim in delimiterCells) {
      final clean = delim.trim();
      if (clean.startsWith(':') && clean.endsWith(':')) {
        alignments.add(PdfTableCellAlignment.center);
      } else if (clean.endsWith(':')) {
        alignments.add(PdfTableCellAlignment.right);
      } else {
        alignments.add(PdfTableCellAlignment.left);
      }
    }

    final headers = headerCells.map((h) => parseInline(h.trim())).toList();
    final rows = <List<List<PdfInlineRun>>>[];

    var i = startIndex + 2;
    while (i < lines.length) {
      final rowLine = lines[i].trim();
      if (rowLine.isEmpty || !rowLine.contains('|')) break;
      final rowCells = _splitTableRow(rowLine);
      if (rowCells.isEmpty) break;

      final parsedRow = rowCells.map((c) => parseInline(c.trim())).toList();
      rows.add(parsedRow);
      i++;
    }

    return _ParsedTableResult(
      block: PdfTableBlock(
        headers: headers,
        alignments: alignments,
        rows: rows,
      ),
      nextIndex: i,
    );
  }

  static List<String> _splitTableRow(String row) {
    var clean = row.trim();
    if (clean.startsWith('|')) clean = clean.substring(1);
    if (clean.endsWith('|')) clean = clean.substring(0, clean.length - 1);
    return clean.split('|');
  }

  /// Recursively parses an inline Markdown string [text] into semantic [PdfInlineRun]s.
  static List<PdfInlineRun> parseInline(
    String text, {
    bool isBold = false,
    bool isItalic = false,
    bool isStrike = false,
    bool isHighlight = false,
    bool isCode = false,
    String? linkUrl,
    bool isTag = false,
  }) {
    if (text.isEmpty) return const [];

    final runs = <PdfInlineRun>[];
    var i = 0;
    final len = text.length;

    while (i < len) {
      final char = text[i];

      // 1. Escaped characters: \* \_ \` \# \[ \] \( \) \~ \= \\
      if (char == '\\' && i + 1 < len) {
        final next = text[i + 1];
        if (_isEscapable(next)) {
          runs.add(
            PdfInlineRun(
              text: next,
              isBold: isBold,
              isItalic: isItalic,
              isStrike: isStrike,
              isHighlight: isHighlight,
              isCode: isCode,
              linkUrl: linkUrl,
              isTag: isTag,
            ),
          );
          i += 2;
          continue;
        }
      }

      // 2. Inline Code: `code` or ``code``
      if (char == '`') {
        final isDouble = (i + 1 < len && text[i + 1] == '`');
        final delim = isDouble ? '``' : '`';
        final dLen = delim.length;
        final closeIdx = text.indexOf(delim, i + dLen);

        if (closeIdx != -1) {
          final codeContent = text.substring(i + dLen, closeIdx);
          runs.add(
            PdfInlineRun(
              text: codeContent,
              isCode: true,
              isBold: isBold,
              isItalic: isItalic,
              isStrike: isStrike,
              linkUrl: linkUrl,
            ),
          );
          i = closeIdx + dLen;
          continue;
        }
      }

      // 3. Links: [text](url)
      if (char == '[') {
        final linkMatch = RegExp(r'^\[([^\]\n]+)\]\(([^)\n]*)\)').matchAsPrefix(text, i);
        if (linkMatch != null) {
          final title = linkMatch.group(1)!;
          final targetUrl = linkMatch.group(2)!.trim();

          runs.addAll(
            parseInline(
              title,
              isBold: isBold,
              isItalic: isItalic,
              isStrike: isStrike,
              isHighlight: isHighlight,
              isCode: isCode,
              linkUrl: targetUrl.isNotEmpty ? targetUrl : null,
              isTag: isTag,
            ),
          );
          i += linkMatch.group(0)!.length;
          continue;
        }
      }

      // 4. Bare URLs: https://... or http://...
      if (text.startsWith('http://', i) || text.startsWith('https://', i)) {
        final urlMatch = RegExp(r'^https?://[^\s<]+').matchAsPrefix(text, i);
        if (urlMatch != null) {
          final url = urlMatch.group(0)!;
          runs.add(
            PdfInlineRun(
              text: url,
              linkUrl: url,
              isBold: isBold,
              isItalic: isItalic,
            ),
          );
          i += url.length;
          continue;
        }
      }

      // 5. Tags: #tag (must be preceded by whitespace, start of line, or soft line break)
      if (char == '#' && (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\t' || text[i - 1] == '\n')) {
        final tagMatch = RegExp(r'^#([a-zA-Z0-9_\-\/]+)').matchAsPrefix(text, i);
        if (tagMatch != null) {
          final fullTag = tagMatch.group(0)!;
          runs.add(
            PdfInlineRun(
              text: fullTag,
              isTag: true,
              isBold: isBold,
              isItalic: isItalic,
            ),
          );
          i += fullTag.length;
          continue;
        }
      }

      // 6. Bold + Italic: ***text*** or ___text___
      if (text.startsWith('***', i) || text.startsWith('___', i)) {
        final delim = text.substring(i, i + 3);
        final closeIdx = _findClosing(text, delim, i + 3);
        if (closeIdx != -1) {
          final inner = text.substring(i + 3, closeIdx);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            runs.addAll(
              parseInline(
                inner,
                isBold: true,
                isItalic: true,
                isStrike: isStrike,
                isHighlight: isHighlight,
                isCode: isCode,
                linkUrl: linkUrl,
                isTag: isTag,
              ),
            );
            i = closeIdx + 3;
            continue;
          }
        }
      }

      // 7. Bold: **text** or __text__
      if (text.startsWith('**', i) || text.startsWith('__', i)) {
        final delim = text.substring(i, i + 2);
        final closeIdx = _findClosing(text, delim, i + 2);
        if (closeIdx != -1) {
          final inner = text.substring(i + 2, closeIdx);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            runs.addAll(
              parseInline(
                inner,
                isBold: true,
                isItalic: isItalic,
                isStrike: isStrike,
                isHighlight: isHighlight,
                isCode: isCode,
                linkUrl: linkUrl,
                isTag: isTag,
              ),
            );
            i = closeIdx + 2;
            continue;
          }
        }
      }

      // 8. Strikethrough: ~~text~~
      if (text.startsWith('~~', i)) {
        final closeIdx = _findClosing(text, '~~', i + 2);
        if (closeIdx != -1) {
          final inner = text.substring(i + 2, closeIdx);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            runs.addAll(
              parseInline(
                inner,
                isBold: isBold,
                isItalic: isItalic,
                isStrike: true,
                isHighlight: isHighlight,
                isCode: isCode,
                linkUrl: linkUrl,
                isTag: isTag,
              ),
            );
            i = closeIdx + 2;
            continue;
          }
        }
      }

      // 9. Highlight: ==text==
      if (text.startsWith('==', i)) {
        final closeIdx = _findClosing(text, '==', i + 2);
        if (closeIdx != -1) {
          final inner = text.substring(i + 2, closeIdx);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            runs.addAll(
              parseInline(
                inner,
                isBold: isBold,
                isItalic: isItalic,
                isStrike: isStrike,
                isHighlight: true,
                isCode: isCode,
                linkUrl: linkUrl,
                isTag: isTag,
              ),
            );
            i = closeIdx + 2;
            continue;
          }
        }
      }

      // 10. Italic: *text* or _text_
      if (char == '*' || char == '_') {
        final delim = char;
        final isWordFlanked = (char == '_' && i > 0 && _isAlphanumeric(text[i - 1]));
        if (!isWordFlanked) {
          final closeIdx = _findClosing(text, delim, i + 1);
          if (closeIdx != -1) {
            final inner = text.substring(i + 1, closeIdx);
            if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
              runs.addAll(
                parseInline(
                  inner,
                  isBold: isBold,
                  isItalic: true,
                  isStrike: isStrike,
                  isHighlight: isHighlight,
                  isCode: isCode,
                  linkUrl: linkUrl,
                  isTag: isTag,
                ),
              );
              i = closeIdx + 1;
              continue;
            }
          }
        }
      }

      // Plain character or text slice accumulation
      var end = i + 1;
      while (end < len) {
        final c = text[end];
        if (c == '\\' ||
            c == '`' ||
            c == '[' ||
            c == '*' ||
            c == '_' ||
            c == '~' ||
            c == '=' ||
            c == '#' ||
            (c == 'h' && (text.startsWith('http://', end) || text.startsWith('https://', end)))) {
          break;
        }
        end++;
      }

      runs.add(
        PdfInlineRun(
          text: text.substring(i, end),
          isBold: isBold,
          isItalic: isItalic,
          isStrike: isStrike,
          isHighlight: isHighlight,
          isCode: isCode,
          linkUrl: linkUrl,
          isTag: isTag,
        ),
      );
      i = end;
    }

    return runs;
  }

  static int _findClosing(String text, String delimiter, int start) {
    var idx = start;
    while (idx < text.length) {
      final found = text.indexOf(delimiter, idx);
      if (found == -1) return -1;
      if (found > 0 && text[found - 1] == '\\') {
        idx = found + delimiter.length;
        continue;
      }
      return found;
    }
    return -1;
  }

  static bool _isEscapable(String char) {
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
    return (code >= 48 && code <= 57) ||
        (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122);
  }
}

class _ParsedTableResult {
  const _ParsedTableResult({
    required this.block,
    required this.nextIndex,
  });

  final PdfTableBlock block;
  final int nextIndex;
}
