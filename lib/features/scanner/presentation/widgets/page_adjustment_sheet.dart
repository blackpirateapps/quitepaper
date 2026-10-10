import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/image_processing/document_quad.dart';
import '../../../../core/image_processing/image_adjustments.dart';
import '../../../../core/image_processing/image_processor.dart';
import '../../../../core/image_processing/scan_mode.dart';
import '../../domain/scanned_page.dart';
import 'scanner_preview_canvas.dart';

/// Lightweight modal sheet for interactive non-destructive document adjustments.
///
/// Features:
/// - Real-time GPU color filtering for instant 60fps slider feedback.
/// - Capture modes: Original, Auto, Document, Whiteboard, Grayscale, B&W Text
///   (each a baked [ScanMode] pipeline previewed as a thumbnail).
/// - Fine Tune: Brightness, Contrast, Saturation, Grayscale.
/// - Direct manipulation interactive Crop & 90-degree Rotation.
/// - Press-and-hold before/after comparison.
class PageAdjustmentSheet extends StatefulWidget {
  const PageAdjustmentSheet({
    super.key,
    required this.page,
    this.imageProcessor = const DartImageProcessor(),
    this.title,
    this.enableDocumentQuad = false,
  });

  final ScannedPage page;
  final ImageProcessor imageProcessor;
  final String? title;

  /// When true, the Crop & Rotate tab uses the 4-corner perspective-crop
  /// overlay (with auto-detect) instead of the rectangular crop. Enabled from
  /// the document scanner; the generic image editor keeps rectangular crop.
  final bool enableDocumentQuad;

  static Future<ScannedPage?> show(
    BuildContext context, {
    required ScannedPage page,
    ImageProcessor? imageProcessor,
    String? title,
    bool enableDocumentQuad = false,
  }) {
    return showModalBottomSheet<ScannedPage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PageAdjustmentSheet(
        page: page,
        imageProcessor: imageProcessor ?? const DartImageProcessor(),
        title: title,
        enableDocumentQuad: enableDocumentQuad,
      ),
    );
  }

  @override
  State<PageAdjustmentSheet> createState() => _PageAdjustmentSheetState();
}

class _PageAdjustmentSheetState extends State<PageAdjustmentSheet> {
  late ImageAdjustments _adjustments;
  late ScanMode _scanMode;
  NormalizedQuad? _documentQuad;
  bool _isDetecting = false;
  Map<ScanMode, Uint8List> _modePreviews = const {};
  int _activeTab = 0; // 0: Tone & Style, 1: Crop & Rotate
  bool _isFineTuneExpanded = true;

  @override
  void initState() {
    super.initState();
    _adjustments = widget.page.adjustments;
    _scanMode = widget.page.scanMode;
    _documentQuad = widget.page.documentQuad;
    _bakeModePreviews();
  }

  Future<void> _bakeModePreviews() async {
    try {
      final previews =
          await widget.imageProcessor.renderModePreviews(widget.page.previewBytes);
      if (mounted) setState(() => _modePreviews = previews);
    } catch (_) {
      // Carousel falls back to plain preview bytes on the canvas.
    }
  }

  /// The mode-baked base image shown on the live canvas (tone knobs layer on top
  /// via the GPU colour matrix inside [ScannerPreviewCanvas]).
  Uint8List get _canvasBytes =>
      _modePreviews[_scanMode] ?? widget.page.previewBytes;

  void _onAdjustmentsChanged(ImageAdjustments updated) {
    setState(() {
      _adjustments = updated;
    });
  }

  void _selectMode(ScanMode mode) {
    setState(() => _scanMode = mode);
  }

  void _resetCrop() {
    setState(() {
      _adjustments = _adjustments.copyWith(clearCrop: true);
    });
  }

  void _resetAll() {
    setState(() {
      _adjustments = ImageAdjustments.neutral;
      _scanMode = ScanMode.original;
      if (widget.enableDocumentQuad) _documentQuad = null;
    });
  }

  /// The quad shown/edited on the canvas (full-frame when none is set yet).
  NormalizedQuad get _effectiveQuad => _documentQuad ?? NormalizedQuad.full;

  void _resetQuadToFullPage() {
    setState(() => _documentQuad = NormalizedQuad.full);
  }

  Future<void> _autoDetectQuad() async {
    setState(() => _isDetecting = true);
    try {
      final result =
          await widget.imageProcessor.detectDocumentQuad(widget.page.rawImageBytes);
      if (!mounted) return;
      setState(() {
        // Accept a confident detection; otherwise fall back to full page.
        _documentQuad =
            result.confidence >= 0.35 ? result.quad : NormalizedQuad.full;
      });
      if (mounted && result.confidence < 0.35) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect page edges — adjust the corners manually.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetecting = false);
    }
  }

  void _commitAndClose() {
    final quadIsMeaningful =
        _documentQuad != null && !_documentQuad!.isFullFrame;
    final updatedPage = widget.page.copyWith(
      adjustments: _adjustments,
      scanMode: _scanMode,
      documentQuad: widget.enableDocumentQuad && quadIsMeaningful
          ? _documentQuad
          : null,
      clearDocumentQuad: widget.enableDocumentQuad && !quadIsMeaningful,
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
                  widget.title ?? 'Page ${widget.page.pageNumber} Adjustments',
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
                previewBytes: _canvasBytes,
                adjustments: _adjustments,
                isCropMode: _activeTab == 1,
                onAdjustmentsChanged: _onAdjustmentsChanged,
                quad: widget.enableDocumentQuad ? _effectiveQuad : null,
                onQuadChanged: widget.enableDocumentQuad
                    ? (q) => setState(() => _documentQuad = q)
                    : null,
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
    final monochrome = _scanMode.isMonochrome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Capture-mode selector (replaces the old fake presets).
        Text(
          'MODE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ScanMode.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final mode = ScanMode.values[index];
              return _buildModeTile(mode, colors);
            },
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Grayscale Toggle (redundant while a monochrome mode is active)
        Opacity(
          opacity: monochrome ? 0.4 : 1.0,
          child: Row(
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
                value: monochrome || _adjustments.grayscale,
                activeTrackColor: colors.accent,
                onChanged: monochrome
                    ? null
                    : (val) =>
                        _onAdjustmentsChanged(_adjustments.copyWith(grayscale: val)),
              ),
            ],
          ),
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

          // Saturation Slider (-1.0 to 1.0) — no-op under a monochrome mode
          _buildSliderRow(
            label: 'Saturation',
            value: monochrome ? 0.0 : _adjustments.saturation,
            icon: Icons.color_lens_outlined,
            colors: colors,
            enabled: !monochrome,
            onChanged: (val) =>
                _onAdjustmentsChanged(_adjustments.copyWith(saturation: val)),
          ),
        ],
      ],
    );
  }

  Widget _buildModeTile(ScanMode mode, AppColors colors) {
    final isSelected = mode == _scanMode;
    final bytes = _modePreviews[mode];

    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 66,
            decoration: BoxDecoration(
              color: colors.textTertiary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: isSelected ? colors.accent : colors.divider,
                width: isSelected ? 2.2 : 1.0,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true)
                : Icon(Icons.image_outlined, size: 20, color: colors.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            mode.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? colors.accent : colors.textSecondary,
            ),
          ),
        ],
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

        // Crop Actions — perspective quad (scanner) or rectangle (image editor)
        if (widget.enableDocumentQuad)
          ..._buildQuadCropActions(colors)
        else ...[
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
      ],
    );
  }

  List<Widget> _buildQuadCropActions(AppColors colors) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Document Edges',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: _resetQuadToFullPage,
            child: Text(
              'Use Full Page',
              style: TextStyle(color: colors.accent, fontSize: 13),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        'Drag the four corners to frame the page; it will be flattened to a straight-on scan. '
        'Auto-detect finds the edges for you.',
        style: TextStyle(fontSize: 12.5, color: colors.textSecondary, height: 1.4),
      ),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isDetecting ? null : _autoDetectQuad,
          icon: _isDetecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_fix_high_rounded),
          label: Text(_isDetecting ? 'Detecting…' : 'Auto-detect edges'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.accent,
            side: BorderSide(color: colors.accent),
          ),
        ),
      ),
    ];
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required IconData icon,
    required AppColors colors,
    required ValueChanged<double> onChanged,
    bool enabled = true,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Column(
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
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
