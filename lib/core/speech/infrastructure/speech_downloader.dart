import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import '../domain/speech_model.dart';
import 'speech_storage_service.dart';

typedef ProgressCallback = void Function({
  required int downloadedBytes,
  required int totalBytes,
  required double progress,
});

class SpeechDownloadException implements Exception {
  SpeechDownloadException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SpeechDownloader {
  SpeechDownloader({
    this.httpClient,
    required this.storageService,
  });

  final http.Client? httpClient;
  final SpeechStorageService storageService;

  http.Client? _activeClient;
  bool _isCancelled = false;

  /// Download and atomically install the specified speech model.
  Future<File> downloadAndVerify({
    required SpeechModelDescriptor descriptor,
    ProgressCallback? onProgress,
  }) async {
    _isCancelled = false;
    final client = httpClient ?? http.Client();
    _activeClient = client;

    final partFile = await storageService.getPartFile(descriptor);
    final destinationFile = await storageService.getModelFile(descriptor);

    // Ensure clean state before download
    if (await partFile.exists()) {
      try {
        await partFile.delete();
      } catch (_) {}
    }

    IOSink? sink;
    try {
      final uri = Uri.parse(descriptor.downloadUrl);
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw SpeechDownloadException(
          "The speech model couldn't be downloaded.\n\nCheck your connection and try again.",
        );
      }

      final totalBytes = response.contentLength ?? descriptor.sizeBytes;
      int downloadedBytes = 0;

      sink = partFile.openWrite();
      final Completer<void> completer = Completer<void>();

      final subscription = response.stream.listen(
        (chunk) {
          if (_isCancelled) {
            return;
          }
          sink?.add(chunk);
          downloadedBytes += chunk.length;

          final progress = totalBytes > 0
              ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          onProgress?.call(
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
            progress: progress,
          );
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(
              SpeechDownloadException(
                'The download was interrupted.\n\nPlease try again.',
              ),
            );
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        cancelOnError: true,
      );

      await completer.future;
      await subscription.cancel();

      if (_isCancelled) {
        await sink.flush();
        await sink.close();
        sink = null;
        if (await partFile.exists()) {
          await partFile.delete();
        }
        throw SpeechDownloadException('Download cancelled.');
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Verify file size
      final actualSize = await partFile.length();
      if (actualSize != descriptor.sizeBytes) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
        throw SpeechDownloadException(
          'The speech model could not be verified.\n\nPlease download it again.',
        );
      }

      // Verify SHA-256 Checksum
      final actualSha256 = await _calculateFileSha256(partFile);
      if (actualSha256.toLowerCase() != descriptor.expectedSha256.toLowerCase()) {
        if (await partFile.exists()) {
          await partFile.delete();
        }
        throw SpeechDownloadException(
          'The speech model could not be verified.\n\nPlease download it again.',
        );
      }

      // Atomic rename to destination path
      if (await destinationFile.exists()) {
        await destinationFile.delete();
      }
      await partFile.rename(destinationFile.path);

      // Save verified metadata
      final metadata = SpeechModelMetadata(
        modelId: descriptor.id,
        version: descriptor.version,
        filename: descriptor.filename,
        sizeBytes: actualSize,
        sha256: actualSha256,
        installedAt: DateTime.now(),
      );
      await storageService.saveMetadata(metadata);

      return destinationFile;
    } on SocketException {
      if (sink != null) {
        await sink.close();
      }
      if (await partFile.exists()) {
        await partFile.delete();
      }
      throw SpeechDownloadException(
        "The speech model couldn't be downloaded.\n\nCheck your connection and try again.",
      );
    } on http.ClientException {
      if (sink != null) {
        await sink.close();
      }
      if (await partFile.exists()) {
        await partFile.delete();
      }
      throw SpeechDownloadException(
        'The download was interrupted.\n\nPlease try again.',
      );
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      if (await partFile.exists()) {
        await partFile.delete();
      }
      if (e is SpeechDownloadException) {
        rethrow;
      }
      throw SpeechDownloadException(
        'The download was interrupted.\n\nPlease try again.',
      );
    } finally {
      if (httpClient == null) {
        client.close();
      }
      _activeClient = null;
    }
  }

  /// Cancels any active download operation.
  void cancel() {
    _isCancelled = true;
    _activeClient?.close();
  }

  Future<String> _calculateFileSha256(File file) async {
    final stream = file.openRead();
    final digest = await crypto.sha256.bind(stream).first;
    return digest.toString();
  }
}
