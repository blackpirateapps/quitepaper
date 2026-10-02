import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quitepaper/core/version/app_version_provider.dart';

void main() {
  group('AppVersionInfo & Providers Unit Tests', () {
    test('formats displayVersion with buildNumber correctly', () {
      const info = AppVersionInfo(
        version: '1.6.0',
        buildNumber: '264',
      );

      expect(info.displayVersion, equals('Version 1.6.0 (264)'));
      expect(info.fullVersion, equals('1.6.0+264'));
    });

    test('omits buildNumber in displayVersion when buildNumber is 0 or empty', () {
      const infoZero = AppVersionInfo(
        version: '1.6.0',
        buildNumber: '0',
      );
      expect(infoZero.displayVersion, equals('Version 1.6.0'));
      expect(infoZero.fullVersion, equals('1.6.0'));

      const infoEmpty = AppVersionInfo(
        version: '1.6.0',
        buildNumber: '',
      );
      expect(infoEmpty.displayVersion, equals('Version 1.6.0'));
      expect(infoEmpty.fullVersion, equals('1.6.0'));
    });

    test('equality and hashCode work as expected', () {
      const a = AppVersionInfo(version: '1.6.0', buildNumber: '264');
      const b = AppVersionInfo(version: '1.6.0', buildNumber: '264');
      const c = AppVersionInfo(version: '1.6.0', buildNumber: '265');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('packageInfoProvider defaults to safe fallback in test environments', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final versionInfo = container.read(appVersionInfoProvider);
      expect(versionInfo.version, isNotEmpty);
      expect(versionInfo.displayVersion, startsWith('Version '));
    });

    test('appVersionInfoProvider dynamically maps custom packageInfoProvider override', () {
      final customPackageInfo = PackageInfo(
        appName: 'Quite Paper Custom',
        packageName: 'com.custom.app',
        version: '2.0.0',
        buildNumber: '582',
        buildSignature: '',
      );

      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWithValue(customPackageInfo),
        ],
      );
      addTearDown(container.dispose);

      final versionInfo = container.read(appVersionInfoProvider);
      expect(versionInfo.version, equals('2.0.0'));
      expect(versionInfo.buildNumber, equals('582'));
      expect(versionInfo.displayVersion, equals('Version 2.0.0 (582)'));
      expect(versionInfo.fullVersion, equals('2.0.0+582'));
    });
  });
}
