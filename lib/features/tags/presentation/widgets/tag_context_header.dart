import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/application/notes_provider.dart';
import '../../../notes/application/notes_query_provider.dart';
import '../../../notes/presentation/widgets/notes_filter_button.dart';
import '../../../web_clipper/presentation/web_clip_dialog.dart';
import '../../application/tag_providers.dart';
import '../../domain/tag_icon_registry.dart';
import '../../domain/tag_model.dart';
import 'tag_action_dialogs.dart';
import 'tag_color_picker_sheet.dart';
import 'tag_icon_picker_sheet.dart';

/// Compact middle-pane header communicating active tag filter context and actions.
class TagContextHeader extends ConsumerWidget implements PreferredSizeWidget {
  const TagContextHeader({
    super.key,
    required this.tagName,
    this.tagId,
    required this.noteCount,
    this.isTablet = false,
    this.isSidebarVisible = true,
    this.onToggleSidebar,
    this.onOpenDrawer,
    this.onSortPressed,
    this.onFilterPressed,
    this.onSearchPressed,
    this.onCreateNotePressed,
    this.advancedFilterCount = 0,
  });

  final String tagName;
  final String? tagId;
  final int noteCount;
  final bool isTablet;
  final bool isSidebarVisible;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onSortPressed;
  final VoidCallback? onFilterPressed;
  final VoidCallback? onSearchPressed;
  final VoidCallback? onCreateNotePressed;
  final int advancedFilterCount;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  Future<void> _handleRename(BuildContext context, WidgetRef ref, Tag tag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
    final existingNames = allTags.map((t) => t.name).toList();

    final newName = await TagRenameDialog.show(
      context,
      tag: tag,
      existingTags: existingNames,
    );

    if (newName != null && newName != tag.name && context.mounted) {
      final service = ref.read(tagServiceProvider);
      try {
        await service.renameTag(tag.id, newName);
        ref.read(selectedTagFilterProvider.notifier).state = newName;
        ref.read(notesQueryProvider.notifier).setTag(newName);

        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tag renamed to #$newName'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
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

  Future<void> _handleDelete(BuildContext context, WidgetRef ref, Tag tag) async {
    final confirmed = await TagDeleteDialog.show(context, tag: tag);
    if (confirmed == true && context.mounted) {
      final service = ref.read(tagServiceProvider);
      await service.deleteTag(tag.id);

      // Return workspace to All Notes
      ref.read(currentDestinationProvider.notifier).state = AppDestination.allNotes;
      ref.read(selectedTagFilterProvider.notifier).state = null;
      ref.read(selectedTagIdProvider.notifier).state = null;
      ref.read(notesQueryProvider.notifier).clearAllFilters();

      if (context.mounted) {
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

  Future<void> _handleMerge(BuildContext context, WidgetRef ref, Tag sourceTag) async {
    final allTags = ref.read(allTagsProvider).valueOrNull ?? [];

    final destination = await TagMergeDialog.show(
      context,
      sourceTag: sourceTag,
      availableTags: allTags,
    );

    if (destination != null && context.mounted) {
      final service = ref.read(tagServiceProvider);
      await service.mergeTags(sourceTag.id, destination.id);

      ref.read(selectedTagFilterProvider.notifier).state = destination.name;
      ref.read(selectedTagIdProvider.notifier).state = destination.id;
      ref.read(notesQueryProvider.notifier).setTag(destination.name);

      if (context.mounted) {
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

  Future<void> _handleChangeIcon(BuildContext context, WidgetRef ref, Tag tag) async {
    final newIcon = await TagIconPickerSheet.show(
      context,
      currentIconId: tag.icon,
      tagName: tag.name,
    );
    if (context.mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagIcon(tag.id, newIcon);
    }
  }

  Future<void> _handleChangeColor(BuildContext context, WidgetRef ref, Tag tag) async {
    final newColor = await TagColorPickerSheet.show(
      context,
      currentColorId: tag.color,
    );
    if (context.mounted) {
      final service = ref.read(tagServiceProvider);
      await service.setTagColor(tag.id, newColor);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve tag entity by ID or name
    final allTags = ref.watch(allTagsProvider).valueOrNull ?? [];
    Tag? tag;
    if (tagId != null) {
      for (final t in allTags) {
        if (t.id == tagId) {
          tag = t;
          break;
        }
      }
    }
    if (tag == null) {
      for (final t in allTags) {
        if (t.name.toLowerCase() == tagName.toLowerCase()) {
          tag = t;
          break;
        }
      }
    }

    final colorDef = tag?.colorDefinition;
    final customColor = colorDef?.foreground(isDark);
    final iconData = TagIconRegistry.getIconData(
      tag?.icon,
      fallback: tag?.isPinned == true ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.tag,
    );

    return Container(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final isVeryNarrow = availableWidth < 310;

            return Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.background,
              ),
              child: Row(
            children: [
              if (onOpenDrawer != null)
                QuietIconButton(
                  icon: PhosphorIconsRegular.list,
                  tooltip: 'Open navigation',
                  onPressed: onOpenDrawer,
                )
              else if (isTablet && onToggleSidebar != null)
                QuietIconButton(
                  icon: isSidebarVisible
                      ? PhosphorIconsRegular.sidebarSimple
                      : PhosphorIconsRegular.sidebarSimple,
                  tooltip: isSidebarVisible ? 'Hide navigation' : 'Show navigation',
                  onPressed: onToggleSidebar,
                ),
              const SizedBox(width: 4.0),

              // Tag Icon & Name
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      iconData,
                      size: 18,
                      color: customColor ?? colors.accent,
                    ),
                    const SizedBox(width: 6.0),
                    Flexible(
                      child: Text(
                        '#$tagName',
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),

              if (!isVeryNarrow) ...[
                if (onSortPressed != null)
                  QuietIconButton(
                    icon: PhosphorIconsRegular.arrowsDownUp,
                    tooltip: 'Sort notes',
                    onPressed: onSortPressed,
                  ),
                if (onFilterPressed != null)
                  NotesFilterButton(
                    advancedFilterCount: advancedFilterCount,
                    onPressed: onFilterPressed!,
                  ),
                if (onSearchPressed != null)
                  QuietIconButton(
                    icon: PhosphorIconsRegular.magnifyingGlass,
                    tooltip: 'Search notes',
                    onPressed: onSearchPressed,
                  ),
              ],

              if (onCreateNotePressed != null)
                QuietIconButton(
                  icon: PhosphorIconsRegular.plus,
                  tooltip: 'New note in #$tagName',
                  isActive: true,
                  onPressed: onCreateNotePressed,
                ),

              // Tag Context Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(PhosphorIconsRegular.dotsThree, size: 20),
                tooltip: 'Tag options',
                color: colors.surface,
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadii.borderMd,
                  side: BorderSide(color: colors.divider, width: 0.8),
                ),
                onSelected: (val) {
                  if (tag == null) return;
                  switch (val) {
                    case 'rename':
                      _handleRename(context, ref, tag);
                      break;
                    case 'icon':
                      _handleChangeIcon(context, ref, tag);
                      break;
                    case 'color':
                      _handleChangeColor(context, ref, tag);
                      break;
                    case 'pin':
                      ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
                      break;
                    case 'merge':
                      _handleMerge(context, ref, tag);
                      break;
                    case 'delete':
                      _handleDelete(context, ref, tag);
                      break;
                    case 'sort':
                      onSortPressed?.call();
                      break;
                    case 'filter':
                      onFilterPressed?.call();
                      break;
                    case 'search':
                      onSearchPressed?.call();
                      break;
                    case 'clip':
                      WebClipDialog.show(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (isVeryNarrow) ...[
                    if (onSortPressed != null)
                      PopupMenuItem(
                        value: 'sort',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.arrowsDownUp, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Sort notes', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                          ],
                        ),
                      ),
                    if (onFilterPressed != null)
                      PopupMenuItem(
                        value: 'filter',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.funnel, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Filter notes', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                          ],
                        ),
                      ),
                    if (onSearchPressed != null)
                      PopupMenuItem(
                        value: 'search',
                        child: Row(
                          children: [
                            Icon(PhosphorIconsRegular.magnifyingGlass, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text('Search notes', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                          ],
                        ),
                      ),
                    const PopupMenuDivider(),
                  ],
                  if (tag != null) ...[
                    PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.pencilSimple, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Rename tag', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'icon',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.smiley, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(tag.icon != null ? 'Change icon' : 'Add icon', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'color',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.palette, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text(tag.color != null ? 'Change color' : 'Add color', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            tag.isPinned ? PhosphorIconsFill.pushPin : PhosphorIconsRegular.pushPin,
                            size: 18,
                            color: tag.isPinned ? colors.accent : colors.textSecondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(tag.isPinned ? 'Unpin tag' : 'Pin tag', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'merge',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.gitMerge, size: 18, color: colors.textSecondary),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Merge into...', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsRegular.trash, size: 18, color: colors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Delete tag', style: AppTypography.bodySmall.copyWith(color: colors.error)),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  PopupMenuItem(
                    value: 'clip',
                    child: Row(
                      children: [
                        Icon(PhosphorIconsRegular.globe, size: 18, color: colors.textSecondary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Clip webpage', style: AppTypography.bodySmall.copyWith(color: colors.textPrimary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  ),
);
  }
}
