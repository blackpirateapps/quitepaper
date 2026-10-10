import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../core/attachments/presentation/quiet_attachment_card.dart';
import '../../../../core/documents/presentation/quiet_document_card.dart';
import '../../../../core/uri/quiet_paper_uri.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/rich_block.dart';
import '../../application/rich_document_controller.dart';

/// Semantic attachment card block in Quiet Paper's Visual editor surface.
///
/// Renders a document ([QuietDocumentCard]) or generic file ([QuietAttachmentCard])
/// card whose own tap gesture opens the resource, with a small remove control that
/// deletes the block from the document (mirroring [RichImageBlock]).
class RichAttachmentBlock extends StatelessWidget {
  const RichAttachmentBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    this.readOnly = false,
  });

  final AttachmentBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final uri = QuietPaperUri.tryParse(block.uri);
    final resourceId = uri?.resourceId ?? '';

    final Widget card;
    if (block.kind == AttachmentBlockKind.document) {
      card = QuietDocumentCard(
        documentId: resourceId,
        title: block.name.isNotEmpty ? block.name : 'Scanned Document',
        uriString: block.uri,
      );
    } else {
      card = QuietAttachmentCard(
        attachmentId: resourceId,
        title: block.name.isNotEmpty ? block.name : 'Attachment',
        uriString: block.uri,
      );
    }

    if (readOnly) {
      return card;
    }

    // Card tap opens the resource; the small overlay control removes the block.
    return Stack(
      children: [
        card,
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: AppRadii.borderSm,
              border: Border.all(color: colors.divider),
            ),
            child: QuietIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Remove Attachment',
              size: 16,
              padding: const EdgeInsets.all(6.0),
              onPressed: () {
                controller.convertBlockToParagraph(blockIndex);
              },
            ),
          ),
        ),
      ],
    );
  }
}
