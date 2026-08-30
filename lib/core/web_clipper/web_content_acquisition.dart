import 'web_capture_result.dart';

export 'web_capture_payload.dart';
export 'web_capture_result.dart';

/// Common abstraction for acquiring webpage content (either direct HTTP or in-app browser).
abstract class WebContentAcquirer {
  /// Acquires content from [url] and returns a structured [WebCaptureResult].
  Future<WebCaptureResult> acquire(Uri url);
}

/// Interface for in-app browser based content capture.
abstract class BrowserContentAcquirer {
  /// Captures the current DOM and metadata from the browser for [url].
  Future<WebCaptureResult> capture(Uri url);
}
