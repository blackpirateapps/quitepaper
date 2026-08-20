import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/form_card.dart';
import '../../../core/widgets/quiet_button.dart';

class ChangeAccountPasswordDialog extends ConsumerStatefulWidget {
  const ChangeAccountPasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ChangeAccountPasswordDialog(),
    );
  }

  @override
  ConsumerState<ChangeAccountPasswordDialog> createState() =>
      _ChangeAccountPasswordDialogState();
}

class _ChangeAccountPasswordDialogState
    extends ConsumerState<ChangeAccountPasswordDialog> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentPasswordController.dispose();
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
    final newPassword = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    // Validate inputs
    if (currentPass.isEmpty) {
      setState(() => _errorMessage =
          'Please enter your current account password to verify identity.');
      return;
    }

    if (newPassword.length < 8) {
      setState(() => _errorMessage =
          'New account password must be at least 8 characters long.');
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
      final auth = ref.read(authServiceProvider);
      await auth.updateAccountPassword(
        currentPassword: currentPass,
        newPassword: newPassword,
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Account password updated successfully.'),
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
                    child: Icon(
                      Icons.key_outlined,
                      color: colors.accentDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account Password',
                          style: AppTypography.headline.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Login & cloud account credentials',
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

              // Section 1: Current Password
              Text(
                '1. Verify Current Password',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your current account login password.',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              FormCard(
                children: [
                  FormInputRow(
                    controller: _currentPasswordController,
                    icon: Icons.lock_outline,
                    labelText: 'Current Password',
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
                          _obscureCurrentPassword = !_obscureCurrentPassword),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 2: New Password
              Text(
                '2. Set New Account Password',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a strong password (minimum 8 characters).',
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              FormCard(
                children: [
                  FormInputRow(
                    controller: _newPasswordController,
                    icon: Icons.key_outlined,
                    labelText: 'New Password (min. 8 chars)',
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
                          _obscureConfirmPassword = !_obscureConfirmPassword),
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

              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: QuietButton(
                  label: 'Update Password',
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
