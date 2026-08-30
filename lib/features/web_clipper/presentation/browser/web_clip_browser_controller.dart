import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/web_clipper/web_capture_payload.dart';
import '../../../../core/web_clipper/web_capture_result.dart';

/// Loading and lifecycle states for the acquisition browser.
enum BrowserLoadingState {
  idle,
  opening,
  loading,
  ready,
  capturing,
  processing,
  success,
  error,
}

/// Immutable state for the in-app acquisition browser.
@immutable
class WebClipBrowserState {
  const WebClipBrowserState({
    required this.currentUrl,
    this.pageTitle = '',
    this.progress = 0.0,
    this.loadingState = BrowserLoadingState.opening,
    this.canGoBack = false,
    this.canGoForward = false,
    this.isSecure = true,
    this.errorMessage,
    this.statusMessage,
    this.generationId = 0,
    this.isTakingLong = false,
  });

  final String currentUrl;
  final String pageTitle;
  final double progress;
  final BrowserLoadingState loadingState;
  final bool canGoBack;
  final bool canGoForward;
  final bool isSecure;
  final String? errorMessage;
  final String? statusMessage;
  final int generationId;
  final bool isTakingLong;

  String get domain {
    final uri = Uri.tryParse(currentUrl);
    if (uri == null || uri.host.isEmpty) return 'Web Browser';
    return uri.host.replaceFirst(RegExp(r'^www\.'), '');
  }

  bool get isLoading =>
      loadingState == BrowserLoadingState.opening ||
      loadingState == BrowserLoadingState.loading;

  bool get isCapturingOrProcessing =>
      loadingState == BrowserLoadingState.capturing ||
      loadingState == BrowserLoadingState.processing;

  bool get canClip =>
      (loadingState == BrowserLoadingState.ready || isTakingLong) &&
      !isCapturingOrProcessing;

  WebClipBrowserState copyWith({
    String? currentUrl,
    String? pageTitle,
    double? progress,
    BrowserLoadingState? loadingState,
    bool? canGoBack,
    bool? canGoForward,
    bool? isSecure,
    String? errorMessage,
    String? statusMessage,
    int? generationId,
    bool? isTakingLong,
  }) {
    return WebClipBrowserState(
      currentUrl: currentUrl ?? this.currentUrl,
      pageTitle: pageTitle ?? this.pageTitle,
      progress: progress ?? this.progress,
      loadingState: loadingState ?? this.loadingState,
      canGoBack: canGoBack ?? this.canGoBack,
      canGoForward: canGoForward ?? this.canGoForward,
      isSecure: isSecure ?? this.isSecure,
      errorMessage: errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
      generationId: generationId ?? this.generationId,
      isTakingLong: isTakingLong ?? this.isTakingLong,
    );
  }
}

/// Controller managing WebViewController, page readiness evaluation,
/// monotonic request generations, safe navigation interception, and DOM capture.
class WebClipBrowserController extends ChangeNotifier {
  WebClipBrowserController({
    required String initialUrl,
    WebViewController? webViewController,
  }) : _state = WebClipBrowserState(
          currentUrl: _normalizeUrl(initialUrl),
          isSecure: _normalizeUrl(initialUrl).startsWith('https://'),
        ) {
    if (webViewController != null) {
      _controller = webViewController;
    } else if (!kIsWeb) {
      _initController();
    }
  }

  WebClipBrowserState _state;
  WebClipBrowserState get state => _state;

  WebViewController? _controller;
  WebViewController? get webViewController => _controller;

  Timer? _readinessTimer;
  Timer? _timeoutTimer;
  bool _isDisposed = false;

  /// Maximum safe captured HTML length (15MB).
  static const int maxHtmlSizeBytes = 15 * 1024 * 1024;

  static String _normalizeUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://google.com';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  void _initController() {
    try {
      final controller = WebViewController();
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);

      controller.setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (_isDisposed) return;
            _updateProgress(progress / 100.0);
          },
          onPageStarted: (String url) {
            if (_isDisposed) return;
            _onPageStarted(url);
          },
          onPageFinished: (String url) {
            if (_isDisposed) return;
            _onPageFinished(url);
          },
          onWebResourceError: (WebResourceError error) {
            if (_isDisposed) return;
            // Only flag main frame errors
            if (error.isForMainFrame ?? true) {
              _onResourceError(error);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            return _handleNavigationRequest(request);
          },
        ),
      );

      final uri = Uri.tryParse(_state.currentUrl);
      if (uri != null) {
        controller.loadRequest(uri);
      }

      _controller = controller;
    } catch (e) {
      if (e.toString().contains('WebViewPlatform.instance') ||
          e.toString().contains('A platform implementation for `webview_flutter` has not been set')) {
        // Test environment without WebViewPlatform implementation
        _state = _state.copyWith(
          loadingState: BrowserLoadingState.ready,
          errorMessage: null,
        );
        return;
      }
      _state = _state.copyWith(
        loadingState: BrowserLoadingState.error,
        errorMessage: 'Failed to initialize browser engine: $e',
      );
      notifyListeners();
    }
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final url = request.url.trim();
    final uri = Uri.tryParse(url);

    if (uri == null) {
      return NavigationDecision.prevent;
    }

    // 1. Allow standard HTTP and HTTPS web navigation
    if (uri.isScheme('http') || uri.isScheme('https')) {
      return NavigationDecision.navigate;
    }

    // 2. Safe external schemes (mailto, tel) - dispatch safely
    if (uri.isScheme('mailto') || uri.isScheme('tel') || uri.isScheme('sms')) {
      try {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return NavigationDecision.prevent;
    }

    // 3. Block arbitrary or dangerous schemes (javascript:, file:, intent:, custom protocols)
    debugPrint('Blocked unsupported URL navigation scheme: ${uri.scheme}');
    return NavigationDecision.prevent;
  }

  void _updateProgress(double progress) {
    _state = _state.copyWith(
      progress: progress,
      loadingState: progress >= 1.0
          ? (_state.loadingState == BrowserLoadingState.loading
              ? BrowserLoadingState.ready
              : _state.loadingState)
          : BrowserLoadingState.loading,
    );
    notifyListeners();
  }

  void _onPageStarted(String url) {
    _readinessTimer?.cancel();
    _timeoutTimer?.cancel();

    final nextGen = _state.generationId + 1;
    final isSecure = url.startsWith('https://');

    _state = _state.copyWith(
      currentUrl: url,
      progress: 0.1,
      loadingState: BrowserLoadingState.loading,
      errorMessage: null,
      statusMessage: null,
      generationId: nextGen,
      isSecure: isSecure,
      isTakingLong: false,
    );
    notifyListeners();

    // Start 15s timeout timer to offer "Clip Anyway" if page is slow to fire load events
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isDisposed || _state.generationId != nextGen) return;
      if (_state.loadingState == BrowserLoadingState.loading) {
        _state = _state.copyWith(isTakingLong: true);
        notifyListeners();
      }
    });
  }

  Future<void> _onPageFinished(String url) async {
    final currentGen = _state.generationId;
    _timeoutTimer?.cancel();

    // Check history navigation capabilities
    bool canBack = false;
    bool canFwd = false;
    if (_controller != null) {
      try {
        canBack = await _controller!.canGoBack();
        canFwd = await _controller!.canGoForward();
      } catch (_) {}
    }

    // Retrieve document title and readiness from DOM
    String docTitle = _state.pageTitle;
    if (_controller != null) {
      try {
        final titleResult = await _controller!.getTitle();
        if (titleResult != null && titleResult.trim().isNotEmpty) {
          docTitle = titleResult.trim();
        }
      } catch (_) {}
    }

    if (_isDisposed || _state.generationId != currentGen) return;

    _state = _state.copyWith(
      currentUrl: url,
      pageTitle: docTitle,
      progress: 1.0,
      loadingState: BrowserLoadingState.ready,
      canGoBack: canBack,
      canGoForward: canFwd,
      errorMessage: null,
    );
    notifyListeners();

    // Secondary readiness probe (150ms debounce to allow dynamic SPAs to populate title/DOM)
    _readinessTimer = Timer(const Duration(milliseconds: 300), () async {
      if (_isDisposed || _state.generationId != currentGen) return;
      await _probeReadiness(currentGen);
    });
  }

  Future<void> _probeReadiness(int expectedGen) async {
    if (_controller == null || _isDisposed || _state.generationId != expectedGen) {
      return;
    }

    try {
      final jsResult = await _controller!.runJavaScriptReturningResult('''
        (() => {
          try {
            return JSON.stringify({
              title: document.title || '',
              url: window.location.href || '',
              readyState: document.readyState
            });
          } catch(e) {
            return '{}';
          }
        })()
      ''');

      if (_isDisposed || _state.generationId != expectedGen) return;

      final rawString = _cleanJsReturn(jsResult.toString());
      final decoded = json.decode(rawString);
      if (decoded is Map<String, dynamic>) {
        final title = decoded['title'] as String?;
        final url = decoded['url'] as String?;
        if (title != null && title.trim().isNotEmpty && title != _state.pageTitle) {
          _state = _state.copyWith(pageTitle: title.trim());
          notifyListeners();
        }
        if (url != null && url.trim().isNotEmpty && url != _state.currentUrl) {
          _state = _state.copyWith(currentUrl: url.trim());
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  void _onResourceError(WebResourceError error) {
    // Only flag critical non-cancelation errors
    if (error.errorCode == -999) return; // NSURLErrorCancelled on iOS / WebKit
    _state = _state.copyWith(
      errorMessage: error.description,
      loadingState: BrowserLoadingState.error,
    );
    notifyListeners();
  }

  /// Navigates the browser to [newUrl].
  Future<void> navigateTo(String newUrl) async {
    final normalized = _normalizeUrl(newUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
      _state = _state.copyWith(
        errorMessage: 'Invalid URL. Only http:// and https:// are supported.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      currentUrl: normalized,
      errorMessage: null,
      loadingState: BrowserLoadingState.loading,
    );
    notifyListeners();

    if (_controller != null) {
      try {
        await _controller!.loadRequest(uri);
      } catch (e) {
        _state = _state.copyWith(
          errorMessage: 'Failed to load URL: $e',
          loadingState: BrowserLoadingState.error,
        );
        notifyListeners();
      }
    }
  }

  /// Reloads the current page.
  Future<void> reload() async {
    if (_controller != null) {
      try {
        await _controller!.reload();
      } catch (_) {}
    }
  }

  /// Navigates back in browser history.
  Future<void> goBack() async {
    if (_controller != null && await _controller!.canGoBack()) {
      await _controller!.goBack();
    }
  }

  /// Navigates forward in browser history.
  Future<void> goForward() async {
    if (_controller != null && await _controller!.canGoForward()) {
      await _controller!.goForward();
    }
  }

  /// Explicit user capture action.
  ///
  /// Extracts the complete DOM outerHTML, document.title, location.href, and OpenGraph/meta tags
  /// from the currently loaded page without persisting cookies or authentication credentials.
  Future<WebCaptureResult> captureCurrentPage() async {
    if (_state.isCapturingOrProcessing) {
      return const WebCaptureResult.failure(
        WebAcquisitionError(
          kind: WebAcquisitionErrorKind.cancelled,
          message: 'A capture request is already in progress.',
        ),
      );
    }

    final captureGen = _state.generationId;

    _state = _state.copyWith(
      loadingState: BrowserLoadingState.capturing,
      statusMessage: 'Capturing page content…',
      errorMessage: null,
    );
    notifyListeners();

    if (_controller == null) {
      _state = _state.copyWith(loadingState: BrowserLoadingState.ready);
      notifyListeners();
      return const WebCaptureResult.failure(
        WebAcquisitionError(
          kind: WebAcquisitionErrorKind.captureFailed,
          message: 'In-app browser engine is not available.',
        ),
      );
    }

    try {
      // Deterministic, minimal, safe DOM snapshot extraction script
      const captureScript = '''
        (() => {
          try {
            const doc = document.documentElement;
            const canonicalEl = document.querySelector('link[rel="canonical"]');
            const descEl = document.querySelector('meta[name="description"], meta[property="og:description"], meta[property="twitter:description"]');
            const authorEl = document.querySelector('meta[name="author"], meta[property="article:author"], meta[property="twitter:creator"]');
            const ogTitleEl = document.querySelector('meta[property="og:title"], meta[property="twitter:title"]');
            const pubDateEl = document.querySelector('meta[property="article:published_time"], meta[name="date"], meta[name="pubdate"]');
            
            return JSON.stringify({
              html: doc ? doc.outerHTML : (document.body ? document.body.outerHTML : ''),
              title: document.title || (ogTitleEl ? ogTitleEl.getAttribute('content') : '') || '',
              url: window.location.href || '',
              canonicalUrl: canonicalEl ? canonicalEl.href : null,
              description: descEl ? descEl.getAttribute('content') : null,
              author: authorEl ? authorEl.getAttribute('content') : null,
              publishedAt: pubDateEl ? pubDateEl.getAttribute('content') : null
            });
          } catch (e) {
            return JSON.stringify({
              html: document.documentElement ? document.documentElement.outerHTML : '',
              title: document.title || '',
              url: window.location.href || ''
            });
          }
        })()
      ''';

      final jsResult = await _controller!.runJavaScriptReturningResult(captureScript);

      // Race guard: verify page did not navigate away during JS execution
      if (_isDisposed || _state.generationId != captureGen) {
        return const WebCaptureResult.failure(
          WebAcquisitionError(
            kind: WebAcquisitionErrorKind.cancelled,
            message: 'Capture was cancelled because page navigated.',
          ),
        );
      }

      final rawOutput = _cleanJsReturn(jsResult.toString());
      final decoded = json.decode(rawOutput) as Map<String, dynamic>;

      final html = decoded['html'] as String? ?? '';
      final title = decoded['title'] as String? ?? _state.pageTitle;
      final finalUrl = decoded['url'] as String? ?? _state.currentUrl;
      final canonicalUrl = decoded['canonicalUrl'] as String?;
      final description = decoded['description'] as String?;
      final author = decoded['author'] as String?;
      final pubDateStr = decoded['publishedAt'] as String?;
      DateTime? publishedAt;
      if (pubDateStr != null && pubDateStr.isNotEmpty) {
        publishedAt = DateTime.tryParse(pubDateStr);
      }

      if (html.isEmpty) {
        _state = _state.copyWith(loadingState: BrowserLoadingState.ready);
        notifyListeners();
        return const WebCaptureResult.failure(
          WebAcquisitionError(
            kind: WebAcquisitionErrorKind.invalidContent,
            message: 'The page returned empty HTML content.',
          ),
        );
      }

      if (html.length > maxHtmlSizeBytes) {
        _state = _state.copyWith(loadingState: BrowserLoadingState.ready);
        notifyListeners();
        return const WebCaptureResult.failure(
          WebAcquisitionError(
            kind: WebAcquisitionErrorKind.invalidContent,
            message: 'This page is too large to clip automatically (> 15MB).',
          ),
        );
      }

      final payload = WebCapturePayload(
        requestedUrl: _state.currentUrl,
        finalUrl: finalUrl.isNotEmpty ? finalUrl : _state.currentUrl,
        html: html,
        pageTitle: title.isNotEmpty ? title : null,
        canonicalUrl: canonicalUrl,
        description: description,
        author: author,
        publishedAt: publishedAt,
        acquisitionMethod: WebAcquisitionMethod.inAppBrowser,
      );

      _state = _state.copyWith(
        loadingState: BrowserLoadingState.processing,
        statusMessage: 'Extracting article…',
      );
      notifyListeners();

      return WebCaptureResult.success(payload);
    } catch (e) {
      if (_isDisposed || _state.generationId != captureGen) {
        return const WebCaptureResult.failure(
          WebAcquisitionError(
            kind: WebAcquisitionErrorKind.cancelled,
            message: 'Capture cancelled.',
          ),
        );
      }

      _state = _state.copyWith(
        loadingState: BrowserLoadingState.ready,
        errorMessage: 'Capture failed: $e',
      );
      notifyListeners();

      return WebCaptureResult.failure(
        WebAcquisitionError(
          kind: WebAcquisitionErrorKind.captureFailed,
          message: 'Failed to extract page HTML: $e',
          underlyingError: e,
        ),
      );
    }
  }

  /// Restores browser to ready state when returning from preview sheet or after processing.
  void resetToReady() {
    if (_isDisposed) return;
    _state = _state.copyWith(
      loadingState: BrowserLoadingState.ready,
      statusMessage: null,
      errorMessage: null,
    );
    notifyListeners();
  }

  String _cleanJsReturn(String raw) {
    var str = raw.trim();
    if (str.startsWith('"') && str.endsWith('"') && str.length >= 2) {
      try {
        str = json.decode(str) as String;
      } catch (_) {
        str = str.substring(1, str.length - 1);
        str = str.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
      }
    }
    return str;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _readinessTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }
}
