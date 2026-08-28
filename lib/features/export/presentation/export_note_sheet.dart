import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/presentation/widgets/note_password_dialogs.dart';
import '../application/export_provider.dart';
import '../domain/export_models.dart';

/// Modal bottom sheet for exporting an individual note to multiple formats.
class ExportNoteSheet extends ConsumerStatefulWidget {
  const ExportNoteSheet({
    super.key,
    required this.note,
  });

  final Note note;

  /// Presents the export note sheet modally.
  static Future<void> show(BuildContext context, {required Note note}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportNoteSheet(note: note),
    );
  }

  @override
  ConsumerState<ExportNoteSheet> createState() => _ExportNoteSheetState();
}

class _ExportNoteSheetState extends ConsumerState<ExportNoteSheet> {
  late ExportFormat _selectedFormat;
  late bool _includeMetadata;
  late bool _includeAttachments;
  late bool _includeOcr;
  late AttachmentExportStrategy _attachmentStrategy;
  late NoteLinkStrategy _noteLinkStrategy;

  bool _showAdvanced = false;
  bool _isExporting = false;
  ExportProgressState? _progressState;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(exportPreferencesProvider);
    _selectedFormat = prefs.lastFormat;
    _includeMetadata = prefs.includeMetadata;
    _includeAttachments = prefs.includeAttachments;
    _includeOcr = prefs.includeOcr;
    _attachmentStrategy = prefs.attachmentStrategy;
    _noteLinkStrategy = prefs.noteLinkStrategy;
  }

  Future<void> _handleExport({required bool isShare}) async {
    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _progressState = const ExportProgressState(
        phase: ExportPhase.preparingNote,
        progress: 0.1,
      );
    });

    // If password-protected, prompt password if not yet unlocked
    String? suppliedPassword;
    if (widget.note.isPasswordProtected) {
      final passResult = await PromptPasswordDialog.show(
        context,
        title: 'Unlock Note to Export',
        hint: 'Enter note password',
        actionLabel: 'Export',
      );
      if (passResult == null || passResult.isEmpty) {
        if (mounted) {
          setState(() {
            _isExporting = false;
            _progressState = null;
          });
        }
        return;
      }
      suppliedPassword = passResult;
    }

    try {
      final exportService = ref.read(exportServiceProvider);

      final request = ExportRequest(
        noteId: widget.note.id,
        format: _selectedFormat,
        includeMetadata: _includeMetadata,
        includeAttachments: _includeAttachments,
        attachmentStrategy: _attachmentStrategy,
        includeOcr: _includeOcr,
        ocrStrategy: _includeOcr
            ? (_selectedFormat == ExportFormat.qpnote
                ? OcrExportStrategy.separateFiles
                : OcrExportStrategy.appendToDocument)
            : OcrExportStrategy.none,
        noteLinkStrategy: _noteLinkStrategy,
        shareAfterExport: isShare,
        notePassword: suppliedPassword,
      );

      // Save user preferences
      await ref.read(exportPreferencesProvider.notifier).updatePreferences(
            lastFormat: _selectedFormat,
            includeMetadata: _includeMetadata,
            includeAttachments: _includeAttachments,
            includeOcr: _includeOcr,
            attachmentStrategy: _attachmentStrategy,
            noteLinkStrategy: _noteLinkStrategy,
          );

      if (isShare) {
        final result = await exportService.exportNote(
          request,
          onProgress: (prog) {
            if (mounted) setState(() => _progressState = prog);
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Shared "${result.filename}"'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        final result = await exportService.exportAndSave(
          request,
          onProgress: (prog) {
            if (mounted) setState(() => _progressState = prog);
          },
        );

        if (mounted) {
          if (result != null) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Saved "${result.filename}"'),
                duration: const Duration(seconds: 4),
              ),
            );
          } else {
            // User cancelled file picker
            setState(() {
              _isExporting = false;
              _progressState = null;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExporting = false;
          _progressState = null;
          _errorMessage = e.toString().replaceAll('ExportSecurityException: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header drag handle & title
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.textTertiary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.12),
                        borderRadius: AppRadii.borderMd,
                      ),
                      child: Icon(
                        Icons.ios_share_rounded,
                        color: colors.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Export Note',
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.note.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    QuietIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Format Selection Grid
                Text(
                  'EXPORT FORMAT',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisSpacing: AppSpacing.sm,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.3,
                  children: [
                    _buildFormatTile(
                      format: ExportFormat.markdown,
                      icon: Icons.article_outlined,
                      subtitle: '.md (Portable Markdown)',
                      colors: colors,
                    ),
                    _buildFormatTile(
                      format: ExportFormat.pdf,
                      icon: Icons.picture_as_pdf_outlined,
                      subtitle: '.pdf (Searchable Document)',
                      colors: colors,
                    ),
                    _buildFormatTile(
                      format: ExportFormat.html,
                      icon: Icons.language_rounded,
                      subtitle: '.html (Standalone Webpage)',
                      colors: colors,
                    ),
                    _buildFormatTile(
                      format: ExportFormat.plainText,
                      icon: Icons.text_snippet_outlined,
                      subtitle: '.txt (Clean Plain Text)',
                      colors: colors,
                    ),
                    _buildFormatTile(
                      format: ExportFormat.docx,
                      icon: Icons.description_outlined,
                      subtitle: '.docx (Microsoft Word)',
                      colors: colors,
                    ),
                    _buildFormatTile(
                      format: ExportFormat.qpnote,
                      icon: Icons.inventory_2_outlined,
                      subtitle: '.qpnote (Full Package)',
                      colors: colors,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Advanced Options Expandable
                InkWell(
                  onTap: () {
                    setState(() {
                      _showAdvanced = !_showAdvanced;
                    });
                  },
                  borderRadius: AppRadii.borderMd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadii.borderMd,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Advanced Options',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          _showAdvanced
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showAdvanced) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: AppRadii.borderMd,
                      border: Border.all(color: colors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSwitchRow(
                          title: 'Include metadata',
                          subtitle: 'Embed dates, tags, and notebook attributes',
                          value: _includeMetadata,
                          onChanged: (val) => setState(() => _includeMetadata = val),
                          colors: colors,
                        ),
                        const Divider(height: 16),
                        _buildSwitchRow(
                          title: 'Include attachments',
                          subtitle: 'Embed images and attached documents',
                          value: _includeAttachments,
                          onChanged: (val) => setState(() => _includeAttachments = val),
                          colors: colors,
                        ),
                        const Divider(height: 16),
                        _buildSwitchRow(
                          title: 'Include OCR recognized text',
                          subtitle: 'Include searchable transcripts of scans',
                          value: _includeOcr,
                          onChanged: (val) => setState(() => _includeOcr = val),
                          colors: colors,
                        ),
                      ],
                    ),
                  ),
                ],

                // Error Banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadii.borderMd,
                      border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 18, color: colors.error),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.caption.copyWith(color: colors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Progress Banner during active export
                if (_isExporting && _progressState != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.08),
                      borderRadius: AppRadii.borderMd,
                      border: Border.all(color: colors.accent.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.accent,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              _progressState!.effectiveMessage,
                              style: AppTypography.caption.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _progressState!.progress > 0 ? _progressState!.progress : null,
                          backgroundColor: colors.divider,
                          color: colors.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Action Buttons: Save to File & Share
                Row(
                  children: [
                    Expanded(
                      child: QuietButton(
                        label: 'Save File',
                        icon: Icons.folder_open_rounded,
                        variant: QuietButtonVariant.tonal,
                        isLoading: _isExporting && _progressState?.phase != ExportPhase.sharing,
                        onPressed: _isExporting ? null : () => _handleExport(isShare: false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: QuietButton(
                        label: 'Share',
                        icon: Icons.share_rounded,
                        variant: QuietButtonVariant.primary,
                        isLoading: _isExporting && _progressState?.phase == ExportPhase.sharing,
                        onPressed: _isExporting ? null : () => _handleExport(isShare: true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormatTile({
    required ExportFormat format,
    required IconData icon,
    required String subtitle,
    required AppColors colors,
  }) {
    final isSelected = _selectedFormat == format;

    return InkWell(
      onTap: _isExporting
          ? null
          : () {
              setState(() {
                _selectedFormat = format;
              });
            },
      borderRadius: AppRadii.borderMd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    format.displayName,
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? colors.accent : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontSize: 10,
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

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required AppColors colors,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: colors.accent,
          activeTrackColor: colors.accent.withValues(alpha: 0.4),
          onChanged: _isExporting ? null : onChanged,
        ),
      ],
    );
  }
}
