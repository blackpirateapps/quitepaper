import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/speech_model.dart';

class SpeechStorageService {
  SpeechStorageService({
    Directory? baseDirectory,
    Directory? temporaryDirectory,
  })  : _customBaseDir = baseDirectory,
        _customTempDir = temporaryDirectory;

  final Directory? _customBaseDir;
  final Directory? _customTempDir;

  static const String _speechModelSubdir = 'models/speech';
  static const String _metadataFileName = 'metadata.json';
  static const String _tempPartExtension = '.part';

  /// Root directory for all speech models.
  Future<Directory> getSpeechModelsDirectory({bool create = true}) async {
    if (_customBaseDir != null) {
      final dir = Directory(p.join(_customBaseDir.path, _speechModelSubdir));
      if (create && !await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _speechModelSubdir));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Directory for a specific model ID.
  Future<Directory> getModelDirectory(String modelId, {bool create = true}) async {
    final base = await getSpeechModelsDirectory(create: create);
    final dir = Directory(p.join(base.path, modelId));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Final installed file path for the model binary.
  Future<File> getModelFile(SpeechModelDescriptor descriptor, {bool createDirectory = true}) async {
    final dir = await getModelDirectory(descriptor.id, create: createDirectory);
    return File(p.join(dir.path, descriptor.filename));
  }

  /// Temporary download `.part` file path.
  Future<File> getPartFile(SpeechModelDescriptor descriptor, {bool createDirectory = true}) async {
    final dir = await getModelDirectory(descriptor.id, create: createDirectory);
    return File(p.join(dir.path, '${descriptor.filename}$_tempPartExtension'));
  }

  /// Path to model metadata.json.
  Future<File> getMetadataFile(String modelId, {bool createDirectory = true}) async {
    final dir = await getModelDirectory(modelId, create: createDirectory);
    return File(p.join(dir.path, _metadataFileName));
  }

  /// Temporary directory for ephemeral audio recordings.
  Future<Directory> getAudioTempDirectory({bool create = true}) async {
    if (_customTempDir != null) {
      if (create && !await _customTempDir.exists()) {
        await _customTempDir.create(recursive: true);
      }
      return _customTempDir;
    }
    final tempDir = await getTemporaryDirectory();
    final dir = Directory(p.join(tempDir.path, 'speech_audio'));
    if (create && !await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Checks whether a model is fully installed and verified on disk.
  Future<bool> isModelInstalled(SpeechModelDescriptor descriptor) async {
    final file = await getModelFile(descriptor, createDirectory: false);
    if (!await file.exists()) return false;

    final length = await file.length();
    if (length != descriptor.sizeBytes) return false;

    final metadataFile = await getMetadataFile(descriptor.id, createDirectory: false);
    if (!await metadataFile.exists()) return false;

    return true;
  }

  /// Reads stored metadata for a model if present.
  Future<SpeechModelMetadata?> readMetadata(String modelId) async {
    try {
      final file = await getMetadataFile(modelId, createDirectory: false);
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      final map = json.decode(raw) as Map<String, dynamic>;
      return SpeechModelMetadata.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Saves metadata to disk.
  Future<void> saveMetadata(SpeechModelMetadata metadata) async {
    final file = await getMetadataFile(metadata.modelId, createDirectory: true);
    await file.writeAsString(json.encode(metadata.toJson()));
  }

  /// Deletes the model binary, metadata, and any partial files for this model.
  Future<void> deleteModel(String modelId) async {
    try {
      final base = await getSpeechModelsDirectory(create: false);
      final dir = Directory(p.join(base.path, modelId));
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  /// Cleans up any leftover temporary files or orphaned audio recordings.
  Future<void> cleanOrphanedAudioFiles() async {
    try {
      final tempDir = await getAudioTempDirectory(create: false);
      if (await tempDir.exists()) {
        final entities = tempDir.listSync();
        for (final entity in entities) {
          if (entity is File && p.basename(entity.path).startsWith('speech_temp_')) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}
