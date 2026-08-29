import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/notes_query_provider.dart';
import '../../domain/notes_filter.dart';
import 'notes_filter_sheet.dart';

/// Renders a compact, contextual summary of active advanced query filters.
///
/// Invariants:
/// - Takes 0 vertical space when no advanced filters are active.
/// - Never duplicates the active tag from the tag bar.
/// - Does not display a redundant standalone Clear button.
/// - Collapses to at most 2 chips plus an accessible `+N` pill to avoid pushing note content down.
class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({
    super.key,
    this.horizontalPadding = AppSpacing.lg,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final query = ref.watch(notesQueryProvider);
    final filter = query.filter;

    if (!filter.hasAdvancedFilters) {
      return const SizedBox.shrink();
    }

    final chips = <_FilterChipData>[];

    // Extra tags beyond the primary selected tag (e.g., if multiple tags selected in Filter Sheet)
    if (filter.tags.length > 1) {
      final extraTags = filter.tags.skip(1);
      for (final tag in extraTags) {
        chips.add(
          _FilterChipData(
            label: '#$tag',
            onRemove: () => ref.read(notesQueryProvider.notifier).removeFilterTag(tag),
          ),
        );
      }
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

    // Display at most 2 individual chips, then +N
    const maxVisibleChips = 2;
    final visibleChips = chips.take(maxVisibleChips).toList();
    final overflowCount = chips.length - visibleChips.length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: 2.0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...visibleChips.map((chip) => Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: _ActiveChipWidget(
                    label: chip.label,
                    onRemove: chip.onRemove,
                  ),
                )),
            if (overflowCount > 0)
              Semantics(
                label: '$overflowCount additional filters active',
                button: true,
                child: Tooltip(
                  message: '$overflowCount additional filters active. Tap to view all filters.',
                  child: Material(
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderSm,
                      side: BorderSide(color: colors.divider, width: 0.8),
                    ),
                    child: InkWell(
                      onTap: () => NotesFilterSheet.show(context),
                      borderRadius: AppRadii.borderSm,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        child: Text(
                          '+$overflowCount',
                          style: AppTypography.caption.copyWith(
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
      padding: const EdgeInsets.only(left: 7, top: 2.5, bottom: 2.5, right: 4),
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
          Semantics(
            label: 'Remove $label filter',
            button: true,
            child: GestureDetector(
              onTap: onRemove,
              child: Icon(
                Icons.close_rounded,
                size: 13,
                color: colors.accentDark.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
