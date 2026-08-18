import 'package:flutter/foundation.dart';

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

@immutable
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    required this.publishedAt,
    required this.apkUrl,
    required this.apkFileName,
    required this.apkSizeBytes,
    required this.architecture,
    required this.htmlUrl,
  });

  final String version;
  final String tagName;
  final String title;
  final String releaseNotes;
  final DateTime publishedAt;
  final String apkUrl;
  final String apkFileName;
  final int apkSizeBytes;
  final String architecture;
  final String htmlUrl;

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  factory AppReleaseInfo.fromGitHubJson({
    required Map<String, dynamic> json,
    required List<String> deviceAbis,
  }) {
    final tagName = json['tag_name'] as String? ?? '';
    var version = tagName.startsWith('v') ? tagName.substring(1) : tagName;
    if (version.isEmpty) {
      version = json['name'] as String? ?? '1.0.0';
    }

    final title = json['name'] as String? ?? 'Quiet Paper v$version';
    final releaseNotes = json['body'] as String? ?? '';
    final publishedAtStr = json['published_at'] as String? ??
        json['created_at'] as String? ??
        DateTime.now().toIso8601String();
    final publishedAt = DateTime.tryParse(publishedAtStr) ?? DateTime.now();
    final htmlUrl = json['html_url'] as String? ??
        'https://github.com/blackpirateapps/quitepaper/releases';

    final rawAssets = json['assets'] as List? ?? [];
    final assets = rawAssets
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // Find the best APK asset matching device architecture
    var matchedUrl = '';
    var matchedFileName = '';
    var matchedSize = 0;
    var matchedArch = 'universal';

    // Normalized device ABIs (e.g., arm64-v8a -> arm64-v8a, arm64 -> arm64-v8a)
    final normalizedAbis = deviceAbis.map((abi) => abi.toLowerCase()).toList();

    // 1. Try exact device ABI matches in preference order
    for (final abi in normalizedAbis) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk') && name.contains(abi)) {
          matchedUrl = asset['browser_download_url'] as String? ?? '';
          matchedFileName = asset['name'] as String? ?? '';
          matchedSize = asset['size'] as int? ?? 0;
          matchedArch = abi;
          break;
        }
      }
      if (matchedUrl.isNotEmpty) break;
    }

    // 2. Fallback to universal APK
    if (matchedUrl.isEmpty) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk') && name.contains('universal')) {
          matchedUrl = asset['browser_download_url'] as String? ?? '';
          matchedFileName = asset['name'] as String? ?? '';
          matchedSize = asset['size'] as int? ?? 0;
          matchedArch = 'universal';
          break;
        }
      }
    }

    // 3. Fallback to any APK asset in release
    if (matchedUrl.isEmpty) {
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          matchedUrl = asset['browser_download_url'] as String? ?? '';
          matchedFileName = asset['name'] as String? ?? '';
          matchedSize = asset['size'] as int? ?? 0;
          matchedArch = 'apk';
          break;
        }
      }
    }

    return AppReleaseInfo(
      version: version,
      tagName: tagName,
      title: title,
      releaseNotes: releaseNotes,
      publishedAt: publishedAt,
      apkUrl: matchedUrl,
      apkFileName: matchedFileName,
      apkSizeBytes: matchedSize,
      architecture: matchedArch,
      htmlUrl: htmlUrl,
    );
  }
}

@immutable
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    required this.currentVersion,
    this.latestRelease,
    this.errorMessage,
  });

  final bool hasUpdate;
  final String currentVersion;
  final AppReleaseInfo? latestRelease;
  final String? errorMessage;
}

@immutable
class DownloadProgress {
  const DownloadProgress({
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.status = DownloadStatus.idle,
    this.filePath,
    this.errorMessage,
  });

  final int receivedBytes;
  final int totalBytes;
  final double progress;
  final DownloadStatus status;
  final String? filePath;
  final String? errorMessage;

  String get formattedProgress {
    if (totalBytes <= 0) {
      final mb = receivedBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(1)} MB';
    }
    final recMb = receivedBytes / (1024 * 1024);
    final totMb = totalBytes / (1024 * 1024);
    final pct = (progress * 100).clamp(0, 100).toInt();
    return '${recMb.toStringAsFixed(1)} / ${totMb.toStringAsFixed(1)} MB ($pct%)';
  }
}
