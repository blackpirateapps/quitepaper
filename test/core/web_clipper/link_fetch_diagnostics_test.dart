import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/web_clipper/link_fetch_diagnostics.dart';

void main() {
  group('LinkFetchDiagnostics', () {
    test('creates diagnostics with full fields and produces formatted report', () {
      final diagnostics = LinkFetchDiagnostics(
        url: 'https://example.com/article',
        timestamp: DateTime(2026, 10, 19, 10, 0),
        stage: LinkFetchStage.pageFetch,
        reason: 'Server returned HTTP 403 (Forbidden) — Access denied',
        httpStatusCode: 403,
        httpStatusReason: 'Forbidden',
        contentType: 'text/html; charset=utf-8',
        duration: const Duration(milliseconds: 245),
        rawException: 'HttpException: 403 Forbidden',
        resolvedRedirectUri: 'https://example.com/blocked',
        leadImageUrl: 'https://example.com/thumb.jpg',
        leadImageStatusCode: 404,
        leadImageError: 'Image not found',
        extractedTitle: 'Example Title',
        extractedDescription: 'Example Description',
        extractedSiteName: 'Example Site',
      );

      expect(diagnostics.url, equals('https://example.com/article'));
      expect(diagnostics.stage, equals(LinkFetchStage.pageFetch));
      expect(diagnostics.stage.displayLabel, equals('Network Request'));
      expect(diagnostics.httpStatusCode, equals(403));

      final report = diagnostics.toFormattedReport();
      expect(report, contains('URL: https://example.com/article'));
      expect(report, contains('Failure Stage: Network Request'));
      expect(report, contains('HTTP Status: 403 (Forbidden)'));
      expect(report, contains('Content-Type: text/html; charset=utf-8'));
      expect(report, contains('Redirected To: https://example.com/blocked'));
      expect(report, contains('Title: Example Title'));
      expect(report, contains('Description: Example Description'));
      expect(report, contains('Lead Image HTTP Status: 404'));
      expect(report, contains('Lead Image Error: Image not found'));
    });

    test('value equality and hashing works across equivalent instances', () {
      final timestamp = DateTime(2026, 10, 19, 10, 0);
      final d1 = LinkFetchDiagnostics(
        url: 'https://example.com',
        timestamp: timestamp,
        stage: LinkFetchStage.urlValidation,
        reason: 'Invalid scheme',
      );
      final d2 = LinkFetchDiagnostics(
        url: 'https://example.com',
        timestamp: timestamp,
        stage: LinkFetchStage.urlValidation,
        reason: 'Invalid scheme',
      );

      expect(d1, equals(d2));
      expect(d1.hashCode, equals(d2.hashCode));
    });

    test('LinkBakeResult correctly reports isSuccess', () {
      final diagnostics = LinkFetchDiagnostics(
        url: 'https://example.com',
        timestamp: DateTime(2026, 10, 19, 10, 0),
        stage: LinkFetchStage.urlValidation,
        reason: 'Error',
      );

      final failedResult = LinkBakeResult(block: null, diagnostics: diagnostics);
      expect(failedResult.isSuccess, isFalse);
    });
  });
}
