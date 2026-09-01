import 'package:flutter/material.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_date_helper.dart';
import '../../../notes/domain/note_model.dart';

/// A time-oriented, editorial journal tile rendered in the All Entries chronological timeline.
class JournalTimelineTile extends StatefulWidget {
  const JournalTimelineTile({
    super.key,
    required this.note,
    required this.onTap,
    this.isHighlighted = false,
    this.onHighlightComplete,
  });

  final Note note;
  final VoidCallback onTap;
  final bool isHighlighted;
  final VoidCallback? onHighlightComplete;

  @override
  State<JournalTimelineTile> createState() => _JournalTimelineTileState();
}

class _JournalTimelineTileState extends State<JournalTimelineTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _highlightController;
  Animation<double>? _highlightAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  @override
  void didUpdateWidget(JournalTimelineTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isHighlighted && widget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  void _startHighlightAnimation() {
    final disableAnimations =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;

    if (disableAnimations) {
      widget.onHighlightComplete?.call();
      return;
    }

    _highlightController?.dispose();
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _highlightAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _highlightController!,
        curve: Curves.easeOutCubic,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onHighlightComplete?.call();
        }
      });

    _highlightController!.forward();
  }

  @override
  void dispose() {
    _highlightController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateStr = widget.note.journalDate;
    final parsedDate = dateStr != null
        ? JournalDateHelper.tryParseDateString(dateStr)
        : JournalDateHelper.toLocalDate(widget.note.createdAt);

    final dayNumber = parsedDate != null ? JournalDateHelper.formatDayTwoDigits(parsedDate.day) : '--';
    final weekdayShort = parsedDate != null ? JournalDateHelper.formatWeekdayShort(parsedDate) : '';
    final isToday = dateStr == JournalDateHelper.todayString();
    final fullDateDisplay = parsedDate != null
        ? JournalDateHelper.formatDisplayDate(parsedDate)
        : JournalDateHelper.formatDisplayDate(widget.note.createdAt);

    final semanticLabel = '$fullDateDisplay, ${widget.note.displayTitle}';

    return AnimatedBuilder(
      animation: _highlightAnimation ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        final highlightFactor = _highlightAnimation?.value ?? 0.0;
        final highlightBg = highlightFactor > 0
            ? colors.accent.withValues(alpha: 0.18 * highlightFactor)
            : Colors.transparent;

        return Material(
          color: highlightBg,
          child: child,
        );
      },
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: InkWell(
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Day Column
                SizedBox(
                  width: 44,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayNumber,
                        style: AppTypography.title.copyWith(
                          color: isToday ? colors.accent : colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        weekdayShort,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSpacing.sm),

                // Subtle vertical accent bar/indicator
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.only(top: 2, right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isToday
                        ? colors.accent.withValues(alpha: 0.8)
                        : colors.divider.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),

                // Right Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Note Title Row
                      Row(
                        children: [
                          if (widget.note.isPasswordProtected) ...[
                            Icon(
                              PhosphorIconsRegular.lock,
                              size: 14,
                              color: colors.textSecondary,
                            ),
                            const SizedBox(width: 5.0),
                          ],
                          Expanded(
                            child: Text(
                              widget.note.displayTitle,
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
                      if (widget.note.previewSnippet.isNotEmpty) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          widget.note.previewSnippet,
                          style: AppTypography.bodySmall.copyWith(
                            color: colors.textSecondary,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Tags metadata if present
                      if (widget.note.tags.isNotEmpty) ...[
                        const SizedBox(height: 6.0),
                        Wrap(
                          spacing: 6.0,
                          runSpacing: 4.0,
                          children: widget.note.tags.take(3).map((t) {
                            return Text(
                              '#$t',
                              style: AppTypography.caption.copyWith(
                                color: colors.textTertiary,
                                fontSize: 11.5,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
