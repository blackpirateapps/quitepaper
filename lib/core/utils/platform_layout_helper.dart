import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized utility for platform layout and desktop environment detection.
class PlatformLayoutHelper {
  const PlatformLayoutHelper._();

  /// Whether the app is running on a native desktop platform (Linux, macOS, Windows).
  static bool get isDesktopPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }

  /// Whether the app is running on Linux specifically.
  static bool get isLinuxPlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.linux;
  }

  /// Whether the editor should adopt desktop ergonomics (top-docked toolbar,
  /// desktop mouse interactions, dropdown menus).
  ///
  /// Evaluates to true if running on a native desktop platform (Linux, macOS, Windows).
  static bool isDesktopEditor(BuildContext context) {
    return isDesktopPlatform;
  }
}
