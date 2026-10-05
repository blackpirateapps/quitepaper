import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../settings/domain/default_settings.dart';
import '../../../tags/domain/phosphor_icons.dart';

/// User decision for an image compression prompt.
enum ImageCompressionDialogChoice {
  compress,
  keepOriginal,
}

/// Returned payload from [ImageCompressionDialog].
@immutable
class ImageCompressionDecision {
  const ImageCompressionDecision({
    required this.choice,
    required this.rememberChoice,
  });

  final ImageCompressionDialogChoice choice;
  final bool rememberChoice;
}

/// Clean editorial dialog shown when an image larger than 500 KB is imported.
class ImageCompressionDialog extends StatefulWidget {
  const ImageCompressionDialog({
    super.key,
    required this.fileName,
    required this.byteSize,
    required this.width,
    required this.height,
    required this.preset,
  });

  final String fileName;
  final int byteSize;
  final int width;
  final int height;
  final ImageCompressionPreset preset;

  static Future<ImageCompressionDecision?> show(
    BuildContext context, {
    required String fileName,
    required int byteSize,
    required int width,
    required int height,
    required ImageCompressionPreset preset,
  }) {
    return showDialog<ImageCompressionDecision>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ImageCompressionDialog(
        fileName: fileName,
        byteSize: byteSize,
        width: width,
        height: height,
        preset: preset,
      ),
    );
  }

  @override
  State<ImageCompressionDialog> createState() => _ImageCompressionDialogState();
}

class _ImageCompressionDialogState extends State<ImageCompressionDialog> {
  ImageCompressionDialogChoice _selectedChoice = ImageCompressionDialogChoice.compress;
  bool _rememberChoice = false;

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  void _onConfirm() {
    Navigator.of(context).pop(
      ImageCompressionDecision(
        choice: _selectedChoice,
        rememberChoice: _rememberChoice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final formattedSize = _formatBytes(widget.byteSize);
    final hasDimensions = widget.width > 0 && widget.height > 0;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadii.rLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.md),
      title: Row(
        children: [
          Icon(
            PhosphorIconsRegular.fileImage,
            color: colors.accent,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Optimize Image',
              style: AppTypography.headline.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. File Metadata Preview Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: AppRadii.borderSm,
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasDimensions
                                ? '$formattedSize • ${widget.width} × ${widget.height} px'
                                : formattedSize,
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Compressing images saves device storage and speeds up encrypted sync.',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // 2. Choice 1: Compress & Optimize
              _buildChoiceCard(
                colors: colors,
                choice: ImageCompressionDialogChoice.compress,
                title: 'Compress & Optimize',
                badgeText: 'Recommended',
                subtitle:
                    'Max ${widget.preset.maxDimension}px, ${widget.preset.quality}% quality • Saves ~80% space',
                icon: PhosphorIconsRegular.sparkle,
              ),

              const SizedBox(height: AppSpacing.xs),

              // 3. Choice 2: Keep Original
              _buildChoiceCard(
                colors: colors,
                choice: ImageCompressionDialogChoice.keepOriginal,
                title: 'Keep Original',
                badgeText: null,
                subtitle: 'Full raw resolution ($formattedSize)',
                icon: PhosphorIconsRegular.image,
              ),

              const SizedBox(height: AppSpacing.md),

              // 4. Remember My Choice Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    _rememberChoice = !_rememberChoice;
                  });
                },
                borderRadius: AppRadii.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberChoice,
                          activeColor: colors.accent,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _rememberChoice = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remember my choice',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Can be managed in Settings → Default Settings',
                              style: AppTypography.caption.copyWith(
                                color: colors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        QuietButton(
          label: 'Cancel',
          variant: QuietButtonVariant.tonal,
          onPressed: () => Navigator.of(context).pop(null),
        ),
        QuietButton(
          label: 'Insert Image',
          variant: QuietButtonVariant.primary,
          onPressed: _onConfirm,
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required AppColors colors,
    required ImageCompressionDialogChoice choice,
    required String title,
    required String? badgeText,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedChoice == choice;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedChoice = choice;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.08)
              : colors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider.withValues(alpha: 0.5),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? PhosphorIconsFill.checkCircle
                  : PhosphorIconsRegular.circle,
              color: isSelected ? colors.accent : colors.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: AppTypography.caption.copyWith(
                              color: colors.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
