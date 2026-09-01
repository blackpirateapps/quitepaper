import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../notes/application/notes_query_provider.dart';
import '../../application/tag_providers.dart';
import '../../domain/tag_icon_registry.dart';
import '../../domain/tag_model.dart';
import 'tag_action_dialogs.dart';
import 'tag_color_picker_sheet.dart';
import 'tag_icon_picker_sheet.dart';

/// Embedded Tag Browser component designed for Quiet Paper's 3-pane middle pane and mobile views.
class TagBrowserView extends ConsumerStatefulWidget {
  const TagBrowserView({
    super.key,
    this.onOpenDrawer,
    this.onToggleSidebar,
    this.isSidebarVisible = true,
    this.isTablet = false,
    this.onClose,
    this.onTagSelected,
  });

  /// Optional callback to open drawer on phones
  final VoidCallback? onOpenDrawer;

  /// Optional callback to toggle left sidebar on tablets
  final VoidCallback? onToggleSidebar;

  /// Whether the left sidebar is currently visible
  final bool isSidebarVisible;

  /// Whether running in tablet 3-pane middle layout
  final bool isTablet;

  /// Optional close callback if displayed in a modal/dialog/screen
  final VoidCallback? onClose;

  /// Optional tag selected callback; defaults to activating AppDestination.tag
  final ValueChanged<Tag>? onTagSelected;

  @override
  ConsumerState<TagBrowserView> createState() => _TagBrowserViewState();
}

class _TagBrowserViewState extends ConsumerState<TagBrowserView> {
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

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
      _searchController.clear();
    });
    ref.read(tagSearchQueryProvider.notifier).state = '';
  }

  void _handleTagTap(Tag tag) {
    if (widget.onTagSelected != null) {
      widget.onTagSelected!(tag);
    } else {
      ref.read(currentDestinationProvider.notifier).state = AppDestination.tag;
      ref.read(selectedTagFilterProvider.notifier).state = tag.name;
      ref.read(selectedTagIdProvider.notifier).state = tag.id;
      ref.read(notesQueryProvider.notifier).setTag(tag.name);
    }
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
            content: Text('Tag #${tag.name} deleted (notes kept)'),
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xs,
                ),
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
                  PhosphorIconsRegular.arrowSquareOut,
                  size: 20,
                  color: colors.accent,
                ),
                title: Text(
                  'Open',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleTagTap(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  tag.isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
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
                leading: Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: colors.textSecondary),
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
                leading: Icon(
                  PhosphorIconsRegular.smiley,
                  size: 20,
                  color: colors.textSecondary,
                ),
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
                leading: Icon(PhosphorIconsRegular.palette, size: 20, color: colors.textSecondary),
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
                leading: Icon(PhosphorIconsRegular.gitMerge, size: 20, color: colors.textSecondary),
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
                leading: Icon(PhosphorIconsRegular.trash, size: 20, color: colors.error),
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
            _closeSearch();
          } else {
            widget.onClose?.call();
          }
        },
      },
      child: Container(
        color: colors.background,
        child: Column(
          children: [
            // Compact Header
            _buildHeader(context, colors, activeSort, activeFilter),
            Divider(color: colors.divider, height: 1),

            // Tag List Body
            Expanded(
              child: filteredTagsAsync.when(
                data: (tags) {
                  final allRawTags = ref.watch(allTagsProvider).valueOrNull ?? [];

                  // Empty State: No tags exist at all
                  if (allRawTags.isEmpty && query.isEmpty) {
                    return _buildEmptyState(
                      colors,
                      title: 'No tags yet',
                      subtitle: 'Add tags to your notes to organize them here.',
                      actionLabel: 'Create Tag',
                      onAction: _handleCreateTag,
                    );
                  }

                  // Empty State: Search or filter returned 0 results
                  if (tags.isEmpty) {
                    return _buildEmptyState(
                      colors,
                      title: query.isNotEmpty ? 'No matching tags' : 'No tags match this filter',
                      subtitle: query.isNotEmpty
                          ? 'No tags found matching "$query".'
                          : 'Try changing your active filter.',
                    );
                  }

                  // Filtered / Search results view (flat list)
                  final isFilteredOrSorted = query.isNotEmpty ||
                      activeFilter != TagFilter.all ||
                      activeSort != TagSort.name;

                  if (!isFilteredOrSorted && pinnedTags.isNotEmpty) {
                    final unpinnedTags = tags.where((t) => !t.isPinned).toList();

                    return ListView(
                      padding: const EdgeInsets.only(bottom: 48),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        const SizedBox(height: AppSpacing.xs),
                        _buildSectionHeader(colors, 'PINNED', pinnedTags.length),
                        Padding(
                          padding: EdgeInsets.zero,
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pinnedTags.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIdx, newIdx) {
                              final list = List<Tag>.from(pinnedTags);
                              if (newIdx > oldIdx) newIdx -= 1;
                              final item = list.removeAt(oldIdx);
                              list.insert(newIdx, item);
                              ref
                                  .read(tagServiceProvider)
                                  .reorderPinnedTags(list.map((t) => t.id).toList());
                            },
                            itemBuilder: (ctx, index) {
                              final item = pinnedTags[index];
                              return _buildTagRow(
                                item,
                                colors,
                                key: ValueKey('pinned_${item.id}'),
                                hidePinGlyph: true,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _buildSectionHeader(colors, 'ALL TAGS', unpinnedTags.length),
                        ...unpinnedTags.map((item) {
                          return _buildTagRow(
                            item,
                            colors,
                            key: ValueKey('all_${item.id}'),
                          );
                        }),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: tags.length,
                    itemBuilder: (ctx, index) {
                      final item = tags[index];
                      return _buildTagRow(
                        item,
                        colors,
                        key: ValueKey('tag_${item.id}'),
                      );
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppColors colors,
    TagSort activeSort,
    TagFilter activeFilter,
  ) {
    if (_isSearchOpen) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                style: AppTypography.body.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Search tags...',
                  hintStyle: AppTypography.body.copyWith(
                    color: colors.textTertiary,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              QuietIconButton(
                icon: PhosphorIconsRegular.xCircle,
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  ref.read(tagSearchQueryProvider.notifier).state = '';
                },
              ),
            QuietIconButton(
              icon: PhosphorIconsRegular.x,
              tooltip: 'Close search',
              onPressed: _closeSearch,
            ),
          ],
        ),
      );
    }

    final totalCount = ref.watch(allTagsProvider).valueOrNull?.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 340;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              if (widget.onOpenDrawer != null)
                QuietIconButton(
                  icon: PhosphorIconsRegular.list,
                  tooltip: 'Open navigation',
                  onPressed: widget.onOpenDrawer,
                )
              else if (widget.isTablet && widget.onToggleSidebar != null)
                QuietIconButton(
                  icon: widget.isSidebarVisible
                      ? PhosphorIconsRegular.sidebarSimple
                      : PhosphorIconsRegular.sidebarSimple,
                  tooltip: widget.isSidebarVisible ? 'Hide navigation' : 'Show navigation',
                  onPressed: widget.onToggleSidebar,
                ),
              const SizedBox(width: 4),
              Text(
                'Tags',
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: colors.divider.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$totalCount',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              // Search Action
              QuietIconButton(
                icon: PhosphorIconsRegular.magnifyingGlass,
                tooltip: 'Search tags',
                onPressed: () {
                  setState(() {
                    _isSearchOpen = true;
                  });
                  _searchFocusNode.requestFocus();
                },
              ),
              if (!isCompact) ...[
                // Separate Sort Menu
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<TagSort>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(PhosphorIconsRegular.arrowsDownUp, size: 20),
                    tooltip: 'Sort tags',
                    color: colors.surface,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderMd,
                      side: BorderSide(color: colors.divider, width: 0.8),
                    ),
                    initialValue: activeSort,
                    onSelected: (val) {
                      ref.read(tagSortProvider.notifier).state = val;
                    },
                    itemBuilder: (context) => _buildSortMenuItems(colors, activeSort),
                  ),
                ),
                const SizedBox(width: 2),
                // Separate Filter Menu
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<TagFilter>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      activeFilter != TagFilter.all
                          ? PhosphorIconsFill.funnel
                          : PhosphorIconsRegular.funnel,
                      size: 20,
                      color: activeFilter != TagFilter.all ? colors.accent : null,
                    ),
                    tooltip: 'Filter tags',
                    color: colors.surface,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderMd,
                      side: BorderSide(color: colors.divider, width: 0.8),
                    ),
                    initialValue: activeFilter,
                    onSelected: (val) {
                      ref.read(tagFilterProvider.notifier).state = val;
                    },
                    itemBuilder: (context) => _buildFilterMenuItems(colors, activeFilter),
                  ),
                ),
              ] else ...[
                // Compact Combined Sort & Filter Menu
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      activeFilter != TagFilter.all
                          ? PhosphorIconsFill.funnel
                          : PhosphorIconsRegular.arrowsDownUp,
                      size: 20,
                      color: activeFilter != TagFilter.all ? colors.accent : null,
                    ),
                    tooltip: 'Sort and filter tags',
                    color: colors.surface,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderMd,
                      side: BorderSide(color: colors.divider, width: 0.8),
                    ),
                    onSelected: (val) {
                      if (val.startsWith('sort_')) {
                        final sortName = val.substring(5);
                        final sort = TagSort.values.firstWhere((s) => s.name == sortName);
                        ref.read(tagSortProvider.notifier).state = sort;
                      } else if (val.startsWith('filter_')) {
                        final filterName = val.substring(7);
                        final filter = TagFilter.values.firstWhere((f) => f.name == filterName);
                        ref.read(tagFilterProvider.notifier).state = filter;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'SORT BY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...TagSort.values.map(
                        (s) => PopupMenuItem<String>(
                          value: 'sort_${s.name}',
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getSortLabel(s),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: activeSort == s ? colors.accent : colors.textPrimary,
                                    fontWeight: activeSort == s ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (activeSort == s)
                                Icon(PhosphorIconsRegular.check, size: 16, color: colors.accent),
                            ],
                          ),
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        enabled: false,
                        height: 28,
                        child: Text(
                          'FILTER BY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      ...TagFilter.values.map(
                        (f) => PopupMenuItem<String>(
                          value: 'filter_${f.name}',
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _getFilterLabel(f),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: activeFilter == f ? colors.accent : colors.textPrimary,
                                    fontWeight: activeFilter == f ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (activeFilter == f)
                                Icon(PhosphorIconsRegular.check, size: 16, color: colors.accent),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(width: 2),
              // Add Tag Action
              QuietIconButton(
                icon: PhosphorIconsRegular.plus,
                tooltip: 'New tag',
                isActive: true,
                onPressed: _handleCreateTag,
              ),
            ],
          ),
        );
      },
    );
  }

  String _getSortLabel(TagSort sort) {
    switch (sort) {
      case TagSort.name:
        return 'Name (A–Z)';
      case TagSort.noteCount:
        return 'Note count';
      case TagSort.recentlyUsed:
        return 'Recently used';
      case TagSort.recentlyCreated:
        return 'Recently created';
      case TagSort.custom:
        return 'Custom (Pinned first)';
    }
  }

  String _getFilterLabel(TagFilter filter) {
    switch (filter) {
      case TagFilter.all:
        return 'All tags';
      case TagFilter.pinned:
        return 'Pinned only';
      case TagFilter.hasIcon:
        return 'Has icon';
      case TagFilter.hasColor:
        return 'Has color';
      case TagFilter.hasNotes:
        return 'With notes';
      case TagFilter.unused:
        return 'Unused tags';
    }
  }

  List<PopupMenuEntry<TagSort>> _buildSortMenuItems(AppColors colors, TagSort activeSort) {
    return TagSort.values.map((s) {
      return _buildPopupCheckItem(
        s,
        _getSortLabel(s),
        activeSort == s,
        colors,
      );
    }).toList();
  }

  List<PopupMenuEntry<TagFilter>> _buildFilterMenuItems(AppColors colors, TagFilter activeFilter) {
    return TagFilter.values.map((f) {
      return _buildPopupCheckItem(
        f,
        _getFilterLabel(f),
        activeFilter == f,
        colors,
      );
    }).toList();
  }

  PopupMenuItem<T> _buildPopupCheckItem<T>(
    T value,
    String label,
    bool isSelected,
    AppColors colors,
  ) {
    return PopupMenuItem<T>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            Icon(PhosphorIconsRegular.check, size: 16, color: colors.accent),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppColors colors, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
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

  Widget _buildTagRow(
    Tag item,
    AppColors colors, {
    Key? key,
    bool hidePinGlyph = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = item.colorDefinition;
    final iconData = TagIconRegistry.getIconData(item.icon);

    return Semantics(
      key: key,
      label: '${item.name}, ${item.noteCount} notes${item.isPinned ? ', pinned' : ''}',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTagTap(item),
          onLongPress: () => _showTagOptions(context, item),
          onSecondaryTap: () => _showTagOptions(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8.0,
            ),
            child: Row(
              children: [
                // Icon or hash glyph container
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colorDef != null
                        ? colorDef.background(isDark)
                        : colors.tagBackground,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      size: 15,
                      color: colorDef != null
                          ? colorDef.foreground(isDark)
                          : colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Tag Name
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '#${item.name}',
                          style: AppTypography.body.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (item.isPinned && !hidePinGlyph) ...[
                        const SizedBox(width: 5),
                        Icon(
                          PhosphorIconsFill.pushPin,
                          size: 12,
                          color: colors.accent,
                        ),
                      ],
                    ],
                  ),
                ),

                // Note count badge
                Text(
                  '${item.noteCount}',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),

                // More options button
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(
                      PhosphorIconsRegular.dotsThreeVertical,
                      color: colors.textTertiary,
                    ),
                    tooltip: 'Tag options',
                    onPressed: () => _showTagOptions(context, item),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    AppColors colors, {
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.tag,
              size: 44,
              color: colors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              QuietButton(
                label: actionLabel,
                icon: PhosphorIconsRegular.plus,
                variant: QuietButtonVariant.secondary,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
