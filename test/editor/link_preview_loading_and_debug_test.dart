import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/web_clipper/link_fetch_diagnostics.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';
import 'package:quitepaper/features/editor/application/quiet_super_editor_controller.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/link_preview_debug_card.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/link_preview_loading_card.dart';
import 'package:quitepaper/features/editor/presentation/widgets/super_editor/quiet_link_preview_component.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  group('LinkPreviewNode & Serialization Tests', () {
    test('serializes as plain link without sentinel comment when status is loading', () {
      final node = LinkPreviewNode(
        id: 'node-1',
        url: 'https://flutter.dev',
        title: 'Flutter - Build apps for any screen',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.loading,
      );

      final doc = MutableDocument(nodes: [node]);
      const serializer = LinkPreviewNodeSerializer();
      final serialized = serializer.doSerialization(doc, node);

      expect(serialized, equals('[Flutter - Build apps for any screen](https://flutter.dev)'));
      expect(isLinkPreviewComment(serialized), isFalse);
    });

    test('serializes as plain link without sentinel comment when status is failed', () {
      final node = LinkPreviewNode(
        id: 'node-2',
        url: 'https://broken-link.com',
        title: 'https://broken-link.com',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.failed,
        diagnostics: LinkFetchDiagnostics(
          url: 'https://broken-link.com',
          timestamp: DateTime(2026, 10, 19),
          stage: LinkFetchStage.pageFetch,
          reason: '404 Not Found',
          httpStatusCode: 404,
        ),
      );

      final doc = MutableDocument(nodes: [node]);
      const serializer = LinkPreviewNodeSerializer();
      final serialized = serializer.doSerialization(doc, node);

      expect(serialized, equals('[https://broken-link.com](https://broken-link.com)'));
      expect(isLinkPreviewComment(serialized), isFalse);
    });

    test('serializes with sentinel comment when status is loaded', () {
      final node = LinkPreviewNode(
        id: 'node-3',
        url: 'https://flutter.dev',
        title: 'Flutter',
        description: 'Multi-platform UI toolkit',
        siteName: 'flutter.dev',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.loaded,
      );

      final doc = MutableDocument(nodes: [node]);
      const serializer = LinkPreviewNodeSerializer();
      final serialized = serializer.doSerialization(doc, node);

      final lines = serialized.split('\n');
      expect(lines.first, equals('[Flutter](https://flutter.dev)'));
      expect(isLinkPreviewComment(lines[1]), isTrue);
    });
  });

  group('LinkPreviewLoadingCard Widget Tests', () {
    testWidgets('renders skeleton loader with domain and animated indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: LinkPreviewLoadingCard(
              url: 'https://news.ycombinator.com/item?id=123',
              title: 'Hacker News Item',
            ),
          ),
        ),
      );

      expect(find.text('news.ycombinator.com'), findsOneWidget);
      expect(find.text('•  Fetching preview…'), findsOneWidget);
      expect(find.text('Hacker News Item'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);

      // Verify smooth ticker animation advances without exceptions
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));
    });
  });

  group('LinkPreviewDebugCard Widget Tests', () {
    testWidgets('renders diagnostics, expands details, and triggers actions', (tester) async {
      final diagnostics = LinkFetchDiagnostics(
        url: 'https://api.github.com/blocked',
        timestamp: DateTime(2026, 10, 19, 12, 0),
        stage: LinkFetchStage.pageFetch,
        reason: 'Server returned HTTP 403 Forbidden (Anti-bot challenge)',
        httpStatusCode: 403,
        httpStatusReason: 'Forbidden',
        contentType: 'text/html',
        duration: const Duration(milliseconds: 312),
        rawException: 'HttpException: 403',
        leadImageUrl: 'https://github.githubassets.com/thumb.png',
        leadImageStatusCode: 404,
      );

      var retried = false;
      var converted = false;
      var removed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LinkPreviewDebugCard(
              diagnostics: diagnostics,
              onRetry: () => retried = true,
              onConvertToLink: () => converted = true,
              onRemove: () => removed = true,
            ),
          ),
        ),
      );

      // Verify header and badges
      expect(find.text('Link Preview Fetch Failed — api.github.com'), findsOneWidget);
      expect(find.text('Stage: Network Request'), findsOneWidget);
      expect(find.text('HTTP 403 Forbidden'), findsOneWidget);
      expect(find.text('312ms'), findsOneWidget);
      expect(find.text('Server returned HTTP 403 Forbidden (Anti-bot challenge)'), findsOneWidget);

      // Expand technical details
      expect(find.text('URL:'), findsNothing);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('URL:'), findsOneWidget);
      expect(find.text('https://api.github.com/blocked'), findsOneWidget);
      expect(find.text('Content-Type:'), findsOneWidget);
      expect(find.text('Exception:'), findsOneWidget);

      // Tap Retry action
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);

      // Tap Plain Link action
      await tester.tap(find.text('Plain Link'));
      expect(converted, isTrue);

      // Tap Remove action
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(removed, isTrue);

      // Tap Copy Info
      await tester.tap(find.text('Copy Info'));
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('Settings LinkPreviewDebugNotifier Tests', () {
    test('defaults to true and persists toggled value to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = LinkPreviewDebugNotifier(prefs);
      expect(notifier.state, isTrue);

      await notifier.set(false);
      expect(notifier.state, isFalse);
      expect(prefs.getBool('app_link_preview_debug'), isFalse);

      await notifier.set(true);
      expect(notifier.state, isTrue);
      expect(prefs.getBool('app_link_preview_debug'), isTrue);
    });
  });

  group('LinkPreviewComponent State & Super Editor Tests', () {
    testWidgets('renders LinkPreviewLoadingCard when node.status is loading', (tester) async {
      final node = LinkPreviewNode(
        id: 'loading-node',
        url: 'https://flutter.dev',
        title: 'Flutter',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.loading,
      );

      final document = MutableDocument(nodes: [node]);
      final editor = createDefaultDocumentEditor(document: document, composer: MutableDocumentComposer());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smartWebLinksProvider.overrideWith((ref) => SmartWebLinksNotifier(null)..state = true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: LinkPreviewComponent(
                componentKey: GlobalKey(),
                node: node,
                editor: editor,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinkPreviewLoadingCard), findsOneWidget);
      expect(find.text('flutter.dev'), findsOneWidget);
    });

    testWidgets('renders LinkPreviewDebugCard when node.status is failed and debug is enabled', (tester) async {
      final diagnostics = LinkFetchDiagnostics(
        url: 'https://example.com/bad',
        timestamp: DateTime(2026, 10, 19),
        stage: LinkFetchStage.pageFetch,
        reason: 'HTTP 404 Not Found',
        httpStatusCode: 404,
      );

      final node = LinkPreviewNode(
        id: 'failed-node',
        url: 'https://example.com/bad',
        title: 'https://example.com/bad',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.failed,
        diagnostics: diagnostics,
      );

      final document = MutableDocument(nodes: [node]);
      final editor = createDefaultDocumentEditor(document: document, composer: MutableDocumentComposer());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smartWebLinksProvider.overrideWith((ref) => SmartWebLinksNotifier(null)..state = true),
            linkPreviewDebugProvider.overrideWith((ref) => LinkPreviewDebugNotifier(null)..state = true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: LinkPreviewComponent(
                componentKey: GlobalKey(),
                node: node,
                editor: editor,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinkPreviewDebugCard), findsOneWidget);
      expect(find.text('Link Preview Fetch Failed — example.com'), findsOneWidget);
      expect(find.text('HTTP 404 Not Found'), findsOneWidget);
    });

    testWidgets('falls back to plain inline link when node.status is failed and debug is toggled OFF', (tester) async {
      final diagnostics = LinkFetchDiagnostics(
        url: 'https://example.com/bad',
        timestamp: DateTime(2026, 10, 19),
        stage: LinkFetchStage.pageFetch,
        reason: 'HTTP 404 Not Found',
        httpStatusCode: 404,
      );

      final node = LinkPreviewNode(
        id: 'failed-node-quiet',
        url: 'https://example.com/bad',
        title: 'https://example.com/bad',
        fetchedAt: DateTime(2026, 10, 19),
        status: LinkPreviewStatus.failed,
        diagnostics: diagnostics,
      );

      final document = MutableDocument(nodes: [node]);
      final editor = createDefaultDocumentEditor(document: document, composer: MutableDocumentComposer());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            smartWebLinksProvider.overrideWith((ref) => SmartWebLinksNotifier(null)..state = true),
            linkPreviewDebugProvider.overrideWith((ref) => LinkPreviewDebugNotifier(null)..state = false),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: LinkPreviewComponent(
                componentKey: GlobalKey(),
                node: node,
                editor: editor,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(LinkPreviewDebugCard), findsNothing);
      expect(find.text('https://example.com/bad'), findsOneWidget);
    });

    test('QuietSuperEditorController.insertLinkPreview inserts LinkPreviewNode in loading status', () {
      final controller = QuietSuperEditorController();
      final document = MutableDocument(nodes: [
        ParagraphNode(id: 'para-1', text: AttributedText('')),
      ]);
      final composer = MutableDocumentComposer();
      final editor = createDefaultDocumentEditor(document: document, composer: composer);

      controller.attach(editor, composer);
      controller.insertLinkPreview(url: 'https://flutter.dev');

      final previewNode = document.whereType<LinkPreviewNode>().firstOrNull;
      expect(previewNode, isNotNull);
      expect(previewNode!.url, equals('https://flutter.dev'));
      expect(previewNode.status, equals(LinkPreviewStatus.loading));
    });
  });
}
