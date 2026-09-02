import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/speech/application/speech_model_manager.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/domain/speech_model_status.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_downloader.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';

class MockDescriptor implements SpeechModelDescriptor {
  const MockDescriptor({
    required this.id,
    required this.name,
    this.subtitle = '',
    required this.language,
    required this.languageCode,
    required this.sizeBytes,
    required this.version,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSha256,
    this.isMultilingual = false,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String subtitle;
  @override
  final String language;
  @override
  final String languageCode;
  @override
  final int sizeBytes;
  @override
  final String version;
  @override
  final String filename;
  @override
  final String downloadUrl;
  @override
  final String expectedSha256;
  @override
  final bool isMultilingual;
}

void main() {
  late Directory tempDir;
  late SpeechStorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('model_mgr_test_');
    storageService = SpeechStorageService(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('initial status is notInstalled and checkStatus updates accurately',
      () async {
    final descriptor = const FutoEnglishSpeechModel();
    final mockClient = MockClient((_) async => http.Response('', 200));
    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    final manager = SpeechModelManager(
      descriptor: descriptor,
      storageService: storageService,
      downloader: downloader,
    );

    final status = await manager.checkStatus();
    expect(status.status, equals(SpeechModelInstallationStatus.notInstalled));
    expect(status.isInstalled, isFalse);
  });

  test('successful downloadModel transitions to installed and notifies listeners',
      () async {
    const content = 'model binary payload data';
    final bytes = utf8.encode(content);
    final sha = crypto.sha256.convert(bytes).toString();

    final descriptor = MockDescriptor(
      id: 'mgr_test_model',
      name: 'Manager Model',
      language: 'English',
      languageCode: 'en',
      sizeBytes: bytes.length,
      version: '1',
      filename: 'mgr-model.bin',
      downloadUrl: 'https://example.com/mgr-model.bin',
      expectedSha256: sha,
    );

    final mockClient = MockClient.streaming((req, stream) async {
      return http.StreamedResponse(Stream.value(bytes), 200,
          contentLength: bytes.length);
    });

    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    final manager = SpeechModelManager(
      descriptor: descriptor,
      storageService: storageService,
      downloader: downloader,
    );

    final states = <SpeechModelInstallationStatus>[];
    manager.addListener(() {
      states.add(manager.status.status);
    });

    final success = await manager.downloadModel();
    expect(success, isTrue);
    expect(manager.status.isInstalled, isTrue);
    expect(states, contains(SpeechModelInstallationStatus.downloading));
    expect(states.last, equals(SpeechModelInstallationStatus.installed));
  });

  test('deleteModel removes model and resets status to notInstalled', () async {
    const content = 'model content';
    final bytes = utf8.encode(content);
    final sha = crypto.sha256.convert(bytes).toString();

    final descriptor = MockDescriptor(
      id: 'delete_model',
      name: 'Delete Model',
      language: 'English',
      languageCode: 'en',
      sizeBytes: bytes.length,
      version: '1',
      filename: 'delete-model.bin',
      downloadUrl: 'https://example.com/delete-model.bin',
      expectedSha256: sha,
    );

    final mockClient = MockClient.streaming((req, stream) async {
      return http.StreamedResponse(Stream.value(bytes), 200,
          contentLength: bytes.length);
    });

    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    final manager = SpeechModelManager(
      descriptor: descriptor,
      storageService: storageService,
      downloader: downloader,
    );

    await manager.downloadModel();
    expect(manager.status.isInstalled, isTrue);

    await manager.deleteModel();
    expect(manager.status.status,
        equals(SpeechModelInstallationStatus.notInstalled));
  });
}
