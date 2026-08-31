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
/// Only renders when active backlinks exist; completely vanishes when active count is zero.
class BacklinksSection extends ConsumerStatefulWidget {
  const BacklinksSection({
    super.key,
    required this.noteId,
    required this.onOpenNote,
    this.initialMaxVisible = 3,
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
      data: (result) {
        if (result.activeBacklinks.isEmpty) {
          return const SizedBox.shrink();
        }

        return _buildBacklinksContent(context, result);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildBacklinksContent(BuildContext context, BacklinkQueryResult result) {
    final colors = context.appColors;
    final activeBacklinks = result.activeBacklinks;
    final totalCount = activeBacklinks.length;
    final hasMore = totalCount > widget.initialMaxVisible && !_isExpanded;
    final visibleItems = hasMore
        ? activeBacklinks.sublist(0, widget.initialMaxVisible)
        : activeBacklinks;
    final hiddenCount = totalCount - widget.initialMaxVisible;

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final animationDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Subtle editorial divider
          Divider(
            height: 1,
            thickness: 0.8,
            color: colors.divider.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header: LINKED FROM · N (Understated uppercase caption)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              'LINKED FROM · $totalCount',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Backlink items with smooth animated expansion
          AnimatedSize(
            duration: animationDuration,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in visibleItems)
                  _BacklinkItemTile(
                    item: item,
                    onTap: () => widget.onOpenNote(item.sourceNote),
                  ),
              ],
            ),
          ),

          // Expand / collapse button
          if (hasMore) ...[
            const SizedBox(height: 2.0),
            Semantics(
              button: true,
              label: 'Show $hiddenCount more backlinks',
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: AppRadii.borderSm,
                  onTap: () {
                    setState(() {
                      _isExpanded = true;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: Text(
                      'Show $hiddenCount more',
                      style: AppTypography.caption.copyWith(
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ] else if (_isExpanded && totalCount > widget.initialMaxVisible) ...[
            const SizedBox(height: 2.0),
            Semantics(
              button: true,
              label: 'Show fewer backlinks',
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  borderRadius: AppRadii.borderSm,
                  onTap: () {
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                    child: Text(
                      'Show less',
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Subtle indication for backlinks residing in Trash
          if (result.trashedBacklinksCount > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
              child: Text(
                '+ ${result.trashedBacklinksCount} in Trash',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary.withValues(alpha: 0.65),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A quiet, two-line backlink item tile.
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

    // Build subtitle metadata string (e.g. "#math #notes · Yesterday" or "Yesterday")
    final tagsStr = item.tags.isNotEmpty
        ? item.tags.map((t) => '#$t').join(' ')
        : '';
    final metadataStr = tagsStr.isNotEmpty ? '$tagsStr · $dateStr' : dateStr;

    return Semantics(
      button: true,
      label: 'Open linked note: ${item.displayTitle}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Line 1: Dominant Title + Lock Icon + Multiplier
                Row(
                  children: [
                    if (item.isPasswordProtected) ...[
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        item.displayTitle,
                        style: AppTypography.bodySmallMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.occurrencesCount > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.1),
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
                    ],
                  ],
                ),
                const SizedBox(height: 2.0),

                // Line 2: Subtle Metadata (Tags & Relative Timestamp)
                Text(
                  metadataStr,
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
