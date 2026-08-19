import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/widgets/quiet_icon_button.dart';

/// In-note search and replace toolbar widget.
/// Provides real-time query search, previous/next match navigation,
/// match count indicators, and replace / replace all capabilities.
class InNoteSearchBar extends StatelessWidget {
  const InNoteSearchBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onClose,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.matchCount,
    required this.currentMatchIndex,
    this.showReplace = false,
    this.onToggleReplace,
    this.replaceController,
    this.replaceFocusNode,
    this.onReplace,
    this.onReplaceAll,
    this.isReadOnly = false,
  });

  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final VoidCallback onClose;
  final VoidCallback onPreviousMatch;
  final VoidCallback onNextMatch;
  final int matchCount;
  final int currentMatchIndex;
  final bool showReplace;
  final VoidCallback? onToggleReplace;
  final TextEditingController? replaceController;
  final FocusNode? replaceFocusNode;
  final VoidCallback? onReplace;
  final VoidCallback? onReplaceAll;
  final bool isReadOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final hasQuery = searchController.text.isNotEmpty;

    String matchText = '';
    if (hasQuery) {
      if (matchCount == 0) {
        matchText = '0/0';
      } else {
        final current = (currentMatchIndex >= 0 && currentMatchIndex < matchCount)
            ? currentMatchIndex + 1
            : 0;
        matchText = '$current/$matchCount';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: colors.divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: Search Query & Navigations
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4.0, right: 6.0),
                child: Icon(
                  Icons.search_rounded,
                  size: 19,
                  color: hasQuery ? colors.accent : colors.textSecondary,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontSize: 14.5,
                  ),
                  cursorColor: colors.accent,
                  decoration: InputDecoration(
                    hintText: 'Find in note...',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: colors.textTertiary,
                      fontSize: 14.5,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => onNextMatch(),
                ),
              ),
              if (matchText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Text(
                    matchText,
                    style: AppTypography.caption.copyWith(
                      color: matchCount > 0
                          ? colors.textSecondary
                          : colors.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              QuietIconButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: 'Previous match',
                size: 32,
                onPressed: (matchCount > 0) ? onPreviousMatch : null,
              ),
              QuietIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: 'Next match',
                size: 32,
                onPressed: (matchCount > 0) ? onNextMatch : null,
              ),
              if (!isReadOnly && onToggleReplace != null)
                QuietIconButton(
                  icon: Icons.find_replace_rounded,
                  tooltip: showReplace ? 'Hide replace' : 'Show replace',
                  size: 32,
                  isActive: showReplace,
                  onPressed: onToggleReplace,
                ),
              QuietIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Close search',
                size: 32,
                onPressed: onClose,
              ),
            ],
          ),

          // Row 2: Replace Bar (if enabled & not read-only)
          if (showReplace && !isReadOnly && replaceController != null) ...[
            Divider(color: colors.divider.withValues(alpha: 0.6), height: 1),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 6.0),
                  child: Icon(
                    Icons.edit_note_rounded,
                    size: 19,
                    color: colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: replaceController,
                    focusNode: replaceFocusNode,
                    style: AppTypography.bodyMedium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      hintText: 'Replace with...',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: colors.textTertiary,
                        fontSize: 14.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ActionChipButton(
                  label: 'Replace',
                  onPressed: (matchCount > 0) ? onReplace : null,
                  colors: colors,
                ),
                const SizedBox(width: 4.0),
                _ActionChipButton(
                  label: 'All',
                  tooltip: 'Replace all occurrences',
                  onPressed: (matchCount > 0) ? onReplaceAll : null,
                  colors: colors,
                ),
                const SizedBox(width: 4.0),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionChipButton extends StatelessWidget {
  const _ActionChipButton({
    required this.label,
    required this.onPressed,
    required this.colors,
    this.tooltip,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppColors colors;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;

    final child = Material(
      color: isEnabled ? colors.tagBackground : colors.tagBackground.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(6.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(6.0),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: isEnabled ? colors.textPrimary : colors.textTertiary,
              fontWeight: FontWeight.w600,
              fontSize: 12.0,
            ),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: child,
      );
    }
    return child;
  }
}
