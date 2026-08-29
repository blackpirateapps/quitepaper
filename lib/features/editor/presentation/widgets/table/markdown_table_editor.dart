import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radii.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../application/markdown_formatter.dart';
import '../../../application/markdown_parser.dart';
import '../../../application/markdown_table_controller.dart';
import '../../../application/markdown_text_input_formatter.dart';
import '../../../domain/markdown_styles.dart';
import '../../../domain/markdown_table.dart';
import '../../../domain/markdown_table_cell.dart';
import '../../../domain/markdown_table_position.dart';
import '../link_prompt_dialog.dart';
import 'markdown_table_toolbar.dart';

/// The interactive hybrid table editing surface.
/// Renders a spreadsheet-like grid with cell cursor, Tab/Shift+Tab navigation,
/// cell formatting, and pure source-preserving Markdown transformations.
class MarkdownTableEditor extends StatefulWidget {
  const MarkdownTableEditor({
    super.key,
    required this.controller,
    this.styles,
    this.onClose,
    this.searchQuery,
  });

  final MarkdownTableController controller;
  final MarkdownStyles? styles;
  final VoidCallback? onClose;
  final String? searchQuery;

  @override
  State<MarkdownTableEditor> createState() => _MarkdownTableEditorState();
}

class _MarkdownTableEditorState extends State<MarkdownTableEditor> {
  final ScrollController _horizontalScrollController = ScrollController();
  static const double _columnWidth = 140.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(MarkdownTableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final cellCtrl = widget.controller.cellController;
    final updated = action(value: cellCtrl.value);
    cellCtrl.value = updated;
    if (!widget.controller.cellFocusNode.hasFocus) {
      widget.controller.cellFocusNode.requestFocus();
    }
  }

  Future<void> _promptLink(BuildContext context) async {
    final cellCtrl = widget.controller.cellController;
    final selection = cellCtrl.selection;
    final text = cellCtrl.text;
    var initialTitle = '';
    if (selection.isValid && !selection.isCollapsed) {
      final selStart = selection.start;
      final selEnd = selection.end;
      initialTitle = text.substring(selStart, selEnd);
    }

    final result = await LinkPromptDialog.show(
      context,
      initialTitle: initialTitle,
    );

    if (result != null) {
      final updated = MarkdownFormatter.createLink(
        value: cellCtrl.value,
        url: result.url,
        title: result.title,
      );
      cellCtrl.value = updated;
      if (!widget.controller.cellFocusNode.hasFocus) {
        widget.controller.cellFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final table = widget.controller.table;
    final effectiveStyles = widget.styles ?? MarkdownStyles.fromColors(colors);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        // Tab -> Next Cell (or create row at last cell)
        if (event.logicalKey == LogicalKeyboardKey.tab) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          if (isShiftPressed) {
            widget.controller.moveToPreviousCell();
          } else {
            widget.controller.moveToNextCell(createRowIfLast: true);
          }
          return KeyEventResult.handled;
        }

        // Enter -> Next row in same column
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
          if (!isShiftPressed) {
            widget.controller.moveToCellBelow(createRowIfLast: true);
            return KeyEventResult.handled;
          }
        }

        // Escape -> Close table editor
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          widget.onClose?.call();
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: CallbackShortcuts(
        bindings: {
          // Bold: Ctrl+B / Cmd+B
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
              _applyFormat(MarkdownFormatter.toggleBold),
          const SingleActivator(LogicalKeyboardKey.keyB, meta: true): () =>
              _applyFormat(MarkdownFormatter.toggleBold),

          // Italic: Ctrl+I / Cmd+I
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): () =>
              _applyFormat(MarkdownFormatter.toggleItalic),
          const SingleActivator(LogicalKeyboardKey.keyI, meta: true): () =>
              _applyFormat(MarkdownFormatter.toggleItalic),

          // Strikethrough: Ctrl+Shift+X / Cmd+Shift+X
          const SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true): () =>
              _applyFormat(MarkdownFormatter.toggleStrikethrough),
          const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true): () =>
              _applyFormat(MarkdownFormatter.toggleStrikethrough),

          // Code: Ctrl+` / Cmd+`
          const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
              _applyFormat(MarkdownFormatter.toggleInlineCode),
          const SingleActivator(LogicalKeyboardKey.backquote, meta: true): () =>
              _applyFormat(MarkdownFormatter.toggleInlineCode),

          // Link: Ctrl+K / Cmd+K
          const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
              _promptLink(context),
          const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
              _promptLink(context),
        },
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contextual Toolbar
              MarkdownTableToolbar(
                controller: widget.controller,
                onCloseTable: widget.onClose,
              ),

              // Spreadsheet Container
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(
                    color: colors.accent.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: IntrinsicWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Row
                        _buildRow(
                          context: context,
                          table: table,
                          row: table.headerRow,
                          rowIndex: 0,
                          isHeader: true,
                          colors: colors,
                          styles: effectiveStyles,
                        ),

                        // Body Rows
                        for (var r = 0; r < table.bodyRows.length; r++) ...[
                          Divider(
                            height: 1,
                            thickness: 0.8,
                            color: colors.divider.withValues(alpha: 0.5),
                          ),
                          _buildRow(
                            context: context,
                            table: table,
                            row: table.bodyRows[r],
                            rowIndex: r + 1,
                            isHeader: false,
                            colors: colors,
                            styles: effectiveStyles,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required MarkdownTable table,
    required dynamic row,
    required int rowIndex,
    required bool isHeader,
    required AppColors colors,
    required MarkdownStyles styles,
  }) {
    final cells = row.cells as List<MarkdownTableCell>;

    return Container(
      color: isHeader ? colors.tagBackground.withValues(alpha: 0.35) : Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var col = 0; col < table.columnCount; col++) ...[
            if (col > 0)
              Container(
                width: 1.0,
                color: colors.divider.withValues(alpha: 0.4),
              ),
            _buildCell(
              context: context,
              cell: col < cells.length ? cells[col] : null,
              rowIndex: rowIndex,
              columnIndex: col,
              isHeader: isHeader,
              colors: colors,
              styles: styles,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCell({
    required BuildContext context,
    required MarkdownTableCell? cell,
    required int rowIndex,
    required int columnIndex,
    required bool isHeader,
    required AppColors colors,
    required MarkdownStyles styles,
  }) {
    final isActive = widget.controller.activePosition.row == rowIndex &&
        widget.controller.activePosition.column == columnIndex;
    final alignment = widget.controller.table.getAlignment(columnIndex);
    final pos = TablePosition(row: rowIndex, column: columnIndex);

    if (isActive) {
      // Active Editable Field
      return Container(
        width: _columnWidth,
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.08),
          border: Border.all(
            color: colors.accent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        alignment: alignment.alignment,
        child: TextField(
          controller: widget.controller.cellController,
          focusNode: widget.controller.cellFocusNode,
          autofocus: true,
          cursorColor: colors.accent,
          style: (styles.body).copyWith(
            color: colors.textPrimary,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          ),
          textAlign: alignment.textAlign,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: isHeader ? 'Header ${columnIndex + 1}' : 'Cell',
            hintStyle: AppTypography.caption.copyWith(
              color: colors.textTertiary.withValues(alpha: 0.4),
            ),
          ),
          inputFormatters: const [
            MarkdownTextInputFormatter(),
          ],
          contextMenuBuilder: (context, editableTextState) {
            final buttonItems = editableTextState.contextMenuButtonItems;
            final isSelectionActive =
                !editableTextState.textEditingValue.selection.isCollapsed;

            if (isSelectionActive) {
              final formattingButtons = [
                ContextMenuButtonItem(
                  label: 'Bold',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applyFormat(MarkdownFormatter.toggleBold);
                  },
                ),
                ContextMenuButtonItem(
                  label: 'Italic',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applyFormat(MarkdownFormatter.toggleItalic);
                  },
                ),
                ContextMenuButtonItem(
                  label: 'Strike',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applyFormat(MarkdownFormatter.toggleStrikethrough);
                  },
                ),
                ContextMenuButtonItem(
                  label: 'Code',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _applyFormat(MarkdownFormatter.toggleInlineCode);
                  },
                ),
                ContextMenuButtonItem(
                  label: 'Link',
                  onPressed: () {
                    ContextMenuController.removeAny();
                    _promptLink(context);
                  },
                ),
              ];

              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: [
                  ...formattingButtons,
                  ...buttonItems,
                ],
              );
            }

            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: buttonItems,
            );
          },
          maxLines: null,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
        ),
      );
    }

    // Inactive Cell
    final cellText = cell?.trimmedText ?? '';
    final textSpan = cellText.isNotEmpty
        ? MarkdownParser.buildTextSpan(
            text: cellText,
            styles: styles,
            searchQuery: widget.searchQuery,
          )
        : TextSpan(
            text: isHeader ? 'Header ${columnIndex + 1}' : ' ',
            style: isHeader
                ? AppTypography.bodySmallMedium.copyWith(
                    color: colors.textTertiary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  )
                : AppTypography.bodySmall.copyWith(color: colors.textTertiary),
          );

    return InkWell(
      onTap: () => widget.controller.setActivePosition(pos),
      splashColor: colors.accent.withValues(alpha: 0.1),
      highlightColor: colors.accent.withValues(alpha: 0.05),
      child: Container(
        width: _columnWidth,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        alignment: alignment.alignment,
        child: RichText(
          text: textSpan,
          textAlign: alignment.textAlign,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
