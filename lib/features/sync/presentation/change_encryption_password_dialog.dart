import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/quiet_button.dart';

class ChangeEncryptionPasswordDialog extends ConsumerStatefulWidget {
  const ChangeEncryptionPasswordDialog({super.key});

  @override
  ConsumerState<ChangeEncryptionPasswordDialog> createState() =>
      _ChangeEncryptionPasswordDialogState();
}

class _ChangeEncryptionPasswordDialogState
    extends ConsumerState<ChangeEncryptionPasswordDialog> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      setState(() => _errorMessage = 'Please enter a new encryption password.');
      return;
    }
    if (newPassword != confirm) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final keyManager = ref.read(keyManagerProvider);
      final api = ref.read(syncApiClientProvider);

      // Re-wrap master key with new password (note ciphertexts stay untouched)
      final updatedWrappedKey = await keyManager.changePassword(
        newPassword: newPassword,
      );

      // Upload updated wrapped key
      await api.putKeys(updatedWrappedKey);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Encryption password changed successfully.'),
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
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change Encryption Password',
              style: AppTypography.headline.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Re-wraps your master key locally. Your encrypted note contents remain unchanged.',
              style: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Encryption Password',
                border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: AppRadii.borderMd),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: AppTypography.caption.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
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
                  label: 'Change Password',
                  variant: QuietButtonVariant.primary,
                  onPressed: _isLoading ? null : _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
