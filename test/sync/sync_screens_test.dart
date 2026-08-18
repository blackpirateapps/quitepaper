import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/sync/presentation/change_encryption_password_screen.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncAuthScreen Page Tests', () {
    testWidgets('Renders full page with AppBar and Zero-Knowledge info cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const SyncAuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page AppBar
      expect(find.text('Cloud Sync & Encryption'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verify Zero-Knowledge Sync intro
      expect(find.text('Zero-Knowledge Sync'), findsOneWidget);
      expect(find.text('End-to-End Encrypted Cloud Backup'), findsOneWidget);

      // Verify Information cards
      expect(find.text('What Gets Encrypted'), findsOneWidget);
      expect(find.text('What Stays Plaintext (Metadata)'), findsOneWidget);
      expect(find.text('Two Separate Passwords'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Navigate to Create Account step 1
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('What is your email address?'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Navigate to Sign In screen directly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const SyncAuthScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign In
      await tester.ensureVisible(find.text('Sign In'));
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In to Quiet Paper'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Account Login Password (Firebase)'), findsOneWidget);
      expect(find.text('Quiet Paper Encryption Password'), findsOneWidget);
      expect(find.text('Sign In & Unlock'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ChangeEncryptionPasswordScreen Page Tests', () {
    testWidgets('Renders full page with verification and password change sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const ChangeEncryptionPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page AppBar
      expect(find.text('Change Encryption Password'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verify sections
      expect(find.text('1. Verify Current Vault Ownership'), findsOneWidget);
      expect(find.text('2. Set New Encryption Password'), findsOneWidget);
      expect(find.text('Verify & Change Password'), findsOneWidget);

      // Toggle recovery key
      expect(find.text('Forgot password? Use Recovery Key'), findsOneWidget);
      await tester.ensureVisible(find.text('Forgot password? Use Recovery Key'));
      await tester.tap(find.text('Forgot password? Use Recovery Key'));
      await tester.pumpAndSettle();

      expect(find.text('Emergency Recovery Key (qp-xxxx-...)'), findsOneWidget);
      expect(find.text('Use Current Password Instead'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
