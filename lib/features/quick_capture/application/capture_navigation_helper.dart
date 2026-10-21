import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/quick_capture_payload.dart';

/// Handles source-aware navigation and task stack return for Quick Capture.
class CaptureNavigationHelper {
  static const MethodChannel _channel =
      MethodChannel('com.blackpiratex.quietpaper/quick_capture');

  /// Closes the Quick Capture experience according to its origin:
  /// - Widget-origin: pops the route and moves the task to background, returning to the launcher.
  /// - Share-origin: pops the route and returns to the originating application.
  /// - In-app: standard route pop.
  static Future<void> closeCapture(
    BuildContext context, {
    required CaptureOrigin origin,
  }) async {
    final nav = Navigator.of(context);
    final canPop = nav.canPop();

    if (canPop) {
      nav.pop();
    }

    if (origin == CaptureOrigin.widget || origin == CaptureOrigin.share) {
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _channel.invokeMethod('moveTaskToBack');
        } catch (e) {
          debugPrint('[CaptureNavigationHelper] moveTaskToBack error: $e');
          if (!canPop) {
            await SystemNavigator.pop();
          }
        }
      }
    }
  }
}
