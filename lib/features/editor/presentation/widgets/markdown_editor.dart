import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_formatter.dart';
import '../../application/markdown_text_input_formatter.dart';
import 'link_prompt_dialog.dart';

/// A dedicated, distraction-free Markdown editor widget.
/// Renders dynamic Markdown visual styling while preserving exact underlying Markdown source.
class MarkdownEditor extends StatelessWidget {
  const MarkdownEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.hintText = 'Start writing...',
    this.textCapitalization = TextCapitalization.sentences,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.readOnly = false,
  });

  final MarkdownEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final EdgeInsets scrollPadding;
  final bool readOnly;

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: controller.value);
    controller.value = updated;
    onChanged?.call(controller.text);
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  Future<void> _promptLink(BuildContext context) async {
    final selection = controller.selection;
    final text = controller.text;
    String initialTitle = '';
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
        value: controller.value,
        url: result.url,
        title: result.title,
      );
      controller.value = updated;
      onChanged?.call(controller.text);
      if (!focusNode.hasFocus) {
        focusNode.requestFocus();
      }
    }
  }

  void _handleTap() {
    final val = controller.value;
    final text = val.text;
    final sel = val.selection;
    if (!sel.isValid) return;

    final cursor = sel.start;
    if (cursor < 0 || cursor > text.length) return;

    // Find line surrounding tap
    var lineStart = 0;
    if (cursor > 0) {
      lineStart = text.lastIndexOf('\n', cursor - 1) + 1;
    }
    var lineEnd = text.indexOf('\n', cursor);
    if (lineEnd == -1) {
      lineEnd = text.length;
    }

    final line = text.substring(lineStart, lineEnd);
    final match = RegExp(r'^(\s*[-*+]\s*\[)([ xX])(\])').firstMatch(line);
    if (match != null) {
      final markerEnd = lineStart + match.end;
      // If tapped in the marker region (e.g. within "- [ ]")
      if (cursor <= markerEnd + 1) {
        final state = match.group(2);
        final newState = (state == 'x' || state == 'X') ? ' ' : 'x';
        final stateOffset = lineStart + (match.group(1)?.length ?? 3);
        final newText = text.replaceRange(stateOffset, stateOffset + 1, newState);
        controller.value = TextEditingValue(
          text: newText,
          selection: sel,
        );
        onChanged?.call(newText);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CallbackShortcuts(
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

        // Inline Code: Ctrl+` / Cmd+`
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
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        cursorColor: colors.accent,
        style: (controller.styles?.body ?? AppTypography.editorBody).copyWith(
          color: colors.textPrimary,
        ),
        inputFormatters: const [
          MarkdownTextInputFormatter(),
        ],
        onTap: _handleTap,
        contextMenuBuilder: (context, editableTextState) {
          final buttonItems = editableTextState.contextMenuButtonItems;
          final isSelectionActive =
              !editableTextState.textEditingValue.selection.isCollapsed;

          if (isSelectionActive) {
            // Prepend selection formatting buttons to the context menu
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
              ContextMenuButtonItem(
                label: 'Checklist',
                onPressed: () {
                  ContextMenuController.removeAny();
                  _applyFormat(MarkdownFormatter.toggleChecklist);
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
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.editorBody.copyWith(
            color: colors.textTertiary.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
        maxLines: null,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        scrollPadding: scrollPadding,
      ),
    );
  }
}
