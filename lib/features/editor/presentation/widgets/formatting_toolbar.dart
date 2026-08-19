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
    this.focusNode,
  });

  final TextEditingController controller;
  final VoidCallback onTagPressed;
  final FocusNode? focusNode;

  void _applyFormat(TextEditingValue Function({required TextEditingValue value}) action) {
    final updated = action(value: controller.value);
    controller.value = updated;
    if (focusNode != null && !focusNode!.hasFocus) {
      focusNode!.requestFocus();
    }
  }

  void _applyHelperFormat(TextEditingValue Function(TextEditingValue) action) {
    final updated = action(controller.value);
    controller.value = updated;
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
  });

  final String? label;
  final IconData? icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isBold;
  final bool isItalic;
  final bool isStrikethrough;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    TextStyle textStyle = TextStyle(
      fontSize: 16,
      color: colors.textSecondary,
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
          onTap: onPressed,
          child: Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 18, color: colors.textSecondary)
                : Text(label!, style: textStyle),
          ),
        ),
      ),
    );
  }
}
