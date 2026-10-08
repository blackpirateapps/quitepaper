import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_asset_image_view.dart';
import 'package:quitepaper/core/documents/presentation/quiet_document_card.dart';
import 'package:quitepaper/core/uri/quiet_paper_uri.dart';
import 'package:super_editor/super_editor.dart';

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
      selection: componentViewModel.selection?.nodeSelection
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
        child: QuietAssetImageView(
          assetId: qpUri.resourceId,
          noteId: noteId,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: QuietAssetImageView(
        url: uriString,
        noteId: noteId,
      ),
    );
  }
}

/// Normalizes markdown text for SuperEditor document deserialization.
///
/// Ensures standalone image blocks (`![alt](url)`) and table blocks have blank lines
/// (`\n\n`) before and after them. This prevents Markdown / CommonMark parsers
/// from merging them into surrounding text paragraphs and subsequently dropping them.
String normalizeMarkdownForSuperEditor(String markdown) {
  if (markdown.isEmpty) return markdown;

  final lines = const LineSplitter().convert(markdown);
  final buffer = StringBuffer();
  final imageLineRegex = RegExp(r'^\s*!\[.*?\]\(.*?\)\s*$');
  final tableLineRegex = RegExp(r'^\s*\|.*?\|\s*$');

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    final isImage = imageLineRegex.hasMatch(line);
    final isTable = tableLineRegex.hasMatch(line);

    if (isImage) {
      if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
        if (!buffer.toString().endsWith('\n')) {
          buffer.write('\n');
        }
        buffer.write('\n');
      }
      buffer.write(line.trim());
      buffer.write('\n\n');
      continue;
    }

    buffer.write(line);
    if (isTable && i + 1 < lines.length && !tableLineRegex.hasMatch(lines[i + 1]) && lines[i + 1].trim().isNotEmpty) {
      buffer.write('\n\n');
      continue;
    }

    if (i < lines.length - 1) {
      buffer.write('\n');
    }
  }

  return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n');
}

/// A specialized [DocumentNodeMarkdownSerializer] that serializes [ImageNode]
/// to Markdown and guarantees a blank line before following nodes.
///
/// In standard SuperEditor serialization, [ImageNodeSerializer] does not add
/// a trailing newline, causing subsequent nodes to be separated by only a single
/// newline (`\n`). In CommonMark, an image line followed by a single newline and text
/// is treated as a paragraph of text containing an image, which [deserializeMarkdownToDocument]
/// drops because it only parses pure block images.
class QuietImageNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<ImageNode> {
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
    final hasSize = node.expectedBitmapSize?.width != null || node.expectedBitmapSize?.height != null;
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

