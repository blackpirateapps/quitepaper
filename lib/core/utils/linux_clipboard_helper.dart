import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pasteboard/pasteboard.dart';

/// Function signature for executing system processes, enabling mock injection in tests.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  dynamic stdoutEncoding,
});

/// Utility to retrieve clipboard images and file paths on Linux desktop environments,
/// handling Wayland (`wl-paste`), X11 (`xclip`), and GTK clipboard mechanics.
class LinuxClipboardHelper {
  const LinuxClipboardHelper({
    this.processRunner,
  });

  final ProcessRunner? processRunner;

  Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments, {
    dynamic stdoutEncoding,
  }) {
    if (processRunner != null) {
      return processRunner!(executable, arguments, stdoutEncoding: stdoutEncoding);
    }
    return Process.run(executable, arguments, stdoutEncoding: stdoutEncoding);
  }

  /// Retrieves raw image bytes from the clipboard.
  ///
  /// First queries [Pasteboard.image]. If running on Linux and [Pasteboard.image]
  /// returns null or empty, attempts native command line extraction via `wl-paste`
  /// (Wayland) or `xclip` (X11).
  Future<Uint8List?> getClipboardImage() async {
    // 1. Try Pasteboard native GTK channel
    try {
      final pasteboardBytes = await Pasteboard.image;
      if (pasteboardBytes != null && pasteboardBytes.isNotEmpty) {
        return pasteboardBytes;
      }
    } catch (e) {
      debugPrint('[LinuxClipboardHelper] Pasteboard.image failed: $e');
    }

    // 2. Linux fallback for Wayland / X11
    if (!kIsWeb && Platform.isLinux) {
      return _getLinuxNativeImage();
    }

    return null;
  }

  /// Retrieves copied file paths from the clipboard.
  ///
  /// First queries [Pasteboard.files]. If running on Linux and empty, attempts
  /// to parse `text/uri-list` from `wl-paste` (Wayland) or `xclip` (X11).
  Future<List<String>> getClipboardFiles() async {
    // 1. Try Pasteboard native GTK channel
    try {
      final pasteboardFiles = await Pasteboard.files();
      if (pasteboardFiles.isNotEmpty) {
        return pasteboardFiles;
      }
    } catch (e) {
      debugPrint('[LinuxClipboardHelper] Pasteboard.files failed: $e');
    }

    // 2. Linux fallback for Wayland / X11
    if (!kIsWeb && Platform.isLinux) {
      return _getLinuxNativeFiles();
    }

    return const [];
  }

  Future<Uint8List?> _getLinuxNativeImage() async {
    // Check Wayland wl-paste first if running in Wayland session or wl-paste exists
    final isWayland = Platform.environment.containsKey('WAYLAND_DISPLAY') ||
        Platform.environment['XDG_SESSION_TYPE'] == 'wayland';

    if (isWayland) {
      final waylandPng = await _runCommand(
        'wl-paste',
        ['--type', 'image/png'],
        binary: true,
      );
      if (waylandPng != null && waylandPng.isNotEmpty) {
        return waylandPng;
      }

      final waylandJpeg = await _runCommand(
        'wl-paste',
        ['--type', 'image/jpeg'],
        binary: true,
      );
      if (waylandJpeg != null && waylandJpeg.isNotEmpty) {
        return waylandJpeg;
      }
    }

    // X11 / Xwayland fallback via xclip
    final xclipPng = await _runCommand(
      'xclip',
      ['-selection', 'clipboard', '-target', 'image/png', '-out'],
      binary: true,
    );
    if (xclipPng != null && xclipPng.isNotEmpty) {
      return xclipPng;
    }

    final xclipJpeg = await _runCommand(
      'xclip',
      ['-selection', 'clipboard', '-target', 'image/jpeg', '-out'],
      binary: true,
    );
    if (xclipJpeg != null && xclipJpeg.isNotEmpty) {
      return xclipJpeg;
    }

    // If wl-paste was not attempted yet (e.g. session type unstated), try it as a last resort
    if (!isWayland) {
      final wlPng = await _runCommand(
        'wl-paste',
        ['--type', 'image/png'],
        binary: true,
      );
      if (wlPng != null && wlPng.isNotEmpty) {
        return wlPng;
      }
    }

    return null;
  }

  Future<List<String>> _getLinuxNativeFiles() async {
    String? uriListText;

    final isWayland = Platform.environment.containsKey('WAYLAND_DISPLAY') ||
        Platform.environment['XDG_SESSION_TYPE'] == 'wayland';

    if (isWayland) {
      final res = await _runCommandText(
        'wl-paste',
        ['--type', 'text/uri-list'],
      );
      if (res != null && res.trim().isNotEmpty) {
        uriListText = res;
      }
    }

    if (uriListText == null) {
      final res = await _runCommandText(
        'xclip',
        ['-selection', 'clipboard', '-target', 'text/uri-list', '-out'],
      );
      if (res != null && res.trim().isNotEmpty) {
        uriListText = res;
      }
    }

    if (uriListText == null || uriListText.trim().isEmpty) {
      return const [];
    }

    final resolvedPaths = <String>[];
    final lines = const LineSplitter().convert(uriListText);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (trimmed.startsWith('file://')) {
        try {
          final uri = Uri.parse(trimmed);
          resolvedPaths.add(uri.toFilePath());
        } catch (_) {}
      } else if (trimmed.startsWith('/') && File(trimmed).existsSync()) {
        resolvedPaths.add(trimmed);
      }
    }

    return resolvedPaths;
  }

  Future<Uint8List?> _runCommand(
    String executable,
    List<String> arguments, {
    required bool binary,
  }) async {
    try {
      final result = await _runProcess(
        executable,
        arguments,
        stdoutEncoding: binary ? null : systemEncoding,
      ).timeout(const Duration(milliseconds: 1500));

      if (result.exitCode == 0 && result.stdout != null) {
        if (binary && result.stdout is List<int>) {
          final bytes = Uint8List.fromList(result.stdout as List<int>);
          if (bytes.isNotEmpty) return bytes;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _runCommandText(
    String executable,
    List<String> arguments,
  ) async {
    try {
      final result = await _runProcess(
        executable,
        arguments,
        stdoutEncoding: systemEncoding,
      ).timeout(const Duration(milliseconds: 1500));

      if (result.exitCode == 0 && result.stdout != null) {
        final text = result.stdout.toString();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }
}
