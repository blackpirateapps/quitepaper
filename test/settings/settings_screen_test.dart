import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        backupServiceProvider.overrideWithValue(
          BackupService(
            database: db,
            cryptoService: DefaultCryptoService(),
            sharedPreferences: prefs,
          ),
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: [AppColors.light],
        ),
        home: child,
      ),
    );
  }

  testWidgets('SettingsScreen renders iOS grouped sections on phone layout', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 360 x 800 logical dp
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Top section headers
    expect(find.text('CLOUD SYNC & ENCRYPTION'), findsOneWidget);
    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('IMPORT'), findsOneWidget);

    // Grouped items in top sections
    expect(find.text('Set up Encrypted Sync'), findsOneWidget);
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('Light paper'), findsOneWidget);
    expect(find.text('Dark paper'), findsOneWidget);
    expect(find.text('Import Markdown Folder'), findsOneWidget);

    // Scroll to check Backup section
    await tester.scrollUntilVisible(
      find.text('Create Backup'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('LOCAL BACKUP & RESTORE'), findsOneWidget);
    expect(find.text('Create Backup'), findsOneWidget);
    expect(find.text('Restore Backup'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Daily Auto-Backup'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Daily Auto-Backup'), findsOneWidget);
    expect(find.byType(CupertinoSwitch), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Check for updates'),
      200.0,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('SAMPLE NOTES'), findsOneWidget);
    expect(find.text('Load sample notes'), findsOneWidget);
    expect(find.text('ABOUT'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('SettingsScreen renders centered grouped list on tablet layout', (tester) async {
    tester.view.physicalSize = const Size(1600, 2560);
    tester.view.devicePixelRatio = 2.0; // 800 x 1280 logical dp (Tablet)
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      createTestWidget(child: const SettingsScreen()),
    );
    await tester.pumpAndSettle();

    // Verify ConstrainedBox constraints for tablet
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.byWidgetPredicate((w) => w is ConstrainedBox && w.constraints.maxWidth == 680),
    );
    expect(constrainedBox.constraints.maxWidth, 680);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('CLOUD SYNC & ENCRYPTION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
