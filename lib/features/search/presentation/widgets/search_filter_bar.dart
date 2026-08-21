import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/search_provider.dart';

/// Horizontal filter chip selector for Global Search
class SearchFilterBar extends ConsumerWidget {
  const SearchFilterBar({
    super.key,
    required this.results,
  });

  final GlobalSearchResults results;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final activeFilter = ref.watch(searchFilterProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(
            color: colors.divider.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip(
            context: context,
            ref: ref,
            filter: SearchFilter.all,
            label: 'All',
            count: results.totalCount,
            isSelected: activeFilter == SearchFilter.all,
            colors: colors,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildFilterChip(
            context: context,
            ref: ref,
            filter: SearchFilter.notes,
            label: 'Notes',
            count: results.notesCount,
            isSelected: activeFilter == SearchFilter.notes,
            colors: colors,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildFilterChip(
            context: context,
            ref: ref,
            filter: SearchFilter.documents,
            label: 'Documents & OCR',
            count: results.documentsCount,
            isSelected: activeFilter == SearchFilter.documents,
            colors: colors,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildFilterChip(
            context: context,
            ref: ref,
            filter: SearchFilter.tags,
            label: 'Tags',
            count: results.tagsCount,
            isSelected: activeFilter == SearchFilter.tags,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required WidgetRef ref,
    required SearchFilter filter,
    required String label,
    required int count,
    required bool isSelected,
    required AppColors colors,
  }) {
    return InkWell(
      onTap: () {
        ref.read(searchFilterProvider.notifier).state = filter;
      },
      borderRadius: BorderRadius.circular(20.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.surface,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? colors.accent
                : colors.divider.withValues(alpha: 0.8),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: isSelected ? colors.accent : colors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12.5,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accent
                      : colors.divider.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : colors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
