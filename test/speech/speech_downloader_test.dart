import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_downloader.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';

class TestSpeechModelDescriptor implements SpeechModelDescriptor {
  const TestSpeechModelDescriptor({
    required this.id,
    required this.name,
    required this.language,
    required this.languageCode,
    required this.sizeBytes,
    required this.version,
    required this.filename,
    required this.downloadUrl,
    required this.expectedSha256,
  });

  @override
  final String id;
  @override
  final String name;
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
}

void main() {
  late Directory tempDir;
  late SpeechStorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech_download_test_');
    storageService = SpeechStorageService(baseDirectory: tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('successfully downloads, verifies sha256 and installs model atomically',
      () async {
    const testContent = 'Hello FUTO Voice Model Speech Test Binary Content';
    final testBytes = utf8.encode(testContent);
    final expectedSha = crypto.sha256.convert(testBytes).toString();

    final descriptor = TestSpeechModelDescriptor(
      id: 'test_model_1',
      name: 'Test Model',
      language: 'English',
      languageCode: 'en',
      sizeBytes: testBytes.length,
      version: '1',
      filename: 'test-model.bin',
      downloadUrl: 'https://example.com/test-model.bin',
      expectedSha256: expectedSha,
    );

    final mockClient = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(testBytes),
        200,
        contentLength: testBytes.length,
      );
    });

    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    int progressReports = 0;
    final file = await downloader.downloadAndVerify(
      descriptor: descriptor,
      onProgress: ({
        required int downloadedBytes,
        required int totalBytes,
        required double progress,
      }) {
        progressReports++;
        expect(downloadedBytes, equals(testBytes.length));
        expect(totalBytes, equals(testBytes.length));
        expect(progress, equals(1.0));
      },
    );

    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), equals(testBytes));
    expect(progressReports, greaterThan(0));

    // Ensure .part file was removed upon atomic installation
    final partFile = await storageService.getPartFile(descriptor);
    expect(await partFile.exists(), isFalse);

    // Verify metadata was saved
    final metadata = await storageService.readMetadata(descriptor.id);
    expect(metadata, isNotNull);
    expect(metadata?.sha256, equals(expectedSha));
    expect(metadata?.sizeBytes, equals(testBytes.length));
  });

  test('detects SHA-256 checksum mismatch and deletes partial file', () async {
    const testContent = 'Actual downloaded content';
    final testBytes = utf8.encode(testContent);

    final descriptor = TestSpeechModelDescriptor(
      id: 'test_model_corrupt',
      name: 'Corrupt Model',
      language: 'English',
      languageCode: 'en',
      sizeBytes: testBytes.length,
      version: '1',
      filename: 'corrupt-model.bin',
      downloadUrl: 'https://example.com/corrupt-model.bin',
      expectedSha256: '0000000000000000000000000000000000000000000000000000000000000000',
    );

    final mockClient = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(testBytes),
        200,
        contentLength: testBytes.length,
      );
    });

    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    expect(
      () => downloader.downloadAndVerify(descriptor: descriptor),
      throwsA(isA<SpeechDownloadException>()),
    );

    final partFile = await storageService.getPartFile(descriptor);
    expect(await partFile.exists(), isFalse);

    final destFile = await storageService.getModelFile(descriptor);
    expect(await destFile.exists(), isFalse);
  });

  test('handles HTTP error status codes gracefully', () async {
    final descriptor = const FutoEnglishSpeechModel();

    final mockClient = MockClient.streaming((request, bodyStream) async {
      return http.StreamedResponse(
        Stream.value(utf8.encode('Not found')),
        404,
      );
    });

    final downloader = SpeechDownloader(
      httpClient: mockClient,
      storageService: storageService,
    );

    expect(
      () => downloader.downloadAndVerify(descriptor: descriptor),
      throwsA(isA<SpeechDownloadException>()),
    );
  });
}
