import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/sync/sync_api_client.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/version/app_version_provider.dart';
import 'package:quitepaper/features/onboarding/presentation/onboarding_screen.dart';
import 'package:quitepaper/features/settings/presentation/about_app_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncApiClient extends Fake implements SyncApiClient {
  @override
  String get baseUrl => 'https://quitepaper.vercel.app';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        syncApiClientProvider.overrideWithValue(_FakeSyncApiClient()),
        appVersionInfoProvider.overrideWithValue(
          const AppVersionInfo(
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: child,
      ),
    );
  }

  group('AboutAppScreen Welcome Tour Row Tests', () {
    testWidgets('Renders WELCOME TOUR section and "Show welcome tour" row',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(child: const AboutAppScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('WELCOME TOUR'), findsOneWidget);
      expect(find.text('Show welcome tour'), findsOneWidget);
      expect(
        find.text('Revisit the introduction and first-note tips.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-show-welcome-tour')),
        findsOneWidget,
      );
    });

    testWidgets('Tapping "Show welcome tour" opens OnboardingScreen in replay mode',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(child: const AboutAppScreen()),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const Key('settings-show-welcome-tour')),
      );
      await tester.tap(find.byKey(const Key('settings-show-welcome-tour')));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('A quiet place to think.'), findsOneWidget);
    });
  });
}
