import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/devices/domain/device.dart';
import '../../features/notes/application/notes_provider.dart';
import '../database/app_database.dart';

final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  final db = ref.watch(databaseProvider);
  return DeviceInfoService(database: db);
});

final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(deviceInfoServiceProvider);
  return service.getStableDeviceId();
});

class DeviceInfoService {
  DeviceInfoService({
    required this.database,
    DeviceInfoPlugin? deviceInfoPlugin,
    this.appVersion = '1.5.8',
  }) : _deviceInfo = deviceInfoPlugin ?? DeviceInfoPlugin();

  final AppDatabase database;
  final DeviceInfoPlugin _deviceInfo;
  final String appVersion;

  /// Retrieves or generates the persistent, stable device ID for this installation.
  Future<String> getStableDeviceId() async {
    return database.getOrCreateDeviceId();
  }

  /// Collects real platform and hardware metadata for this device installation.
  Future<DeviceRegistrationRequest> getCurrentDeviceMetadata() async {
    final deviceId = await getStableDeviceId();

    String platform = 'Unknown';
    String? model;
    String? deviceName;
    String? osVersion;

    try {
      if (kIsWeb) {
        platform = 'Web';
        final web = await _deviceInfo.webBrowserInfo;
        deviceName = web.browserName.name;
        model = web.userAgent;
        osVersion = web.platform;
      } else if (Platform.isAndroid) {
        platform = 'Android';
        final android = await _deviceInfo.androidInfo;
        model = android.model.isNotEmpty ? android.model : android.device;
        deviceName = android.model.isNotEmpty ? android.model : 'Android Device';
        osVersion = 'Android ${android.version.release} (API ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        platform = 'iOS';
        final ios = await _deviceInfo.iosInfo;
        model = ios.utsname.machine.isNotEmpty ? ios.utsname.machine : ios.model;
        deviceName = ios.name.isNotEmpty ? ios.name : 'iPhone/iPad';
        osVersion = 'iOS ${ios.systemVersion}';
      } else if (Platform.isMacOS) {
        platform = 'macOS';
        final mac = await _deviceInfo.macOsInfo;
        model = mac.model.isNotEmpty ? mac.model : 'Mac';
        deviceName = mac.computerName.isNotEmpty ? mac.computerName : 'MacBook';
        osVersion = 'macOS ${mac.osRelease}';
      } else if (Platform.isLinux) {
        platform = 'Linux';
        final linux = await _deviceInfo.linuxInfo;
        model = linux.prettyName.isNotEmpty ? linux.prettyName : 'Linux PC';
        deviceName = linux.name.isNotEmpty ? linux.name : 'Linux Device';
        osVersion = linux.versionId ?? linux.version ?? 'Linux';
      } else if (Platform.isWindows) {
        platform = 'Windows';
        final win = await _deviceInfo.windowsInfo;
        model = win.productName.isNotEmpty ? win.productName : 'Windows PC';
        deviceName = win.computerName.isNotEmpty ? win.computerName : 'Windows Device';
        osVersion = 'Windows ${win.displayVersion}';
      }
    } catch (_) {
      // Meaningful fallback without crashing
      platform = Platform.operatingSystem;
      osVersion = Platform.operatingSystemVersion;
      deviceName = '$platform Device';
    }

    return DeviceRegistrationRequest(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      model: model,
      osVersion: osVersion,
      appVersion: appVersion,
    );
  }
}
