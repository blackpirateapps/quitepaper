import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/note_links/note_link_search_service.dart';
import '../../../../core/utils/date_formatter.dart';


/// A Notion-style inline autocomplete floating menu for selecting or creating note links.
class NoteLinkInlineMenu extends StatelessWidget {
  const NoteLinkInlineMenu({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.query,
    required this.onSelectNote,
    required this.onCreateNote,
    this.maxHeight = 240.0,
    this.width = 340.0,
    this.scrollController,
  });

  final List<NoteLinkSearchResultItem> items;
  final int selectedIndex;
  final String query;
  final ValueChanged<NoteLinkSearchResultItem> onSelectNote;
  final ValueChanged<String> onCreateNote;
  final double maxHeight;
  final double width;
  final ScrollController? scrollController;

  bool get _hasCreateOption => query.trim().isNotEmpty;
  int get _totalOptionCount => items.length + (_hasCreateOption ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: width,
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.borderMd,
          border: Border.all(
            color: colors.divider.withValues(alpha: 0.8),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 16.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Subtle Section Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 6.0),
              child: Text(
                'LINK TO NOTE',
                style: AppTypography.caption.copyWith(
                  color: colors.textTertiary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            // Scrollable List of Candidates
            Flexible(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 4.0),
                shrinkWrap: true,
                itemCount: _totalOptionCount,
                itemBuilder: (context, index) {
                  // Candidate note row
                  if (index < items.length) {
                    final item = items[index];
                    final isSelected = index == selectedIndex;
                    return _InlineNoteCandidateTile(
                      item: item,
                      isSelected: isSelected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelectNote(item);
                      },
                    );
                  }

                  // Create note row (last item)
                  final isSelected = index == selectedIndex;
                  return _InlineCreateNoteTile(
                    query: query.trim(),
                    isSelected: isSelected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onCreateNote(query.trim());
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineNoteCandidateTile extends StatelessWidget {
  const _InlineNoteCandidateTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NoteLinkSearchResultItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dateStr = DateFormatter.formatNoteTileTime(item.updatedAt);

    // Build subtitle metadata: e.g. "#math #notes · Yesterday" or snippet
    final tagsStr = item.tags.isNotEmpty
        ? item.tags.map((t) => '#$t').join(' ')
        : '';
    final subtitleText = tagsStr.isNotEmpty
        ? '$tagsStr · $dateStr'
        : (item.snippet.isNotEmpty ? item.snippet : dateStr);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? colors.accent.withValues(alpha: 0.12) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              item.isPasswordProtected
                  ? Icons.lock_outline_rounded
                  : Icons.description_outlined,
              size: 15,
              color: isSelected ? colors.accent : colors.textTertiary,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.displayTitle,
                    style: AppTypography.bodySmallMedium.copyWith(
                      color: isSelected ? colors.textPrimary : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1.0),
                  Text(
                    subtitleText,
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontSize: 11.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineCreateNoteTile extends StatelessWidget {
  const _InlineCreateNoteTile({
    required this.query,
    required this.isSelected,
    required this.onTap,
  });

  final String query;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected ? colors.accent.withValues(alpha: 0.12) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: colors.accent,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Create ',
                  style: AppTypography.bodySmallMedium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13.0,
                  ),
                  children: [
                    TextSpan(
                      text: '“$query”',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.accent,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
