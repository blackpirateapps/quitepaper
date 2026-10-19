import 'package:flutter/foundation.dart';

import '../../features/editor/domain/rich_block.dart';

/// The specific phase during link metadata & thumbnail resolution where
/// an operation occurred or failed.
enum LinkFetchStage {
  urlValidation,
  pageFetch,
  htmlParsing,
  metadataExtraction,
  thumbnailFetch,
  thumbnailProcessing,
  attachmentStorage;

  String get displayLabel {
    switch (this) {
      case LinkFetchStage.urlValidation:
        return 'URL Validation';
      case LinkFetchStage.pageFetch:
        return 'Network Request';
      case LinkFetchStage.htmlParsing:
        return 'HTML Validation';
      case LinkFetchStage.metadataExtraction:
        return 'Metadata Extraction';
      case LinkFetchStage.thumbnailFetch:
        return 'Thumbnail Download';
      case LinkFetchStage.thumbnailProcessing:
        return 'Thumbnail Compression';
      case LinkFetchStage.attachmentStorage:
        return 'Encrypted Storage';
    }
  }
}

/// Structured diagnostic telemetry recorded during link preview baking.
@immutable
class LinkFetchDiagnostics {
  const LinkFetchDiagnostics({
    required this.url,
    required this.timestamp,
    required this.stage,
    required this.reason,
    this.httpStatusCode,
    this.httpStatusReason,
    this.contentType,
    this.duration,
    this.rawException,
    this.resolvedRedirectUri,
    this.leadImageUrl,
    this.leadImageStatusCode,
    this.leadImageError,
    this.extractedTitle,
    this.extractedDescription,
    this.extractedSiteName,
  });

  /// The original URL that was attempted.
  final String url;

  /// Time when the fetch operation was initiated or completed.
  final DateTime timestamp;

  /// The stage at which the fetch terminated or encountered a failure.
  final LinkFetchStage stage;

  /// Human-readable explanation of why the fetch succeeded or failed.
  final String reason;

  /// HTTP status code from the page request (e.g., 200, 403, 404, 500).
  final int? httpStatusCode;

  /// HTTP status reason phrase (e.g., "Forbidden", "Not Found").
  final String? httpStatusReason;

  /// Content-Type header received from the server.
  final String? contentType;

  /// Elapsed duration of the entire fetch operation.
  final Duration? duration;

  /// Raw exception message or stack string if an unhandled exception occurred.
  final String? rawException;

  /// Final redirected URL if 3xx redirects occurred.
  final String? resolvedRedirectUri;

  /// Lead image URL extracted from the page's OpenGraph / Twitter meta tags.
  final String? leadImageUrl;

  /// HTTP status code when attempting to download the lead image.
  final int? leadImageStatusCode;

  /// Detailed error string if lead image download or processing failed.
  final String? leadImageError;

  /// Title extracted from `<title>` or `og:title`.
  final String? extractedTitle;

  /// Description extracted from `<meta name="description">` or `og:description`.
  final String? extractedDescription;

  /// Publisher or website name extracted from `og:site_name` or domain.
  final String? extractedSiteName;

  /// Produces a formatted markdown diagnostic report suitable for copying to clipboard.
  String toFormattedReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Quiet Paper Link Preview Diagnostics ===');
    buffer.writeln('URL: $url');
    buffer.writeln('Timestamp: ${timestamp.toIso8601String()}');
    if (duration != null) {
      buffer.writeln('Duration: ${duration!.inMilliseconds}ms');
    }
    buffer.writeln('Failure Stage: ${stage.displayLabel}');
    buffer.writeln('Reason: $reason');
    if (httpStatusCode != null) {
      buffer.writeln(
          'HTTP Status: $httpStatusCode${httpStatusReason != null ? " ($httpStatusReason)" : ""}');
    }
    if (contentType != null) {
      buffer.writeln('Content-Type: $contentType');
    }
    if (resolvedRedirectUri != null && resolvedRedirectUri != url) {
      buffer.writeln('Redirected To: $resolvedRedirectUri');
    }
    if (rawException != null) {
      buffer.writeln('Exception: $rawException');
    }
    buffer.writeln('--- Metadata Extraction ---');
    buffer.writeln('Title: ${extractedTitle ?? "(none)"}');
    buffer.writeln('Description: ${extractedDescription ?? "(none)"}');
    buffer.writeln('Site Name: ${extractedSiteName ?? "(none)"}');
    buffer.writeln('Lead Image URL: ${leadImageUrl ?? "(none)"}');
    if (leadImageStatusCode != null) {
      buffer.writeln('Lead Image HTTP Status: $leadImageStatusCode');
    }
    if (leadImageError != null) {
      buffer.writeln('Lead Image Error: $leadImageError');
    }
    buffer.writeln('============================================');
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkFetchDiagnostics &&
          runtimeType == other.runtimeType &&
          url == other.url &&
          timestamp == other.timestamp &&
          stage == other.stage &&
          reason == other.reason &&
          httpStatusCode == other.httpStatusCode &&
          httpStatusReason == other.httpStatusReason &&
          contentType == other.contentType &&
          duration == other.duration &&
          rawException == other.rawException &&
          resolvedRedirectUri == other.resolvedRedirectUri &&
          leadImageUrl == other.leadImageUrl &&
          leadImageStatusCode == other.leadImageStatusCode &&
          leadImageError == other.leadImageError &&
          extractedTitle == other.extractedTitle &&
          extractedDescription == other.extractedDescription &&
          extractedSiteName == other.extractedSiteName;

  @override
  int get hashCode => Object.hash(
        url,
        timestamp,
        stage,
        reason,
        httpStatusCode,
        httpStatusReason,
        contentType,
        duration,
        rawException,
        resolvedRedirectUri,
        leadImageUrl,
        leadImageStatusCode,
        leadImageError,
        extractedTitle,
        extractedDescription,
        extractedSiteName,
      );
}

/// The composite result of a link preview bake operation.
@immutable
class LinkBakeResult {
  const LinkBakeResult({
    this.block,
    required this.diagnostics,
  });

  /// The resulting rich preview block on success, or `null` if fetching failed.
  final LinkPreviewBlock? block;

  /// Structured diagnostic details explaining the fetch outcome.
  final LinkFetchDiagnostics diagnostics;

  /// Whether baking completed successfully and produced a rich block.
  bool get isSuccess => block != null;
}
