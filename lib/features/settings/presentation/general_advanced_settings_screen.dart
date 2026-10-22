import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/maintenance/maintenance_models.dart';
import 'package:quitepaper/core/ocr/ollama_ocr_settings.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/application/sample_notes.dart';
import '../application/settings_provider.dart';
import 'widgets/maintenance_progress_sheet.dart';
import 'widgets/settings_shared_widgets.dart';

/// Advanced system settings for maintenance, OCR, sample notes, and debugging.
class GeneralAdvancedSettingsScreen extends ConsumerWidget {
  const GeneralAdvancedSettingsScreen({super.key});

  Future<void> _handleDownloadAllAttachments(BuildContext context) async {
    await MaintenanceProgressSheet.show(
      context,
      taskType: MaintenanceTaskType.downloadAttachments,
    );
  }

  Future<void> _handleRerunOcrForAll(BuildContext context, WidgetRef ref) async {
    final keyManager = ref.read(keyManagerProvider);
    if (!keyManager.isUnlocked) {
      final colors = context.appColors;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Encryption Locked',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Quiet Paper encryption keys are locked. Please unlock your notebook to extract text and re-run OCR on attachments.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    await MaintenanceProgressSheet.show(
      context,
      taskType: MaintenanceTaskType.rerunOcr,
    );
  }

  Future<void> _handleRebuildSearchIndex(BuildContext context) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Rebuild Search Index',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will rebuild full-text search indexes and refresh OCR candidate caches across all notes. Your note contents will not be modified.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Rebuild',
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    await MaintenanceProgressSheet.show(
      context,
      taskType: MaintenanceTaskType.rebuildSearchIndex,
    );
  }

  Future<void> _showEditEndpointDialog(
    BuildContext context,
    WidgetRef ref,
    String currentEndpoint,
  ) async {
    final colors = context.appColors;
    final textController = TextEditingController(text: currentEndpoint);

    final newEndpoint = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Ollama Endpoint URL',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the local or network HTTP address of your Ollama daemon.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                autofocus: true,
                style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'http://127.0.0.1:11434',
                  hintStyle: AppTypography.bodySmall.copyWith(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.surfaceElevated,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final trimmed = textController.text.trim();
                if (trimmed.isNotEmpty) {
                  Navigator.of(dialogContext).pop(trimmed);
                }
              },
              child: Text(
                'Save',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (newEndpoint != null && newEndpoint.isNotEmpty && context.mounted) {
      await ref.read(ollamaOcrSettingsProvider.notifier).setEndpoint(newEndpoint);
    }
  }

  Future<void> _showSelectModelDialog(
    BuildContext context,
    WidgetRef ref,
    String currentModel,
    List<String> availableModels,
  ) async {
    final colors = context.appColors;
    final textController = TextEditingController(text: currentModel);

    final candidateModels = <String>{
      ...availableModels,
      'deepseek-ocr',
      'deepseek-ocr:latest',
      'hf.co/ggml-org/DeepSeek-OCR-GGUF:latest',
      if (currentModel.isNotEmpty) currentModel,
    }.toList();

    String selected = currentModel;

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Select OCR Model',
                style: AppTypography.headline.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select a discovered Ollama vision model or enter a model name below.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: SingleChildScrollView(
                        child: Column(
                          children: candidateModels.map((m) {
                            final isCur = m == selected;
                            return InkWell(
                              onTap: () {
                                setDialogState(() {
                                  selected = m;
                                  textController.text = m;
                                });
                              },
                              borderRadius: BorderRadius.circular(8.0),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isCur
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                      color: isCur
                                          ? colors.accent
                                          : colors.textTertiary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        m,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: isCur
                                              ? colors.accent
                                              : colors.textPrimary,
                                          fontWeight: isCur
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Custom model identifier:',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: textController,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'deepseek-ocr',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: colors.textTertiary,
                        ),
                        filled: true,
                        fillColor: colors.surfaceElevated,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: colors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                          borderSide: BorderSide(color: colors.accent, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          selected = val.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final chosenModel = textController.text.trim();
                    if (chosenModel.isNotEmpty) {
                      Navigator.of(dialogContext).pop(chosenModel);
                    }
                  },
                  child: Text(
                    'Select',
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (chosen != null && chosen.isNotEmpty && context.mounted) {
      await ref.read(ollamaOcrSettingsProvider.notifier).setModel(chosen);
    }
  }

  Widget _buildOllamaOcrSection(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
  ) {
    final ollamaSettings = ref.watch(ollamaOcrSettingsProvider);

    String statusText;
    Color statusColor;
    switch (ollamaSettings.status) {
      case OllamaConnectionStatus.connected:
        statusText = 'Connected • ${ollamaSettings.model}';
        statusColor = const Color(0xFF2E7D32);
        break;
      case OllamaConnectionStatus.checking:
        statusText = 'Checking daemon connection…';
        statusColor = colors.accent;
        break;
      case OllamaConnectionStatus.disconnected:
      case OllamaConnectionStatus.error:
        statusText = 'Ollama offline (${ollamaSettings.endpoint})';
        statusColor = colors.error;
        break;
      case OllamaConnectionStatus.initial:
        statusText = 'Status unverified';
        statusColor = colors.textSecondary;
        break;
    }

    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.memory_rounded,
          title: 'Use Local Ollama OCR',
          subtitle:
              'Transcribe documents and attachments using local DeepSeek-OCR without cloud upload',
          trailing: CupertinoSwitch(
            value: ollamaSettings.enabled,
            activeTrackColor: colors.accent,
            onChanged: (v) =>
                ref.read(ollamaOcrSettingsProvider.notifier).setEnabled(v),
          ),
        ),
        if (ollamaSettings.enabled) ...[
          buildDivider(colors),
          SettingsRow(
            icon: Icons.sensors_rounded,
            iconColor: statusColor,
            title: 'Daemon Status',
            subtitle: statusText,
            trailing: IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: colors.textSecondary,
              tooltip: 'Check Connection',
              onPressed: () async {
                final success = await ref
                    .read(ollamaOcrSettingsProvider.notifier)
                    .checkConnection();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    persist: false,
                    content: Text(
                      success
                          ? 'Connected to Ollama! Found ${ref.read(ollamaOcrSettingsProvider).availableModels.length} models.'
                          : 'Unable to connect to Ollama at ${ollamaSettings.endpoint}.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
          buildDivider(colors),
          SettingsRow(
            icon: Icons.link_rounded,
            title: 'Ollama Endpoint',
            subtitle: ollamaSettings.endpoint,
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: colors.textTertiary,
            ),
            onTap: () =>
                _showEditEndpointDialog(context, ref, ollamaSettings.endpoint),
          ),
          buildDivider(colors),
          SettingsRow(
            icon: Icons.auto_awesome_rounded,
            title: 'OCR Model',
            subtitle: ollamaSettings.model,
            trailing: Icon(
              CupertinoIcons.chevron_forward,
              size: 14,
              color: colors.textTertiary,
            ),
            onTap: () => _showSelectModelDialog(
              context,
              ref,
              ollamaSettings.model,
              ollamaSettings.availableModels,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Advanced',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // ==========================================
                // Section: Maintenance
                // ==========================================
                buildSectionHeader(context, 'Advanced Maintenance'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.cloud_download_outlined,
                      title: 'Download All Attachments',
                      subtitle:
                          'Download all media and documents from cloud for offline access',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleDownloadAllAttachments(context),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.document_scanner_outlined,
                      title: 'Rerun OCR for All Files',
                      subtitle:
                          'Extract text from all local scanned documents and image attachments',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleRerunOcrForAll(context, ref),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.manage_search_rounded,
                      title: 'Rebuild Search Index',
                      subtitle:
                          'Refresh full-text and OCR indexes for notes and attachments',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleRebuildSearchIndex(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Desktop OCR (Ollama)
                // ==========================================
                if (!kIsWeb &&
                    (Platform.isLinux ||
                        Platform.isMacOS ||
                        Platform.isWindows)) ...[
                  buildSectionHeader(context, 'Desktop OCR (Ollama)'),
                  _buildOllamaOcrSection(context, ref, colors),
                  const SizedBox(height: 24),
                ],

                // ==========================================
                // Section: Sample Notes
                // ==========================================
                buildSectionHeader(context, 'Sample Notes'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.auto_stories_outlined,
                      title: 'Load sample notes',
                      subtitle:
                          'Populate example notes demonstrating Markdown, hashtags, and editorial formatting.',
                      onTap: () async {
                        final repository =
                            ref.read(notesRepositoryProvider);
                        await SampleNotes.populateSampleNotes(
                            repository);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sample notes loaded'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Debug
                // ==========================================
                buildSectionHeader(context, 'Debug'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.bug_report_outlined,
                      title: 'Link preview debug info',
                      subtitle:
                          'Show detailed failure diagnostics when link preview fetching fails in the editor.',
                      trailing: CupertinoSwitch(
                        value: ref.watch(linkPreviewDebugProvider),
                        activeTrackColor: colors.accent,
                        onChanged: (v) =>
                            ref.read(linkPreviewDebugProvider.notifier).set(v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
