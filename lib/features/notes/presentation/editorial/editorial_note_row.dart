import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/search/search_models.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../export/presentation/export_note_sheet.dart';
import '../../../sidebar/presentation/widgets/permanent_delete_dialog.dart';
import '../../domain/editorial_attachment_extractor.dart';
import '../../domain/note_metadata_extractor.dart';
import '../../domain/note_model.dart';
import 'editorial_attachment_group.dart';

/// Editorial note row component faithfully reproducing the visual language,
/// hierarchy, proportions, and selection treatment of the Bear notes reference.
class EditorialNoteRow extends StatefulWidget {
  const EditorialNoteRow({
    super.key,
    required this.note,
    required this.onTap,
    this.isSelected = false,
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
    this.isMultiSelecting = false,
    this.isItemMultiSelected = false,
    this.onItemMultiSelectToggle,
  });

  final Note note;
  final VoidCallback onTap;
  final bool isSelected;
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
  final bool isMultiSelecting;
  final bool isItemMultiSelected;
  final VoidCallback? onItemMultiSelectToggle;

  @override
  State<EditorialNoteRow> createState() => _EditorialNoteRowState();
}

class _EditorialNoteRowState extends State<EditorialNoteRow> {
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

    final attachments = EditorialAttachmentExtractor.extract(widget.note);

    final formattedTime = DateFormatter.formatNoteTileTime(
      widget.note.isTrashed
          ? (widget.note.deletedAt ?? widget.note.updatedAt)
          : widget.note.updatedAt,
    );

    final isHighlighted = widget.isSelected || widget.isItemMultiSelected;

    // Selected item has a distinct soft background container
    final containerColor = isHighlighted
        ? (isDark
            ? colors.surfaceSubtle
            : colors.selection.withValues(alpha: 0.55))
        : (_isHovered
            ? colors.surfaceSubtle.withValues(alpha: 0.4)
            : Colors.transparent);

    final semanticLabel = [
      metadata.displayTitle,
      if (widget.note.isPinned) 'pinned',
      if (widget.note.isPasswordProtected) 'password protected',
      'modified $formattedTime',
      if (metadata.previewSnippet.isNotEmpty) metadata.previewSnippet,
      if (widget.note.tags.isNotEmpty) 'tags: ${widget.note.tags.join(", ")}',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      selected: isHighlighted,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isHighlighted ? 8.0 : 0.0,
            vertical: isHighlighted ? 2.0 : 0.0,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: isHighlighted
                  ? BorderRadius.circular(10.0)
                  : BorderRadius.zero,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: isHighlighted
                    ? BorderRadius.circular(10.0)
                    : BorderRadius.zero,
                onTap: widget.isMultiSelecting
                    ? widget.onItemMultiSelectToggle
                    : widget.onTap,
                onLongPress: widget.isMultiSelecting
                    ? widget.onItemMultiSelectToggle
                    : () => _showContextMenu(context),
                child: Container(
                  decoration: BoxDecoration(
                    border: isHighlighted
                        ? null
                        : Border(
                            bottom: BorderSide(
                              color: colors.divider.withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left vertical accent indicator on selection
                        if (isHighlighted)
                          Container(
                            width: 3.5,
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: const BorderRadius.horizontal(
                                right: Radius.circular(2.5),
                              ),
                            ),
                          ),

                        // Multi-select Checkbox indicator
                        if (widget.isMultiSelecting)
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppSpacing.md,
                              right: AppSpacing.xs,
                              top: 14.0,
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

                        // Main Editorial Content Area
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: isHighlighted ? 12.0 : 16.0,
                              right: isHighlighted ? 12.0 : 16.0,
                              top: 11.0,
                              bottom: 11.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Title Row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.note.isPasswordProtected)
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
                                    Expanded(
                                      child: _buildHighlightedText(
                                        text: metadata.displayTitle,
                                        query: widget.searchQuery,
                                        precomputedSpans:
                                            widget.titleHighlightSpans,
                                        baseStyle: AppTypography.bodyMedium
                                            .copyWith(
                                          color: colors.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15.5,
                                          height: 1.25,
                                        ),
                                        highlightColor: colors.searchHighlight,
                                        highlightTextColor:
                                            colors.searchHighlightText,
                                        textColor: colors.textPrimary,
                                        maxLines: 2,
                                      ),
                                    ),
                                  ],
                                ),

                                // 2. Preview Text Snippet (clean Markdown stripped)
                                if (metadata.previewSnippet.isNotEmpty) ...[
                                  const SizedBox(height: 4.0),
                                  _buildHighlightedText(
                                    text: metadata.previewSnippet,
                                    query: widget.searchQuery,
                                    precomputedSpans:
                                        widget.snippetHighlightSpans,
                                    baseStyle:
                                        AppTypography.bodySmall.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 13.5,
                                      height: 1.35,
                                    ),
                                    highlightColor: colors.searchHighlight,
                                    highlightTextColor:
                                        colors.searchHighlightText,
                                    textColor: colors.textPrimary,
                                    maxLines: 2,
                                  ),
                                ] else if (metadata.hasCustomTitle &&
                                    attachments.isEmpty) ...[
                                  const SizedBox(height: 3.0),
                                  Text(
                                    'No content',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: colors.textTertiary
                                          .withValues(alpha: 0.6),
                                      fontSize: 13.0,
                                    ),
                                  ),
                                ],

                                // 3. Inline Attachment Preview
                                if (attachments.isNotEmpty)
                                  EditorialAttachmentGroup(items: attachments),

                                // 4. Tags row (subtle metadata)
                                if (widget.note.tags.isNotEmpty) ...[
                                  const SizedBox(height: 6.0),
                                  Wrap(
                                    spacing: 6.0,
                                    runSpacing: 4.0,
                                    children: widget.note.tags.map((tag) {
                                      return GestureDetector(
                                        onTap: widget.onTagTap != null
                                            ? () => widget.onTagTap!(tag)
                                            : null,
                                        child: Text(
                                          '#$tag',
                                          style: AppTypography.caption.copyWith(
                                            color: colors.textTertiary,
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],

                                // 5. Footer Line: Pin Icon + Date
                                const SizedBox(height: 6.0),
                                Row(
                                  children: [
                                    if (widget.note.isPinned &&
                                        !widget.note.isTrashed &&
                                        !widget.note.isArchived) ...[
                                      Icon(
                                        Icons.push_pin_rounded,
                                        size: 13,
                                        color: colors.accent,
                                      ),
                                      const SizedBox(width: 4.0),
                                    ],
                                    Text(
                                      formattedTime,
                                      style: AppTypography.caption.copyWith(
                                        color: colors.textTertiary,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
    required List<TokenSpanDto>? precomputedSpans,
    required TextStyle baseStyle,
    required Color highlightColor,
    required Color highlightTextColor,
    required Color textColor,
    required int maxLines,
  }) {
    if (precomputedSpans != null && precomputedSpans.isNotEmpty) {
      final spans = <TextSpan>[];
      var cursor = 0;
      for (final s in precomputedSpans) {
        if (s.start > cursor && s.start <= text.length) {
          spans.add(TextSpan(
            text: text.substring(cursor, s.start),
            style: baseStyle.copyWith(color: textColor),
          ));
        }
        final end = s.end <= text.length ? s.end : text.length;
        if (s.start < text.length && end > s.start) {
          spans.add(TextSpan(
            text: text.substring(s.start, end),
            style: baseStyle.copyWith(
              backgroundColor: highlightColor,
              color: highlightTextColor,
              fontWeight: FontWeight.bold,
            ),
          ));
        }
        cursor = end;
      }
      if (cursor < text.length) {
        spans.add(TextSpan(
          text: text.substring(cursor),
          style: baseStyle.copyWith(color: textColor),
        ));
      }
      return Text.rich(
        TextSpan(children: spans),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (query == null || query.trim().isEmpty) {
      return Text(
        text,
        style: baseStyle.copyWith(color: textColor),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerQuery = query.toLowerCase();
    final lowerText = text.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (start < text.length) {
      final idx = lowerText.indexOf(lowerQuery, start);
      if (idx == -1) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: baseStyle.copyWith(color: textColor),
        ));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(
          text: text.substring(start, idx),
          style: baseStyle.copyWith(color: textColor),
        ));
      }
      final end = idx + lowerQuery.length;
      spans.add(TextSpan(
        text: text.substring(idx, end),
        style: baseStyle.copyWith(
          backgroundColor: highlightColor,
          color: highlightTextColor,
          fontWeight: FontWeight.bold,
        ),
      ));
      start = end;
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showContextMenu(BuildContext context) {
    final colors = context.appColors;
    final note = widget.note;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppRadii.rLg),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (widget.onItemMultiSelectToggle != null)
              ListTile(
                leading: Icon(Icons.checklist_rounded, color: colors.textSecondary),
                title: Text('Select note', style: AppTypography.bodySmall),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onItemMultiSelectToggle!();
                },
              ),
            if (widget.onTogglePin != null && !note.isTrashed && !note.isArchived)
              ListTile(
                leading: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: colors.textSecondary,
                ),
                title: Text(
                  note.isPinned ? 'Unpin note' : 'Pin note',
                  style: AppTypography.bodySmall,
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onTogglePin!();
                },
              ),
            if (!note.isTrashed)
              ListTile(
                leading: Icon(
                  note.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: colors.textSecondary,
                ),
                title: Text(
                  note.isArchived ? 'Unarchive note' : 'Archive note',
                  style: AppTypography.bodySmall,
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  if (note.isArchived) {
                    widget.onUnarchive?.call();
                  } else {
                    widget.onArchive?.call();
                  }
                },
              ),
            if (!note.isTrashed)
              ListTile(
                leading: Icon(Icons.file_upload_outlined, color: colors.textSecondary),
                title: Text('Export note', style: AppTypography.bodySmall),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  ExportNoteSheet.show(context, note: note);
                },
              ),
            if (note.isTrashed) ...[
              ListTile(
                leading: Icon(Icons.restore_rounded, color: colors.success),
                title: Text(
                  'Restore note',
                  style: AppTypography.bodySmall.copyWith(color: colors.success),
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onRestore?.call();
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: colors.error),
                title: Text(
                  'Delete permanently',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                onTap: () async {
                  Navigator.of(bottomSheetContext).pop();
                  final confirmed = await PermanentDeleteDialog.show(context);
                  if (confirmed) {
                    widget.onDeletePermanently?.call();
                  }
                },
              ),
            ] else
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: colors.error),
                title: Text(
                  'Move to Trash',
                  style: AppTypography.bodySmall.copyWith(color: colors.error),
                ),
                onTap: () {
                  Navigator.of(bottomSheetContext).pop();
                  widget.onTrash?.call();
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
