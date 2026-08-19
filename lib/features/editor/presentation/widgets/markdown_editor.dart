import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../application/markdown_editing_controller.dart';
import '../../application/markdown_text_input_formatter.dart';

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
  });

  final MarkdownEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final TextCapitalization textCapitalization;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final EdgeInsets scrollPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      cursorColor: colors.accent,
      style: AppTypography.editorBody.copyWith(
        color: colors.textPrimary,
      ),
      inputFormatters: const [
        MarkdownTextInputFormatter(),
      ],
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
    );
  }
}
