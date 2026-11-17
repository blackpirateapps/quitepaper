import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/quick_capture_payload.dart';
import '../presentation/quick_capture_screen.dart';
import 'quick_capture_normalizer.dart';

/// Central coordinator that handles Quick Capture launches from home-screen widgets,
/// Android share sheets, or in-app triggers, preventing duplicate routes and safely
/// delivering new incoming shares to active sessions.
class QuickCaptureCoordinator {
  static const MethodChannel _channel = MethodChannel(
    'com.blackpiratex.quietpaper/quick_capture',
  );

  static bool _initialized = false;
  static bool _isRouteOpen = false;
  static QuickCapturePayload? _activePayload;
  static final _pendingShares = <QuickCapturePayload>[];
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Whether the Quick Capture route is currently active on screen.
  static bool get isRouteOpen => _isRouteOpen;

  /// Initializes native method call listener for widget taps while the app is running.
  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_initialized ||
        kIsWeb ||
        Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onQuickCaptureRequested':
          final args = call.arguments is Map
              ? Map<String, dynamic>.from(call.arguments as Map)
              : null;
          final originStr = args?['origin'] as String? ?? 'widget';
          final origin = originStr == 'share'
              ? CaptureOrigin.share
              : CaptureOrigin.widget;
          final rawText = args?['text'] as String?;
          final rawUri = args?['uri'] as String?;

          final payload = QuickCaptureNormalizer.normalize(
            origin: origin,
            rawText: rawText,
            rawUri: rawUri,
          );
          openCapture(payload);
          break;
      }
    });

    // Check if the application was cold-launched from the widget
    if (Platform.isAndroid) {
      _checkInitialWidgetLaunch();
    }
  }

  static Future<void> _checkInitialWidgetLaunch() async {
    try {
      final initialData = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getInitialCaptureRequest',
      );
      if (initialData != null && initialData.isNotEmpty) {
        final originStr = initialData['origin'] as String? ?? 'widget';
        final origin = originStr == 'share'
            ? CaptureOrigin.share
            : CaptureOrigin.widget;
        final rawText = initialData['text'] as String?;
        final rawUri = initialData['uri'] as String?;

        final payload = QuickCaptureNormalizer.normalize(
          origin: origin,
          rawText: rawText,
          rawUri: rawUri,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          openCapture(payload);
        });
      }
    } catch (e) {
      debugPrint('[QuickCaptureCoordinator] Error checking initial launch: $e');
    }
  }

  /// Opens Quick Capture with the provided payload. If already open, avoids pushing
  /// duplicate routes and queues distinct incoming requests until the active session closes.
  static void openCapture(QuickCapturePayload payload) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    if (_isRouteOpen) {
      if (!_sameRequest(_activePayload, payload) &&
          !_pendingShares.any((pending) => _sameRequest(pending, payload))) {
        _pendingShares.add(payload);
      }
      return;
    }

    _isRouteOpen = true;
    _activePayload = payload;
    nav.push<void>(QuickCaptureScreen.route(payload)).then((_) {
      if (!identical(_activePayload, payload)) return;
      _isRouteOpen = false;
      _activePayload = null;
      if (_pendingShares.isNotEmpty) {
        openCapture(_pendingShares.removeAt(0));
      }
    });
  }

  static bool _sameRequest(
    QuickCapturePayload? first,
    QuickCapturePayload second,
  ) =>
      first != null &&
      (first.id == second.id ||
          (first.origin == second.origin &&
              first.sourceUrl == second.sourceUrl &&
              first.initialContent == second.initialContent &&
              first.titleHint == second.titleHint));

  static void dispose() {
    _initialized = false;
    _isRouteOpen = false;
    _navigatorKey = null;
    _activePayload = null;
    _pendingShares.clear();
  }
}
