import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../annotations/annotation_editing_controller.dart';

/// Minimal, theme-native markup palette for the document viewer (spec §4.5).
///
/// Shown only while the reader is in annotate mode (toggled from the app bar).
/// A leading close button exits back to reading. Tools, color and width live on
/// one quiet scrolling row; the style row appears only for a style-bearing tool.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.controller,
    required this.ocrAvailable,
    required this.ocrPending,
    required this.onClose,
  });

  final AnnotationEditingController controller;

  /// Whether OCR geometry is ready (gates text-anchored tools).
  final bool ocrAvailable;

  /// Whether OCR is still processing (shows a quiet "preparing text…" hint).
  final bool ocrPending;

  /// Exit annotate mode (back to reading / navigate).
  final VoidCallback onClose;

  static const List<int> _palette = [
    0xFFEF5350, // red
    0xFFFFCA28, // amber
    0xFF66BB6A, // green
    0xFF42A5F5, // blue
    0xFF000000, // black
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final tool = controller.tool;
        final showStyle = tool.isFreeformDraw ||
            tool.isTextAnchored ||
            tool == AnnotationTool.comment;
        return Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs, vertical: 2),
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _btn(colors, Icons.close_rounded, 'Done', onClose),
                      _gap(),
                      _tool(colors, AnnotationTool.ink, Icons.edit_outlined, 'Pen'),
                      _tool(colors, AnnotationTool.highlighter,
                          Icons.brush_outlined, 'Highlighter'),
                      _tool(colors, AnnotationTool.rect,
                          Icons.rectangle_outlined, 'Rectangle'),
                      _tool(colors, AnnotationTool.ellipse,
                          Icons.circle_outlined, 'Ellipse'),
                      _tool(colors, AnnotationTool.line,
                          Icons.horizontal_rule_rounded, 'Line'),
                      _tool(colors, AnnotationTool.arrow,
                          Icons.north_east_rounded, 'Arrow'),
                      _tool(colors, AnnotationTool.textHighlight,
                          Icons.highlight_rounded, 'Highlight text',
                          enabled: ocrAvailable),
                      _tool(colors, AnnotationTool.underline,
                          Icons.format_underlined_rounded, 'Underline',
                          enabled: ocrAvailable),
                      _tool(colors, AnnotationTool.strikethrough,
                          Icons.strikethrough_s_rounded, 'Strikethrough',
                          enabled: ocrAvailable),
                      _tool(colors, AnnotationTool.squiggly,
                          Icons.gesture_rounded, 'Squiggly',
                          enabled: ocrAvailable),
                      _tool(colors, AnnotationTool.select,
                          Icons.text_fields_rounded, 'Select & copy',
                          enabled: ocrAvailable),
                      _tool(colors, AnnotationTool.comment,
                          Icons.sticky_note_2_outlined, 'Comment'),
                      _tool(colors, AnnotationTool.redaction,
                          Icons.square_rounded, 'Redact'),
                      _tool(colors, AnnotationTool.eraser,
                          Icons.auto_fix_normal_rounded, 'Eraser'),
                      _gap(),
                      _btn(colors, Icons.undo_rounded, 'Undo',
                          controller.canUndo ? controller.undo : null),
                      _btn(colors, Icons.redo_rounded, 'Redo',
                          controller.canRedo ? controller.redo : null),
                    ],
                  ),
                ),
                if (ocrPending && !ocrAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, top: 2),
                    child: Text(
                      'Preparing text…',
                      style:
                          TextStyle(fontSize: 11, color: colors.textTertiary),
                    ),
                  ),
                if (showStyle) _styleRow(colors, tool),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _styleRow(AppColors colors, AnnotationTool tool) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => controller.setColor(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: controller.colorArgb == c
                        ? colors.accent
                        : colors.divider.withValues(alpha: 0.6),
                    width: controller.colorArgb == c ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          if (tool.isFreeformDraw)
            SizedBox(
              width: 110,
              child: Slider(
                min: 0.001,
                max: 0.02,
                value: controller.strokeWidth.clamp(0.001, 0.02),
                onChanged: controller.setStrokeWidth,
              ),
            ),
          if (tool == AnnotationTool.rect || tool == AnnotationTool.ellipse)
            _btn(
              colors,
              controller.filled
                  ? Icons.format_color_fill_rounded
                  : Icons.check_box_outline_blank_rounded,
              'Toggle fill',
              () => controller.setFilled(!controller.filled),
              active: controller.filled,
            ),
          if (tool == AnnotationTool.line ||
              tool == AnnotationTool.arrow ||
              tool == AnnotationTool.rect ||
              tool == AnnotationTool.ellipse)
            _btn(
              colors,
              Icons.straighten_rounded,
              'Snap to 45°',
              () => controller.setSnapStraight(!controller.snapStraight),
              active: controller.snapStraight,
            ),
        ],
      ),
    );
  }

  Widget _tool(AppColors colors, AnnotationTool tool, IconData icon,
      String tooltip,
      {bool enabled = true}) {
    final active = controller.tool == tool;
    return Tooltip(
      message: enabled ? tooltip : '$tooltip (preparing text…)',
      child: IconButton(
        icon: Icon(icon, size: 21),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        color: active ? colors.accent : colors.textSecondary,
        disabledColor: colors.textTertiary.withValues(alpha: 0.35),
        style: active
            ? IconButton.styleFrom(
                backgroundColor: colors.accent.withValues(alpha: 0.12))
            : null,
        onPressed: enabled ? () => controller.setTool(tool) : null,
      ),
    );
  }

  Widget _btn(AppColors colors, IconData icon, String tooltip,
      VoidCallback? onPressed,
      {bool active = false}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 21),
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        color: active ? colors.accent : colors.textSecondary,
        onPressed: onPressed,
      ),
    );
  }

  Widget _gap() => const SizedBox(width: 6);
}
