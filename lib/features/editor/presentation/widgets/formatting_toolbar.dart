import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/markdown/markdown_helper.dart';

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.controller,
    required this.onTagPressed,
  });

  final TextEditingController controller;
  final VoidCallback onTagPressed;

  void _applyFormat(TextEditingValue Function(TextEditingValue) action) {
    final updated = action(controller.value);
    controller.value = updated;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: 48,
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
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.wrapSelection(
                value: v,
                prefix: '**',
                suffix: '**',
                defaultText: 'bold',
              ),
            ),
          ),
          _ToolbarButton(
            label: 'I',
            tooltip: 'Italic (*text*)',
            isItalic: true,
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.wrapSelection(
                value: v,
                prefix: '*',
                suffix: '*',
                defaultText: 'italic',
              ),
            ),
          ),
          _ToolbarButton(
            label: 'S',
            tooltip: 'Strikethrough (~~text~~)',
            isStrikethrough: true,
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.wrapSelection(
                value: v,
                prefix: '~~',
                suffix: '~~',
                defaultText: 'strike',
              ),
            ),
          ),
          _ToolbarButton(
            label: 'H',
            tooltip: 'Heading (# / ## / ###)',
            isBold: true,
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.toggleLinePrefix(
                value: v,
                prefix: '# ',
              ),
            ),
          ),
          _ToolbarButton(
            label: '•',
            tooltip: 'Bullet list (- item)',
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.toggleLinePrefix(
                value: v,
                prefix: '- ',
              ),
            ),
          ),
          _ToolbarButton(
            label: '1.',
            tooltip: 'Numbered list (1. item)',
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.toggleLinePrefix(
                value: v,
                prefix: '1. ',
              ),
            ),
          ),
          _ToolbarButton(
            label: '"',
            tooltip: 'Quote (> quote)',
            onPressed: () => _applyFormat(
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
            onPressed: () => _applyFormat(
              (v) => MarkdownHelper.wrapSelection(
                value: v,
                prefix: '`',
                suffix: '`',
                defaultText: 'code',
              ),
            ),
          ),
          _ToolbarButton(
            icon: Icons.code_rounded,
            tooltip: 'Code block (```)',
            onPressed: () => _applyFormat(MarkdownHelper.insertCodeBlock),
          ),
          _ToolbarButton(
            icon: Icons.link_rounded,
            tooltip: 'Link ([title](url))',
            onPressed: () => _applyFormat(MarkdownHelper.insertLink),
          ),
          _ToolbarButton(
            label: '#',
            tooltip: 'Add tag (#tag)',
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
