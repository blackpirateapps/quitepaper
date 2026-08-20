import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/widgets/form_card.dart';
import 'package:quitepaper/features/sync/presentation/change_account_password_dialog.dart';
import 'package:quitepaper/features/sync/presentation/change_account_password_screen.dart';
import 'package:quitepaper/features/sync/presentation/change_encryption_password_dialog.dart';
import 'package:quitepaper/features/sync/presentation/change_encryption_password_screen.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_dialog.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SyncAuthScreen Page & Aesthetic Tests', () {
    testWidgets('Renders full page with Inset Grouped FormCard and badges', (tester) async {
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

      // Verify FormCard structure
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInfoRow), findsNWidgets(3));
      expect(find.byType(FormDivider), findsNWidgets(2));

      // Verify Information cards & badges
      expect(find.text('What Gets Encrypted'), findsOneWidget);
      expect(find.text('Fully Private'), findsOneWidget);
      expect(find.text('What Stays Plaintext (Metadata)'), findsOneWidget);
      expect(find.text('Metadata Only'), findsOneWidget);
      expect(find.text('Two Separate Passwords'), findsOneWidget);
      expect(find.text('Zero Knowledge'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);

      // Navigate to Create Account step 1
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('What is your email address?'), findsOneWidget);
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInputRow), findsOneWidget);
      expect(find.text('Already have an account? Sign In'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Step 1 to Step 2 to Step 3 flow has no redundant bottom back buttons', (tester) async {
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

      // Go to Step 1
      await tester.ensureVisible(find.text('Create Account'));
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Enter valid email and continue
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify Step 2
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Create Account Password'), findsOneWidget);
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInputRow), findsNWidgets(2));
      expect(find.byType(FormDivider), findsOneWidget);

      // Verify NO bottom back button on Step 2
      expect(find.widgetWithText(TextButton, 'Back'), findsNothing);

      // Enter passwords and continue
      final step2Inputs = find.byType(TextField);
      await tester.enterText(step2Inputs.at(0), 'password123');
      await tester.enterText(step2Inputs.at(1), 'password123');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Verify Step 3
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Set Encryption Password'), findsOneWidget);
      expect(find.text('Password Safety: If you forget this password, only your Recovery Key can restore your notes.'), findsOneWidget);
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInputRow), findsNWidgets(2));
      expect(find.text('Create Account & Encrypt'), findsOneWidget);

      // Verify NO bottom back button on Step 3
      expect(find.widgetWithText(TextButton, 'Back'), findsNothing);

      // Tap top-left navigation back to step 2
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('Sign In screen has single FormCard, outside helper text, and full-width action button', (tester) async {
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
      expect(find.text('Decodes notes locally on device.'), findsOneWidget);
      expect(find.text('Sign In & Unlock'), findsOneWidget);
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInputRow), findsNWidgets(3));
      expect(find.byType(FormDivider), findsNWidgets(2));

      // Toggle recovery key
      await tester.ensureVisible(find.text('Forgot Password? Use Recovery Key'));
      await tester.tap(find.text('Forgot Password? Use Recovery Key'));
      await tester.pumpAndSettle();

      expect(find.text('Recover Encrypted Notes'), findsOneWidget);
      expect(find.text('Recovery Key (qp-xxxx-...)'), findsOneWidget);
      expect(find.text('New Encryption Password (Optional)'), findsOneWidget);
      expect(find.text('Recover & Unlock'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('ChangeEncryptionPasswordScreen Page Tests', () {
    testWidgets('Renders two FormCards and full-width action button without bottom cancel button', (tester) async {
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

      // Verify sections and FormCards
      expect(find.text('1. Verify Current Vault Ownership'), findsOneWidget);
      expect(find.text('2. Set New Encryption Password'), findsOneWidget);
      expect(find.byType(FormCard), findsNWidgets(2));
      expect(find.text('Verify & Change Password'), findsOneWidget);

      // No bottom cancel button
      expect(find.widgetWithText(TextButton, 'Cancel'), findsNothing);

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

  group('ChangeAccountPasswordScreen Page Tests', () {
    testWidgets('Renders two FormCards and full-width action button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const ChangeAccountPasswordScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify page AppBar
      expect(find.text('Change Account Password'), findsWidgets);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      // Verify sections and FormCards
      expect(find.text('1. Verify Current Password'), findsOneWidget);
      expect(find.text('2. Set New Account Password'), findsOneWidget);
      expect(find.byType(FormCard), findsNWidgets(2));
      expect(find.text('Update Password'), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('Dialog Variations Tests', () {
    testWidgets('ChangeAccountPasswordDialog renders Inset Grouped Table cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const Scaffold(
              body: ChangeAccountPasswordDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account Password'), findsOneWidget);
      expect(find.text('1. Verify Current Password'), findsOneWidget);
      expect(find.text('2. Set New Account Password'), findsOneWidget);
      expect(find.byType(FormCard), findsNWidgets(2));
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets('ChangeEncryptionPasswordDialog renders Inset Grouped Table cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const Scaffold(
              body: ChangeEncryptionPasswordDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Master Password Rotation'), findsOneWidget);
      expect(find.text('1. Verify Current Vault Ownership'), findsOneWidget);
      expect(find.text('2. Set New Encryption Password'), findsOneWidget);
      expect(find.byType(FormCard), findsNWidgets(2));
      expect(find.text('Verify & Change Password'), findsOneWidget);
    });

    testWidgets('SyncAuthDialog renders Inset Grouped Table cards', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(extensions: const [AppColors.light]),
            home: const Scaffold(
              body: SyncAuthDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Zero-Knowledge Sync'), findsOneWidget);
      expect(find.byType(FormCard), findsOneWidget);
      expect(find.byType(FormInfoRow), findsNWidgets(3));
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
