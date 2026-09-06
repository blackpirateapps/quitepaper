import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../tags/domain/phosphor_icons.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import '../../../core/journal/domain/journal_models.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/domain/note_model.dart';
import '../application/journal_providers.dart';

class OnThisDayView extends ConsumerWidget {
  const OnThisDayView({
    super.key,
    this.onNoteSelected,
  });

  /// Optional callback when an entry is selected (used on tablet 3-pane layout)
  final void Function(Note note)? onNoteSelected;

  void _handleNoteTap(BuildContext context, Note note) {
    if (onNoteSelected != null) {
      onNoteSelected!(note);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(note: note),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final entriesAsync = ref.watch(onThisDayEntriesStreamProvider);
    final historicalState = ref.watch(historicalWeekProvider);
    final today = ref.watch(historicalReferenceDateProvider);
    final monthDayLabel = JournalDateHelper.formatMonthDay(today);

    final hasHistoricalEntries = historicalState.yearGroups.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      body: CustomScrollView(
        slivers: [
          // 1. Exact Date Section Header
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.clockCounterClockwise,
                            size: 22,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            'ON THIS DAY',
                            style: AppTypography.caption.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.3,
                              fontSize: 12.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        monthDayLabel,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Divider(color: colors.divider, height: 1, thickness: 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Exact Date Section Content
          entriesAsync.when(
            data: (entries) {
              if (entries.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.xxl,
                        ),
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
                              'Nothing from this date yet.',
                              style: AppTypography.headline.copyWith(
                                color: colors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              hasHistoricalEntries
                                  ? 'Your memories from this time in previous years appear below.'
                                  : 'Your first entry here will appear next year.',
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
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final note = entries[index];
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _OnThisDayTile(
                              note: note,
                              onTap: () => _handleNoteTap(context, note),
                            ),
                            if (index < entries.length - 1)
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
                      ),
                    );
                  },
                  childCount: entries.length,
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xxl),
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'Unable to load historical entries.',
                    style: AppTypography.bodySmall.copyWith(color: colors.error),
                  ),
                ),
              ),
            ),
          ),

          // 3. Section Breathing Space (editorial spacing)
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.editorial),
          ),

          // 4. "THIS TIME IN PREVIOUS YEARS" Section Header
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.clock,
                        size: 22,
                        color: colors.accent,
                      ),
                      const SizedBox(width: 8.0),
                      Text(
                        'THIS TIME IN PREVIOUS YEARS',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Historical Content
          _buildHistoricalContent(context, ref, colors, historicalState),
        ],
      ),
    );
  }

  Widget _buildHistoricalContent(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    HistoricalWeekState state,
  ) {
    if (state.isLoading && state.yearGroups.isEmpty) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: CircularProgressIndicator.adaptive(),
          ),
        ),
      );
    }

    if (state.hasError && state.yearGroups.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  "Couldn't load older memories.",
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                QuietButton(
                  label: 'Try again',
                  variant: QuietButtonVariant.ghost,
                  onPressed: () {
                    HistoricalWeekActions.retry(ref);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.yearGroups.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsLight.clockCounterClockwise,
                    size: 44,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Nothing from this time yet.',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'Your memories will appear here in future years.',
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
      );
    }

    final showOlderRow = state.hasMoreOlderYears || state.hasError;

    return SliverPadding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Check if this is the bottom "Show older memories" / error row
            if (index == state.yearGroups.length) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: Column(
                      children: [
                        if (state.hasError) ...[
                          Text(
                            "Couldn't load older memories.",
                            style: AppTypography.bodySmall.copyWith(color: colors.error),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          QuietButton(
                            label: 'Try again',
                            variant: QuietButtonVariant.ghost,
                            onPressed: () {
                              HistoricalWeekActions.retry(ref);
                            },
                          ),
                        ] else if (state.hasMoreOlderYears) ...[
                          QuietButton(
                            label: 'Show older memories',
                            variant: QuietButtonVariant.ghost,
                            isLoading: state.isLoadingOlder,
                            onPressed: () {
                              HistoricalWeekActions.loadOlderMemories(ref);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }

            final group = state.yearGroups[index];
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Historical Period Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.period.periodLabel,
                              style: AppTypography.title.copyWith(
                                color: colors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Divider(color: colors.divider, height: 1, thickness: 0.8),
                          ],
                        ),
                      ),

                      // Day Groups
                      ...group.dayGroups.map((dayGroup) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day header
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                top: AppSpacing.md,
                                bottom: AppSpacing.xs,
                              ),
                              child: Text(
                                dayGroup.dayLabel,
                                style: AppTypography.caption.copyWith(
                                  color: colors.accent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            // Notes in this day
                            ...dayGroup.entries.asMap().entries.map((entry) {
                              final noteIndex = entry.key;
                              final note = entry.value;
                              return Column(
                                children: [
                                  _HistoricalNoteTile(
                                    note: note,
                                    onTap: () => _handleNoteTap(context, note),
                                  ),
                                  if (noteIndex < dayGroup.entries.length - 1)
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
                              );
                            }),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
          childCount: state.yearGroups.length + (showOlderRow ? 1 : 0),
        ),
      ),
    );
  }
}

class _OnThisDayTile extends StatelessWidget {
  const _OnThisDayTile({
    required this.note,
    required this.onTap,
  });

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateDisplay = note.journalDate != null
        ? JournalDateHelper.formatDisplayDate(note.journalDate!)
        : JournalDateHelper.formatDisplayDate(note.createdAt);

    final relativeYear = note.journalDate != null
        ? JournalDateHelper.formatRelativeYear(note.journalDate!)
        : JournalDateHelper.formatRelativeYear(note.createdAt);

    final semanticLabel = '$dateDisplay, ${note.displayTitle}, $relativeYear';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Year & Relative indicator
                Row(
                  children: [
                    Text(
                      dateDisplay,
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (relativeYear.isNotEmpty) ...[
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: colors.divider.withValues(alpha: 0.8),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          relativeYear,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6.0),

                // Note Title
                Row(
                  children: [
                    if (note.isPasswordProtected) ...[
                      Icon(
                        PhosphorIconsRegular.lock,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6.0),
                    ],
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Preview Snippet
                if (note.previewSnippet.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Text(
                    note.previewSnippet,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Tags chips if any
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: note.tags.take(4).map((tag) {
                      return Text(
                        '#$tag',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricalNoteTile extends StatelessWidget {
  const _HistoricalNoteTile({
    required this.note,
    required this.onTap,
  });

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final semanticLabel = '${note.displayTitle}, ${note.previewSnippet}';

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note Title with Lock Icon if protected
                Row(
                  children: [
                    if (note.isPasswordProtected) ...[
                      Icon(
                        PhosphorIconsRegular.lock,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6.0),
                    ],
                    Expanded(
                      child: Text(
                        note.displayTitle,
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Preview Snippet
                if (note.previewSnippet.isNotEmpty) ...[
                  const SizedBox(height: 4.0),
                  Text(
                    note.previewSnippet,
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Tags chips if any
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 6.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    children: note.tags.take(4).map((tag) {
                      return Text(
                        '#$tag',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
