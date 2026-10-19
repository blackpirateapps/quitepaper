import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/core/web_clipper/link_title_fetcher.dart';
import 'package:quitepaper/features/editor/presentation/widgets/link_enhance_button.dart';
import 'package:quitepaper/features/editor/presentation/widgets/link_prompt_dialog.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';

void main() {
  Widget wrapWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(child: child),
      ),
    );
  }

  group('LinkEnhanceButton Tests', () {
    testWidgets('renders sparkle icon in idle state', (tester) async {
      await tester.pumpWidget(
        wrapWidget(
          LinkEnhanceButton(
            url: 'https://example.com',
            onEnhanced: (_) async {},
          ),
        ),
      );

      expect(find.byIcon(PhosphorIconsRegular.sparkle), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tap triggers fetch, displays spinner, and fires onEnhanced', (tester) async {
      String? enhancedTitle;
      final completer = Completer<http.Response>();
      final mockClient = MockClient((request) async {
        return completer.future;
      });
      final fetcher = LinkTitleFetcher(client: mockClient);

      await tester.pumpWidget(
        wrapWidget(
          LinkEnhanceButton(
            url: 'https://example.com',
            titleFetcher: fetcher,
            onEnhanced: (title) async {
              enhancedTitle = title;
            },
          ),
        ),
      );

      final button = find.byType(LinkEnhanceButton);
      await tester.tap(button);
      await tester.pump();

      // Should show progress indicator while fetching
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        http.Response(
          '<html><head><title>Example Domain</title></head><body></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );

      // Settle async fetch
      await tester.pumpAndSettle();

      expect(enhancedTitle, equals('Example Domain'));
      // Returns to idle icon
      expect(find.byIcon(PhosphorIconsRegular.sparkle), findsOneWidget);
    });

    testWidgets('shows snackbar when fetch returns no title', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>No title here</body></html>', 200,
            headers: {'content-type': 'text/html'});
      });
      final fetcher = LinkTitleFetcher(client: mockClient);

      await tester.pumpWidget(
        wrapWidget(
          LinkEnhanceButton(
            url: 'https://example.com',
            titleFetcher: fetcher,
            onEnhanced: (_) async {},
          ),
        ),
      );

      await tester.tap(find.byType(LinkEnhanceButton));
      await tester.pumpAndSettle();

      expect(find.text('Could not fetch title for link'), findsOneWidget);
    });
  });

  group('LinkPromptDialog Suffix Sparkle Tests', () {
    testWidgets('clicking sparkle suffix fetches title into title input field', (tester) async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '<html><head><title>Quiet Paper Docs</title></head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final fetcher = LinkTitleFetcher(client: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LinkPromptDialog(
              initialUrl: 'https://quietpaper.org/docs',
              initialTitle: '',
              titleFetcher: fetcher,
            ),
          ),
        ),
      );

      // Verify the sparkle icon is present in the Link Text field
      final sparkleIcon = find.byIcon(PhosphorIconsRegular.sparkle);
      expect(sparkleIcon, findsOneWidget);

      await tester.tap(sparkleIcon);
      await tester.pumpAndSettle();

      // Title field should be updated with fetched title
      expect(find.text('Quiet Paper Docs'), findsOneWidget);
    });
  });

  group('MarkdownPreview WebLinkElementBuilder Tests', () {
    testWidgets('renders LinkEnhanceButton and updates markdown when enhanced', (tester) async {
      String? updatedMarkdown;
      final mockClient = MockClient((request) async {
        return http.Response(
          '<html><head><title>Flutter Awesome</title></head></html>',
          200,
          headers: {'content-type': 'text/html'},
        );
      });
      final fetcher = LinkTitleFetcher(client: mockClient);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: QuietMarkdownPreview(
                markdownData: 'Check out [my link](https://flutter.dev) for details.',
                titleFetcher: fetcher,
                onMarkdownChanged: (newMd) {
                  updatedMarkdown = newMd;
                },
              ),
            ),
          ),
        ),
      );

      // Sparkle button is rendered for the link
      final sparkle = find.byIcon(PhosphorIconsRegular.sparkle);
      expect(sparkle, findsOneWidget);
      expect(find.text('my link'), findsOneWidget);

      await tester.tap(sparkle);
      await tester.pumpAndSettle();

      expect(updatedMarkdown, equals('Check out [Flutter Awesome](https://flutter.dev) for details.'));
    });
  });
}
