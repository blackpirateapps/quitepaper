import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Resolves Linux desktop system appearance and brightness preference
/// across KDE Plasma, GNOME, Sway, Hyprland, and other FreeDesktop environments.
class LinuxThemeResolver {
  LinuxThemeResolver({ProcessRunner? processRunner})
      : _processRunner = processRunner ?? Process.run;

  final ProcessRunner _processRunner;

  /// Resolves the current system brightness on Linux.
  /// Returns `Brightness.dark`, `Brightness.light`, or `null` if unable to determine.
  Future<Brightness?> resolveBrightness() async {
    if (!kIsWeb && !Platform.isLinux) {
      return null;
    }

    try {
      // 1. Try FreeDesktop Settings Portal via gdbus (KDE Plasma 5/6, GNOME 42+, modern Wayland)
      final portalBrightness = await _readPortalColorScheme();
      if (portalBrightness != null) {
        return portalBrightness;
      }

      // 2. Fallback to GSettings (GNOME, Cinnamon, MATE)
      final gsettingsBrightness = await _readGSettingsColorScheme();
      if (gsettingsBrightness != null) {
        return gsettingsBrightness;
      }

      // 3. Fallback to KDE configuration file (~/.config/kdeglobals)
      final kdeBrightness = await _readKdeGlobalsColorScheme();
      if (kdeBrightness != null) {
        return kdeBrightness;
      }
    } catch (e) {
      debugPrint('[LinuxThemeResolver] Error querying desktop appearance: $e');
    }

    return null;
  }

  Future<Brightness?> _readPortalColorScheme() async {
    try {
      final result = await _processRunner(
        'gdbus',
        [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.portal.Desktop',
          '--object-path',
          '/org/freedesktop/portal/desktop',
          '--method',
          'org.freedesktop.portal.Settings.Read',
          'org.freedesktop.appearance',
          'color-scheme',
        ],
      );

      if (result.exitCode == 0) {
        final stdout = result.stdout.toString();
        // Portal returns '(<<uint32 1>>,)':
        // 0 = no preference, 1 = prefer-dark, 2 = prefer-light
        if (stdout.contains('uint32 1')) {
          return Brightness.dark;
        } else if (stdout.contains('uint32 2') || stdout.contains('uint32 0')) {
          return Brightness.light;
        }
      }
    } catch (_) {
      // gdbus not installed or portal unavailable
    }
    return null;
  }

  Future<Brightness?> _readGSettingsColorScheme() async {
    try {
      final result = await _processRunner(
        'gsettings',
        ['get', 'org.gnome.desktop.interface', 'color-scheme'],
      );

      if (result.exitCode == 0) {
        final stdout = result.stdout.toString().trim();
        if (stdout.contains('prefer-dark')) {
          return Brightness.dark;
        } else if (stdout.contains('default') || stdout.contains('prefer-light')) {
          return Brightness.light;
        }
      }
    } catch (_) {
      // gsettings not installed
    }
    return null;
  }

  Future<Brightness?> _readKdeGlobalsColorScheme() async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return null;
      final file = File('$home/.config/kdeglobals');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.startsWith('ColorScheme=')) {
            final value = trimmed.substring('ColorScheme='.length).toLowerCase();
            if (value.contains('dark')) {
              return Brightness.dark;
            } else if (value.contains('light') || value.contains('breeze')) {
              return Brightness.light;
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }
}
