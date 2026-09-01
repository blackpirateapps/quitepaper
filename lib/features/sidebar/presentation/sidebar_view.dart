import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/notes_query_provider.dart';
import '../../notes/application/saved_filters_provider.dart';
import '../../notes/domain/saved_filter.dart';
import '../../notes/presentation/widgets/saved_filters_sheet.dart';
import '../../search/presentation/search_screen.dart';
import '../../../core/database/app_database.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tags/application/tag_providers.dart';
import '../../tags/domain/tag_colors.dart';
import '../../tags/domain/tag_icon_registry.dart';
import '../../tags/domain/tag_model.dart';
import '../../tags/presentation/widgets/tag_action_dialogs.dart';
import '../../tags/presentation/widgets/tag_color_picker_sheet.dart';
import '../../tags/presentation/widgets/tag_icon_picker_sheet.dart';
import '../../web_clipper/presentation/web_clip_dialog.dart';
import 'widgets/sidebar_item.dart';

class SidebarView extends ConsumerWidget {
  const SidebarView({
    super.key,
    this.onItemSelected,
    this.isCollapsible = false,
  });

  /// Optional callback when a destination or item is selected (e.g. to close drawer on mobile)
  final VoidCallback? onItemSelected;

  /// Whether to display a collapse button (on tablet/desktop split view)
  final bool isCollapsible;

  static const int _maxVisibleTags = 7;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentDestination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);

    final activeCount = ref.watch(activeNotesCountProvider).valueOrNull;
    final pinnedCount = ref.watch(pinnedNotesCountProvider).valueOrNull;
    final archiveCount = ref.watch(archivedNotesCountProvider).valueOrNull;
    final trashCount = ref.watch(trashedNotesCountProvider).valueOrNull;
    final tagsAsync = ref.watch(allTagsStreamProvider);

    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final headerTextColor = isSidebarDark ? const Color(0xFFF1F2F4) : colors.textPrimary;
    final searchBgColor = isSidebarDark ? colors.sidebarSelected : colors.background;
    final searchHintColor = isSidebarDark ? const Color(0xFF9CA3AF) : colors.textTertiary;
    final searchIconColor = isSidebarDark ? const Color(0xFF9CA3AF) : colors.textSecondary;
    final sidebarDividerColor = isSidebarDark ? const Color(0xFF2D333B) : colors.divider;

    return Container(
      color: colors.sidebarBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Header & Branding
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quiet Paper',
                      style: AppTypography.title.copyWith(
                        color: headerTextColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (isCollapsible)
                    QuietIconButton(
                      icon: PhosphorIconsRegular.sidebarSimple,
                      tooltip: 'Hide navigation sidebar',
                      onPressed: () {
                        ref.read(isNavSidebarVisibleProvider.notifier).state =
                            false;
                      },
                    ),
                ],
              ),
            ),

            // Global Search entry button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Material(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: InkWell(
                  onTap: () {
                    onItemSelected?.call();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 9.0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 18,
                          color: searchIconColor,
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'Search notes...',
                            style: AppTypography.bodySmall.copyWith(
                              color: searchHintColor,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // Scrollable navigation list (Library + Tags)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, AppSpacing.xs, 0, AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIBRARY Section Header
                    _buildSectionHeader(context, 'LIBRARY'),

                    SidebarItem(
                      icon: PhosphorIconsRegular.note,
                      label: 'All Notes',
                      count: activeCount,
                      isSelected: currentDestination == AppDestination.allNotes &&
                          selectedTag == null,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.allNotes;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        ref.read(notesQueryProvider.notifier).clearAllFilters();
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: currentDestination == AppDestination.pinned
                          ? PhosphorIconsFill.pushPin
                          : PhosphorIconsRegular.pushPin,
                      label: 'Pinned',
                      count: pinnedCount,
                      isSelected: currentDestination == AppDestination.pinned,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.pinned;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        ref.read(notesQueryProvider.notifier).clearAllFilters();
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: currentDestination == AppDestination.archive
                          ? PhosphorIconsFill.archive
                          : PhosphorIconsRegular.archive,
                      label: 'Archive',
                      count: archiveCount,
                      isSelected: currentDestination == AppDestination.archive,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.archive;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        ref.read(notesQueryProvider.notifier).clearAllFilters();
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: currentDestination == AppDestination.trash
                          ? PhosphorIconsFill.trash
                          : PhosphorIconsRegular.trash,
                      label: 'Trash',
                      count: trashCount,
                      isSelected: currentDestination == AppDestination.trash,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.trash;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        ref.read(notesQueryProvider.notifier).clearAllFilters();
                        onItemSelected?.call();
                      },
                    ),

                    // SMART VIEWS Section (if any saved views exist)
                    Builder(
                      builder: (ctx) {
                        final savedFilters = ref.watch(savedFiltersProvider);
                        if (savedFilters.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            _buildSectionHeader(
                              context,
                              'SMART VIEWS',
                              trailing: SizedBox(
                                height: 28,
                                width: 28,
                                child: QuietIconButton(
                                  icon: PhosphorIconsRegular.slidersHorizontal,
                                  size: 16,
                                  padding: const EdgeInsets.all(4.0),
                                  tooltip: 'Manage smart views',
                                  onPressed: () {
                                    onItemSelected?.call();
                                    SavedFiltersSheet.show(context);
                                  },
                                ),
                              ),
                            ),
                            ...savedFilters.map((sv) {
                              return SidebarItem(
                                icon: PhosphorIconsRegular.bookmarkSimple,
                                label: sv.name,
                                onTap: () {
                                  ref.read(notesQueryProvider.notifier).setFilters(sv.query.filter);
                                  ref.read(notesQueryProvider.notifier).setSort(sv.query.sort);
                                  onItemSelected?.call();
                                },
                                onLongPress: () => _showSmartViewOptions(context, ref, sv),
                                onSecondaryTap: () => _showSmartViewOptions(context, ref, sv),
                              );
                            }),
                          ],
                        );
                      },
                    ),

                    // TAGS Section
                    tagsAsync.when(
                      data: (tags) {
                        if (tags.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final isDark = Theme.of(context).brightness == Brightness.dark;

                        // Sort tags: pinned first (by pinnedOrder), then active note count
                        final sortedTags = List<TagWithCount>.from(tags)..sort((a, b) {
                          if (a.isPinned && !b.isPinned) return -1;
                          if (!a.isPinned && b.isPinned) return 1;
                          if (a.isPinned && b.isPinned) {
                            return a.pinnedOrder.compareTo(b.pinnedOrder);
                          }
                          return b.noteCount.compareTo(a.noteCount);
                        });

                        final displayTags = sortedTags.take(_maxVisibleTags).toList();
                        final hasMore = sortedTags.length > _maxVisibleTags;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            _buildSectionHeader(
                              context,
                              'TAGS',
                              trailing: SizedBox(
                                height: 28,
                                width: 28,
                                child: QuietIconButton(
                                  icon: PhosphorIconsRegular.slidersHorizontal,
                                  size: 16,
                                  padding: const EdgeInsets.all(4.0),
                                  tooltip: 'Manage tags',
                                  onPressed: () {
                                    ref.read(currentDestinationProvider.notifier).state =
                                        AppDestination.tagBrowser;
                                    ref.read(selectedTagFilterProvider.notifier).state = null;
                                    ref.read(selectedTagIdProvider.notifier).state = null;
                                    onItemSelected?.call();
                                  },
                                ),
                              ),
                            ),
                            ...displayTags.map((t) {
                              final isTagSelected =
                                  currentDestination == AppDestination.tag &&
                                      selectedTag == t.name;

                              final colorDef = TagColors.fromId(t.color);
                              final customColor = colorDef?.foreground(isDark);
                              final iconData = TagIconRegistry.getIconData(
                                t.icon,
                                fallback: t.isPinned
                                    ? PhosphorIconsFill.pushPin
                                    : PhosphorIconsRegular.tag,
                              );

                              return SidebarItem(
                                icon: iconData,
                                label: t.name,
                                count: t.noteCount,
                                isSelected: isTagSelected,
                                customIconColor: customColor,
                                onTap: () {
                                  ref
                                      .read(currentDestinationProvider.notifier)
                                      .state = AppDestination.tag;
                                  ref
                                      .read(selectedTagFilterProvider.notifier)
                                      .state = t.name;
                                  ref
                                      .read(selectedTagIdProvider.notifier)
                                      .state = t.id;
                                  ref
                                      .read(notesQueryProvider.notifier)
                                      .setTag(t.name);
                                  onItemSelected?.call();
                                },
                                onLongPress: () {
                                  _showTagOptions(context, ref, t);
                                },
                                onSecondaryTap: () {
                                  _showTagOptions(context, ref, t);
                                },
                              );
                            }),
                            if (hasMore) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: 4.0,
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadii.sm),
                                  onTap: () {
                                    ref.read(currentDestinationProvider.notifier).state =
                                        AppDestination.tagBrowser;
                                    ref.read(selectedTagFilterProvider.notifier).state = null;
                                    ref.read(selectedTagIdProvider.notifier).state = null;
                                    onItemSelected?.call();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 6.0,
                                    ),
                                    child: Text(
                                      'Show all tags (${tags.length})...',
                                      style: AppTypography.caption.copyWith(
                                        color: currentDestination == AppDestination.tagBrowser
                                            ? colors.accent
                                            : colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Divider & Actions
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 2.0,
              ),
              child: Divider(
                color: sidebarDividerColor,
                height: 1,
                thickness: 0.8,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SidebarItem(
                    icon: PhosphorIconsRegular.globe,
                    label: 'Clip Webpage',
                    onTap: () {
                      onItemSelected?.call();
                      WebClipDialog.show(context);
                    },
                  ),
                  SidebarItem(
                    icon: PhosphorIconsRegular.gearSix,
                    label: 'Settings',
                    onTap: () {
                      onItemSelected?.call();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final colors = context.appColors;
    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final headerColor = isSidebarDark ? const Color(0xFF9CA3AF) : colors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: headerColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              fontSize: 11.5,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Future<void> _showSmartViewOptions(
    BuildContext context,
    WidgetRef ref,
    SavedFilter sv,
  ) async {
    final colors = context.appColors;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Material(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sv.name,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(color: colors.divider, height: 1),
                  ListTile(
                    leading: Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: colors.textPrimary),
                    title: Text(
                      'Rename',
                      style: AppTypography.body.copyWith(color: colors.textPrimary),
                    ),
                    onTap: () => Navigator.of(ctx).pop('rename'),
                  ),
                  ListTile(
                    leading: Icon(PhosphorIconsRegular.trash, size: 20, color: colors.error),
                    title: Text(
                      'Delete',
                      style: AppTypography.body.copyWith(color: colors.error),
                    ),
                    onTap: () => Navigator.of(ctx).pop('delete'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (action == 'rename' && context.mounted) {
      await _renameSmartViewDialog(context, ref, sv);
    } else if (action == 'delete' && context.mounted) {
      await _deleteSmartViewConfirmation(context, ref, sv);
    }
  }

  Future<void> _renameSmartViewDialog(
    BuildContext context,
    WidgetRef ref,
    SavedFilter sv,
  ) async {
    final controller = TextEditingController(text: sv.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLg,
            side: BorderSide(color: colors.divider, width: 0.8),
          ),
          title: Text(
            'Rename Smart View',
            style: AppTypography.headline.copyWith(color: colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'View Name',
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderMd,
                borderSide: BorderSide(color: colors.divider, width: 0.8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ),
            QuietButton(
              label: 'Save',
              variant: QuietButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty) {
        await ref.read(savedFiltersProvider.notifier).rename(sv.id, newName);
      }
    }
  }

  Future<void> _deleteSmartViewConfirmation(
    BuildContext context,
    WidgetRef ref,
    SavedFilter sv,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLg,
            side: BorderSide(color: colors.divider, width: 0.8),
          ),
          title: Text(
            'Delete Smart View',
            style: AppTypography.headline.copyWith(color: colors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to delete "${sv.name}"? This cannot be undone.',
            style: AppTypography.body.copyWith(color: colors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary),
              ),
            ),
            QuietButton(
              label: 'Delete',
              variant: QuietButtonVariant.destructive,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await ref.read(savedFiltersProvider.notifier).delete(sv.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Smart view "${sv.name}" deleted'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showTagOptions(BuildContext context, WidgetRef ref, TagWithCount t) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = TagColors.fromId(t.color);

    final tag = Tag(
      id: t.tag.id,
      name: t.name,
      icon: t.icon,
      color: t.color,
      isPinned: t.isPinned,
      pinnedOrder: t.pinnedOrder,
      createdAt: t.tag.createdAt ?? DateTime.now(),
      updatedAt: t.tag.updatedAt ?? DateTime.now(),
      noteCount: t.noteCount,
    );

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
                      TagIconRegistry.getIconData(t.icon),
                      size: 20,
                      color: colorDef?.foreground(isDark) ?? colors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#${t.name}',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${t.noteCount} note${t.noteCount == 1 ? '' : 's'}',
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
                  ref.read(currentDestinationProvider.notifier).state = AppDestination.tag;
                  ref.read(selectedTagFilterProvider.notifier).state = t.name;
                  ref.read(selectedTagIdProvider.notifier).state = t.id;
                  ref.read(notesQueryProvider.notifier).setTag(t.name);
                  onItemSelected?.call();
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(
                  t.isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
                  size: 20,
                  color: t.isPinned ? colors.accent : colors.textSecondary,
                ),
                title: Text(
                  t.isPinned ? 'Unpin tag' : 'Pin to top',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ref.read(tagServiceProvider).pinTag(t.id, !t.isPinned);
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(PhosphorIconsRegular.pencilSimple, size: 20, color: colors.textSecondary),
                title: Text(
                  'Rename',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
                  final existingNames = allTags.map((x) => x.name).toList();
                  final newName = await TagRenameDialog.show(
                    context,
                    tag: tag,
                    existingTags: existingNames,
                  );
                  if (newName != null && newName != tag.name && context.mounted) {
                    await ref.read(tagServiceProvider).renameTag(tag.id, newName);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(selectedTagFilterProvider.notifier).state = newName;
                      ref.read(notesQueryProvider.notifier).setTag(newName);
                    }
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(PhosphorIconsRegular.smiley, size: 20, color: colors.textSecondary),
                title: Text(
                  t.icon != null ? 'Change icon' : 'Add icon',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final newIcon = await TagIconPickerSheet.show(
                    context,
                    currentIconId: t.icon,
                    tagName: t.name,
                  );
                  if (context.mounted) {
                    await ref.read(tagServiceProvider).setTagIcon(t.id, newIcon);
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(PhosphorIconsRegular.palette, size: 20, color: colors.textSecondary),
                title: Text(
                  t.color != null ? 'Change color' : 'Add color',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final newColor = await TagColorPickerSheet.show(
                    context,
                    currentColorId: t.color,
                  );
                  if (context.mounted) {
                    await ref.read(tagServiceProvider).setTagColor(t.id, newColor);
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(PhosphorIconsRegular.gitMerge, size: 20, color: colors.textSecondary),
                title: Text(
                  'Merge into...',
                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
                  final destination = await TagMergeDialog.show(
                    context,
                    sourceTag: tag,
                    availableTags: allTags,
                  );
                  if (destination != null && context.mounted) {
                    await ref.read(tagServiceProvider).mergeTags(tag.id, destination.id);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(selectedTagFilterProvider.notifier).state = destination.name;
                      ref.read(selectedTagIdProvider.notifier).state = destination.id;
                      ref.read(notesQueryProvider.notifier).setTag(destination.name);
                    }
                  }
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(PhosphorIconsRegular.trash, size: 20, color: colors.error),
                title: Text(
                  'Delete tag',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final confirmed = await TagDeleteDialog.show(context, tag: tag);
                  if (confirmed == true && context.mounted) {
                    await ref.read(tagServiceProvider).deleteTag(tag.id);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(currentDestinationProvider.notifier).state = AppDestination.allNotes;
                      ref.read(selectedTagFilterProvider.notifier).state = null;
                      ref.read(selectedTagIdProvider.notifier).state = null;
                      ref.read(notesQueryProvider.notifier).clearAllFilters();
                    }
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
