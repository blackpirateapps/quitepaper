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
  }) : descriptor = descriptor ?? const FutoEnglishSpeechModel();

  final SpeechModelDescriptor descriptor;
  final SpeechStorageService storageService;
  final SpeechDownloader downloader;

  SpeechModelStatus _status = SpeechModelStatus.initial;
  SpeechModelStatus get status => _status;

  bool _isChecking = false;

  /// Check current model installation and verification state.
  Future<SpeechModelStatus> checkStatus() async {
    if (_isChecking) return _status;
    _isChecking = true;

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
      _isChecking = false;
      notifyListeners();
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
