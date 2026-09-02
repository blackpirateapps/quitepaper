/// Lifecycle states of the speech model on device.
enum SpeechModelInstallationStatus {
  notInstalled,
  downloading,
  verifying,
  installed,
  error,
}

/// Rich status representation of model installation.
class SpeechModelStatus {
  const SpeechModelStatus({
    required this.status,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
    this.modelPath,
  });

  final SpeechModelInstallationStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;
  final String? modelPath;

  bool get isInstalled => status == SpeechModelInstallationStatus.installed;
  bool get isDownloading => status == SpeechModelInstallationStatus.downloading;
  bool get isVerifying => status == SpeechModelInstallationStatus.verifying;
  bool get hasError => status == SpeechModelInstallationStatus.error;

  SpeechModelStatus copyWith({
    SpeechModelInstallationStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
    String? modelPath,
  }) {
    return SpeechModelStatus(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      modelPath: modelPath ?? this.modelPath,
    );
  }

  static const SpeechModelStatus initial = SpeechModelStatus(
    status: SpeechModelInstallationStatus.notInstalled,
  );
}
