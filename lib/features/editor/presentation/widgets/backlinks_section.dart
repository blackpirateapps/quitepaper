import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/note_links/note_link_models.dart';
import '../../../../core/note_links/note_link_provider.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../notes/domain/note_model.dart';

/// A calm, editorial backlinks section displaying notes that link to the currently viewed note.
/// Only renders when backlinks exist; completely vanishes when count is zero.
class BacklinksSection extends ConsumerStatefulWidget {
  const BacklinksSection({
    super.key,
    required this.noteId,
    required this.onOpenNote,
    this.initialMaxVisible = 4,
  });

  final String noteId;
  final ValueChanged<Note> onOpenNote;
  final int initialMaxVisible;

  @override
  ConsumerState<BacklinksSection> createState() => _BacklinksSectionState();
}

class _BacklinksSectionState extends ConsumerState<BacklinksSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final backlinksAsync = ref.watch(backlinksForNoteProvider(widget.noteId));

    return backlinksAsync.when(
      data: (backlinks) {
        if (backlinks.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildBacklinksContent(context, backlinks);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }


  Widget _buildBacklinksContent(BuildContext context, List<BacklinkItem> backlinks) {
    final colors = context.appColors;
    final totalCount = backlinks.length;
    final hasMore = totalCount > widget.initialMaxVisible && !_isExpanded;
    final visibleItems = hasMore
        ? backlinks.sublist(0, widget.initialMaxVisible)
        : backlinks;
    final hiddenCount = totalCount - widget.initialMaxVisible;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thin divider line
          Divider(
            height: 1,
            thickness: 0.8,
            color: colors.divider.withValues(alpha: 0.8),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header: LINKED FROM · N
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 14,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'LINKED FROM · $totalCount',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Backlink items
          ...visibleItems.map((item) {
            return _BacklinkItemTile(
              item: item,
              onTap: () => widget.onOpenNote(item.sourceNote),
            );
          }),

          // Expand / collapse button
          if (hasMore) ...[
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              borderRadius: AppRadii.borderSm,
              onTap: () {
                setState(() {
                  _isExpanded = true;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Show all $hiddenCount more',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: colors.accent,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_isExpanded && totalCount > widget.initialMaxVisible) ...[
            const SizedBox(height: AppSpacing.xs),
            InkWell(
              borderRadius: AppRadii.borderSm,
              onTap: () {
                setState(() {
                  _isExpanded = false;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Show less',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_up_rounded,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BacklinkItemTile extends StatelessWidget {
  const _BacklinkItemTile({
    required this.item,
    required this.onTap,
  });

  final BacklinkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateStr = DateFormatter.formatNoteTileTime(item.updatedAt);

    return Material(

      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.borderMd,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
          child: Row(
            children: [
              // Subtle document icon
              Icon(
                item.isPasswordProtected
                    ? Icons.lock_outline_rounded
                    : Icons.description_outlined,
                size: 16,
                color: colors.accent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Title & Tags
              Expanded(
                child: Text(
                  item.displayTitle,
                  style: AppTypography.bodySmallMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Multiple links badge (if > 1)
              if (item.occurrencesCount > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.12),
                    borderRadius: AppRadii.borderSm,
                  ),
                  child: Text(
                    '×${item.occurrencesCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Date
              Text(
                dateStr,
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: colors.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
