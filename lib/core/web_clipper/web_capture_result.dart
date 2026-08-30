import 'package:flutter/foundation.dart';
import 'web_capture_payload.dart';

/// Failure categorization for content acquisition and processing.
enum WebAcquisitionErrorKind {
  /// The network connection is offline or unreachable.
  networkFailure,

  /// Access requires an in-app browser session (e.g. login, verification, JS rendering).
  requiresBrowser,

  /// The requested URL scheme or target page format is unsupported.
  unsupportedPage,

  /// The page content is empty, malformed, or contains no readable elements.
  invalidContent,

  /// The article extraction engine could not isolate a structured article container.
  extractionFailed,

  /// The browser DOM capture bridge failed or timed out.
  captureFailed,

  /// The page load or extraction operation timed out.
  timeout,

  /// The capture operation was cancelled by the user or superseded by navigation.
  cancelled,
}

/// Structured error describing web acquisition failures.
@immutable
class WebAcquisitionError implements Exception {
  const WebAcquisitionError({
    required this.kind,
    required this.message,
    this.statusCode,
    this.underlyingError,
  });

  final WebAcquisitionErrorKind kind;
  final String message;
  final int? statusCode;
  final Object? underlyingError;

  @override
  String toString() => message;
}

/// Result object for browser or direct web content capture.
@immutable
class WebCaptureResult {
  const WebCaptureResult.success(
    this.payload, {
    this.diagnostics,
    this.warnings = const <String>[],
  })  : isSuccess = true,
        error = null;

  const WebCaptureResult.failure(
    this.error, {
    this.diagnostics,
    this.warnings = const <String>[],
  })  : isSuccess = false,
        payload = null;

  final bool isSuccess;
  final WebCapturePayload? payload;
  final WebAcquisitionError? error;
  final String? diagnostics;
  final List<String> warnings;
}
