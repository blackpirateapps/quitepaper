import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/core/speech/infrastructure/speech_storage_service.dart';

void main() {
  late Directory tempDir;
  late Directory audioTempDir;
  late SpeechStorageService storageService;
  const descriptor = FutoEnglishSpeechModel();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech_storage_test_');
    audioTempDir =
        await Directory.systemTemp.createTemp('speech_audio_temp_test_');
    storageService = SpeechStorageService(
      baseDirectory: tempDir,
      temporaryDirectory: audioTempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await audioTempDir.exists()) {
      await audioTempDir.delete(recursive: true);
    }
  });

  test('generates expected model, part, and metadata file paths', () async {
    final modelFile = await storageService.getModelFile(descriptor);
    final partFile = await storageService.getPartFile(descriptor);
    final metadataFile = await storageService.getMetadataFile(descriptor.id);

    expect(modelFile.path, contains('futo_voice_input_english_39'));
    expect(modelFile.path, endsWith('voice-input-english-39.bin'));
    expect(partFile.path, endsWith('voice-input-english-39.bin.part'));
    expect(metadataFile.path, endsWith('metadata.json'));
  });

  test('isModelInstalled returns false when model binary is missing', () async {
    final installed = await storageService.isModelInstalled(descriptor);
    expect(installed, isFalse);
  });

  test('isModelInstalled returns false when file size does not match descriptor',
      () async {
    final modelFile = await storageService.getModelFile(descriptor);
    await modelFile.writeAsString('small fake content');

    final metadataFile = await storageService.getMetadataFile(descriptor.id);
    await metadataFile.writeAsString('{}');

    final installed = await storageService.isModelInstalled(descriptor);
    expect(installed, isFalse);
  });

  test(
      'isModelInstalled returns true when model binary size matches and metadata exists',
      () async {
    final modelFile = await storageService.getModelFile(descriptor);
    final dummyBytes = List<int>.filled(descriptor.sizeBytes, 0);
    await modelFile.writeAsBytes(dummyBytes);

    final metadata = SpeechModelMetadata(
      modelId: descriptor.id,
      version: descriptor.version,
      filename: descriptor.filename,
      sizeBytes: descriptor.sizeBytes,
      sha256: descriptor.expectedSha256,
      installedAt: DateTime.now(),
    );
    await storageService.saveMetadata(metadata);

    final installed = await storageService.isModelInstalled(descriptor);
    expect(installed, isTrue);

    final readMeta = await storageService.readMetadata(descriptor.id);
    expect(readMeta, isNotNull);
    expect(readMeta?.modelId, equals(descriptor.id));
    expect(readMeta?.version, equals('39'));
    expect(readMeta?.sizeBytes, equals(descriptor.sizeBytes));
  });

  test('deleteModel removes model directory and metadata', () async {
    final modelFile = await storageService.getModelFile(descriptor);
    await modelFile.writeAsString('content');

    final metadata = SpeechModelMetadata(
      modelId: descriptor.id,
      version: descriptor.version,
      filename: descriptor.filename,
      sizeBytes: 7,
      sha256: 'abc',
      installedAt: DateTime.now(),
    );
    await storageService.saveMetadata(metadata);

    expect(await modelFile.exists(), isTrue);

    await storageService.deleteModel(descriptor.id);

    final modelDir = await storageService.getModelDirectory(descriptor.id, create: false);
    expect(await modelDir.exists(), isFalse);
  });

  test('cleanOrphanedAudioFiles deletes speech_temp_*.wav files', () async {
    final file1 = File('${audioTempDir.path}/speech_temp_123.wav');
    final file2 = File('${audioTempDir.path}/speech_temp_456.wav');
    final otherFile = File('${audioTempDir.path}/unrelated_file.txt');

    await file1.writeAsString('audio');
    await file2.writeAsString('audio');
    await otherFile.writeAsString('other');

    await storageService.cleanOrphanedAudioFiles();

    expect(await file1.exists(), isFalse);
    expect(await file2.exists(), isFalse);
    expect(await otherFile.exists(), isTrue);
  });
}
