import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../settings/presentation/settings_screen.dart';
import '../../../web_clipper/presentation/web_clip_dialog.dart';
import '../../application/notes_provider.dart';
import '../../application/notes_query_provider.dart';
import '../widgets/notes_filter_sheet.dart';
import '../widgets/notes_sort_sheet.dart';

/// Compact, calm header for the Editorial notes list.
/// Displays dynamic collection title with quick switcher dropdown,
/// new note button, search button, and overflow menu matching the reference design.
class EditorialListHeader extends ConsumerWidget {
  const EditorialListHeader({
    super.key,
    required this.title,
    required this.destination,
    required this.onOpenSearch,
    required this.onCreateNote,
    this.isTablet = false,
    this.isSidebarVisible = true,
    this.onToggleSidebar,
    this.onEmptyTrash,
    this.onHideNoteList,
  });

  final String title;
  final AppDestination destination;
  final VoidCallback onOpenSearch;
  final VoidCallback onCreateNote;
  final bool isTablet;
  final bool isSidebarVisible;
  final VoidCallback? onToggleSidebar;
  final VoidCallback? onEmptyTrash;
  final VoidCallback? onHideNoteList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final query = ref.watch(notesQueryProvider);
    final activeFilterCount = query.filter.advancedFilterCount;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.divider.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Tablet Sidebar toggle icon (if collapsible)
          if (isTablet && onToggleSidebar != null) ...[
            QuietIconButton(
              icon: isSidebarVisible
                  ? Icons.menu_open_rounded
                  : Icons.view_sidebar_outlined,
              tooltip: isSidebarVisible ? 'Hide navigation' : 'Show navigation',
              onPressed: onToggleSidebar!,
            ),
            const SizedBox(width: 2.0),
          ] else if (!isTablet) ...[
            Builder(
              builder: (scaffoldCtx) => QuietIconButton(
                icon: Icons.menu_rounded,
                tooltip: 'Open navigation',
                onPressed: () => Scaffold.of(scaffoldCtx).openDrawer(),
              ),
            ),
            const SizedBox(width: 2.0),
          ],

          // Dynamic Collection Title with Dropdown Affordance
          Expanded(
            child: _buildCollectionDropdown(context, ref, colors),
          ),

          // Action 1: Compose / New Note
          QuietIconButton(
            icon: Icons.edit_square,
            tooltip: 'New note',
            onPressed: onCreateNote,
          ),

          // Action 2: Search Notes
          QuietIconButton(
            icon: Icons.search_rounded,
            tooltip: 'Search notes',
            onPressed: onOpenSearch,
          ),

          // Action 3: Overflow Menu (Sort, Filter, Web Clip, Settings, Trash)
          PopupMenuButton<String>(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.more_horiz_rounded, size: 20),
                if (activeFilterCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'More actions',
            color: colors.surface,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadii.borderMd,
              side: BorderSide(color: colors.divider, width: 0.8),
            ),
            onSelected: (val) {
              if (val == 'sort') {
                NotesSortSheet.show(context);
              } else if (val == 'filter') {
                NotesFilterSheet.show(context);
              } else if (val == 'clip') {
                WebClipDialog.show(context);
              } else if (val == 'settings') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else if (val == 'hide_list') {
                onHideNoteList?.call();
              } else if (val == 'empty_trash') {
                onEmptyTrash?.call();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sort',
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Sort notes',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_list_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      activeFilterCount > 0
                          ? 'Filter notes ($activeFilterCount)'
                          : 'Filter notes',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clip',
                child: Row(
                  children: [
                    Icon(Icons.language_rounded,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Clip webpage',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined,
                        size: 18, color: colors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Settings',
                      style: AppTypography.bodySmall
                          .copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              if (isTablet && onHideNoteList != null)
                PopupMenuItem(
                  value: 'hide_list',
                  child: Row(
                    children: [
                      Icon(Icons.fullscreen_rounded,
                          size: 18, color: colors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Hide note list',
                        style: AppTypography.bodySmall
                            .copyWith(color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              if (destination == AppDestination.trash) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'empty_trash',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever_outlined,
                          size: 18, color: colors.error),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Empty trash',
                        style: AppTypography.bodySmall
                            .copyWith(color: colors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionDropdown(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
  ) {
    return PopupMenuButton<AppDestination>(
      tooltip: 'Switch collection',
      color: colors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderMd,
        side: BorderSide(color: colors.divider, width: 0.8),
      ),
      offset: const Offset(0, 36),
      onSelected: (dest) {
        ref.read(currentDestinationProvider.notifier).state = dest;
        if (dest != AppDestination.tag) {
          ref.read(selectedTagFilterProvider.notifier).state = null;
          ref.read(selectedTagIdProvider.notifier).state = null;
        }
      },
      itemBuilder: (context) => [
        _buildDestItem(
          AppDestination.allNotes,
          'Notes',
          Icons.note_alt_outlined,
          destination == AppDestination.allNotes,
          colors,
        ),
        _buildDestItem(
          AppDestination.pinned,
          'Pinned',
          Icons.push_pin_outlined,
          destination == AppDestination.pinned,
          colors,
        ),
        _buildDestItem(
          AppDestination.archive,
          'Archive',
          Icons.archive_outlined,
          destination == AppDestination.archive,
          colors,
        ),
        _buildDestItem(
          AppDestination.trash,
          'Trash',
          Icons.delete_outline_rounded,
          destination == AppDestination.trash,
          colors,
        ),
        _buildDestItem(
          AppDestination.tagBrowser,
          'Tags',
          Icons.label_outline_rounded,
          destination == AppDestination.tagBrowser ||
              destination == AppDestination.tag,
          colors,
        ),
        _buildDestItem(
          AppDestination.allJournalEntries,
          'Journal',
          Icons.calendar_today_outlined,
          destination == AppDestination.allJournalEntries,
          colors,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4.0),
            Icon(
              CupertinoIcons.chevron_down,
              size: 13,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<AppDestination> _buildDestItem(
    AppDestination dest,
    String label,
    IconData icon,
    bool isSelected,
    AppColors colors,
  ) {
    return PopupMenuItem<AppDestination>(
      value: dest,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isSelected ? colors.accent : colors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: 16,
              color: colors.accent,
            ),
        ],
      ),
    );
  }
}
