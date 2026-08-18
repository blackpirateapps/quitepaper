import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/update/update_dialog.dart';
import 'package:quitepaper/core/update/update_models.dart';
import 'package:quitepaper/core/update/update_provider.dart';
import 'package:quitepaper/core/update/update_service.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final testRelease = AppReleaseInfo(
    version: '1.3.0',
    tagName: 'v1.3.0',
    title: 'Quiet Paper v1.3.0',
    releaseNotes: '### New in v1.3.0\n- Auto update engine\n- Performance improvements',
    publishedAt: DateTime.now(),
    apkUrl: 'https://example.com/quiet-paper-1.3.0-arm64-v8a.apk',
    apkFileName: 'quiet-paper-1.3.0-arm64-v8a.apk',
    apkSizeBytes: 22521725,
    architecture: 'arm64-v8a',
    htmlUrl: 'https://github.com/blackpirateapps/quitepaper/releases/tag/v1.3.0',
  );

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        updateServiceProvider.overrideWithValue(
          UpdateService(
            sharedPreferences: prefs,
            currentVersion: '1.2.0',
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('UpdateDialog renders version info, release notes, and snooze checkbox', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: UpdateDialog(
          release: testRelease,
          currentVersion: '1.2.0',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify header and versions
    expect(find.text('Update Available'), findsOneWidget);
    expect(find.text('Quiet Paper v1.3.0'), findsOneWidget);
    expect(find.text('v1.2.0  →  v1.3.0'), findsOneWidget);
    expect(find.text('arm64-v8a • 21.5 MB'), findsOneWidget);

    // Verify release notes
    expect(find.text("What's New"), findsOneWidget);
    expect(find.textContaining('Auto update engine'), findsOneWidget);

    // Verify 30-day snooze checkbox
    expect(find.text("Don't remind me for 30 days"), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
  });

  testWidgets('Tapping Later without checkbox dismisses without snoozing', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UpdateDialog.show(context, testRelease),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsOneWidget);

    // Tap Later
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    // Dialog closed
    expect(find.text('Update Available'), findsNothing);

    // Not snoozed
    final service = UpdateService(sharedPreferences: prefs);
    expect(service.isSnoozed('1.3.0'), isFalse);
  });

  testWidgets('Tapping Later with 30-day checkbox snoozes prompts for 30 days', (tester) async {
    await tester.pumpWidget(
      createTestWidget(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UpdateDialog.show(context, testRelease),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Tap Checkbox
    await tester.tap(find.text("Don't remind me for 30 days"));
    await tester.pumpAndSettle();

    // Tap Later
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(find.text('Update Available'), findsNothing);

    // Snoozed
    final service = UpdateService(sharedPreferences: prefs);
    expect(service.isSnoozed('1.3.0'), isTrue);
  });
}
