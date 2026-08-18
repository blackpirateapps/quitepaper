import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';
import '../../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../../domain/note_model.dart';

class NoteListTile extends StatelessWidget {
  const NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    this.searchQuery,
    this.onTogglePin,
    this.onArchive,
    this.onUnarchive,
    this.onTrash,
    this.onRestore,
    this.onDeletePermanently,
    this.onDelete,
    this.onTagTap,
    this.isSelected = false,
    this.isMultiSelecting = false,
    this.isItemMultiSelected = false,
    this.onItemMultiSelectToggle,
  });

  final Note note;
  final VoidCallback onTap;
  final String? searchQuery;
  final VoidCallback? onTogglePin;
  final VoidCallback? onArchive;
  final VoidCallback? onUnarchive;
  final VoidCallback? onTrash;
  final VoidCallback? onRestore;
  final VoidCallback? onDeletePermanently;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onTagTap;
  final bool isSelected;
  final bool isMultiSelecting;
  final bool isItemMultiSelected;
  final VoidCallback? onItemMultiSelectToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final formattedTime = note.isTrashed
        ? 'Moved to Trash · ${DateFormatter.formatNoteTileTime(note.deletedAt ?? note.updatedAt)}'
        : DateFormatter.formatNoteTileTime(note.updatedAt);
    final preview = note.previewSnippet;

    return Material(
      color: (isSelected || isItemMultiSelected)
          ? colors.selection.withValues(alpha: 0.5)
          : Colors.transparent,
      child: InkWell(
        onTap: isMultiSelecting ? onItemMultiSelectToggle : onTap,
        onLongPress: isMultiSelecting
            ? onItemMultiSelectToggle
            : () => _showContextMenu(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: 14.0,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: colors.divider.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMultiSelecting) ...[
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md, top: 2.0),
                  child: Icon(
                    isItemMultiSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: isItemMultiSelected
                        ? colors.accent
                        : colors.textTertiary,
                  ),
                ),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and relative time / pin row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (note.isPinned && !note.isTrashed && !note.isArchived) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0, right: 6.0),
                            child: Icon(
                              Icons.push_pin_rounded,
                              size: 14,
                              color: colors.accent,
                            ),
                          ),
                        ],
                        Expanded(
                          child: _buildHighlightedText(
                            text: note.displayTitle,
                            query: searchQuery,
                            baseStyle: AppTypography.bodyMedium.copyWith(
                              color: note.hasCustomTitle
                                  ? colors.textPrimary
                                  : colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16.5,
                            ),
                            highlightColor: colors.accent,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          formattedTime,
                          style: AppTypography.caption.copyWith(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Preview content snippet
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 5.0),
                      _buildHighlightedText(
                        text: preview,
                        query: searchQuery,
                        baseStyle: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                        highlightColor: colors.accent,
                        maxLines: 2,
                      ),
                    ] else if (note.hasCustomTitle) ...[
                      const SizedBox(height: 4.0),
                      Text(
                        'No content',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textTertiary.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                        ),
                      ),
                    ],

                    // Tags row
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Wrap(
                        spacing: 6.0,
                        runSpacing: 4.0,
                        children: note.tags.map((tag) {
                          return QuietTagChip(
                            tag: tag,
                            showBackground: true,
                            onTap: onTagTap != null ? () => onTagTap!(tag) : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText({
    required String text,
    required String? query,
    required TextStyle baseStyle,
    required Color highlightColor,
    int maxLines = 1,
  }) {
    if (query == null || query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final cleanQuery = query.trim();
    final searchPattern = cleanQuery.startsWith('#')
        ? cleanQuery.substring(1).trim()
        : cleanQuery;

    if (searchPattern.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final pattern = RegExp(RegExp.escape(searchPattern), caseSensitive: false);
    final matches = pattern.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(match.start, match.end),
        style: baseStyle.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.w700,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      semanticsLabel: text,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showContextMenu(BuildContext context) {
    final colors = context.appColors;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.isTrashed) ...[
                  // Trashed note context menu: Restore, Delete Permanently
                  ListTile(
                    leading: Icon(
                      Icons.restore_rounded,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Restore note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onRestore?.call();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Delete permanently',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final confirmed = await PermanentDeleteDialog.show(context, count: 1);
                      if (confirmed) {
                        onDeletePermanently?.call();
                      }
                    },
                  ),
                ] else if (note.isArchived) ...[
                  // Archived note context menu: Unarchive, Move to Trash
                  ListTile(
                    leading: Icon(
                      Icons.unarchive_outlined,
                      color: colors.textPrimary,
                    ),
                    title: Text(
                      'Unarchive note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onUnarchive?.call();
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Move to Trash',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (onTrash != null) {
                        onTrash!();
                      } else {
                        onDelete?.call();
                      }
                    },
                  ),
                ] else ...[
                  // Active note context menu: Pin/Unpin, Archive, Move to Trash
                  if (onTogglePin != null)
                    ListTile(
                      leading: Icon(
                        note.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        note.isPinned ? 'Unpin note' : 'Pin note',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onTogglePin!();
                      },
                    ),
                  if (onArchive != null)
                    ListTile(
                      leading: Icon(
                        Icons.archive_outlined,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        'Archive note',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        onArchive!();
                      },
                    ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: colors.error,
                    ),
                    title: Text(
                      'Move to Trash',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (onTrash != null) {
                        onTrash!();
                      } else {
                        onDelete?.call();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
