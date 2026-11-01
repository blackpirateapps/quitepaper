import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/platform_layout_helper.dart';
import '../../../../core/widgets/quiet_adaptive_modal.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../notes/application/notes_query_provider.dart';
import '../../application/tag_providers.dart';
import '../../domain/tag_icon_registry.dart';
import '../../domain/tag_model.dart';
import '../../domain/tag_path.dart';
import '../../domain/tag_tree.dart';
import 'tag_action_dialogs.dart';
import 'tag_color_picker_sheet.dart';
import 'tag_icon_picker_sheet.dart';

/// Tag Browser view with Bear Notes editorial aesthetic.
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

  void _clearSearch() {
    _searchController.clear();
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

  Future<void> _handleAddNestedTag(Tag parentTag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    final existingNames = allTags.map((t) => t.name).toList();

    final newTag = await TagCreateDialog.showNested(
      context,
      parentTag: parentTag,
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
      final currentExpanded = ref.read(expandedTagPathsProvider);
      if (!currentExpanded.contains(parentTag.name)) {
        ref.read(expandedTagPathsProvider.notifier).toggle(parentTag.name);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nested tag #${newTag.name} created'),
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
    final allTags = ref.read(allTagsProvider).valueOrNull ?? const <Tag>[];
    final hasDescendants = allTags.any(
      (candidate) => candidate.name.startsWith('${tag.name}/'),
    );
    final mode = await TagDeleteDialog.showWithMode(
      context,
      tag: tag,
      hasDescendants: hasDescendants,
    );
    if (mode != null && mounted) {
      final service = ref.read(tagServiceProvider);
      await service.deleteTag(tag.id, mode: mode);
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
            content: Text(
              'Merged #${sourceTag.name} into #${destination.name}',
            ),
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

  void _showTagOptions(
    BuildContext context,
    Tag tag, {
    BuildContext? anchorContext,
    Offset? cursorPosition,
    PopoverAlignment? alignment,
  }) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = tag.colorDefinition;
    final hasCustomIcon = tag.icon != null && tag.icon!.isNotEmpty;

    QuietAdaptiveModal.show(
      context: context,
      type: AdaptiveModalType.popover,
      anchorContext: anchorContext,
      cursorPosition: cursorPosition,
      alignment:
          alignment ??
          (cursorPosition != null
              ? PopoverAlignment.auto
              : PopoverAlignment.end),
      maxWidth: 290,
      builder: (ctx) => Material(
        color: PlatformLayoutHelper.isDesktop(context)
            ? Colors.transparent
            : colors.surface,
        borderRadius: PlatformLayoutHelper.isDesktop(context)
            ? null
            : const BorderRadius.vertical(top: AppRadii.rLg),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdaptiveSheetDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.borderSubtle,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: hasCustomIcon
                            ? Icon(
                                TagIconRegistry.getIconData(tag.icon),
                                size: 18,
                                color: colorDef?.foreground(isDark) ??
                                    colors.accent,
                              )
                            : Text(
                                '#',
                                style: GoogleFonts.newsreader(
                                  textStyle:
                                      const TextStyle(fontFamily: 'serif'),
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: colorDef?.foreground(isDark) ??
                                      colors.accent,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${tag.name}',
                            style: GoogleFonts.newsreader(
                              textStyle: const TextStyle(fontFamily: 'serif'),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Tag options & styling',
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${tag.noteCount}',
                        style: GoogleFonts.jetBrainsMono(
                          textStyle: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                            fontFamily: 'monospace',
                          ),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
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
                  PhosphorIconsRegular.folderPlus,
                  size: 20,
                  color: colors.textSecondary,
                ),
                title: Text(
                  'Add nested tag',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleAddNestedTag(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  tag.isPinned
                      ? PhosphorIconsFill.pushPin
                      : PhosphorIconsRegular.pushPin,
                  size: 20,
                  color: tag.isPinned ? colors.accent : colors.textSecondary,
                ),
                title: Text(
                  tag.isPinned ? 'Unpin tag' : 'Pin to top',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 20,
                  color: colors.textSecondary,
                ),
                title: Text(
                  'Rename',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
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
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChangeIcon(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  PhosphorIconsRegular.palette,
                  size: 20,
                  color: colors.textSecondary,
                ),
                title: Text(
                  tag.color != null ? 'Change color' : 'Add color',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleChangeColor(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  PhosphorIconsRegular.gitMerge,
                  size: 20,
                  color: colors.textSecondary,
                ),
                title: Text(
                  'Merge into...',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleMerge(tag);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  PhosphorIconsRegular.trash,
                  size: 20,
                  color: colors.error,
                ),
                title: Text(
                  'Delete tag',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleDelete(tag);
                },
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }

  String _getSortIndicatorLabel(TagSort sort) {
    switch (sort) {
      case TagSort.name:
        return 'Sorted A–Z';
      case TagSort.noteCount:
        return 'Sorted by notes';
      case TagSort.recentlyUsed:
        return 'Sorted by recent';
      case TagSort.recentlyCreated:
        return 'Sorted by created';
      case TagSort.custom:
        return 'Sorted custom';
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filteredTagsAsync = ref.watch(filteredBrowserTagsProvider);
    final pinnedTags = ref.watch(pinnedTagsProvider);
    final activeFilter = ref.watch(tagFilterProvider);
    final activeSort = ref.watch(tagSortProvider);
    final query = ref.watch(tagSearchQueryProvider);
    final expandedPaths = ref.watch(expandedTagPathsProvider);
    final totalCount = ref.watch(allTagsProvider).valueOrNull?.length ?? 0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_searchController.text.isNotEmpty) {
            _clearSearch();
          } else {
            widget.onClose?.call();
          }
        },
      },
      child: Container(
        color: colors.background,
        child: Column(
          children: [
            // Editorial Masthead and Toolbar
            _buildMastheadAndToolbar(
              context,
              colors,
              activeSort,
              activeFilter,
              totalCount,
            ),
            Divider(color: colors.divider, height: 1),

            // Tag List Body
            Expanded(
              child: filteredTagsAsync.when(
                data: (tags) {
                  final allRawTags =
                      ref.watch(allTagsProvider).valueOrNull ?? [];

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
                      title: query.isNotEmpty
                          ? 'No matching tags'
                          : 'No tags match this filter',
                      subtitle: query.isNotEmpty
                          ? 'No tags found matching "$query".'
                          : 'Try changing your active filter or clear search.',
                    );
                  }

                  // Filtered or searched view (Flat scannable list)
                  final isFilteredOrSorted =
                      query.isNotEmpty ||
                      activeFilter != TagFilter.all ||
                      activeSort != TagSort.name;

                  if (!isFilteredOrSorted) {
                    final unpinnedTags =
                        tags.where((t) => !t.isPinned).toList();
                    final tree = TagTree.build(unpinnedTags);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.xs,
                        AppSpacing.sm,
                        48,
                      ),
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      children: [
                        if (pinnedTags.isNotEmpty) ...[
                          _buildSectionHeader(
                            colors,
                            'PINNED',
                            pinnedTags.length,
                          ),
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: pinnedTags.length,
                            // ignore: deprecated_member_use
                            onReorder: (oldIdx, newIdx) {
                              final list = List<Tag>.from(pinnedTags);
                              if (newIdx > oldIdx) newIdx -= 1;
                              final item = list.removeAt(oldIdx);
                              list.insert(newIdx, item);
                              ref
                                  .read(tagServiceProvider)
                                  .reorderPinnedTags(
                                    list.map((t) => t.id).toList(),
                                  );
                            },
                            itemBuilder: (ctx, index) {
                              final item = pinnedTags[index];
                              return ReorderableDelayedDragStartListener(
                                key: ValueKey('pinned_${item.id}'),
                                index: index,
                                child: _TagRowWidget(
                                  tag: item,
                                  colors: colors,
                                  isDark: isDark,
                                  hidePinGlyph: true,
                                  onTap: () => _handleTagTap(item),
                                  onOptions: (c, {position}) =>
                                      _showTagOptions(
                                    c,
                                    item,
                                    anchorContext: c,
                                    cursorPosition: position,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _buildSectionHeader(
                            colors,
                            'ALL TAGS',
                            unpinnedTags.length,
                          ),
                        ],
                        for (final rootNode in tree.roots)
                          _TagTreeNodeWidget(
                            key: ValueKey('tree_node_${rootNode.tag.id}'),
                            node: rootNode,
                            expandedPaths: expandedPaths,
                            colors: colors,
                            isDark: isDark,
                            onTap: _handleTagTap,
                            onToggle: (p) => ref
                                .read(expandedTagPathsProvider.notifier)
                                .toggle(p),
                            onOptions: (c, t, {position}) => _showTagOptions(
                              c,
                              t,
                              anchorContext: c,
                              cursorPosition: position,
                            ),
                          ),
                      ],
                    );
                  }

                  // Flat list for search / sorted / filtered results
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      48,
                    ),
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    itemCount: tags.length,
                    itemBuilder: (ctx, index) {
                      final item = tags[index];
                      return _TagRowWidget(
                        key: ValueKey('tag_${item.id}'),
                        tag: item,
                        colors: colors,
                        isDark: isDark,
                        onTap: () => _handleTagTap(item),
                        onOptions: (c, {position}) => _showTagOptions(
                          c,
                          item,
                          anchorContext: c,
                          cursorPosition: position,
                        ),
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator.adaptive()),
                error: (err, _) => Center(
                  child: Text(
                    'Error loading tags: $err',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMastheadAndToolbar(
    BuildContext context,
    AppColors colors,
    TagSort activeSort,
    TagFilter activeFilter,
    int totalCount,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Lightweight Toolbar Row
          Row(
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
                  tooltip: widget.isSidebarVisible
                      ? 'Hide navigation'
                      : 'Show navigation',
                  onPressed: widget.onToggleSidebar,
                ),
              const Spacer(),

              // Hierarchy Tree pill button
              SizedBox(
                height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Tag hierarchy options',
                  color: colors.surface,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.borderMd,
                    side: BorderSide(color: colors.divider, width: 0.8),
                  ),
                  onSelected: (val) {
                    if (val == 'tree_expand_all') {
                      final allTags =
                          ref.read(allTagsProvider).valueOrNull ?? [];
                      final tree = TagTree.build(allTags);
                      ref.read(expandedTagPathsProvider.notifier).expandAll(
                            tree.nodesByPath.values
                                .where((n) => n.hasChildren)
                                .map((n) => n.path?.value ?? n.tag.name),
                          );
                    } else if (val == 'tree_collapse_all') {
                      ref
                          .read(expandedTagPathsProvider.notifier)
                          .collapseAll();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'tree_expand_all',
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Expand all sub-tags',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'tree_collapse_all',
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Collapse all sub-tags',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: colors.borderSubtle, width: 1.0),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.treeStructure,
                          size: 15,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Tree',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Sort & Filter combined menu button
              SizedBox(
                height: 32,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Sort and filter tags',
                  color: colors.surface,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.borderMd,
                    side: BorderSide(color: colors.divider, width: 0.8),
                  ),
                  onSelected: (val) {
                    if (val.startsWith('sort_')) {
                      final sortName = val.substring(5);
                      final sort = TagSort.values.firstWhere(
                        (s) => s.name == sortName,
                      );
                      ref.read(tagSortProvider.notifier).state = sort;
                    } else if (val.startsWith('filter_')) {
                      final filterName = val.substring(7);
                      final filter = TagFilter.values.firstWhere(
                        (f) => f.name == filterName,
                      );
                      ref.read(tagFilterProvider.notifier).state = filter;
                    } else if (val == 'tree_expand_all') {
                      final allTags =
                          ref.read(allTagsProvider).valueOrNull ?? [];
                      final tree = TagTree.build(allTags);
                      ref.read(expandedTagPathsProvider.notifier).expandAll(
                            tree.nodesByPath.values
                                .where((n) => n.hasChildren)
                                .map((n) => n.path?.value ?? n.tag.name),
                          );
                    } else if (val == 'tree_collapse_all') {
                      ref
                          .read(expandedTagPathsProvider.notifier)
                          .collapseAll();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 26,
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
                                  color: activeSort == s
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontWeight: activeSort == s
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (activeSort == s)
                              Icon(
                                PhosphorIconsRegular.check,
                                size: 16,
                                color: colors.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 26,
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
                                  color: activeFilter == f
                                      ? colors.accent
                                      : colors.textPrimary,
                                  fontWeight: activeFilter == f
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (activeFilter == f)
                              Icon(
                                PhosphorIconsRegular.check,
                                size: 16,
                                color: colors.accent,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      enabled: false,
                      height: 26,
                      child: Text(
                        'HIERARCHY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'tree_expand_all',
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.caretDown,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Expand all sub-tags',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'tree_collapse_all',
                      child: Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: colors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Collapse all sub-tags',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: activeFilter != TagFilter.all
                          ? colors.accentSoft
                          : colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: activeFilter != TagFilter.all
                            ? colors.accent
                            : colors.borderSubtle,
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        activeFilter != TagFilter.all
                            ? PhosphorIconsFill.funnel
                            : PhosphorIconsRegular.slidersHorizontal,
                        size: 15,
                        color: activeFilter != TagFilter.all
                            ? colors.accent
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // Bear Signature Accent "+ New" Tag Pill
              Material(
                color: colors.accent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _handleCreateTag,
                  child: Tooltip(
                    message: 'New tag',
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            PhosphorIconsRegular.plus,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'New',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 2. Editorial Serif Title Row with Total Tag Count Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Tags',
                style: GoogleFonts.newsreader(
                  textStyle: const TextStyle(fontFamily: 'serif'),
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: colors.borderSubtle, width: 1.0),
                ),
                child: Text(
                  '$totalCount',
                  style: GoogleFonts.jetBrainsMono(
                    textStyle: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontFamily: 'monospace',
                    ),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              Flexible(
                child: InkWell(
                  onTap: () {
                    ref.read(tagSortProvider.notifier).state =
                        activeSort == TagSort.name
                            ? TagSort.noteCount
                            : TagSort.name;
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      _getSortIndicatorLabel(activeSort),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: GoogleFonts.newsreader(
                        textStyle: const TextStyle(fontFamily: 'serif'),
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 3. Integrated Soft-Inset Search Bar
          Tooltip(
            message: 'Search tags',
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: colors.surfaceSecondary,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border:
                    Border.all(color: colors.borderSubtle, width: 1.0),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 15,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Filter $totalCount tags or #journal/...',
                        hintStyle: AppTypography.bodySmall.copyWith(
                          color: colors.textTertiary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      icon: Icon(
                        PhosphorIconsRegular.xCircle,
                        color: colors.textTertiary,
                      ),
                      tooltip: 'Clear search',
                      onPressed: _clearSearch,
                    ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // 4. Quick Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  isSelected: activeFilter == TagFilter.all,
                  colors: colors,
                  onTap: () => ref.read(tagFilterProvider.notifier).state =
                      TagFilter.all,
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'Pinned',
                  isSelected: activeFilter == TagFilter.pinned,
                  colors: colors,
                  onTap: () => ref.read(tagFilterProvider.notifier).state =
                      TagFilter.pinned,
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'TagCons',
                  isSelected: activeFilter == TagFilter.hasIcon,
                  colors: colors,
                  onTap: () => ref.read(tagFilterProvider.notifier).state =
                      TagFilter.hasIcon,
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'With Notes',
                  isSelected: activeFilter == TagFilter.hasNotes,
                  colors: colors,
                  onTap: () => ref.read(tagFilterProvider.notifier).state =
                      TagFilter.hasNotes,
                ),
                const SizedBox(width: 5),
                _buildFilterChip(
                  label: 'Unused',
                  isSelected: activeFilter == TagFilter.unused,
                  colors: colors,
                  onTap: () => ref.read(tagFilterProvider.notifier).state =
                      TagFilter.unused,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? colors.accent : colors.borderSubtle,
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isSelected ? colors.accent : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(AppColors colors, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle, width: 0.8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.jetBrainsMono(
                textStyle: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontFamily: 'monospace',
                ),
                color: colors.textSecondary,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Divider(
              color: colors.divider,
              thickness: 0.7,
              height: 1,
            ),
          ),
        ],
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
            Text(
              '#',
              style: GoogleFonts.newsreader(
                textStyle: const TextStyle(fontFamily: 'serif'),
                fontSize: 48,
                fontStyle: FontStyle.italic,
                color: colors.textTertiary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: GoogleFonts.newsreader(
                textStyle: const TextStyle(fontFamily: 'serif'),
                color: colors.textPrimary,
                fontSize: 18,
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

/// Row architecture adhering to the "Single Signifier" Pure Bear design.
class _TagRowWidget extends StatelessWidget {
  const _TagRowWidget({
    super.key,
    required this.tag,
    required this.colors,
    required this.isDark,
    this.hasChildren = false,
    this.isExpanded = false,
    this.hidePinGlyph = false,
    this.onTap,
    this.onToggle,
    this.onOptions,
  });

  final Tag tag;
  final AppColors colors;
  final bool isDark;
  final bool hasChildren;
  final bool isExpanded;
  final bool hidePinGlyph;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final void Function(BuildContext context, {Offset? position})? onOptions;

  @override
  Widget build(BuildContext context) {
    final colorDef = tag.colorDefinition;
    final path = TagPath.tryParse(tag.name);
    final displayName = path != null ? path.leaf : tag.name;
    final fullLabel = path?.token ?? '#${tag.name}';
    final hasCustomIcon = tag.icon != null && tag.icon!.isNotEmpty;
    final isZero = tag.noteCount == 0;

    return Semantics(
      label: '$fullLabel, ${tag.noteCount} notes'
          '${tag.isPinned ? ', pinned' : ''}'
          '${tag.isImplicit ? ', implicit parent tag' : ''}',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Builder(
          builder: (rowContext) => InkWell(
            borderRadius: BorderRadius.circular(AppRadii.md),
            splashColor: colors.surfaceSecondary.withValues(alpha: 0.5),
            highlightColor: colors.surfaceSecondary.withValues(alpha: 0.35),
            hoverColor: colors.surfaceSubtle.withValues(alpha: 0.5),
            onTap: onTap,
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onOptions?.call(rowContext);
            },
            onSecondaryTapUp: (details) =>
                onOptions?.call(rowContext, position: details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 10.5,
              ),
              child: Row(
                children: [
                  // Left Icon Slot: Fixed width 28px for strict vertical alignment
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onOptions?.call(rowContext);
                        },
                        child: hasCustomIcon
                            ? Icon(
                                TagIconRegistry.getIconData(tag.icon),
                                size: 16,
                                color: colorDef?.foreground(isDark) ??
                                    colors.textSecondary,
                              )
                            : Text(
                                '#',
                                style: GoogleFonts.newsreader(
                                  textStyle:
                                      const TextStyle(fontFamily: 'serif'),
                                  fontSize: 17,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: colorDef?.foreground(isDark) ??
                                      colors.textTertiary,
                                  height: 1.0,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),

                  // Tag Name and Inline Disclosure Chevron
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: AppTypography.body.copyWith(
                              color: isZero
                                  ? colors.textDisabled
                                  : colors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: 14.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        if (hasChildren && onToggle != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onToggle,
                            child: Tooltip(
                              message: isExpanded
                                  ? 'Collapse sub-tags'
                                  : 'Expand sub-tags',
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 6.0,
                                  right: 2.0,
                                ),
                                child: AnimatedRotation(
                                  turns: isExpanded ? 0.25 : 0.0,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  child: Icon(
                                    PhosphorIconsRegular.caretRight,
                                    size: 13,
                                    color: isExpanded
                                        ? colors.accent
                                        : colors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (tag.isPinned && !hidePinGlyph) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Tabular Note Count Right-Aligned
                  Text(
                    '${tag.noteCount}',
                    style: GoogleFonts.jetBrainsMono(
                      textStyle: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontFamily: 'monospace',
                      ),
                      fontSize: 12.5,
                      fontWeight: tag.noteCount >= 50
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color:
                          isZero ? colors.textDisabled : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recursive hierarchy node widget rendering children with a vertical thread guide line.
class _TagTreeNodeWidget extends StatelessWidget {
  const _TagTreeNodeWidget({
    super.key,
    required this.node,
    required this.expandedPaths,
    required this.colors,
    required this.isDark,
    required this.onTap,
    required this.onToggle,
    required this.onOptions,
  });

  final TagTreeNode node;
  final Set<String> expandedPaths;
  final AppColors colors;
  final bool isDark;
  final void Function(Tag tag) onTap;
  final void Function(String path) onToggle;
  final void Function(BuildContext context, Tag tag, {Offset? position})
      onOptions;

  @override
  Widget build(BuildContext context) {
    final path = node.path?.value ?? node.tag.name;
    final isExpanded = expandedPaths.contains(path);
    final hasChildren = node.hasChildren;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TagRowWidget(
          key: ValueKey('all_${node.tag.id}'),
          tag: node.tag,
          colors: colors,
          isDark: isDark,
          hasChildren: hasChildren,
          isExpanded: isExpanded,
          onTap: () {
            if (node.isImplicit && hasChildren) {
              onToggle(path);
              return;
            }
            onTap(node.tag);
          },
          onToggle: hasChildren ? () => onToggle(path) : null,
          onOptions: (ctx, {position}) =>
              onOptions(ctx, node.tag, position: position),
        ),
        if (hasChildren)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Container(
                    margin: const EdgeInsets.only(left: 21.0),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: colors.divider,
                          width: 1.0,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 6.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in node.children)
                          _TagTreeNodeWidget(
                            key: ValueKey('tree_node_${child.tag.id}'),
                            node: child,
                            expandedPaths: expandedPaths,
                            colors: colors,
                            isDark: isDark,
                            onTap: onTap,
                            onToggle: onToggle,
                            onOptions: onOptions,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
