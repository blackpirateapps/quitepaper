import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/backup/backup_provider.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/update/update_provider.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_fab.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../sidebar/presentation/sidebar_view.dart';
import '../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../../tags/presentation/tag_browser_screen.dart';
import '../../web_clipper/presentation/web_clip_dialog.dart';
import '../application/notes_provider.dart';
import '../application/notes_query_provider.dart';
import '../data/notes_repository.dart';
import '../domain/note_group.dart';
import '../domain/note_model.dart';
import 'widgets/active_filter_chips.dart';
import 'widgets/note_date_header.dart';
import 'widgets/note_empty_state.dart';
import 'widgets/note_list_tile.dart';
import 'widgets/notes_filter_button.dart';
import 'widgets/notes_filter_sheet.dart';
import 'widgets/notes_loading_more_indicator.dart';
import 'widgets/notes_sort_sheet.dart';
import 'widgets/pull_down_search_reveal.dart';
import 'widgets/tags_filter_bar.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  String? _selectedNoteIdForTablet;
  final Set<String> _selectedNoteIds = {};
  bool _isMultiSelecting = false;
  bool _shouldAutoFocusTablet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnLaunch();
      _performAutoBackupOnLaunch();
    });
  }

  Future<void> _performAutoBackupOnLaunch() async {
    try {
      final backupService = ref.read(backupServiceProvider);
      await backupService.performAutoBackupIfDue();
    } catch (_) {
      // Quiet background failure, ignore
    }
  }

  Future<void> _checkForUpdatesOnLaunch() async {
    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdate();
      if (!mounted) return;

      if (result.hasUpdate && result.latestRelease != null) {
        final release = result.latestRelease!;
        if (!updateService.isSnoozed(release.version)) {
          UpdateDialog.show(
            context,
            release,
            currentVersion: updateService.currentVersion,
          );
        }
      }
    } catch (_) {
      // Quiet background check failure, ignore
    }
  }


  void _exitMultiSelect() {
    setState(() {
      _isMultiSelecting = false;
      _selectedNoteIds.clear();
    });
  }

  void _toggleNoteMultiSelect(String id) {
    setState(() {
      if (_selectedNoteIds.contains(id)) {
        _selectedNoteIds.remove(id);
        if (_selectedNoteIds.isEmpty) {
          _isMultiSelecting = false;
        }
      } else {
        _selectedNoteIds.add(id);
      }
    });
  }

  String _getDestinationTitle(AppDestination destination) {
    switch (destination) {
      case AppDestination.allNotes:
        return 'Notes';
      case AppDestination.pinned:
        return 'Pinned';
      case AppDestination.archive:
        return 'Archive';
      case AppDestination.trash:
        return 'Trash';
      case AppDestination.tag:
        return 'Tags';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLayout = screenWidth >= 900.0;

    if (isTabletLayout) {
      return _buildTabletLayout(context, colors);
    }

    return _buildPhoneLayout(context, colors);
  }

  Widget _buildPhoneLayout(BuildContext context, AppColors colors) {
    final destination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final repository = ref.watch(notesRepositoryProvider);
    final collectionState = ref.watch(notesCollectionProvider);
    final groups = ref.watch(groupedNotesCollectionProvider);
    final query = ref.watch(notesQueryProvider);

    final title = _getDestinationTitle(destination);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true): () {
          TagBrowserScreen.open(context);
        },
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true): () {
          TagBrowserScreen.open(context);
        },
      },
      child: PullDownSearchReveal(
        onOpenSearch: () => _openSearchScreen(context),
        child: Scaffold(
        backgroundColor: colors.background,
        drawerEnableOpenDragGesture: true,
        drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.35,
        drawer: Drawer(
          backgroundColor: colors.surface,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: AppRadii.rMd),
          ),
          width: 300,
          child: SidebarView(
            onItemSelected: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        appBar: _isMultiSelecting
            ? _buildMultiSelectAppBar(context, colors, destination, repository)
            : AppBar(
                backgroundColor: colors.background,
                elevation: 0,
                scrolledUnderElevation: 0,
                leading: Builder(
                  builder: (scaffoldCtx) => QuietIconButton(
                    icon: Icons.menu_rounded,
                    tooltip: 'Open navigation',
                    onPressed: () {
                      Scaffold.of(scaffoldCtx).openDrawer();
                    },
                  ),
                ),
                title: Text(
                  title,
                  style: AppTypography.title.copyWith(
                    color: colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  QuietIconButton(
                    icon: Icons.swap_vert_rounded,
                    tooltip: 'Sort notes',
                    onPressed: () => NotesSortSheet.show(context),
                  ),
                  NotesFilterButton(
                    advancedFilterCount: query.filter.advancedFilterCount,
                    onPressed: () => NotesFilterSheet.show(context),
                  ),
                  QuietIconButton(
                    icon: Icons.search_rounded,
                    tooltip: 'Search notes',
                    onPressed: () => _openSearchScreen(context),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    tooltip: 'More options',
                    color: colors.surface,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderMd,
                      side: BorderSide(color: colors.divider, width: 0.8),
                    ),
                    onSelected: (val) {
                      if (val == 'clip') {
                        WebClipDialog.show(context);
                      } else if (val == 'settings') {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      } else if (val == 'empty_trash') {
                        _confirmEmptyTrash(context);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'clip',
                        child: Row(
                          children: [
                            Icon(Icons.language_rounded, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Clip webpage',
                              style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                      if (destination == AppDestination.trash)
                        PopupMenuItem(
                          value: 'empty_trash',
                          child: Row(
                            children: [
                              Icon(Icons.delete_sweep_outlined, size: 18, color: colors.error),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Empty trash',
                                style: AppTypography.bodySmall.copyWith(color: colors.error),
                              ),
                            ],
                          ),
                        ),
                      PopupMenuItem(
                        value: 'settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings_outlined, size: 18, color: colors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Settings',
                              style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ),
        body: SafeArea(
          child: Builder(
            builder: (scaffoldCtx) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 250) {
                  Scaffold.of(scaffoldCtx).openDrawer();
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (destination == AppDestination.allNotes ||
                      destination == AppDestination.tag)
                    const TagsFilterBar(),
                  const ActiveFilterChips(),
                  if (!collectionState.initialLoading && collectionState.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: 4.0,
                      ),
                      child: Text(
                        '${collectionState.totalCount} ${collectionState.totalCount == 1 ? 'note' : 'notes'}',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Keyset-based prefetch threshold: 800dp from bottom
                        if (notification.metrics.extentAfter < 800) {
                          ref.read(notesCollectionProvider.notifier).loadMore();
                        }
                        return false;
                      },
                      child: collectionState.initialLoading
                          ? const Center(
                              child: CircularProgressIndicator.adaptive(),
                            )
                          : (groups.isEmpty && collectionState.notes.isEmpty)
                              ? SingleChildScrollView(
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  child: SizedBox(
                                    height: 400,
                                    child: NoteEmptyState(
                                      onCreateNote: () => _createAndOpenNote(context),
                                      destination: destination,
                                      tagFilter: selectedTag,
                                      hasActiveFilters: query.filter.hasAdvancedFilters,
                                      onClearFilters: () => ref
                                          .read(notesQueryProvider.notifier)
                                          .clearAllFilters(),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 96),
                                  physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics(),
                                  ),
                                  itemCount: _calculateTotalItemCount(groups) + 1,
                                  itemBuilder: (context, index) {
                                    if (index == _calculateTotalItemCount(groups)) {
                                      return NotesLoadingMoreIndicator(
                                        loadingMore: collectionState.loadingMore,
                                        error: collectionState.error,
                                        onRetry: () => ref
                                            .read(notesCollectionProvider.notifier)
                                            .retry(),
                                      );
                                    }
                                    return _buildGroupedItem(context, groups, index);
                                  },
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: (destination == AppDestination.allNotes ||
                destination == AppDestination.pinned ||
                destination == AppDestination.tag)
            ? QuietFab(
                onPressed: () => _createAndOpenNote(context),
              )
            : null,
      ),
    ),
    );
  }

  AppBar _buildMultiSelectAppBar(
    BuildContext context,
    AppColors colors,
    AppDestination destination,
    NotesRepository repository,
  ) {
    final count = _selectedNoteIds.length;

    return AppBar(
      backgroundColor: colors.surface,
      elevation: 1,
      leading: QuietIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close selection',
        onPressed: _exitMultiSelect,
      ),
      title: Text(
        '$count selected',
        style: AppTypography.headline.copyWith(
          color: colors.textPrimary,
          fontSize: 18,
        ),
      ),
      actions: [
        if (destination == AppDestination.trash) ...[
          QuietIconButton(
            icon: Icons.restore_rounded,
            tooltip: 'Restore selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.restoreNotes(ids);
              for (final id in ids) {
                ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
              }
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes restored'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_forever_rounded,
            tooltip: 'Delete permanently',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              final confirmed =
                  await PermanentDeleteDialog.show(context, count: count);
              if (confirmed) {
                await repository.deletePermanentlyBatch(ids);
                for (final id in ids) {
                  ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
                }
                _exitMultiSelect();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$count notes permanently deleted'),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
          ),
        ] else if (destination == AppDestination.archive) ...[
          QuietIconButton(
            icon: Icons.unarchive_outlined,
            tooltip: 'Unarchive selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.unarchiveNotes(ids);
              for (final id in ids) {
                ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
              }
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes unarchived'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Move to Trash',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.trashNotes(ids);
              for (final id in ids) {
                ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
              }
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes moved to Trash'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ] else ...[
          QuietIconButton(
            icon: Icons.archive_outlined,
            tooltip: 'Archive selected',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.archiveNotes(ids);
              for (final id in ids) {
                ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
              }
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes archived'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          QuietIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Move to Trash',
            onPressed: () async {
              final ids = _selectedNoteIds.toList();
              await repository.trashNotes(ids);
              for (final id in ids) {
                ref.read(notesCollectionProvider.notifier).removeLocalNote(id);
              }
              _exitMultiSelect();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count notes moved to Trash'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
        ],
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }

  Widget _buildTabletLayout(BuildContext context, AppColors colors) {
    final destination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);
    final collectionState = ref.watch(notesCollectionProvider);
    final groups = ref.watch(groupedNotesCollectionProvider);
    final query = ref.watch(notesQueryProvider);
    final title = _getDestinationTitle(destination);

    // Watch active note if one is selected in tablet mode
    Note? activeNote;
    if (_selectedNoteIdForTablet != null) {
      final matches = collectionState.notes.where((n) => n.id == _selectedNoteIdForTablet);
      if (matches.isNotEmpty) {
        activeNote = matches.first;
      }
    }

    final isNavSidebarVisible = ref.watch(isNavSidebarVisibleProvider);
    final isNoteListVisible = ref.watch(isNoteListVisibleProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Row(
          children: [
            // 1. Left Navigation Sidebar (280dp, collapsible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              width: isNavSidebarVisible ? 280.0 : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 280.0,
                  maxWidth: 280.0,
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: colors.divider, width: 1),
                      ),
                    ),
                    child: const SidebarView(isCollapsible: true),
                  ),
                ),
              ),
            ),

            // 2. Middle Note List Pane (320dp, collapsible)
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              width: isNoteListVisible ? 320.0 : 0.0,
              child: ClipRect(
                child: OverflowBox(
                  minWidth: 320.0,
                  maxWidth: 320.0,
                  alignment: Alignment.topLeft,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: colors.divider, width: 1),
                      ),
                    ),
                    child: PullDownSearchReveal(
                      isTabletPane: true,
                      onOpenSearch: () => _openSearchScreen(context),
                      child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragEnd: (details) {
                        if (!isNavSidebarVisible &&
                            details.primaryVelocity != null &&
                            details.primaryVelocity! > 250) {
                          ref
                              .read(isNavSidebarVisibleProvider.notifier)
                              .state = true;
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Middle Pane Top bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final availableWidth = constraints.maxWidth;
                                final isVeryNarrow = availableWidth < 300;

                                return Row(
                                  children: [
                                    QuietIconButton(
                                      icon: isNavSidebarVisible
                                          ? Icons.menu_open_rounded
                                          : Icons.view_sidebar_outlined,
                                      tooltip: isNavSidebarVisible
                                          ? 'Hide navigation'
                                          : 'Show navigation',
                                      onPressed: () {
                                        ref
                                            .read(isNavSidebarVisibleProvider.notifier)
                                            .state = !isNavSidebarVisible;
                                      },
                                    ),
                                    const SizedBox(width: 4.0),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: AppTypography.title.copyWith(
                                          color: colors.textPrimary,
                                          fontSize: 19,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    if (!isVeryNarrow) ...[
                                      QuietIconButton(
                                        icon: Icons.swap_vert_rounded,
                                        tooltip: 'Sort notes',
                                        onPressed: () => NotesSortSheet.show(context),
                                      ),
                                      NotesFilterButton(
                                        advancedFilterCount: query.filter.advancedFilterCount,
                                        onPressed: () => NotesFilterSheet.show(context),
                                      ),
                                      QuietIconButton(
                                        icon: Icons.search_rounded,
                                        tooltip: 'Search notes',
                                        onPressed: () => _openSearchScreen(context),
                                      ),
                                    ],
                                    QuietIconButton(
                                      icon: Icons.add_rounded,
                                      tooltip: 'New note',
                                      isActive: true,
                                      onPressed: () => _createAndOpenNoteTablet(),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_horiz_rounded, size: 20),
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
                                        } else if (val == 'search') {
                                          _openSearchScreen(context);
                                        } else if (val == 'clip') {
                                          WebClipDialog.show(context);
                                        } else if (val == 'hide_list') {
                                          ref
                                              .read(isNoteListVisibleProvider.notifier)
                                              .state = false;
                                        } else if (val == 'empty_trash') {
                                          _confirmEmptyTrash(context);
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        if (isVeryNarrow) ...[
                                          PopupMenuItem(
                                            value: 'sort',
                                            child: Row(
                                              children: [
                                                Icon(Icons.swap_vert_rounded, size: 18, color: colors.textSecondary),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(
                                                  'Sort notes',
                                                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'filter',
                                            child: Row(
                                              children: [
                                                Icon(Icons.filter_list_rounded, size: 18, color: colors.textSecondary),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(
                                                  query.filter.advancedFilterCount > 0
                                                      ? 'Filter notes (${query.filter.advancedFilterCount})'
                                                      : 'Filter notes',
                                                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'search',
                                            child: Row(
                                              children: [
                                                Icon(Icons.search_rounded, size: 18, color: colors.textSecondary),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(
                                                  'Search notes',
                                                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        PopupMenuItem(
                                          value: 'clip',
                                          child: Row(
                                            children: [
                                              Icon(Icons.language_rounded, size: 18, color: colors.textSecondary),
                                              const SizedBox(width: AppSpacing.sm),
                                              Text(
                                                'Clip webpage',
                                                style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (activeNote != null)
                                          PopupMenuItem(
                                            value: 'hide_list',
                                            child: Row(
                                              children: [
                                                Icon(Icons.fullscreen_rounded, size: 18, color: colors.textSecondary),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(
                                                  'Hide note list',
                                                  style: AppTypography.bodySmall.copyWith(color: colors.textPrimary),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (destination == AppDestination.trash)
                                          PopupMenuItem(
                                            value: 'empty_trash',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_sweep_outlined, size: 18, color: colors.error),
                                                const SizedBox(width: AppSpacing.sm),
                                                Text(
                                                  'Empty trash',
                                                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (destination == AppDestination.allNotes ||
                              destination == AppDestination.tag) ...[
                            const TagsFilterBar(),
                          ],
                          const ActiveFilterChips(horizontalPadding: AppSpacing.md),
                          if (!collectionState.initialLoading && collectionState.notes.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.md,
                                right: AppSpacing.md,
                                top: 2.0,
                                bottom: 4.0,
                              ),
                              child: Text(
                                '${collectionState.totalCount} ${collectionState.totalCount == 1 ? 'note' : 'notes'}',
                                style: AppTypography.caption.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification: (notification) {
                                if (notification.metrics.extentAfter < 800) {
                                  ref.read(notesCollectionProvider.notifier).loadMore();
                                }
                                return false;
                              },
                              child: collectionState.initialLoading
                                  ? const Center(
                                      child: CircularProgressIndicator.adaptive(),
                                    )
                                  : (groups.isEmpty && collectionState.notes.isEmpty)
                                      ? SingleChildScrollView(
                                          physics: const BouncingScrollPhysics(
                                            parent: AlwaysScrollableScrollPhysics(),
                                          ),
                                          child: SizedBox(
                                            height: 400,
                                            child: NoteEmptyState(
                                              onCreateNote: () => _createAndOpenNoteTablet(),
                                              destination: destination,
                                              tagFilter: selectedTag,
                                              hasActiveFilters: query.filter.hasAdvancedFilters,
                                              onClearFilters: () => ref
                                                  .read(notesQueryProvider.notifier)
                                                  .clearAllFilters(),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          physics: const BouncingScrollPhysics(
                                            parent: AlwaysScrollableScrollPhysics(),
                                          ),
                                          itemCount: _calculateTotalItemCount(groups) + 1,
                                          itemBuilder: (context, index) {
                                            if (index == _calculateTotalItemCount(groups)) {
                                              return NotesLoadingMoreIndicator(
                                                loadingMore: collectionState.loadingMore,
                                                error: collectionState.error,
                                                onRetry: () => ref
                                                    .read(notesCollectionProvider.notifier)
                                                    .retry(),
                                              );
                                            }
                                            return _buildGroupedItem(
                                              context,
                                              groups,
                                              index,
                                              isTablet: true,
                                            );
                                          },
                                        ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),

            // 3. Right Detail Editor Pane
            Expanded(
              child: activeNote != null
                  ? KeyedSubtree(
                      key: ValueKey(activeNote.id),
                      child: EditorScreen(
                        note: activeNote,
                        autoFocusBody: _shouldAutoFocusTablet &&
                            _selectedNoteIdForTablet == activeNote.id,
                        initialPreviewMode: !(_shouldAutoFocusTablet &&
                            _selectedNoteIdForTablet == activeNote.id),
                        onClose: () {
                          setState(() {
                            _selectedNoteIdForTablet = null;
                          });
                        },
                      ),
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 48,
                              color: colors.textTertiary.withValues(alpha: 0.35),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No note selected',
                              style: AppTypography.title.copyWith(
                                color: colors.textSecondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Select a note to view or create a new one.',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                            if (!isNoteListVisible || !isNavSidebarVisible) ...[
                              const SizedBox(height: AppSpacing.lg),
                              QuietButton(
                                label: 'Show note list',
                                icon: Icons.view_sidebar_outlined,
                                variant: QuietButtonVariant.secondary,
                                onPressed: () {
                                  ref
                                      .read(isNoteListVisibleProvider.notifier)
                                      .state = true;
                                  ref
                                      .read(isNavSidebarVisibleProvider.notifier)
                                      .state = true;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _calculateTotalItemCount(List<NoteGroup> groups) {
    var count = 0;
    for (final g in groups) {
      count += 1; // Section header
      count += g.notes.length; // Notes in this group
    }
    return count;
  }

  Widget _buildGroupedItem(
    BuildContext context,
    List<NoteGroup> groups,
    int index, {
    bool isTablet = false,
  }) {
    final destination = ref.watch(currentDestinationProvider);
    final repository = ref.watch(notesRepositoryProvider);
    var accumulated = 0;

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      if (index == accumulated) {
        return NoteDateHeader(
          title: group.header,
          isFirst: i == 0,
        );
      }
      accumulated++;

      final noteIndex = index - accumulated;
      if (noteIndex < group.notes.length) {
        final note = group.notes[noteIndex];
        final isSelected = isTablet && _selectedNoteIdForTablet == note.id;
        final isItemMultiSelected = _selectedNoteIds.contains(note.id);

        DismissDirection dismissDirection;
        Widget? background;
        Widget? secondaryBackground;

        if (destination == AppDestination.trash) {
          dismissDirection = DismissDirection.startToEnd;
          background = Container(
            color: context.appColors.success,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.restore_rounded,
              color: Colors.white,
            ),
          );
        } else if (destination == AppDestination.archive) {
          dismissDirection = DismissDirection.horizontal;
          background = Container(
            color: context.appColors.tagBackground,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(
              Icons.unarchive_outlined,
              color: context.appColors.textPrimary,
            ),
          );
          secondaryBackground = Container(
            color: context.appColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          );
        } else {
          // All Notes / Pinned / Tag:
          // Swipe right (startToEnd) -> Archive
          // Swipe left (endToStart) -> Move to Trash
          dismissDirection = DismissDirection.horizontal;
          background = Container(
            color: context.appColors.tagBackground,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Icon(
              Icons.archive_outlined,
              color: context.appColors.accent,
            ),
          );
          secondaryBackground = Container(
            color: context.appColors.error,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
            ),
          );
        }

        return Dismissible(
          key: ValueKey('dismiss_${note.id}'),
          direction: dismissDirection,
          background: background,
          secondaryBackground: secondaryBackground,
          onDismissed: (direction) {
            if (destination == AppDestination.trash) {
              _restoreNoteWithUndo(note);
            } else if (destination == AppDestination.archive) {
              if (direction == DismissDirection.startToEnd) {
                _unarchiveNoteWithUndo(note);
              } else {
                _trashNoteWithUndo(note);
              }
            } else {
              if (direction == DismissDirection.startToEnd) {
                _archiveNoteWithUndo(note);
              } else {
                _trashNoteWithUndo(note);
              }
            }
          },
          child: NoteListTile(
            note: note,
            isSelected: isSelected,
            isMultiSelecting: _isMultiSelecting,
            isItemMultiSelected: isItemMultiSelected,
            onItemMultiSelectToggle: () => _toggleNoteMultiSelect(note.id),
            onTap: () {
              if (isTablet) {
                setState(() {
                  _selectedNoteIdForTablet = note.id;
                  _shouldAutoFocusTablet = false;
                });
              } else {
                _openNote(context, note);
              }
            },
            onTagTap: (tag) {
              ref.read(currentDestinationProvider.notifier).state =
                  AppDestination.tag;
              ref.read(selectedTagFilterProvider.notifier).state = tag;
              ref.read(notesQueryProvider.notifier).setTag(tag);
            },
            onTogglePin: () {
              repository.setPinned(note.id, !note.isPinned);
              ref.read(notesCollectionProvider.notifier).refresh();
            },
            onArchive: () {
              _archiveNoteWithUndo(note);
            },
            onUnarchive: () {
              _unarchiveNoteWithUndo(note);
            },
            onTrash: () {
              _trashNoteWithUndo(note);
            },
            onRestore: () {
              _restoreNoteWithUndo(note);
            },
            onDeletePermanently: () {
              _deletePermanently(note);
            },
            onDelete: () {
              _trashNoteWithUndo(note);
            },
          ),
        );
      }
      accumulated += group.notes.length;
    }

    return const SizedBox.shrink();
  }

  void _openSearchScreen(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      SearchPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  void _openNote(BuildContext context, Note note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          note: note,
          initialPreviewMode: true,
        ),
      ),
    );
  }

  void _createAndOpenNote(BuildContext context) async {
    const uuid = Uuid();
    final now = DateTime.now();
    final selectedFilter = ref.read(selectedTagFilterProvider);

    final initialTags = selectedFilter != null && selectedFilter.isNotEmpty
        ? [selectedFilter]
        : <String>[];

    final newNote = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      tags: initialTags,
    );

    await ref.read(notesRepositoryProvider).saveNote(newNote);
    ref.read(notesCollectionProvider.notifier).refresh();

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EditorScreen(
            note: newNote,
            autoFocusBody: true,
            initialPreviewMode: false,
          ),
        ),
      );
    }
  }

  void _createAndOpenNoteTablet() async {
    const uuid = Uuid();
    final now = DateTime.now();
    final selectedFilter = ref.read(selectedTagFilterProvider);

    final initialTags = selectedFilter != null && selectedFilter.isNotEmpty
        ? [selectedFilter]
        : <String>[];

    final newNote = Note(
      id: uuid.v4(),
      title: '',
      content: '',
      createdAt: now,
      updatedAt: now,
      tags: initialTags,
    );

    await ref.read(notesRepositoryProvider).saveNote(newNote);
    ref.read(notesCollectionProvider.notifier).refresh();

    setState(() {
      _selectedNoteIdForTablet = newNote.id;
      _shouldAutoFocusTablet = true;
    });
  }

  void _archiveNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.archiveNote(note.id);
    ref.read(notesCollectionProvider.notifier).removeLocalNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note archived'),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.unarchiveNote(note.id);
            ref.read(notesCollectionProvider.notifier).refresh();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _unarchiveNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.unarchiveNote(note.id);
    ref.read(notesCollectionProvider.notifier).removeLocalNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note unarchived'),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.archiveNote(note.id);
            ref.read(notesCollectionProvider.notifier).refresh();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _trashNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.trashNote(note.id);
    ref.read(notesCollectionProvider.notifier).removeLocalNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note moved to Trash'),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.restoreFromTrash(note.id);
            ref.read(notesCollectionProvider.notifier).refresh();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _restoreNoteWithUndo(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.restoreFromTrash(note.id);
    ref.read(notesCollectionProvider.notifier).removeLocalNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note restored'),
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.horizontal,
        persist: false,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            repository.trashNote(note.id);
            ref.read(notesCollectionProvider.notifier).refresh();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _deletePermanently(Note note) {
    final repository = ref.read(notesRepositoryProvider);
    repository.deletePermanently(note.id);
    ref.read(notesCollectionProvider.notifier).removeLocalNote(note.id);

    if (_selectedNoteIdForTablet == note.id) {
      setState(() {
        _selectedNoteIdForTablet = null;
      });
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Note permanently deleted'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _confirmEmptyTrash(BuildContext context) async {
    final count = ref.read(trashedNotesCountProvider).valueOrNull ?? 0;
    if (count == 0) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trash is already empty'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final confirmed = await PermanentDeleteDialog.show(context, count: count);
    if (confirmed) {
      await ref.read(notesRepositoryProvider).emptyTrash();
      ref.read(notesCollectionProvider.notifier).refresh();
      setState(() {
        _selectedNoteIdForTablet = null;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trash emptied'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
