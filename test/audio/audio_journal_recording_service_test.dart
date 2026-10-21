import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:quitepaper/core/audio/domain/audio_journal_models.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_journal_recording_service.dart';

class FakeAudioRecorder extends Fake implements AudioRecorder {
  bool permission = true;
  bool isStarted = false;
  bool pausedState = false;
  String? recordedPath;
  RecordConfig? lastConfig;

  final StreamController<Amplitude> _amplitudeController =
      StreamController<Amplitude>.broadcast();

  @override
  Future<bool> hasPermission({bool request = true}) async => permission;

  @override
  Future<bool> isEncoderSupported(AudioEncoder encoder) async => true;

  @override
  Future<bool> isRecording() async => isStarted;

  @override
  Future<bool> isPaused() async => pausedState;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    isStarted = true;
    pausedState = false;
    lastConfig = config;
    recordedPath = path;
    final file = File(path);
    if (!file.existsSync()) {
      file.parent.createSync(recursive: true);
      // Write > 100 bytes so file validation in stopRecording succeeds
      file.writeAsBytesSync(List<int>.filled(256, 0x42));
    }
  }

  @override
  Future<void> pause() async {
    pausedState = true;
  }

  @override
  Future<void> resume() async {
    pausedState = false;
  }

  @override
  Future<String?> stop() async {
    isStarted = false;
    pausedState = false;
    return recordedPath;
  }

  @override
  Future<void> cancel() async {
    isStarted = false;
    pausedState = false;
  }

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
  }

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) {
    return _amplitudeController.stream;
  }

  void emitAmplitude(double current, double max) {
    _amplitudeController.add(Amplitude(current: current, max: max));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeAudioRecorder fakeRecorder;
  late AudioJournalRecordingService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('audio_journal_test_');
    fakeRecorder = FakeAudioRecorder();
    service = AudioJournalRecordingService(
      recorder: fakeRecorder,
      customTempDirectory: tempDir,
      config: const AudioJournalConfig(
        maxDuration: Duration(seconds: 5),
      ),
    );
  });

  tearDown(() async {
    await service.dispose();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('AudioJournalRecordingService Tests', () {
    test('initial state is idle with zero elapsed duration', () {
      expect(service.session.status, equals(AudioJournalStatus.idle));
      expect(service.session.elapsedDuration, equals(Duration.zero));
      expect(service.session.workingFile, isNull);
    });

    test('hasPermission reflects recorder permission state', () async {
      fakeRecorder.permission = true;
      expect(await service.hasPermission(), isTrue);

      fakeRecorder.permission = false;
      expect(await service.hasPermission(), isFalse);
    });

    test('startRecording initializes session and creates file', () async {
      final file = await service.startRecording(noteId: 'note-123');

      expect(service.session.status, equals(AudioJournalStatus.recording));
      expect(service.session.activeNoteId, equals('note-123'));
      expect(service.session.workingFile, isNotNull);
      expect(file.existsSync(), isTrue);
      expect(fakeRecorder.isStarted, isTrue);
    });

    test('cannot start a second recording while one is already active', () async {
      await service.startRecording(noteId: 'note-1');

      expect(
        () => service.startRecording(noteId: 'note-2'),
        throwsA(isA<StateError>()),
      );
    });

    test('pause and resume updates session status and maintains duration', () async {
      await service.startRecording();
      expect(service.session.status, equals(AudioJournalStatus.recording));

      await service.pauseRecording();
      expect(service.session.status, equals(AudioJournalStatus.paused));
      expect(fakeRecorder.pausedState, isTrue);

      await service.resumeRecording();
      expect(service.session.status, equals(AudioJournalStatus.recording));
      expect(fakeRecorder.pausedState, isFalse);
    });

    test('stopRecording finalizes session and stops recorder', () async {
      await service.startRecording(noteId: 'note-finish');
      final finishedFile = await service.stopRecording();

      expect(service.session.status, equals(AudioJournalStatus.completed));
      expect(service.session.activeNoteId, equals('note-finish'));
      expect(finishedFile, isNotNull);
      expect(finishedFile!.existsSync(), isTrue);
      expect(fakeRecorder.isStarted, isFalse);
    });

    test('stopRecording returns null if not active', () async {
      final result = await service.stopRecording();
      expect(result, isNull);
    });

    test('cancelRecording deletes temporary file and resets session to cancelled', () async {
      final file = await service.startRecording();
      expect(file.existsSync(), isTrue);

      await service.cancelRecording();

      expect(service.session.status, equals(AudioJournalStatus.cancelled));
      expect(file.existsSync(), isFalse);
      expect(fakeRecorder.isStarted, isFalse);
    });

    test('reset changes session back to idle', () async {
      await service.startRecording();
      await service.cancelRecording();
      expect(service.session.status, equals(AudioJournalStatus.cancelled));

      service.reset();
      expect(service.session.status, equals(AudioJournalStatus.idle));
    });

    test('cleanupStaleRecordings removes files older than maxAge', () async {
      final audioDir = await service.getAudioTempDirectory();
      final oldFile = File('${audioDir.path}/old_recording.m4a');
      await oldFile.writeAsString('old audio');
      final oldTime = DateTime.now().subtract(const Duration(hours: 48));
      await oldFile.setLastModified(oldTime);

      final freshFile = File('${audioDir.path}/fresh_recording.m4a');
      await freshFile.writeAsString('fresh audio');

      expect(oldFile.existsSync(), isTrue);
      expect(freshFile.existsSync(), isTrue);

      await service.cleanupStaleRecordings(maxAge: const Duration(hours: 24));

      expect(oldFile.existsSync(), isFalse);
      expect(freshFile.existsSync(), isTrue);
    });

    test('live amplitude updates are aggregated in session liveAmplitudes', () async {
      await service.startRecording();

      fakeRecorder.emitAmplitude(-10.0, 0.0);
      fakeRecorder.emitAmplitude(-25.0, 0.0);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(service.session.liveAmplitudes, isNotEmpty);
    });
  });
}
