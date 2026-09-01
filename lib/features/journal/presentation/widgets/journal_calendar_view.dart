import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_date_helper.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../../notes/domain/note_model.dart';
import '../../application/journal_providers.dart';
import 'journal_month_year_picker.dart';

/// Interactive typeset paper calendar card supporting date browsing, entry previews,
/// and smooth timeline navigation.
class JournalCalendarView extends ConsumerWidget {
  const JournalCalendarView({
    super.key,
    required this.onOpenEntry,
    required this.onShowInTimeline,
  });

  final void Function(Note note) onOpenEntry;
  final void Function(String noteId, String journalDate) onShowInTimeline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final isCollapsed = ref.watch(calendarIsCollapsedProvider);
    final visibleMonth = ref.watch(calendarVisibleMonthProvider);
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final journalDatesAsync = ref.watch(
      journalDatesForMonthStreamProvider(visibleMonth),
    );
    final selectedEntryAsync = ref.watch(selectedDateJournalEntryProvider);

    final now = DateTime.now();
    final isCurrentMonth = visibleMonth.year == now.year && visibleMonth.month == now.month;
    final monthDisplayTitle = JournalDateHelper.formatMonthYear(
      DateTime(visibleMonth.year, visibleMonth.month),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceSubtle.withValues(alpha: 0.5),
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider.withValues(alpha: 0.5), width: 0.7),
      ),
      child: isCollapsed
          ? _buildCollapsedHeader(context, ref, colors, monthDisplayTitle, isCurrentMonth, now)
          : _buildExpandedCalendar(
              context,
              ref,
              colors,
              visibleMonth,
              monthDisplayTitle,
              isCurrentMonth,
              selectedDate,
              journalDatesAsync.valueOrNull ?? const {},
              selectedEntryAsync.valueOrNull,
              now,
            ),
    );
  }

  Widget _buildCollapsedHeader(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    String monthDisplayTitle,
    bool isCurrentMonth,
    DateTime now,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: () {
        ref.read(calendarIsCollapsedProvider.notifier).state = false;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.calendarDots,
              size: 17,
              color: colors.accent,
            ),
            const SizedBox(width: 8.0),
            Flexible(
              child: Text(
                monthDisplayTitle,
                style: AppTypography.title.copyWith(
                  color: colors.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            if (!isCurrentMonth)
              Padding(
                padding: const EdgeInsets.only(right: 6.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(calendarVisibleMonthProvider.notifier).state =
                        (year: now.year, month: now.month);
                    ref.read(calendarSelectedDateProvider.notifier).state = null;
                  },
                  child: Text(
                    'Today',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            Icon(
              PhosphorIconsRegular.caretDown,
              size: 15,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCalendar(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    ({int year, int month}) visibleMonth,
    String monthDisplayTitle,
    bool isCurrentMonth,
    String? selectedDate,
    Set<String> journalDates,
    Note? selectedEntry,
    DateTime now,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month navigation bar: ‹  September 2026  ›
        Row(
          children: [
            QuietIconButton(
              icon: PhosphorIconsRegular.caretLeft,
              tooltip: 'Previous month',
              onPressed: () {
                final prev = JournalDateHelper.previousMonth(visibleMonth.year, visibleMonth.month);
                ref.read(calendarVisibleMonthProvider.notifier).state = prev;
                ref.read(calendarSelectedDateProvider.notifier).state = null;
              },
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: () {
                    final monthGroups = ref.read(journalMonthGroupsProvider).valueOrNull ?? [];
                    final yearsWithEntries = monthGroups.map((g) => g.year).toSet();

                    JournalMonthYearPicker.show(
                      context,
                      initialYear: visibleMonth.year,
                      initialMonth: visibleMonth.month,
                      yearsWithEntries: yearsWithEntries,
                      onMonthSelected: (y, m) {
                        ref.read(calendarVisibleMonthProvider.notifier).state = (year: y, month: m);
                        ref.read(calendarSelectedDateProvider.notifier).state = null;
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            monthDisplayTitle,
                            style: AppTypography.title.copyWith(
                              color: colors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Icon(
                          PhosphorIconsRegular.caretUpDown,
                          size: 13,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!isCurrentMonth)
              Padding(
                padding: const EdgeInsets.only(right: 2.0),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(calendarVisibleMonthProvider.notifier).state =
                        (year: now.year, month: now.month);
                    ref.read(calendarSelectedDateProvider.notifier).state = null;
                  },
                  child: Text(
                    'Today',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            QuietIconButton(
              icon: PhosphorIconsRegular.caretRight,
              tooltip: 'Next month',
              onPressed: () {
                final next = JournalDateHelper.nextMonth(visibleMonth.year, visibleMonth.month);
                ref.read(calendarVisibleMonthProvider.notifier).state = next;
                ref.read(calendarSelectedDateProvider.notifier).state = null;
              },
            ),
          ],
        ),

        const SizedBox(height: 4.0),

        // Weekdays row (M, T, W, T, F, S, S)
        Row(
          children: const [
            _WeekdayLabel('M'),
            _WeekdayLabel('T'),
            _WeekdayLabel('W'),
            _WeekdayLabel('T'),
            _WeekdayLabel('F'),
            _WeekdayLabel('S'),
            _WeekdayLabel('S'),
          ],
        ),

        const SizedBox(height: 2.0),
        Divider(color: colors.divider.withValues(alpha: 0.4), height: 1, thickness: 0.6),
        const SizedBox(height: 2.0),

        // Calendar Grid
        _buildCalendarGrid(context, ref, colors, visibleMonth, selectedDate, journalDates, now),

        // Selected Date Preview
        if (selectedDate != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Divider(color: colors.divider.withValues(alpha: 0.5), height: 1, thickness: 0.7),
          const SizedBox(height: AppSpacing.sm),
          _SelectedDatePreview(
            dateString: selectedDate,
            entry: selectedEntry,
            onOpenEntry: () {
              if (selectedEntry != null) {
                onOpenEntry(selectedEntry);
              }
            },
            onShowInTimeline: () {
              if (selectedEntry != null) {
                onShowInTimeline(selectedEntry.id, selectedDate);
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    ({int year, int month}) visibleMonth,
    String? selectedDate,
    Set<String> journalDates,
    DateTime now,
  ) {
    final daysCount = JournalDateHelper.daysInMonth(visibleMonth.year, visibleMonth.month);
    final firstWeekday = JournalDateHelper.firstWeekdayOfMonth(visibleMonth.year, visibleMonth.month); // 1 = Mon .. 7 = Sun
    final leadingPadding = firstWeekday - 1; // Number of blank cells before the 1st
    final totalCells = leadingPadding + daysCount;
    final totalRows = (totalCells / 7).ceil();

    final todayStr = JournalDateHelper.todayString(now);

    return Column(
      children: List.generate(totalRows, (rowIndex) {
        return Row(
          children: List.generate(7, (colIndex) {
            final cellIndex = rowIndex * 7 + colIndex;
            final dayNumber = cellIndex - leadingPadding + 1;

            if (dayNumber < 1 || dayNumber > daysCount) {
              return const Expanded(child: SizedBox(height: 32));
            }

            final cellDateStr =
                '${visibleMonth.year.toString().padLeft(4, '0')}-${visibleMonth.month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
            final hasEntry = journalDates.contains(cellDateStr);
            final isToday = cellDateStr == todayStr;
            final isSelected = cellDateStr == selectedDate;

            final parsed = DateTime(visibleMonth.year, visibleMonth.month, dayNumber);
            final fullDateDisplay = JournalDateHelper.formatDisplayDate(parsed);
            final semanticLabel = isToday
                ? '$fullDateDisplay, today${hasEntry ? ', journal entry exists' : ', no journal entry'}'
                : '$fullDateDisplay${hasEntry ? ', journal entry exists' : ', no journal entry'}';

            return Expanded(
              child: Semantics(
                label: semanticLabel,
                selected: isSelected,
                button: true,
                child: Material(
                  color: isSelected
                      ? colors.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6.0),
                    onTap: () {
                      if (isSelected) {
                        ref.read(calendarSelectedDateProvider.notifier).state = null;
                      } else {
                        ref.read(calendarSelectedDateProvider.notifier).state = cellDateStr;
                      }
                    },
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6.0),
                        border: isToday
                            ? Border.all(color: colors.accent, width: 1.1)
                            : (isSelected
                                ? Border.all(
                                    color: colors.accent.withValues(alpha: 0.4),
                                    width: 0.8,
                                  )
                                : null),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: AppTypography.bodySmall.copyWith(
                              color: isSelected
                                  ? colors.accent
                                  : (isToday ? colors.accent : colors.textPrimary),
                              fontWeight: isToday || isSelected || hasEntry
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 12.5,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 1.5),
                          // Understated entry dot indicator
                          Container(
                            width: 3.5,
                            height: 3.5,
                            decoration: BoxDecoration(
                              color: hasEntry ? colors.accent : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 11.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedDatePreview extends StatelessWidget {
  const _SelectedDatePreview({
    required this.dateString,
    required this.entry,
    required this.onOpenEntry,
    required this.onShowInTimeline,
  });

  final String dateString;
  final Note? entry;
  final VoidCallback onOpenEntry;
  final VoidCallback onShowInTimeline;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final parsed = JournalDateHelper.tryParseDateString(dateString);
    final headerLabel = parsed != null
        ? JournalDateHelper.formatDisplayDate(parsed).toUpperCase()
        : dateString.toUpperCase();

    if (entry == null) {
      // Empty preview: date has no journal entry
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8.0),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: colors.divider.withValues(alpha: 0.5), width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerLabel,
              style: AppTypography.caption.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 3.0),
            Text(
              'No journal entry',
              style: AppTypography.bodySmall.copyWith(
                color: colors.textTertiary,
                fontSize: 13.0,
              ),
            ),
          ],
        ),
      );
    }

    final relativeTime = JournalDateHelper.formatTimelineEntryMetadata(
      dateString,
      entry!.updatedAt,
    );

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onOpenEntry,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: colors.divider, width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      headerLabel,
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (relativeTime.isNotEmpty) ...[
                    const SizedBox(width: 8.0),
                    Text(
                      relativeTime,
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6.0),

              // Title (Dominant element)
              Row(
                children: [
                  if (entry!.isPasswordProtected) ...[
                    Icon(
                      PhosphorIconsRegular.lock,
                      size: 14,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 5.0),
                  ],
                  Expanded(
                    child: Text(
                      entry!.displayTitle,
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (entry!.previewSnippet.isNotEmpty) ...[
                const SizedBox(height: 4.0),
                Text(
                  entry!.previewSnippet,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onShowInTimeline,
                  icon: Text(
                    'Show in All Entries',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  label: Icon(
                    PhosphorIconsRegular.arrowRight,
                    size: 14,
                    color: colors.accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
