# Android web clipper audit evidence

Source revision: `810704c40ce943d9b339279e5b83193001d32b01`.

## Focused probe output

These are characterization assertions: they pass when the documented defect is present. The snapshot storage exception is deliberately injected for WC-03. The final run is shown below. An earlier loopback attempt encountered Flutter test HTTP interception (HTTP 400); the final harness constructs a real client for its local server and reproduces the redirect defect successfully. That harness issue is not an application finding.

```text
00:00 +0: loading /home/dog/git/quitepaper/test/web_clipper/android_audit_probe_test.dart
00:00 +0: WC-01 saved snapshot contains Markdown rather than a usable image source
WC-01 saved img src=![Photo](qp://asset/photo-id)
00:00 +1: WC-02 preview inlines CSS but default commit discards it
WC-02 CSS fetched during scan, absent from persisted snapshot
00:00 +2: WC-03 snapshot write failure still reports complete and saves note
Failed to create web snapshot document: Bad state: vault write failed
WC-03 result=success, snapshot=null, progress=complete
00:00 +3: WC-04 removed default tags are reinserted on commit
WC-04 requested tags=[custom], saved=[clipped, example.com, custom]
00:00 +4: WC-05 browser canonical changes relative asset origin
WC-05 loaded mirror.example but image resolved to https://publisher.example/photo.png
00:00 +5: WC-06 real HTTP redirect resolves relative image against old path
WC-06 real redirect=/posts/article, expected image=/posts/photo.png, actual image=http://127.0.0.1:35147/photo.png
00:00 +6: WC-07 state copy cannot clear a previous error or status
WC-07 after clearing: error=Old error, status=Old status
00:00 +7: WC-08 failed query image replaced with another query image
WC-08 image one=404, image two=200, both saved as same asset
00:00 +8: WC-09 browser success pops newly opened editor
WC-09 route events: [push:/, push:/browser, push:ModalBottomSheetRoute<Note?>, pop:ModalBottomSheetRoute<Note?>, push:MaterialPageRoute<dynamic>, pop:MaterialPageRoute<dynamic>]
00:02 +9: WC-10 second share is discarded while first capture stays open
[QuickCaptureCoordinator] Route already open; ignoring duplicate push.
WC-10 new unique second URL ignored; first URL remains
00:02 +10: All tests passed!
```

## Probe source

The temporary file was `test/web_clipper/android_audit_probe_test.dart`. It imports existing fake repository/vault implementations from web_clipper_service_test.dart without invoking that file's main. WC-09 mocks capture/service results to isolate the actual screen and preview navigation. WC-10 uses a separate memory database. The only real HTTP traffic is WC-06 against its local fixture server. The malformed image source and missing CSS are verified before storage encryption, at the document service boundary.

To replay on the audited source, extract this Dart block into the temporary path and run:

```sh
flutter test --no-pub test/web_clipper/android_audit_probe_test.dart --reporter expanded
```

Remove the executable probe afterward. It is evidence of bugs, not a regression test suite to adopt unchanged.

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:http/io_client.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_capture_result.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_coordinator.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_normalizer.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_provider.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/core/web_clipper/web_image_downloader.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_controller.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_screen.dart';
import 'package:quitepaper/features/web_clipper/presentation/web_clip_preview_sheet.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'web_clipper_service_test.dart' as fakes;

const page =
    '<html><head><title>Audit Article</title><link rel="stylesheet" href="/style.css"></head><body><article><p>Enough article text for extraction.</p><img src="/photo.png" alt="Photo"></article></body></html>';
WebClipScanResult scanFixture() => const WebClipScanResult(
  metadata: ExtractedArticleMetadata(
    sourceUrl: 'https://example.com/article',
    title: 'Audit Article',
    domain: 'example.com',
  ),
  rawHtml: page,
  cleanedArticleHtml:
      '<article><p>Enough article text for extraction.</p><img src="https://example.com/photo.png" alt="Photo"></article>',
  markdownBody: 'Enough article text for extraction.',
  markdownSizeEstimate: 50,
  htmlSnapshotSizeEstimate: 400,
  images: [
    ClippedImageCandidate(
      rawUrl: '/photo.png',
      resolvedUrl: 'https://example.com/photo.png',
      altText: 'Photo',
    ),
  ],
);

class DirectHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)..findProxy = (_) => 'DIRECT';
}

class FixedDownloader extends WebImageDownloader {
  FixedDownloader() : super(attachmentService: fakes.FakeAttachmentService());
  @override
  Future<Map<String, String>> downloadAndEncryptImages({
    required List<ClippedImageCandidate> candidates,
    required String noteId,
    void Function(int, int)? onProgress,
  }) async => {
    '/photo.png': '![Photo](qp://asset/photo-id)',
    'https://example.com/photo.png': '![Photo](qp://asset/photo-id)',
  };
}

class FailedDocuments extends fakes.FakeDocumentService {
  @override
  Future<Never> createWebSnapshotDocument({
    required Uint8List htmlBytes,
    String? noteId,
    String title = 'Web Snapshot',
  }) async => throw StateError('vault write failed');
}

class CapturingController extends WebClipBrowserController {
  CapturingController() : super(initialUrl: 'https://example.com/article');
  @override
  Future<WebCaptureResult> captureCurrentPage() async =>
      WebCaptureResult.success(
        WebCapturePayload(
          requestedUrl: state.currentUrl,
          finalUrl: state.currentUrl,
          html: page,
        ),
      );
}

class FixedClipper extends WebClipperService {
  FixedClipper() : super(notesRepository: fakes.InMemoryNotesRepository());
  @override
  Future<WebClipScanResult> scanPayload(
    WebCapturePayload payload, {
    bool allowFallback = true,
  }) async => scanFixture();
  @override
  Future<({Note note, DocumentEntity? snapshotDocument})> clipArticle({
    required WebClipScanResult scanResult,
    required WebClipperOptions options,
    void Function(WebClipProgress)? onProgress,
  }) async => (
    note: Note(
      id: 'audit-note',
      title: 'Audit Article',
      content: 'Saved article',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    snapshotDocument: null,
  );
}

class RouteRecorder extends NavigatorObserver {
  final List<String> events = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('push:${route.settings.name ?? route.runtimeType}');
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      events.add('pop:${route.settings.name ?? route.runtimeType}');
}

void main() {
  test(
    'WC-01 saved snapshot contains Markdown rather than a usable image source',
    () async {
      final docs = fakes.FakeDocumentService();
      final service = WebClipperService(
        notesRepository: fakes.InMemoryNotesRepository(),
        documentService: docs,
        imageDownloader: FixedDownloader(),
      );
      await service.clipArticle(
        scanResult: scanFixture(),
        options: const WebClipperOptions(),
      );
      final saved = html.parse(
        utf8.decode(docs.createdSnapshots.values.single),
      );
      final src = saved.querySelector('img')!.attributes['src'];
      expect(src, '![Photo](qp://asset/photo-id)');
      print('WC-01 saved img src=$src');
    },
  );
  test('WC-02 preview inlines CSS but default commit discards it', () async {
    final requests = <String>[];
    final scanner = WebClipperScanner(
      httpClient: MockClient((request) async {
        requests.add(request.url.toString());
        return http.Response(
          request.url.path.endsWith('.css') ? 'p { color: red; }' : '',
          200,
        );
      }),
    );
    final scan = await scanner.scanPayload(
      WebCapturePayload(
        requestedUrl: 'https://example.com/article',
        finalUrl: 'https://example.com/article',
        html: page,
      ),
    );
    expect(requests, contains('https://example.com/style.css'));
    final docs = fakes.FakeDocumentService();
    await WebClipperService(
      notesRepository: fakes.InMemoryNotesRepository(),
      documentService: docs,
    ).clipArticle(
      scanResult: scan,
      options: const WebClipperOptions(downloadImages: false),
    );
    final saved = utf8.decode(docs.createdSnapshots.values.single);
    expect(
      saved,
      contains('<link rel="stylesheet" href="https://example.com/style.css">'),
    );
    expect(saved, isNot(contains('p { color: red; }')));
    print('WC-02 CSS fetched during scan, absent from persisted snapshot');
  });
  test(
    'WC-03 snapshot write failure still reports complete and saves note',
    () async {
      final progress = <WebClipProgressStep>[];
      final result =
          await WebClipperService(
            notesRepository: fakes.InMemoryNotesRepository(),
            documentService: FailedDocuments(),
          ).clipArticle(
            scanResult: scanFixture(),
            options: const WebClipperOptions(downloadImages: false),
            onProgress: (p) => progress.add(p.step),
          );
      expect(result.snapshotDocument, isNull);
      expect(progress.last, WebClipProgressStep.complete);
      expect(result.note.content, isNot(contains('qp://document/')));
      print('WC-03 result=success, snapshot=null, progress=complete');
    },
  );
  test('WC-04 removed default tags are reinserted on commit', () async {
    final result =
        await WebClipperService(
          notesRepository: fakes.InMemoryNotesRepository(),
        ).clipArticle(
          scanResult: scanFixture(),
          options: const WebClipperOptions(
            tags: ['custom'],
            saveHtmlSnapshot: false,
            downloadImages: false,
          ),
        );
    expect(result.note.tags, ['clipped', 'example.com', 'custom']);
    print('WC-04 requested tags=[custom], saved=${result.note.tags}');
  });
  test('WC-05 browser canonical changes relative asset origin', () async {
    final scan =
        await WebClipperScanner(
          httpClient: MockClient((_) async => http.Response('', 200)),
        ).scanPayload(
          WebCapturePayload(
            requestedUrl: 'https://mirror.example/posts/42',
            finalUrl: 'https://mirror.example/posts/42',
            canonicalUrl: 'https://publisher.example/articles/42',
            html: page,
          ),
        );
    expect(
      scan.images.single.resolvedUrl,
      'https://publisher.example/photo.png',
    );
    print(
      'WC-05 loaded mirror.example but image resolved to ${scan.images.single.resolvedUrl}',
    );
  });
  test(
    'WC-06 real HTTP redirect resolves relative image against old path',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final base = 'http://127.0.0.1:${server.port}';
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        if (request.uri.path == '/start') {
          request.response.statusCode = HttpStatus.found;
          request.response.headers.set(
            HttpHeaders.locationHeader,
            '$base/posts/article',
          );
        } else if (request.uri.path == '/posts/article') {
          request.response.headers.contentType = ContentType.html;
          request.response.write(
            page
                .replaceAll('/photo.png', 'photo.png')
                .replaceAll('<link rel="stylesheet" href="/style.css">', ''),
          );
        }
        await request.response.close();
      });
      final client = IOClient(DirectHttpOverrides().createHttpClient(null));
      try {
        final scan = await WebClipperScanner(
          httpClient: client,
        ).scanUrl('$base/start');
        expect(paths, contains('/posts/article'));
        expect(scan.images.single.resolvedUrl, '$base/photo.png');
        expect(paths, contains('/photo.png'));
        print(
          'WC-06 real redirect=/posts/article, expected image=/posts/photo.png, actual image=${scan.images.single.resolvedUrl}',
        );
      } finally {
        client.close();
        await server.close(force: true);
      }
    },
  );
  test('WC-07 state copy cannot clear a previous error or status', () {
    const state = WebClipBrowserState(
      currentUrl: 'https://example.com',
      errorMessage: 'Old error',
      statusMessage: 'Old status',
    );
    final reset = state.copyWith(
      errorMessage: null,
      statusMessage: null,
      loadingState: BrowserLoadingState.ready,
    );
    expect(reset.errorMessage, 'Old error');
    expect(reset.statusMessage, 'Old status');
    print(
      'WC-07 after clearing: error=${reset.errorMessage}, status=${reset.statusMessage}',
    );
  });
  test('WC-08 failed query image replaced with another query image', () async {
    final downloader = WebImageDownloader(
      attachmentService: fakes.FakeAttachmentService(),
      httpClient: MockClient(
        (request) async => request.url.query == 'id=one'
            ? http.Response('', 404)
            : http.Response.bytes(
                [255, 216, 255],
                200,
                headers: {'content-type': 'image/jpeg'},
              ),
      ),
    );
    final scan = scanFixture().copyWith(
      cleanedArticleHtml:
          '<article><p>Two distinct images</p><img src="https://example.com/image?id=one" alt="One"><img src="https://example.com/image?id=two" alt="Two"></article>',
      images: const [
        ClippedImageCandidate(
          rawUrl: 'https://example.com/image?id=one',
          resolvedUrl: 'https://example.com/image?id=one',
        ),
        ClippedImageCandidate(
          rawUrl: 'https://example.com/image?id=two',
          resolvedUrl: 'https://example.com/image?id=two',
        ),
      ],
    );
    final result =
        await WebClipperService(
          notesRepository: fakes.InMemoryNotesRepository(),
          imageDownloader: downloader,
        ).clipArticle(
          scanResult: scan,
          options: const WebClipperOptions(saveHtmlSnapshot: false),
        );
    expect(
      result.note.content,
      contains('![One](qp://asset/00000000-0000-0000-0000-000000000001)'),
    );
    expect(
      result.note.content,
      contains('![Two](qp://asset/00000000-0000-0000-0000-000000000001)'),
    );
    print('WC-08 image one=404, image two=200, both saved as same asset');
  });
  testWidgets('WC-09 browser success pops newly opened editor', (tester) async {
    final controller = CapturingController()..resetToReady();
    final recorder = RouteRecorder();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webClipperServiceProvider.overrideWithValue(FixedClipper()),
        ],
        child: MaterialApp(
          navigatorKey: key,
          navigatorObservers: [recorder],
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );
    unawaited(
      key.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/browser'),
          builder: (_) => WebClipBrowserScreen(
            initialUrl: 'https://example.com/article',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clip'));
    await tester.pumpAndSettle();
    expect(find.byType(WebClipPreviewSheet), findsOneWidget);
    await tester.tap(find.text('Clip').last);
    await tester.pumpAndSettle();
    print('WC-09 route events: ${recorder.events}');
    expect(recorder.events.last, 'pop:MaterialPageRoute<dynamic>');
    expect(find.byType(WebClipBrowserScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
  testWidgets(
    'WC-10 second share is discarded while first capture stays open',
    (tester) async {
      final db = AppDatabase.memory();
      final key = GlobalKey<NavigatorState>();
      QuickCaptureCoordinator.initialize(key);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            navigatorKey: key,
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      QuickCaptureCoordinator.openCapture(
        QuickCaptureNormalizer.normalize(
          origin: CaptureOrigin.share,
          rawText: 'https://example.com/first',
        ),
      );
      await tester.pumpAndSettle();
      QuickCaptureCoordinator.openCapture(
        QuickCaptureNormalizer.normalize(
          origin: CaptureOrigin.share,
          rawText: 'https://example.com/second',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('https://example.com/first'), findsOneWidget);
      expect(find.text('https://example.com/second'), findsNothing);
      print('WC-10 new unique second URL ignored; first URL remains');
      await tester.pumpWidget(const SizedBox.shrink());
      QuickCaptureCoordinator.dispose();
      await db.close();
    },
  );
}
```

## Existing share-entry tests

```text
00:00 +0: loading /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart
00:00 +0: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests handles empty and whitespace-only text gracefully
00:00 +1: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests normalizes plain text and preserves Unicode and line breaks
00:00 +2: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests handles URL-only content correctly
00:00 +3: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests extracts title hint from subject when distinct from content
00:00 +4: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests ignores subject if it is identical to URL or content
00:00 +5: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests avoids duplicating URL when text already contains it
00:00 +6: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests appends URL when text does not contain it
00:00 +7: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests caps oversized payload without crashing
00:00 +8: /home/dog/git/quitepaper/test/quick_capture/quick_capture_normalizer_test.dart: QuickCaptureNormalizer Tests preserves explicitSessionId and targetNoteId across retries
00:00 +9: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests renders all visual elements matching design specification
00:02 +10: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests automatically requests keyboard focus on mount
00:02 +11: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests save button is disabled for empty content and saves when text entered
00:02 +12: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests prefills shared URL and displays Clip full article action
00:02 +13: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests shows resume unfinished draft chip when earlier drafts exist
00:03 +14: /home/dog/git/quitepaper/test/quick_capture/quick_capture_screen_test.dart: QuickCaptureScreen Widget Tests renders cleanly on narrow viewports without overflow
00:03 +15: All tests passed!
```
