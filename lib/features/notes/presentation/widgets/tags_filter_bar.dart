import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../application/notes_provider.dart';

class TagsFilterBar extends ConsumerWidget {
  const TagsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(allTagsStreamProvider);
    final selectedFilter = ref.watch(selectedTagFilterProvider);

    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        return Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              // "All Notes" chip
              _FilterChipItem(
                label: 'All',
                isSelected: selectedFilter == null,
                onTap: () {
                  ref.read(selectedTagFilterProvider.notifier).state = null;
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              ...tags.map((tagWithCount) {
                final isSelected = selectedFilter != null &&
                    TagParser.normalizeTag(selectedFilter) ==
                        TagParser.normalizeTag(tagWithCount.tag.name);

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChipItem(
                    label: '#${tagWithCount.tag.name}',
                    count: tagWithCount.noteCount,
                    isSelected: isSelected,
                    onTap: () {
                      if (isSelected) {
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                      } else {
                        ref.read(selectedTagFilterProvider.notifier).state =
                            tagWithCount.tag.name;
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = isSelected ? colors.accentSoft : colors.surface;
    final fg = isSelected ? colors.accentDark : colors.textSecondary;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderSm,
        side: BorderSide(
          color: isSelected ? colors.accent.withValues(alpha: 0.4) : colors.divider,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.compact,
            vertical: 6.0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: AppTypography.tag.copyWith(
                  color: fg,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '$count',
                  style: AppTypography.caption.copyWith(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
