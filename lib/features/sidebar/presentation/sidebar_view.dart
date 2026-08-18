import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../notes/application/notes_provider.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import 'widgets/sidebar_item.dart';
import 'widgets/tag_browser_sheet.dart';

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

    return Container(
      color: colors.surface,
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
                        color: colors.textPrimary,
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
                      icon: Icons.menu_open_rounded,
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
                color: colors.background,
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
                          Icons.search_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: Text(
                            'Search notes...',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textTertiary,
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
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LIBRARY Section Header
                    _buildSectionHeader(context, 'LIBRARY'),

                    SidebarItem(
                      icon: Icons.description_outlined,
                      label: 'All Notes',
                      count: activeCount,
                      isSelected: currentDestination == AppDestination.allNotes &&
                          selectedTag == null,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.allNotes;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: Icons.push_pin_outlined,
                      label: 'Pinned',
                      count: pinnedCount,
                      isSelected: currentDestination == AppDestination.pinned,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.pinned;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: Icons.archive_outlined,
                      label: 'Archive',
                      count: archiveCount,
                      isSelected: currentDestination == AppDestination.archive,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.archive;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        onItemSelected?.call();
                      },
                    ),

                    SidebarItem(
                      icon: Icons.delete_outline_rounded,
                      label: 'Trash',
                      count: trashCount,
                      isSelected: currentDestination == AppDestination.trash,
                      onTap: () {
                        ref.read(currentDestinationProvider.notifier).state =
                            AppDestination.trash;
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        onItemSelected?.call();
                      },
                    ),

                    // TAGS Section
                    tagsAsync.when(
                      data: (tags) {
                        if (tags.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final displayTags = tags.take(_maxVisibleTags).toList();
                        final hasMore = tags.length > _maxVisibleTags;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.md),
                            _buildSectionHeader(context, 'TAGS'),
                            ...displayTags.map((t) {
                              final isTagSelected =
                                  (currentDestination == AppDestination.tag ||
                                          currentDestination == AppDestination.allNotes) &&
                                      selectedTag == t.tag.name;

                              return SidebarItem(
                                icon: Icons.tag_rounded,
                                label: t.tag.name,
                                count: t.noteCount,
                                isSelected: isTagSelected,
                                onTap: () {
                                  ref
                                      .read(currentDestinationProvider.notifier)
                                      .state = AppDestination.tag;
                                  ref
                                      .read(selectedTagFilterProvider.notifier)
                                      .state = t.tag.name;
                                  onItemSelected?.call();
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
                                    onItemSelected?.call();
                                    TagBrowserSheet.show(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                      vertical: 6.0,
                                    ),
                                    child: Text(
                                      'Show all tags (${tags.length})...',
                                      style: AppTypography.caption.copyWith(
                                        color: colors.accent,
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

            // Bottom Divider & Settings Row
            Divider(color: colors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: SidebarItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  onItemSelected?.call();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          fontSize: 11.5,
        ),
      ),
    );
  }
}
