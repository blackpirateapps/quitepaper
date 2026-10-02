import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Represents parsed, dynamic application version and build metadata.
class AppVersionInfo {
  const AppVersionInfo({
    required this.version,
    required this.buildNumber,
    this.appName = 'Quite Paper',
    this.packageName = 'com.blackpirate.quitepaper',
  });

  final String version;
  final String buildNumber;
  final String appName;
  final String packageName;

  /// User-facing display string, e.g. "Version 1.6.0 (264)" or "Version 1.6.0".
  String get displayVersion {
    if (buildNumber.isEmpty || buildNumber == '0') {
      return 'Version $version';
    }
    return 'Version $version ($buildNumber)';
  }

  /// Full SemVer string with build metadata, e.g. "1.6.0+264".
  String get fullVersion {
    if (buildNumber.isEmpty || buildNumber == '0') {
      return version;
    }
    return '$version+$buildNumber';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppVersionInfo &&
          runtimeType == other.runtimeType &&
          version == other.version &&
          buildNumber == other.buildNumber;

  @override
  int get hashCode => Object.hash(version, buildNumber);

  @override
  String toString() => fullVersion;
}

/// Fallback PackageInfo instance for tests and environments without platform channels.
final packageInfoProvider = Provider<PackageInfo>((ref) {
  return PackageInfo(
    appName: 'Quite Paper',
    packageName: 'com.blackpirate.quitepaper',
    version: '1.6.0',
    buildNumber: '0',
    buildSignature: '',
  );
});

/// Exposes the app's dynamic version information.
final appVersionInfoProvider = Provider<AppVersionInfo>((ref) {
  final packageInfo = ref.watch(packageInfoProvider);
  return AppVersionInfo(
    version: packageInfo.version.isNotEmpty ? packageInfo.version : '1.6.0',
    buildNumber: packageInfo.buildNumber.isNotEmpty ? packageInfo.buildNumber : '0',
    appName: packageInfo.appName.isNotEmpty ? packageInfo.appName : 'Quite Paper',
    packageName: packageInfo.packageName.isNotEmpty ? packageInfo.packageName : 'com.blackpirate.quitepaper',
  );
});
