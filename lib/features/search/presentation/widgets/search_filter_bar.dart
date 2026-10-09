import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/search_provider.dart';

/// Segmented control for selecting the active Global Search category.
///
/// A single rounded track holds four equal segments; the selected segment is
/// marked by an elevated "thumb" that slides smoothly between positions. This
/// replaces the earlier row of four separately-bordered pills.
class SearchFilterBar extends ConsumerWidget {
  const SearchFilterBar({
    super.key,
    required this.results,
  });

  final GlobalSearchResults results;

  /// Index order of segments, used to position the sliding thumb.
  static const List<SearchFilter> _order = [
    SearchFilter.all,
    SearchFilter.notes,
    SearchFilter.documents,
    SearchFilter.tags,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final activeFilter = ref.watch(searchFilterProvider);
    final selectedIndex =
        _order.indexOf(activeFilter).clamp(0, _order.length - 1);

    final segments = <_SegmentData>[
      _SegmentData(SearchFilter.all, 'All', results.totalCount, 'search_filter_all'),
      _SegmentData(SearchFilter.notes, 'Notes', results.notesCount, 'search_filter_notes'),
      _SegmentData(SearchFilter.documents, 'Docs', results.documentsCount, 'search_filter_documents'),
      _SegmentData(SearchFilter.tags, 'Tags', results.tagsCount, 'search_filter_tags'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      color: colors.background,
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colors.surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / segments.length;
            return Stack(
              children: [
                // Sliding selection thumb.
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: colors.isDark ? 0.28 : 0.07),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                // Segment labels (drawn above the thumb).
                Row(
                  children: segments.map((seg) {
                    final isSelected = seg.filter == activeFilter;
                    return Expanded(
                      child: InkWell(
                        key: ValueKey(seg.keyId),
                        onTap: () => ref
                            .read(searchFilterProvider.notifier)
                            .state = seg.filter,
                        borderRadius: BorderRadius.circular(9),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                seg.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: isSelected
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            if (seg.count > 0) ...[
                              const SizedBox(width: 4),
                              Text(
                                '${seg.count}',
                                style: AppTypography.caption.copyWith(
                                  color: colors.textTertiary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SegmentData {
  const _SegmentData(this.filter, this.label, this.count, this.keyId);

  final SearchFilter filter;
  final String label;
  final int count;
  final String keyId;
}
