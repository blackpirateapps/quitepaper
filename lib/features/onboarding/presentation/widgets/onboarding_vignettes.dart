import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Decorative vignettes for the Quiet Paper onboarding flow.
/// All vignettes are purely visual and wrapped in [ExcludeSemantics].

class WelcomeVignette extends StatelessWidget {
  const WelcomeVignette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 220,
          height: 190,
          child: Stack(
          alignment: Alignment.center,
          children: [
            // Offset paper card 1 (-3 degrees)
            Transform.rotate(
              angle: -3 * math.pi / 180,
              child: Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.divider),
                ),
              ),
            ),
            // Offset paper card 2 (+2 degrees)
            Transform.rotate(
              angle: 2 * math.pi / 180,
              child: Container(
                width: 180,
                height: 120,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.divider),
                ),
              ),
            ),
            // Center icon & caption
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/icons/icon.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiet Paper',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textTertiary,
                    letterSpacing: 0.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class PrivacyVignette extends StatelessWidget {
  const PrivacyVignette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          height: 180,
          child: Stack(
            children: [
              // Note card
              Positioned(
                left: 0,
                top: 10,
                child: Container(
                  width: 250,
                  height: 155,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Morning thoughts',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Skeleton line 1 (92%)
                      Container(
                        width: 190,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 7),
                      // Skeleton line 2 (78%)
                      Container(
                        width: 160,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 7),
                      // Skeleton line 3 (56%)
                      Container(
                        width: 120,
                        height: 6,
                        decoration: BoxDecoration(
                          color: colors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const Spacer(),
                      // Lock pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 13,
                                color: colors.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Encrypted on device',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Cloud icon & dashed indicator behind/right
              Positioned(
                right: 6,
                top: 25,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      size: 44,
                      color: colors.textTertiary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ciphertext only',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Dashed connection indicator
              Positioned(
                right: 68,
                top: 48,
                child: CustomPaint(
                  size: const Size(30, 2),
                  painter: _DashedLinePainter(color: colors.divider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceVignette extends StatelessWidget {
  const VoiceVignette({super.key});

  static const List<double> waveformHeights = [
    8, 14, 20, 28, 18, 34, 24, 16, 30, 22, 12, 26, 32, 18, 24, 14, 10
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Voice memo card (320 x 96)
            Container(
              height: 96,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Play circle
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accentSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          size: 22,
                          color: colors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Waveform bars
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            for (final h in waveformHeights) ...[
                              Container(
                                width: 3.5,
                                height: h,
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 3),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '0:42',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voice memo',
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                      ),
                      // On-device pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.memory_rounded,
                              size: 13,
                              color: colors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'On-device',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: colors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Transcript card (320 x 92)
            Container(
              height: 92,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'TRANSCRIPT',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Skeleton line 1 (88%)
                  Container(
                    width: 320 * 0.88 - 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Skeleton line 2 (96%)
                  Container(
                    width: 320 * 0.96 - 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Skeleton line 3 (64%)
                  Container(
                    width: 320 * 0.64 - 28,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

class SimplicityVignette extends StatelessWidget {
  const SimplicityVignette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Above chip: No folders
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 14,
                    color: colors.textTertiary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'No folders',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // List card (320 x 190)
            Container(
              width: 320,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1
                  _buildNoteRow(
                    colors: colors,
                    title: 'A quiet place to think',
                    tag: '#welcome',
                    isPinned: true,
                  ),
                  Divider(height: 1, thickness: 1, color: colors.divider),
                  // Row 2
                  _buildNoteRow(
                    colors: colors,
                    title: 'Books I want to read',
                    tag: '#reading',
                  ),
                  Divider(height: 1, thickness: 1, color: colors.divider),
                  // Row 3
                  _buildNoteRow(
                    colors: colors,
                    title: 'Morning thoughts',
                    tag: '#journal',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Below list: loose tag chips
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTagChip(colors, '#ideas'),
                  const SizedBox(width: 8),
                  _buildTagChip(colors, '#writing'),
                  const SizedBox(width: 8),
                  _buildTagChip(colors, '#reference'),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildNoteRow({
    required AppColors colors,
    required String title,
    required String tag,
    bool isPinned = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          if (isPinned) ...[
            Icon(
              Icons.push_pin_rounded,
              size: 13,
              color: colors.accent,
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildTagChip(colors, tag),
        ],
      ),
    );
  }

  Widget _buildTagChip(AppColors colors, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.tagBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: colors.tagText,
        ),
      ),
    );
  }
}

class OcrVignette extends StatelessWidget {
  const OcrVignette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rotated document card with scan brackets (240 x 150)
            Transform.rotate(
              angle: -1.5 * math.pi / 180,
              child: SizedBox(
                width: 240,
                height: 140,
                child: Stack(
                  children: [
                    // Base document
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 160,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Highlighted line
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accentSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Container(
                              width: 180,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 140,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 100,
                            height: 6,
                            decoration: BoxDecoration(
                              color: colors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 4 Scanner corner brackets
                    // Top-left
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _buildScannerCorner(colors, isTop: true, isLeft: true),
                    ),
                    // Top-right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildScannerCorner(colors, isTop: true, isLeft: false),
                    ),
                    // Bottom-left
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildScannerCorner(colors, isTop: false, isLeft: true),
                    ),
                    // Bottom-right
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildScannerCorner(colors, isTop: false, isLeft: false),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Downward indicator
            Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: colors.accent,
            ),
            const SizedBox(height: 8),
            // Extracted text card (250 x 70)
            Container(
              width: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SEARCHABLE TEXT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: colors.textTertiary,
                        ),
                      ),
                      Icon(
                        Icons.search_rounded,
                        size: 15,
                        color: colors.accent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The quietest notes are often the truest.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 140,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildScannerCorner(
    AppColors colors, {
    required bool isTop,
    required bool isLeft,
  }) {
    const size = 16.0;
    const thickness = 2.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: colors.accent, width: thickness)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: colors.accent, width: thickness)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: colors.accent, width: thickness)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: colors.accent, width: thickness)
              : BorderSide.none,
        ),
      ),
    );
  }
}

class SyncVignette extends StatelessWidget {
  const SyncVignette({super.key, this.isConnected = false});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 320,
          height: 180,
          child: Stack(
          alignment: Alignment.center,
          children: [
            // Phone shape (left) - 90 x 150
            Positioned(
              left: 12,
              child: Container(
                width: 90,
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.divider, width: 1.5),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: colors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 5,
                      width: 50,
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 5,
                      width: 60,
                      decoration: BoxDecoration(
                        color: colors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Laptop shape (right) - 150 x 90
            Positioned(
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130,
                    height: 80,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.divider, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 5,
                          width: 40,
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 5,
                          width: 80,
                          decoration: BoxDecoration(
                            color: colors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 150,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),
            // Connection line between devices
            Positioned(
              left: 95,
              right: 125,
              child: isConnected
                  ? Container(
                      height: 2,
                      color: colors.accent,
                    )
                  : CustomPaint(
                      size: const Size(60, 2),
                      painter: _DashedLinePainter(color: colors.divider),
                    ),
            ),
            // Lock badge in the centre
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colors.accentSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    isConnected ? Icons.lock_rounded : Icons.lock_outline_rounded,
                    size: 16,
                    color: colors.accentDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'end-to-end encrypted',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: colors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class ReadyVignette extends StatelessWidget {
  const ReadyVignette({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return ExcludeSemantics(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
        width: 300,
        height: 170,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.divider),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Note row 1 skeleton
                Container(
                  width: 120,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                // Note row 2 skeleton
                Container(
                  width: 140,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 6,
                  decoration: BoxDecoration(
                    color: colors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
            // Floating + button with spotlight halo
            Positioned(
              right: 4,
              bottom: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Spotlight ring
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                  ),
                  // Accent halo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentSoft,
                    ),
                  ),
                  // Inner + button
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(math.min(startX + dashWidth, size.width), size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
