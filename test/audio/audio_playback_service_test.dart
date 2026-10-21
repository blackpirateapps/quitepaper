import 'dart:async';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_playback_service.dart';

class FakeAudioPlayer extends Fake implements AudioPlayer {
  Source? currentSource;
  @override
  PlayerState state = PlayerState.stopped;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _durationController =
      StreamController<Duration>.broadcast();
  final StreamController<void> _completeController =
      StreamController<void>.broadcast();

  @override
  Stream<PlayerState> get onPlayerStateChanged => _stateController.stream;

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration> get onDurationChanged => _durationController.stream;

  @override
  Stream<void> get onPlayerComplete => _completeController.stream;

  @override
  Future<void> play(
    Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    currentSource = source;
    state = PlayerState.playing;
    _stateController.add(state);
  }

  @override
  Future<void> pause() async {
    state = PlayerState.paused;
    _stateController.add(state);
  }

  @override
  Future<void> resume() async {
    state = PlayerState.playing;
    _stateController.add(state);
  }

  @override
  Future<void> seek(Duration position) async {
    currentPosition = position;
    _positionController.add(position);
  }

  @override
  Future<void> stop() async {
    state = PlayerState.stopped;
    _stateController.add(state);
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
    await _completeController.close();
  }

  void emitDuration(Duration duration) {
    totalDuration = duration;
    _durationController.add(duration);
  }

  void emitPosition(Duration position) {
    currentPosition = position;
    _positionController.add(position);
  }

  void emitComplete() {
    state = PlayerState.completed;
    _completeController.add(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioPlayer fakePlayer;
  late AudioPlaybackService service;

  setUp(() {
    fakePlayer = FakeAudioPlayer();
    service = AudioPlaybackService(player: fakePlayer);
  });

  tearDown(() async {
    await service.dispose();
  });

  group('AudioPlaybackService Tests', () {
    test('initial snapshot is stopped with zero duration and position', () {
      expect(service.snapshot.isPlaying, isFalse);
      expect(service.snapshot.isPaused, isFalse);
      expect(service.snapshot.isStopped, isTrue);
      expect(service.snapshot.activeAttachmentId, isNull);
      expect(service.snapshot.position, equals(Duration.zero));
      expect(service.snapshot.duration, equals(Duration.zero));
      expect(service.snapshot.progressFraction, equals(0.0));
    });

    test('playBytes initiates playback and updates snapshot', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(
        attachmentId: 'att-1',
        bytes: fakeBytes,
        mimeType: 'audio/mp4',
        initialDuration: const Duration(seconds: 45),
      );

      expect(service.snapshot.activeAttachmentId, equals('att-1'));
      expect(service.snapshot.isPlaying, isTrue);
      expect(service.snapshot.duration, equals(const Duration(seconds: 45)));
      expect(fakePlayer.currentSource, isA<BytesSource>());
    });

    test('pause and resume toggle player state', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(attachmentId: 'att-1', bytes: fakeBytes);

      await service.pause();
      expect(service.snapshot.isPaused, isTrue);
      expect(service.snapshot.isPlaying, isFalse);

      await service.resume();
      expect(service.snapshot.isPlaying, isTrue);
      expect(service.snapshot.isPaused, isFalse);
    });

    test('seek updates position and progress fraction', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(
        attachmentId: 'att-1',
        bytes: fakeBytes,
        initialDuration: const Duration(seconds: 100),
      );

      await service.seek(const Duration(seconds: 25));
      expect(service.snapshot.position, equals(const Duration(seconds: 25)));
      expect(service.snapshot.progressFraction, closeTo(0.25, 0.001));
    });

    test('single active player policy: starting second clip stops first clip', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(attachmentId: 'clip-1', bytes: fakeBytes);
      expect(service.snapshot.activeAttachmentId, equals('clip-1'));

      await service.playBytes(attachmentId: 'clip-2', bytes: fakeBytes);
      expect(service.snapshot.activeAttachmentId, equals('clip-2'));
      expect(service.snapshot.isPlaying, isTrue);
    });

    test('stop clears active attachment and resets state to stopped', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(attachmentId: 'att-1', bytes: fakeBytes);

      await service.stop();
      expect(service.snapshot.activeAttachmentId, isNull);
      expect(service.snapshot.isStopped, isTrue);
      expect(service.snapshot.position, equals(Duration.zero));
    });

    test('onPlayerComplete resets position and marks state completed', () async {
      final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);
      await service.playBytes(
        attachmentId: 'att-1',
        bytes: fakeBytes,
        initialDuration: const Duration(seconds: 30),
      );

      fakePlayer.emitComplete();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.snapshot.playerState, equals(PlayerState.completed));
      expect(service.snapshot.position, equals(Duration.zero));
    });
  });
}
