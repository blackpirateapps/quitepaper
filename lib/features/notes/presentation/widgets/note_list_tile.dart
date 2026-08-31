import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/search/search_models.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/quiet_tag_chip.dart';
import '../../../export/presentation/export_note_sheet.dart';
import '../../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../../domain/note_metadata_extractor.dart';
import '../../domain/note_model.dart';
import 'note_thumbnail_view.dart';

/// Calm editorial note tile adopting the information hierarchy and density
/// of Bear Notes while preserving Quiet Paper's aesthetic across all theme families.
class NoteListTile extends StatefulWidget {
  const NoteListTile({
    super.key,
    required this.note,
    required this.onTap,
    this.searchQuery,
    this.precomputedSnippet,
    this.titleHighlightSpans,
    this.snippetHighlightSpans,
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
  final String? precomputedSnippet;
  final List<TokenSpanDto>? titleHighlightSpans;
  final List<TokenSpanDto>? snippetHighlightSpans;
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
  State<NoteListTile> createState() => _NoteListTileState();
}

class _NoteListTileState extends State<NoteListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final metadata = NoteMetadataExtractor.extract(
      widget.note,
      searchQuery: widget.searchQuery,
      precomputedSnippet: widget.precomputedSnippet,
    );

    final formattedTime = DateFormatter.formatNoteTileTime(
      widget.note.isTrashed
          ? (widget.note.deletedAt ?? widget.note.updatedAt)
          : widget.note.updatedAt,
    );

    final isHighlighted = widget.isSelected || widget.isItemMultiSelected;

    final backgroundColor = isHighlighted
        ? (isDark
            ? colors.surfaceSubtle
            : colors.selection.withValues(alpha: 0.5))
        : (_isHovered
            ? colors.surfaceSubtle.withValues(alpha: 0.45)
            : Colors.transparent);

    final semanticLabel = [
      metadata.displayTitle,
      if (widget.note.isPinned) 'pinned',
      if (widget.note.isPasswordProtected) 'password protected',
      'modified $formattedTime',
      if (metadata.previewSnippet.isNotEmpty) metadata.previewSnippet,
      if (metadata.attachmentSummary != null) metadata.attachmentSummary!,
      if (widget.note.tags.isNotEmpty) 'tags: ${widget.note.tags.join(", ")}',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      selected: isHighlighted,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: backgroundColor,
          child: InkWell(
            onTap: widget.isMultiSelecting
                ? widget.onItemMultiSelectToggle
                : widget.onTap,
            onLongPress: widget.isMultiSelecting
                ? widget.onItemMultiSelectToggle
                : () => _showContextMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: 12.0,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colors.divider.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-select Checkbox indicator
                  if (widget.isMultiSelecting) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        right: AppSpacing.md,
                        top: 2.0,
                      ),
                      child: Icon(
                        widget.isItemMultiSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: widget.isItemMultiSelected
                            ? colors.accent
                            : colors.textTertiary,
                      ),
                    ),
                  ],

                  // Main Note Info Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Primary Line: Title + Pin/Lock indicator + Time
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.note.isPasswordProtected) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2.0,
                                  right: 6.0,
                                ),
                                child: Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: colors.accent,
                                ),
                              ),
                            ] else if (widget.note.isPinned &&
                                !widget.note.isTrashed &&
                                !widget.note.isArchived) ...[
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 2.0,
                                  right: 6.0,
                                ),
                                child: Icon(
                                  Icons.push_pin_rounded,
                                  size: 14,
                                  color: colors.accent,
                                ),
                              ),
                            ],
                            Expanded(
                              child: _buildHighlightedText(
                                text: metadata.displayTitle,
                                query: widget.searchQuery,
                                precomputedSpans: widget.titleHighlightSpans,
                                baseStyle: AppTypography.bodyMedium.copyWith(
                                  color: metadata.hasCustomTitle ||
                                          metadata.displayTitle != 'Untitled'
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.5,
                                  height: 1.25,
                                ),
                                highlightColor: colors.searchHighlight,
                                highlightTextColor: colors.searchHighlightText,
                                textColor: colors.textPrimary,
                                maxLines: 2,
                              ),
                            ),
                            if (metadata.thumbnailUri == null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                formattedTime,
                                style: AppTypography.caption.copyWith(
                                  color: colors.textTertiary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),

                        // 2. Content Preview
                        if (metadata.previewSnippet.isNotEmpty) ...[
                          const SizedBox(height: 4.0),
                          _buildHighlightedText(
                            text: metadata.previewSnippet,
                            query: widget.searchQuery,
                            precomputedSpans: widget.snippetHighlightSpans,
                            baseStyle: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                              fontSize: 13.5,
                              height: 1.35,
                            ),
                            highlightColor: colors.searchHighlight,
                            highlightTextColor: colors.searchHighlightText,
                            textColor: colors.textPrimary,
                            maxLines: 2,
                          ),
                        ] else if (metadata.hasCustomTitle) ...[
                          const SizedBox(height: 3.0),
                          Text(
                            'No content',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textTertiary.withValues(alpha: 0.6),
                              fontSize: 13.0,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        // 3. Metadata Row (Tags, Attachment Text, and Time when thumbnail present)
                        if (widget.note.tags.isNotEmpty ||
                            metadata.attachmentSummary != null ||
                            metadata.thumbnailUri != null ||
                            widget.note.isTrashed) ...[
                          const SizedBox(height: 6.0),
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6.0,
                                  runSpacing: 4.0,
                                  children: [
                                    // Tags
                                    ...widget.note.tags.map((tag) {
                                      return QuietTagChip(
                                        tag: tag,
                                        onTap: () => widget.onTagTap?.call(tag),
                                      );
                                    }),

                                    // Attachment Metadata — TEXT, NOT ICONS
                                    if (metadata.attachmentSummary != null) ...[
                                      if (widget.note.tags.isNotEmpty)
                                        Text(
                                          '·',
                                          style: TextStyle(
                                            color: colors.textTertiary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      Text(
                                        metadata.attachmentSummary!,
                                        style: AppTypography.caption.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (metadata.thumbnailUri != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  formattedTime,
                                  style: AppTypography.caption.copyWith(
                                    color: colors.textTertiary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        // 4. Trashed note deletion indicator
                        if (widget.note.isTrashed) ...[
                          const SizedBox(height: 4.0),
                          Text(
                            'Moved to Trash · ${DateFormatter.getGroupBucket(widget.note.deletedAt ?? widget.note.updatedAt)}',
                            style: AppTypography.caption.copyWith(
                              color: colors.textTertiary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Image Thumbnail (when note contains image)
                  if (metadata.thumbnailUri != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    NoteThumbnailView(
                      thumbnailUri: metadata.thumbnailUri!,
                      size: 48.0,
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

  Widget _buildHighlightedText({
    required String text,
    required String? query,
    required TextStyle baseStyle,
    required Color highlightColor,
    required Color highlightTextColor,
    required Color textColor,
    List<TokenSpanDto>? precomputedSpans,
    int maxLines = 1,
  }) {
    if (text.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final rawSpans = precomputedSpans ?? const <TokenSpanDto>[];
    if (rawSpans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Sort and merge overlapping spans
    final sortedSpans = [...rawSpans]..sort((a, b) => a.start.compareTo(b.start));

    final mergedSpans = <TokenSpanDto>[];
    for (final span in sortedSpans) {
      if (span.start < 0 || span.end > text.length || span.start >= span.end) {
        continue;
      }
      if (mergedSpans.isEmpty) {
        mergedSpans.add(span);
      } else {
        final last = mergedSpans.last;
        if (span.start <= last.end) {
          mergedSpans[mergedSpans.length - 1] = TokenSpanDto(
            start: last.start,
            end: span.end > last.end ? span.end : last.end,
            isExact: last.isExact && span.isExact,
          );
        } else {
          mergedSpans.add(span);
        }
      }
    }

    if (mergedSpans.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final span in mergedSpans) {
      if (span.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, span.start),
          style: baseStyle,
        ));
      }
      spans.add(TextSpan(
        text: text.substring(span.start, span.end),
        style: baseStyle.copyWith(
          color: highlightTextColor,
          backgroundColor: span.isExact
              ? highlightColor.withValues(alpha: 0.45)
              : highlightColor.withValues(alpha: 0.28),
          fontWeight: FontWeight.w700,
        ),
      ));
      lastEnd = span.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
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
                if (widget.note.isTrashed) ...[
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ExportNoteSheet.show(context, note: widget.note);
                    },
                  ),
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
                      widget.onRestore?.call();
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
                      final confirmed = await PermanentDeleteDialog.show(
                        context,
                        count: 1,
                      );
                      if (confirmed) {
                        widget.onDeletePermanently?.call();
                      }
                    },
                  ),
                ] else if (widget.note.isArchived) ...[
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ExportNoteSheet.show(context, note: widget.note);
                    },
                  ),
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
                      widget.onUnarchive?.call();
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
                      if (widget.onTrash != null) {
                        widget.onTrash!();
                      } else {
                        widget.onDelete?.call();
                      }
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: Icon(
                      Icons.ios_share_rounded,
                      color: colors.textSecondary,
                    ),
                    title: Text(
                      'Export note',
                      style: AppTypography.bodyMedium.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ExportNoteSheet.show(context, note: widget.note);
                    },
                  ),
                  if (widget.onTogglePin != null)
                    ListTile(
                      leading: Icon(
                        widget.note.isPinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                        color: colors.textSecondary,
                      ),
                      title: Text(
                        widget.note.isPinned ? 'Unpin note' : 'Pin note',
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        widget.onTogglePin!();
                      },
                    ),
                  if (widget.onArchive != null)
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
                        widget.onArchive!();
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
                      if (widget.onTrash != null) {
                        widget.onTrash!();
                      } else {
                        widget.onDelete?.call();
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
