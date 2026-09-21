import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/speech_model.dart';
import '../domain/speech_model_status.dart';
import '../infrastructure/speech_downloader.dart';
import '../infrastructure/speech_storage_service.dart';

class SpeechModelManager extends ChangeNotifier {
  SpeechModelManager({
    SpeechModelDescriptor? descriptor,
    required this.storageService,
    required this.downloader,
    bool autoCheck = true,
  }) : descriptor = descriptor ?? const FutoEnglishSpeechModel() {
    if (autoCheck) {
      unawaited(checkStatus());
    }
  }

  final SpeechModelDescriptor descriptor;
  final SpeechStorageService storageService;
  final SpeechDownloader downloader;

  SpeechModelStatus _status = SpeechModelStatus.initial;
  SpeechModelStatus get status => _status;

  bool _isDisposed = false;
  Completer<SpeechModelStatus>? _checkCompleter;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Check current model installation and verification state.
  Future<SpeechModelStatus> checkStatus() async {
    if (_isDisposed) return _status;
    if (_checkCompleter != null) {
      return _checkCompleter!.future;
    }

    final completer = Completer<SpeechModelStatus>();
    _checkCompleter = completer;

    if (_status.status != SpeechModelInstallationStatus.installed &&
        _status.status != SpeechModelInstallationStatus.downloading) {
      _status = _status.copyWith(status: SpeechModelInstallationStatus.checking);
      if (!_isDisposed) {
        notifyListeners();
      }
    }

    try {
      final isInstalled = await storageService.isModelInstalled(descriptor);
      if (isInstalled) {
        final file = await storageService.getModelFile(descriptor);
        _status = SpeechModelStatus(
          status: SpeechModelInstallationStatus.installed,
          progress: 1.0,
          downloadedBytes: descriptor.sizeBytes,
          totalBytes: descriptor.sizeBytes,
          modelPath: file.path,
        );
      } else {
        _status = const SpeechModelStatus(
          status: SpeechModelInstallationStatus.notInstalled,
        );
      }
    } catch (e) {
      _status = SpeechModelStatus(
        status: SpeechModelInstallationStatus.error,
        errorMessage: e.toString(),
      );
    } finally {
      if (!_isDisposed) {
        notifyListeners();
      }
      completer.complete(_status);
      _checkCompleter = null;
    }
    return _status;
  }

  /// Downloads and verifies the speech model on device.
  Future<bool> downloadModel() async {
    if (_status.status == SpeechModelInstallationStatus.downloading) {
      return false;
    }

    _status = const SpeechModelStatus(
      status: SpeechModelInstallationStatus.downloading,
      progress: 0.0,
      downloadedBytes: 0,
    );
    notifyListeners();

    try {
      final file = await downloader.downloadAndVerify(
        descriptor: descriptor,
        onProgress: ({
          required int downloadedBytes,
          required int totalBytes,
          required double progress,
        }) {
          _status = SpeechModelStatus(
            status: SpeechModelInstallationStatus.downloading,
            progress: progress,
            downloadedBytes: downloadedBytes,
            totalBytes: totalBytes,
          );
          notifyListeners();
        },
      );

      _status = SpeechModelStatus(
        status: SpeechModelInstallationStatus.installed,
        progress: 1.0,
        downloadedBytes: descriptor.sizeBytes,
        totalBytes: descriptor.sizeBytes,
        modelPath: file.path,
      );
      notifyListeners();
      return true;
    } on SpeechDownloadException catch (e) {
      _status = SpeechModelStatus(
        status: SpeechModelInstallationStatus.error,
        errorMessage: e.message,
      );
      notifyListeners();
      return false;
    } catch (e) {
      _status = SpeechModelStatus(
        status: SpeechModelInstallationStatus.error,
        errorMessage: e.toString(),
      );
      notifyListeners();
      return false;
    }
  }

  /// Cancels an active download.
  void cancelDownload() {
    downloader.cancel();
    _status = const SpeechModelStatus(
      status: SpeechModelInstallationStatus.notInstalled,
    );
    notifyListeners();
  }

  /// Deletes the installed model from disk.
  Future<void> deleteModel() async {
    await storageService.deleteModel(descriptor.id);
    _status = const SpeechModelStatus(
      status: SpeechModelInstallationStatus.notInstalled,
    );
    notifyListeners();
  }
}
