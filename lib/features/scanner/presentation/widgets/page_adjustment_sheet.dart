import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/image_processing/image_adjustments.dart';
import '../../../../core/image_processing/image_processor.dart';
import '../../domain/scanned_page.dart';
import 'scanner_preview_canvas.dart';

/// Lightweight modal sheet for interactive non-destructive document adjustments.
///
/// Features:
/// - Real-time GPU color filtering for instant 60fps slider feedback.
/// - Presets: Original, Auto, B&W.
/// - Fine Tune: Brightness, Contrast, Saturation, Grayscale.
/// - Direct manipulation interactive Crop & 90-degree Rotation.
/// - Press-and-hold before/after comparison.
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
  int _activeTab = 0; // 0: Tone & Style, 1: Crop & Rotate
  bool _isFineTuneExpanded = true;

  @override
  void initState() {
    super.initState();
    _adjustments = widget.page.adjustments;
  }

  void _onAdjustmentsChanged(ImageAdjustments updated) {
    setState(() {
      _adjustments = updated;
    });
  }

  void _applyPreset(ImageAdjustments preset) {
    setState(() {
      _adjustments = _adjustments.copyWith(
        brightness: preset.brightness,
        contrast: preset.contrast,
        saturation: preset.saturation,
        grayscale: preset.grayscale,
      );
    });
  }

  void _resetCrop() {
    setState(() {
      _adjustments = _adjustments.copyWith(clearCrop: true);
    });
  }

  void _resetAll() {
    setState(() {
      _adjustments = ImageAdjustments.neutral;
    });
  }

  void _commitAndClose() {
    final updatedPage = widget.page.copyWith(
      adjustments: _adjustments,
    );
    Navigator.of(context).pop(updatedPage);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
              child: ScannerPreviewCanvas(
                previewBytes: widget.page.previewBytes,
                adjustments: _adjustments,
                isCropMode: _activeTab == 1,
                onAdjustmentsChanged: _onAdjustmentsChanged,
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
    final isOriginal = _adjustments.isNeutral;
    final isAuto = _adjustments.contrast == 0.20 &&
        _adjustments.brightness == 0.05 &&
        !_adjustments.grayscale;
    final isBw = _adjustments.grayscale &&
        _adjustments.contrast == 0.25 &&
        _adjustments.brightness == 0.10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Presets Row (Original, Auto, B&W)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildPresetPill(
              label: 'Original',
              isSelected: isOriginal,
              icon: Icons.image_outlined,
              colors: colors,
              onTap: () => _applyPreset(ImageAdjustments.neutral),
            ),
            _buildPresetPill(
              label: 'Auto',
              isSelected: isAuto,
              icon: Icons.auto_awesome,
              colors: colors,
              onTap: () => _applyPreset(ImageAdjustments.auto),
            ),
            _buildPresetPill(
              label: 'B&W',
              isSelected: isBw,
              icon: Icons.filter_b_and_w_rounded,
              colors: colors,
              onTap: () => _applyPreset(ImageAdjustments.blackAndWhite),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Grayscale Toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.filter_b_and_w_rounded, size: 20, color: colors.textSecondary),
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

        const SizedBox(height: AppSpacing.sm),

        // Fine Tune Accordion Header
        InkWell(
          onTap: () => setState(() => _isFineTuneExpanded = !_isFineTuneExpanded),
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FINE TUNE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: colors.textSecondary,
                  ),
                ),
                Icon(
                  _isFineTuneExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        if (_isFineTuneExpanded) ...[
          const SizedBox(height: AppSpacing.xs),

          // Brightness Slider (-1.0 to 1.0)
          _buildSliderRow(
            label: 'Brightness',
            value: _adjustments.brightness,
            icon: Icons.brightness_6_outlined,
            colors: colors,
            onChanged: (val) =>
                _onAdjustmentsChanged(_adjustments.copyWith(brightness: val)),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Contrast Slider (-1.0 to 1.0)
          _buildSliderRow(
            label: 'Contrast',
            value: _adjustments.contrast,
            icon: Icons.contrast_rounded,
            colors: colors,
            onChanged: (val) =>
                _onAdjustmentsChanged(_adjustments.copyWith(contrast: val)),
          ),
          const SizedBox(height: AppSpacing.xs),

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
      ],
    );
  }

  Widget _buildPresetPill({
    required String label,
    required bool isSelected,
    required IconData icon,
    required AppColors colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.withValues(alpha: 0.18)
              : colors.textTertiary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? colors.accent : colors.divider,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? colors.accent : colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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

        // Crop Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Crop Document',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (_adjustments.crop != null)
              TextButton(
                onPressed: _resetCrop,
                child: Text(
                  'Reset Crop',
                  style: TextStyle(color: colors.accent, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Drag the corner handles or edge bars directly on the document image above to frame the page.',
          style: TextStyle(
            fontSize: 12.5,
            color: colors.textSecondary,
            height: 1.4,
          ),
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
}
