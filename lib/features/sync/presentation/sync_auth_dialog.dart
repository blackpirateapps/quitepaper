import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/form_card.dart';
import '../../../core/widgets/quiet_button.dart';

enum _AuthFlowStep {
  onboarding,
  signupEmail,
  signupAccountPassword,
  signupEncryptionPassword,
  signupComplete,
  signIn,
}

class SyncAuthDialog extends ConsumerStatefulWidget {
  const SyncAuthDialog({super.key});

  @override
  ConsumerState<SyncAuthDialog> createState() => _SyncAuthDialogState();
}

class _SyncAuthDialogState extends ConsumerState<SyncAuthDialog> {
  _AuthFlowStep _step = _AuthFlowStep.onboarding;

  final _emailController = TextEditingController();
  final _fbPasswordController = TextEditingController();
  final _fbConfirmPasswordController = TextEditingController();
  final _encPasswordController = TextEditingController();
  final _encConfirmPasswordController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _serverUrlController =
      TextEditingController(text: 'https://quitepaper.vercel.app');
  final _apiKeyController = TextEditingController();

  bool _obscureFbPassword = true;
  bool _obscureFbConfirmPassword = true;
  bool _obscureEncPassword = true;
  bool _obscureEncConfirmPassword = true;
  bool _obscureSignInFbPassword = true;
  bool _obscureSignInEncPassword = true;

  bool _isRecoveringInSignIn = false;
  bool _isLoading = false;
  bool _showAdvancedSettings = false;
  bool _copiedRecoveryKey = false;
  String? _errorMessage;
  String? _generatedRecoveryKey;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authServiceProvider);
    if (auth.apiKey.isNotEmpty) {
      _apiKeyController.text = auth.apiKey;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _fbPasswordController.dispose();
    _fbConfirmPasswordController.dispose();
    _encPasswordController.dispose();
    _encConfirmPasswordController.dispose();
    _recoveryKeyController.dispose();
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  // --- Step 1 Validation (Email) ---
  void _submitSignupEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return;
    }
    setState(() {
      _errorMessage = null;
      _step = _AuthFlowStep.signupAccountPassword;
    });
  }

  // --- Step 2 Validation (Account Login Password) ---
  void _submitSignupAccountPassword() {
    final pass = _fbPasswordController.text;
    final confirm = _fbConfirmPasswordController.text;

    if (pass.length < 6) {
      setState(() => _errorMessage =
          'Account password must be at least 6 characters long.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Account passwords do not match.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _step = _AuthFlowStep.signupEncryptionPassword;
    });
  }

  // --- Step 3 Validation & Registration (Encryption Password) ---
  Future<void> _submitSignupFinal() async {
    final encPass = _encPasswordController.text;
    final encConfirm = _encConfirmPasswordController.text;

    if (encPass.length < 8) {
      setState(() => _errorMessage =
          'Encryption password must be at least 8 characters long.');
      return;
    }
    if (encPass != encConfirm) {
      setState(() => _errorMessage = 'Encryption passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final keyManager = ref.read(keyManagerProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final api = ref.read(syncApiClientProvider);
      final engine = ref.read(syncEngineProvider);

      if (_apiKeyController.text.trim().isNotEmpty) {
        auth.setApiKey(_apiKeyController.text.trim());
      }

      if (auth.apiKey.isEmpty) {
        final serverUrl = _serverUrlController.text.trim();
        await auth.fetchConfigFromBackend(serverUrl);
      }

      if (auth.apiKey.isEmpty) {
        setState(() {
          _isLoading = false;
          _showAdvancedSettings = true;
          _errorMessage =
              'Firebase API key not found. Please expand Server Settings below or set FIREBASE_API_KEY in Vercel.';
        });
        return;
      }

      final email = _emailController.text.trim();
      final fbPass = _fbPasswordController.text;

      final serverUrl = _serverUrlController.text.trim();
      if (serverUrl.isNotEmpty) {
        api.setBaseUrl(serverUrl);
      }

      // 1. Sign up with Firebase
      final user = await auth.signUpWithEmailAndPassword(email, fbPass);

      // 2. Trigger email verification
      await auth.sendEmailVerification(user.idToken);

      // 3. Generate recovery key & setup new master key
      final recoveryKey = crypto.generateRecoveryKey();
      _generatedRecoveryKey = recoveryKey;

      final wrappedKey = await keyManager.setupNewKeys(
        password: encPass,
        recoveryKey: recoveryKey,
      );

      // 4. Upload wrapped key metadata to server
      await api.putKeys(wrappedKey);

      // 5. Trigger initial sync
      engine.syncNow();

      setState(() {
        _isLoading = false;
        _step = _AuthFlowStep.signupComplete;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanErrorMessage(e);
      });
    }
  }

  // --- Sign In Submission ---
  Future<void> _submitSignIn() async {
    final email = _emailController.text.trim();
    final fbPassword = _fbPasswordController.text;
    final encPassword = _encPasswordController.text;

    if (email.isEmpty || fbPassword.isEmpty) {
      setState(
          () => _errorMessage = 'Email and account password are required.');
      return;
    }

    if (!_isRecoveringInSignIn && encPassword.isEmpty) {
      setState(() =>
          _errorMessage = 'Quiet Paper encryption password is required.');
      return;
    }

    if (_isRecoveringInSignIn && _recoveryKeyController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter your recovery key.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = ref.read(authServiceProvider);
      final keyManager = ref.read(keyManagerProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final api = ref.read(syncApiClientProvider);
      final engine = ref.read(syncEngineProvider);

      if (_apiKeyController.text.trim().isNotEmpty) {
        auth.setApiKey(_apiKeyController.text.trim());
      }

      final serverUrl = _serverUrlController.text.trim();
      if (serverUrl.isNotEmpty) {
        api.setBaseUrl(serverUrl);
      }

      if (auth.apiKey.isEmpty) {
        await auth.fetchConfigFromBackend(serverUrl);
      }

      if (auth.apiKey.isEmpty) {
        setState(() {
          _isLoading = false;
          _showAdvancedSettings = true;
          _errorMessage =
              'Firebase API key not found. Please expand Server Settings below or set FIREBASE_API_KEY in Vercel.';
        });
        return;
      }

      // Sign in with Firebase
      await auth.signInWithEmailAndPassword(email, fbPassword);

      try {
        final remoteKey = await api.getKeys();

        if (_isRecoveringInSignIn) {
          if (remoteKey == null) {
            throw Exception('No encrypted notes vault found for this account.');
          }

          await keyManager.unlockWithRecoveryKey(
            recoveryKey: _recoveryKeyController.text.trim(),
            remoteWrappedKey: remoteKey,
          );

          if (encPassword.isNotEmpty) {
            final updatedKey =
                await keyManager.changePassword(newPassword: encPassword);
            await api.putKeys(updatedKey);
          }
        } else {
          if (remoteKey != null) {
            await keyManager.unlockWithPassword(
              password: encPassword,
              remoteWrappedKey: remoteKey,
            );
          } else {
            // First time syncing this account: initialize keys
            final recoveryKey = crypto.generateRecoveryKey();
            _generatedRecoveryKey = recoveryKey;
            final wrapped = await keyManager.setupNewKeys(
              password: encPassword,
              recoveryKey: recoveryKey,
            );
            await api.putKeys(wrapped);
          }
        }
      } catch (unlockError) {
        // Rollback Firebase session: Stay completely logged out if encryption password fails
        try {
          await auth.signOut();
        } catch (_) {}
        keyManager.lock();

        final rawMsg = unlockError.toString();
        if (rawMsg.contains('SecretBoxAuthenticationError') ||
            rawMsg.contains('MAC') ||
            rawMsg.contains('decrypt') ||
            rawMsg.contains('Invalid') ||
            rawMsg.contains('failed')) {
          throw Exception(
            'Incorrect Quiet Paper encryption password. If you forgot your password, tap "Forgot Password? Use Recovery Key" below.',
          );
        }
        rethrow;
      }

      engine.syncNow();

      if (_generatedRecoveryKey == null && mounted) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _isLoading = false;
          _step = _AuthFlowStep.signupComplete;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanErrorMessage(e);
      });
    }
  }

  String _cleanErrorMessage(Object error) {
    var msg = error.toString();
    msg = msg.replaceFirst(RegExp(r'^(Exception|FormatException|StateError):\s*'), '');
    return msg.trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (_step) {
            _AuthFlowStep.onboarding => _buildOnboarding(colors),
            _AuthFlowStep.signupEmail => _buildSignupEmail(colors),
            _AuthFlowStep.signupAccountPassword =>
              _buildSignupAccountPassword(colors),
            _AuthFlowStep.signupEncryptionPassword =>
              _buildSignupEncryptionPassword(colors),
            _AuthFlowStep.signupComplete => _buildSignupComplete(colors),
            _AuthFlowStep.signIn => _buildSignIn(colors),
          },
        ),
      ),
    );
  }

  // ===========================================================================
  // SCREEN 0: ENCRYPTION ONBOARDING & SAFETY GUIDE
  // ===========================================================================
  Widget _buildOnboarding(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.accentSoft,
                borderRadius: AppRadii.borderMd,
              ),
              child: Icon(Icons.shield_outlined,
                  color: colors.accentDark, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zero-Knowledge Sync',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'End-to-End Encrypted Cloud Backup',
                    style: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Your notes belong only to you. Quiet Paper uses strict client-side encryption so that nobody — not even our servers — can read your notes.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Information FormCard
        FormCard(
          children: [
            FormInfoRow(
              icon: Icons.lock_outline,
              title: 'What Gets Encrypted',
              badge: 'Fully Private',
              badgeColor: colors.success,
              description:
                  'Your note titles, note content, and tags are encrypted on your device using Argon2id and XChaCha20-Poly1305 before uploading.',
            ),
            const FormDivider(),
            FormInfoRow(
              icon: Icons.notes_outlined,
              title: 'What Stays Plaintext (Metadata)',
              badge: 'Metadata Only',
              badgeColor: colors.textSecondary,
              description:
                  'Only non-sensitive metadata (note IDs, created/updated timestamps, and archived/trashed status) is visible to the server for syncing order.',
            ),
            const FormDivider(),
            FormInfoRow(
              icon: Icons.vpn_key_outlined,
              title: 'Two Separate Passwords',
              badge: 'Zero Knowledge',
              badgeColor: colors.accentDark,
              description:
                  '1. Account Password: Logs you into Firebase.\n2. Encryption Password: Unlocks your master key locally. Never sent to any server.',
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Create Account',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            onPressed: () {
              setState(() {
                _step = _AuthFlowStep.signupEmail;
                _errorMessage = null;
              });
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Sign In',
            variant: QuietButtonVariant.secondary,
            isFullWidth: true,
            onPressed: () {
              setState(() {
                _step = _AuthFlowStep.signIn;
                _errorMessage = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator(AppColors colors, String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(colors.accent),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SIGN UP STEP 1: EMAIL
  // ===========================================================================
  Widget _buildSignupEmail(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardHeader(
          colors: colors,
          stepNumber: 'Step 1 of 3',
          title: 'What is your email address?',
          subtitle:
              'Used to identify your account and send security & verification notices.',
          onBack: () {
            setState(() {
              _step = _AuthFlowStep.onboarding;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        FormCard(
          children: [
            FormInputRow(
              controller: _emailController,
              icon: Icons.email_outlined,
              labelText: 'Email address',
              hintText: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _submitSignupEmail(),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Continue',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            onPressed: _submitSignupEmail,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _step = _AuthFlowStep.signIn;
                _errorMessage = null;
              });
            },
            child: Text(
              'Already have an account? Sign In',
              style: AppTypography.caption.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
                fontSize: 13.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SIGN UP STEP 2: ACCOUNT LOGIN PASSWORD
  // ===========================================================================
  Widget _buildSignupAccountPassword(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardHeader(
          colors: colors,
          stepNumber: 'Step 2 of 3',
          title: 'Create Account Password',
          subtitle:
              'This password logs you into Firebase to verify your identity. It does NOT encrypt your notes.',
          onBack: () {
            setState(() {
              _step = _AuthFlowStep.signupEmail;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        FormCard(
          children: [
            FormInputRow(
              controller: _fbPasswordController,
              icon: Icons.lock_outline,
              labelText: 'Account Password (min. 6 characters)',
              obscureText: _obscureFbPassword,
              autofocus: true,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                icon: Icon(
                  _obscureFbPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colors.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscureFbPassword = !_obscureFbPassword),
              ),
            ),
            const FormDivider(),
            FormInputRow(
              controller: _fbConfirmPasswordController,
              icon: Icons.lock_outline,
              labelText: 'Confirm Account Password',
              obscureText: _obscureFbConfirmPassword,
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _submitSignupAccountPassword(),
              suffix: IconButton(
                icon: Icon(
                  _obscureFbConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colors.textTertiary,
                ),
                onPressed: () => setState(() =>
                    _obscureFbConfirmPassword = !_obscureFbConfirmPassword),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Continue',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            onPressed: _submitSignupAccountPassword,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SIGN UP STEP 3: ENCRYPTION PASSWORD
  // ===========================================================================
  Widget _buildSignupEncryptionPassword(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardHeader(
          colors: colors,
          stepNumber: 'Step 3 of 3',
          title: 'Set Encryption Password',
          subtitle:
              'This Master Password mathematically encrypts your notes on this device. We NEVER receive or store it on any server.',
          onBack: () {
            setState(() {
              _step = _AuthFlowStep.signupAccountPassword;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.md),

        // Distinct warning banner
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(color: colors.accentDark.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: colors.accentDark, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Password Safety: If you forget this password, only your Recovery Key can restore your notes.',
                  style: AppTypography.caption.copyWith(
                    color: colors.accentDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isLoading)
          _buildLoadingIndicator(
            colors,
            'Deriving Argon2id encryption key & wrapping master key...',
          ),
        FormCard(
          children: [
            FormInputRow(
              controller: _encPasswordController,
              icon: Icons.key_outlined,
              labelText: 'Quiet Paper Encryption Password (min. 8 chars)',
              obscureText: _obscureEncPassword,
              autofocus: true,
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                icon: Icon(
                  _obscureEncPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colors.textTertiary,
                ),
                onPressed: () =>
                    setState(() => _obscureEncPassword = !_obscureEncPassword),
              ),
            ),
            const FormDivider(),
            FormInputRow(
              controller: _encConfirmPasswordController,
              icon: Icons.key_outlined,
              labelText: 'Confirm Encryption Password',
              obscureText: _obscureEncConfirmPassword,
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
              onSubmitted: (_) => _submitSignupFinal(),
              suffix: IconButton(
                icon: Icon(
                  _obscureEncConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colors.textTertiary,
                ),
                onPressed: () => setState(() =>
                    _obscureEncConfirmPassword = !_obscureEncConfirmPassword),
              ),
            ),
          ],
        ),
        _buildServerSettingsAccordion(colors),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Create Account & Encrypt',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitSignupFinal,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCREEN 4: SIGN UP COMPLETE, EMAIL VERIFICATION & RECOVERY KEY
  // ===========================================================================
  Widget _buildSignupComplete(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: colors.success.withValues(alpha: 0.15),
                borderRadius: AppRadii.borderMd,
              ),
              child: Icon(Icons.check_circle_outline,
                  color: colors.success, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account Created!',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Your zero-knowledge encrypted vault is ready.',
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Email verification FormCard
        FormCard(
          children: [
            FormInfoRow(
              icon: Icons.mark_email_unread_outlined,
              iconColor: colors.accentDark,
              title: 'Check your email for verification',
              description:
                  'We have sent a verification link to ${_emailController.text.trim()}. Please click the link in your inbox to verify your account.',
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // Recovery Key Box
        Text(
          'Your Emergency Recovery Key',
          style: AppTypography.bodySmallMedium.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Save this key in a password manager or safe offline document. If you forget your encryption password, this is the only way to recover your notes.',
          style: AppTypography.caption.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: colors.divider.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                _generatedRecoveryKey ?? 'Generating key...',
                style: AppTypography.editorCode.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _generatedRecoveryKey == null
                      ? null
                      : () {
                          Clipboard.setData(
                              ClipboardData(text: _generatedRecoveryKey!));
                          setState(() => _copiedRecoveryKey = true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Recovery key copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                  icon: Icon(
                    _copiedRecoveryKey ? Icons.check : Icons.copy,
                    size: 16,
                  ),
                  label: Text(_copiedRecoveryKey ? 'Copied' : 'Copy Key'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: 'Done — Saved Recovery Key',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // SCREEN: SIGN IN FOR EXISTING USERS
  // ===========================================================================
  Widget _buildSignIn(AppColors colors) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWizardHeader(
          colors: colors,
          stepNumber: _isRecoveringInSignIn ? 'Recovery' : 'Sign In',
          title: _isRecoveringInSignIn
              ? 'Recover Encrypted Notes'
              : 'Sign In to Quiet Paper',
          subtitle: _isRecoveringInSignIn
              ? 'Use your recovery key to unlock notes and choose a new password.'
              : 'Enter your credentials to unlock and sync your encrypted notes.',
          onBack: () {
            setState(() {
              _step = _AuthFlowStep.onboarding;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_isLoading)
          _buildLoadingIndicator(
            colors,
            'Authenticating & unlocking encrypted vault...',
          ),
        FormCard(
          children: [
            FormInputRow(
              controller: _emailController,
              icon: Icons.email_outlined,
              labelText: 'Email address',
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
            ),
            const FormDivider(),
            FormInputRow(
              controller: _fbPasswordController,
              icon: Icons.lock_outline,
              labelText: 'Account Login Password (Firebase)',
              obscureText: _obscureSignInFbPassword,
              enabled: !_isLoading,
              onChanged: (_) => _clearError(),
              suffix: IconButton(
                icon: Icon(
                  _obscureSignInFbPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: colors.textTertiary,
                ),
                onPressed: () => setState(() =>
                    _obscureSignInFbPassword = !_obscureSignInFbPassword),
              ),
            ),
            const FormDivider(),
            if (_isRecoveringInSignIn) ...[
              FormInputRow(
                controller: _recoveryKeyController,
                icon: Icons.vpn_key_outlined,
                labelText: 'Recovery Key (qp-xxxx-...)',
                enabled: !_isLoading,
                onChanged: (_) => _clearError(),
              ),
              const FormDivider(),
              FormInputRow(
                controller: _encPasswordController,
                icon: Icons.key_outlined,
                labelText: 'New Encryption Password (Optional)',
                obscureText: _obscureSignInEncPassword,
                enabled: !_isLoading,
                onChanged: (_) => _clearError(),
                suffix: IconButton(
                  icon: Icon(
                    _obscureSignInEncPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onPressed: () => setState(() =>
                      _obscureSignInEncPassword = !_obscureSignInEncPassword),
                ),
              ),
            ] else ...[
              FormInputRow(
                controller: _encPasswordController,
                icon: Icons.key_outlined,
                labelText: 'Quiet Paper Encryption Password',
                obscureText: _obscureSignInEncPassword,
                enabled: !_isLoading,
                onChanged: (_) => _clearError(),
                suffix: IconButton(
                  icon: Icon(
                    _obscureSignInEncPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: colors.textTertiary,
                  ),
                  onPressed: () => setState(() =>
                      _obscureSignInEncPassword = !_obscureSignInEncPassword),
                ),
              ),
            ],
          ],
        ),
        if (!_isRecoveringInSignIn) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, top: 6.0),
            child: Text(
              'Decodes notes locally on device.',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontSize: 12.0,
              ),
            ),
          ),
        ],
        _buildServerSettingsAccordion(colors),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage!,
            style: AppTypography.caption.copyWith(color: colors.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _step = _AuthFlowStep.signupEmail;
                        _errorMessage = null;
                      });
                    },
              child: Text(
                'New? Create Account',
                style: AppTypography.caption.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isRecoveringInSignIn = !_isRecoveringInSignIn;
                        _errorMessage = null;
                      });
                    },
              child: Text(
                _isRecoveringInSignIn
                    ? 'Use Encryption Password'
                    : 'Forgot Password? Use Recovery Key',
                style: AppTypography.caption.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: QuietButton(
            label: _isRecoveringInSignIn
                ? 'Recover & Unlock'
                : 'Sign In & Unlock',
            variant: QuietButtonVariant.primary,
            isFullWidth: true,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : _submitSignIn,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // REUSABLE WIDGET HELPERS
  // ===========================================================================
  Widget _buildWizardHeader({
    required AppColors colors,
    required String stepNumber,
    required String title,
    required String subtitle,
    required VoidCallback onBack,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onBack,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              stepNumber,
              style: AppTypography.caption.copyWith(
                color: colors.accentDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          title,
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildServerSettingsAccordion(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: () {
            setState(() {
              _showAdvancedSettings = !_showAdvancedSettings;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  _showAdvancedSettings
                      ? Icons.arrow_drop_down
                      : Icons.arrow_right,
                  size: 18,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Server & Firebase API Settings',
                    style: AppTypography.caption
                        .copyWith(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showAdvancedSettings) ...[
          const SizedBox(height: AppSpacing.sm),
          FormCard(
            children: [
              FormInputRow(
                controller: _serverUrlController,
                labelText: 'Sync Server URL',
                hintText: 'https://quitepaper.vercel.app',
              ),
              const FormDivider(indent: 16),
              FormInputRow(
                controller: _apiKeyController,
                labelText: 'Firebase Web API Key',
                hintText: 'AIzaSy...',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
