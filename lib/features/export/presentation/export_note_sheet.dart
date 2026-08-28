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

    final displayTitle = widget.note.displayTitle.isNotEmpty
        ? widget.note.displayTitle
        : 'Untitled Note';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(
                        top: AppSpacing.xs,
                        bottom: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colors.textTertiary.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: colors.accent.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.ios_share_rounded,
                            color: colors.accent,
                            size: 17,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export Note',
                                style: AppTypography.title.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 12.5,
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
                  ),

                  // Section Header: FORMAT
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
                    child: Text(
                      'FORMAT',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  // Single Grouped Format Surface
                  _GroupedContainer(
                    colors: colors,
                    children: [
                      _FormatRow(
                        title: 'Markdown',
                        subtitle: '.md · Portable Markdown',
                        icon: Icons.article_outlined,
                        isSelected: _selectedFormat == ExportFormat.markdown,
                        colors: colors,
                        isFirst: true,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.markdown),
                      ),
                      _buildRowDivider(colors),
                      _FormatRow(
                        title: 'PDF',
                        subtitle: '.pdf · Searchable Document',
                        icon: Icons.picture_as_pdf_outlined,
                        isSelected: _selectedFormat == ExportFormat.pdf,
                        colors: colors,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.pdf),
                      ),
                      _buildRowDivider(colors),
                      _FormatRow(
                        title: 'HTML',
                        subtitle: '.html · Standalone Web Page',
                        icon: Icons.language_rounded,
                        isSelected: _selectedFormat == ExportFormat.html,
                        colors: colors,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.html),
                      ),
                      _buildRowDivider(colors),
                      _FormatRow(
                        title: 'Plain Text',
                        subtitle: '.txt · Clean Plain Text',
                        icon: Icons.text_snippet_outlined,
                        isSelected: _selectedFormat == ExportFormat.plainText,
                        colors: colors,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.plainText),
                      ),
                      _buildRowDivider(colors),
                      _FormatRow(
                        title: 'Microsoft Word',
                        subtitle: '.docx · Microsoft Word',
                        icon: Icons.description_outlined,
                        isSelected: _selectedFormat == ExportFormat.docx,
                        colors: colors,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.docx),
                      ),
                      _buildRowDivider(colors),
                      _FormatRow(
                        title: 'Quiet Paper Package',
                        subtitle: '.qpnote · Full-Fidelity Note',
                        icon: Icons.inventory_2_outlined,
                        isSelected: _selectedFormat == ExportFormat.qpnote,
                        colors: colors,
                        isSpecial: true,
                        isLast: true,
                        onTap: _isExporting
                            ? null
                            : () => setState(() => _selectedFormat = ExportFormat.qpnote),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Advanced Options Expander Row
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAdvanced = !_showAdvanced;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.divider.withValues(alpha: 0.6),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Advanced Options',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          Icon(
                            _showAdvanced
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Format-Specific Advanced Options
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _showAdvanced
                        ? Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: _buildFormatSpecificOptions(colors),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.25),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: colors.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.caption.copyWith(
                                color: colors.error,
                                fontSize: 12,
                              ),
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
                        color: colors.accent.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.accent.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 13,
                                height: 13,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.accent,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _progressState!.effectiveMessage,
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: _progressState!.progress > 0
                                  ? _progressState!.progress
                                  : null,
                              minHeight: 3,
                              backgroundColor: colors.divider.withValues(alpha: 0.4),
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons: Save File & Share
                  Row(
                    children: [
                      Expanded(
                        child: QuietButton(
                          label: 'Save File',
                          icon: Icons.folder_open_rounded,
                          variant: QuietButtonVariant.secondary,
                          isLoading: _isExporting &&
                              _progressState?.phase != ExportPhase.sharing,
                          onPressed: _isExporting
                              ? null
                              : () => _handleExport(isShare: false),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: QuietButton(
                          label: 'Share',
                          icon: Icons.share_rounded,
                          variant: QuietButtonVariant.primary,
                          isLoading: _isExporting &&
                              _progressState?.phase == ExportPhase.sharing,
                          onPressed: _isExporting
                              ? null
                              : () => _handleExport(isShare: true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRowDivider(AppColors colors) {
    return Divider(
      color: colors.divider.withValues(alpha: 0.45),
      height: 1,
      thickness: 0.8,
      indent: 48,
      endIndent: 0,
    );
  }

  Widget _buildFormatSpecificOptions(AppColors colors) {
    switch (_selectedFormat) {
      case ExportFormat.markdown:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'YAML frontmatter with dates, tags, and pinned state',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include attachments',
              subtitle: 'Rewrite local relative asset links in attachments folder',
              value: _includeAttachments,
              colors: colors,
              onChanged: (val) => setState(() => _includeAttachments = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Append searchable scan transcripts at end of file',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );

      case ExportFormat.pdf:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'Header card with note dates, tags, and attributes',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include attachments',
              subtitle: 'Embed image attachments directly into PDF pages',
              value: _includeAttachments,
              colors: colors,
              onChanged: (val) => setState(() => _includeAttachments = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Append searchable scan transcripts to PDF',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );

      case ExportFormat.html:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'Editorial header card with creation dates and tags',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include attachments',
              subtitle: 'Embed images inline as self-contained Base64 data URIs',
              value: _includeAttachments,
              colors: colors,
              onChanged: (val) => setState(() => _includeAttachments = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Append recognized scan text in transcript sections',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );

      case ExportFormat.plainText:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'Plain text header summary with dates and tags',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Append OCR transcripts at bottom of plain text',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );

      case ExportFormat.docx:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'Document properties, header table, and tag chips',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include attachments',
              subtitle: 'Embed pictures and drawings directly in Word document',
              value: _includeAttachments,
              colors: colors,
              onChanged: (val) => setState(() => _includeAttachments = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Append OCR transcript sections to Word document',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );

      case ExportFormat.qpnote:
        return _GroupedContainer(
          colors: colors,
          children: [
            _OptionRow(
              title: 'Include metadata',
              subtitle: 'Preserve tags, timestamps, and note ID in metadata.json',
              value: _includeMetadata,
              colors: colors,
              isFirst: true,
              onChanged: (val) => setState(() => _includeMetadata = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include attachments',
              subtitle: 'Pack all attached images and documents into package',
              value: _includeAttachments,
              colors: colors,
              onChanged: (val) => setState(() => _includeAttachments = val),
            ),
            _buildOptionDivider(colors),
            _OptionRow(
              title: 'Include OCR recognized text',
              subtitle: 'Pack structured OCR transcripts into ocr/ folder',
              value: _includeOcr,
              colors: colors,
              isLast: true,
              onChanged: (val) => setState(() => _includeOcr = val),
            ),
          ],
        );
    }
  }

  Widget _buildOptionDivider(AppColors colors) {
    return Divider(
      color: colors.divider.withValues(alpha: 0.4),
      height: 1,
      thickness: 0.8,
      indent: 16,
      endIndent: 16,
    );
  }
}

/// A container card mimicking Quiet Paper's iOS/Bear grouped table sections.
class _GroupedContainer extends StatelessWidget {
  const _GroupedContainer({
    required this.colors,
    required this.children,
  });

  final AppColors colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// A clickable format option row inside the unified grouped format selector.
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.colors,
    required this.onTap,
    this.isSpecial = false,
    this.isFirst = false,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final AppColors colors;
  final VoidCallback? onTap;
  final bool isSpecial;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      selected: isSelected,
      button: true,
      child: Material(
        color: isSelected
            ? colors.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(12) : Radius.zero,
            bottom: isLast ? const Radius.circular(12) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTypography.bodyMedium.copyWith(
                                color: isSelected
                                    ? colors.accent
                                    : colors.textPrimary,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                fontSize: 15.0,
                              ),
                            ),
                          ),
                          if (isSpecial) ...[
                            const SizedBox(width: 8.0),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6.0,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Text(
                                'Recommended',
                                style: AppTypography.caption.copyWith(
                                  color: colors.accent,
                                  fontSize: 10.0,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12.0,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                if (isSelected)
                  Icon(
                    Icons.check_rounded,
                    size: 20,
                    color: colors.accent,
                  )
                else
                  const SizedBox(width: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A switch row inside the grouped options container.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.colors,
    required this.onChanged,
    this.isFirst = false,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final AppColors colors;
  final ValueChanged<bool> onChanged;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 10.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12.0),
          Switch.adaptive(
            value: value,
            activeThumbColor: colors.accent,
            activeTrackColor: colors.accent.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
