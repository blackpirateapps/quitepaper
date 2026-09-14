import 'package:flutter/foundation.dart';
import '../../../core/utils/date_formatter.dart';

@immutable
class Device {
  const Device({
    required this.id,
    required this.deviceId,
    this.deviceName,
    this.platform,
    this.model,
    this.osVersion,
    this.appVersion,
    required this.createdAt,
    required this.lastActiveAt,
    this.revokedAt,
  });

  final String id;
  final String deviceId;
  final String? deviceName;
  final String? platform;
  final String? model;
  final String? osVersion;
  final String? appVersion;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;

  bool isCurrent(String currentDeviceId) => deviceId == currentDeviceId;

  String get displayTitle {
    if (deviceName != null && deviceName!.trim().isNotEmpty) {
      return deviceName!.trim();
    }
    if (model != null && model!.trim().isNotEmpty) {
      return model!.trim();
    }
    if (platform != null && platform!.trim().isNotEmpty) {
      return '$platform Device';
    }
    return 'Quiet Paper Device';
  }

  String get displaySubtitle {
    final plat = platform != null && platform!.trim().isNotEmpty
        ? platform!.trim()
        : 'Device';
    final ver = appVersion != null && appVersion!.trim().isNotEmpty
        ? 'Quiet Paper ${appVersion!.trim()}'
        : 'Quiet Paper';
    return '$plat · $ver';
  }

  String get displayLastActive {
    final now = DateTime.now();
    final diff = now.difference(lastActiveAt);

    if (diff.inSeconds < 60) {
      return 'Active now';
    }
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes;
      return 'Active $m min${m == 1 ? '' : 's'} ago';
    }
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'Active $h hour${h == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      final d = diff.inDays;
      return 'Active $d day${d == 1 ? '' : 's'} ago';
    }
    return 'Active ${DateFormatter.formatRelative(lastActiveAt)}';
  }

  String get shortDeviceId {
    if (deviceId.length >= 4) {
      return '••••${deviceId.substring(deviceId.length - 4).toUpperCase()}';
    }
    return deviceId.toUpperCase();
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: (json['id'] ?? json['deviceId'] ?? '') as String,
      deviceId: (json['deviceId'] ?? json['id'] ?? '') as String,
      deviceName: json['deviceName'] as String?,
      platform: json['platform'] as String?,
      model: json['model'] as String?,
      osVersion: json['osVersion'] as String?,
      appVersion: json['appVersion'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.tryParse(json['lastActiveAt'] as String) ?? DateTime.now()
          : (json['lastSeenAt'] != null
              ? DateTime.tryParse(json['lastSeenAt'] as String) ?? DateTime.now()
              : DateTime.now()),
      revokedAt: json['revokedAt'] != null
          ? DateTime.tryParse(json['revokedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'model': model,
        'osVersion': osVersion,
        'appVersion': appVersion,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
        'revokedAt': revokedAt?.toIso8601String(),
      };

  Device copyWith({
    String? id,
    String? deviceId,
    String? deviceName,
    String? platform,
    String? model,
    String? osVersion,
    String? appVersion,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    DateTime? revokedAt,
  }) {
    return Device(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      model: model ?? this.model,
      osVersion: osVersion ?? this.osVersion,
      appVersion: appVersion ?? this.appVersion,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      revokedAt: revokedAt ?? this.revokedAt,
    );
  }
}

@immutable
class DeviceRegistrationRequest {
  const DeviceRegistrationRequest({
    required this.deviceId,
    this.deviceName,
    this.platform,
    this.model,
    this.osVersion,
    this.appVersion,
  });

  final String deviceId;
  final String? deviceName;
  final String? platform;
  final String? model;
  final String? osVersion;
  final String? appVersion;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        if (deviceName != null) 'deviceName': deviceName,
        if (platform != null) 'platform': platform,
        if (model != null) 'model': model,
        if (osVersion != null) 'osVersion': osVersion,
        if (appVersion != null) 'appVersion': appVersion,
      };
}
