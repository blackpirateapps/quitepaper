import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/utils/platform_layout_helper.dart';
import '../../../core/widgets/desktop_smooth_scroll.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../../core/widgets/quiet_adaptive_modal.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/notes_query_provider.dart';
import '../../notes/application/saved_filters_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/domain/saved_filter.dart';
import '../../notes/presentation/widgets/saved_filters_sheet.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/application/default_settings_provider.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tags/application/tag_providers.dart';
import '../../tags/domain/tag_colors.dart';
import '../../tags/domain/tag_icon_registry.dart';
import '../../tags/domain/tag_model.dart';
import '../../tags/domain/tag_path.dart';
import '../../tags/domain/tag_tree.dart';
import '../../tags/presentation/widgets/tag_action_dialogs.dart';
import '../../tags/presentation/widgets/tag_color_picker_sheet.dart';
import '../../tags/presentation/widgets/tag_icon_picker_sheet.dart';
import '../../journal/application/journal_providers.dart';
import 'widgets/sidebar_sync_tile.dart';
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

  Future<void> _handleQuickCompose(BuildContext context, WidgetRef ref) async {
    onItemSelected?.call();
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

  Widget _buildSettingsButton(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: 'Settings',
      button: true,
      child: Tooltip(
        message: 'Settings',
        child: Material(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(9.0),
          child: InkWell(
            onTap: () {
              onItemSelected?.call();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(9.0),
            child: Container(
              width: 34.0,
              height: 34.0,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9.0),
                border: Border.all(
                  color: colors.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Opacity(
                    opacity: 0.0,
                    child: SizedBox(
                      width: 0,
                      height: 0,
                      child: Text('Settings'),
                    ),
                  ),
                  Icon(
                    PhosphorIconsRegular.gearSix,
                    size: 18.0,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final currentDestination = ref.watch(currentDestinationProvider);
    final selectedTag = ref.watch(selectedTagFilterProvider);

    final activeCount = ref.watch(activeNotesCountProvider).valueOrNull;
    final pinnedCount = ref.watch(pinnedNotesCountProvider).valueOrNull;
    final archiveCount = ref.watch(archivedNotesCountProvider).valueOrNull;
    final trashCount = ref.watch(trashedNotesCountProvider).valueOrNull;
    final hasTodayEntry = ref.watch(hasTodayJournalEntryProvider);
    final tagsAsync = ref.watch(allTagsProvider);
    final expandedTagPaths = ref.watch(expandedTagPathsProvider);

    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final headerTextColor = isSidebarDark
        ? const Color(0xFFF1F2F4)
        : colors.textPrimary;
    final searchBgColor = isSidebarDark
        ? colors.sidebarSelected
        : colors.surfaceSecondary;
    final searchHintColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textTertiary;
    final searchIconColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textSecondary;
    final sidebarDividerColor = isSidebarDark
        ? const Color(0xFF2D333B)
        : colors.divider;

    return Container(
      color: colors.sidebarBackground,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Header & Branding (Literary Masthead)
            Padding(
              padding: const EdgeInsets.fromLTRB(14.0, 12.0, 10.0, 6.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quiet Paper',
                      style: GoogleFonts.newsreader(
                        textStyle: const TextStyle(fontFamily: 'serif'),
                        fontSize: 22.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: headerTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  // Quick Compose Button
                  Material(
                    color: colors.accentSoft,
                    borderRadius: BorderRadius.circular(8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8.0),
                      onTap: () => _handleQuickCompose(context, ref),
                      child: Container(
                        width: 32.0,
                        height: 32.0,
                        alignment: Alignment.center,
                        child: Icon(
                          PhosphorIconsRegular.pencilSimple,
                          size: 17.0,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6.0),
                  // Collapse / Close drawer button
                  QuietIconButton(
                    icon: PhosphorIconsRegular.sidebarSimple,
                    tooltip: isCollapsible
                        ? 'Hide navigation sidebar'
                        : 'Close drawer',
                    size: 18.0,
                    onPressed: () {
                      if (isCollapsible) {
                        ref.read(isNavSidebarVisibleProvider.notifier).state =
                            false;
                      } else {
                        onItemSelected?.call();
                      }
                    },
                  ),
                ],
              ),
            ),

            // Tactile Search Pill
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 6.0),
              child: Material(
                color: searchBgColor,
                borderRadius: BorderRadius.circular(10.0),
                child: InkWell(
                  onTap: () {
                    onItemSelected?.call();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(10.0),
                  child: Container(
                    height: 38.0,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.0),
                      border: Border.all(
                        color: colors.borderSubtle,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                          size: 16.0,
                          color: searchIconColor,
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            'Search notes...',
                            style: AppTypography.bodySmall.copyWith(
                              color: searchHintColor,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6.0,
                            vertical: 2.0,
                          ),
                          decoration: BoxDecoration(
                            color: colors.sidebarBackground.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(
                              color: colors.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '/',
                            style: TextStyle(
                              color: searchHintColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Scrollable navigation list (Middle Zone)
            Expanded(
              child: DesktopSmoothScroll(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, 4.0, 0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LIBRARY Section Header
                      _buildSectionHeader(context, 'LIBRARY'),

                      SidebarItem(
                        icon: PhosphorIconsRegular.note,
                        label: 'All Notes',
                        count: activeCount,
                        isSelected:
                            currentDestination == AppDestination.allNotes &&
                            selectedTag == null,
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.allNotes;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
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
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
                          onItemSelected?.call();
                        },
                      ),

                      SidebarItem(
                        icon: currentDestination == AppDestination.archive
                            ? PhosphorIconsFill.archive
                            : PhosphorIconsRegular.archive,
                        label: 'Archive',
                        count: archiveCount,
                        isSelected:
                            currentDestination == AppDestination.archive,
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.archive;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
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
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
                          onItemSelected?.call();
                        },
                      ),

                      // JOURNAL Section Header
                      _buildSectionHeader(
                        context,
                        'JOURNAL',
                        trailing: Text(
                          'Daily',
                          style: GoogleFonts.newsreader(
                            textStyle: const TextStyle(fontFamily: 'serif'),
                            fontStyle: FontStyle.italic,
                            fontSize: 12.5,
                            color: isSidebarDark
                                ? const Color(0xFF9CA3AF)
                                : colors.textTertiary,
                          ),
                        ),
                      ),

                      SidebarItem(
                        icon: PhosphorIconsRegular.calendarCheck,
                        label: 'Today',
                        trailing: hasTodayEntry
                            ? Container(
                                width: 6.0,
                                height: 6.0,
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                        onTap: () async {
                          onItemSelected?.call();
                          final autoTag = ref
                              .read(defaultSettingsProvider)
                              .autoTagTodayJournal;
                          final journalService = ref.read(
                            journalServiceProvider,
                          );
                          await journalService.openOrCreateTodayFlow(
                            context,
                            isTablet: isCollapsible,
                            autoTagYear: autoTag,
                          );
                        },
                      ),

                      SidebarItem(
                        icon:
                            currentDestination ==
                                AppDestination.allJournalEntries
                            ? PhosphorIconsFill.calendarDots
                            : PhosphorIconsRegular.calendarDots,
                        label: 'All Entries',
                        isSelected:
                            currentDestination ==
                            AppDestination.allJournalEntries,
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.allJournalEntries;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
                          onItemSelected?.call();
                        },
                      ),

                      SidebarItem(
                        icon: currentDestination == AppDestination.onThisDay
                            ? PhosphorIconsFill.clockCounterClockwise
                            : PhosphorIconsRegular.clockCounterClockwise,
                        label: 'On This Day',
                        isSelected:
                            currentDestination == AppDestination.onThisDay,
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.onThisDay;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
                          onItemSelected?.call();
                        },
                      ),

                      SidebarItem(
                        icon: currentDestination == AppDestination.places
                            ? PhosphorIconsFill.mapPin
                            : PhosphorIconsRegular.mapPin,
                        label: 'Places',
                        isSelected: currentDestination == AppDestination.places,
                        onTap: () {
                          ref.read(currentDestinationProvider.notifier).state =
                              AppDestination.places;
                          ref.read(selectedTagFilterProvider.notifier).state =
                              null;
                          ref
                              .read(notesQueryProvider.notifier)
                              .clearAllFilters();
                          onItemSelected?.call();
                        },
                      ),

                      // SMART VIEWS Section (if any saved views exist)
                      Builder(
                        builder: (ctx) {
                          final savedFilters = ref.watch(savedFiltersProvider);
                          if (savedFilters.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                context,
                                'SMART VIEWS',
                                trailing: SizedBox(
                                  height: 24.0,
                                  width: 24.0,
                                  child: QuietIconButton(
                                    icon:
                                        PhosphorIconsRegular.slidersHorizontal,
                                    size: 15.0,
                                    padding: EdgeInsets.zero,
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
                                    ref
                                        .read(notesQueryProvider.notifier)
                                        .setFilters(sv.query.filter);
                                    ref
                                        .read(notesQueryProvider.notifier)
                                        .setSort(sv.query.sort);
                                    onItemSelected?.call();
                                  },
                                  onLongPress: () =>
                                      _showSmartViewOptions(context, ref, sv),
                                  onSecondaryTap: () =>
                                      _showSmartViewOptions(context, ref, sv),
                                  onSecondaryTapUp: (details) =>
                                      _showSmartViewOptions(
                                        context,
                                        ref,
                                        sv,
                                        details.globalPosition,
                                      ),
                                );
                              }),
                            ],
                          );
                        },
                      ),

                      // TAGS Section ("Pure Bear List" Design)
                      tagsAsync.when(
                        data: (tags) {
                          if (tags.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final tree = TagTree.build(
                            tags,
                            compare: TagTree.compareByUsage,
                          );
                          final visibleRoots =
                              tree.roots.take(_maxVisibleTags).toList();
                          if (selectedTag != null) {
                            final rootName =
                                TagPath.tryParse(selectedTag)?.segments.first ??
                                selectedTag;
                            for (final root in tree.roots) {
                              final name =
                                  root.path?.segments.first ?? root.tag.name;
                              if (name == rootName &&
                                  !visibleRoots.contains(root)) {
                                visibleRoots.add(root);
                                break;
                              }
                            }
                          }
                          final hasMore =
                              tree.roots.length > visibleRoots.length;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(
                                context,
                                'TAGS',
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        ref
                                            .read(
                                              currentDestinationProvider
                                                  .notifier,
                                            )
                                            .state = AppDestination
                                            .tagBrowser;
                                        ref
                                                .read(
                                                  selectedTagFilterProvider
                                                      .notifier,
                                                )
                                                .state =
                                            null;
                                        ref
                                                .read(
                                                  selectedTagIdProvider
                                                      .notifier,
                                                )
                                                .state =
                                            null;
                                        onItemSelected?.call();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4.0,
                                          vertical: 2.0,
                                        ),
                                        child: Text(
                                          'All ${tags.length} ↗',
                                          style: TextStyle(
                                            color: colors.accent,
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4.0),
                                    SizedBox(
                                      height: 24.0,
                                      width: 24.0,
                                      child: QuietIconButton(
                                        icon:
                                            PhosphorIconsRegular
                                                .slidersHorizontal,
                                        size: 15.0,
                                        padding: EdgeInsets.zero,
                                        tooltip: 'Manage tags',
                                        onPressed: () {
                                          ref
                                              .read(
                                                currentDestinationProvider
                                                    .notifier,
                                              )
                                              .state = AppDestination
                                              .tagBrowser;
                                          ref
                                                  .read(
                                                    selectedTagFilterProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              null;
                                          ref
                                                  .read(
                                                    selectedTagIdProvider
                                                        .notifier,
                                                  )
                                                  .state =
                                              null;
                                          onItemSelected?.call();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final rootNode in visibleRoots)
                                _buildTagTreeNode(
                                  context,
                                  ref,
                                  colors,
                                  isSidebarDark,
                                  rootNode,
                                  expandedTagPaths,
                                  selectedTag,
                                  currentDestination,
                                ),
                              if (hasMore) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 2.0,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                    onTap: () {
                                      ref
                                          .read(
                                            currentDestinationProvider.notifier,
                                          )
                                          .state = AppDestination
                                          .tagBrowser;
                                      ref
                                              .read(
                                                selectedTagFilterProvider
                                                    .notifier,
                                              )
                                              .state =
                                          null;
                                      ref
                                              .read(
                                                selectedTagIdProvider.notifier,
                                              )
                                              .state =
                                          null;
                                      onItemSelected?.call();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 6.0,
                                      ),
                                      child: Text(
                                        'Show all tags (${tags.length})...',
                                        style: AppTypography.caption.copyWith(
                                          color:
                                              currentDestination ==
                                                  AppDestination.tagBrowser
                                              ? colors.accent
                                              : (isSidebarDark
                                                  ? const Color(0xFF9CA3AF)
                                                  : colors.textSecondary),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.0,
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
            ),

            // Pinned Bottom Hairline Divider
            Container(
              height: 1.0,
              color: sidebarDividerColor,
            ),

            // Pinned Bottom Footer Bar (Unified Sync + Settings)
            Padding(
              padding: const EdgeInsets.fromLTRB(6.0, 6.0, 8.0, 6.0),
              child: SidebarSyncTile(
                onItemSelected: onItemSelected,
                trailing: _buildSettingsButton(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagTreeNode(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    bool isSidebarDark,
    TagTreeNode node,
    Set<String> expandedTagPaths,
    String? selectedTag,
    AppDestination currentDestination,
  ) {
    final path = node.path?.value ?? node.tag.name;
    final isExpanded = expandedTagPaths.contains(path);
    final isTagSelected =
        currentDestination == AppDestination.tag && selectedTag == node.tag.name;

    final colorDef = TagColors.fromId(node.tag.color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customColor = colorDef?.foreground(isDark);
    final hasCustomIcon = node.tag.icon != null && node.tag.icon!.isNotEmpty;

    final defaultTextColor = isSidebarDark
        ? const Color(0xFFF1F2F4)
        : colors.textPrimary;
    final defaultSecondaryColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textSecondary;
    final defaultTertiaryColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textTertiary;

    final textColor = isTagSelected
        ? (isSidebarDark ? Colors.white : colors.textPrimary)
        : defaultTextColor;

    final countColor = isTagSelected
        ? (isSidebarDark ? const Color(0xFFE5E7EB) : colors.textPrimary)
        : (node.tag.noteCount == 0 ? colors.textDisabled : defaultTertiaryColor);

    final backgroundColor = isTagSelected
        ? colors.sidebarSelected
        : Colors.transparent;

    final textStyle =
        (isTagSelected ? AppTypography.bodyMedium : AppTypography.body).copyWith(
          color: textColor,
          fontWeight: isTagSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 14.5,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          selected: isTagSelected,
          label:
              '${node.displayPath}, ${node.tag.noteCount} notes${node.tag.isImplicit ? ', implicit parent tag' : ''}',
          button: true,
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 8.0,
              vertical: 1.5,
            ),
            child: Material(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(9.0),
              child: InkWell(
                onTap: () {
                  if (node.tag.isImplicit && node.hasChildren) {
                    ref.read(expandedTagPathsProvider.notifier).toggle(path);
                    return;
                  }
                  ref.read(currentDestinationProvider.notifier).state =
                      AppDestination.tag;
                  ref.read(selectedTagFilterProvider.notifier).state =
                      node.tag.name;
                  ref.read(selectedTagIdProvider.notifier).state = node.tag.id;
                  ref.read(notesQueryProvider.notifier).setTag(node.tag.name);
                  onItemSelected?.call();
                },
                onLongPress: () => _showTagOptions(context, ref, node.tag),
                onSecondaryTap: () => _showTagOptions(context, ref, node.tag),
                onSecondaryTapUp: (details) => _showTagOptions(
                  context,
                  ref,
                  node.tag,
                  details.globalPosition,
                ),
                borderRadius: BorderRadius.circular(9.0),
                splashColor: colors.accent.withValues(alpha: 0.1),
                highlightColor: colors.selection.withValues(alpha: 0.3),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 36.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10.0,
                      vertical: 7.0,
                    ),
                    child: Row(
                      children: [
                        // Fixed 22px Left Icon Slot
                        SizedBox(
                          width: 22.0,
                          height: 22.0,
                          child: Center(
                            child: hasCustomIcon
                                ? Icon(
                                    TagIconRegistry.getIconData(node.tag.icon),
                                    size: 17.0,
                                    color: isTagSelected
                                        ? colors.accent
                                        : (customColor ??
                                            defaultSecondaryColor),
                                  )
                                : Text(
                                    '#',
                                    style: GoogleFonts.newsreader(
                                      textStyle: const TextStyle(
                                        fontFamily: 'serif',
                                      ),
                                      fontSize: 16.0,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w500,
                                      color: isTagSelected
                                          ? colors.accent
                                          : (customColor ??
                                              defaultTertiaryColor),
                                      height: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // Label & Inline Disclosure Chevron
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  node.displayName,
                                  style: textStyle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (node.hasChildren)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => ref
                                      .read(expandedTagPathsProvider.notifier)
                                      .toggle(path),
                                  child: Tooltip(
                                    message: isExpanded
                                        ? 'Collapse ${node.displayName}'
                                        : 'Expand ${node.displayName}',
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        left: 5.0,
                                        right: 2.0,
                                      ),
                                      child: AnimatedRotation(
                                        turns: isExpanded ? 0.25 : 0.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        curve: Curves.easeInOut,
                                        child: Icon(
                                          PhosphorIconsRegular.caretRight,
                                          size: 12.0,
                                          color: isExpanded
                                              ? colors.accent
                                              : defaultTertiaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (node.tag.isPinned) ...[
                                const SizedBox(width: 5.0),
                                Container(
                                  width: 5.0,
                                  height: 5.0,
                                  decoration: BoxDecoration(
                                    color: colors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Right-Aligned Tabular Count
                        const SizedBox(width: 8.0),
                        Text(
                          '${node.tag.noteCount}',
                          style: GoogleFonts.jetBrainsMono(
                            textStyle: const TextStyle(
                              fontFeatures: [FontFeature.tabularFigures()],
                              fontFamily: 'monospace',
                            ),
                            fontSize: 12.5,
                            fontWeight: isTagSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: countColor,
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

        // Nested Children with 1px Vertical Thread Line
        if (node.hasChildren)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
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
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final child in node.children)
                          _buildTagTreeNode(
                            context,
                            ref,
                            colors,
                            isSidebarDark,
                            child,
                            expandedTagPaths,
                            selectedTag,
                            currentDestination,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final colors = context.appColors;
    final isSidebarDark = colors.sidebarBackground.computeLuminance() < 0.5;
    final headerColor = isSidebarDark
        ? const Color(0xFF9CA3AF)
        : colors.textTertiary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        14.0,
        14.0,
        10.0,
        4.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: AppTypography.caption.copyWith(
              color: headerColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              fontSize: 11.0,
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
    SavedFilter sv, [
    Offset? globalPosition,
  ]) async {
    final colors = context.appColors;

    String? action;
    if (PlatformLayoutHelper.isDesktopPlatform && globalPosition != null) {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      final position = RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        overlay != null
            ? Offset.zero & overlay.size
            : Rect.fromLTWH(0, 0, globalPosition.dx, globalPosition.dy),
      );
      action = await showMenu<String>(
        context: context,
        position: position,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderMd,
          side: BorderSide(color: colors.divider, width: 0.8),
        ),
        items: [
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 18,
                  color: colors.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Rename',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.trash, size: 18, color: colors.error),
                const SizedBox(width: 10),
                Text(
                  'Delete',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      action = await QuietAdaptiveModal.show<String>(
        context: context,
        type: AdaptiveModalType.popover,
        cursorPosition: globalPosition,
        maxWidth: 280,
        builder: (ctx) {
          return Material(
            color: colors.surface,
            borderRadius: PlatformLayoutHelper.isDesktop(context)
                ? AppRadii.borderMd
                : const BorderRadius.vertical(top: AppRadii.rLg),
            clipBehavior: Clip.antiAlias,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AdaptiveSheetDragHandle(),
                    const SizedBox(height: AppSpacing.xs),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
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
                      leading: Icon(
                        PhosphorIconsRegular.pencilSimple,
                        size: 20,
                        color: colors.textPrimary,
                      ),
                      title: Text(
                        'Rename',
                        style: AppTypography.body.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () => Navigator.of(ctx).pop('rename'),
                    ),
                    ListTile(
                      leading: Icon(
                        PhosphorIconsRegular.trash,
                        size: 20,
                        color: colors.error,
                      ),
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
    }

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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
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
                style: AppTypography.bodyMedium.copyWith(
                  color: colors.textSecondary,
                ),
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

  bool _tagHasDescendants(WidgetRef ref, Tag tag) {
    final tags = ref.read(allTagsProvider).valueOrNull ?? const <Tag>[];
    return tags.any((candidate) => candidate.name.startsWith('${tag.name}/'));
  }

  void _showTagOptions(
    BuildContext context,
    WidgetRef ref,
    Tag tag, [
    Offset? globalPosition,
  ]) async {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDef = tag.colorDefinition;

    if (PlatformLayoutHelper.isDesktopPlatform && globalPosition != null) {
      final overlay =
          Overlay.of(context).context.findRenderObject() as RenderBox?;
      final position = RelativeRect.fromRect(
        Rect.fromLTWH(globalPosition.dx, globalPosition.dy, 0, 0),
        overlay != null
            ? Offset.zero & overlay.size
            : Rect.fromLTWH(0, 0, globalPosition.dx, globalPosition.dy),
      );

      final selected = await showMenu<String>(
        context: context,
        position: position,
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderMd,
          side: BorderSide(color: colors.divider, width: 0.8),
        ),
        items: [
          PopupMenuItem<String>(
            value: 'open',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.arrowSquareOut,
                  size: 18,
                  color: colors.accent,
                ),
                const SizedBox(width: 10),
                Text(
                  'Open',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'nested',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.folderPlus,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Add nested tag',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'pin',
            child: Row(
              children: [
                Icon(
                  tag.isPinned
                      ? PhosphorIconsFill.pushPin
                      : PhosphorIconsRegular.pushPin,
                  size: 18,
                  color: tag.isPinned ? colors.accent : colors.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  tag.isPinned ? 'Unpin tag' : 'Pin to top',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'rename',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Rename...',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'icon',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.smiley,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  tag.icon != null ? 'Change icon...' : 'Add icon...',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'color',
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.palette,
                  size: 18,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  tag.color != null ? 'Change color...' : 'Add color...',
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(PhosphorIconsRegular.trash, size: 18, color: colors.error),
                const SizedBox(width: 10),
                Text(
                  'Delete tag',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
              ],
            ),
          ),
        ],
      );

      if (!context.mounted) return;

      if (selected == 'open') {
        ref.read(currentDestinationProvider.notifier).state =
            AppDestination.tag;
        ref.read(selectedTagFilterProvider.notifier).state = tag.name;
        ref.read(selectedTagIdProvider.notifier).state = tag.id;
        ref.read(notesQueryProvider.notifier).setTag(tag.name);
        onItemSelected?.call();
      } else if (selected == 'nested') {
        final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
        final existingNames = allTags.map((x) => x.name).toList();
        final newTag = await TagCreateDialog.showNested(
          context,
          parentTag: tag,
          existingTags: existingNames,
        );
        if (newTag != null && context.mounted) {
          final service = ref.read(tagServiceProvider);
          await service.createTag(
            newTag.name,
            icon: newTag.icon,
            color: newTag.color,
            isPinned: newTag.isPinned,
          );
          final currentExpanded = ref.read(expandedTagPathsProvider);
          if (!currentExpanded.contains(tag.name)) {
            ref.read(expandedTagPathsProvider.notifier).toggle(tag.name);
          }
          if (context.mounted) {
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
      } else if (selected == 'pin') {
        ref.read(tagServiceProvider).pinTag(tag.id, !tag.isPinned);
      } else if (selected == 'rename') {
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
      } else if (selected == 'icon') {
        final newIcon = await TagIconPickerSheet.show(
          context,
          currentIconId: tag.icon,
          tagName: tag.name,
        );
        if (context.mounted) {
          await ref.read(tagServiceProvider).setTagIcon(tag.id, newIcon);
        }
      } else if (selected == 'color') {
        final newColor = await TagColorPickerSheet.show(
          context,
          currentColorId: tag.color,
        );
        if (context.mounted) {
          await ref.read(tagServiceProvider).setTagColor(tag.id, newColor);
        }
      } else if (selected == 'delete') {
        final mode = await TagDeleteDialog.showWithMode(
          context,
          tag: tag,
          hasDescendants: _tagHasDescendants(ref, tag),
        );
        if (mode != null && context.mounted) {
          await ref.read(tagServiceProvider).deleteTag(tag.id, mode: mode);
          if (ref.read(selectedTagFilterProvider) == tag.name) {
            ref.read(currentDestinationProvider.notifier).state =
                AppDestination.allNotes;
            ref.read(selectedTagFilterProvider.notifier).state = null;
            ref.read(selectedTagIdProvider.notifier).state = null;
            ref.read(notesQueryProvider.notifier).setTag(null);
          }
        }
      }
      return;
    }

    QuietAdaptiveModal.show(
      context: context,
      type: AdaptiveModalType.popover,
      maxWidth: 280,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: PlatformLayoutHelper.isDesktop(context)
              ? AppRadii.borderMd
              : const BorderRadius.vertical(top: AppRadii.rLg),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdaptiveSheetDragHandle(),
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
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
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
                  ref.read(currentDestinationProvider.notifier).state =
                      AppDestination.tag;
                  ref.read(selectedTagFilterProvider.notifier).state = tag.name;
                  ref.read(selectedTagIdProvider.notifier).state = tag.id;
                  ref.read(notesQueryProvider.notifier).setTag(tag.name);
                  onItemSelected?.call();
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
                  final existingNames = allTags.map((x) => x.name).toList();
                  final newTag = await TagCreateDialog.showNested(
                    context,
                    parentTag: tag,
                    existingTags: existingNames,
                  );
                  if (newTag != null && context.mounted) {
                    final service = ref.read(tagServiceProvider);
                    await service.createTag(
                      newTag.name,
                      icon: newTag.icon,
                      color: newTag.color,
                      isPinned: newTag.isPinned,
                    );
                    final currentExpanded = ref.read(expandedTagPathsProvider);
                    if (!currentExpanded.contains(tag.name)) {
                      ref
                          .read(expandedTagPathsProvider.notifier)
                          .toggle(tag.name);
                    }
                    if (context.mounted) {
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
                  final existingNames = allTags.map((x) => x.name).toList();
                  final newName = await TagRenameDialog.show(
                    context,
                    tag: tag,
                    existingTags: existingNames,
                  );
                  if (newName != null &&
                      newName != tag.name &&
                      context.mounted) {
                    await ref
                        .read(tagServiceProvider)
                        .renameTag(tag.id, newName);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(selectedTagFilterProvider.notifier).state =
                          newName;
                      ref.read(notesQueryProvider.notifier).setTag(newName);
                    }
                  }
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final newIcon = await TagIconPickerSheet.show(
                    context,
                    currentIconId: tag.icon,
                    tagName: tag.name,
                  );
                  if (context.mounted) {
                    await ref
                        .read(tagServiceProvider)
                        .setTagIcon(tag.id, newIcon);
                  }
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final newColor = await TagColorPickerSheet.show(
                    context,
                    currentColorId: tag.color,
                  );
                  if (context.mounted) {
                    await ref
                        .read(tagServiceProvider)
                        .setTagColor(tag.id, newColor);
                  }
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final allTags = ref.read(allTagsProvider).valueOrNull ?? [];
                  final destination = await TagMergeDialog.show(
                    context,
                    sourceTag: tag,
                    availableTags: allTags,
                  );
                  if (destination != null && context.mounted) {
                    await ref
                        .read(tagServiceProvider)
                        .mergeTags(tag.id, destination.id);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(selectedTagFilterProvider.notifier).state =
                          destination.name;
                      ref.read(selectedTagIdProvider.notifier).state =
                          destination.id;
                      ref
                          .read(notesQueryProvider.notifier)
                          .setTag(destination.name);
                    }
                  }
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
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final mode = await TagDeleteDialog.showWithMode(
                    context,
                    tag: tag,
                    hasDescendants: _tagHasDescendants(ref, tag),
                  );
                  if (mode != null && context.mounted) {
                    await ref
                        .read(tagServiceProvider)
                        .deleteTag(tag.id, mode: mode);
                    if (ref.read(selectedTagFilterProvider) == tag.name) {
                      ref.read(currentDestinationProvider.notifier).state =
                          AppDestination.allNotes;
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
