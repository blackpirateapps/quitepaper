import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/image_processing/image_adjustments.dart';
import '../../../../core/image_processing/image_processor.dart';
import '../../../../core/ocr/ocr_models.dart';
import '../../domain/scanned_page.dart';

/// Modal adjustment sheet allowing non-destructive adjustment of
/// Crop, Rotate, Brightness, Contrast, Saturation, and Grayscale.
class PageAdjustmentSheet extends StatefulWidget {
  const PageAdjustmentSheet({
    super.key,
    required this.page,
    this.imageProcessor = const DartImageProcessor(),
  });

  final ScannedPage page;
  final ImageProcessor imageProcessor;

  static Future<ScannedPage?> show(
    BuildContext context, {
    required ScannedPage page,
    ImageProcessor? imageProcessor,
  }) {
    return showModalBottomSheet<ScannedPage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PageAdjustmentSheet(
        page: page,
        imageProcessor: imageProcessor ?? const DartImageProcessor(),
      ),
    );
  }

  @override
  State<PageAdjustmentSheet> createState() => _PageAdjustmentSheetState();
}

class _PageAdjustmentSheetState extends State<PageAdjustmentSheet> {
  late ImageAdjustments _adjustments;
  Uint8List? _previewBytes;
  bool _isRendering = false;
  int _activeTab = 0; // 0: Adjust Tone, 1: Crop & Rotate

  // Normalized crop sliders
  double _cropLeft = 0.0;
  double _cropTop = 0.0;
  double _cropRight = 1.0;
  double _cropBottom = 1.0;

  @override
  void initState() {
    super.initState();
    _adjustments = widget.page.adjustments;
    _previewBytes = widget.page.imageBytes;

    if (_adjustments.crop != null) {
      _cropLeft = _adjustments.crop!.x;
      _cropTop = _adjustments.crop!.y;
      _cropRight = _adjustments.crop!.right;
      _cropBottom = _adjustments.crop!.bottom;
    }

    _updatePreview();
  }

  Future<void> _updatePreview() async {
    if (_isRendering) return;
    setState(() => _isRendering = true);

    try {
      final processed = await widget.imageProcessor.process(
        widget.page.rawImageBytes,
        _adjustments,
        isPreview: true,
      );

      if (mounted) {
        setState(() {
          _previewBytes = processed;
          _isRendering = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRendering = false);
      }
    }
  }

  void _onAdjustmentsChanged(ImageAdjustments updated) {
    setState(() {
      _adjustments = updated;
    });
    _updatePreview();
  }

  void _onCropChanged() {
    final x = _cropLeft.clamp(0.0, 0.90);
    final y = _cropTop.clamp(0.0, 0.90);
    final right = _cropRight.clamp(x + 0.05, 1.0);
    final bottom = _cropBottom.clamp(y + 0.05, 1.0);

    final cropRect = (x == 0.0 && y == 0.0 && right == 1.0 && bottom == 1.0)
        ? null
        : NormalizedRect(
            x: x,
            y: y,
            width: right - x,
            height: bottom - y,
          );

    _onAdjustmentsChanged(_adjustments.copyWith(
      crop: cropRect,
      clearCrop: cropRect == null,
    ));
  }

  void _resetCrop() {
    setState(() {
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
    });
    _onAdjustmentsChanged(_adjustments.copyWith(clearCrop: true));
  }

  void _resetAll() {
    setState(() {
      _cropLeft = 0.0;
      _cropTop = 0.0;
      _cropRight = 1.0;
      _cropBottom = 1.0;
      _adjustments = ImageAdjustments.neutral;
    });
    _updatePreview();
  }

  Future<void> _commitAndClose() async {
    // Render full-resolution output on commit
    setState(() => _isRendering = true);

    final finalBytes = await widget.imageProcessor.process(
      widget.page.rawImageBytes,
      _adjustments,
      isPreview: false,
    );

    if (mounted) {
      final updatedPage = widget.page.copyWith(
        imageBytes: finalBytes,
        adjustments: _adjustments,
      );
      Navigator.of(context).pop(updatedPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Column(
        children: [
          // 1. Sheet Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _resetAll,
                  child: Text(
                    'Reset',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                Text(
                  'Page ${widget.page.pageNumber} Adjustments',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: _commitAndClose,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.accent,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 2. Interactive Live Preview Canvas
          Expanded(
            flex: 5,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(AppSpacing.md),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_previewBytes != null)
                    Image.memory(
                      _previewBytes!,
                      fit: BoxFit.contain,
                    ),
                  if (_isRendering)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: const CupertinoActivityIndicator(
                        color: Colors.white,
                        radius: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 3. Tab Selector (Tone vs Crop/Rotate)
          Container(
            color: colors.surface,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Tone & Exposure')),
                    selected: _activeTab == 0,
                    onSelected: (val) => setState(() => _activeTab = 0),
                    selectedColor: colors.accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _activeTab == 0 ? colors.accent : colors.textSecondary,
                      fontWeight: _activeTab == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Crop & Rotate')),
                    selected: _activeTab == 1,
                    onSelected: (val) => setState(() => _activeTab = 1),
                    selectedColor: colors.accent.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _activeTab == 1 ? colors.accent : colors.textSecondary,
                      fontWeight: _activeTab == 1 ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 4. Controls Body
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _activeTab == 0
                  ? _buildToneControls(colors)
                  : _buildCropAndRotateControls(colors),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToneControls(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Grayscale dedicated toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.filter_b_and_w_rounded,
                    size: 20, color: colors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Grayscale Document',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
            CupertinoSwitch(
              value: _adjustments.grayscale,
              activeTrackColor: colors.accent,
              onChanged: (val) =>
                  _onAdjustmentsChanged(_adjustments.copyWith(grayscale: val)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Brightness Slider (-1.0 to 1.0)
        _buildSliderRow(
          label: 'Brightness',
          value: _adjustments.brightness,
          icon: Icons.brightness_6_outlined,
          colors: colors,
          onChanged: (val) =>
              _onAdjustmentsChanged(_adjustments.copyWith(brightness: val)),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Contrast Slider (-1.0 to 1.0)
        _buildSliderRow(
          label: 'Contrast',
          value: _adjustments.contrast,
          icon: Icons.contrast_rounded,
          colors: colors,
          onChanged: (val) =>
              _onAdjustmentsChanged(_adjustments.copyWith(contrast: val)),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Saturation Slider (-1.0 to 1.0)
        _buildSliderRow(
          label: 'Saturation',
          value: _adjustments.saturation,
          icon: Icons.color_lens_outlined,
          colors: colors,
          onChanged: (val) =>
              _onAdjustmentsChanged(_adjustments.copyWith(saturation: val)),
        ),
      ],
    );
  }

  Widget _buildCropAndRotateControls(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Rotation Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            OutlinedButton.icon(
              onPressed: () => _onAdjustmentsChanged(_adjustments.rotateLeft()),
              icon: const Icon(Icons.rotate_left_rounded),
              label: const Text('↶ Rotate Left'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.divider),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _onAdjustmentsChanged(_adjustments.rotateRight()),
              icon: const Icon(Icons.rotate_right_rounded),
              label: const Text('↷ Rotate Right'),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.divider),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Crop Sliders
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Crop Margins',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (_adjustments.crop != null)
              TextButton(
                onPressed: _resetCrop,
                child: Text('Reset Crop',
                    style: TextStyle(color: colors.accent, fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        _buildCropSlider(
          label: 'Left Margin',
          value: _cropLeft,
          max: 0.45,
          colors: colors,
          onChanged: (v) {
            _cropLeft = v;
            _onCropChanged();
          },
        ),
        _buildCropSlider(
          label: 'Top Margin',
          value: _cropTop,
          max: 0.45,
          colors: colors,
          onChanged: (v) {
            _cropTop = v;
            _onCropChanged();
          },
        ),
        _buildCropSlider(
          label: 'Right Margin',
          value: 1.0 - _cropRight,
          max: 0.45,
          colors: colors,
          onChanged: (v) {
            _cropRight = 1.0 - v;
            _onCropChanged();
          },
        ),
        _buildCropSlider(
          label: 'Bottom Margin',
          value: 1.0 - _cropBottom,
          max: 0.45,
          colors: colors,
          onChanged: (v) {
            _cropBottom = 1.0 - v;
            _onCropChanged();
          },
        ),
      ],
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required IconData icon,
    required AppColors colors,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.accent,
            thumbColor: colors.accent,
            inactiveTrackColor: colors.divider,
            trackHeight: 3,
          ),
          child: Slider(
            value: value,
            min: -1.0,
            max: 1.0,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCropSlider({
    required String label,
    required double value,
    required double max,
    required AppColors colors,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.accent,
              thumbColor: colors.accent,
              inactiveTrackColor: colors.divider,
              trackHeight: 2,
            ),
            child: Slider(
              value: value.clamp(0.0, max),
              min: 0.0,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${(value * 100).toInt()}%',
            textAlign: TextAlign.end,
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ),
      ],
    );
  }
}
