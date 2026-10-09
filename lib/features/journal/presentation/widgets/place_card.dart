import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../tags/domain/phosphor_icons.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/journal/domain/journal_place.dart';

/// Formats a place's [firstDate]→[lastDate] span editorially:
/// `Oct 2024` for a single visit, `2024` within one year, else `2019 – 2026`.
String placeDateSpanLabel(JournalPlace place) {
  if (place.isSingleVisit) {
    return DateFormat('MMM yyyy').format(place.firstDate);
  }
  if (place.firstDate.year == place.lastDate.year) {
    return '${place.firstDate.year}';
  }
  return '${place.firstDate.year} – ${place.lastDate.year}';
}

/// Splits a place display name into a primary token and an optional secondary
/// (region/country) tail. `Kolkata, West Bengal` → (`Kolkata`, `West Bengal`);
/// `Kolkata` → (`Kolkata`, null).
({String primary, String? secondary}) splitPlaceName(String displayName) {
  final idx = displayName.indexOf(',');
  if (idx < 0) return (primary: displayName.trim(), secondary: null);
  final primary = displayName.substring(0, idx).trim();
  final secondary = displayName.substring(idx + 1).trim();
  return (
    primary: primary.isEmpty ? displayName.trim() : primary,
    secondary: secondary.isEmpty ? null : secondary,
  );
}

/// A typographic, map-free place card for the Places list (§6.2).
class PlaceCard extends StatefulWidget {
  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
  });

  final JournalPlace place;
  final VoidCallback onTap;

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final place = widget.place;
    final name = splitPlaceName(place.displayName);
    final span = placeDateSpanLabel(place);
    final entryLabel =
        '${place.entryCount} ${place.entryCount == 1 ? 'entry' : 'entries'}';

    final semanticLabel = name.secondary != null
        ? '${name.primary}, ${name.secondary}, $entryLabel, $span'
        : '${name.primary}, $entryLabel, $span';

    final backgroundColor = _isHovered
        ? colors.surfaceSubtle.withValues(alpha: isDark ? 0.5 : 0.45)
        : Colors.transparent;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: backgroundColor,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.primary,
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (name.secondary != null) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            name.secondary!,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6.0),
                        Text(
                          '$span · $entryLabel',
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    PhosphorIconsRegular.caretRight,
                    size: 16,
                    color: colors.textTertiary,
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
