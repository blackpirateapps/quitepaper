import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../core/attachments/attachment_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/font_family_helper.dart';
import '../../../features/settings/application/typography_provider.dart';
import '../../../features/settings/domain/typography_settings.dart';
import '../../../features/tags/domain/phosphor_icons.dart';
import '../../speech/presentation/speech_download_dialog.dart';
import '../application/audio_duration_helper.dart';
import '../application/audio_journal_provider.dart';
import '../application/audio_transcription_provider.dart';
import '../domain/audio_transcript_models.dart';
import 'audio_rename_dialog.dart';

/// Embedded interactive audio presentation card for voice memos and recordings.
///
/// Supports:
/// 1. Compact inline mode:
///    Microphone icon + Title + Subtitle ("9:05 AM · 03:18") + Play button.
/// 2. Expanded rich player card with Transcript section (Image 0):
///    Waveform icon + Title + Subtitle ("21 October · 9:05 AM · 03:18") + Overflow menu,
///    Play/Pause button + Elapsed time ("00:45 / 03:18") + Seekable waveform,
///    Collapsible transcript container with on-device badge & "Edit transcript" action.
/// 3. In-flight processing interface (Image 1):
///    Header with spinner, status stage ("Transcribing on device…"), progress bar,
///    on-device privacy guarantee badge, and "Cancel" action.
class QuietAudioCard extends ConsumerStatefulWidget {
  const QuietAudioCard({
    super.key,
    required this.attachmentId,
    required this.title,
    required this.uriString,
    this.initialEntity,
    this.initialExpanded = false,
    this.initialTranscript,
    this.initialTranscriptLanguage,
    this.initialIsTranscriptEdited = false,
    this.onTranscriptChanged,
    this.onInsertTranscript,
    this.onAttachmentRenamed,
    this.onAttachmentDeleted,
    this.isReadOnly = false,
  });

  final String attachmentId;
  final String title;
  final String uriString;
  final AttachmentEntity? initialEntity;
  final bool initialExpanded;
  final String? initialTranscript;
  final String? initialTranscriptLanguage;
  final bool initialIsTranscriptEdited;
  final void Function(String newTranscript, bool isEdited)? onTranscriptChanged;
  final void Function(String transcriptText)? onInsertTranscript;
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

  // Transcript state
  String? _transcript;
  String? _transcriptLanguage;
  bool _isTranscriptEdited = false;
  bool _isTranscriptExpanded = true;
  bool _isEditingTranscript = false;
  late TextEditingController _transcriptEditController;

  AudioTranscriptionJobState? _jobState;
  StreamSubscription<AudioTranscriptionJobState>? _jobSubscription;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded || widget.initialTranscript != null;
    _entity = widget.initialEntity;
    _transcript = widget.initialTranscript;
    _transcriptLanguage = widget.initialTranscriptLanguage;
    _isTranscriptEdited = widget.initialIsTranscriptEdited;
    _transcriptEditController = TextEditingController(text: _transcript ?? '');

    _subscribeToTranscriptionJobs();
    _loadAttachment();
  }

  @override
  void didUpdateWidget(QuietAudioCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachmentId != widget.attachmentId) {
      _jobSubscription?.cancel();
      _subscribeToTranscriptionJobs();
      _loadAttachment();
    }
    if (oldWidget.initialTranscript != widget.initialTranscript &&
        widget.initialTranscript != null) {
      _transcript = widget.initialTranscript;
      _transcriptLanguage = widget.initialTranscriptLanguage;
      _isTranscriptEdited = widget.initialIsTranscriptEdited;
      _transcriptEditController.text = _transcript ?? '';
    }
  }

  @override
  void dispose() {
    _jobSubscription?.cancel();
    _transcriptEditController.dispose();
    super.dispose();
  }

  void _subscribeToTranscriptionJobs() {
    final transcriptionService = ref.read(audioFileTranscriptionServiceProvider);
    final active = transcriptionService.getJobState(widget.attachmentId);
    if (active != null && active.isBusy) {
      _jobState = active;
    }
    _jobSubscription = transcriptionService.watchJob(widget.attachmentId).listen((state) {
      if (!mounted) return;
      setState(() {
        _jobState = state;
        if (state.isCompleted && state.transcriptData != null) {
          _jobState = null;
          _transcript = state.transcriptData!.text;
          _transcriptLanguage = state.transcriptData!.language;
          _isTranscriptEdited = state.transcriptData!.isEdited;
          _transcriptEditController.text = _transcript ?? '';
          _isTranscriptExpanded = true;
          _isExpanded = true;
          widget.onTranscriptChanged?.call(_transcript!, _isTranscriptEdited);
        } else if (state.hasFailed || state.isCancelled) {
          _jobState = null;
        }
      });
    });
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
      final waveformCache = ref.read(audioWaveformCacheServiceProvider);

      // 1. Check local persistent waveform cache first (instant synchronous lookup, no decryption needed)
      final cached = waveformCache.getWaveform(widget.attachmentId);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _waveformBars = cached;
          });
        }
        return;
      }

      // 2. Check if decrypted bytes are in memory cache
      final service = ref.read(attachmentServiceProvider);
      final memCache = service.getDecryptedCache(widget.attachmentId);
      if (memCache != null && memCache.isNotEmpty) {
        final bars = AudioDurationHelper.extractAmplitudesFromBytes(
          memCache,
          count: 32,
          mimeType: _entity?.mimeType,
          fileName: _entity?.fileName,
        );
        await waveformCache.cacheWaveform(widget.attachmentId, bars);
        if (mounted) {
          setState(() {
            _waveformBars = bars;
          });
        }
        return;
      }

      // 3. Resolve the attachment locally on-device once in the background
      // to extract and cache the real waveform so the audio file stays encrypted on disk.
      final resolution = await service.resolveAsset(widget.attachmentId);
      if (resolution.isAvailable && resolution.data != null && resolution.data!.isNotEmpty) {
        final bars = AudioDurationHelper.extractAmplitudesFromBytes(
          resolution.data!,
          count: 32,
          mimeType: _entity?.mimeType,
          fileName: _entity?.fileName,
        );
        await waveformCache.cacheWaveform(widget.attachmentId, bars);
        if (mounted) {
          setState(() {
            _waveformBars = bars;
          });
        }
        return;
      }

      // 4. Fallback if resolution fails or asset not found
      if (mounted && _waveformBars.isEmpty) {
        setState(() {
          _waveformBars = AudioDurationHelper.extractAmplitudesFromBytes(
            Uint8List(0),
            count: 32,
          );
        });
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
        final bars = AudioDurationHelper.extractAmplitudesFromBytes(
          bytes,
          count: 32,
          mimeType: mimeType,
          fileName: _entity?.fileName,
        );
        ref.read(audioWaveformCacheServiceProvider).cacheWaveform(widget.attachmentId, bars);
        setState(() {
          _waveformBars = bars;
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

  Future<void> _startTranscription({bool isRegeneration = false}) async {
    setState(() {
      _isExpanded = true;
      _jobState = const AudioTranscriptionJobState(
        status: AudioTranscriptionStatus.checkingModel,
        stageLabel: 'Checking speech model…',
      );
    });

    final transcriptionService = ref.read(audioFileTranscriptionServiceProvider);
    final modelManager = transcriptionService.speechModelManager;
    final modelStatus = await modelManager.checkStatus();

    if (!modelStatus.isInstalled) {
      if (!mounted) return;
      final downloaded = await SpeechDownloadDialog.show(
        context,
        modelDescriptor: modelManager.descriptor,
      );
      if (downloaded != true) {
        if (mounted) {
          setState(() {
            _jobState = null;
          });
        }
        return;
      }
    }

    try {
      final result = await transcriptionService.transcribeAttachment(
        attachmentId: widget.attachmentId,
        onStateChange: (state) {
          if (mounted) {
            setState(() {
              _jobState = state;
            });
          }
        },
      );

      if (result != null && mounted) {
        setState(() {
          _jobState = null;
          _transcript = result.text;
          _transcriptLanguage = result.language;
          _isTranscriptEdited = false;
          _transcriptEditController.text = _transcript ?? '';
          _isTranscriptExpanded = true;
        });
        widget.onTranscriptChanged?.call(result.text, false);
      } else if (mounted) {
        setState(() {
          _jobState = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _jobState = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transcription error: $e'),
            behavior: SnackBarBehavior.floating,
            persist: false,
          ),
        );
      }
    }
  }

  void _cancelTranscription() {
    setState(() {
      _jobState = null;
    });
    ref
        .read(audioFileTranscriptionServiceProvider)
        .cancelTranscription(widget.attachmentId);
  }

  Future<void> _handleRegenerate() async {
    if (_isTranscriptEdited) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final colors = ctx.appColors;
          final typography = ref.read(typographySettingsProvider);
          return AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.borderMd),
            title: Text(
              'Regenerate transcript?',
              style: _headingStyle(
                typography: typography,
                baseSize: 18.0,
                color: colors.textPrimary,
              ),
            ),
            content: Text(
              'This transcript was edited manually. Regenerating will replace your edited text with a newly generated transcript.\n\nYour original voice recording is never modified.',
              style: _bodyStyle(
                typography: typography,
                baseSize: 14.0,
                color: colors.textPrimary,
                height: typography.lineHeight,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: _captionStyle(
                    typography: typography,
                    baseSize: 14.0,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Regenerate',
                  style: _captionStyle(
                    typography: typography,
                    baseSize: 14.0,
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      );

      if (confirmed != true) return;
    }

    await _startTranscription(isRegeneration: true);
  }

  void _copyTranscript() {
    if (_transcript == null || _transcript!.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _transcript!));
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcript copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
        persist: false,
      ),
    );
  }

  void _insertTranscriptIntoNote() {
    if (_transcript == null || _transcript!.isEmpty) return;
    widget.onInsertTranscript?.call(_transcript!);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transcript inserted into note.'),
        behavior: SnackBarBehavior.floating,
        persist: false,
      ),
    );
  }

  void _saveEditedTranscript() {
    final updated = _transcriptEditController.text.trim();
    if (updated.isNotEmpty && updated != _transcript) {
      setState(() {
        _transcript = updated;
        _isTranscriptEdited = true;
        _isEditingTranscript = false;
      });
      widget.onTranscriptChanged?.call(updated, true);
    } else {
      setState(() {
        _isEditingTranscript = false;
      });
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
    ref.read(audioWaveformCacheServiceProvider).removeWaveform(widget.attachmentId);
    widget.onAttachmentDeleted?.call(widget.attachmentId);
  }

  String _formatLanguageLabel(String? code) {
    if (code == null || code.isEmpty) return 'English';
    switch (code.toLowerCase()) {
      case 'en':
        return 'English';
      case 'auto':
        return 'Auto-detected';
      case 'es':
        return 'Spanish';
      case 'fr':
        return 'French';
      case 'de':
        return 'German';
      case 'it':
        return 'Italian';
      case 'pt':
        return 'Portuguese';
      case 'zh':
        return 'Chinese';
      case 'ja':
        return 'Japanese';
      default:
        return code.toUpperCase();
    }
  }

  TextStyle _headingStyle({
    required TypographySettings typography,
    required double baseSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    final headingFont = FontFamilyHelper.resolveHeadingFontFamily(
      typography.headingFontFamily ?? typography.bodyFontFamily,
    );
    return FontFamilyHelper.getTextStyle(
      fontFamily: headingFont,
      baseStyle: TextStyle(
        fontSize: typography.scaleFontSize(baseSize),
        fontWeight: fontWeight,
        letterSpacing: typography.letterSpacing,
        color: color,
      ),
    );
  }

  TextStyle _bodyStyle({
    required TypographySettings typography,
    required double baseSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    final bodyFont = FontFamilyHelper.resolveBodyFontFamily(
      typography.bodyFontFamily,
    );
    return FontFamilyHelper.getTextStyle(
      fontFamily: bodyFont,
      baseStyle: TextStyle(
        fontSize: typography.scaleFontSize(baseSize),
        fontWeight: fontWeight,
        height: height,
        letterSpacing: typography.letterSpacing,
        color: color,
        fontFeatures: fontFeatures,
      ),
    );
  }

  TextStyle _captionStyle({
    required TypographySettings typography,
    double baseSize = 12.0,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    List<FontFeature>? fontFeatures,
  }) {
    final bodyFont = FontFamilyHelper.resolveBodyFontFamily(
      typography.bodyFontFamily,
    );
    return FontFamilyHelper.getTextStyle(
      fontFamily: bodyFont,
      baseStyle: TextStyle(
        fontSize: typography.scaleFontSize(baseSize),
        fontWeight: fontWeight,
        letterSpacing: typography.letterSpacing,
        color: color,
        fontFeatures: fontFeatures,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final playbackSnapshot = ref.watch(audioPlaybackSnapshotProvider);
    final isThisActive = playbackSnapshot.activeAttachmentId == widget.attachmentId;
    final isPlaying = isThisActive && playbackSnapshot.isPlaying;
    final isPaused = isThisActive && playbackSnapshot.isPaused;

    if (isThisActive && playbackSnapshot.duration > Duration.zero) {
      _cachedDuration = playbackSnapshot.duration;
    }

    final effectiveDuration = (isThisActive && playbackSnapshot.duration > Duration.zero)
        ? playbackSnapshot.duration
        : (_cachedDuration ?? Duration.zero);

    final position = isThisActive ? playbackSnapshot.position : Duration.zero;

    // Check if in-flight transcription is actively busy for this attachment
    final jobAsync = ref.watch(audioTranscriptionJobStateProvider(widget.attachmentId));
    final activeJob = _jobState ?? jobAsync.valueOrNull;
    final isTranscribingBusy = activeJob?.isBusy == true;
    if (isTranscribingBusy) {
      return _buildProcessingInterface(
        colors: colors,
        typography: typography,
        effectiveDuration: effectiveDuration,
        jobState: activeJob,
      );
    }

    final shouldShowExpanded =
        _isExpanded || isPlaying || isPaused || (_transcript != null && _transcript!.isNotEmpty);

    if (!shouldShowExpanded) {
      return _buildCompactView(
        colors: colors,
        typography: typography,
        effectiveDuration: effectiveDuration,
        isPlaying: isPlaying,
      );
    }

    return _buildExpandedCard(
      colors: colors,
      typography: typography,
      position: position,
      effectiveDuration: effectiveDuration,
      isPlaying: isPlaying,
      isPaused: isPaused,
      isThisActive: isThisActive,
    );
  }

  /// In-flight processing interface (matches Image 1).
  Widget _buildProcessingInterface({
    required AppColors colors,
    required TypographySettings typography,
    required Duration effectiveDuration,
    AudioTranscriptionJobState? jobState,
  }) {
    final state = jobState ?? _jobState;
    const subtitle = 'Whisper Base · English';

    final stageLabel = (state?.stageLabel.isNotEmpty == true)
        ? state!.stageLabel
        : 'Transcribing on device…';

    final progressValue = state?.progressPercent != null
        ? (state!.progressPercent! / 100.0).clamp(0.0, 1.0)
        : null;

    final progressLabel = state?.progressPercent != null
        ? '${state!.progressPercent}%'
        : 'Processing';

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
            // Top Row: Waveform icon + Title / Subtitle + Loading spinner
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
                        style: _headingStyle(
                          typography: typography,
                          baseSize: 18.0,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: _captionStyle(
                          typography: typography,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.accent,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Middle status row: "Transcribing on device..." + "Processing"
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stageLabel,
                  style: _captionStyle(
                    typography: typography,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  progressLabel,
                  style: _captionStyle(
                    typography: typography,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Horizontal Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 3,
                backgroundColor: colors.divider.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
              ),
            ),

            const SizedBox(height: 14),

            // Bottom row: Shield badge + Cancel button
            Row(
              children: [
                Icon(
                  PhosphorIconsRegular.shieldCheck,
                  size: 15,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your audio stays on this device during transcription.',
                    style: _captionStyle(
                      typography: typography,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _cancelTranscription,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Cancel',
                      style: _captionStyle(
                        typography: typography,
                        color: colors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact inline row.
  Widget _buildCompactView({
    required AppColors colors,
    required TypographySettings typography,
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
                Icon(
                  PhosphorIconsFill.microphone,
                  size: 20,
                  color: colors.accent,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: _headingStyle(
                          typography: typography,
                          baseSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: _captionStyle(
                          typography: typography,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
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

  /// Full / expanded audio player card with Transcript section (matches Image 0).
  Widget _buildExpandedCard({
    required AppColors colors,
    required TypographySettings typography,
    required Duration position,
    required Duration effectiveDuration,
    required bool isPlaying,
    required bool isPaused,
    required bool isThisActive,
  }) {
    final dateStr = _entity != null
        ? AudioDurationHelper.formatDateTime(_entity!.createdAt)
        : '';
    final durationStr = AudioDurationHelper.formatDuration(effectiveDuration);
    final headerSubtitle = dateStr.isNotEmpty
        ? '$dateStr · $durationStr'
        : durationStr;

    final positionStr = AudioDurationHelper.formatDuration(position);

    final progressFraction = effectiveDuration > Duration.zero
        ? (position.inMilliseconds / effectiveDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final hasTranscript = _transcript != null && _transcript!.isNotEmpty;

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
            // 1. Top Row: Waveform icon + Title / Subtitle + ⋯ Menu
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
                        style: _headingStyle(
                          typography: typography,
                          baseSize: 18.0,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headerSubtitle,
                        style: _captionStyle(
                          typography: typography,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
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
                      case 'transcribe':
                        _startTranscription();
                        break;
                      case 'edit_transcript':
                        setState(() {
                          _isTranscriptExpanded = true;
                          _isEditingTranscript = true;
                        });
                        break;
                      case 'copy_transcript':
                        _copyTranscript();
                        break;
                      case 'insert_transcript':
                        _insertTranscriptIntoNote();
                        break;
                      case 'regenerate':
                        _handleRegenerate();
                        break;
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
                    if (!hasTranscript && !widget.isReadOnly)
                      PopupMenuItem(
                        value: 'transcribe',
                        child: Text(
                          'Transcribe audio',
                          style: _bodyStyle(typography: typography, baseSize: 14.0),
                        ),
                      ),
                    if (hasTranscript) ...[
                      PopupMenuItem(
                        value: 'copy_transcript',
                        child: Text(
                          'Copy transcript',
                          style: _bodyStyle(typography: typography, baseSize: 14.0),
                        ),
                      ),
                      if (!widget.isReadOnly) ...[
                        PopupMenuItem(
                          value: 'edit_transcript',
                          child: Text(
                            'Edit transcript',
                            style: _bodyStyle(typography: typography, baseSize: 14.0),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'insert_transcript',
                          child: Text(
                            'Insert into note',
                            style: _bodyStyle(typography: typography, baseSize: 14.0),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'regenerate',
                          child: Text(
                            'Regenerate transcript…',
                            style: _bodyStyle(typography: typography, baseSize: 14.0),
                          ),
                        ),
                      ],
                      const PopupMenuDivider(),
                    ],
                    if (!widget.isReadOnly)
                      PopupMenuItem(
                        value: 'rename',
                        child: Text(
                          'Rename',
                          style: _bodyStyle(typography: typography, baseSize: 14.0),
                        ),
                      ),
                    PopupMenuItem(
                      value: 'export',
                      child: Text(
                        'Export audio…',
                        style: _bodyStyle(typography: typography, baseSize: 14.0),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'collapse',
                      child: Text(
                        'Compact view',
                        style: _bodyStyle(typography: typography, baseSize: 14.0),
                      ),
                    ),
                    if (!widget.isReadOnly) ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Remove from note',
                          style: _bodyStyle(
                            typography: typography,
                            baseSize: 14.0,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 2. Middle Row: Play/Pause button + Position + Waveform + Duration
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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

                Text(
                  positionStr,
                  style: _captionStyle(
                    typography: typography,
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),

                const SizedBox(width: 12),

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

                Text(
                  durationStr,
                  style: _captionStyle(
                    typography: typography,
                    color: colors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            // 3. Transcript Section (Image 0)
            if (hasTranscript) ...[
              const SizedBox(height: 18),
              _buildTranscriptSection(colors: colors, typography: typography),
            ] else ...[
              const SizedBox(height: 16),
              // Bottom Row fallback: Lock icon + "Encrypted attachment"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.lock,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Encrypted attachment',
                            style: _captionStyle(
                              typography: typography,
                              color: colors.textTertiary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!widget.isReadOnly)
                    InkWell(
                      onTap: _startTranscription,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Transcribe audio',
                          style: _captionStyle(
                            typography: typography,
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Transcript section (collapsible container with header, body, and actions matching Image 0).
  Widget _buildTranscriptSection({
    required AppColors colors,
    required TypographySettings typography,
  }) {
    final langLabel = _formatLanguageLabel(_transcriptLanguage);
    final statusSubtitle = _isTranscriptEdited
        ? 'Edited manually · $langLabel'
        : 'Available · $langLabel';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transcript Header Row with chevron
        InkWell(
          onTap: () {
            setState(() {
              _isTranscriptExpanded = !_isTranscriptExpanded;
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.fileText,
                  size: 18,
                  color: colors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Transcript',
                        style: _headingStyle(
                          typography: typography,
                          baseSize: 16.0,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        statusSubtitle,
                        style: _captionStyle(
                          typography: typography,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _isTranscriptExpanded
                      ? PhosphorIconsRegular.caretUp
                      : PhosphorIconsRegular.caretDown,
                  size: 16,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Expanded transcript body container
        if (_isTranscriptExpanded) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isEditingTranscript) ...[
                  // Inline Text Editing Interface
                  TextField(
                    controller: _transcriptEditController,
                    maxLines: null,
                    autofocus: true,
                    style: _bodyStyle(
                      typography: typography,
                      baseSize: 16.0,
                      color: colors.textPrimary,
                      height: typography.lineHeight,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Edit transcript…',
                      hintStyle: _bodyStyle(
                        typography: typography,
                        baseSize: 16.0,
                        color: colors.textTertiary,
                        height: typography.lineHeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _transcriptEditController.text = _transcript ?? '';
                            _isEditingTranscript = false;
                          });
                        },
                        child: Text(
                          'Cancel',
                          style: _captionStyle(
                            typography: typography,
                            baseSize: 13.0,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saveEditedTranscript,
                        child: Text(
                          'Save',
                          style: _captionStyle(
                            typography: typography,
                            baseSize: 13.0,
                            color: colors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Read / Display Mode
                  SelectableText(
                    _transcript ?? '',
                    style: _bodyStyle(
                      typography: typography,
                      baseSize: 16.0,
                      color: colors.textPrimary,
                      height: typography.lineHeight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Footer Row: "Generated on device" / "Edited manually" + "Edit transcript"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isTranscriptEdited ? 'Edited manually' : 'Generated on device',
                        style: _captionStyle(
                          typography: typography,
                          color: colors.textTertiary,
                        ),
                      ),
                      if (!widget.isReadOnly)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _transcriptEditController.text = _transcript ?? '';
                              _isEditingTranscript = true;
                            });
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            child: Text(
                              'Edit transcript',
                              style: _captionStyle(
                                typography: typography,
                                color: colors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
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
