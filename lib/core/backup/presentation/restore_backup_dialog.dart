import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../widgets/quiet_button.dart';
import '../../widgets/quiet_icon_button.dart';
import '../backup_models.dart';
import '../backup_provider.dart';

class RestoreBackupDialog extends ConsumerStatefulWidget {
  const RestoreBackupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const RestoreBackupDialog(),
    );
  }

  @override
  ConsumerState<RestoreBackupDialog> createState() => _RestoreBackupDialogState();
}

class _RestoreBackupDialogState extends ConsumerState<RestoreBackupDialog> {
  File? _selectedFile;
  BackupValidationResult? _validation;
  bool _isValidating = false;
  bool _isRestoring = false;

  RestoreStrategy _strategy = RestoreStrategy.merge;
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _errorText = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        dialogTitle: 'Select Quiet Paper Backup (.qpbackup or .json)',
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        _selectedFile = file;
        _passwordController.clear();
        await _validateFile(file);
      }
    } catch (e) {
      setState(() {
        _errorText = 'Error selecting file: $e';
      });
    }
  }

  Future<void> _validateFile(File file, {String? password}) async {
    setState(() {
      _isValidating = true;
      _errorText = null;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final validation = await service.validateBackupFile(
        file,
        password: password,
      );

      if (mounted) {
        setState(() {
          _validation = validation;
          _isValidating = false;
          if (!validation.isValid && validation.errorMessage != null) {
            _errorText = validation.errorMessage;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isValidating = false;
          _errorText = 'Validation failed: $e';
        });
      }
    }
  }

  Future<void> _handleUnlockEncrypted() async {
    if (_selectedFile == null) return;
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _errorText = 'Please enter the backup password.';
      });
      return;
    }

    await _validateFile(_selectedFile!, password: password);
  }

  Future<void> _handleRestore() async {
    if (_validation?.payload == null) return;

    setState(() {
      _isRestoring = true;
      _errorText = null;
    });

    try {
      final service = ref.read(backupServiceProvider);
      final result = await service.restoreBackup(
        _validation!.payload!,
        strategy: _strategy,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Restored ${result.totalRestored} notes'
              '${result.totalUpdated > 0 ? ', updated ${result.totalUpdated}' : ''}'
              '${result.totalSkipped > 0 ? ', skipped ${result.totalSkipped}' : ''}'
              '${result.totalConflicts > 0 ? ', kept ${result.totalConflicts} duplicates' : ''}.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRestoring = false;
          _errorText = 'Restore failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isFileLoaded = _selectedFile != null && _validation != null;
    final isEncryptedAndLocked =
        _validation?.isEncrypted == true && _validation?.payload == null;
    final isReadyToRestore = _validation?.payload != null;

    return Dialog(
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
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
                      Icons.settings_backup_restore_rounded,
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
                          'Restore from Backup',
                          style: AppTypography.title.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Import notes from .qpbackup archive',
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

              // File Selection Area
              if (!isFileLoaded || _validation?.isValid == false) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_zip_outlined,
                        size: 40,
                        color: colors.textTertiary,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Select a .qpbackup or JSON backup file from your device storage.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      QuietButton(
                        label: 'Select Backup File',
                        icon: Icons.file_open_outlined,
                        variant: QuietButtonVariant.primary,
                        isLoading: _isValidating,
                        onPressed: _isValidating ? null : _pickFile,
                      ),
                    ],
                  ),
                ),
              ],

              // Encrypted Lock Screen
              if (isEncryptedAndLocked) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 20, color: colors.accent),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Encrypted Backup',
                            style: AppTypography.caption.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'This backup is protected with Argon2id + XChaCha20-Poly1305 encryption. Enter the password used when creating it.',
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: AppTypography.bodySmall.copyWith(
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Backup Password',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.borderMd,
                            borderSide: BorderSide(color: colors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadii.borderMd,
                            borderSide: BorderSide(
                              color: colors.accent,
                              width: 1.5,
                            ),
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
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _pickFile,
                            child: Text(
                              'Choose another file',
                              style: AppTypography.caption.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          QuietButton(
                            label: 'Unlock & Preview',
                            icon: Icons.lock_open_rounded,
                            variant: QuietButtonVariant.primary,
                            isLoading: _isValidating,
                            onPressed:
                                _isValidating ? null : _handleUnlockEncrypted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Backup Validated Preview & Strategy Options
              if (isReadyToRestore) ...[
                // Snapshot metadata card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: colors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _validation!.manifest != null
                                ? DateFormat.yMMMd().add_jm().format(
                                      _validation!.manifest!.createdAt,
                                    )
                                : 'Backup Snapshot',
                            style: AppTypography.caption.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.12),
                              borderRadius: AppRadii.borderSm,
                            ),
                            child: Text(
                              _validation!.isEncrypted
                                  ? '🔒 Encrypted'
                                  : 'Plain Snapshot',
                              style: AppTypography.caption.copyWith(
                                color: colors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat(
                            colors,
                            '${_validation!.payload!.notes.length}',
                            'Notes',
                          ),
                          _buildStat(
                            colors,
                            '${_validation!.payload!.tags.length}',
                            'Tags',
                          ),
                          _buildStat(
                            colors,
                            'v${_validation!.manifest?.appVersion ?? '1.0'}',
                            'App Version',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Restore Strategy Options
                Text(
                  'Restore Strategy',
                  style: AppTypography.caption.copyWith(
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildStrategyTile(
                  colors: colors,
                  strategy: RestoreStrategy.merge,
                  title: 'Merge (Recommended)',
                  subtitle:
                      'Adds missing notes, updates older notes, and preserves local changes.',
                ),
                _buildStrategyTile(
                  colors: colors,
                  strategy: RestoreStrategy.keepBoth,
                  title: 'Keep Both',
                  subtitle:
                      'Creates duplicate notes with (Restored) title on conflict.',
                ),
                _buildStrategyTile(
                  colors: colors,
                  strategy: RestoreStrategy.replace,
                  title: 'Clean Replace',
                  subtitle:
                      'Wipes the current local notebook and replaces with backup.',
                  isDestructive: true,
                ),
              ],

              // Error banner
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
              if (isReadyToRestore)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _pickFile,
                      child: Text(
                        'Change File',
                        style: AppTypography.caption.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        QuietButton(
                          label: 'Cancel',
                          variant: QuietButtonVariant.tonal,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        QuietButton(
                          label:
                              'Restore ${_validation!.payload!.notes.length} Notes',
                          icon: Icons.settings_backup_restore_rounded,
                          variant: _strategy == RestoreStrategy.replace
                              ? QuietButtonVariant.destructive
                              : QuietButtonVariant.primary,
                          isLoading: _isRestoring,
                          onPressed: _isRestoring ? null : _handleRestore,
                        ),
                      ],
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

  Widget _buildStrategyTile({
    required AppColors colors,
    required RestoreStrategy strategy,
    required String title,
    required String subtitle,
    bool isDestructive = false,
  }) {
    final isSelected = _strategy == strategy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _strategy = strategy;
          });
        },
        borderRadius: AppRadii.borderSm,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? (isDestructive ? colors.error : colors.accent)
                        : colors.textTertiary,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDestructive ? colors.error : colors.accent,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected
                            ? (isDestructive ? colors.error : colors.accent)
                            : colors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      subtitle,
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
    );
  }
}
