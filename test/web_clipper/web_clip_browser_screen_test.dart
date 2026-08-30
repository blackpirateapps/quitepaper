import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_controller.dart';
import 'package:quitepaper/features/web_clipper/presentation/browser/web_clip_browser_screen.dart';

void main() {
  group('WebClipBrowserScreen Widget Tests', () {
    testWidgets('renders header, domain title, history buttons, and clip dock', (tester) async {
      final controller = WebClipBrowserController(initialUrl: 'https://example.com/mobile-article');
      controller.resetToReady();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: WebClipBrowserScreen(
              initialUrl: 'https://example.com/mobile-article',
              controller: controller,
            ),
          ),
        ),
      );

      // Verify domain and secure lock indicator in AppBar
      expect(find.text('example.com'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);

      // Verify bottom clip bar
      expect(find.text('Clip'), findsOneWidget);
      expect(find.text('Ready to clip content'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('tapping domain in header opens Navigate to URL dialog', (tester) async {
      final controller = WebClipBrowserController(initialUrl: 'https://example.com/article');
      controller.resetToReady();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: WebClipBrowserScreen(
              initialUrl: 'https://example.com/article',
              controller: controller,
            ),
          ),
        ),
      );

      await tester.tap(find.text('example.com'));
      await tester.pumpAndSettle();

      expect(find.text('Navigate to URL'), findsOneWidget);
      expect(find.text('https://example.com/article'), findsOneWidget);
      expect(find.text('Go'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Navigate to URL'), findsNothing);

      controller.dispose();
    });

    testWidgets('overflow menu displays actions including Page Info, Copy URL, Reload', (tester) async {
      final controller = WebClipBrowserController(initialUrl: 'https://example.com/post');
      controller.resetToReady();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: WebClipBrowserScreen(
              initialUrl: 'https://example.com/post',
              controller: controller,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Reload'), findsOneWidget);
      expect(find.text('External Browser'), findsOneWidget);
      expect(find.text('Copy URL'), findsOneWidget);
      expect(find.text('Page Info'), findsOneWidget);
      expect(find.text('Close Browser'), findsOneWidget);

      // Tap Page Info
      await tester.tap(find.text('Page Info'));
      await tester.pumpAndSettle();

      expect(find.text('Page Info'), findsOneWidget);
      expect(find.text('DOMAIN'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      controller.dispose();
    });
  });
}
