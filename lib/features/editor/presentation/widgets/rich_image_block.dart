import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/rich_block.dart';
import '../../application/rich_document_controller.dart';

/// Semantic image preview block in Quiet Paper's Visual editor surface.
class RichImageBlock extends StatelessWidget {
  const RichImageBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    this.readOnly = false,
  });

  final ImageBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isLocal = !block.url.startsWith('http://') && !block.url.startsWith('https://');

    Widget imageWidget;
    if (isLocal) {
      final file = File(block.url);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colors),
        );
      } else {
        imageWidget = _buildPlaceholder(colors);
      }
    } else {
      imageWidget = Image.network(
        block.url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(colors),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image surface
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Center(child: imageWidget),
          ),

          // Caption & actions bar
          if (block.alt.isNotEmpty || !readOnly)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (block.alt.isNotEmpty)
                          Text(
                            block.alt,
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        Text(
                          block.url,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (!readOnly)
                    QuietIconButton(
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Remove Image',
                      size: 16,
                      onPressed: () {
                        controller.convertBlockToParagraph(blockIndex);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(AppColors colors) {
    return Container(
      height: 120,
      color: colors.surface,
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 24, color: colors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            block.alt.isNotEmpty ? block.alt : 'Image Attachment',
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
