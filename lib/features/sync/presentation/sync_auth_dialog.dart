import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/quiet_button.dart';

class SyncAuthDialog extends ConsumerStatefulWidget {
  const SyncAuthDialog({super.key});

  @override
  ConsumerState<SyncAuthDialog> createState() => _SyncAuthDialogState();
}

class _SyncAuthDialogState extends ConsumerState<SyncAuthDialog> {
  final _emailController = TextEditingController();
  final _firebasePasswordController = TextEditingController();
  final _encryptionPasswordController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _serverUrlController =
      TextEditingController(text: 'https://quitepaper.vercel.app');
  final _apiKeyController = TextEditingController();

  bool _isSignUp = false;
  bool _isRecovering = false;
  bool _isLoading = false;
  bool _showAdvancedSettings = false;
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
    _firebasePasswordController.dispose();
    _encryptionPasswordController.dispose();
    _recoveryKeyController.dispose();
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final fbPassword = _firebasePasswordController.text;
    final encPassword = _encryptionPasswordController.text;

    if (email.isEmpty || fbPassword.isEmpty) {
      setState(() => _errorMessage = 'Email and account password are required.');
      return;
    }

    if (!_isRecovering && encPassword.isEmpty) {
      setState(() => _errorMessage = 'Quiet Paper encryption password is required.');
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
              'Firebase API key not found. Please enter your Firebase Web API Key in Server Settings below or set FIREBASE_API_KEY in Vercel.';
        });
        return;
      }

      if (_isSignUp) {
        // Sign up with Firebase
        await auth.signUpWithEmailAndPassword(email, fbPassword);

        // Generate recovery key & setup new encryption master key
        final recoveryKey = crypto.generateRecoveryKey();
        _generatedRecoveryKey = recoveryKey;

        final wrappedKey = await keyManager.setupNewKeys(
          password: encPassword,
          recoveryKey: recoveryKey,
        );

        // Upload wrapped key metadata to server
        await api.putKeys(wrappedKey);
      } else if (_isRecovering) {
        // Sign in with Firebase
        await auth.signInWithEmailAndPassword(email, fbPassword);
        final remoteKey = await api.getKeys();
        if (remoteKey == null) {
          throw Exception('No encrypted notes found on server.');
        }

        // Unlock with recovery key
        await keyManager.unlockWithRecoveryKey(
          recoveryKey: _recoveryKeyController.text.trim(),
          remoteWrappedKey: remoteKey,
        );

        // Set new password
        if (encPassword.isNotEmpty) {
          final updatedKey =
              await keyManager.changePassword(newPassword: encPassword);
          await api.putKeys(updatedKey);
        }
      } else {
        // Sign in with Firebase
        await auth.signInWithEmailAndPassword(email, fbPassword);
        final remoteKey = await api.getKeys();

        if (remoteKey != null) {
          await keyManager.unlockWithPassword(
            password: encPassword,
            remoteWrappedKey: remoteKey,
          );
        } else {
          // No remote keys yet: set up initial keys
          final recoveryKey = crypto.generateRecoveryKey();
          _generatedRecoveryKey = recoveryKey;
          final wrapped = await keyManager.setupNewKeys(
            password: encPassword,
            recoveryKey: recoveryKey,
          );
          await api.putKeys(wrapped);
        }
      }

      // Trigger initial sync
      engine.syncNow();

      if (_generatedRecoveryKey == null && mounted) {
        Navigator.of(context).pop();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_generatedRecoveryKey != null) {
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
        title: Text(
          'Your Recovery Key',
          style: AppTypography.title.copyWith(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Save this recovery key in a safe place. If you forget your Quiet Paper encryption password, this key is the only way to recover your notes.',
              style:
                  AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: SelectableText(
                _generatedRecoveryKey!,
                style: AppTypography.editorCode.copyWith(
                  color: colors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          QuietButton(
            label: 'I have saved it',
            variant: QuietButtonVariant.primary,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isSignUp
                    ? 'Create Quiet Paper Account'
                    : _isRecovering
                        ? 'Recover Account'
                        : 'Sign In to Sync',
                style:
                    AppTypography.headline.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'End-to-end encrypted notes with zero-knowledge cloud backup.',
                style: AppTypography.bodySmall
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _firebasePasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Account password (Firebase)',
                  border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_isRecovering)
                TextField(
                  controller: _recoveryKeyController,
                  decoration: InputDecoration(
                    labelText: 'Recovery Key (qp-xxxx-...)',
                    border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                  ),
                )
              else
                TextField(
                  controller: _encryptionPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Quiet Paper Encryption Password',
                    helperText: 'Protects note content. Never sent to server.',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                  ),
                ),
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
                      Text(
                        'Server & Firebase API Settings',
                        style: AppTypography.caption
                            .copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showAdvancedSettings) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _serverUrlController,
                  decoration: InputDecoration(
                    labelText: 'Sync Server URL (Optional)',
                    hintText: 'https://your-project.vercel.app',
                    border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'Firebase Web API Key',
                    hintText: 'AIzaSy...',
                    border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: AppTypography.caption.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _isRecovering = false;
                              _errorMessage = null;
                            });
                          },
                    child: Text(_isSignUp
                        ? 'Have an account? Sign In'
                        : 'New? Create Account'),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              setState(() {
                                _isRecovering = !_isRecovering;
                                _errorMessage = null;
                              });
                            },
                      child: Text(
                          _isRecovering ? 'Use Password' : 'Use Recovery Key'),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  QuietButton(
                    label: 'Cancel',
                    variant: QuietButtonVariant.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  QuietButton(
                    label: _isSignUp ? 'Create & Encrypt' : 'Sign In & Unlock',
                    variant: QuietButtonVariant.primary,
                    onPressed: _isLoading ? null : _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
