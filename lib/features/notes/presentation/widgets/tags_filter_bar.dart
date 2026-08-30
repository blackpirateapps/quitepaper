import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/tag_parser.dart';
import '../../../tags/domain/tag_colors.dart';
import '../../../tags/domain/tag_icon_registry.dart';
import '../../application/notes_provider.dart';

class TagsFilterBar extends ConsumerStatefulWidget {
  const TagsFilterBar({super.key});

  @override
  ConsumerState<TagsFilterBar> createState() => _TagsFilterBarState();
}

class _TagsFilterBarState extends ConsumerState<TagsFilterBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToStart() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(selectedTagFilterProvider, (prev, next) {
      if (prev != next) {
        _scrollToStart();
      }
    });

    final tagsAsync = ref.watch(allTagsStreamProvider);
    final selectedFilter = ref.watch(selectedTagFilterProvider);

    return tagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) return const SizedBox.shrink();

        // If a tag is active, reorder the list so the active tag is placed right next to "All"
        final List<TagWithCount> displayTags = List.of(tags);
        if (selectedFilter != null) {
          final normalizedSelected = TagParser.normalizeTag(selectedFilter);
          final selectedIdx = displayTags.indexWhere(
            (t) => TagParser.normalizeTag(t.tag.name) == normalizedSelected,
          );
          if (selectedIdx > 0) {
            final selectedItem = displayTags.removeAt(selectedIdx);
            displayTags.insert(0, selectedItem);
          }
        }

        return Container(
          height: 38,
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: ListView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              // "All Notes" chip
              _FilterChipItem(
                label: 'All',
                isSelected: selectedFilter == null,
                onTap: () {
                  ref.read(selectedTagFilterProvider.notifier).state = null;
                  ref.read(selectedTagIdProvider.notifier).state = null;
                  if (ref.read(currentDestinationProvider) == AppDestination.tag) {
                    ref.read(currentDestinationProvider.notifier).state =
                        AppDestination.allNotes;
                  }
                },
              ),
              const SizedBox(width: AppSpacing.sm),
              ...displayTags.map((tagWithCount) {
                final isSelected = selectedFilter != null &&
                    TagParser.normalizeTag(selectedFilter) ==
                        TagParser.normalizeTag(tagWithCount.name);

                final isDark = Theme.of(context).brightness == Brightness.dark;
                final colorDef = TagColors.fromId(tagWithCount.color);
                final iconData = tagWithCount.icon != null
                    ? TagIconRegistry.getIconData(tagWithCount.icon)
                    : (tagWithCount.isPinned ? Icons.push_pin_rounded : null);

                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _FilterChipItem(
                    label: '#${tagWithCount.name}',
                    count: tagWithCount.noteCount,
                    isSelected: isSelected,
                    icon: iconData,
                    customColor: colorDef?.foreground(isDark),
                    customBg: colorDef?.background(isDark),
                    onTap: () {
                      if (isSelected) {
                        ref.read(selectedTagFilterProvider.notifier).state = null;
                        ref.read(selectedTagIdProvider.notifier).state = null;
                      } else {
                        ref.read(selectedTagFilterProvider.notifier).state =
                            tagWithCount.name;
                        ref.read(selectedTagIdProvider.notifier).state =
                            tagWithCount.id;
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
    this.icon,
    this.customColor,
    this.customBg,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;
  final Color? customColor;
  final Color? customBg;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final bg = isSelected
        ? colors.accentSoft
        : (customBg ?? colors.surface);
    final fg = isSelected
        ? colors.accentDark
        : (customColor ?? colors.textSecondary);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderSm,
        side: BorderSide(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.4)
              : (customColor?.withValues(alpha: 0.3) ?? colors.divider),
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
              if (icon != null) ...[
                Icon(icon, size: 12, color: fg),
                const SizedBox(width: 4),
              ],
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
