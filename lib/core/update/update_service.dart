import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'update_models.dart';

class UpdateService {
  UpdateService({
    required this.sharedPreferences,
    http.Client? httpClient,
    this.currentVersion = '1.2.0',
    this.githubRepo = 'blackpirateapps/quitepaper',
  }) : _httpClient = httpClient ?? http.Client();

  final SharedPreferences sharedPreferences;
  final http.Client _httpClient;
  final String currentVersion;
  final String githubRepo;

  static const _channel = MethodChannel('com.blackpiratex.quietpaper/updater');
  static const _kSnoozedUntilKey = 'update_snoozed_until';
  static const _kSnoozedVersionKey = 'update_snoozed_version';

  /// Get device supported ABIs from Android platform
  Future<List<String>> getDeviceAbis() async {
    try {
      final abis = await _channel.invokeListMethod<String>('getDeviceAbis');
      return abis ?? ['arm64-v8a', 'universal'];
    } catch (_) {
      // Fallback for tests or non-Android
      return ['arm64-v8a', 'universal'];
    }
  }

  /// Check if the app has permission to install unknown apps (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    try {
      final canInstall =
          await _channel.invokeMethod<bool>('canRequestPackageInstalls');
      return canInstall ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Open system settings to allow install from unknown sources for this app
  Future<bool> openInstallPermissionSettings() async {
    try {
      final res =
          await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return res ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Launch the system installer for the downloaded APK
  Future<bool> installApk(String filePath) async {
    try {
      final res = await _channel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Failed to trigger APK install: $e');
      return false;
    }
  }

  /// Compares semantic versions (e.g. "1.3.0" vs "1.2.0")
  static bool isNewerVersion(String latestVersion, String currentVersion) {
    try {
      final cleanLatest = latestVersion.replaceAll(RegExp(r'^[vV]'), '').trim();
      final cleanCurrent =
          currentVersion.replaceAll(RegExp(r'^[vV]'), '').trim();

      // Split build metadata (+3) if present
      final latestCore = cleanLatest.split('+').first.split('-').first;
      final currentCore = cleanCurrent.split('+').first.split('-').first;

      final latestParts =
          latestCore.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final currentParts =
          currentCore.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      for (var i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether update prompts are currently snoozed for this version
  bool isSnoozed(String targetVersion) {
    final snoozedUntil = sharedPreferences.getInt(_kSnoozedUntilKey) ?? 0;
    final snoozedVersion =
        sharedPreferences.getString(_kSnoozedVersionKey) ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;

    return now < snoozedUntil && snoozedVersion == targetVersion;
  }

  /// Snooze update prompts for the specified number of days (default: 30 days)
  Future<void> snoozeUpdate(String targetVersion, {int days = 30}) async {
    final until =
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    await sharedPreferences.setInt(_kSnoozedUntilKey, until);
    await sharedPreferences.setString(_kSnoozedVersionKey, targetVersion);
  }

  /// Clears active snooze
  Future<void> clearSnooze() async {
    await sharedPreferences.remove(_kSnoozedUntilKey);
    await sharedPreferences.remove(_kSnoozedVersionKey);
  }

  /// Queries GitHub Releases API for the latest release
  Future<UpdateCheckResult> checkForUpdate({
    List<String>? overrideAbis,
  }) async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$githubRepo/releases/latest');
      final response = await _httpClient.get(
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'QuietPaper-App/$currentVersion',
        },
      );

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          errorMessage:
              'Failed to fetch latest release (${response.statusCode})',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final abis = overrideAbis ?? await getDeviceAbis();
      final release =
          AppReleaseInfo.fromGitHubJson(json: json, deviceAbis: abis);

      final hasUpdate = isNewerVersion(release.version, currentVersion);

      return UpdateCheckResult(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestRelease: release,
      );
    } catch (e) {
      return UpdateCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        errorMessage: e.toString(),
      );
    }
  }

  /// Downloads the specified release APK with progress tracking
  Stream<DownloadProgress> downloadApk(AppReleaseInfo release) async* {
    if (release.apkUrl.isEmpty) {
      yield const DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: 'No APK download URL found for this device architecture.',
      );
      return;
    }

    yield const DownloadProgress(
      progress: 0.0,
      status: DownloadStatus.downloading,
    );

    try {
      final request = http.Request('GET', Uri.parse(release.apkUrl));
      request.headers['User-Agent'] = 'QuietPaper-App/$currentVersion';
      final response = await _httpClient.send(request);

      if (response.statusCode != 200) {
        yield DownloadProgress(
          status: DownloadStatus.failed,
          errorMessage:
              'Server responded with HTTP ${response.statusCode} while downloading update.',
        );
        return;
      }

      final totalBytes = response.contentLength ?? release.apkSizeBytes;
      final tempDir = await getTemporaryDirectory();
      final sanitizedName = release.apkFileName.isNotEmpty
          ? release.apkFileName
          : 'quiet-paper-${release.version}.apk';
      final saveFile = File('${tempDir.path}/$sanitizedName');

      if (await saveFile.exists()) {
        await saveFile.delete();
      }

      final sink = saveFile.openWrite();
      var receivedBytes = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;

        yield DownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: progress,
          status: DownloadStatus.downloading,
        );
      }

      await sink.flush();
      await sink.close();

      yield DownloadProgress(
        receivedBytes: receivedBytes,
        totalBytes: totalBytes,
        progress: 1.0,
        status: DownloadStatus.completed,
        filePath: saveFile.path,
      );
    } catch (e) {
      yield DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: 'Download failed: $e',
      );
    }
  }
}
