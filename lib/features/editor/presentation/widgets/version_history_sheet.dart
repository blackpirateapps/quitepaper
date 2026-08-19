import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../notes/domain/note_model.dart';
import '../../../notes/domain/note_version_model.dart';

/// Bottom sheet displaying the chronological version history of a note
/// with visual diffs and non-destructive version restoration.
class VersionHistorySheet extends ConsumerStatefulWidget {
  const VersionHistorySheet({
    super.key,
    required this.note,
    required this.currentTitle,
    required this.currentContent,
    required this.currentTags,
    required this.onRestoreVersion,
  });

  final Note note;
  final String currentTitle;
  final String currentContent;
  final List<String> currentTags;
  final Future<void> Function(NoteVersion version) onRestoreVersion;

  static Future<void> show(
    BuildContext context, {
    required Note note,
    required String currentTitle,
    required String currentContent,
    required List<String> currentTags,
    required Future<void> Function(NoteVersion version) onRestoreVersion,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VersionHistorySheet(
        note: note,
        currentTitle: currentTitle,
        currentContent: currentContent,
        currentTags: currentTags,
        onRestoreVersion: onRestoreVersion,
      ),
    );
  }

  @override
  ConsumerState<VersionHistorySheet> createState() => _VersionHistorySheetState();
}

class _VersionHistorySheetState extends ConsumerState<VersionHistorySheet> {
  NoteVersion? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final repository = ref.watch(notesRepositoryProvider);
    final size = MediaQuery.of(context).size;

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.85),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                if (_selectedVersion != null)
                  QuietIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back to versions',
                    onPressed: () => setState(() => _selectedVersion = null),
                  )
                else
                  Icon(Icons.history_rounded, size: 22, color: colors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedVersion != null
                        ? 'Version ${_selectedVersion!.versionNumber}'
                        : 'Version History',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                ),
                QuietIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(color: colors.divider, height: 1),

          // Content
          Expanded(
            child: _selectedVersion != null
                ? _buildVersionDetailView(context, _selectedVersion!, colors)
                : _buildVersionsList(context, repository, colors),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionsList(
    BuildContext context,
    dynamic repository,
    AppColors colors,
  ) {
    return StreamBuilder<List<NoteVersion>>(
      stream: repository.watchVersions(widget.note.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final versions = snapshot.data ?? [];
        if (versions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 48, color: colors.textTertiary),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No past versions yet',
                    style: AppTypography.bodyLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Versions are saved automatically whenever you make changes in a note session.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          itemCount: versions.length,
          separatorBuilder: (context, index) => Divider(color: colors.divider.withValues(alpha: 0.5), height: 1),
          itemBuilder: (context, index) {
            final version = versions[index];
            final dateStr = DateFormat.yMMMd().add_jm().format(version.createdAt);

            return InkWell(
              borderRadius: AppRadii.borderMd,
              onTap: () => setState(() => _selectedVersion = version),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.tagBackground,
                        borderRadius: AppRadii.borderSm,
                      ),
                      child: Text(
                        'v${version.versionNumber}',
                        style: AppTypography.caption.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateStr,
                            style: AppTypography.bodyMedium.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${version.wordCount} words',
                                style: AppTypography.caption.copyWith(
                                  color: colors.textTertiary,
                                ),
                              ),
                              if (version.deltaSummary != null && version.deltaSummary!.isNotEmpty) ...[
                                Text(
                                  ' • ',
                                  style: AppTypography.caption.copyWith(color: colors.textTertiary),
                                ),
                                Flexible(
                                  child: Text(
                                    version.deltaSummary!,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.caption.copyWith(
                                      color: colors.accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 20, color: colors.textTertiary),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVersionDetailView(
    BuildContext context,
    NoteVersion version,
    AppColors colors,
  ) {
    final dateStr = DateFormat.yMMMd().add_jm().format(version.createdAt);

    return Column(
      children: [
        // Version Meta Banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: colors.tagBackground.withValues(alpha: 0.5),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saved on $dateStr',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${version.wordCount} words • ${version.charCount} characters',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              QuietButton(
                label: 'Copy Text',
                icon: Icons.copy_rounded,
                variant: QuietButtonVariant.secondary,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: version.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Version text copied to clipboard'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(width: AppSpacing.xs),
              QuietButton(
                label: 'Restore',
                icon: Icons.restore_rounded,
                variant: QuietButtonVariant.primary,
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: colors.surface,
                      title: const Text('Restore this version?'),
                      content: Text(
                        'This will restore Version ${version.versionNumber} into your active editor. Your current note state will be saved as a new version automatically.',
                        style: AppTypography.bodyMedium.copyWith(color: colors.textPrimary),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text('Restore', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    Navigator.of(context).pop();
                    await widget.onRestoreVersion(version);
                  }
                },
              ),
            ],
          ),
        ),

        // Diff & Text View
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (version.title.trim().isNotEmpty) ...[
                  Text(
                    version.title,
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (version.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: version.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.tagBackground,
                          borderRadius: AppRadii.borderSm,
                        ),
                        child: Text(
                          '#$tag',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                Text(
                  version.content.isNotEmpty ? version.content : '*Empty content*',
                  style: AppTypography.bodyLarge.copyWith(
                    color: colors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
