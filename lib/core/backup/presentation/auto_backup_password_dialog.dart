import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../widgets/quiet_button.dart';
import '../../widgets/quiet_icon_button.dart';
import '../backup_provider.dart';

class AutoBackupPasswordDialog extends ConsumerStatefulWidget {
  const AutoBackupPasswordDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AutoBackupPasswordDialog(),
    );
  }

  @override
  ConsumerState<AutoBackupPasswordDialog> createState() =>
      _AutoBackupPasswordDialogState();
}

class _AutoBackupPasswordDialogState
    extends ConsumerState<AutoBackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorText;
  bool _isSaving = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final pass = _passwordController.text;
    final confirm = _confirmController.text;

    if (pass.isEmpty) {
      setState(() {
        _errorText = 'Please enter a password or clear it.';
      });
      return;
    }

    if (pass.length < 6) {
      setState(() {
        _errorText = 'Password must be at least 6 characters.';
      });
      return;
    }

    if (pass != confirm) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(autoBackupConfigProvider.notifier).setPassword(pass);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-backup encryption password configured.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Failed to save password: $e';
        });
      }
    }
  }

  Future<void> _handleClear() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await ref.read(autoBackupConfigProvider.notifier).clearPassword();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Auto-backup password removed. Backups will be unencrypted.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorText = 'Failed to clear password: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final config = ref.watch(autoBackupConfigProvider);

    return Dialog(
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: AppRadii.borderMd,
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: colors.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Backup Encryption',
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          config.hasPassword
                              ? 'Password currently configured'
                              : 'Protect background snapshots',
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  QuietIconButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              Text(
                'When configured, Quiet Paper will automatically encrypt daily rolling backups using this password. The password is kept securely on your device keychain.',
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Password fields
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: config.hasPassword ? 'New Password' : 'Password',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                style: AppTypography.bodySmall.copyWith(
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadii.borderMd,
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: colors.textTertiary,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: colors.error),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: AppTypography.caption.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Actions
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (config.hasPassword) ...[
                          Row(
                            children: [
                              QuietButton(
                                label: 'Remove Password',
                                variant: QuietButtonVariant.destructive,
                                isLoading: _isSaving,
                                onPressed: _isSaving ? null : _handleClear,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            QuietButton(
                              label: 'Cancel',
                              variant: QuietButtonVariant.tonal,
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            QuietButton(
                              label: 'Save Password',
                              icon: Icons.check_rounded,
                              variant: QuietButtonVariant.primary,
                              isLoading: _isSaving,
                              onPressed: _isSaving ? null : _handleSave,
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (config.hasPassword)
                        QuietButton(
                          label: 'Remove Password',
                          variant: QuietButtonVariant.destructive,
                          isLoading: _isSaving,
                          onPressed: _isSaving ? null : _handleClear,
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QuietButton(
                            label: 'Cancel',
                            variant: QuietButtonVariant.tonal,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          QuietButton(
                            label: 'Save Password',
                            icon: Icons.check_rounded,
                            variant: QuietButtonVariant.primary,
                            isLoading: _isSaving,
                            onPressed: _isSaving ? null : _handleSave,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
