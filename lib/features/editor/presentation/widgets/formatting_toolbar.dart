import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../application/markdown_formatter.dart';
import 'link_prompt_dialog.dart';

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.onTagPressed,
    this.onImagePressed,
    this.onScanPressed,
    this.onPdfPressed,
    this.focusNode,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.onApplyAtomicEdit,
  });

  final TextEditingController controller;
  final VoidCallback onTagPressed;
  final VoidCallback? onImagePressed;
  final VoidCallback? onScanPressed;
  final VoidCallback? onPdfPressed;
  final FocusNode? focusNode;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final void Function(TextEditingValue value)? onApplyAtomicEdit;

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: controller.value);
    controller.value = updated;
    onApplyAtomicEdit?.call(updated);
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  void _applyHelperFormat(TextEditingValue Function(TextEditingValue) action) {
    final updated = action(controller.value);
    controller.value = updated;
    onApplyAtomicEdit?.call(updated);
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  Future<void> _handleLink(BuildContext context) async {
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
      onApplyAtomicEdit?.call(updated);
      if (focusNode != null && !focusNode!.hasFocus) {
        focusNode!.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.8),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _ToolbarButton(
            icon: Icons.undo_rounded,
            tooltip: 'Undo (Ctrl+Z)',
            isEnabled: canUndo,
            onPressed: onUndo ?? () {},
          ),
          _ToolbarButton(
            icon: Icons.redo_rounded,
            tooltip: 'Redo (Ctrl+Shift+Z)',
            isEnabled: canRedo,
            onPressed: onRedo ?? () {},
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            width: 1,
            color: colors.divider.withValues(alpha: 0.6),
          ),
          _ToolbarButton(
            label: 'B',
            tooltip: 'Bold (**text**)',
            isBold: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleBold),
          ),
          _ToolbarButton(
            label: 'I',
            tooltip: 'Italic (*text*)',
            isItalic: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleItalic),
          ),
          _ToolbarButton(
            label: 'S',
            tooltip: 'Strikethrough (~~text~~)',
            isStrikethrough: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleStrikethrough),
          ),
          _ToolbarButton(
            label: 'H',
            tooltip: 'Cycle heading (# / ## / ###)',
            isBold: true,
            onPressed: () => _applyHelperFormat(MarkdownHelper.cycleHeading),
          ),
          _ToolbarButton(
            label: '☐',
            tooltip: 'Checklist (- [ ] item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleChecklist),
          ),
          _ToolbarButton(
            label: '•',
            tooltip: 'Bullet list (- item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleBulletList),
          ),
          _ToolbarButton(
            label: '1.',
            tooltip: 'Numbered list (1. item)',
            onPressed: () => _applyFormat(MarkdownFormatter.toggleOrderedList),
          ),
          _ToolbarButton(
            label: '"',
            tooltip: 'Quote (> quote)',
            onPressed: () => _applyHelperFormat(
              (v) => MarkdownHelper.toggleLinePrefix(
                value: v,
                prefix: '> ',
              ),
            ),
          ),
          _ToolbarButton(
            label: '`',
            tooltip: 'Inline code (`code`)',
            isMonospace: true,
            onPressed: () => _applyFormat(MarkdownFormatter.toggleInlineCode),
          ),
          _ToolbarButton(
            icon: Icons.code_rounded,
            tooltip: 'Code block (```)',
            onPressed: () => _applyHelperFormat(MarkdownHelper.insertCodeBlock),
          ),
          _ToolbarButton(
            icon: Icons.link_rounded,
            tooltip: 'Link ([title](url))',
            onPressed: () => _handleLink(context),
          ),
          if (onImagePressed != null)
            _ToolbarButton(
              icon: Icons.image_outlined,
              tooltip: 'Insert image (![alt](qp://asset/...))',
              onPressed: onImagePressed!,
            ),
          if (onScanPressed != null)
            _ToolbarButton(
              icon: Icons.document_scanner_outlined,
              tooltip: 'Scan document ([title](qp://document/...))',
              onPressed: onScanPressed!,
            ),
          if (onPdfPressed != null)
            _ToolbarButton(
              icon: Icons.picture_as_pdf_outlined,
              tooltip: 'Attach PDF document ([title](qp://document/...))',
              onPressed: onPdfPressed!,
            ),
          _ToolbarButton(
            label: '#',
            tooltip: 'Add tag',
            isBold: true,
            onPressed: onTagPressed,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    this.label,
    this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isBold = false,
    this.isItalic = false,
    this.isStrikethrough = false,
    this.isMonospace = false,
    this.isEnabled = true,
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isBold;
  final bool isItalic;
  final bool isStrikethrough;
  final bool isMonospace;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final effectiveColor = isEnabled
        ? colors.textSecondary
        : colors.textTertiary.withValues(alpha: 0.35);

    TextStyle textStyle = TextStyle(
      fontSize: 16,
      color: effectiveColor,
      fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: isStrikethrough ? TextDecoration.lineThrough : TextDecoration.none,
      fontFamily: isMonospace ? 'monospace' : null,
    );

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          onTap: isEnabled ? onPressed : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 18, color: effectiveColor)
                : Text(label!, style: textStyle),
          ),
        ),
      ),
    );
  }
}
