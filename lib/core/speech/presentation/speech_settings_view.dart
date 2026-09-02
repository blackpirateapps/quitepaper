import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../application/speech_provider.dart';
import '../domain/speech_model.dart';
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SpeechModelDescriptor descriptor,
  ) async {
    final colors = context.appColors;
    final manager = ref.read(speechModelManagerFamily(descriptor));
    final service = ref.read(speechRecognitionServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          'Delete ${descriptor.name}?',
          style: AppTypography.headline.copyWith(color: colors.textPrimary),
        ),
        content: Text(
          'This will delete the local voice model (${_formatMb(descriptor.sizeBytes)}). You will need to download it again to use it for offline speech recognition.\n\n'
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
      final active = ref.read(selectedSpeechModelProvider);
      if (active.id == descriptor.id) {
        await service.releaseEngine();
      }
      await manager.deleteModel();
    }
  }

  Widget _buildModelCard({
    required BuildContext context,
    required WidgetRef ref,
    required AppColors colors,
    required SpeechModelDescriptor descriptor,
    required bool isSelected,
  }) {
    final manager = ref.watch(speechModelManagerFamily(descriptor));
    final status = manager.status;

    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () async {
        if (!status.isInstalled) {
          final installed = await SpeechDownloadDialog.show(
            context,
            modelDescriptor: descriptor,
          );
          if (installed == true) {
            await ref.read(selectedSpeechModelProvider.notifier).setModel(descriptor);
          }
        } else {
          await ref.read(selectedSpeechModelProvider.notifier).setModel(descriptor);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Radio indicator
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.accent : colors.divider,
                      width: isSelected ? 5.5 : 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              descriptor.name,
                              style: AppTypography.bodyMedium.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.15),
                                borderRadius: AppRadii.borderSm,
                              ),
                              child: Text(
                                'ACTIVE',
                                style: AppTypography.caption.copyWith(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descriptor.subtitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.isInstalled
                            ? 'Installed • ${_formatMb(descriptor.sizeBytes)}'
                            : status.isDownloading
                                ? 'Downloading • ${(status.progress * 100).toInt()}%'
                                : 'Not downloaded • ${_formatMb(descriptor.sizeBytes)}',
                        style: AppTypography.caption.copyWith(
                          color: status.isInstalled
                              ? colors.accent
                              : status.isDownloading
                                  ? colors.accent
                                  : colors.textTertiary,
                          fontWeight: status.isInstalled || status.isDownloading
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status.isInstalled)
                  TextButton(
                    onPressed: () => _confirmDelete(context, ref, descriptor),
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
                    onPressed: () async {
                      final installed = await SpeechDownloadDialog.show(
                        context,
                        modelDescriptor: descriptor,
                      );
                      if (installed == true) {
                        await ref.read(selectedSpeechModelProvider.notifier).setModel(descriptor);
                      }
                    },
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
            if (status.isDownloading) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: AppRadii.borderSm,
                child: LinearProgressIndicator(
                  value: status.progress > 0 ? status.progress : null,
                  backgroundColor: colors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final selectedModel = ref.watch(selectedSpeechModelProvider);

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

          // ENGLISH MODELS SECTION
          Padding(
            padding: const EdgeInsets.only(left: 4, top: AppSpacing.sm, bottom: AppSpacing.xs),
            child: Text(
              'ENGLISH VOICE MODELS',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                fontSize: 11.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: Column(
              children: [
                _buildModelCard(
                  context: context,
                  ref: ref,
                  colors: colors,
                  descriptor: SpeechModels.english39,
                  isSelected: selectedModel.id == SpeechModels.english39.id,
                ),
                Divider(height: 1, thickness: 0.8, color: colors.divider, indent: 44),
                _buildModelCard(
                  context: context,
                  ref: ref,
                  colors: colors,
                  descriptor: SpeechModels.english74,
                  isSelected: selectedModel.id == SpeechModels.english74.id,
                ),
                Divider(height: 1, thickness: 0.8, color: colors.divider, indent: 44),
                _buildModelCard(
                  context: context,
                  ref: ref,
                  colors: colors,
                  descriptor: SpeechModels.english244,
                  isSelected: selectedModel.id == SpeechModels.english244.id,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // MULTILINGUAL MODEL SECTION
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
            child: Text(
              'MULTILINGUAL VOICE MODEL',
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
              'Auto-detects spoken languages (English, Spanish, French, German, Hindi, Japanese, and 90+ more) and writes in that language.',
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: colors.divider, width: 0.8),
            ),
            child: _buildModelCard(
              context: context,
              ref: ref,
              colors: colors,
              descriptor: SpeechModels.multilingual244,
              isSelected: selectedModel.id == SpeechModels.multilingual244.id,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
