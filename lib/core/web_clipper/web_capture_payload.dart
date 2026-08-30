import 'package:flutter/foundation.dart';

/// Strategy used to acquire webpage content.
enum WebAcquisitionMethod {
  /// Direct background HTTP/HTTPS request with automated resilient fallback.
  directHttp,

  /// In-app interactive browser session with user-assisted navigation and explicit capture.
  inAppBrowser,
}

/// Immutable content payload captured from an in-app browser session or direct acquisition.
@immutable
class WebCapturePayload {
  WebCapturePayload({
    required this.requestedUrl,
    required this.finalUrl,
    required this.html,
    this.pageTitle,
    this.canonicalUrl,
    this.description,
    this.author,
    this.publishedAt,
    DateTime? capturedAt,
    this.acquisitionMethod = WebAcquisitionMethod.inAppBrowser,
  }) : capturedAt = capturedAt ?? DateTime.now();

  /// The original URL requested by the user or intent.
  final String requestedUrl;

  /// The final URL after any HTTP or client-side redirects.
  final String finalUrl;

  /// The complete HTML content of the page at the moment of capture.
  final String html;

  /// Page title reported by document.title or `<head>`.
  final String? pageTitle;

  /// Explicit canonical URL specified by `<link rel="canonical">` if present.
  final String? canonicalUrl;

  /// Meta description or OpenGraph description.
  final String? description;

  /// Article author reported by metadata or byline.
  final String? author;

  /// Published timestamp if reported in metadata.
  final DateTime? publishedAt;

  /// Exact timestamp when the content was captured.
  final DateTime capturedAt;

  /// The acquisition strategy used to obtain this payload.
  final WebAcquisitionMethod acquisitionMethod;

  /// Effective URL for resolving relative links and asset paths.
  String get effectiveUrl =>
      (canonicalUrl != null && canonicalUrl!.trim().isNotEmpty)
          ? canonicalUrl!
          : (finalUrl.isNotEmpty ? finalUrl : requestedUrl);

  /// Approximate byte size of the captured raw HTML string.
  int get htmlByteSize => html.length;

  WebCapturePayload copyWith({
    String? requestedUrl,
    String? finalUrl,
    String? html,
    String? pageTitle,
    String? canonicalUrl,
    String? description,
    String? author,
    DateTime? publishedAt,
    DateTime? capturedAt,
    WebAcquisitionMethod? acquisitionMethod,
  }) {
    return WebCapturePayload(
      requestedUrl: requestedUrl ?? this.requestedUrl,
      finalUrl: finalUrl ?? this.finalUrl,
      html: html ?? this.html,
      pageTitle: pageTitle ?? this.pageTitle,
      canonicalUrl: canonicalUrl ?? this.canonicalUrl,
      description: description ?? this.description,
      author: author ?? this.author,
      publishedAt: publishedAt ?? this.publishedAt,
      capturedAt: capturedAt ?? this.capturedAt,
      acquisitionMethod: acquisitionMethod ?? this.acquisitionMethod,
    );
  }
}
