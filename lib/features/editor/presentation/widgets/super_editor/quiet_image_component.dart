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
