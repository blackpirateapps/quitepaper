import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../application/tag_providers.dart';
import '../domain/tag_icon_registry.dart';
import '../domain/tag_model.dart';
import 'tag_detail_screen.dart';
import 'widgets/tag_action_dialogs.dart';
import 'widgets/tag_color_picker_sheet.dart';
import 'widgets/tag_icon_picker_sheet.dart';

/// Dedicated Full-Page Tag Browser Screen for Quiet Paper.
class TagBrowserScreen extends ConsumerStatefulWidget {
  const TagBrowserScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const TagBrowserScreen()),
    );
  }

  @override
  ConsumerState<TagBrowserScreen> createState() => _TagBrowserScreenState();
}

class _TagBrowserScreenState extends ConsumerState<TagBrowserScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref.read(tagSearchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTag() async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    final existingNames = allTags.map((t) => t.name).toList();

    final newTag = await TagCreateDialog.show(
      context,
      existingTags: existingNames,
    );

    if (newTag != null && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.createTag(
        newTag.name,
        icon: newTag.icon,
        color: newTag.color,
        isPinned: newTag.isPinned,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag #${newTag.name} created'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleRename(Tag tag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    final existingNames = allTags.map((t) => t.name).toList();

    final newName = await TagRenameDialog.show(
      context,
      tag: tag,
      existingTags: existingNames,
    );

    if (newName != null && newName != tag.name && mounted) {
      final service = ref.read(tagServiceProvider);
      try {
        await service.renameTag(tag.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tag renamed from #${tag.name} to #$newName'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error renaming tag: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleDelete(Tag tag) async {
    final confirmed = await TagDeleteDialog.show(context, tag: tag);
    if (confirmed == true && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.deleteTag(tag.id);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tag #${tag.name} deleted'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleMerge(Tag sourceTag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];

    final destination = await TagMergeDialog.show(
      context,
      sourceTag: sourceTag,
      availableTags: allTags,
    );

    if (destination != null && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.mergeTags(sourceTag.id, destination.id);
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Merged #${sourceTag.name} into #${destination.name}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleChangeIcon(Tag tag) async {
    final newIcon = await TagIconPickerSheet.show(
      context,
      currentIconId: tag.icon,
      tagName: tag.name,
    );
    if (mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagIcon(tag.id, newIcon);
    }
  }

  Future<void> _handleChangeColor(Tag tag) async {
    final newColor = await TagColorPickerSheet.show(
      context,
      currentColorId: tag.color,
    );
    if (mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagColor(tag.id, newColor);
    }
  }

  void _showTagOptions(BuildContext context, Tag tag) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = tag.colorDefinition;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      TagIconRegistry.getIconData(tag.icon),
                      size: 20,
                      color: colorDef?.foreground(isDark) ?? colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${tag.name}',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${tag.noteCount} note${tag.noteCount == 1 ? '' : 's'}',
                      style: AppTypography.caption.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Divider(color: colors.divider, height: 1),
              ListTile(
                dense: true,
                leading: Icon(
                  tag.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 20,
                  color: tag.isPinned ? colors.accent : colors.textSecondary,
                ),
                title: Text(
                  tag.isPinned ? 'Unpin tag' : 'Pin to top',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
                title: Text(
                  'Rename',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleRename(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.sentiment_satisfied_alt_rounded, size: 20, color: colors.textSecondary),
                title: Text(
                  tag.icon != null ? 'Change icon' : 'Add icon',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChangeIcon(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.palette_outlined, size: 20, color: colors.textSecondary),
                title: Text(
                  tag.color != null ? 'Change color' : 'Add color',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChangeColor(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.merge_type_rounded, size: 20, color: colors.textSecondary),
                title: Text(
                  'Merge into...',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleMerge(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.delete_outline_rounded, size: 20, color: colors.error),
                title: Text(
                  'Delete tag',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleDelete(tag);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filteredTagsAsync = ref.watch(filteredBrowserTagsProvider);
    final pinnedTags = ref.watch(pinnedTagsProvider);
    final activeFilter = ref.watch(tagFilterProvider);
    final activeSort = ref.watch(tagSortProvider);
    final query = ref.watch(tagSearchQueryProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearchOpen) {
            setState(() {
              _isSearchOpen = false;
              _searchController.clear();
            });
          } else {
            Navigator.of(context).pop();
          }
        },
      },
      child: Scaffold(
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
          title: _isSearchOpen
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: true,
                  style: AppTypography.title.copyWith(
                    color: colors.textPrimary,
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search tags...',
                    hintStyle: AppTypography.title.copyWith(
                      color: colors.textTertiary,
                      fontSize: 18,
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  'Tags',
                  style: AppTypography.title.copyWith(color: colors.textPrimary),
                ),
          actions: [
            if (_isSearchOpen)
              QuietIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close search',
                onPressed: () {
                  setState(() {
                    _isSearchOpen = false;
                    _searchController.clear();
                  });
                },
              )
            else
              QuietIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Search tags',
                onPressed: () {
                  setState(() => _isSearchOpen = true);
                  _searchFocusNode.requestFocus();
                },
              ),

            // Filter menu
            PopupMenuButton<TagFilter>(
              icon: Icon(
                activeFilter != TagFilter.all
                    ? Icons.filter_alt_rounded
                    : Icons.filter_alt_outlined,
                color: activeFilter != TagFilter.all ? colors.accent : colors.textSecondary,
                size: 20,
              ),
              tooltip: 'Filter tags',
              color: colors.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
              onSelected: (filter) => ref.read(tagFilterProvider.notifier).state = filter,
              itemBuilder: (ctx) => TagFilter.values.map((f) {
                final isSelected = activeFilter == f;
                return PopupMenuItem(
                  value: f,
                  child: Row(
                    children: [
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 16, color: colors.accent)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(
                        f.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected ? colors.accent : colors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            // Sort menu
            PopupMenuButton<TagSort>(
              icon: Icon(
                Icons.sort_rounded,
                color: activeSort != TagSort.name ? colors.accent : colors.textSecondary,
                size: 20,
              ),
              tooltip: 'Sort tags',
              color: colors.surface,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
              onSelected: (sort) => ref.read(tagSortProvider.notifier).state = sort,
              itemBuilder: (ctx) => TagSort.values.map((s) {
                final isSelected = activeSort == s;
                return PopupMenuItem(
                  value: s,
                  child: Row(
                    children: [
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 16, color: colors.accent)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 8),
                      Text(
                        s.label,
                        style: AppTypography.bodySmall.copyWith(
                          color: isSelected ? colors.accent : colors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

            QuietIconButton(
              icon: Icons.add_rounded,
              tooltip: 'New Tag',
              onPressed: _handleCreateTag,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: filteredTagsAsync.when(
          data: (tags) {
            if (tags.isEmpty) {
              return _buildEmptyState(colors, query, activeFilter);
            }

            final isDefaultView = query.isEmpty && activeFilter == TagFilter.all && activeSort == TagSort.name;

            if (isDefaultView && pinnedTags.isNotEmpty) {
              final unpinnedTags = tags.where((t) => !t.isPinned).toList();

              return ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                children: [
                  // PINNED Section
                  _buildSectionHeader(colors, 'PINNED', pinnedTags.length),
                  Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pinnedTags.length,
                      onReorderItem: (oldIdx, newIdx) {
                        final list = List<Tag>.from(pinnedTags);
                        final item = list.removeAt(oldIdx);
                        list.insert(newIdx, item);
                        ref.read(tagServiceProvider).reorderPinnedTags(list.map((t) => t.id).toList());
                      },
                      itemBuilder: (ctx, index) {
                        final item = pinnedTags[index];
                        return _buildTagRow(item, colors, key: ValueKey('pinned_${item.id}'));
                      },
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),
                  _buildSectionHeader(colors, 'ALL TAGS', unpinnedTags.length),
                  ...unpinnedTags.map((item) {
                    return _buildTagRow(item, colors, key: ValueKey('all_${item.id}'));
                  }),
                ],
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: tags.length,
              itemBuilder: (ctx, index) {
                final item = tags[index];
                return _buildTagRow(item, colors, key: ValueKey('tag_${item.id}'));
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator.adaptive()),
          error: (err, _) => Center(
            child: Text(
              'Error loading tags: $err',
              style: AppTypography.bodySmall.copyWith(color: colors.error),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppColors colors, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: colors.divider.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagRow(Tag item, AppColors colors, {Key? key}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = item.colorDefinition;
    final iconData = TagIconRegistry.getIconData(item.icon);

    return InkWell(
      key: key,
      onTap: () => TagDetailScreen.open(context, tagId: item.id),
      onLongPress: () => _showTagOptions(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10.0,
        ),
        child: Row(
          children: [
            // Icon or hash glyph container
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorDef != null
                    ? colorDef.background(isDark)
                    : colors.tagBackground,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 16,
                  color: colorDef != null
                      ? colorDef.foreground(isDark)
                      : colors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Tag Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '#${item.name}',
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin_rounded,
                          size: 12,
                          color: colors.accent,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Note count badge
            Text(
              '${item.noteCount}',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 4),

            // Overflow menu button
            IconButton(
              icon: Icon(
                Icons.more_horiz_rounded,
                size: 18,
                color: colors.textTertiary,
              ),
              splashRadius: 18,
              onPressed: () => _showTagOptions(context, item),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors, String query, TagFilter filter) {
    String title;
    String subtitle;
    IconData icon;

    if (query.isNotEmpty) {
      title = 'No matching tags';
      subtitle = 'No tags found matching "$query"';
      icon = Icons.search_off_rounded;
    } else if (filter == TagFilter.pinned) {
      title = 'No pinned tags';
      subtitle = 'Pin the tags you use most often for quick access.';
      icon = Icons.push_pin_outlined;
    } else if (filter == TagFilter.unused) {
      title = 'No unused tags';
      subtitle = 'All tags currently have associated notes.';
      icon = Icons.done_all_rounded;
    } else {
      title = 'No tags yet';
      subtitle = 'Add tags to your notes with #tag to organize them here.';
      icon = Icons.label_outline_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: colors.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (query.isEmpty && filter == TagFilter.all) ...[
              const SizedBox(height: AppSpacing.lg),
              QuietButton(
                label: 'Create Tag',
                icon: Icons.add_rounded,
                variant: QuietButtonVariant.primary,
                onPressed: _handleCreateTag,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
