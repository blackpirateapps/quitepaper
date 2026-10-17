import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Centralized utility for platform layout and desktop environment detection.
class PlatformLayoutHelper {
  const PlatformLayoutHelper._();

  /// Whether the environment is a native desktop platform (Linux, macOS, Windows).
  ///
  /// If [context] is provided, checks `Theme.of(context).platform` to allow
  /// testing and runtime overrides; otherwise checks `defaultTargetPlatform`.
  static bool isDesktop([BuildContext? context]) {
    if (kIsWeb) return false;
    final platform = context != null ? Theme.of(context).platform : defaultTargetPlatform;
    return platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows;
  }

  /// Whether the app is running on a native desktop platform (Linux, macOS, Windows).
  static bool get isDesktopPlatform => isDesktop();

  /// Whether the app is running on Linux specifically.
  static bool isLinux([BuildContext? context]) {
    if (kIsWeb) return false;
    final platform = context != null ? Theme.of(context).platform : defaultTargetPlatform;
    return platform == TargetPlatform.linux;
  }

  /// Whether the app is running on Linux specifically.
  static bool get isLinuxPlatform => isLinux();

  /// Whether the editor should adopt desktop ergonomics (top-docked toolbar,
  /// desktop mouse interactions, dropdown menus).
  ///
  /// Evaluates to true if running on a native desktop platform (Linux, macOS, Windows).
  static bool isDesktopEditor(BuildContext context) {
    return isDesktop(context);
  }
}
