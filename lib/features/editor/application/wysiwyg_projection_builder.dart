import 'package:flutter/material.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../domain/markdown_styles.dart';
import '../domain/markdown_token.dart';
import '../domain/source_visual_mapping.dart';

/// Builds a [SourceVisualMapping] from canonical Markdown source, hiding raw delimiters
/// and producing visual runs with appropriate typography and styling.
abstract final class WysiwygProjectionBuilder {
  static final String uncheckedGlyph = '${String.fromCharCode(PhosphorIconsRegular.square.codePoint)} ';
  static final String checkedGlyph = '${String.fromCharCode(PhosphorIconsRegular.checkSquare.codePoint)} ';

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

  /// Builds a [SourceVisualMapping] for [sourceText] using [styles].
  ///
  /// If [stripFrontmatter] is true, frontmatter block at index 0 is excluded from the visual projection
  /// (because it is displayed in the dedicated Properties section).
  static SourceVisualMapping build({
    required String sourceText,
    required MarkdownStyles styles,
    bool stripFrontmatter = false,
  }) {
    if (sourceText.isEmpty) {
      return SourceVisualMapping.empty;
    }

    final runs = <MarkdownVisualRun>[];
    final visualBuffer = StringBuffer();
    final lines = _splitLinesWithOffsets(sourceText);

    var inFrontmatter = false;

    for (var i = 0; i < lines.length; i++) {
      final lineInfo = lines[i];
      final lineText = lineInfo.text;
      final lineStart = lineInfo.start;
      final lineEnd = lineInfo.end;

      var isClosingFrontmatterLine = false;

      // 1. YAML Frontmatter check (only starts at document index 0)
      if (i == 0 && lineText.trim() == '---') {
        inFrontmatter = true;
        if (!stripFrontmatter) {
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: lineStart,
            sourceEnd: lineEnd,
            visualText: lineText,
            type: MarkdownTokenType.frontmatterDelimiter,
            style: styles.frontmatterDelimiter,
          );
        } else {
          // Hidden frontmatter
          runs.add(MarkdownVisualRun(
            sourceStart: lineStart,
            sourceEnd: lineEnd,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.frontmatterDelimiter,
            style: styles.frontmatterDelimiter,
            visualText: '',
            isHiddenSyntax: true,
          ));
        }
      } else if (inFrontmatter) {
        if (lineText.trim() == '---' || lineText.trim() == '...') {
          inFrontmatter = false;
          isClosingFrontmatterLine = true;
          if (!stripFrontmatter) {
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: lineStart,
              sourceEnd: lineEnd,
              visualText: lineText,
              type: MarkdownTokenType.frontmatterDelimiter,
              style: styles.frontmatterDelimiter,
            );
          } else {
            runs.add(MarkdownVisualRun(
              sourceStart: lineStart,
              sourceEnd: lineEnd,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.frontmatterDelimiter,
              style: styles.frontmatterDelimiter,
              visualText: '',
              isHiddenSyntax: true,
            ));
          }
        } else {
          if (!stripFrontmatter) {
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: lineStart,
              sourceEnd: lineEnd,
              visualText: lineText,
              type: MarkdownTokenType.frontmatter,
              style: styles.frontmatter,
            );
          } else {
            runs.add(MarkdownVisualRun(
              sourceStart: lineStart,
              sourceEnd: lineEnd,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.frontmatter,
              style: styles.frontmatter,
              visualText: '',
              isHiddenSyntax: true,
            ));
          }
        }
      }
      // 2. Fenced Code Blocks (``` or ~~~)
      else if (_codeFenceRegex.firstMatch(lineText) case final fenceMatch?) {
        final fenceDelimiter = fenceMatch.group(2) ?? '```';

        // Opening fence: in WYSIWYG, we can hide the raw fence or style it quietly
        runs.add(MarkdownVisualRun(
          sourceStart: lineStart,
          sourceEnd: lineStart + lineText.length,
          visualStart: visualBuffer.length,
          visualEnd: visualBuffer.length,
          type: MarkdownTokenType.codeBlockFence,
          style: styles.codeBlockFence,
          visualText: '',
          isHiddenSyntax: true,
        ));

        // Look ahead for closing fence
        var closingIndex = -1;
        for (var j = i + 1; j < lines.length; j++) {
          final candidateText = lines[j].text;
          final candMatch = _codeFenceRegex.firstMatch(candidateText);
          if (candMatch != null && candMatch.group(2) == fenceDelimiter) {
            closingIndex = j;
            break;
          }
        }

        if (closingIndex != -1) {
          // Closed code block
          if (closingIndex > i + 1) {
            final bodyStart = lines[i + 1].start;
            final bodyEnd = lines[closingIndex].start;
            final bodyText = sourceText.substring(bodyStart, bodyEnd);

            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: bodyStart,
              sourceEnd: bodyEnd,
              visualText: bodyText,
              type: MarkdownTokenType.codeBlock,
              style: styles.codeBlock,
            );
          }

          // Closing fence is hidden
          final closingLine = lines[closingIndex];
          runs.add(MarkdownVisualRun(
            sourceStart: closingLine.start,
            sourceEnd: closingLine.start + closingLine.text.length,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.codeBlockFence,
            style: styles.codeBlockFence,
            visualText: '',
            isHiddenSyntax: true,
          ));

          i = closingIndex;
          continue;
        } else {
          // Unclosed code block spanning to end
          if (i + 1 < lines.length) {
            final bodyStart = lines[i + 1].start;
            final bodyEnd = sourceText.length;
            final bodyText = sourceText.substring(bodyStart, bodyEnd);

            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: bodyStart,
              sourceEnd: bodyEnd,
              visualText: bodyText,
              type: MarkdownTokenType.codeBlock,
              style: styles.codeBlock,
            );
          }
          i = lines.length;
          continue;
        }
      }
      // 3. Horizontal Rules (---, ***, ___)
      else if (_horizontalRuleRegex.hasMatch(lineText)) {
        _addVisualRun(
          runs: runs,
          visualBuffer: visualBuffer,
          sourceStart: lineStart,
          sourceEnd: lineStart + lineText.length,
          visualText: lineText,
          type: MarkdownTokenType.horizontalRule,
          style: styles.horizontalRule,
        );
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
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: currentOffset,
            sourceEnd: currentOffset + indentLen,
            visualText: lineText.substring(0, indentLen),
            type: MarkdownTokenType.body,
            style: styles.body,
          );
          currentOffset += indentLen;
        }

        // Heading marker (e.g. "## ") is HIDDEN in WYSIWYG mode
        final totalMarkerLen = hashCount + sepLen;
        runs.add(MarkdownVisualRun(
          sourceStart: currentOffset,
          sourceEnd: currentOffset + totalMarkerLen,
          visualStart: visualBuffer.length,
          visualEnd: visualBuffer.length,
          type: MarkdownTokenType.headingMarker,
          style: headingStyle,
          visualText: '',
          isHiddenSyntax: true,
        ));
        currentOffset += totalMarkerLen;

        final remainderStart = indentLen + totalMarkerLen;
        if (remainderStart < lineText.length) {
          final remainder = lineText.substring(remainderStart);
          _projectInlineSegments(
            text: remainder,
            baseOffset: currentOffset,
            baseStyle: headingStyle,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
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
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: currentOffset,
            sourceEnd: currentOffset + indent.length,
            visualText: indent,
            type: MarkdownTokenType.body,
            style: styles.body,
          );
          currentOffset += indent.length;
        }

        // Quote marker (e.g. "> ") is HIDDEN in WYSIWYG mode
        final markerWithSep = '$marker$sep';
        runs.add(MarkdownVisualRun(
          sourceStart: currentOffset,
          sourceEnd: currentOffset + markerWithSep.length,
          visualStart: visualBuffer.length,
          visualEnd: visualBuffer.length,
          type: MarkdownTokenType.blockquoteMarker,
          style: styles.blockquote,
          visualText: '',
          isHiddenSyntax: true,
        ));
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _projectInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.blockquote,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
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
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: currentOffset,
            sourceEnd: currentOffset + indent.length,
            visualText: indent,
            type: MarkdownTokenType.body,
            style: styles.body,
          );
          currentOffset += indent.length;
        }

        final markerBaseStyle = isChecked ? styles.taskTextCompleted : styles.body;
        final markerText = '$prefix$stateChar$closeBracket$sep';

        // Checkbox marker in WYSIWYG is mapped to Phosphor icon symbol
        final visualCheckbox = isChecked ? checkedGlyph : uncheckedGlyph;
        _addVisualRun(
          runs: runs,
          visualBuffer: visualBuffer,
          sourceStart: currentOffset,
          sourceEnd: currentOffset + markerText.length,
          visualText: visualCheckbox,
          type: isChecked
              ? MarkdownTokenType.checklistMarkerChecked
              : MarkdownTokenType.checklistMarkerUnchecked,
          style: markerBaseStyle.copyWith(
            fontFamily: PhosphorIconsRegular.fontFamily,
            color: isChecked
                ? styles.checklistMarkerChecked.color
                : styles.checklistMarker.color,
            fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
          ),
        );
        currentOffset += markerText.length;

        if (content.isNotEmpty) {
          _projectInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: markerBaseStyle,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
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
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: currentOffset,
            sourceEnd: currentOffset + indent.length,
            visualText: indent,
            type: MarkdownTokenType.body,
            style: styles.body,
          );
          currentOffset += indent.length;
        }

        final markerWithSep = '$marker$sep';
        // In WYSIWYG mode, "- " becomes "• " bullet
        _addVisualRun(
          runs: runs,
          visualBuffer: visualBuffer,
          sourceStart: currentOffset,
          sourceEnd: currentOffset + markerWithSep.length,
          visualText: '• ',
          type: MarkdownTokenType.unorderedListMarker,
          style: styles.body.copyWith(
            color: styles.listMarker.color,
            fontWeight: styles.listMarker.fontWeight ?? FontWeight.w600,
          ),
        );
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _projectInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.body,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
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
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: currentOffset,
            sourceEnd: currentOffset + indent.length,
            visualText: indent,
            type: MarkdownTokenType.body,
            style: styles.body,
          );
          currentOffset += indent.length;
        }

        final markerWithSep = '$marker$sep';
        _addVisualRun(
          runs: runs,
          visualBuffer: visualBuffer,
          sourceStart: currentOffset,
          sourceEnd: currentOffset + markerWithSep.length,
          visualText: markerWithSep,
          type: MarkdownTokenType.orderedListMarker,
          style: styles.body.copyWith(
            color: styles.listMarker.color,
            fontWeight: styles.listMarker.fontWeight ?? FontWeight.w600,
          ),
        );
        currentOffset += markerWithSep.length;

        if (content.isNotEmpty) {
          _projectInlineSegments(
            text: content,
            baseOffset: currentOffset,
            baseStyle: styles.body,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
          );
        }
      }
      // 9. Normal Body line
      else {
        if (lineText.isNotEmpty) {
          _projectInlineSegments(
            text: lineText,
            baseOffset: lineStart,
            baseStyle: styles.body,
            styles: styles,
            runs: runs,
            visualBuffer: visualBuffer,
          );
        }
      }

      // Newline separator between lines
      if (i < lines.length - 1) {
        final newlineOffset = lineStart + lineText.length;
        if ((!inFrontmatter && !isClosingFrontmatterLine) || !stripFrontmatter) {
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: newlineOffset,
            sourceEnd: newlineOffset + 1,
            visualText: '\n',
            type: MarkdownTokenType.body,
            style: styles.body,
          );
        } else {
          runs.add(MarkdownVisualRun(
            sourceStart: newlineOffset,
            sourceEnd: newlineOffset + 1,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.frontmatter,
            style: styles.frontmatter,
            visualText: '',
            isHiddenSyntax: true,
          ));
        }
      }
    }

    return SourceVisualMapping(
      sourceText: sourceText,
      visualText: visualBuffer.toString(),
      runs: runs,
    );
  }

  /// Appends a visual run and writes to the visual text buffer.
  static void _addVisualRun({
    required List<MarkdownVisualRun> runs,
    required StringBuffer visualBuffer,
    required int sourceStart,
    required int sourceEnd,
    required String visualText,
    required MarkdownTokenType type,
    required TextStyle style,
  }) {
    final vStart = visualBuffer.length;
    visualBuffer.write(visualText);
    final vEnd = visualBuffer.length;

    runs.add(MarkdownVisualRun(
      sourceStart: sourceStart,
      sourceEnd: sourceEnd,
      visualStart: vStart,
      visualEnd: vEnd,
      type: type,
      style: style,
      visualText: visualText,
      isHiddenSyntax: false,
    ));
  }

  /// Scans inline tokens (bold, italic, code, links, tags, etc.) and hides delimiters in WYSIWYG.
  static void _projectInlineSegments({
    required String text,
    required int baseOffset,
    required TextStyle baseStyle,
    required MarkdownStyles styles,
    required List<MarkdownVisualRun> runs,
    required StringBuffer visualBuffer,
  }) {
    var i = 0;
    final len = text.length;
    var plainStart = 0;

    void flushPlain(int end) {
      if (end > plainStart) {
        final segment = text.substring(plainStart, end);
        _addVisualRun(
          runs: runs,
          visualBuffer: visualBuffer,
          sourceStart: baseOffset + plainStart,
          sourceEnd: baseOffset + end,
          visualText: segment,
          type: MarkdownTokenType.body,
          style: baseStyle,
        );
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
          // Hide the backslash
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + i,
            sourceEnd: baseOffset + i + 1,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.syntaxMarker,
            style: baseStyle,
            visualText: '',
            isHiddenSyntax: true,
          ));
          // Show the escaped character as plain text
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: baseOffset + i + 1,
            sourceEnd: baseOffset + i + 2,
            visualText: nextChar,
            type: MarkdownTokenType.body,
            style: baseStyle,
          );
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
          // Hide opening backtick
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + i,
            sourceEnd: baseOffset + i + delimLen,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.inlineCodeMarker,
            style: styles.inlineCode,
            visualText: '',
            isHiddenSyntax: true,
          ));

          // Visible code text
          final codeContent = text.substring(i + delimLen, closeIndex);
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: baseOffset + i + delimLen,
            sourceEnd: baseOffset + closeIndex,
            visualText: codeContent,
            type: MarkdownTokenType.inlineCode,
            style: styles.inlineCode,
          );

          // Hide closing backtick
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + closeIndex,
            sourceEnd: baseOffset + closeIndex + delimLen,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.inlineCodeMarker,
            style: styles.inlineCode,
            visualText: '',
            isHiddenSyntax: true,
          ));

          i = closeIndex + delimLen;
          plainStart = i;
          continue;
        }
      }

      // Note Link: [[Title]]
      if (text.startsWith('[[', i)) {
        final closeIndex = text.indexOf(']]', i + 2);
        if (closeIndex != -1) {
          flushPlain(i);
          final title = text.substring(i + 2, closeIndex);

          // Hide [[
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + i,
            sourceEnd: baseOffset + i + 2,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.syntaxMarker,
            style: styles.link,
            visualText: '',
            isHiddenSyntax: true,
          ));

          // Visible title
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: baseOffset + i + 2,
            sourceEnd: baseOffset + closeIndex,
            visualText: title,
            type: MarkdownTokenType.linkText,
            style: styles.link,
          );

          // Hide ]]
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + closeIndex,
            sourceEnd: baseOffset + closeIndex + 2,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.syntaxMarker,
            style: styles.link,
            visualText: '',
            isHiddenSyntax: true,
          ));

          i = closeIndex + 2;
          plainStart = i;
          continue;
        }
      }

      // Markdown Link: [label](url)
      if (char == '[') {
        final linkMatch = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)').matchAsPrefix(text, i);
        if (linkMatch != null) {
          final fullMatch = linkMatch.group(0)!;
          final title = linkMatch.group(1)!;

          flushPlain(i);

          // Hide "["
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + i,
            sourceEnd: baseOffset + i + 1,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.syntaxMarker,
            style: styles.link,
            visualText: '',
            isHiddenSyntax: true,
          ));

          // Visible title
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: baseOffset + i + 1,
            sourceEnd: baseOffset + i + 1 + title.length,
            visualText: title,
            type: MarkdownTokenType.linkText,
            style: styles.link,
          );

          // Hide "](url)"
          final closingPartStart = i + 1 + title.length;
          final closingPartEnd = i + fullMatch.length;
          runs.add(MarkdownVisualRun(
            sourceStart: baseOffset + closingPartStart,
            sourceEnd: baseOffset + closingPartEnd,
            visualStart: visualBuffer.length,
            visualEnd: visualBuffer.length,
            type: MarkdownTokenType.linkUrl,
            style: styles.link,
            visualText: '',
            isHiddenSyntax: true,
          ));

          i = closingPartEnd;
          plainStart = i;
          continue;
        }
      }

      // Tags: #tag
      if (char == '#' && (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\t')) {
        final tagMatch = RegExp(r'#([a-zA-Z0-9_\-\/]+)').matchAsPrefix(text, i);
        if (tagMatch != null) {
          final fullTag = tagMatch.group(0)!;
          flushPlain(i);
          _addVisualRun(
            runs: runs,
            visualBuffer: visualBuffer,
            sourceStart: baseOffset + i,
            sourceEnd: baseOffset + i + fullTag.length,
            visualText: fullTag,
            type: MarkdownTokenType.tag,
            style: styles.tag,
          );
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
          final inner = text.substring(i + 3, closeIndex);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            flushPlain(i);

            // Hide opening ***
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + i,
              sourceEnd: baseOffset + i + 3,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.boldItalic,
              visualText: '',
              isHiddenSyntax: true,
            ));

            // Visible text with bold italic style
            final boldItalicStyle = baseStyle.merge(styles.boldItalic);
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: baseOffset + i + 3,
              sourceEnd: baseOffset + closeIndex,
              visualText: inner,
              type: MarkdownTokenType.boldItalic,
              style: boldItalicStyle,
            );

            // Hide closing ***
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + closeIndex,
              sourceEnd: baseOffset + closeIndex + 3,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.boldItalic,
              visualText: '',
              isHiddenSyntax: true,
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
          final inner = text.substring(i + 2, closeIndex);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            flushPlain(i);

            // Hide opening **
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + i,
              sourceEnd: baseOffset + i + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.bold,
              visualText: '',
              isHiddenSyntax: true,
            ));

            // Visible text with bold style
            final boldStyle = baseStyle.merge(styles.bold);
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: baseOffset + i + 2,
              sourceEnd: baseOffset + closeIndex,
              visualText: inner,
              type: MarkdownTokenType.bold,
              style: boldStyle,
            );

            // Hide closing **
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + closeIndex,
              sourceEnd: baseOffset + closeIndex + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.bold,
              visualText: '',
              isHiddenSyntax: true,
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
          final inner = text.substring(i + 2, closeIndex);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            flushPlain(i);

            // Hide opening ~~
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + i,
              sourceEnd: baseOffset + i + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.strikethrough,
              visualText: '',
              isHiddenSyntax: true,
            ));

            final strikeStyle = baseStyle.merge(styles.strikethrough);
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: baseOffset + i + 2,
              sourceEnd: baseOffset + closeIndex,
              visualText: inner,
              type: MarkdownTokenType.strikethrough,
              style: strikeStyle,
            );

            // Hide closing ~~
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + closeIndex,
              sourceEnd: baseOffset + closeIndex + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.strikethrough,
              visualText: '',
              isHiddenSyntax: true,
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
          final inner = text.substring(i + 2, closeIndex);
          if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
            flushPlain(i);

            // Hide opening ==
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + i,
              sourceEnd: baseOffset + i + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.highlight,
              visualText: '',
              isHiddenSyntax: true,
            ));

            final highlightStyle = baseStyle.merge(styles.highlight);
            _addVisualRun(
              runs: runs,
              visualBuffer: visualBuffer,
              sourceStart: baseOffset + i + 2,
              sourceEnd: baseOffset + closeIndex,
              visualText: inner,
              type: MarkdownTokenType.highlight,
              style: highlightStyle,
            );

            // Hide closing ==
            runs.add(MarkdownVisualRun(
              sourceStart: baseOffset + closeIndex,
              sourceEnd: baseOffset + closeIndex + 2,
              visualStart: visualBuffer.length,
              visualEnd: visualBuffer.length,
              type: MarkdownTokenType.syntaxMarker,
              style: styles.highlight,
              visualText: '',
              isHiddenSyntax: true,
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
        final isWordFlanked = (char == '_' && i > 0 && _isAlphanumeric(text[i - 1]));
        if (!isWordFlanked) {
          final closeIndex = _findClosingDelimiter(text, delimiter, i + 1);
          if (closeIndex != -1) {
            final inner = text.substring(i + 1, closeIndex);
            if (inner.isNotEmpty && !inner.startsWith(' ') && !inner.endsWith(' ')) {
              flushPlain(i);

              // Hide opening *
              runs.add(MarkdownVisualRun(
                sourceStart: baseOffset + i,
                sourceEnd: baseOffset + i + 1,
                visualStart: visualBuffer.length,
                visualEnd: visualBuffer.length,
                type: MarkdownTokenType.syntaxMarker,
                style: styles.italic,
                visualText: '',
                isHiddenSyntax: true,
              ));

              final italicStyle = baseStyle.merge(styles.italic);
              _addVisualRun(
                runs: runs,
                visualBuffer: visualBuffer,
                sourceStart: baseOffset + i + 1,
                sourceEnd: baseOffset + closeIndex,
                visualText: inner,
                type: MarkdownTokenType.italic,
                style: italicStyle,
              );

              // Hide closing *
              runs.add(MarkdownVisualRun(
                sourceStart: baseOffset + closeIndex,
                sourceEnd: baseOffset + closeIndex + 1,
                visualStart: visualBuffer.length,
                visualEnd: visualBuffer.length,
                type: MarkdownTokenType.syntaxMarker,
                style: styles.italic,
                visualText: '',
                isHiddenSyntax: true,
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

  static int _findClosingDelimiter(String text, String delimiter, int startIndex) {
    var searchIndex = startIndex;
    while (searchIndex < text.length) {
      final found = text.indexOf(delimiter, searchIndex);
      if (found == -1) return -1;
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

  static _HeadingMatch? _tryParseHeading(String line) {
    var indent = 0;
    while (indent < line.length && (line[indent] == ' ' || line[indent] == '\t')) {
      indent++;
    }
    var hashes = 0;
    while (indent + hashes < line.length && line[indent + hashes] == '#') {
      hashes++;
    }
    if (hashes < 1 || hashes > 6) return null;
    final afterHashes = indent + hashes;
    if (afterHashes == line.length) {
      return _HeadingMatch(indentLength: indent, hashCount: hashes, separatorLength: 0);
    }
    var sep = 0;
    while (afterHashes + sep < line.length &&
        (line[afterHashes + sep] == ' ' || line[afterHashes + sep] == '\t')) {
      sep++;
    }
    if (sep == 0) return null;
    return _HeadingMatch(indentLength: indent, hashCount: hashes, separatorLength: sep);
  }

  static List<_LineInfo> _splitLinesWithOffsets(String text) {
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

class _HeadingMatch {
  final int indentLength;
  final int hashCount;
  final int separatorLength;

  const _HeadingMatch({
    required this.indentLength,
    required this.hashCount,
    required this.separatorLength,
  });
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
