import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../application/speech_provider.dart';
import 'speech_download_dialog.dart';

class SpeechSettingsView extends ConsumerWidget {
  const SpeechSettingsView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SpeechSettingsView(),
      ),
    );
  }

  String _formatMb(int bytes) {
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final colors = context.appColors;
    final manager = ref.read(speechModelManagerProvider);
    final service = ref.read(speechRecognitionServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          'Delete Speech Model?',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This will delete the local English speech model. You will need to download it again to use offline speech recognition.\n\n'
          'Your notes, attachments, and encryption keys will not be affected.',
          style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
        ),
        actions: [
          QuietButton(
            label: 'Cancel',
            variant: QuietButtonVariant.tonal,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          QuietButton(
            label: 'Delete',
            variant: QuietButtonVariant.destructive,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.releaseEngine();
      await manager.deleteModel();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final status = ref.watch(speechModelStatusProvider);
    final manager = ref.watch(speechModelManagerProvider);
    final descriptor = manager.descriptor;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Speech Recognition',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
            child: Text(
              'OFFLINE TRANSCRIPTION',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 11.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.md),
            child: Text(
              'Quiet Paper transcribes your voice entirely on this device with zero network dependency.',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          // Grouped Container
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: AppRadii.borderSm,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.mic_rounded,
                          color: status.isInstalled
                              ? colors.accent
                              : colors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              descriptor.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status.isInstalled
                                  ? 'Installed • ${_formatMb(descriptor.sizeBytes)}'
                                  : status.isDownloading
                                      ? 'Downloading • ${(status.progress * 100).toInt()}%'
                                      : 'Not downloaded • ${_formatMb(descriptor.sizeBytes)}',
                              style: AppTypography.caption.copyWith(
                                color: status.isInstalled
                                    ? colors.accent
                                    : colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (status.isInstalled)
                        TextButton(
                          onPressed: () => _confirmDelete(context, ref),
                          child: Text(
                            'Delete',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else if (!status.isDownloading)
                        TextButton(
                          onPressed: () => SpeechDownloadDialog.show(context),
                          child: Text(
                            'Download',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
