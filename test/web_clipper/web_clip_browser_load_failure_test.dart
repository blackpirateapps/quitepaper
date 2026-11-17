import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_controller.dart';

class NativeDelegate extends PlatformNavigationDelegate {
  NativeDelegate(super.params) : super.implementation();
  late PageEventCallback started;
  late PageEventCallback finished;
  late ProgressCallback progress;
  late WebResourceErrorCallback error;
  @override
  Future<void> setOnPageStarted(PageEventCallback callback) async =>
      started = callback;
  @override
  Future<void> setOnPageFinished(PageEventCallback callback) async =>
      finished = callback;
  @override
  Future<void> setOnProgress(ProgressCallback callback) async =>
      progress = callback;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback callback) async =>
      error = callback;
  @override
  Future<void> setOnNavigationRequest(
    NavigationRequestCallback callback,
  ) async {}
}

class NativeController extends PlatformWebViewController {
  NativeController(super.params) : super.implementation();
  Completer<String?>? pendingTitle;
  Completer<Object>? pendingProbe;
  String probeUrl = 'https://example.com/recovered';
  @override
  Future<void> setJavaScriptMode(JavaScriptMode mode) async {}
  @override
  Future<void> setPlatformNavigationDelegate(
    PlatformNavigationDelegate handler,
  ) async {}
  @override
  Future<void> loadRequest(LoadRequestParams params) async {}
  @override
  Future<void> reload() async {}
  @override
  Future<bool> canGoBack() async => false;
  @override
  Future<bool> canGoForward() async => false;
  @override
  Future<String?> getTitle() =>
      pendingTitle?.future ?? Future.value('Loaded page');
  @override
  Future<Object> runJavaScriptReturningResult(String script) =>
      pendingProbe?.future ??
      Future.value(
        '{"title":"Loaded page","url":"$probeUrl","readyState":"complete"}',
      );
}

class NativePlatform extends WebViewPlatform {
  late NativeDelegate delegate;
  late NativeController controller;
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(
    PlatformNavigationDelegateCreationParams params,
  ) => delegate = NativeDelegate(params);
  @override
  PlatformWebViewController createPlatformWebViewController(
    PlatformWebViewControllerCreationParams params,
  ) => controller = NativeController(params);
}

void main() {
  late NativePlatform native;
  late WebClipBrowserController browser;
  setUp(() {
    native = NativePlatform();
    WebViewPlatform.instance = native;
    browser = WebClipBrowserController(initialUrl: 'http://example.com/failed');
  });
  tearDown(() => browser.dispose());

  void fail() => native.delegate.error(
    const WebResourceError(
      errorCode: -1,
      description: 'net::ERR_CLEARTEXT_NOT_PERMITTED',
      isForMainFrame: true,
    ),
  );

  testWidgets(
    'main-frame error survives progress, internal start and page-finished callbacks',
    (tester) async {
      native.delegate.started('http://example.com/failed');
      await tester.pump(const Duration(seconds: 16));
      expect(
        browser.state.canClip,
        isTrue,
        reason: 'slow loading can offer Clip Anyway',
      );
      fail();
      native.delegate.progress(10);
      native.delegate.progress(100);
      native.delegate.started('chrome-error://chromewebdata/');
      native.delegate.finished('chrome-error://chromewebdata/');
      native.delegate.finished('http://example.com/failed');
      await tester.pump(const Duration(seconds: 1));
      expect(browser.state.loadingState, BrowserLoadingState.error);
      expect(browser.state.currentUrl, 'http://example.com/failed');
      expect(browser.state.errorMessage, contains('CLEARTEXT'));
      expect(browser.state.canClip, isFalse);
      expect(browser.state.isTakingLong, isFalse);
      expect((await browser.captureCurrentPage()).isSuccess, isFalse);
      browser.resetToReady();
      expect(browser.state.loadingState, BrowserLoadingState.error);

      await browser.reload();
      expect(browser.state.loadingState, BrowserLoadingState.loading);
      expect(browser.state.errorMessage, isNull);
      native.delegate.started('https://example.com/recovered');
      native.delegate.finished('https://example.com/recovered');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(browser.state.loadingState, BrowserLoadingState.ready);
      expect(browser.state.canClip, isTrue);
      expect(browser.state.currentUrl, 'https://example.com/recovered');
      expect(browser.state.errorMessage, isNull);
    },
  );

  testWidgets(
    'error arriving during page-finished title lookup remains failed',
    (tester) async {
      native.delegate.started('http://example.com/failed');
      native.controller.pendingTitle = Completer<String?>();
      native.delegate.finished('http://example.com/failed');
      await tester.pump();
      fail();
      native.controller.pendingTitle!.complete('Error document');
      await tester.pump(const Duration(seconds: 1));
      expect(browser.state.loadingState, BrowserLoadingState.error);
      expect(browser.state.canClip, isFalse);
      expect(browser.state.pageTitle, isNot('Error document'));
    },
  );

  testWidgets('pending readiness probe cannot overwrite a main-frame failure', (
    tester,
  ) async {
    native.delegate.started('http://example.com/failed');
    native.controller.pendingProbe = Completer<Object>();
    native.delegate.finished('http://example.com/failed');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    fail();
    native.controller.pendingProbe!.complete(
      '{"url":"chrome-error://chromewebdata/","title":"Error page"}',
    );
    await tester.pump();
    expect(browser.state.loadingState, BrowserLoadingState.error);
    expect(browser.state.currentUrl, 'http://example.com/failed');
    expect(browser.state.pageTitle, isNot('Error page'));
  });

  testWidgets('subframe and cancelled resource errors do not fail the page', (
    tester,
  ) async {
    native.delegate.started('https://example.com/recovered');
    native.delegate.error(
      const WebResourceError(
        errorCode: -1,
        description: 'Image failed',
        isForMainFrame: false,
      ),
    );
    native.delegate.error(
      const WebResourceError(
        errorCode: -999,
        description: 'Cancelled',
        isForMainFrame: true,
      ),
    );
    native.delegate.finished('https://example.com/recovered');
    await tester.pump();
    expect(browser.state.loadingState, BrowserLoadingState.ready);
    expect(browser.state.errorMessage, isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
    'readiness ignores internal Chromium URLs and navigation clears old failure',
    (tester) async {
      native.delegate.started('http://example.com/failed');
      fail();
      await browser.navigateTo('https://example.com/recovered');
      native.controller.probeUrl = 'chrome-error://chromewebdata/';
      native.delegate.finished('https://example.com/recovered');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(browser.state.currentUrl, 'https://example.com/recovered');
      expect(browser.state.errorMessage, isNull);
    },
  );
}
