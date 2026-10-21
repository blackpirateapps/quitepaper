import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../features/quick_capture/application/quick_capture_coordinator.dart';
import '../../features/quick_capture/application/quick_capture_normalizer.dart';
import '../../features/quick_capture/domain/quick_capture_payload.dart';
import '../sharing/shared_file_importer.dart';

/// Handler for content received from other apps via Android share / "Open with"
/// intents: shared URLs are routed to the web clipper, while opened PDF, text,
/// and Markdown files are imported into a new note by [SharedFileImporter].
class ShareIntentHandler {
  static StreamSubscription<List<SharedMediaFile>>? _intentSub;
  static bool _initialized = false;

  /// Initializes share intent listeners and checks initial share intent on launch.
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized || kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _initialized = true;

    try {
      // 1. Listen to incoming shared media while app is running
      _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (files) {
          _handleSharedFiles(files, navigatorKey);
        },
        onError: (err) {
          debugPrint('Error receiving share intent stream: $err');
        },
      );

      // 2. Check initial share intent when app is opened from closed state
      ReceiveSharingIntent.instance.getInitialMedia().then((files) {
        _handleSharedFiles(files, navigatorKey);
        ReceiveSharingIntent.instance.reset();
      }).catchError((err) {
        debugPrint('Error getting initial share intent: $err');
      });
    } catch (e) {
      debugPrint('ShareIntentHandler initialization skipped on this platform: $e');
    }
  }

  static void dispose() {
    _intentSub?.cancel();
    _intentSub = null;
    _initialized = false;
  }

  static void _handleSharedFiles(
    List<SharedMediaFile> files,
    GlobalKey<NavigatorState> navigatorKey,
  ) {
    if (files.isEmpty) return;

    for (final file in files) {
      final raw = file.path.trim();
      if (raw.isEmpty) continue;

      // A real on-disk file means the user opened or shared a document
      // (PDF, text or Markdown); otherwise `path` carries shared text/URL.
      final isFile = _isExistingFile(raw);
      final mimeType = file.mimeType;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = navigatorKey.currentContext;
        if (context == null) return;
        if (isFile) {
          SharedFileImporter.importFile(
            path: raw,
            mimeType: mimeType,
            navigatorKey: navigatorKey,
          );
        } else {
          final payload = QuickCaptureNormalizer.normalize(
            origin: CaptureOrigin.share,
            rawText: raw,
          );
          QuickCaptureCoordinator.openCapture(payload);
        }
      });
      return; // Handle only the first shareable item.
    }
  }

  static bool _isExistingFile(String path) {
    try {
      return File(path).existsSync();
    } catch (_) {
      return false;
    }
  }
}
