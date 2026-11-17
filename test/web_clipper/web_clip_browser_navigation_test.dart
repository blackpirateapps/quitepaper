import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/web_clipper/web_capture_payload.dart';
import 'package:quitepaper/core/web_clipper/web_capture_result.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_provider.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/features/editor/presentation/editor_screen.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_controller.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_screen.dart';
import 'package:quitepaper/features/web_clipper/presentation/web_clip_preview_sheet.dart';
import 'web_clipper_service_test.dart' as fakes;

class CapturingController extends WebClipBrowserController {
  CapturingController() : super(initialUrl: 'https://example.com/article');
  @override
  Future<WebCaptureResult> captureCurrentPage() async =>
      WebCaptureResult.success(
        WebCapturePayload(
          requestedUrl: state.currentUrl,
          finalUrl: state.currentUrl,
          html: '<article><p>Saved article body.</p></article>',
        ),
      );
}

class FixedClipper extends WebClipperService {
  FixedClipper() : super(notesRepository: fakes.InMemoryNotesRepository());
  @override
  Future<WebClipScanResult> scanPayload(
    WebCapturePayload payload, {
    bool allowFallback = true,
  }) async => const WebClipScanResult(
    metadata: ExtractedArticleMetadata(
      sourceUrl: 'https://example.com/article',
      title: 'Saved Article',
      domain: 'example.com',
    ),
    rawHtml: '',
    cleanedArticleHtml: '',
    markdownBody: 'Saved article body.',
    markdownSizeEstimate: 10,
    htmlSnapshotSizeEstimate: 0,
    images: [],
  );
  @override
  Future<({Note note, DocumentEntity? snapshotDocument})> clipArticle({
    required WebClipScanResult scanResult,
    required WebClipperOptions options,
    void Function(WebClipProgress)? onProgress,
  }) async => (
    note: Note(
      id: 'saved-note',
      title: 'Saved Article',
      content: 'Saved article body.',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    snapshotDocument: null,
  );
}

class RouteRecorder extends NavigatorObserver {
  final popped = <Route<dynamic>>[];
  Route<dynamic>? replacement;
  Route<dynamic>? replaced;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      popped.add(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacement = newRoute;
    replaced = oldRoute;
  }
}

void main() {
  testWidgets(
    'browser save replaces browser with editor without popping editor',
    (tester) async {
      final controller = CapturingController()..resetToReady();
      final observer = RouteRecorder();
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            webClipperServiceProvider.overrideWithValue(FixedClipper()),
          ],
          child: MaterialApp(
            navigatorKey: key,
            navigatorObservers: [observer],
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      final browser = MaterialPageRoute<Note?>(
        builder: (_) => WebClipBrowserScreen(
          initialUrl: 'https://example.com/article',
          controller: controller,
        ),
      );
      unawaited(key.currentState!.push(browser));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clip'));
      await tester.pumpAndSettle();
      expect(find.byType(WebClipPreviewSheet), findsOneWidget);
      await tester.tap(find.text('Clip').last);
      await tester.idle();
      expect(observer.replaced, browser);
      final editorRoute = observer.replacement! as MaterialPageRoute<void>;
      final editor = editorRoute.builder(key.currentContext!) as EditorScreen;
      expect(editor.note.id, 'saved-note');
      expect(observer.popped, hasLength(1));
      expect(observer.popped.single, isNot(editorRoute));
      expect(controller.state.isCapturingOrProcessing, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );
}
