import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';

void main() {
  Widget buildWrapper(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Markdown Link Overflow Regression Tests', () {
    testWidgets('long URLs in bullet points render without RenderFlex overflow on narrow viewport', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const md = '''
Illustration by Claudine Hellmuth/POLITICO (iStock)

By [Marcia Brown](https://www.politico.com) and Steve Volk10/18/2026 07:00 AM EDT

* https://www.facebook.com/sharer/sharer.php?u=https://politi.co/4i7mFrp
* https://twitter.com/intent/tweet?url=https://politi.co/4i7mFrp&text=Maybe%20There%20Was%20an%20Egg%20Cartel%20After%20All&via=politico
* 
* 

Marcia Brown is a food and agriculture reporter for POLITICO
''';

      await tester.pumpWidget(
        buildWrapper(
          QuietMarkdownPreview(
            markdownData: md,
            onMarkdownChanged: (newMd) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('unbaked link preview fallback with long URL renders without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const md = '''
[https://www.facebook.com/sharer/sharer.php?u=https://politi.co/4i7mFrp&extra=query_parameters_very_long_url_to_exceed_screen_width](https://www.facebook.com/sharer/sharer.php?u=https://politi.co/4i7mFrp&extra=query_parameters_very_long_url_to_exceed_screen_width)
<!-- qp-link-preview:{"title":"","description":"","image":"","domain":"facebook.com"} -->
''';

      await tester.pumpWidget(
        buildWrapper(
          QuietMarkdownPreview(
            markdownData: md,
            onMarkdownChanged: (newMd) {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
