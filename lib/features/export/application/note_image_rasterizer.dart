import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/syntax/application/syntax_highlighter.dart';
import '../../../core/syntax/application/syntax_language_resolver.dart';
import '../../../features/settings/domain/typography_settings.dart';
import '../domain/export_models.dart';
import '../presentation/widgets/note_screenshot_card.dart';

/// Helper utility for rasterizing a whole note into a continuous, high-resolution PNG image
/// using off-screen RepaintBoundary rendering.
class NoteImageRasterizer {
  const NoteImageRasterizer();

  /// Captures [snapshot] as a PNG image byte array using [context]'s overlay.
  static Future<Uint8List> rasterizeNote({
    required BuildContext context,
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    SyntaxHighlighter? highlighter,
    SyntaxLanguageResolver? resolver,
    TypographySettings typography = const TypographySettings(),
  }) async {
    final repaintKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: 0,
          top: 0,
          child: Opacity(
            opacity: 0.01, // Near-invisible offscreen capture overlay
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: request.imageOptions.logicalWidth,
                child: RepaintBoundary(
                  key: repaintKey,
                  child: NoteScreenshotCard(
                    snapshot: snapshot,
                    options: request.imageOptions,
                    highlighter: highlighter,
                    resolver: resolver,
                    typography: typography,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    try {
      // 1. Wait for frame layout and painting to complete
      await WidgetsBinding.instance.endOfFrame;
      // Brief pause to allow image assets and text layouts to settle
      await Future<void>.delayed(const Duration(milliseconds: 120));

      // 2. Locate boundary
      final boundary =
          repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError(
          'Failed to locate RenderRepaintBoundary for note screenshot.',
        );
      }

      // 3. Rasterize to image
      final pixelRatio = request.imageOptions.pixelRatio;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError(
          'Failed to encode rasterized note screenshot to PNG byte data.',
        );
      }

      return byteData.buffer.asUint8List();
    } finally {
      entry.remove();
    }
  }
}
