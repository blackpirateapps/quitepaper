import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/utils/link_launcher_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LinkLauncherHelper Domain Extraction & Trust Tests', () {
    test('extractDomain correctly parses various URL structures', () {
      expect(
        LinkLauncherHelper.extractDomain('https://en.wikipedia.org/wiki/Flutter'),
        'en.wikipedia.org',
      );
      expect(
        LinkLauncherHelper.extractDomain('http://github.com/blackpirateapps/quitepaper?param=1&foo=bar'),
        'github.com',
      );
      expect(
        LinkLauncherHelper.extractDomain('subdomain.example.co.uk/path/to/resource'),
        'subdomain.example.co.uk',
      );
      expect(
        LinkLauncherHelper.extractDomain(''),
        isNull,
      );
    });

    test('trustDomain persists and isDomainTrusted returns correct status', () async {
      expect(await LinkLauncherHelper.isDomainTrusted('wikipedia.org'), isFalse);

      await LinkLauncherHelper.trustDomain('wikipedia.org');

      expect(await LinkLauncherHelper.isDomainTrusted('wikipedia.org'), isTrue);
      expect(await LinkLauncherHelper.isDomainTrusted('WIKIPEDIA.ORG'), isTrue);
      expect(await LinkLauncherHelper.isDomainTrusted('github.com'), isFalse);
    });
  });

  group('LinkConfirmationDialog Widget Tests', () {
    testWidgets('Renders full URL and allows toggling domain trust checkbox', (tester) async {
      const testUrl = 'https://docs.flutter.dev/development/ui/widgets/material?query=test';
      const testDomain = 'docs.flutter.dev';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [AppColors.light]),
          home: const Scaffold(
            body: LinkConfirmationDialog(
              url: testUrl,
              domain: testDomain,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Dialog header and description
      expect(find.text('Open External Link?'), findsOneWidget);
      expect(find.text('You are leaving Quiet Paper to open a web page.'), findsOneWidget);

      // Verify URL container renders full URL
      expect(find.text(testUrl), findsOneWidget);

      // Verify Trust Domain checkbox text
      expect(find.text('Trust links from $testDomain in the future'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Checkbox is initially false
      Checkbox checkbox = tester.widget(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      // Tap checkbox to toggle
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      checkbox = tester.widget(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Verify Cancel and Open Link buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Open Link'), findsOneWidget);
    });
  });
}
