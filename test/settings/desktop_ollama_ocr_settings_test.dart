import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/flavor/app_flavor.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/update/update_provider.dart';
import 'package:quitepaper/core/update/update_service.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/general_advanced_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncEngine implements SyncEngine {
  final _controller = StreamController<SyncState>.broadcast();

  @override
  SyncState get state => const SyncState(status: SyncStatus.localOnly);

  @override
  Stream<SyncState> get stateStream => _controller.stream;

  @override
  void dispose() {
    _controller.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;
  late _FakeSyncEngine fakeSyncEngine;

  group('Desktop OCR (Ollama) Settings Widget Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'quietpaper_ollama_ocr_enabled': true,
        'quietpaper_ollama_ocr_endpoint': 'http://127.0.0.1:11434',
        'quietpaper_ollama_ocr_model': 'deepseek-ocr',
      });
      FlutterSecureStorage.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.memory();
      fakeSyncEngine = _FakeSyncEngine();
    });

    tearDown(() async {
      fakeSyncEngine.dispose();
      await db.close();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          appFlavorProvider.overrideWithValue(AppDistributionFlavor.github),
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(MockAuthService()),
          syncEngineProvider.overrideWithValue(fakeSyncEngine),
          syncStateProvider.overrideWithValue(const SyncState(status: SyncStatus.localOnly)),
          updateServiceProvider.overrideWithValue(
            UpdateService(
              sharedPreferences: prefs,
              currentVersion: '1.2.0',
            ),
          ),
          backupServiceProvider.overrideWithValue(
            BackupService(
              database: db,
              cryptoService: DefaultCryptoService(),
              sharedPreferences: prefs,
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GeneralAdvancedSettingsScreen(),
        ),
      );
    }

    testWidgets('Renders Desktop OCR section and controls on desktop platforms', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('DESKTOP OCR (OLLAMA)'),
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('DESKTOP OCR (OLLAMA)'), findsOneWidget);
      expect(find.text('Use Local Ollama OCR'), findsOneWidget);
      expect(find.text('Ollama Endpoint'), findsOneWidget);
      expect(find.text('http://127.0.0.1:11434'), findsOneWidget);
      expect(find.text('OCR Model'), findsOneWidget);
      expect(find.text('deepseek-ocr'), findsOneWidget);
    });

    testWidgets('Tapping Ollama Endpoint opens edit dialog and updates value', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Ollama Endpoint'),
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final endpointRow = find.text('Ollama Endpoint');
      await tester.tap(endpointRow);
      await tester.pumpAndSettle();

      expect(find.text('Ollama Endpoint URL'), findsOneWidget);

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      await tester.enterText(textFieldFinder, 'http://192.168.1.50:11434');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('http://192.168.1.50:11434'), findsOneWidget);
    });

    testWidgets('Tapping OCR Model opens model selection dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('OCR Model'),
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final modelRow = find.text('OCR Model');
      await tester.tap(modelRow);
      await tester.pumpAndSettle();

      expect(find.text('Select OCR Model'), findsOneWidget);
      expect(find.text('deepseek-ocr:latest'), findsOneWidget);

      await tester.tap(find.text('deepseek-ocr:latest'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('deepseek-ocr:latest'), findsOneWidget);
    });

    testWidgets('Toggling switch off hides secondary rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Use Local Ollama OCR'),
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      final ocrSwitchFinder = find.descendant(
        of: find.ancestor(of: find.text('Use Local Ollama OCR'), matching: find.byType(Row)),
        matching: find.byType(CupertinoSwitch),
      );
      expect(ocrSwitchFinder, findsOneWidget);

      await tester.tap(ocrSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Ollama Endpoint'), findsNothing);
      expect(find.text('OCR Model'), findsNothing);
    });
  });
}
