import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../application/rich_document_controller.dart';
import '../../../domain/rich_block.dart';
import 'text_block_widget.dart';

/// Autonomous Flutter widget rendering an editorial callout block.
class CalloutBlockWidget extends StatelessWidget {
  const CalloutBlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  final CalloutBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  IconData _getIcon() {
    switch (block.kind) {
      case CalloutKind.tip:
        return PhosphorIconsRegular.lightbulb;
      case CalloutKind.info:
        return PhosphorIconsRegular.info;
      case CalloutKind.warning:
        return PhosphorIconsRegular.warning;
      case CalloutKind.note:
        return PhosphorIconsRegular.notepad;
    }
  }

  Color _getAccentColor(AppColors colors) {
    switch (block.kind) {
      case CalloutKind.warning:
        return colors.error;
      case CalloutKind.tip:
      case CalloutKind.info:
      case CalloutKind.note:
        return colors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final accent = _getAccentColor(colors);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: accent.withValues(alpha: 0.22),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 10.0),
            child: Icon(
              _getIcon(),
              size: 18,
              color: accent,
            ),
          ),
          Expanded(
            child: TextBlockWidget(
              block: block,
              blockIndex: blockIndex,
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              hintText: 'Callout note...',
              onActiveTargetChanged: onActiveTargetChanged,
              onChanged: onChanged,
              onNavigateUp: onNavigateUp,
              onNavigateDown: onNavigateDown,
            ),
          ),
        ],
      ),
    );
  }
}
