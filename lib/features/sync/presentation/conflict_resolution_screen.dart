import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/sync/conflict/conflict_model.dart';
import '../../../../core/sync/conflict/conflict_region.dart';
import '../../../../core/sync/conflict/merge_result.dart';
import '../../../../core/sync/sync_provider.dart';
import '../../../../core/widgets/quiet_icon_button.dart';

class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key, required this.conflict});

  final SyncConflict conflict;

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late List<String> _tags;
  late List<ConflictRegion> _regions;
  bool _isResolving = false;
  int _selectedTab = 0; // 0: Merged Editor, 1: Side by Side Comparison

  @override
  void initState() {
    super.initState();
    final conflict = widget.conflict;

    _titleController = TextEditingController(
      text: conflict.resolvedTitle ??
          conflict.localPlaintext?.title ??
          conflict.remotePlaintext?.title ??
          '',
    );

    _contentController = TextEditingController(
      text: conflict.resolvedContent ??
          conflict.localPlaintext?.body ??
          conflict.remotePlaintext?.body ??
          '',
    );

    _tags = List<String>.from(
      conflict.resolvedTags ??
          conflict.localPlaintext?.tags ??
          conflict.remotePlaintext?.tags ??
          [],
    );

    _regions = List<ConflictRegion>.from(conflict.conflictRegions);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _applyRegionChoice(int index, ConflictRegionResolution choice) {
    setState(() {
      _regions[index] = _regions[index].copyWith(resolution: choice);
      _recalculateContentFromRegions();
    });
  }

  void _recalculateContentFromRegions() {
    if (_regions.isEmpty) return;

    var content = _contentController.text;
    for (final r in _regions) {
      if (r.resolution == ConflictRegionResolution.useLocal) {
        if (content.contains(r.remoteText)) {
          content = content.replaceFirst(r.remoteText, r.localText);
        }
      } else if (r.resolution == ConflictRegionResolution.useRemote) {
        if (content.contains(r.localText)) {
          content = content.replaceFirst(r.localText, r.remoteText);
        }
      }
    }
    _contentController.text = content;
  }

  Future<void> _handleKeepMine() async {
    setState(() => _isResolving = true);
    try {
      final resolver = ref.read(conflictResolverProvider);
      await resolver.resolveKeepMine(widget.conflict);
      ref.read(syncEngineProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kept local version of note.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve conflict: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _handleKeepTheirs() async {
    setState(() => _isResolving = true);
    try {
      final resolver = ref.read(conflictResolverProvider);
      await resolver.resolveKeepTheirs(widget.conflict);
      ref.read(syncEngineProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Applied remote server version.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve conflict: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _handleKeepBoth() async {
    setState(() => _isResolving = true);
    try {
      final resolver = ref.read(conflictResolverProvider);
      await resolver.resolveKeepBoth(widget.conflict);
      ref.read(syncEngineProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Created separate conflict copy note.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve conflict: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _handleApplyCustomMerge() async {
    setState(() => _isResolving = true);
    try {
      final resolver = ref.read(conflictResolverProvider);
      await resolver.resolveWithCustomMerge(
        conflict: widget.conflict,
        resolvedTitle: _titleController.text.trim(),
        resolvedContent: _contentController.text,
        resolvedTags: _tags,
      );
      ref.read(syncEngineProvider).syncNow();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Successfully merged and saved note.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save merged note: $e')),
      );
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final conflict = widget.conflict;
    final isDeleteVsEdit = conflict.conflictType == ConflictType.deleteVsEdit;

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
          'Resolve Conflict',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isResolving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: CupertinoActivityIndicator(radius: 8),
            )
          else
            TextButton(
              onPressed: _handleApplyCustomMerge,
              child: Text(
                'Save',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: _isResolving
          ? const Center(child: CupertinoActivityIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // 1. Conflict Summary Header Card
                _buildSummaryCard(colors, conflict),
                const SizedBox(height: AppSpacing.lg),

                // 2. Quick Action Buttons
                _buildQuickActionButtons(colors, isDeleteVsEdit),
                const SizedBox(height: AppSpacing.xl),

                if (isDeleteVsEdit) ...[
                  _buildDeleteVsEditDetails(colors, conflict),
                ] else ...[
                  // Tab selector
                  Row(
                    children: [
                      _buildTabButton('Merge Editor', 0, colors),
                      const SizedBox(width: AppSpacing.sm),
                      _buildTabButton('Side-by-Side Diff', 1, colors),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_selectedTab == 0) ...[
                    // Title Editor
                    _buildTitleEditor(colors, conflict),
                    const SizedBox(height: AppSpacing.lg),

                    // Conflict Regions Demarcation (if any)
                    if (_regions.isNotEmpty) ...[
                      Text(
                        'Conflicting Sections (${_regions.length})',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (var i = 0; i < _regions.length; i++)
                        _buildRegionCard(colors, i, _regions[i]),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Markdown Content Editor
                    Text(
                      'Merged Note Content',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: colors.divider, width: 0.5),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: TextField(
                        controller: _contentController,
                        maxLines: null,
                        minLines: 8,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Note content...',
                          hintStyle: AppTypography.bodySmall.copyWith(
                            color: colors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Side-by-side comparison view
                    _buildSideBySideComparison(colors, conflict),
                  ],
                ],
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
    );
  }

  Widget _buildTabButton(String title, int index, AppColors colors) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent.withValues(alpha: 0.12) : colors.surface,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          title,
          style: AppTypography.caption.copyWith(
            color: isSelected ? colors.accent : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(AppColors colors, SyncConflict conflict) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '3-Way Merge Inspection',
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            conflict.explanation ??
                'Edits were made on multiple devices. Review the changes below and select how to resolve them.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(AppColors colors, bool isDeleteVsEdit) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        OutlinedButton.icon(
          onPressed: _handleKeepMine,
          icon: const Icon(Icons.phone_android_rounded, size: 16),
          label: Text(isDeleteVsEdit ? 'Keep Edited Note' : 'Keep Mine (Local)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.divider),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _handleKeepTheirs,
          icon: const Icon(Icons.cloud_outlined, size: 16),
          label: Text(isDeleteVsEdit ? 'Delete Note' : 'Keep Server (Remote)'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.textPrimary,
            side: BorderSide(color: colors.divider),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        ElevatedButton.icon(
          onPressed: _handleKeepBoth,
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Keep Both'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.elevated,
            foregroundColor: colors.textPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteVsEditDetails(AppColors colors, SyncConflict conflict) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deletion vs Edit Conflict',
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'One device deleted this note while another device edited its content. Choose whether to keep the edited note, complete the deletion, or preserve both versions.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleEditor(AppColors colors, SyncConflict conflict) {
    final localTitle = conflict.localPlaintext?.title ?? '';
    final remoteTitle = conflict.remotePlaintext?.title ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Note Title',
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          if (localTitle != remoteTitle && localTitle.isNotEmpty && remoteTitle.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                ActionChip(
                  label: Text('Local: "$localTitle"'),
                  onPressed: () => _titleController.text = localTitle,
                ),
                ActionChip(
                  label: Text('Remote: "$remoteTitle"'),
                  onPressed: () => _titleController.text = remoteTitle,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegionCard(AppColors colors, int index, ConflictRegion region) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Section #${index + 1}',
                style: AppTypography.caption.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Use Mine'),
                    selected: region.resolution == ConflictRegionResolution.useLocal,
                    onSelected: (_) =>
                        _applyRegionChoice(index, ConflictRegionResolution.useLocal),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ChoiceChip(
                    label: const Text('Use Server'),
                    selected: region.resolution == ConflictRegionResolution.useRemote,
                    onSelected: (_) =>
                        _applyRegionChoice(index, ConflictRegionResolution.useRemote),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildCodeBlock('Mine (Local):', region.localText, colors),
          const SizedBox(height: AppSpacing.xs),
          _buildCodeBlock('Server (Remote):', region.remoteText, colors),
        ],
      ),
    );
  }

  Widget _buildCodeBlock(String title, String text, AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.caption.copyWith(color: colors.textTertiary),
        ),
        const SizedBox(height: 2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: colors.divider, width: 0.5),
          ),
          child: Text(
            text.isEmpty ? '(Empty)' : text,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideBySideComparison(AppColors colors, SyncConflict conflict) {
    final local = conflict.localPlaintext;
    final remote = conflict.remotePlaintext;

    return Column(
      children: [
        _buildSideBlock('Mine (Local Branch)', local?.title ?? '', local?.body ?? '', colors),
        const SizedBox(height: AppSpacing.md),
        _buildSideBlock('Server (Remote Branch)', remote?.title ?? '', remote?.body ?? '', colors),
      ],
    );
  }

  Widget _buildSideBlock(String label, String title, String body, AppColors colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title.isEmpty ? 'Untitled' : title,
            style: AppTypography.bodyMedium.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Divider(height: AppSpacing.md),
          Text(
            body.isEmpty ? '(Empty body)' : body,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
