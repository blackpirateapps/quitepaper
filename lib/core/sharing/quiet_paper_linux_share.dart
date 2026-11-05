import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:url_launcher/url_launcher.dart';

/// Function signature for launching URIs via external application or mailto.
typedef UriLauncher = Future<bool> Function(Uri uri);

/// Abstraction for executing operating system processes to allow deterministic unit testing.
abstract class ProcessRunner {
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  });
}

/// Default implementation of [ProcessRunner] utilizing [Process.run].
class DefaultProcessRunner implements ProcessRunner {
  const DefaultProcessRunner();

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true,
    bool runInShell = false,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
    );
  }
}

/// Linux desktop implementation of [SharePlatform] for Quiet Paper.
///
/// Implements [shareXFiles], [share], and [shareUri] using the Freedesktop
/// XDG Desktop Portal (`org.freedesktop.portal.OpenURI`) with interactive chooser
/// (`ask: true`), supplemented with multi-tiered fallbacks (`gio open`, `xdg-open`,
/// `org.freedesktop.FileManager1.ShowItems`, `xdg-email`, and `mailto:`).
class QuietPaperLinuxSharePlugin extends SharePlatform {
  QuietPaperLinuxSharePlugin({
    ProcessRunner? processRunner,
    this.uriLauncher,
    Directory? tempDirectory,
  })  : _processRunner = processRunner ?? const DefaultProcessRunner(),
        customTempDirectory = tempDirectory;

  final ProcessRunner _processRunner;
  final UriLauncher? uriLauncher;
  final Directory? customTempDirectory;

  /// Registers [QuietPaperLinuxSharePlugin] as the active [SharePlatform.instance].
  static void register({
    ProcessRunner? processRunner,
    UriLauncher? uriLauncher,
    Directory? tempDirectory,
  }) {
    SharePlatform.instance = QuietPaperLinuxSharePlugin(
      processRunner: processRunner,
      uriLauncher: uriLauncher,
      tempDirectory: tempDirectory,
    );
  }

  Directory get _tempDir {
    if (customTempDirectory != null) return customTempDirectory!;
    return Directory(p.join(Directory.systemTemp.path, 'quitepaper_shares'));
  }

  /// Summons the Linux platform share mechanism for [XFile] items.
  @override
  Future<ShareResult> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    List<String>? fileNameOverrides,
  }) async {
    if (files.isEmpty) {
      throw ArgumentError('Non-empty list of files must be specified.');
    }

    if (fileNameOverrides != null && fileNameOverrides.length != files.length) {
      throw ArgumentError(
        'The length of fileNameOverrides (${fileNameOverrides.length}) '
        'must match the length of files (${files.length}).',
      );
    }

    // 1. Resolve all files to concrete local disk paths
    final List<File> resolvedFiles = [];
    for (int i = 0; i < files.length; i++) {
      final xFile = files[i];
      final overrideName = fileNameOverrides != null ? fileNameOverrides[i] : null;
      final file = await _ensureFileOnDisk(xFile, overrideName: overrideName);
      resolvedFiles.add(file);
    }

    bool handled = false;

    // 2. Handle single vs multiple files
    if (resolvedFiles.length == 1) {
      final targetFile = resolvedFiles.first;

      // Tier 1: XDG Desktop Portal OpenURI with ask: true (native app chooser)
      handled = await _tryPortalOpenUri(targetFile.path, ask: true);

      // Tier 2: System application launcher (gio open)
      if (!handled) {
        handled = await _tryGioOpen(targetFile.path);
      }

      // Tier 3: System fallback opener (xdg-open)
      if (!handled) {
        handled = await _tryXdgOpen(targetFile.path);
      }

      // Tier 4: Email share with attachment if subject or text was provided
      if (!handled && (subject != null || text != null)) {
        handled = await _tryXdgEmail(targetFile.path, subject: subject, text: text);
      }

      // Tier 5: Reveal file in file manager
      if (!handled) {
        handled = await _tryFileManagerShowItems([targetFile.path]);
      }
      if (!handled) {
        handled = await _tryOpenDirectory(targetFile.parent.path);
      }
    } else {
      // Multiple files:
      // Tier 1: Highlight and reveal all files together in native file manager
      handled = await _tryFileManagerShowItems(resolvedFiles.map((f) => f.path).toList());

      // Tier 2: Open each file via Portal OpenURI
      if (!handled) {
        bool allOpened = true;
        for (final f in resolvedFiles) {
          final ok = await _tryPortalOpenUri(f.path, ask: true);
          if (!ok) {
            allOpened = false;
            break;
          }
        }
        handled = allOpened;
      }

      // Tier 3: Open each file via gio open or xdg-open
      if (!handled) {
        bool allOpened = true;
        for (final f in resolvedFiles) {
          final ok = await _tryGioOpen(f.path) || await _tryXdgOpen(f.path);
          if (!ok) {
            allOpened = false;
            break;
          }
        }
        handled = allOpened;
      }

      // Tier 4: Reveal parent directory
      if (!handled) {
        handled = await _tryOpenDirectory(resolvedFiles.first.parent.path);
      }
    }

    if (handled) {
      return const ShareResult('success', ShareResultStatus.success);
    }

    return ShareResult.unavailable;
  }

  /// Shares a URI on Linux.
  @override
  Future<ShareResult> shareUri(
    Uri uri, {
    Rect? sharePositionOrigin,
  }) async {
    final uriStr = uri.toString();

    // 1. Try Desktop Portal OpenURI
    if (await _tryPortalOpenUri(uriStr, ask: false)) {
      return const ShareResult('success', ShareResultStatus.success);
    }

    // 2. Try gio open / xdg-open
    if (await _tryGioOpen(uriStr) || await _tryXdgOpen(uriStr)) {
      return const ShareResult('success', ShareResultStatus.success);
    }

    // 3. Fallback to share() text handling
    return share(uriStr, sharePositionOrigin: sharePositionOrigin);
  }

  /// Shares text or URLs on Linux.
  @override
  Future<ShareResult> share(
    String text, {
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    // If text is a standalone HTTP/HTTPS URL, try opening via system default browser
    final trimmed = text.trim();
    final isHttpUrl = trimmed.startsWith('http://') || trimmed.startsWith('https://');
    if (isHttpUrl && (subject == null || subject.isEmpty)) {
      if (await _tryPortalOpenUri(trimmed, ask: false)) {
        return const ShareResult('success', ShareResultStatus.success);
      }
      if (await _tryGioOpen(trimmed) || await _tryXdgOpen(trimmed)) {
        return const ShareResult('success', ShareResultStatus.success);
      }
    }

    // Try xdg-email if available
    final emailHandled = await _tryXdgEmail('', subject: subject, text: text);
    if (emailHandled) {
      return const ShareResult('success', ShareResultStatus.success);
    }

    // Standard mailto: URI fallback via UrlLauncher
    final queryParameters = {
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      if (text.isNotEmpty) 'body': text,
    };

    final uri = Uri(
      scheme: 'mailto',
      query: queryParameters.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&'),
    );

    try {
      final launchResult = await _launch(uri);
      if (launchResult) {
        return const ShareResult('success', ShareResultStatus.success);
      }
    } catch (e) {
      debugPrint('Failed to launch mailto URI: $e');
    }

    return ShareResult.unavailable;
  }

  Future<bool> _launch(Uri uri) async {
    if (uriLauncher != null) {
      return uriLauncher!(uri);
    }
    return launchUrl(uri);
  }

  Future<File> _ensureFileOnDisk(XFile xFile, {String? overrideName}) async {
    final tempDir = _tempDir;
    if (!tempDir.existsSync()) {
      tempDir.createSync(recursive: true);
    }

    final hasPath = xFile.path.isNotEmpty;
    final existsOnDisk = hasPath && File(xFile.path).existsSync();

    if (existsOnDisk) {
      final existingFile = File(xFile.path);
      if (overrideName != null && p.basename(xFile.path) != overrideName) {
        final targetPath = p.join(tempDir.path, overrideName);
        return existingFile.copy(targetPath);
      }
      return existingFile;
    }

    // In-memory XFile or non-existent path: write bytes to disk
    final bytes = await xFile.readAsBytes();
    final effectiveName = overrideName ??
        (xFile.name.isNotEmpty ? xFile.name : 'shared_file_${DateTime.now().millisecondsSinceEpoch}');
    final targetPath = p.join(tempDir.path, effectiveName);
    final targetFile = File(targetPath);
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile;
  }

  Future<bool> _tryPortalOpenUri(String uriOrPath, {required bool ask}) async {
    try {
      final uriStr = uriOrPath.startsWith('file://') ||
              uriOrPath.startsWith('http://') ||
              uriOrPath.startsWith('https://')
          ? uriOrPath
          : Uri.file(uriOrPath).toString();

      final optionsJson = ask ? '{"ask": <true>}' : '{}';
      final result = await _processRunner.run(
        'gdbus',
        [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.portal.Desktop',
          '--object-path',
          '/org/freedesktop/portal/desktop',
          '--method',
          'org.freedesktop.portal.OpenURI.OpenURI',
          '',
          uriStr,
          optionsJson,
        ],
      );

      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryGioOpen(String path) async {
    try {
      final result = await _processRunner.run('gio', ['open', path]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryXdgOpen(String path) async {
    try {
      final result = await _processRunner.run('xdg-open', [path]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryFileManagerShowItems(List<String> paths) async {
    try {
      final uris = paths.map((path) => Uri.file(path).toString()).toList();
      final uriArrayArg = '[${uris.map((u) => "'$u'").join(', ')}]';

      final result = await _processRunner.run(
        'gdbus',
        [
          'call',
          '--session',
          '--dest',
          'org.freedesktop.FileManager1',
          '--object-path',
          '/org/freedesktop/FileManager1',
          '--method',
          'org.freedesktop.FileManager1.ShowItems',
          uriArrayArg,
          '',
        ],
      );

      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _tryOpenDirectory(String dirPath) async {
    if (await _tryGioOpen(dirPath)) return true;
    return _tryXdgOpen(dirPath);
  }

  Future<bool> _tryXdgEmail(
    String filePath, {
    String? subject,
    String? text,
  }) async {
    try {
      final args = <String>[];
      if (filePath.isNotEmpty && File(filePath).existsSync()) {
        args.addAll(['--attach', filePath]);
      }
      if (subject != null && subject.isNotEmpty) {
        args.addAll(['--subject', subject]);
      }
      if (text != null && text.isNotEmpty) {
        args.addAll(['--body', text]);
      }

      if (args.isEmpty) return false;

      final result = await _processRunner.run('xdg-email', args);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
