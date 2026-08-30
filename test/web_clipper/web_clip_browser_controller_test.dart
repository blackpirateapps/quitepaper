import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_capture_result.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_controller.dart';

void main() {
  group('WebClipBrowserController', () {
    test('initializes with normalized URL and default state', () {
      final controller = WebClipBrowserController(initialUrl: 'example.com/tech-article');

      expect(controller.state.currentUrl, 'https://example.com/tech-article');
      expect(controller.state.domain, 'example.com');
      expect(controller.state.isSecure, isTrue);
      expect(
        controller.state.loadingState == BrowserLoadingState.opening ||
            controller.state.loadingState == BrowserLoadingState.ready,
        isTrue,
      );
      expect(controller.state.canGoBack, isFalse);
      expect(controller.state.canGoForward, isFalse);
      expect(controller.state.generationId, 0);

      controller.dispose();
    });

    test('normalizes http vs https URLs and strips www prefix from domain display', () {
      final controller = WebClipBrowserController(initialUrl: 'http://www.sub.blog.org/path');

      expect(controller.state.currentUrl, 'http://www.sub.blog.org/path');
      expect(controller.state.domain, 'sub.blog.org');
      expect(controller.state.isSecure, isFalse);

      controller.dispose();
    });

    test('resetToReady restores ready state and clears transient messages', () {
      final controller = WebClipBrowserController(initialUrl: 'https://example.com');

      controller.resetToReady();

      expect(controller.state.loadingState, BrowserLoadingState.ready);
      expect(controller.state.statusMessage, isNull);
      expect(controller.state.errorMessage, isNull);

      controller.dispose();
    });

    test('captureCurrentPage rejects when browser engine is not available', () async {
      final controller = WebClipBrowserController(initialUrl: 'https://example.com');

      final result = await controller.captureCurrentPage();

      expect(result.isSuccess, isFalse);
      expect(result.error, isNotNull);
      expect(result.error!.kind, WebAcquisitionErrorKind.captureFailed);

      controller.dispose();
    });

    test('WebClipBrowserState computed properties', () {
      const stateLoading = WebClipBrowserState(
        currentUrl: 'https://example.com',
        loadingState: BrowserLoadingState.loading,
      );
      expect(stateLoading.isLoading, isTrue);
      expect(stateLoading.isCapturingOrProcessing, isFalse);
      expect(stateLoading.canClip, isFalse);

      const stateReady = WebClipBrowserState(
        currentUrl: 'https://example.com',
        loadingState: BrowserLoadingState.ready,
      );
      expect(stateReady.isLoading, isFalse);
      expect(stateReady.isCapturingOrProcessing, isFalse);
      expect(stateReady.canClip, isTrue);

      const stateTakingLong = WebClipBrowserState(
        currentUrl: 'https://example.com',
        loadingState: BrowserLoadingState.loading,
        isTakingLong: true,
      );
      expect(stateTakingLong.canClip, isTrue);

      const stateCapturing = WebClipBrowserState(
        currentUrl: 'https://example.com',
        loadingState: BrowserLoadingState.capturing,
      );
      expect(stateCapturing.isCapturingOrProcessing, isTrue);
      expect(stateCapturing.canClip, isFalse);
    });

    test('WebCapturePayload model fields and effectiveUrl', () {
      final payload = WebCapturePayload(
        requestedUrl: 'https://example.com/a',
        finalUrl: 'https://example.com/article/1',
        html: '<html><body><article><p>Hello</p></article></body></html>',
        pageTitle: 'Test Article',
        canonicalUrl: 'https://example.com/canonical-url',
        description: 'Test Description',
        author: 'Jane Doe',
        publishedAt: DateTime(2026, 8, 30),
      );

      expect(payload.effectiveUrl, 'https://example.com/canonical-url');
      expect(payload.htmlByteSize, greaterThan(0));
      expect(payload.acquisitionMethod, WebAcquisitionMethod.inAppBrowser);

      final copy = payload.copyWith(pageTitle: 'Updated Title');
      expect(copy.pageTitle, 'Updated Title');
      expect(copy.author, 'Jane Doe');
    });

    test('WebAcquisitionError toString formats message', () {
      const err = WebAcquisitionError(
        kind: WebAcquisitionErrorKind.networkFailure,
        message: 'Device is offline',
        statusCode: 0,
      );

      expect(err.toString(), 'Device is offline');
      expect(err.kind, WebAcquisitionErrorKind.networkFailure);
    });
  });
}
