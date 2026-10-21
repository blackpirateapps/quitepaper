import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../features/tags/domain/phosphor_icons.dart';
import '../application/audio_duration_helper.dart';
import '../domain/audio_journal_models.dart';

/// Active voice memo recording panel docked into the editor toolbar area.
///
/// Provides:
/// - Pulsing recording dot or paused badge
/// - Elapsed captured audio timer (MM:SS)
/// - Live amplitude audio-level visualization bars
/// - Pause / Resume controls
/// - Finish recording (check) and Discard (trash/cancel) actions
class AudioRecordingBar extends StatefulWidget {
  const AudioRecordingBar({
    super.key,
    required this.session,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onCancel,
    this.onErrorDismiss,
  });

  final AudioJournalRecordingSession session;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onCancel;
  final VoidCallback? onErrorDismiss;

  @override
  State<AudioRecordingBar> createState() => _AudioRecordingBarState();
}

class _AudioRecordingBarState extends State<AudioRecordingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final session = widget.session;

    // Error State
    if (session.status == AudioJournalStatus.failed) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.divider, width: 0.8),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: colors.error,
              size: 16,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                session.errorMessage ?? 'Voice recording failed.',
                style: AppTypography.caption.copyWith(color: colors.error),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: colors.textSecondary),
              tooltip: 'Dismiss',
              onPressed: widget.onErrorDismiss ?? widget.onCancel,
            ),
          ],
        ),
      );
    }

    // Busy / Finalizing / Encrypting State
    if (session.isBusy) {
      final label = session.status == AudioJournalStatus.requestingPermission
          ? 'Requesting microphone access…'
          : session.status == AudioJournalStatus.preparing
              ? 'Starting recorder…'
              : session.status == AudioJournalStatus.encrypting
                  ? 'Encrypting recording…'
                  : 'Saving voice memo…';

      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            top: BorderSide(color: colors.divider, width: 0.8),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary),
              tooltip: 'Cancel',
              onPressed: widget.onCancel,
            ),
          ],
        ),
      );
    }

    final isPaused = session.isPaused;
    final timerText = AudioDurationHelper.formatDuration(session.elapsedDuration);

    // Active Recording / Paused Panel
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),

          // Distinct recording indicator (pulsing red/coral dot when live, pause icon when paused)
          if (!isPaused)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accent,
                    ),
                  ),
                );
              },
            )
          else
            Icon(
              PhosphorIconsRegular.pause,
              size: 14,
              color: colors.textSecondary,
            ),

          const SizedBox(width: AppSpacing.sm),

          // Elapsed recording timer
          Text(
            timerText,
            style: AppTypography.bodySmall.copyWith(
              color: isPaused ? colors.textSecondary : colors.textPrimary,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Live audio-level visualization
          Expanded(
            child: _LiveWaveformVisualizer(
              amplitudes: session.liveAmplitudes,
              isPaused: isPaused,
              barColor: isPaused ? colors.textTertiary : colors.accent,
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Pause / Resume toggle button
          IconButton(
            icon: Icon(
              isPaused ? PhosphorIconsRegular.play : PhosphorIconsRegular.pause,
              size: 20,
              color: colors.textPrimary,
            ),
            tooltip: isPaused ? 'Resume Recording' : 'Pause Recording',
            onPressed: isPaused ? widget.onResume : widget.onPause,
          ),

          // Finish recording button
          IconButton(
            icon: Icon(
              PhosphorIconsFill.checkCircle,
              size: 24,
              color: colors.accent,
            ),
            tooltip: 'Finish Recording',
            onPressed: widget.onFinish,
          ),

          // Discard / Cancel button
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.trash,
              size: 18,
              color: colors.textSecondary,
            ),
            tooltip: 'Discard Recording',
            onPressed: widget.onCancel,
          ),

          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Mini live waveform visualization reacting to recent recorded amplitudes.
class _LiveWaveformVisualizer extends StatelessWidget {
  const _LiveWaveformVisualizer({
    required this.amplitudes,
    required this.isPaused,
    required this.barColor,
  });

  final List<double> amplitudes;
  final bool isPaused;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const barWidth = 2.5;
        const gap = 3.0;
        final maxBars = (constraints.maxWidth / (barWidth + gap)).floor().clamp(8, 28);

        final recentBars = amplitudes.length > maxBars
            ? amplitudes.sublist(amplitudes.length - maxBars)
            : amplitudes;

        return SizedBox(
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(maxBars, (index) {
              final ampIndex = recentBars.length - maxBars + index;
              final double heightFraction;
              if (ampIndex >= 0 && ampIndex < recentBars.length) {
                heightFraction = recentBars[ampIndex];
              } else {
                heightFraction = 0.15;
              }

              final barHeight = (heightFraction * 20).clamp(3.0, 20.0);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: barWidth,
                  height: isPaused ? 4.0 : barHeight,
                  decoration: BoxDecoration(
                    color: isPaused ? barColor.withValues(alpha: 0.3) : barColor,
                    borderRadius: BorderRadius.circular(1.0),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
