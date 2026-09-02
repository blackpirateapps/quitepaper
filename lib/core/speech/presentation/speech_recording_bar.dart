import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../domain/speech_session_state.dart';

class SpeechRecordingBar extends StatefulWidget {
  const SpeechRecordingBar({
    super.key,
    required this.session,
    required this.onStop,
    required this.onCancel,
    this.onErrorDismiss,
  });

  final SpeechSession session;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback? onErrorDismiss;

  @override
  State<SpeechRecordingBar> createState() => _SpeechRecordingBarState();
}

class _SpeechRecordingBarState extends State<SpeechRecordingBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final session = widget.session;

    if (session.state == SpeechSessionState.error) {
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
                session.errorMessage ?? 'Speech recognition failed.',
                style: AppTypography.caption.copyWith(
                  color: colors.error,
                ),
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

    if (session.state == SpeechSessionState.checkingModel ||
        session.state == SpeechSessionState.requestingPermission ||
        session.state == SpeechSessionState.loadingEngine) {
      final label = session.state == SpeechSessionState.requestingPermission
          ? 'Requesting microphone access…'
          : session.state == SpeechSessionState.loadingEngine
              ? 'Loading speech model…'
              : 'Preparing speech recognition…';

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

    if (session.isTranscribing) {
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
                'Transcribing on device…',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Recording State
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          // Pulsing Recording Dot
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Opacity(
                opacity: _pulseAnimation.value,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Listening',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatDuration(session.recordingDuration),
            style: AppTypography.caption.copyWith(
              color: colors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: widget.onStop,
              child: Container(
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceSubtle,
                  borderRadius: AppRadii.borderSm,
                  border: Border.all(
                    color: colors.divider.withValues(alpha: 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'Tap to stop recording',
                  style: AppTypography.caption.copyWith(
                    color: colors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Tooltip(
            message: 'Cancel recording',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                onTap: widget.onCancel,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancel',
                    style: AppTypography.caption.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}
