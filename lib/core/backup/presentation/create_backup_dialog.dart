import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../widgets/quiet_button.dart';
import '../../widgets/quiet_icon_button.dart';
import '../backup_models.dart';
import '../backup_provider.dart';

class CreateBackupDialog extends ConsumerStatefulWidget {
  const CreateBackupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const CreateBackupDialog(),
    );
  }

  @override
  ConsumerState<CreateBackupDialog> createState() => _CreateBackupDialogState();
}

class _CreateBackupDialogState extends ConsumerState<CreateBackupDialog> {
  bool _isEncrypted = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;
  bool _isCreating = false;

  BackupPayload? _previewPayload;
  bool _isLoadingPreview = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    try {
      final service = ref.read(backupServiceProvider);
      final payload = await service.generateBackupPayload();
      if (mounted) {
        setState(() {
          _previewPayload = payload;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _handleSaveBackup() async {
    setState(() {
      _errorText = null;
    });

    if (_isEncrypted) {
      final pass = _passwordController.text;
      final confirm = _confirmController.text;

      if (pass.isEmpty) {
        setState(() {
          _errorText = 'Please enter a backup encryption password.';
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
    }

    // Pick target folder
    String? targetFolder;
    try {
      targetFolder = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Backup Destination Folder',
      );
    } catch (e) {
      setState(() {
        _errorText = 'Unable to open folder picker: $e';
      });
      return;
    }

    if (targetFolder == null) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final file = await service.createBackupFile(
        directoryPath: targetFolder,
        password: _isEncrypted ? _passwordController.text : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        final fileName = file.uri.pathSegments.last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup created: $fileName'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreating = false;
          _errorText = 'Failed to create backup: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Dialog(
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
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
                      Icons.backup_rounded,
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
                          'Create Local Backup',
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Save notebook snapshot (.qpbackup)',
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

              // Note summary preview card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.borderMd,
                  border: Border.all(color: colors.divider),
                ),
                child: _isLoadingPreview
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            colors,
                            '${_previewPayload?.manifest.totalNotes ?? 0}',
                            'Total Notes',
                          ),
                          _buildStat(
                            colors,
                            '${_previewPayload?.manifest.activeNotes ?? 0}',
                            'Active',
                          ),
                          _buildStat(
                            colors,
                            '${_previewPayload?.manifest.archivedNotes ?? 0}',
                            'Archived',
                          ),
                          _buildStat(
                            colors,
                            '${_previewPayload?.manifest.trashedNotes ?? 0}',
                            'Trash',
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Password Protection Checkbox
              InkWell(
                onTap: () {
                  setState(() {
                    _isEncrypted = !_isEncrypted;
                    _errorText = null;
                  });
                },
                borderRadius: AppRadii.borderSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _isEncrypted,
                          activeColor: colors.accent,
                          checkColor: Colors.white,
                          side: BorderSide(
                            color: colors.textTertiary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _isEncrypted = val ?? false;
                              _errorText = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password protect this backup',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Encrypts notes with Argon2id + XChaCha20',
                              style: AppTypography.caption.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Password Fields (when encrypted)
              if (_isEncrypted) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Backup Password',
                    labelStyle: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
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
                    labelStyle: AppTypography.caption.copyWith(
                      color: colors.textSecondary,
                    ),
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
              ],

              // Error Text
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
                    label: 'Save Backup',
                    icon: Icons.folder_open_rounded,
                    variant: QuietButtonVariant.primary,
                    isLoading: _isCreating,
                    onPressed: _isCreating ? null : _handleSaveBackup,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(AppColors colors, String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: colors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
