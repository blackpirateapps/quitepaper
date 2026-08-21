import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/features/web_clipper/presentation/web_clip_preview_sheet.dart';

void main() {
  testWidgets('WebClipPreviewSheet renders storage options, tag chips, and size estimate', (tester) async {
    final scanResult = WebClipScanResult(
      metadata: const ExtractedArticleMetadata(
        sourceUrl: 'https://example.com/post',
        title: 'Design for Humans',
        author: 'Sarah Connor',
        domain: 'example.com',
      ),
      rawHtml: '<html><body><article><p>Hello</p></article></body></html>',
      cleanedArticleHtml: '<article><p>Hello</p></article>',
      markdownBody: 'Hello world',
      markdownSizeEstimate: 15 * 1024,
      htmlSnapshotSizeEstimate: 120 * 1024,
      images: const [
        ClippedImageCandidate(
          rawUrl: 'https://example.com/img1.png',
          resolvedUrl: 'https://example.com/img1.png',
          estimatedSizeBytes: 200 * 1024,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: WebClipPreviewSheet(scanResult: scanResult),
          ),
        ),
      ),
    );

    expect(find.text('Clip Webpage'), findsOneWidget);
    expect(find.text('ARTICLE PREVIEW'), findsOneWidget);
    expect(find.text('STORAGE & INGESTION OPTIONS'), findsOneWidget);
    expect(find.text('Markdown Note (Core Body)'), findsOneWidget);
    expect(find.text('Save Web Snapshot'), findsOneWidget);
    expect(find.text('Download Images Locally'), findsOneWidget);
    expect(find.text('#clipped'), findsOneWidget);
    expect(find.text('#example.com'), findsOneWidget);
    expect(find.text('Clip Note (335.0 KB)'), findsOneWidget);
  });
}
