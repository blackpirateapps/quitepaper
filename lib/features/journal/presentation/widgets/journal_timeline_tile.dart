import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_date_helper.dart';
import '../../../../core/location/location_models.dart';
import '../../../notes/domain/note_metadata_extractor.dart';
import '../../../notes/domain/note_model.dart';
import '../../../settings/application/default_settings_provider.dart';

/// A time-oriented, editorial journal tile rendered in the All Entries chronological timeline.
class JournalTimelineTile extends ConsumerStatefulWidget {
  const JournalTimelineTile({
    super.key,
    required this.note,
    required this.onTap,
    this.isSelected = false,
    this.isHighlighted = false,
    this.onHighlightComplete,
  });

  final Note note;
  final VoidCallback onTap;
  final bool isSelected;
  final bool isHighlighted;
  final VoidCallback? onHighlightComplete;

  @override
  ConsumerState<JournalTimelineTile> createState() => _JournalTimelineTileState();
}

class _JournalTimelineTileState extends ConsumerState<JournalTimelineTile>
    with SingleTickerProviderStateMixin {
  AnimationController? _highlightController;
  Animation<double>? _highlightAnimation;
  bool _isHovered = false;

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

  /// City-level display token from an address (first comma segment), falling back
  /// to coordinates. Small private helper for now; §2.2 will centralize this.
  String _cityLabel(JournalLocation loc) {
    final addr = loc.address.trim();
    if (addr.isEmpty) return loc.coordinatesString;
    final first = addr.split(',').first.trim();
    return first.isNotEmpty ? first : addr;
  }

  /// Builds the quiet place & weather dateline (Feature 1). Renders nothing (a
  /// zero-size box) when the setting is off, the note is locked, or neither a
  /// place nor weather exists — so absent metadata never changes tile height.
  Widget _buildDateline(AppColors colors) {
    if (widget.note.isPasswordProtected) return const SizedBox.shrink();
    final show = ref.watch(
      defaultSettingsProvider.select((s) => s.showPlaceAndWeatherOnEntries),
    );
    if (!show) return const SizedBox.shrink();

    final meta = NoteMetadataExtractor.extract(widget.note);
    final location = meta.location;
    final weather = meta.weather;
    final place = location != null ? _cityLabel(location) : null;
    final hasPlace = place != null && place.isNotEmpty;
    final hasWeather = weather != null && weather.isNotEmpty;
    if (!hasPlace && !hasWeather) return const SizedBox.shrink();

    final style = AppTypography.caption.copyWith(
      color: colors.textTertiary,
      fontSize: 11.5,
    );

    final spans = <InlineSpan>[];
    if (hasPlace) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 3.0),
          child: Icon(
            PhosphorIconsRegular.mapPin,
            size: 12,
            color: colors.textTertiary,
          ),
        ),
      ));
      spans.add(TextSpan(text: place));
    }
    if (hasWeather) {
      if (spans.isNotEmpty) {
        spans.add(const TextSpan(text: ' · '));
      }
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 3.0),
          child: Icon(
            weather.icon,
            size: 12,
            color: colors.textTertiary,
          ),
        ),
      ));
      spans.add(TextSpan(text: '${weather.temperature.round()}°'));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5.0),
      child: Text.rich(
        TextSpan(style: style, children: spans),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
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

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _highlightAnimation ?? const AlwaysStoppedAnimation(0.0),
      builder: (context, child) {
        final highlightFactor = _highlightAnimation?.value ?? 0.0;
        final highlightBg = highlightFactor > 0
            ? colors.accent.withValues(alpha: 0.18 * highlightFactor)
            : (widget.isSelected
                ? (isDark
                    ? colors.surfaceSubtle
                    : colors.selection.withValues(alpha: 0.5))
                : (_isHovered
                    ? colors.surfaceSubtle.withValues(alpha: 0.45)
                    : Colors.transparent));

        return Material(
          color: highlightBg,
          child: child,
        );
      },
      child: Semantics(
        label: semanticLabel,
        selected: widget.isSelected,
        button: true,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
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
                            color: (isToday || widget.isHighlighted || widget.isSelected)
                                ? colors.accent
                                : colors.textPrimary,
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
                      color: (isToday || widget.isHighlighted || widget.isSelected)
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

                      // Quiet place & weather dateline (Feature 1)
                      _buildDateline(colors),

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
    ),
  );
}
}
