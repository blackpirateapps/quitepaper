import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

abstract final class StoragePermissionHelper {
  /// Checks and requests necessary storage/all-files permissions on Android.
  /// Returns true if permission is granted, or on non-Android platforms.
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      // 1. On Android 11+ (API 30+), check All Files Access (Manage External Storage)
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) {
        return true;
      }

      // Request Manage External Storage
      final manageResult = await Permission.manageExternalStorage.request();
      if (manageResult.isGranted) {
        return true;
      }

      // 2. Also check standard storage permission (for Android 10 and below)
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isGranted) {
        return true;
      }

      final storageResult = await Permission.storage.request();
      return storageResult.isGranted;
    } catch (_) {
      // Fallback if permission_handler encounters platform differences
      return true;
    }
  }

  /// Checks whether storage permission is currently granted.
  static Future<bool> hasStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final manageStatus = await Permission.manageExternalStorage.status;
      if (manageStatus.isGranted) return true;

      final storageStatus = await Permission.storage.status;
      return storageStatus.isGranted;
    } catch (_) {
      return true;
    }
  }
}
