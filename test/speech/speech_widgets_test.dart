import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/speech/application/speech_model_manager.dart';
import 'package:quitepaper/core/speech/application/speech_provider.dart';
import 'package:quitepaper/core/speech/application/speech_recognition_service.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/domain/speech_recognition_engine.dart';
import 'package:quitepaper/core/speech/domain/speech_session_state.dart';
import 'package:quitepaper/core/speech/infrastructure/audio_recorder_service.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_downloader.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';
import 'package:quitepaper/core/speech/presentation/speech_download_dialog.dart';
import 'package:quitepaper/core/speech/presentation/speech_recording_bar.dart';
import 'package:quitepaper/core/speech/presentation/speech_settings_view.dart';
import 'package:quitepaper/features/editor/presentation/widgets/formatting_toolbar.dart';

class StubEngine implements SpeechRecognitionEngine {
  @override
  bool get isLoaded => true;

  @override
  Future<void> initialize({required String modelPath}) async {}

  @override
  Future<String> transcribe(
      {required String audioPath,
      String lang = 'en',
      void Function(int percent)? onProgress}) async {
    return 'Transcribed speech text';
  }

  @override
  Future<void> dispose() async {}
}

class StubRecorder extends AudioRecorderService {
  StubRecorder({required super.storageService});

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<File> startRecording({void Function()? onMaxDurationReached}) async =>
      File('/tmp/test.wav');
  @override
  Future<File?> stopRecording() async => File('/tmp/test.wav');
}

void main() {
  late Directory tempDir;
  late SpeechStorageService storage;
  late SpeechModelManager manager;
  late SpeechRecognitionService speechService;
  const descriptor = FutoEnglishSpeechModel();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech_widgets_test_');
    storage = SpeechStorageService(baseDirectory: tempDir);
    final downloader = SpeechDownloader(storageService: storage);
    manager = SpeechModelManager(
      descriptor: descriptor,
      storageService: storage,
      downloader: downloader,
    );
    speechService = SpeechRecognitionService(
      modelManager: manager,
      recorderService: StubRecorder(storageService: storage),
      recognitionEngine: StubEngine(),
      storageService: storage,
    );
  });

  tearDown(() async {
    speechService.dispose();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        speechStorageServiceProvider.overrideWithValue(storage),
        speechModelManagerProvider.overrideWith((ref) => manager),
        speechRecognitionServiceProvider.overrideWith((ref) => speechService),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('SpeechDownloadDialog renders model name and MB size',
      (tester) async {
    await tester.pumpWidget(
      createTestWidget(const SpeechDownloadDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline Speech Recognition'), findsOneWidget);
    expect(find.text('English (Fast)'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('SpeechDownloadDialog with Multilingual model renders auto-detect copy',
      (tester) async {
    await tester.pumpWidget(
      createTestWidget(const SpeechDownloadDialog(
        modelDescriptor: SpeechModels.multilingual244,
      )),
    );
    await tester.pumpAndSettle();

    expect(find.text('Offline Speech Recognition'), findsOneWidget);
    expect(find.text('Multilingual (Auto-Detect)'), findsOneWidget);
    expect(find.textContaining('automatically detect and transcribe your voice in multiple languages'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets('SpeechRecordingBar renders listening state and responds to stop',
      (tester) async {
    bool stopPressed = false;
    bool cancelPressed = false;

    const session = SpeechSession(
      state: SpeechSessionState.recording,
      recordingDuration: Duration(seconds: 8),
    );

    await tester.pumpWidget(
      createTestWidget(
        SpeechRecordingBar(
          session: session,
          onStop: () => stopPressed = true,
          onCancel: () => cancelPressed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('00:08'), findsOneWidget);
    expect(find.text('Tap to stop recording'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Tap to stop recording'));
    await tester.pump();
    expect(stopPressed, isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelPressed, isTrue);
  });

  testWidgets('SpeechRecordingBar renders transcribing state', (tester) async {
    const session = SpeechSession(
      state: SpeechSessionState.transcribing,
    );

    await tester.pumpWidget(
      createTestWidget(
        SpeechRecordingBar(
          session: session,
          onStop: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Transcribing on device…'), findsOneWidget);
  });

  testWidgets('SpeechRecordingBar renders preparation states with cancel',
      (tester) async {
    bool cancelPressed = false;
    const session = SpeechSession(
      state: SpeechSessionState.loadingEngine,
    );

    await tester.pumpWidget(
      createTestWidget(
        SpeechRecordingBar(
          session: session,
          onStop: () {},
          onCancel: () => cancelPressed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Loading speech model…'), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);

    await tester.tap(find.byTooltip('Cancel'));
    await tester.pump();
    expect(cancelPressed, isTrue);
  });

  testWidgets('SpeechRecordingBar renders error state with dismissal',
      (tester) async {
    bool errorDismissed = false;
    const session = SpeechSession(
      state: SpeechSessionState.error,
      errorMessage: 'Microphone access denied.',
    );

    await tester.pumpWidget(
      createTestWidget(
        SpeechRecordingBar(
          session: session,
          onStop: () {},
          onCancel: () {},
          onErrorDismiss: () => errorDismissed = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Microphone access denied.'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(errorDismissed, isTrue);
  });

  testWidgets('SpeechSettingsView renders all 4 models and sections', (tester) async {
    await tester.pumpWidget(
      createTestWidget(const SpeechSettingsView()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Speech Recognition'), findsOneWidget);
    expect(find.text('OFFLINE TRANSCRIPTION'), findsOneWidget);
    expect(find.text('ENGLISH VOICE MODELS'), findsOneWidget);
    expect(find.text('English (Fast)'), findsOneWidget);
    expect(find.text('English (Balanced)'), findsOneWidget);
    expect(find.text('English (High Accuracy)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Multilingual (Auto-Detect)'),
      100,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('MULTILINGUAL VOICE MODEL'), findsOneWidget);
    expect(find.text('Multilingual (Auto-Detect)'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('FormattingToolbar renders Dictate button and fires onDictatePressed',
      (tester) async {
    bool dictateTapped = false;
    final controller = TextEditingController(text: 'Test note');

    await tester.pumpWidget(
      createTestWidget(
        FormattingToolbar(
          controller: controller,
          onTagPressed: () {},
          onDictatePressed: () => dictateTapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dictateFinder = find.byTooltip('Dictate');
    expect(dictateFinder, findsOneWidget);

    await tester.tap(dictateFinder);
    await tester.pump();
    expect(dictateTapped, isTrue);
  });
}
