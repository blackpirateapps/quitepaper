import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_asset_image_view.dart';
import 'package:quitepaper/core/documents/presentation/quiet_document_card.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';
import 'package:super_editor/super_editor.dart';

import 'math/quiet_math_parser.dart';

// Preserve code verbatim, including incomplete fences while the user types.
int? _codeFenceLineCount(List<String> lines, int start) {
  final opening = RegExp(r'^ {0,3}(`{3,}|~{3,})').firstMatch(lines[start]);
  if (opening == null) return null;
  final marker = opening.group(1)!;
  final closing = RegExp(
    '^ {0,3}${RegExp.escape(marker[0])}{${marker.length},}\\s*\$',
  );
  for (var i = start + 1; i < lines.length; i++) {
    if (closing.hasMatch(lines[i])) return i - start + 1;
  }
  return lines.length - start;
}

/// Custom [ComponentBuilder] for SuperEditor that renders both encrypted
/// local note attachments (`attachment:<UUID>`, `qp://asset/<UUID>`) and
/// web images using Quiet Paper's [QuietAssetImageView] and [QuietDocumentCard].
class QuietImageComponentBuilder implements ComponentBuilder {
  const QuietImageComponentBuilder({this.noteId});

  final String? noteId;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ImageNode) {
      return null;
    }

    return ImageComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      imageUrl: node.imageUrl,
      expectedSize: node.expectedBitmapSize,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ImageComponentViewModel) {
      return null;
    }

    return ImageComponent(
      componentKey: componentContext.componentKey,
      imageUrl: componentViewModel.imageUrl,
      expectedSize: componentViewModel.expectedSize,
      selection:
          componentViewModel.selection?.nodeSelection
              as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      opacity: componentViewModel.opacity,
      imageBuilder: (context, imageUrl) {
        return _buildQuietImage(context, imageUrl, noteId);
      },
    );
  }

  static Widget _buildQuietImage(
    BuildContext context,
    String imageUrl,
    String? noteId,
  ) {
    var uriString = imageUrl.trim();
    if (uriString.startsWith('<') && uriString.endsWith('>')) {
      uriString = uriString.substring(1, uriString.length - 1).trim();
    }

    final qpUri = QuietPaperUri.tryParse(uriString);
    if (qpUri != null && qpUri.isDocument) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: QuietDocumentCard(
          documentId: qpUri.resourceId,
          title: 'Document',
          uriString: uriString,
        ),
      );
    }

    if (qpUri != null && qpUri.isAsset) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: QuietAssetImageView(assetId: qpUri.resourceId, noteId: noteId),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: QuietAssetImageView(url: uriString, noteId: noteId),
    );
  }
}

/// Normalizes inline formatting delimiter spacing so whitespace is not flanked
/// by emphasis markers (e.g. `**word **` -> `**word** `, `** word**` -> ` **word**`).
/// CommonMark specifications mandate that opening delimiters cannot be followed
/// by whitespace and closing delimiters cannot be preceded by whitespace.
String normalizeInlineMarkdownSpacing(String markdown) {
  if (markdown.isEmpty) return markdown;
  final lines = markdown.split('\n');
  final result = <String>[];
  for (var index = 0; index < lines.length; index++) {
    final protectedCount =
        _codeFenceLineCount(lines, index) ??
        QuietMathParser.blockLineCount(
          (offset) =>
              index + offset < lines.length ? lines[index + offset] : null,
        );
    if (protectedCount != null) {
      result.addAll(lines.sublist(index, index + protectedCount));
      index += protectedCount - 1;
      continue;
    }

    // Protect inline code backticks: odd parts are inside inline code
    final parts = lines[index].split('`');
    for (int i = 0; i < parts.length; i += 2) {
      final text = parts[i];
      final buffer = StringBuffer();
      var cursor = 0;
      for (final match in QuietMathParser.findInlineMathMatches(text)) {
        buffer.write(
          _normalizeInlineSegment(text.substring(cursor, match.start)),
        );
        buffer.write(match.rawMatch);
        cursor = match.end;
      }
      buffer.write(_normalizeInlineSegment(text.substring(cursor)));
      parts[i] = buffer.toString();
    }
    result.add(parts.join('`'));
  }

  return result.join('\n');
}

String _normalizeInlineSegment(String text) {
  var s = text;
  // Bold: ** or __
  s = s.replaceAllMapped(
    RegExp(r'(\*\*|__)\s+([^\s*_\n].*?)\1'),
    (m) => ' ${m[1]}${m[2]}${m[1]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(\*\*|__)(.*?[^\s*_\n])\s+\1'),
    (m) => '${m[1]}${m[2]}${m[1]} ',
  );

  // Strikethrough: ~~
  s = s.replaceAllMapped(
    RegExp(r'(~~)\s+([^\s~\n].*?)\1'),
    (m) => ' ${m[1]}${m[2]}${m[1]}',
  );
  s = s.replaceAllMapped(
    RegExp(r'(~~)(.*?[^\s~\n])\s+\1'),
    (m) => '${m[1]}${m[2]}${m[1]} ',
  );

  // Italic: * (single asterisk, not bold **)
  s = s.replaceAllMapped(
    RegExp(r'(?<!\*)\*\s+([^\s*\n].*?)(?<!\*)\*(?!\*)'),
    (m) => ' *${m[1]}*',
  );
  s = s.replaceAllMapped(
    RegExp(r'(?<!\*)\*(.*?)(?<=[^\s*\n])\s+\*(?!\*)'),
    (m) => '*${m[1]}* ',
  );

  return s;
}

/// Normalizes markdown text for SuperEditor document deserialization.
///
/// Ensures standalone image blocks (`![alt](url)`) and table blocks have blank lines
/// (`\n\n`) before and after them. This prevents Markdown / CommonMark parsers
/// from merging them into surrounding text paragraphs and subsequently dropping them.
String normalizeMarkdownForSuperEditor(String markdown) {
  if (markdown.isEmpty) return markdown;

  final inlineNormalized = normalizeInlineMarkdownSpacing(markdown);

  final lines = const LineSplitter().convert(inlineNormalized);
  final buffer = StringBuffer();
  final imageLineRegex = RegExp(r'^\s*!\[.*?\]\(.*?\)\s*$');
  final tableLineRegex = RegExp(r'^\s*\|.*?\|\s*$');
  final listOrTaskLineRegex = RegExp(r'^\s*([-*+](\s+\[[ xX]\]|\s+)|\d+\.\s+)');
  // A line that is exactly a single `[name](qp://document|asset/...)` link must
  // be isolated as its own block so it deserializes into a standalone paragraph
  // (which is then promoted to an embedded attachment card).
  final qpLinkLineRegex = RegExp(
    r'^\s*\[[^\]]*\]\(\s*qp://(?:document|asset)/[^)]*\)\s*$',
  );
  // A standalone web link line `[Title](https?://...)`
  final webLinkLineRegex = RegExp(r'^\s*\[[^\]]*\]\(\s*https?://[^)]*\)\s*$');
  for (int i = 0; i < lines.length; i++) {
    final codeCount = _codeFenceLineCount(lines, i);
    if (codeCount != null) {
      buffer.writeln(lines.sublist(i, i + codeCount).join('\n'));
      i += codeCount - 1;
      continue;
    }
    // Protect inline delimiters only outside code and display math.
    final line = lines[i].replaceAllMapped(
      RegExp(r'(?<!\\)\\{1,2}\(([\s\S]+?)(?<!\\)\\{1,2}\)'),
      (m) => r'\\(' + m.group(1)! + r'\\)',
    );
    final trimmed = line.trim();
    final isImage = imageLineRegex.hasMatch(line);
    final isTable = tableLineRegex.hasMatch(line);
    final isQpLink = qpLinkLineRegex.hasMatch(line);
    final isWebLink = webLinkLineRegex.hasMatch(line);
    final isLinkPreview =
        isLinkPreviewComment(trimmed) ||
        trimmed.startsWith(r'\<!-- qp-link-preview:');
    final isListOrTask = listOrTaskLineRegex.hasMatch(line);
    final mathCount = QuietMathParser.blockLineCount(
      (offset) => i + offset < lines.length ? lines[i + offset] : null,
    );

    // Isolate complete formulas while preserving every byte inside them.
    if (mathCount != null) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
        if (!buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('\n');
      }

      buffer.write(lines.sublist(i, i + mathCount).join('\n'));
      buffer.write('\n\n');
      i += mathCount - 1;
      continue;
    }

    if (isImage || isQpLink || isWebLink) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
        if (!buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('\n');
      }
      buffer.write(trimmed);
      buffer.write('\n\n');
      continue;
    }

    if (isLinkPreview) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
        if (!buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('\n');
      }
      // Escape the leading '<' with a backslash so CommonMark does not strip it
      // as a raw HTML block or comment, parsing it into a paragraph node instead.
      final escaped = trimmed.startsWith(r'\<!--') ? trimmed : '\\$trimmed';
      buffer.write(escaped);
      buffer.write('\n\n');
      continue;
    }

    buffer.write(line);
    if (isTable &&
        i + 1 < lines.length &&
        !tableLineRegex.hasMatch(lines[i + 1]) &&
        lines[i + 1].trim().isNotEmpty) {
      buffer.write('\n\n');
      continue;
    }

    // In CommonMark, a list or task item followed immediately by a non-list line
    // without a blank line is treated as a lazy continuation of the list item.
    // Ensure a blank line (\n\n) to cleanly terminate the list and preserve
    // following paragraphs as separate nodes.
    if (isListOrTask &&
        i + 1 < lines.length &&
        lines[i + 1].trim().isNotEmpty &&
        !listOrTaskLineRegex.hasMatch(lines[i + 1])) {
      buffer.write('\n\n');
      continue;
    }

    if (i < lines.length - 1) {
      buffer.write('\n');
    }
  }

  // Collapse layout separators without deleting blank lines inside formulas or code.
  final outputLines = buffer.toString().split('\n');
  final result = <String>[];
  for (var index = 0; index < outputLines.length; index++) {
    final count =
        _codeFenceLineCount(outputLines, index) ??
        QuietMathParser.blockLineCount(
          (offset) => index + offset < outputLines.length
              ? outputLines[index + offset]
              : null,
        );
    if (count != null) {
      result.addAll(outputLines.sublist(index, index + count));
      index += count - 1;
    } else if (outputLines[index].isNotEmpty ||
        result.isEmpty ||
        result.last.isNotEmpty) {
      result.add(outputLines[index]);
    }
  }
  return result.join('\n');
}

/// A specialized [DocumentNodeMarkdownSerializer] that serializes [ImageNode]
/// to Markdown and guarantees a blank line before following nodes.
///
/// In standard SuperEditor serialization, [ImageNodeSerializer] does not add
/// a trailing newline, causing subsequent nodes to be separated by only a single
/// newline (`\n`). In CommonMark, an image line followed by a single newline and text
/// is treated as a paragraph of text containing an image, which [deserializeMarkdownToDocument]
/// drops because it only parses pure block images.
class QuietImageNodeSerializer
    extends NodeTypedDocumentNodeMarkdownSerializer<ImageNode> {
  const QuietImageNodeSerializer({this.useSizeNotation = false});

  final bool useSizeNotation;

  @override
  String doSerialization(
    Document document,
    ImageNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null) {
      if (selection is! UpstreamDownstreamNodeSelection) {
        return '';
      }
      if (selection.isCollapsed) {
        return '';
      }
    }

    final buffer = StringBuffer();
    final hasSize =
        node.expectedBitmapSize?.width != null ||
        node.expectedBitmapSize?.height != null;
    if (!useSizeNotation || !hasSize) {
      buffer.write('![${node.altText}](${node.imageUrl})');
    } else {
      buffer.write('![${node.altText}](${node.imageUrl}');
      buffer.write(' =');
      if (node.expectedBitmapSize?.width != null) {
        buffer.write(node.expectedBitmapSize!.width!.toInt());
      }
      buffer.write('x');
      if (node.expectedBitmapSize?.height != null) {
        buffer.write(node.expectedBitmapSize!.height!.toInt());
      }
      buffer.write(')');
    }

    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }

    return buffer.toString();
  }
}
