import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// State snapshot of the application-wide audio player.
@immutable
class AudioPlaybackSnapshot {
  const AudioPlaybackSnapshot({
    this.activeAttachmentId,
    this.playerState = PlayerState.stopped,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
  });

  /// The attachment ID currently loaded or playing.
  final String? activeAttachmentId;

  /// Current playback status (stopped, playing, paused, completed).
  final PlayerState playerState;

  /// Current elapsed position within the media.
  final Duration position;

  /// Total duration of the media.
  final Duration duration;

  /// Error message if playback failed.
  final String? errorMessage;

  bool get isPlaying => playerState == PlayerState.playing;
  bool get isPaused => playerState == PlayerState.paused;
  bool get isStopped => playerState == PlayerState.stopped || playerState == PlayerState.completed;

  /// Progress fraction from 0.0 to 1.0.
  double get progressFraction {
    if (duration == Duration.zero || duration.inMilliseconds <= 0) return 0.0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  AudioPlaybackSnapshot copyWith({
    String? activeAttachmentId,
    PlayerState? playerState,
    Duration? position,
    Duration? duration,
    String? errorMessage,
  }) {
    return AudioPlaybackSnapshot(
      activeAttachmentId: activeAttachmentId ?? this.activeAttachmentId,
      playerState: playerState ?? this.playerState,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPlaybackSnapshot &&
          runtimeType == other.runtimeType &&
          activeAttachmentId == other.activeAttachmentId &&
          playerState == other.playerState &&
          position == other.position &&
          duration == other.duration &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        activeAttachmentId,
        playerState,
        position,
        duration,
        errorMessage,
      );
}

/// Central audio playback coordinator enforcing a single-active-player policy across Quiet Paper.
class AudioPlaybackService {
  AudioPlaybackService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _initListeners();
  }

  final AudioPlayer _player;
  static const _uuid = Uuid();

  AudioPlaybackSnapshot _snapshot = const AudioPlaybackSnapshot();
  AudioPlaybackSnapshot get snapshot => _snapshot;

  final _snapshotController = StreamController<AudioPlaybackSnapshot>.broadcast();
  Stream<AudioPlaybackSnapshot> get snapshotStream => _snapshotController.stream;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<void>? _completeSub;

  File? _currentTempPlaybackFile;
  bool _isDisposed = false;

  void _emit(AudioPlaybackSnapshot updated) {
    if (_isDisposed) return;
    _snapshot = updated;
    _snapshotController.add(_snapshot);
  }

  void _initListeners() {
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _emit(_snapshot.copyWith(playerState: state));
    });

    _positionSub = _player.onPositionChanged.listen((pos) {
      _emit(_snapshot.copyWith(position: pos));
    });

    _durationSub = _player.onDurationChanged.listen((dur) {
      if (dur > Duration.zero) {
        _emit(_snapshot.copyWith(duration: dur));
      }
    });

    _completeSub = _player.onPlayerComplete.listen((_) {
      _emit(_snapshot.copyWith(
        playerState: PlayerState.completed,
        position: Duration.zero,
      ));
    });
  }

  /// Plays the given decrypted [bytes] for [attachmentId].
  ///
  /// Automatically stops any other clip that is currently playing.
  Future<void> playBytes({
    required String attachmentId,
    required Uint8List bytes,
    String? mimeType,
    Duration? initialDuration,
  }) async {
    // If this clip is currently paused, simply resume
    if (_snapshot.activeAttachmentId == attachmentId && _snapshot.isPaused) {
      await resume();
      return;
    }

    // Stop current playback cleanly
    await stop();

    _emit(AudioPlaybackSnapshot(
      activeAttachmentId: attachmentId,
      playerState: PlayerState.playing,
      position: Duration.zero,
      duration: initialDuration ?? Duration.zero,
    ));

    try {
      // First attempt direct in-memory BytesSource
      try {
        await _player.play(BytesSource(bytes, mimeType: mimeType));
      } catch (e) {
        // Fallback for native platform players requiring a file path
        debugPrint('[AudioPlayback] Direct BytesSource error ($e); trying ephemeral temp file...');
        final tempDir = await getTemporaryDirectory();
        final ext = (mimeType?.contains('wav') == true) ? 'wav' : 'm4a';
        final tempFile = File(p.join(tempDir.path, 'playback_temp_${_uuid.v4()}.$ext'));
        await tempFile.writeAsBytes(bytes);
        _currentTempPlaybackFile = tempFile;
        await _player.play(DeviceFileSource(tempFile.path));
      }
    } catch (e) {
      debugPrint('[AudioPlayback] Playback failed: $e');
      _emit(_snapshot.copyWith(
        playerState: PlayerState.stopped,
        errorMessage: 'Could not play audio: $e',
      ));
      await _cleanupTempFile();
    }
  }

  /// Pauses active playback.
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (_) {}
    _emit(_snapshot.copyWith(playerState: PlayerState.paused));
  }

  /// Resumes paused playback.
  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (_) {}
    _emit(_snapshot.copyWith(playerState: PlayerState.playing));
  }

  /// Seeks to [targetPosition].
  Future<void> seek(Duration targetPosition) async {
    try {
      await _player.seek(targetPosition);
    } catch (_) {}
    _emit(_snapshot.copyWith(position: targetPosition));
  }

  /// Stops current playback and clears active session.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    await _cleanupTempFile();
    _emit(const AudioPlaybackSnapshot(
      activeAttachmentId: null,
      playerState: PlayerState.stopped,
      position: Duration.zero,
      duration: Duration.zero,
    ));
  }

  Future<void> _cleanupTempFile() async {
    if (_currentTempPlaybackFile != null) {
      try {
        if (await _currentTempPlaybackFile!.exists()) {
          await _currentTempPlaybackFile!.delete();
        }
      } catch (_) {}
      _currentTempPlaybackFile = null;
    }
  }

  /// Disposes playback resources.
  Future<void> dispose() async {
    _isDisposed = true;
    await stop();
    await _stateSub?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _completeSub?.cancel();
    await _player.dispose();
    await _snapshotController.close();
  }
}
