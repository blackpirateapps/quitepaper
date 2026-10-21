import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../features/tags/domain/phosphor_icons.dart';
import '../application/audio_duration_helper.dart';
import '../application/audio_journal_provider.dart';
import 'audio_rename_dialog.dart';

/// Embedded interactive audio presentation card for voice memos and recordings.
///
/// Supports both:
/// 1. Compact inline mode (Image 0):
///    Microphone icon + Title + Subtitle ("9:05 AM · 03:18") + Play button.
/// 2. Expanded rich player card (Image 1):
///    Waveform icon + Title + Subtitle ("21 Oct 2026 · 4:12 PM") + Overflow menu,
///    Play/Pause button + Elapsed time ("00:08") + Seekable waveform + Duration ("04:36"),
///    Lock badge ("Encrypted attachment · Available offline").
class QuietAudioCard extends ConsumerStatefulWidget {
  const QuietAudioCard({
    super.key,
    required this.attachmentId,
    required this.title,
    required this.uriString,
    this.initialEntity,
    this.initialExpanded = false,
    this.onAttachmentRenamed,
    this.onAttachmentDeleted,
    this.isReadOnly = false,
  });

  final String attachmentId;
  final String title;
  final String uriString;
  final AttachmentEntity? initialEntity;
  final bool initialExpanded;
  final void Function(String attachmentId, String newTitle)? onAttachmentRenamed;
  final void Function(String attachmentId)? onAttachmentDeleted;
  final bool isReadOnly;

  @override
  ConsumerState<QuietAudioCard> createState() => _QuietAudioCardState();
}

class _QuietAudioCardState extends ConsumerState<QuietAudioCard> {
  AttachmentEntity? _entity;
  bool _isExpanded = false;
  Duration? _cachedDuration;
  List<double> _waveformBars = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
    _entity = widget.initialEntity;
    _loadAttachment();
  }

  @override
  void didUpdateWidget(QuietAudioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) {
      _loadAttachment();
    }
  }

  Future<void> _loadAttachment() async {
    final service = ref.read(attachmentServiceProvider);
    final entity = await service.database.getAttachment(widget.attachmentId);
    if (!mounted) return;

    setState(() {
      _entity = entity;
      if (_entity != null && _cachedDuration == null) {
        _cachedDuration = _estimateDuration(_entity!);
      }
    });

    _computeWaveformPreview();
  }

  Duration _estimateDuration(AttachmentEntity entity) {
    // If M4A AAC (128 kbps mono ~ 16,000 bytes/sec)
    final isWav = entity.mimeType.contains('wav') || entity.fileName.endsWith('.wav');
    final bytesPerSec = isWav ? 32000 : 16000;
    if (entity.byteSize > 0) {
      final seconds = (entity.byteSize / bytesPerSec).round();
      return Duration(seconds: seconds > 0 ? seconds : 1);
    }
    return Duration.zero;
  }

  Future<void> _computeWaveformPreview() async {
    try {
      final service = ref.read(attachmentServiceProvider);
      final cache = service.getDecryptedCache(widget.attachmentId);
      if (cache != null && cache.isNotEmpty) {
        final bars = AudioDurationHelper.extractAmplitudesFromBytes(cache, count: 32);
        if (mounted) {
          setState(() {
            _waveformBars = bars;
          });
        }
      } else {
        if (mounted && _waveformBars.isEmpty) {
          setState(() {
            _waveformBars = AudioDurationHelper.extractAmplitudesFromBytes(
              Uint8List(0),
              count: 32,
            );
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _togglePlayback() async {
    final playbackService = ref.read(audioPlaybackServiceProvider);
    final snapshot = playbackService.snapshot;
    final isThisActive = snapshot.activeAttachmentId == widget.attachmentId;

    if (isThisActive && snapshot.isPlaying) {
      await playbackService.pause();
      return;
    }

    if (isThisActive && snapshot.isPaused) {
      await playbackService.resume();
      return;
    }

    // Start playing this clip
    setState(() {
      _isLoading = true;
      _isExpanded = true;
    });

    try {
      final attachmentService = ref.read(attachmentServiceProvider);
      final resolution = await attachmentService.resolveAsset(widget.attachmentId);

      if (!resolution.isAvailable || resolution.data == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(resolution.errorMessage ?? 'Audio recording not available.'),
              behavior: SnackBarBehavior.floating,
              persist: false,
            ),
          );
        }
        return;
      }

      final bytes = resolution.data!;
      final mimeType = _entity?.mimeType ?? 'audio/mp4';

      if (mounted) {
        setState(() {
          _waveformBars = AudioDurationHelper.extractAmplitudesFromBytes(bytes, count: 32);
          _isLoading = false;
        });
      }

      await playbackService.playBytes(
        attachmentId: widget.attachmentId,
        bytes: bytes,
        mimeType: mimeType,
        initialDuration: _cachedDuration,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            behavior: SnackBarBehavior.floating,
            persist: false,
          ),
        );
      }
    }
  }

  Future<void> _handleRename() async {
    final newTitle = await AudioRenameDialog.show(
      context,
      currentTitle: widget.title,
    );
    if (newTitle != null && newTitle.isNotEmpty && newTitle != widget.title) {
      widget.onAttachmentRenamed?.call(widget.attachmentId, newTitle);
    }
  }

  Future<void> _handleExport() async {
    try {
      final attachmentService = ref.read(attachmentServiceProvider);
      final resolution = await attachmentService.resolveAsset(widget.attachmentId);
      if (!resolution.isAvailable || resolution.data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not decrypt audio for export.'),
              behavior: SnackBarBehavior.floating,
              persist: false,
            ),
          );
        }
        return;
      }

      final ext = (_entity?.mimeType.contains('wav') == true) ? 'wav' : 'm4a';
      final cleanTitle = widget.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
      final defaultName = '${cleanTitle.isNotEmpty ? cleanTitle : "recording"}.$ext';

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Audio Recording',
        fileName: defaultName,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: resolution.data!,
      );

      if (savePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio exported successfully.'),
            behavior: SnackBarBehavior.floating,
            persist: false,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            behavior: SnackBarBehavior.floating,
            persist: false,
          ),
        );
      }
    }
  }

  void _handleDelete() {
    widget.onAttachmentDeleted?.call(widget.attachmentId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final playbackSnapshot = ref.watch(audioPlaybackSnapshotProvider);
    final isThisActive = playbackSnapshot.activeAttachmentId == widget.attachmentId;
    final isPlaying = isThisActive && playbackSnapshot.isPlaying;
    final isPaused = isThisActive && playbackSnapshot.isPaused;

    // Cache actual duration from player when available
    if (isThisActive && playbackSnapshot.duration > Duration.zero) {
      _cachedDuration = playbackSnapshot.duration;
    }

    final effectiveDuration = (isThisActive && playbackSnapshot.duration > Duration.zero)
        ? playbackSnapshot.duration
        : (_cachedDuration ?? Duration.zero);

    final position = isThisActive ? playbackSnapshot.position : Duration.zero;

    // If active playback starts, automatically expand to show waveform
    final shouldShowExpanded = _isExpanded || isPlaying || isPaused;

    if (!shouldShowExpanded) {
      return _buildCompactView(
        colors: colors,
        effectiveDuration: effectiveDuration,
        isPlaying: isPlaying,
      );
    }

    return _buildExpandedCard(
      colors: colors,
      position: position,
      effectiveDuration: effectiveDuration,
      isPlaying: isPlaying,
      isPaused: isPaused,
      isThisActive: isThisActive,
    );
  }

  /// Compact inline row (Image 0).
  Widget _buildCompactView({
    required AppColors colors,
    required Duration effectiveDuration,
    required bool isPlaying,
  }) {
    final timeStr = _entity != null
        ? AudioDurationHelper.formatTimeOnly(_entity!.createdAt)
        : '';
    final durStr = AudioDurationHelper.formatDuration(effectiveDuration);
    final subtitle = timeStr.isNotEmpty ? '$timeStr · $durStr' : durStr;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.borderMd,
          onTap: () {
            setState(() {
              _isExpanded = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Microphone icon in accent color
                Icon(
                  PhosphorIconsFill.microphone,
                  size: 20,
                  color: colors.accent,
                ),
                const SizedBox(width: 14),
                // Title & Subtitle column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular Play Button
                if (_isLoading)
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? PhosphorIconsFill.pauseCircle
                          : PhosphorIconsFill.playCircle,
                      size: 32,
                      color: colors.textPrimary,
                    ),
                    tooltip: isPlaying ? 'Pause' : 'Play',
                    onPressed: _togglePlayback,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full / expanded audio player card (Image 1).
  Widget _buildExpandedCard({
    required AppColors colors,
    required Duration position,
    required Duration effectiveDuration,
    required bool isPlaying,
    required bool isPaused,
    required bool isThisActive,
  }) {
    final dateTimeStr = _entity != null
        ? AudioDurationHelper.formatDateTime(_entity!.createdAt)
        : '';

    final positionStr = AudioDurationHelper.formatDuration(position);
    final durationStr = AudioDurationHelper.formatDuration(effectiveDuration);

    final progressFraction = effectiveDuration > Duration.zero
        ? (position.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Row: Waveform icon + Title / Subtitle + ⋯ Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  PhosphorIconsRegular.waveform,
                  size: 22,
                  color: colors.textPrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.bodyLarge.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (dateTimeStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateTimeStr,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Overflow menu
                PopupMenuButton<String>(
                  icon: Icon(
                    PhosphorIconsRegular.dotsThree,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  tooltip: 'Recording Options',
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadii.borderSm,
                    side: BorderSide(color: colors.divider, width: 0.8),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        _handleRename();
                        break;
                      case 'export':
                        _handleExport();
                        break;
                      case 'delete':
                        _handleDelete();
                        break;
                      case 'collapse':
                        setState(() => _isExpanded = false);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!widget.isReadOnly)
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Rename'),
                      ),
                    const PopupMenuItem(
                      value: 'export',
                      child: Text('Export audio…'),
                    ),
                    const PopupMenuItem(
                      value: 'collapse',
                      child: Text('Compact view'),
                    ),
                    if (!widget.isReadOnly) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Remove from note',
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Middle Row: Play/Pause button + Position + Waveform + Duration
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Play / Pause outline button
                if (_isLoading)
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    ),
                  )
                else
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _togglePlayback,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.textPrimary, width: 1.5),
                      ),
                      child: Center(
                        child: Icon(
                          isPlaying
                              ? PhosphorIconsFill.pause
                              : PhosphorIconsFill.play,
                          size: 16,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(width: 14),

                // Position timestamp
                Text(
                  positionStr,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(width: 12),

                // Center seekable waveform bars
                Expanded(
                  child: _WaveformSeeker(
                    bars: _waveformBars,
                    progressFraction: progressFraction,
                    playedColor: colors.accent,
                    unplayedColor: colors.textTertiary.withValues(alpha: 0.35),
                    onSeek: (frac) {
                      if (effectiveDuration > Duration.zero) {
                        final targetMs = (effectiveDuration.inMilliseconds * frac).round();
                        ref
                            .read(audioPlaybackServiceProvider)
                            .seek(Duration(milliseconds: targetMs));
                      }
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // Duration timestamp
                Text(
                  durationStr,
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bottom Row: Lock icon + "Encrypted attachment · Available offline"
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.lock,
                  size: 14,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Encrypted attachment · Available offline',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive seekable waveform bar visualization.
class _WaveformSeeker extends StatelessWidget {
  const _WaveformSeeker({
    required this.bars,
    required this.progressFraction,
    required this.playedColor,
    required this.unplayedColor,
    required this.onSeek,
  });

  final List<double> bars;
  final double progressFraction;
  final Color playedColor;
  final Color unplayedColor;
  final ValueChanged<double> onSeek;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = bars.isNotEmpty ? bars.length : 32;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) {
            final frac = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(frac);
          },
          onHorizontalDragUpdate: (details) {
            final frac = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
            onSeek(frac);
          },
          child: SizedBox(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(count, (index) {
                final barFraction = index / count;
                final isPlayed = barFraction <= progressFraction;
                final heightFraction = bars.isNotEmpty && index < bars.length
                    ? bars[index]
                    : 0.3;
                final barHeight = (heightFraction * 26).clamp(4.0, 26.0);

                return Container(
                  width: 2.5,
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: isPlayed ? playedColor : unplayedColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
