import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/notes_query_provider.dart';
import '../../domain/notes_filter.dart';
import 'notes_filter_sheet.dart';

/// Renders compact removable chips for active query filters above the note list
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final query = ref.watch(notesQueryProvider);
    final filter = query.filter;

    if (filter.isEmpty) {
      return const SizedBox.shrink();
    }

    final chips = <_FilterChipData>[];

    // Tags
    for (final tag in filter.tags) {
      chips.add(
        _FilterChipData(
          label: '#$tag',
          onRemove: () => ref.read(notesQueryProvider.notifier).removeFilterTag(tag),
        ),
      );
    }

    // Untagged
    if (filter.untaggedOnly) {
      chips.add(
        _FilterChipData(
          label: 'Untagged',
          onRemove: () => ref.read(notesQueryProvider.notifier).setFilters(
                filter.copyWith(untaggedOnly: false),
              ),
        ),
      );
    }

    // Pinned
    if (filter.pinnedOnly) {
      chips.add(
        _FilterChipData(
          label: 'Pinned only',
          onRemove: () => ref.read(notesQueryProvider.notifier).setFilters(
                filter.copyWith(pinnedOnly: false),
              ),
        ),
      );
    }

    // Date Modified
    if (filter.modifiedRange != null) {
      chips.add(
        _FilterChipData(
          label: 'Mod: ${filter.modifiedRange!.displayName}',
          onRemove: () => ref.read(notesQueryProvider.notifier).setModifiedRange(null),
        ),
      );
    }

    // Date Created
    if (filter.createdRange != null) {
      chips.add(
        _FilterChipData(
          label: 'Created: ${filter.createdRange!.displayName}',
          onRemove: () => ref.read(notesQueryProvider.notifier).setCreatedRange(null),
        ),
      );
    }

    // Content Filters
    for (final c in filter.contentFilters) {
      chips.add(
        _FilterChipData(
          label: c.displayName,
          onRemove: () => ref.read(notesQueryProvider.notifier).toggleContentFilter(c),
        ),
      );
    }

    // Attachment Filters
    for (final a in filter.attachmentFilters) {
      chips.add(
        _FilterChipData(
          label: a.displayName,
          onRemove: () => ref.read(notesQueryProvider.notifier).toggleAttachmentFilter(a),
        ),
      );
    }

    // Security Filter
    if (filter.securityFilter != SecurityFilter.all) {
      chips.add(
        _FilterChipData(
          label: filter.securityFilter.displayName,
          onRemove: () => ref.read(notesQueryProvider.notifier).setFilters(
                filter.copyWith(securityFilter: SecurityFilter.all),
              ),
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    // Display at most 4 individual chips, then +N
    const maxVisibleChips = 4;
    final visibleChips = chips.take(maxVisibleChips).toList();
    final overflowCount = chips.length - visibleChips.length;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 6.0,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...visibleChips.map((chip) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: _ActiveChipWidget(
                          label: chip.label,
                          onRemove: chip.onRemove,
                        ),
                      )),
                  if (overflowCount > 0) ...[
                    Material(
                      color: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadii.borderSm,
                        side: BorderSide(color: colors.divider, width: 0.8),
                      ),
                      child: InkWell(
                        onTap: () => NotesFilterSheet.show(context),
                        borderRadius: AppRadii.borderSm,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            '+$overflowCount more',
                            style: AppTypography.caption.copyWith(
                              color: colors.accent,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          GestureDetector(
            onTap: () => ref.read(notesQueryProvider.notifier).clearAllFilters(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Clear',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChipData {
  const _FilterChipData({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;
}

class _ActiveChipWidget extends StatelessWidget {
  const _ActiveChipWidget({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: AppRadii.borderSm,
        border: Border.all(
          color: colors.accent.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.only(left: 8, top: 3, bottom: 3, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.accentDark,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 14,
              color: colors.accentDark.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
