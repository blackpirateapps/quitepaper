import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/attachments/attachment_provider.dart';
import '../../../../core/uri/quiet_paper_uri.dart';
import '../../../../core/utils/link_launcher_helper.dart';
import '../../../../core/web_clipper/link_preview_baker.dart';
import '../../../settings/application/settings_provider.dart';
import '../../application/rich_document_controller.dart';
import '../../domain/rich_block.dart';
import '../../domain/rich_inline.dart';
import '../../domain/text_attributes.dart';
import 'link_preview_card.dart';

/// WYSIWYG (Visual editor) wrapper that renders a [LinkPreviewBlock] either as
/// a rich [LinkPreviewCard] (when the Smart Web Links toggle is on) or as a
/// plain inline link (when it is off). Modelled on [RichAttachmentBlock]: the
/// card owns its tap gesture and exposes refresh/remove affordances.
class RichLinkPreviewBlock extends ConsumerWidget {
  const RichLinkPreviewBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    this.readOnly = false,
    this.noteId,
  });

  final LinkPreviewBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;
  final String? noteId;

  /// Replaces the block at [blockIndex] with [newBlock], preserving document
  /// order. The authoritative in-memory document is updated directly (no
  /// Markdown round-trip), mirroring the other block affordances.
  void _replaceBlock(RichBlock newBlock) {
    final blocks = List<RichBlock>.from(controller.document.blocks);
    if (blockIndex < 0 || blockIndex >= blocks.length) return;
    blocks[blockIndex] = newBlock;
    controller.setDocument(controller.document.copyWith(blocks: blocks));
  }

  /// Deletes (tombstones) the baked thumbnail asset referenced by [assetUri]
  /// (a full `qp://asset/<id>` reference), if any.
  Future<void> _tombstoneThumbnail(WidgetRef ref, String? assetUri) async {
    if (assetUri == null || assetUri.trim().isEmpty) return;
    final id = QuietPaperUri.tryParse(assetUri)?.resourceId ??
        (assetUri.startsWith('qp://asset/')
            ? assetUri.substring('qp://asset/'.length)
            : null);
    if (id == null || id.isEmpty) return;
    try {
      await ref.read(attachmentServiceProvider).deleteAttachment(id);
    } catch (_) {
      // Best-effort cleanup; a failed tombstone must not block the edit.
    }
  }

  /// Demotes the card back to a plain inline-link paragraph (preserving the
  /// link target), then tombstones the baked thumbnail.
  Future<void> _handleRemove(WidgetRef ref) async {
    final paragraph = ParagraphBlock(
      id: block.id,
      spans: [
        RichInlineSpan(
          text: block.plainText,
          attributes: TextAttributes(
            linkUrl: block.url,
            linkTitle: block.title.trim().isNotEmpty ? block.title.trim() : null,
          ),
        ),
      ],
    );
    _replaceBlock(paragraph);
    await _tombstoneThumbnail(ref, block.thumbnailAssetId);
  }

  /// Re-bakes the preview for [block] and swaps in the fresh metadata,
  /// tombstoning the superseded thumbnail.
  Future<void> _handleRefresh(WidgetRef ref) async {
    final baker = ref.read(linkPreviewBakerProvider);
    final fresh = await baker.bakeUrl(block.url, noteId: noteId);
    if (fresh == null) return;
    final oldThumb = block.thumbnailAssetId;
    if (oldThumb != null && oldThumb != fresh.thumbnailAssetId) {
      await _tombstoneThumbnail(ref, oldThumb);
    }
    // Preserve the block id so the surface keeps a stable widget key.
    _replaceBlock(fresh.copyWithId(block.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final smartWebLinks = ref.watch(smartWebLinksProvider);

    // Toggle OFF: render a plain inline link instead of the card. The
    // underlying block is preserved and still serializes.
    if (!smartWebLinks) {
      return _PlainInlineLink(url: block.url, label: block.plainText);
    }

    return LinkPreviewCard(
      block: block,
      readOnly: readOnly,
      onRemove: readOnly ? null : () => _handleRemove(ref),
      onRefresh: readOnly ? null : () => _handleRefresh(ref),
    );
  }
}

/// A calm, single-line inline link used when Smart Web Links are disabled.
class _PlainInlineLink extends StatelessWidget {
  const _PlainInlineLink({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => LinkLauncherHelper.handleLinkTap(context, url),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Text(
            label.isNotEmpty ? label : url,
            style: AppTypography.bodySmall.copyWith(
              color: colors.accent,
              decoration: TextDecoration.underline,
              decorationColor: colors.accent.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}
