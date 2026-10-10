import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/image_processing/scan_mode.dart';

/// Office Lens–style horizontal strip of capture-mode thumbnails.
///
/// Each item shows the current page baked in that [ScanMode] (when a preview is
/// available in [previews]) with its label; tapping selects it. If a preview is
/// not yet computed, a labeled placeholder tile is shown instead so the strip
/// never blocks on rendering.
class ScanModeCarousel extends StatelessWidget {
  const ScanModeCarousel({
    super.key,
    required this.selected,
    required this.onSelected,
    this.previews = const {},
    this.modes = ScanMode.values,
    this.isLoading = false,
  });

  /// Currently selected mode.
  final ScanMode selected;

  /// Called when the user taps a mode tile.
  final ValueChanged<ScanMode> onSelected;

  /// Baked per-mode thumbnail bytes (keyed by mode). May be partial/empty.
  final Map<ScanMode, Uint8List> previews;

  /// Which modes to show, in order.
  final List<ScanMode> modes;

  /// Whether previews are still being computed (shows a subtle shimmer hint).
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: modes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final mode = modes[index];
          final isSelected = mode == selected;
          final bytes = previews[mode];

          return GestureDetector(
            onTap: () => onSelected(mode),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 76,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(
                      color: isSelected ? colors.accent : Colors.white24,
                      width: isSelected ? 2.4 : 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes != null
                      ? Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        )
                      : Center(
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white54),
                                  ),
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  color: Colors.white38,
                                  size: 22,
                                ),
                        ),
                ),
                const SizedBox(height: 4),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? colors.accent : Colors.white70,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
