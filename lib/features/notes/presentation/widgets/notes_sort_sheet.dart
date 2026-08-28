import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../application/notes_query_provider.dart';
import '../../domain/notes_filter.dart';
import '../../domain/notes_sort.dart';

/// Modal bottom sheet for configuring primary ordering and direction
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
            top: AppSpacing.md,
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
                  // Header Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SORT BY',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      QuietIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close sort menu',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

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
                    // Primary Sort Field Group
                    _SortGroupContainer(
                      children: [
                        _SortRow(
                          title: 'Recently Updated',
                          isSelected: sort.field == SortField.updated,
                          onTap: () {
                            ref.read(notesQueryProvider.notifier).setSort(
                                  sort.copyWith(field: SortField.updated),
                                );
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        _SortRow(
                          title: 'Recently Created',
                          isSelected: sort.field == SortField.created,
                          onTap: () {
                            ref.read(notesQueryProvider.notifier).setSort(
                                  sort.copyWith(field: SortField.created),
                                );
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        _SortRow(
                          title: 'Title',
                          isSelected: sort.field == SortField.title,
                          onTap: () {
                            ref.read(notesQueryProvider.notifier).setSort(
                                  sort.copyWith(field: SortField.title),
                                );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Sort Direction Header
                    Text(
                      'DIRECTION',
                      style: AppTypography.caption.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Sort Direction Group
                    _SortGroupContainer(
                      children: [
                        _SortRow(
                          title: SortDirection.descending.getDisplayName(sort.field),
                          isSelected: sort.direction == SortDirection.descending,
                          onTap: () {
                            ref.read(notesQueryProvider.notifier).setSort(
                                  sort.copyWith(direction: SortDirection.descending),
                                );
                          },
                        ),
                        Divider(color: colors.divider, height: 1, indent: 16),
                        _SortRow(
                          title: SortDirection.ascending.getDisplayName(sort.field),
                          isSelected: sort.direction == SortDirection.ascending,
                          onTap: () {
                            ref.read(notesQueryProvider.notifier).setSort(
                                  sort.copyWith(direction: SortDirection.ascending),
                                );
                          },
                        ),
                      ],
                    ),

                    if (query.context == NotesContext.active) ...[
                      const SizedBox(height: AppSpacing.lg),
                      // Pinned Group
                      Text(
                        'PINNED NOTES',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SortGroupContainer(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10.0,
                            ),
                            child: Row(
                              children: [
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
                                        'Show pinned notes at the beginning of the list',
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
                                    ref.read(notesQueryProvider.notifier).setSort(
                                          sort.copyWith(pinnedFirst: val),
                                        );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14.0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: isSelected ? colors.accentDark : colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
