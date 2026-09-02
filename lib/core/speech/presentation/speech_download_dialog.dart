import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../application/speech_provider.dart';

class SpeechDownloadDialog extends ConsumerWidget {
  const SpeechDownloadDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const SpeechDownloadDialog(),
    );
  }

  String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final status = ref.watch(speechModelStatusProvider);
    final manager = ref.read(speechModelManagerProvider);
    final descriptor = manager.descriptor;

    final isDownloading = status.isDownloading;
    final isInstalled = status.isInstalled;
    final hasError = status.hasError;

    // Automatically close dialog with success once installed
    if (isInstalled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(true);
        }
      });
    }

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Offline Speech Recognition',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Quiet Paper can transcribe your voice entirely on this device.\n\n'
                'Download the English speech model once (${_formatMb(descriptor.sizeBytes)}). '
                'Afterward, transcription works completely offline.',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.mic_none_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            descriptor.name,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDownloading
                                ? '${_formatMb(status.downloadedBytes)} of ${_formatMb(status.totalBytes > 0 ? status.totalBytes : descriptor.sizeBytes)} (${(status.progress * 100).toInt()}%)'
                                : _formatMb(descriptor.sizeBytes),
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isDownloading) ...[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: AppRadii.borderSm,
                  child: LinearProgressIndicator(
                    value: status.progress > 0 ? status.progress : null,
                    backgroundColor: colors.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    minHeight: 4,
                  ),
                ),
              ],
              if (hasError && status.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  status.errorMessage!,
                  style: AppTypography.caption.copyWith(
                    color: colors.error,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  QuietButton(
                    label: 'Cancel',
                    variant: QuietButtonVariant.tonal,
                    onPressed: () {
                      if (isDownloading) {
                        manager.cancelDownload();
                      }
                      Navigator.of(context).pop(false);
                    },
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (!isDownloading)
                    QuietButton(
                      label: hasError ? 'Retry Download' : 'Download',
                      variant: QuietButtonVariant.primary,
                      onPressed: () {
                        manager.downloadModel();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
