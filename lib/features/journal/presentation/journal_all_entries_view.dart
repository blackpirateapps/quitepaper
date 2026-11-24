import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/domain/note_model.dart';
import '../../search/presentation/search_screen.dart';
import '../application/journal_providers.dart';
import 'widgets/journal_calendar_view.dart';
import 'widgets/journal_timeline_tile.dart';

/// The primary All Entries journal archive view combining an interactive typeset paper
/// calendar with a chronological timeline grouped by year and month.
class JournalAllEntriesView extends ConsumerStatefulWidget {
  const JournalAllEntriesView({
    super.key,
    this.onNoteSelected,
    this.selectedNoteId,
    this.isTablet = false,
    this.isSidebarVisible = true,
    this.onToggleSidebar,
    this.onOpenDrawer,
  });

  /// Optional callback when an entry is selected on tablet split view
  final void Function(Note note)? onNoteSelected;

  /// Currently selected note ID on tablet layout
  final String? selectedNoteId;

  /// Whether running within tablet 3-pane layout
  final bool isTablet;

  /// Whether navigation sidebar is visible on tablet layout
  final bool isSidebarVisible;

  /// Toggle sidebar callback for tablet layout
  final VoidCallback? onToggleSidebar;

  /// Open navigation drawer callback for phone layout
  final VoidCallback? onOpenDrawer;

  @override
  ConsumerState<JournalAllEntriesView> createState() => _JournalAllEntriesViewState();
}

class _JournalAllEntriesViewState extends ConsumerState<JournalAllEntriesView> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _entryKeys = {};
  int _jumpGeneration = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _navigateToEditor(Note note) {
    if (widget.onNoteSelected != null) {
      widget.onNoteSelected!(note);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(note: note),
        ),
      );
    }
  }

  /// Creates (or opens, if it already exists) the journal entry for [date],
  /// then selects that date in the calendar so it stays in context.
  Future<void> _createEntryForDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    ref.read(calendarVisibleMonthProvider.notifier).state =
        (year: normalized.year, month: normalized.month);
    ref.read(calendarSelectedDateProvider.notifier).state =
        JournalDateHelper.toDateString(normalized);

    await ref.read(journalServiceProvider).openOrCreateEntryFlow(
          context,
          normalized,
          isTablet: widget.isTablet,
          onTabletSelectNote: widget.onNoteSelected,
        );
  }

  /// Opens a date picker (today or earlier) to backfill a past journal entry.
  Future<void> _pickDateAndCreate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Add past entry',
    );
    if (picked == null || !mounted) return;
    await _createEntryForDate(picked);
  }

  Future<void> _jumpToEntry(String noteId, String journalDate) async {
    final generation = ++_jumpGeneration;
    ref.read(calendarIsCollapsedProvider.notifier).state = true;
    await WidgetsBinding.instance.endOfFrame;

    var estimated = false;
    var attempts = 0;
    while (mounted && generation == _jumpGeneration && _scrollController.hasClients) {
      final groups = ref.read(journalMonthGroupsProvider).valueOrNull ?? [];
      final entries = groups.expand((group) => group.entries).toList();
      final targetIndex = entries.indexWhere(
        (note) => note.id == noteId && note.journalDate == journalDate,
      );
      // Stop if a live update removed the target, or no layout progress is possible.
      if (targetIndex < 0 || attempts++ > entries.length + groups.length) return;

      // Lazy construction can create a key on any frame: always look it up afresh.
      final targetContext = _entryKeys[noteId]?.currentContext;
      if (targetContext != null && targetContext.mounted) {
        final reduceMotion =
            WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
        await Scrollable.ensureVisible(
          targetContext,
          duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.12,
        );
        if (mounted && generation == _jumpGeneration) {
          ref.read(highlightedJournalEntryIdProvider.notifier).state = noteId;
        }
        return;
      }

      final position = _scrollController.position;
      double nextOffset;
      if (!estimated) {
        // A coarse starting point only. Variable titles, snippets and tags make
        // both row heights and the sliver's total extent estimates inexact.
        estimated = true;
        nextOffset = position.maxScrollExtent * targetIndex / entries.length;
      } else {
        // Seek toward the target using the identities of actually built entries.
        // Overlapping viewport steps cannot skip a month, regardless of its height.
        var nearestIndex = 0;
        var nearestDistance = entries.length;
        for (var index = 0; index < entries.length; index++) {
          if (_entryKeys[entries[index].id]?.currentContext == null) continue;
          final distance = (index - targetIndex).abs();
          if (distance < nearestDistance) {
            nearestIndex = index;
            nearestDistance = distance;
          }
        }
        final direction = targetIndex > nearestIndex ? 1 : -1;
        nextOffset = position.pixels + direction * position.viewportDimension * 0.85;
      }
      nextOffset = nextOffset.clamp(position.minScrollExtent, position.maxScrollExtent);
      if (nextOffset == position.pixels) return;
      _scrollController.jumpTo(nextOffset);
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final monthGroupsAsync = ref.watch(journalMonthGroupsProvider);
    final highlightedId = ref.watch(highlightedJournalEntryIdProvider);
    final isCollapsed = ref.watch(calendarIsCollapsedProvider);

    return Container(
      color: colors.background,
      child: Column(
        children: [
          // Top Bar
          _buildTopBar(context, colors, isCollapsed),

          // Scrollable Content
          Expanded(
            child: monthGroupsAsync.when(
                data: (groups) {
                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      // Collapsible Calendar Card
                      SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: JournalCalendarView(
                              onOpenEntry: _navigateToEditor,
                              onShowInTimeline: _jumpToEntry,
                              onCreateEntry: _createEntryForDate,
                            ),
                          ),
                        ),
                      ),

                      // Empty timeline state
                      if (groups.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      PhosphorIconsLight.calendarBlank,
                                      size: 44,
                                      color: colors.textTertiary,
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    Text(
                                      'No journal entries yet.',
                                      style: AppTypography.headline.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Write your first entry in Today.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        // Chronological Month Groups
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 96.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, groupIndex) {
                                final group = groups[groupIndex];
                                return Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 680),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Month Header
                                        _buildMonthSectionHeader(colors, group.monthLabel),

                                        // Entries for this month
                                        ...group.entries.map((note) {
                                          final key = _entryKeys.putIfAbsent(
                                            note.id,
                                            () => GlobalKey(debugLabel: 'journal_${note.id}'),
                                          );

                                          return Container(
                                            key: key,
                                            child: Column(
                                              children: [
                                                JournalTimelineTile(
                                                  note: note,
                                                  isSelected: widget.selectedNoteId == note.id,
                                                  isHighlighted: highlightedId == note.id,
                                                  onHighlightComplete: () {
                                                    if (highlightedId == note.id) {
                                                      ref
                                                          .read(highlightedJournalEntryIdProvider.notifier)
                                                          .state = null;
                                                    }
                                                  },
                                                  onTap: () => _navigateToEditor(note),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: AppSpacing.lg,
                                                  ),
                                                  child: Divider(
                                                    color: colors.divider.withValues(alpha: 0.6),
                                                    height: 1,
                                                    thickness: 0.8,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),

                                        const SizedBox(height: AppSpacing.md),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: groups.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Unable to load journal archive.',
                      style: AppTypography.bodySmall.copyWith(color: colors.error),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppColors colors, bool isCalendarCollapsed) {
    if (widget.isTablet) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            QuietIconButton(
              icon: widget.isSidebarVisible
                  ? Icons.menu_open_rounded
                  : Icons.view_sidebar_outlined,
              tooltip: widget.isSidebarVisible ? 'Hide navigation' : 'Show navigation',
              onPressed: widget.onToggleSidebar,
            ),
            const SizedBox(width: 4.0),
            Expanded(
              child: Text(
                'All Entries',
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            QuietIconButton(
              icon: PhosphorIconsRegular.calendarPlus,
              tooltip: 'Add past entry',
              onPressed: _pickDateAndCreate,
            ),
            QuietIconButton(
              icon: PhosphorIconsRegular.magnifyingGlass,
              tooltip: 'Search notes',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
                );
              },
            ),
            QuietIconButton(
              icon: isCalendarCollapsed
                  ? PhosphorIconsRegular.calendar
                  : PhosphorIconsFill.calendarDots,
              tooltip: isCalendarCollapsed ? 'Expand calendar' : 'Collapse calendar',
              onPressed: () {
                ref.read(calendarIsCollapsedProvider.notifier).state = !isCalendarCollapsed;
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          QuietIconButton(
            icon: Icons.menu_rounded,
            tooltip: 'Open navigation',
            onPressed: widget.onOpenDrawer,
          ),
          const SizedBox(width: 4.0),
          Expanded(
            child: Text(
              'All Entries',
              style: AppTypography.title.copyWith(
                color: colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          QuietIconButton(
            icon: PhosphorIconsRegular.calendarPlus,
            tooltip: 'Add past entry',
            onPressed: _pickDateAndCreate,
          ),
          QuietIconButton(
            icon: PhosphorIconsRegular.magnifyingGlass,
            tooltip: 'Search notes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
              );
            },
          ),
          QuietIconButton(
            icon: isCalendarCollapsed
                ? PhosphorIconsRegular.calendar
                : PhosphorIconsFill.calendarDots,
            tooltip: isCalendarCollapsed ? 'Expand calendar' : 'Collapse calendar',
            onPressed: () {
              ref.read(calendarIsCollapsedProvider.notifier).state = !isCalendarCollapsed;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSectionHeader(AppColors colors, String monthLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        24.0,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: AppTypography.caption.copyWith(
              color: colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
              fontSize: 12.0,
            ),
          ),
          const SizedBox(height: 6.0),
          Divider(color: colors.divider, height: 1, thickness: 0.8),
        ],
      ),
    );
  }
}
