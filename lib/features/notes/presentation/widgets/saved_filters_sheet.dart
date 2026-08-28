import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_button.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../application/notes_query_provider.dart';
import '../../application/saved_filters_provider.dart';
import '../../domain/saved_filter.dart';

/// Modal bottom sheet to view, apply, rename, and delete saved smart views
class SavedFiltersSheet extends ConsumerWidget {
  const SavedFiltersSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SavedFiltersSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final savedFilters = ref.watch(savedFiltersProvider);

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
                        'SAVED SMART VIEWS',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                      QuietIconButton(
                        icon: Icons.close_rounded,
                        tooltip: 'Close smart views',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (savedFilters.isEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: colors.divider, width: 0.8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 32,
                            color: colors.textTertiary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'No saved smart views yet',
                            style: AppTypography.body.copyWith(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Configure filters and tap "Save as view" to pin your favorite query combinations.',
                            textAlign: TextAlign.center,
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: AppRadii.borderMd,
                        border: Border.all(color: colors.divider, width: 0.8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: savedFilters.length,
                        separatorBuilder: (_, _) => Divider(
                          color: colors.divider,
                          height: 1,
                          indent: 16,
                        ),
                        itemBuilder: (context, index) {
                          final item = savedFilters[index];
                          return _SavedFilterTile(
                            item: item,
                            onApply: () {
                              ref.read(notesQueryProvider.notifier).setFilters(item.query.filter);
                              ref.read(notesQueryProvider.notifier).setSort(item.query.sort);
                              Navigator.of(context).pop();
                            },
                            onRename: () => _renameDialog(context, ref, item),
                            onDelete: () => ref.read(savedFiltersProvider.notifier).delete(item.id),
                          );
                        },
                      ),
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

  Future<void> _renameDialog(
    BuildContext context,
    WidgetRef ref,
    SavedFilter item,
  ) async {
    final controller = TextEditingController(text: item.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final colors = ctx.appColors;
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.borderLg,
            side: BorderSide(color: colors.divider, width: 0.8),
          ),
          title: Text(
            'Rename Smart View',
            style: AppTypography.headline.copyWith(color: colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AppTypography.body.copyWith(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'View Name',
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: AppRadii.borderMd,
                borderSide: BorderSide(color: colors.divider, width: 0.8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: colors.textSecondary)),
            ),
            QuietButton(
              label: 'Save',
              variant: QuietButtonVariant.primary,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await ref.read(savedFiltersProvider.notifier).rename(item.id, controller.text.trim());
    }
  }
}

class _SavedFilterTile extends StatelessWidget {
  const _SavedFilterTile({
    required this.item,
    required this.onApply,
    required this.onRename,
    required this.onDelete,
  });

  final SavedFilter item;
  final VoidCallback onApply;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onApply,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12.0),
          child: Row(
            children: [
              Icon(
                Icons.bookmark_rounded,
                size: 20,
                color: colors.accent,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.body.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Sort: ${item.query.sort.field.displayName} • ${item.query.filter.activeFilterCount} filters',
                      style: AppTypography.caption.copyWith(color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More actions',
                icon: Icon(Icons.more_vert_rounded, size: 18, color: colors.textTertiary),
                onSelected: (action) {
                  if (action == 'rename') {
                    onRename();
                  } else if (action == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: colors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
