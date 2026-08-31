import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/image_processing/image_adjustments.dart';
import 'interactive_crop_overlay.dart';

/// Interactive high-performance document canvas renderer.
///
/// Features:
/// - Real-time GPU color filtering via [ColorFilter.matrix].
/// - Animated 90-degree rotations.
/// - Interactive touch-draggable crop overlay with rule-of-thirds grid.
/// - Pinch-to-zoom and pan via [InteractiveViewer] with double-tap reset.
/// - Press-and-hold before/after comparison with subtle "ORIGINAL" badge.
class ScannerPreviewCanvas extends StatefulWidget {
  const ScannerPreviewCanvas({
    super.key,
    required this.previewBytes,
    required this.adjustments,
    this.isCropMode = false,
    this.onAdjustmentsChanged,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
  });

  /// Cached bounded ~600px preview image bytes.
  final Uint8List previewBytes;

  /// Current non-destructive adjustment parameters.
  final ImageAdjustments adjustments;

  /// Whether the interactive crop overlay handles are displayed.
  final bool isCropMode;

  /// Callback when adjustments are updated via crop or reset.
  final ValueChanged<ImageAdjustments>? onAdjustmentsChanged;

  /// Whether asynchronous preparation is occurring.
  final bool isLoading;

  /// Optional error message if preview decode fails.
  final String? errorMessage;

  /// Optional retry callback if preview error occurs.
  final VoidCallback? onRetry;

  @override
  State<ScannerPreviewCanvas> createState() => _ScannerPreviewCanvasState();
}

class _ScannerPreviewCanvasState extends State<ScannerPreviewCanvas> {
  final TransformationController _transformController = TransformationController();
  bool _isComparingOriginal = false;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (widget.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, size: 48, color: colors.accent),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Unable to preview this adjustment.',
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.onRetry != null)
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }

    final activeAdjustments = _isComparingOriginal
        ? ImageAdjustments.neutral
        : widget.adjustments;

    return GestureDetector(
      onLongPressStart: (_) {
        if (!widget.isCropMode) {
          setState(() => _isComparingOriginal = true);
        }
      },
      onLongPressEnd: (_) {
        if (_isComparingOriginal) {
          setState(() => _isComparingOriginal = false);
        }
      },
      onDoubleTap: widget.isCropMode ? null : _resetZoom,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Zoomable Image Container
          InteractiveViewer(
            transformationController: _transformController,
            panEnabled: !widget.isCropMode,
            scaleEnabled: !widget.isCropMode,
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: AnimatedRotation(
                turns: activeAdjustments.rotationQuarterTurns / 4.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(activeAdjustments.toColorMatrix()),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.memory(
                        widget.previewBytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                      // 2. Interactive Crop Overlay
                      if (widget.isCropMode && !_isComparingOriginal)
                        Positioned.fill(
                          child: InteractiveCropOverlay(
                            crop: widget.adjustments.crop,
                            accentColor: colors.accent,
                            onCropChanged: (newCrop) {
                              widget.onAdjustmentsChanged?.call(
                                widget.adjustments.copyWith(crop: newCrop),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Before/After "ORIGINAL" Hold Indicator Badge
          if (_isComparingOriginal)
            Positioned(
              top: AppSpacing.md,
              child: AnimatedOpacity(
                opacity: _isComparingOriginal ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 14, color: colors.accent),
                      const SizedBox(width: 6),
                      const Text(
                        'ORIGINAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Loading Indicator (Only shown during genuine async operations)
          if (widget.isLoading)
            Positioned(
              bottom: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
