import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../annotations/annotation_editing_controller.dart';

/// Floating, theme-native markup palette for the document viewer (spec §4.5).
///
/// Lets the reader pick the active tool, color and stroke width, toggle the
/// ruler/straight-line assist, undo/redo, and switch back to Navigate. Lives
/// above the page, clear of the tablet thumbnail rail.
class AnnotationToolbar extends StatelessWidget {
  const AnnotationToolbar({
    super.key,
    required this.controller,
    required this.ocrAvailable,
    required this.ocrPending,
  });

  final AnnotationEditingController controller;

  /// Whether OCR geometry is ready (gates text-anchored tools).
  final bool ocrAvailable;

  /// Whether OCR is still processing (shows a quiet "preparing text…" hint).
  final bool ocrPending;

  static const List<int> _palette = [
    0xFFEF5350, // red
    0xFFFFCA28, // amber (highlighter)
    0xFF66BB6A, // green
    0xFF42A5F5, // blue
    0xFF000000, // black
    0xFFFFFFFF, // white
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
            margin: const EdgeInsets.all(AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: colors.divider, width: 0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
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
                      _toolBtn(colors, AnnotationTool.navigate,
                          Icons.pan_tool_alt_outlined, 'Navigate'),
                      _sep(colors),
                      _toolBtn(colors, AnnotationTool.ink, Icons.edit, 'Pen'),
                      _toolBtn(colors, AnnotationTool.highlighter,
                          Icons.brush_outlined, 'Highlighter'),
                      _toolBtn(colors, AnnotationTool.rect,
                          Icons.crop_square, 'Rectangle'),
                      _toolBtn(colors, AnnotationTool.ellipse,
                          Icons.circle_outlined, 'Ellipse'),
                      _toolBtn(colors, AnnotationTool.line,
                          Icons.horizontal_rule, 'Line'),
                      _toolBtn(colors, AnnotationTool.arrow,
                          Icons.north_east, 'Arrow'),
                      _toolBtn(colors, AnnotationTool.eraser,
                          Icons.auto_fix_normal, 'Eraser'),
                      _sep(colors),
                      _toolBtn(colors, AnnotationTool.textHighlight,
                          Icons.highlight, 'Highlight text',
                          enabled: ocrAvailable),
                      _toolBtn(colors, AnnotationTool.underline,
                          Icons.format_underlined, 'Underline',
                          enabled: ocrAvailable),
                      _toolBtn(colors, AnnotationTool.strikethrough,
                          Icons.format_strikethrough, 'Strikethrough',
                          enabled: ocrAvailable),
                      _toolBtn(colors, AnnotationTool.squiggly,
                          Icons.gesture, 'Squiggly',
                          enabled: ocrAvailable),
                      _toolBtn(colors, AnnotationTool.select,
                          Icons.content_copy, 'Select & copy',
                          enabled: ocrAvailable),
                      _toolBtn(colors, AnnotationTool.comment,
                          Icons.chat_bubble_outline, 'Comment'),
                      _sep(colors),
                      _toolBtn(colors, AnnotationTool.redaction,
                          Icons.square, 'Redact'),
                      _sep(colors),
                      _iconBtn(colors, Icons.undo, 'Undo',
                          controller.canUndo ? controller.undo : null),
                      _iconBtn(colors, Icons.redo, 'Redo',
                          controller.canRedo ? controller.redo : null),
                    ],
                  ),
                ),
                if (ocrPending && !ocrAvailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Preparing text… text tools will enable shortly',
                      style: TextStyle(
                          fontSize: 11, color: colors.textTertiary),
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
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in _palette)
            GestureDetector(
              onTap: () => controller.setColor(c),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: controller.colorArgb == c
                        ? colors.accent
                        : colors.divider,
                    width: controller.colorArgb == c ? 2.5 : 1,
                  ),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.sm),
          if (tool.isFreeformDraw) ...[
            Icon(Icons.line_weight, size: 16, color: colors.textSecondary),
            SizedBox(
              width: 120,
              child: Slider(
                min: 0.001,
                max: 0.02,
                value: controller.strokeWidth.clamp(0.001, 0.02),
                onChanged: controller.setStrokeWidth,
              ),
            ),
          ],
          if (tool == AnnotationTool.line ||
              tool == AnnotationTool.arrow ||
              tool == AnnotationTool.rect ||
              tool == AnnotationTool.ellipse)
            _iconBtn(
              colors,
              Icons.straighten,
              'Snap to straight / 45°',
              () => controller.setSnapStraight(!controller.snapStraight),
              active: controller.snapStraight,
            ),
          if (tool == AnnotationTool.rect || tool == AnnotationTool.ellipse)
            _iconBtn(
              colors,
              controller.filled ? Icons.format_color_fill : Icons.border_style,
              'Toggle fill',
              () => controller.setFilled(!controller.filled),
              active: controller.filled,
            ),
        ],
      ),
    );
  }

  Widget _toolBtn(AppColors colors, AnnotationTool tool, IconData icon,
      String tooltip,
      {bool enabled = true}) {
    final active = controller.tool == tool;
    return Tooltip(
      message: enabled ? tooltip : '$tooltip (preparing text…)',
      child: IconButton(
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        color: active ? colors.accent : colors.textSecondary,
        disabledColor: colors.textTertiary.withValues(alpha: 0.4),
        style: active
            ? IconButton.styleFrom(backgroundColor: colors.accent.withValues(alpha: 0.14))
            : null,
        onPressed: enabled ? () => controller.setTool(tool) : null,
      ),
    );
  }

  Widget _iconBtn(AppColors colors, IconData icon, String tooltip,
      VoidCallback? onPressed,
      {bool active = false}) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        color: active ? colors.accent : colors.textSecondary,
        onPressed: onPressed,
      ),
    );
  }

  Widget _sep(AppColors colors) => Container(
        width: 1,
        height: 22,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        color: colors.divider,
      );
}
