import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/form_card.dart';
import '../../../core/widgets/quiet_button.dart';

class ChangeEncryptionPasswordDialog extends ConsumerStatefulWidget {
  const ChangeEncryptionPasswordDialog({super.key});

  @override
  ConsumerState<ChangeEncryptionPasswordDialog> createState() =>
      _ChangeEncryptionPasswordDialogState();
}

class _ChangeEncryptionPasswordDialogState
    extends ConsumerState<ChangeEncryptionPasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _recoveryKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isUsingRecoveryKey = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _recoveryKeyController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _submit() async {
    final currentPass = _currentPasswordController.text;
    final recoveryKey = _recoveryKeyController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    // Validate verification input
    if (!_isUsingRecoveryKey && currentPass.isEmpty) {
      setState(() => _errorMessage =
          'Please enter your current encryption password to verify ownership.');
      return;
    }
    if (_isUsingRecoveryKey && recoveryKey.isEmpty) {
      setState(() => _errorMessage =
          'Please enter your emergency recovery key to verify ownership.');
      return;
    }

    // Validate new password
    if (newPassword.length < 8) {
      setState(() => _errorMessage =
          'New encryption password must be at least 8 characters long.');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _errorMessage = 'New passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final keyManager = ref.read(keyManagerProvider);
      final api = ref.read(syncApiClientProvider);

      // 1. Fetch current wrapped key record
      final currentKeyData =
          await api.getKeys() ?? await keyManager.getStoredWrappedKeyData();

      if (currentKeyData == null) {
        throw Exception('No active encryption keys found to update.');
      }

      // 2. Verify proof of ownership before allowing password rotation
      if (_isUsingRecoveryKey) {
        try {
          await keyManager.unlockWithRecoveryKey(
            recoveryKey: recoveryKey,
            remoteWrappedKey: currentKeyData,
          );
        } catch (e) {
          throw Exception(
              'Invalid Recovery Key. Please check the phrase and try again.');
        }
      } else {
        try {
          await keyManager.unlockWithPassword(
            password: currentPass,
            remoteWrappedKey: currentKeyData,
          );
        } catch (e) {
          throw Exception(
              'Incorrect current encryption password. If you forgot your password, tap "Use Recovery Key" below.');
        }
      }

      // 3. Re-wrap master key with new password (note ciphertexts stay untouched)
      final updatedWrappedKey = await keyManager.changePassword(
        newPassword: newPassword,
      );

      // 4. Upload updated wrapped key with cryptographic proof to backend
      await api.putKeys(updatedWrappedKey);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Vault encryption key updated.'),
            duration: Duration(seconds: 3),
          ),
        );
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
          child: Column(
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
                    child: Icon(Icons.lock_reset_outlined,
                        color: colors.accentDark, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Master Password Rotation',
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Re-wraps your master key. Note ciphertexts stay untouched.',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_isLoading) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(
                        color: colors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2.5,
                          valueColor:
                              AlwaysStoppedAnimation(colors.accent),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Re-wrapping master key with new credentials...',
                          style: AppTypography.bodySmallMedium.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Section 1: Verification of Current Credentials
              Text(
                '1. Verify Current Vault Ownership',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isUsingRecoveryKey
                    ? 'Enter your emergency recovery key to authorize changing your password.'
                    : 'Enter your current encryption password to authorize changing your password.',
                style: AppTypography.caption
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Group 1 FormCard
              FormCard(
                children: [
                  if (_isUsingRecoveryKey) ...[
                    FormInputRow(
                      controller: _recoveryKeyController,
                      icon: Icons.vpn_key_outlined,
                      labelText: 'Emergency Recovery Key (qp-xxxx-...)',
                      enabled: !_isLoading,
                      onChanged: (_) => _clearError(),
                    ),
                  ] else ...[
                    FormInputRow(
                      controller: _currentPasswordController,
                      icon: Icons.lock_outline,
                      labelText: 'Current Encryption Password',
                      obscureText: _obscureCurrentPassword,
                      enabled: !_isLoading,
                      onChanged: (_) => _clearError(),
                      suffix: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                        onPressed: () => setState(() =>
                            _obscureCurrentPassword =
                                !_obscureCurrentPassword),
                      ),
                    ),
                  ],
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isUsingRecoveryKey = !_isUsingRecoveryKey;
                            _errorMessage = null;
                          });
                        },
                  child: Text(
                    _isUsingRecoveryKey
                        ? 'Use Current Password Instead'
                        : 'Forgot password? Use Recovery Key',
                    style: AppTypography.caption.copyWith(
                      color: colors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Section 2: Set New Password
              Text(
                '2. Set New Encryption Password',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a strong password (minimum 8 characters).',
                style: AppTypography.caption
                    .copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Group 2 FormCard
              FormCard(
                children: [
                  FormInputRow(
                    controller: _newPasswordController,
                    icon: Icons.key_outlined,
                    labelText: 'New Encryption Password (min. 8 chars)',
                    obscureText: _obscureNewPassword,
                    enabled: !_isLoading,
                    onChanged: (_) => _clearError(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: colors.textTertiary,
                      ),
                      onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword),
                    ),
                  ),
                  const FormDivider(),
                  FormInputRow(
                    controller: _confirmPasswordController,
                    icon: Icons.key_outlined,
                    labelText: 'Confirm New Password',
                    obscureText: _obscureConfirmPassword,
                    enabled: !_isLoading,
                    onChanged: (_) => _clearError(),
                    onSubmitted: (_) => _submit(),
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 20,
                        color: colors.textTertiary,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword =
                              !_obscureConfirmPassword),
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
                  label: 'Verify & Change Password',
                  variant: QuietButtonVariant.primary,
                  isFullWidth: true,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
