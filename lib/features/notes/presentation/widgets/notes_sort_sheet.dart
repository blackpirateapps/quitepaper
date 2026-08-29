import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../application/notes_query_provider.dart';
import '../../domain/notes_filter.dart';
import '../../domain/notes_sort.dart';

/// Compact, editorial modal bottom sheet for configuring note ordering, direction, and pin behavior
class NotesSortSheet extends ConsumerWidget {
  const NotesSortSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotesSortSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final query = ref.watch(notesQueryProvider);
    final sort = query.sort;
    final isTrash = query.context == NotesContext.trash;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: AppRadii.rLg),
            border: Border.all(color: colors.divider, width: 0.8),
          ),
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.xl,
            left: AppSpacing.lg,
            right: AppSpacing.lg,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subtle Drag Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Sort Notes',
                        style: AppTypography.title.copyWith(
                          color: colors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      QuietIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close sort menu',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (isTrash) ...[
                    // Trash context info
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: colors.divider, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: colors.textTertiary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Trash notes are automatically sorted by deletion date.',
                              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Unified Single Inset Group Container
                    _SortGroupContainer(
                      children: [
                        // 1. Recently Updated
                        _SortRow(
                          title: 'Recently Updated',
                          field: SortField.updated,
                          currentSort: sort,
                          onTap: () {
                            if (sort.field == SortField.updated) {
                              final nextDir = sort.direction == SortDirection.descending
                                  ? SortDirection.ascending
                                  : SortDirection.descending;
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(direction: nextDir),
                                  );
                            } else {
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(
                                      field: SortField.updated,
                                      direction: SortDirection.descending,
                                    ),
                                  );
                            }
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 40),

                        // 2. Recently Created
                        _SortRow(
                          title: 'Recently Created',
                          field: SortField.created,
                          currentSort: sort,
                          onTap: () {
                            if (sort.field == SortField.created) {
                              final nextDir = sort.direction == SortDirection.descending
                                  ? SortDirection.ascending
                                  : SortDirection.descending;
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(direction: nextDir),
                                  );
                            } else {
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(
                                      field: SortField.created,
                                      direction: SortDirection.descending,
                                    ),
                                  );
                            }
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 40),

                        // 3. Title
                        _SortRow(
                          title: 'Title',
                          field: SortField.title,
                          currentSort: sort,
                          onTap: () {
                            if (sort.field == SortField.title) {
                              final nextDir = sort.direction == SortDirection.ascending
                                  ? SortDirection.descending
                                  : SortDirection.ascending;
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(direction: nextDir),
                                  );
                            } else {
                              ref.read(notesQueryProvider.notifier).setSort(
                                    sort.copyWith(
                                      field: SortField.title,
                                      direction: SortDirection.ascending,
                                    ),
                                  );
                            }
                          },
                        ),

                        // 4. Keep Pinned on Top (Active context only)
                        if (query.context == NotesContext.active) ...[
                          Divider(color: colors.divider, height: 1, indent: 40),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10.0,
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 24 + AppSpacing.xs),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Keep Pinned on Top',
                                        style: AppTypography.body.copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        'Show pinned notes at the beginning',
                                        style: AppTypography.caption.copyWith(
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoSwitch(
                                  value: sort.pinnedFirst,
                                  activeTrackColor: colors.accent,
                                  onChanged: (val) {
                                    HapticFeedback.selectionClick();
                                    ref.read(notesQueryProvider.notifier).setSort(
                                          sort.copyWith(pinnedFirst: val),
                                        );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortGroupContainer extends StatelessWidget {
  const _SortGroupContainer({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.title,
    required this.field,
    required this.currentSort,
    required this.onTap,
  });

  final String title;
  final SortField field;
  final NotesSort currentSort;
  final VoidCallback onTap;

  bool get isSelected => currentSort.field == field;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final direction = isSelected
        ? currentSort.direction
        : (field == SortField.title ? SortDirection.ascending : SortDirection.descending);
    final directionLabel = direction.getDisplayName(field);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 13.0,
          ),
          child: Row(
            children: [
              // Checkmark icon
              SizedBox(
                width: 24,
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: colors.accent,
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: isSelected ? colors.textPrimary : colors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                _DirectionBadge(
                  label: directionLabel,
                  isDescending: direction == SortDirection.descending,
                  isTitle: field == SortField.title,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({
    required this.label,
    required this.isDescending,
    required this.isTitle,
  });

  final String label;
  final bool isDescending;
  final bool isTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    IconData icon;
    if (isTitle) {
      icon = isDescending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    } else {
      icon = isDescending ? Icons.south_rounded : Icons.north_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: colors.accentDark,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.accentDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
