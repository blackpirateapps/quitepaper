import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../features/web_clipper/presentation/web_clip_dialog.dart';

/// Handler for receiving shared URLs from external mobile browsers (Chrome, Firefox, Safari).
class ShareIntentHandler {
  static StreamSubscription<List<SharedMediaFile>>? _intentSub;
  static bool _initialized = false;

  /// Initializes share intent listeners and checks initial share intent on launch.
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized || kIsWeb) return;
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
      final text = file.path.trim();
      final url = _extractUrl(text);
      if (url != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = navigatorKey.currentContext;
          if (context != null) {
            WebClipDialog.show(context, initialUrl: url);
          }
        });
        break;
      }
    }
  }

  static String? _extractUrl(String text) {
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text.split(RegExp(r'\s+')).first;
    }
    final match = RegExp(r'https?://[^\s]+').firstMatch(text);
    return match?.group(0);
  }
}
