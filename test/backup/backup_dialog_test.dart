import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/backup_service.dart';
import 'package:quitepaper/core/backup/presentation/auto_backup_password_dialog.dart';
import 'package:quitepaper/core/backup/presentation/create_backup_dialog.dart';
import 'package:quitepaper/core/backup/presentation/restore_backup_dialog.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
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
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('CreateBackupDialog renders stats preview, password toggle, and action buttons', (tester) async {
    final now = DateTime.now();
    await db.saveNote(
      id: 'n1',
      title: 'Sample Note',
      content: 'Sample Content',
      createdAt: now,
      updatedAt: now,
      isPinned: false,
      tags: ['sample'],
    );

    await tester.pumpWidget(
      createTestWidget(child: const CreateBackupDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create Local Backup'), findsOneWidget);
    expect(find.text('Total Notes'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Password protect this backup'), findsOneWidget);
    expect(find.text('Save Backup'), findsOneWidget);

    // Toggle password protection checkbox
    await tester.tap(find.text('Password protect this backup'));
    await tester.pumpAndSettle();

    // Password input fields should appear
    expect(find.text('Backup Password'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
  });

  testWidgets('RestoreBackupDialog renders file selection button and header', (tester) async {
    await tester.pumpWidget(
      createTestWidget(child: const RestoreBackupDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restore from Backup'), findsOneWidget);
    expect(find.text('Select Backup File'), findsOneWidget);
  });

  testWidgets('AutoBackupPasswordDialog renders password fields and save action', (tester) async {
    await tester.pumpWidget(
      createTestWidget(child: const AutoBackupPasswordDialog()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Auto-Backup Encryption'), findsOneWidget);
    expect(find.text('Save Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
