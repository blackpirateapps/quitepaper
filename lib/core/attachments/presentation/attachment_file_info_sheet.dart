import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../database/app_database.dart';
import '../attachment_icon_resolver.dart';
import '../attachment_type_resolver.dart';
import '../text/attachment_text_decoder.dart';
import '../text/attachment_text_detector.dart';

/// Modal bottom sheet displaying detailed file and encoding metadata for an attachment.
class AttachmentFileInfoSheet extends StatelessWidget {
  const AttachmentFileInfoSheet({
    super.key,
    required this.entity,
    this.decodedResult,
    this.format = TextAttachmentFormat.plainText,
  });

  final AttachmentEntity entity;
  final DecodedTextResult? decodedResult;
  final TextAttachmentFormat format;

  static Future<void> show(
    BuildContext context, {
    required AttachmentEntity entity,
    DecodedTextResult? decodedResult,
    TextAttachmentFormat format = TextAttachmentFormat.plainText,
  }) {
    final colors = context.appColors;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) => AttachmentFileInfoSheet(
        entity: entity,
        decodedResult: decodedResult,
        format: format,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final fileName = entity.fileName;
    final mimeType = entity.mimeType;
    final typeLabel = AttachmentTypeResolver.resolveDisplayName(mimeType: mimeType, fileName: fileName);
    final sizeLabel = _formatBytes(entity.byteSize);
    final icon = AttachmentIconResolver.resolveIcon(mimeType: mimeType, fileName: fileName, kind: entity.kind);
    final iconTint = AttachmentIconResolver.resolveIconTint(mimeType: mimeType, fileName: fileName, colors: colors, kind: entity.kind);

    final createdAtStr = DateFormat('MMM d, yyyy · h:mm a').format(entity.createdAt.toLocal());
    final shaPrefix = entity.sha256.isNotEmpty
        ? (entity.sha256.length > 16 ? '${entity.sha256.substring(0, 16)}…' : entity.sha256)
        : 'Not computed';

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconTint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: iconTint, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          style: AppTypography.headline.copyWith(color: colors.textPrimary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$typeLabel • $sizeLabel',
                          style: AppTypography.caption.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),
              Divider(color: colors.divider, height: 1),
              const SizedBox(height: AppSpacing.sm),

              // 2. Metadata Rows
              _MetadataRow(label: 'File Name', value: fileName),
              _MetadataRow(label: 'Format', value: typeLabel),
              _MetadataRow(label: 'File Size', value: sizeLabel),
              if (decodedResult != null) ...[
                _MetadataRow(label: 'Encoding', value: decodedResult!.encoding.label),
                _MetadataRow(label: 'Line Count', value: '${decodedResult!.lineCount}'),
                _MetadataRow(label: 'Line Endings', value: decodedResult!.lineEnding.label),
                if (decodedResult!.isTruncated)
                  const _MetadataRow(label: 'Preview', value: 'Bounded / Partial View'),
              ],
              _MetadataRow(label: 'Added', value: createdAtStr),
              _MetadataRow(label: 'SHA-256', value: shaPrefix),
              _MetadataRow(
                label: 'Encryption',
                value: 'XChaCha20-Poly1305 (QPA1)',
              ),
              _MetadataRow(
                label: 'Sync Status',
                value: entity.uploadState == 'synced'
                    ? 'Synced (Encrypted)'
                    : (entity.uploadState == 'uploading' ? 'Uploading…' : 'Local Only'),
              ),

              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: colors.textTertiary),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
