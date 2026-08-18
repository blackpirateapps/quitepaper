import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/update/update_models.dart';
import 'package:quitepaper/core/update/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('UpdateService Version Comparison Tests', () {
    test('Correctly identifies newer semver versions', () {
      expect(UpdateService.isNewerVersion('1.3.0', '1.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.3.0', '1.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.1', '1.2.0'), isTrue);
      expect(UpdateService.isNewerVersion('1.2.0+4', '1.2.0+3'), isFalse);
      expect(UpdateService.isNewerVersion('1.2.0', '1.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.1.9', '1.2.0'), isFalse);
      expect(UpdateService.isNewerVersion('0.9.0', '1.0.0'), isFalse);
    });
  });

  group('UpdateService 30-Day Snooze Tests', () {
    test('Initially not snoozed', () {
      final service = UpdateService(
        sharedPreferences: prefs,
        currentVersion: '1.2.0',
      );

      expect(service.isSnoozed('1.3.0'), isFalse);
    });

    test('Snoozing for 30 days suppresses prompts for that version but not newer versions', () async {
      final service = UpdateService(
        sharedPreferences: prefs,
        currentVersion: '1.2.0',
      );

      await service.snoozeUpdate('1.3.0', days: 30);

      // Snoozed version returns true
      expect(service.isSnoozed('1.3.0'), isTrue);

      // Newer unexpected version is not snoozed
      expect(service.isSnoozed('1.4.0'), isFalse);

      // Clearing snooze restores prompting
      await service.clearSnooze();
      expect(service.isSnoozed('1.3.0'), isFalse);
    });
  });

  group('AppReleaseInfo Architecture Matching Tests', () {
    final mockReleaseJson = {
      'tag_name': 'v1.3.0',
      'name': 'Quiet Paper v1.3.0',
      'body': '### Features\n- Added update engine\n- Performance improvements',
      'published_at': '2026-08-18T12:00:00Z',
      'html_url': 'https://github.com/blackpirateapps/quitepaper/releases/tag/v1.3.0',
      'assets': [
        {
          'name': 'quiet-paper-1.3.0-arm64-v8a.apk',
          'size': 22521725,
          'browser_download_url':
              'https://github.com/blackpirateapps/quitepaper/releases/download/v1.3.0/quiet-paper-1.3.0-arm64-v8a.apk',
        },
        {
          'name': 'quiet-paper-1.3.0-armeabi-v7a.apk',
          'size': 20127431,
          'browser_download_url':
              'https://github.com/blackpirateapps/quitepaper/releases/download/v1.3.0/quiet-paper-1.3.0-armeabi-v7a.apk',
        },
        {
          'name': 'quiet-paper-1.3.0-x86_64.apk',
          'size': 23973454,
          'browser_download_url':
              'https://github.com/blackpirateapps/quitepaper/releases/download/v1.3.0/quiet-paper-1.3.0-x86_64.apk',
        },
        {
          'name': 'quiet-paper-1.3.0-universal.apk',
          'size': 63230284,
          'browser_download_url':
              'https://github.com/blackpirateapps/quitepaper/releases/download/v1.3.0/quiet-paper-1.3.0-universal.apk',
        },
      ],
    };

    test('Matches arm64-v8a APK when device supports arm64-v8a', () {
      final info = AppReleaseInfo.fromGitHubJson(
        json: mockReleaseJson,
        deviceAbis: ['arm64-v8a', 'armeabi-v7a'],
      );

      expect(info.version, '1.3.0');
      expect(info.apkFileName, 'quiet-paper-1.3.0-arm64-v8a.apk');
      expect(info.architecture, 'arm64-v8a');
      expect(info.formattedSize, '21.5 MB');
    });

    test('Matches armeabi-v7a APK when device is 32-bit ARM', () {
      final info = AppReleaseInfo.fromGitHubJson(
        json: mockReleaseJson,
        deviceAbis: ['armeabi-v7a', 'armeabi'],
      );

      expect(info.apkFileName, 'quiet-paper-1.3.0-armeabi-v7a.apk');
      expect(info.architecture, 'armeabi-v7a');
    });

    test('Matches x86_64 APK when device is x86_64 emulator or Chromebook', () {
      final info = AppReleaseInfo.fromGitHubJson(
        json: mockReleaseJson,
        deviceAbis: ['x86_64', 'x86'],
      );

      expect(info.apkFileName, 'quiet-paper-1.3.0-x86_64.apk');
      expect(info.architecture, 'x86_64');
    });

    test('Falls back to universal APK if ABI does not match specific binary', () {
      final info = AppReleaseInfo.fromGitHubJson(
        json: mockReleaseJson,
        deviceAbis: ['mips', 'unknown-arch'],
      );

      expect(info.apkFileName, 'quiet-paper-1.3.0-universal.apk');
      expect(info.architecture, 'universal');
    });
  });

  group('UpdateService GitHub API Integration Tests', () {
    test('Returns update when newer version is returned by GitHub', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/releases/latest')) {
          return http.Response(
            jsonEncode({
              'tag_name': 'v1.4.0',
              'name': 'Quiet Paper v1.4.0',
              'body': 'Changelog: Major improvements',
              'published_at': '2026-08-18T12:00:00Z',
              'assets': [
                {
                  'name': 'quiet-paper-1.4.0-arm64-v8a.apk',
                  'size': 22521725,
                  'browser_download_url':
                      'https://example.com/quiet-paper-1.4.0-arm64-v8a.apk',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = UpdateService(
        sharedPreferences: prefs,
        httpClient: mockClient,
        currentVersion: '1.2.0',
      );

      final result = await service.checkForUpdate(overrideAbis: ['arm64-v8a']);

      expect(result.hasUpdate, isTrue);
      expect(result.currentVersion, '1.2.0');
      expect(result.latestRelease, isNotNull);
      expect(result.latestRelease!.version, '1.4.0');
      expect(result.latestRelease!.apkFileName, 'quiet-paper-1.4.0-arm64-v8a.apk');
    });

    test('Returns hasUpdate false when on latest version', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'tag_name': 'v1.2.0',
            'name': 'Quiet Paper v1.2.0',
            'body': 'Current release',
            'assets': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = UpdateService(
        sharedPreferences: prefs,
        httpClient: mockClient,
        currentVersion: '1.2.0',
      );

      final result = await service.checkForUpdate(overrideAbis: ['arm64-v8a']);

      expect(result.hasUpdate, isFalse);
      expect(result.latestRelease, isNotNull);
    });
  });
}
