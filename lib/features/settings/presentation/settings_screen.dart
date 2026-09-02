import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/theme/theme_family.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../../core/backup/backup_provider.dart';
import '../../../core/backup/presentation/auto_backup_password_dialog.dart';
import '../../../core/backup/presentation/create_backup_dialog.dart';
import '../../../core/backup/presentation/restore_backup_dialog.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/update/update_provider.dart';
import '../../import/application/markdown_import_scanner.dart';
import '../../import/presentation/markdown_import_screen.dart';
import '../../editor/domain/editor_editing_style.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/sample_notes.dart';
import '../../sync/presentation/change_account_password_dialog.dart';
import '../../sync/presentation/change_encryption_password_screen.dart';
import '../../sync/presentation/conflict_list_screen.dart';
import '../../sync/presentation/sync_auth_screen.dart';
import '../application/settings_provider.dart';
import '../application/typography_provider.dart';
import '../../../core/maintenance/maintenance_models.dart';
import '../../../core/maintenance/maintenance_provider.dart';
import 'storage_management_screen.dart';
import 'typography_settings_screen.dart';
import 'widgets/maintenance_progress_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _syncRotationController;
  Timer? _cooldownTimer;
  int _resendCooldownSeconds = 0;
  bool _isSendingVerification = false;
  bool _isCheckingForUpdates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkEmailVerification();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkEmailVerification();
    }
  }

  Future<void> _checkEmailVerification() async {
    final user = ref.read(currentUserProvider);
    if (user != null && !user.emailVerified) {
      await ref.read(authServiceProvider).reloadUser();
    }
  }

  void _startCooldownTimer() {
    setState(() {
      _resendCooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds > 1) {
        setState(() {
          _resendCooldownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _resendCooldownSeconds = 0;
        });
      }
    });
  }

  Future<void> _sendVerificationEmail(String email) async {
    final colors = Theme.of(context).extension<AppColors>() ?? AppColors.light;
    setState(() {
      _isSendingVerification = true;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification email sent to $email'),
          duration: const Duration(seconds: 3),
        ),
      );
      _startCooldownTimer();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send verification email: $errorMsg'),
          duration: const Duration(seconds: 3),
          backgroundColor: colors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingVerification = false;
        });
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, String email) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Sign Out',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Sign out of $email? Local notes will remain on this device.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Cancel',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                'Sign Out',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).signOut();
      await ref.read(keyManagerProvider).clearLocalKeys();
      await ref.read(syncEngineProvider).resetSyncCursor();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRotationController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkManualUpdate() async {
    setState(() {
      _isCheckingForUpdates = true;
    });

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdate();

      if (!mounted) return;

      if (result.hasUpdate && result.latestRelease != null) {
        UpdateDialog.show(
          context,
          result.latestRelease!,
          currentVersion: updateService.currentVersion,
          isManualCheck: true,
        );
      } else if (result.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update check failed: ${result.errorMessage}'),
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Quiet Paper is up to date (v${updateService.currentVersion})',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking for updates: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingForUpdates = false;
        });
      }
    }
  }

  Future<void> _handleDownloadAllAttachments(BuildContext context) async {
    await MaintenanceProgressSheet.show(
      context,
      taskType: MaintenanceTaskType.downloadAttachments,
    );
  }

  Future<void> _handleRerunOcrForAll(BuildContext context) async {
    final keyManager = ref.read(keyManagerProvider);
    if (!keyManager.isUnlocked) {
      final colors = context.appColors;
      await showDialog<void>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'Encryption Locked',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Quiet Paper encryption keys are locked. Please unlock your notebook to extract text and re-run OCR on attachments.',
            style: AppTypography.bodySmall.copyWith(
              color: colors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'OK',
                style: AppTypography.bodySmallMedium.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
      return;
    }

    await MaintenanceProgressSheet.show(
      context,
      taskType: MaintenanceTaskType.rerunOcr,
    );
  }

  Future<void> _handleRebuildSearchIndex(BuildContext context) async {
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Text(
          'Rebuild Search Index',
          style: AppTypography.headline.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This will rebuild full-text search indexes and refresh OCR candidate caches across all notes. Your note contents will not be modified.',
          style: AppTypography.bodySmall.copyWith(
            color: colors.textSecondary,
            height: 1.4,
          ),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Rebuild',
              style: AppTypography.bodySmallMedium.copyWith(
                color: colors.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final maintenanceService = ref.read(attachmentMaintenanceServiceProvider);
      await maintenanceService.rebuildSearchIndex();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Search index rebuilt successfully'),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to rebuild search index: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: colors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final themeSettings = ref.watch(themeSettingsProvider);
    final editingStyle = ref.watch(editorEditingStyleProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final autoBackupConfig = ref.watch(autoBackupConfigProvider);

    if (syncState.status == SyncStatus.syncing) {
      if (!_syncRotationController.isAnimating) {
        _syncRotationController.repeat();
      }
    } else {
      if (_syncRotationController.isAnimating) {
        _syncRotationController.stop();
        _syncRotationController.reset();
      }
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: QuietIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTypography.title.copyWith(
            color: colors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              children: [
                // ==========================================
                // Section: Cloud Sync & Encryption
                // ==========================================
                _buildSectionHeader(context, 'Cloud Sync & Encryption'),
                _SettingsGroup(
                  children: [
                    if (currentUser == null) ...[
                      _SettingsInfoTile(
                        icon: Icons.cloud_outlined,
                        iconColor: colors.accent,
                        title: 'End-to-End Encrypted Cloud Sync',
                        description:
                            'Quiet Paper keeps notes offline on device. Sign in and set an encryption password to sync securely across devices with zero-knowledge encryption.',
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.cloud_sync_outlined,
                        iconColor: colors.accent,
                        title: 'Set up Encrypted Sync',
                        titleColor: colors.accent,
                        isPrimaryAction: true,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SyncAuthScreen(),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // 1. User Profile & Sync Status Row
                      _SettingsInfoTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: colors.accent,
                        title: currentUser.email,
                        description: _formatSyncStatus(syncState),
                        descriptionColor:
                            syncState.status == SyncStatus.syncError
                                ? colors.error
                                : colors.textSecondary,
                      ),

                      // 2. [CONDITIONAL] Email Verification Row
                      if (!currentUser.emailVerified) ...[
                        _buildDivider(colors),
                        _SettingsRow(
                          icon: Icons.mark_email_unread_outlined,
                          iconColor: colors.accent,
                          title: 'Verify Email Address',
                          subtitle:
                              'Verification required for account recovery.',
                          trailing: GestureDetector(
                            onTap: (_resendCooldownSeconds > 0 ||
                                    _isSendingVerification)
                                ? null
                                : () => _sendVerificationEmail(
                                    currentUser.email),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _resendCooldownSeconds > 0
                                    ? colors.elevated
                                    : colors.accent
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _resendCooldownSeconds > 0
                                      ? colors.divider
                                      : colors.accent
                                          .withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: _isSendingVerification
                                  ? const CupertinoActivityIndicator(radius: 6)
                                  : Text(
                                      _resendCooldownSeconds > 0
                                          ? '${_resendCooldownSeconds}s'
                                          : 'Resend Link',
                                      style: AppTypography.caption.copyWith(
                                        color: _resendCooldownSeconds > 0
                                            ? colors.textTertiary
                                            : colors.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.0,
                                      ),
                                    ),
                            ),
                          ),
                          onTap: (_resendCooldownSeconds > 0 ||
                                  _isSendingVerification)
                              ? null
                              : () => _sendVerificationEmail(currentUser.email),
                        ),
                      ],

                      // 3. Sync Now Row
                      _buildDivider(colors),
                      _SettingsRow(
                        leading: RotationTransition(
                          turns: _syncRotationController,
                          child: Icon(
                            Icons.sync_rounded,
                            size: 20,
                            color: syncState.status == SyncStatus.syncing
                                ? colors.accent
                                : colors.textSecondary,
                          ),
                        ),
                        title: 'Sync Now',
                        trailing: syncState.status == SyncStatus.syncing
                            ? const CupertinoActivityIndicator(radius: 8)
                            : Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: colors.textTertiary,
                              ),
                        onTap: syncState.status == SyncStatus.syncing
                            ? null
                            : () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                messenger.hideCurrentSnackBar();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Syncing notes & images...'),
                                    duration: const Duration(seconds: 1),
                                    backgroundColor: colors.elevated,
                                  ),
                                );

                                await ref.read(syncEngineProvider).syncNow();

                                if (!context.mounted) return;
                                final resultState =
                                    ref.read(syncStateProvider);

                                messenger.hideCurrentSnackBar();

                                if (resultState.status ==
                                    SyncStatus.syncError) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Icons.error_outline,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              resultState.errorMessage ??
                                                  'Sync error occurred. Check Cloudinary credentials in Vercel.',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: colors.error,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                } else if (resultState.status ==
                                    SyncStatus.offline) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                          'Offline • Changes preserved on device'),
                                      duration: const Duration(seconds: 3),
                                      backgroundColor: colors.elevated,
                                    ),
                                  );
                                } else if (resultState.status ==
                                    SyncStatus.conflict ||
                                    resultState.conflictsCount > 0) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Sync complete with ${resultState.conflictsCount} conflict(s) requiring review.',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Colors.orange.shade800,
                                      duration: const Duration(seconds: 4),
                                      action: SnackBarAction(
                                        label: 'Review',
                                        textColor: Colors.white,
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const ConflictListScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                } else if (resultState.status ==
                                    SyncStatus.synced) {
                                  final attSynced =
                                      resultState.attachmentsSynced;
                                  final successText = attSynced > 0
                                      ? 'Sync complete: Notes & $attSynced image(s) synced'
                                      : 'Sync complete: All notes up to date';

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                              Icons.check_circle_outline,
                                              color: Colors.white,
                                              size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              successText,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: colors.accent,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                      ),

                      // [CONDITIONAL] Review Conflicts Row
                      if (syncState.conflictsCount > 0) ...[
                        _buildDivider(colors),
                        _SettingsRow(
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          title:
                              'Review Sync Conflicts (${syncState.conflictsCount})',
                          subtitle:
                              'Conflicting edits need manual resolution',
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: colors.textTertiary,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ConflictListScreen(),
                              ),
                            );
                          },
                        ),
                      ],

                      // 4. Account Password Row (Firebase Auth)
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.key_outlined,
                        title: 'Account Password',
                        subtitle: 'Login & cloud account credentials',
                        trailingRowText: 'Change',
                        onTap: () {
                          ChangeAccountPasswordDialog.show(context);
                        },
                      ),

                      // 5. Encryption Password Row (Zero-Knowledge / Argon2id)
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.shield_outlined,
                        title: 'Encryption Password',
                        subtitle: 'Zero-knowledge note vault key',
                        trailingRowText: 'Change',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChangeEncryptionPasswordScreen(),
                            ),
                          );
                        },
                      ),

                      // 6. Sign Out Row
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.logout_rounded,
                        iconColor: colors.error,
                        title: 'Sign Out',
                        titleColor: colors.error,
                        isDestructive: true,
                        onTap: () =>
                            _confirmSignOut(context, currentUser.email),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Theme Family
                // ==========================================
                _buildSectionHeader(context, 'THEME FAMILY'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Classic Paper',
                      subtitle: 'Warm terracotta & soft paper editorial tones',
                      trailing: _buildThemePreviewSwatches(
                        context: context,
                        colors: isDark ? AppColors.classicDark : AppColors.classicLight,
                        isSelected: themeSettings.family == ThemeFamily.classicPaper,
                      ),
                      isSelected: themeSettings.family == ThemeFamily.classicPaper,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.classicPaper);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Warm Paper',
                      subtitle: 'Warm ivory & midnight slate with serene slate blue accent',
                      trailing: _buildThemePreviewSwatches(
                        context: context,
                        colors: isDark ? AppColors.midnightPaperDark : AppColors.warmPaperLight,
                        isSelected: themeSettings.family == ThemeFamily.warmPaper,
                      ),
                      isSelected: themeSettings.family == ThemeFamily.warmPaper,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setThemeFamily(ThemeFamily.warmPaper);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Appearance
                // ==========================================
                _buildSectionHeader(context, 'APPEARANCE'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.brightness_auto_rounded,
                      title: 'System',
                      subtitle: 'Matches your device display settings',
                      isSelected: themeSettings.appearance == AppearanceMode.system,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.system);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.light_mode_outlined,
                      title: 'Light',
                      isSelected: themeSettings.appearance == AppearanceMode.light,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.light);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark',
                      isSelected: themeSettings.appearance == AppearanceMode.dark,
                      onTap: () {
                        ref
                            .read(themeSettingsProvider.notifier)
                            .setAppearanceMode(AppearanceMode.dark);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.text_fields_rounded,
                      title: 'Typography',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${ref.watch(typographySettingsProvider).bodyFontFamily ?? 'System'}, ${ref.watch(typographySettingsProvider).fontSize.toInt()}pt',
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const TypographySettingsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Editor
                // ==========================================
                _buildSectionHeader(context, 'EDITOR'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.edit_note_rounded,
                      title: 'WYSIWYG',
                      subtitle: 'Hide Markdown syntax for a cleaner writing experience',
                      isSelected: editingStyle == EditorEditingStyle.wysiwyg,
                      onTap: () {
                        ref
                            .read(editorEditingStyleProvider.notifier)
                            .setEditingStyle(EditorEditingStyle.wysiwyg);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.code_rounded,
                      title: 'Markdown',
                      subtitle: 'Show Markdown syntax while editing',
                      isSelected: editingStyle == EditorEditingStyle.markdown,
                      onTap: () {
                        ref
                            .read(editorEditingStyleProvider.notifier)
                            .setEditingStyle(EditorEditingStyle.markdown);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Storage & Attachments
                // ==========================================
                _buildSectionHeader(context, 'Storage & Attachments'),
                _SettingsGroup(
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.cloud_done_rounded,
                      iconColor: colors.accent,
                      title: 'Zero-Knowledge Cloud Storage',
                      description:
                          'Encrypted assets, notes, and PDF documents are retained securely in cloud storage. Maintenance runs automatically across active devices.',
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Storage & Cleanup',
                      subtitle: 'Storage breakdown, GC maintenance, and reclaimable space',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StorageManagementScreen(initialTab: 0),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.attachment_rounded,
                      title: 'Attached Assets',
                      subtitle: 'Active images & scanned documents',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StorageManagementScreen(initialTab: 1),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Orphaned Assets',
                      subtitle: 'Unreferenced cloud assets pending destruction',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StorageManagementScreen(initialTab: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Advanced
                // ==========================================
                _buildSectionHeader(context, 'Advanced'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.cloud_download_outlined,
                      title: 'Download All Attachments',
                      subtitle:
                          'Download all media and documents from cloud for offline access',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleDownloadAllAttachments(context),
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.document_scanner_outlined,
                      title: 'Rerun OCR for All Files',
                      subtitle:
                          'Extract text from all local scanned documents and image attachments',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleRerunOcrForAll(context),
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.manage_search_rounded,
                      title: 'Rebuild Search Index',
                      subtitle:
                          'Refresh full-text and OCR indexes for notes and attachments',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () => _handleRebuildSearchIndex(context),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Import
                // ==========================================
                _buildSectionHeader(context, 'Import'),
                _SettingsGroup(
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.import_contacts_outlined,
                      iconColor: colors.textSecondary,
                      title: 'Import Markdown Folder',
                      description:
                          'Select a folder to scan and import all Markdown (.md) documents recursively, including frontmatter, file creation/modification dates, and subfolder tags.',
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.folder_open_rounded,
                      title: 'Choose folder to import',
                      onTap: () async {
                        try {
                          final folderPath =
                              await FilePicker.platform.getDirectoryPath();
                          if (folderPath != null && context.mounted) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MarkdownImportScreen(
                                  initialFolderPath: folderPath,
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error choosing folder: $e'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Select markdown files',
                      onTap: () async {
                        try {
                          final result =
                              await FilePicker.platform.pickFiles(
                            allowMultiple: true,
                            type: FileType.custom,
                            allowedExtensions: ['md', 'markdown'],
                          );
                          if (result != null &&
                              result.files.isNotEmpty &&
                              context.mounted) {
                            final items =
                                await MarkdownImportScanner.processPickedFiles(
                                    result.files);
                            if (context.mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      MarkdownImportScreen(
                                    initialFolderPath: 'Selected Files',
                                    initialItems: items,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error picking files: $e'),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Local Backup & Restore
                // ==========================================
                _buildSectionHeader(context, 'Local Backup & Restore'),
                _SettingsGroup(
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.storage_outlined,
                      iconColor: colors.textSecondary,
                      title: 'Notebook Backups',
                      description:
                          'Export and restore complete .qpbackup snapshots, optionally protected with Argon2id encryption.',
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.backup_rounded,
                      iconColor: colors.accent,
                      title: 'Create Backup',
                      titleColor: colors.accent,
                      isPrimaryAction: true,
                      onTap: () => CreateBackupDialog.show(context),
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.settings_backup_restore_rounded,
                      title: 'Restore Backup',
                      onTap: () => RestoreBackupDialog.show(context),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Subgroup: Daily Auto-Backup
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.schedule_rounded,
                      title: 'Daily Auto-Backup',
                      subtitle:
                          'Automatically saves snapshots on app launch',
                      trailing: CupertinoSwitch(
                        value: autoBackupConfig.enabled,
                        activeTrackColor: colors.accent,
                        onChanged: (val) async {
                          if (val && autoBackupConfig.folderPath == null) {
                            final folder =
                                await FilePicker.platform.getDirectoryPath(
                              dialogTitle: 'Select Auto-Backup Folder',
                            );
                            if (folder != null) {
                              await ref
                                  .read(
                                      autoBackupConfigProvider.notifier)
                                  .setFolderPath(folder);
                              await ref
                                  .read(
                                      autoBackupConfigProvider.notifier)
                                  .setEnabled(true);
                            }
                          } else {
                            await ref
                                .read(autoBackupConfigProvider.notifier)
                                .setEnabled(val);
                          }
                        },
                      ),
                    ),
                    if (autoBackupConfig.enabled) ...[
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.folder_outlined,
                        title: 'Backup Folder',
                        subtitle: autoBackupConfig.folderPath ??
                            'No folder selected',
                        onTap: () async {
                          final folder =
                              await FilePicker.platform.getDirectoryPath(
                            dialogTitle: 'Change Auto-Backup Folder',
                          );
                          if (folder != null) {
                            await ref
                                .read(
                                    autoBackupConfigProvider.notifier)
                                .setFolderPath(folder);
                          }
                        },
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.history_rounded,
                        title: 'Keep Backups',
                        trailing: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: autoBackupConfig.retentionCount,
                            dropdownColor: colors.surface,
                            icon: Icon(
                              Icons.unfold_more_rounded,
                              size: 18,
                              color: colors.textTertiary,
                            ),
                            style: AppTypography.caption.copyWith(
                              color: colors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                            items: const [3, 5, 10, 30].map((c) {
                              return DropdownMenuItem<int>(
                                value: c,
                                child: Text('$c backups'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                ref
                                    .read(
                                        autoBackupConfigProvider.notifier)
                                    .setRetentionCount(val);
                              }
                            },
                          ),
                        ),
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: autoBackupConfig.hasPassword
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        title: 'Encryption',
                        trailingRowText: autoBackupConfig.hasPassword
                            ? 'Encrypted'
                            : 'Plaintext',
                        onTap: () =>
                            AutoBackupPasswordDialog.show(context),
                      ),
                    ],
                  ],
                ),
                if (autoBackupConfig.lastBackupAt != null)
                  _buildSectionFooter(
                    context,
                    'Last backup: ${DateFormat.yMMMd().add_jm().format(autoBackupConfig.lastBackupAt!)}',
                  ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Sample Notes
                // ==========================================
                _buildSectionHeader(context, 'Sample Notes'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.auto_stories_outlined,
                      title: 'Load sample notes',
                      subtitle:
                          'Populate example notes demonstrating Markdown, hashtags, and editorial formatting.',
                      onTap: () async {
                        final repository =
                            ref.read(notesRepositoryProvider);
                        await SampleNotes.populateSampleNotes(
                            repository);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sample notes loaded'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: About
                // ==========================================
                _buildSectionHeader(context, 'About'),
                _SettingsGroup(
                  children: [
                    _SettingsInfoTile(
                      icon: Icons.edit_note_rounded,
                      iconColor: colors.accent,
                      title: 'Quiet Paper',
                      description:
                          'A quiet place to think.\nVersion 1.5.6 • Offline-first • End-to-End Encrypted Sync',

                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.system_update_rounded,
                      title: 'Check for updates',
                      trailing: _isCheckingForUpdates
                          ? const CupertinoActivityIndicator(radius: 8)
                          : null,
                      onTap:
                          _isCheckingForUpdates ? null : _checkManualUpdate,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: 8.0,
      ),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption.copyWith(
          color: colors.textTertiary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSectionFooter(BuildContext context, String text) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        top: 6.0,
        right: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: colors.textTertiary,
          fontSize: 11.5,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildDivider(AppColors colors) {
    return Divider(
      color: colors.divider.withValues(alpha: 0.5),
      height: 1,
      thickness: 1.0,
      indent: 52, // 16 horizontal padding + 24 icon box + 12 gap = 52
      endIndent: 0,
    );
  }

  Widget _buildThemePreviewSwatches({
    required BuildContext context,
    required AppColors colors,
    required bool isSelected,
  }) {
    final activeColors = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7.0, vertical: 5.0),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: colors.divider, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.divider, width: 0.5),
                ),
              ),
              const SizedBox(width: 3.5),
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: colors.textPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3.5),
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: colors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 3.5),
              Container(
                width: 10.0,
                height: 10.0,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        if (isSelected) ...[
          const SizedBox(width: 8.0),
          Icon(
            Icons.check_rounded,
            size: 20,
            color: activeColors.accent,
          ),
        ],
      ],
    );
  }

  String _formatSyncStatus(SyncState state) {
    switch (state.status) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.synced:
        if (state.lastSyncedAt != null) {
          final time = DateFormat.jm().format(state.lastSyncedAt!);
          if (state.attachmentsSynced > 0) {
            return 'All notes & ${state.attachmentsSynced} image(s) synced at $time';
          }
          return 'All notes synced at $time';
        }
        return 'All notes synced';
      case SyncStatus.pendingSync:
        return 'Unlock encryption password to sync';
      case SyncStatus.offline:
        return 'Offline • Changes saved locally';
      case SyncStatus.conflict:
        return 'Conflict detected • Preserved locally';
      case SyncStatus.syncError:
        return state.errorMessage ?? 'Sync failed • Check Cloudinary config';
      case SyncStatus.localOnly:
        return 'Local storage only';
    }
  }
}

/// A container card mimicking the iOS grouped table section.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// An informative, non-clickable row used for headers/descriptions inside a grouped section.
class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.descriptionColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final Color? descriptionColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 14.0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: iconColor ?? colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16.0,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: descriptionColor ?? colors.textSecondary,
                    fontSize: 12.0,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A standard clickable row inside a grouped section.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    this.icon,
    this.leading,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.titleColor,
    this.trailing,
    this.trailingRowText,
    this.isSelected = false,
    this.isPrimaryAction = false,
    this.isDestructive = false,
    this.onTap,
  }) : assert(icon != null || leading != null,
            'Either icon or leading must be provided');

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? titleColor;
  final Widget? trailing;
  final String? trailingRowText;
  final bool isSelected;
  final bool isPrimaryAction;
  final bool isDestructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final resolvedIconColor = iconColor ??
        (isSelected
            ? colors.accent
            : (isDestructive
                ? colors.error
                : (isPrimaryAction ? colors.accent : colors.textSecondary)));

    final resolvedTitleColor = titleColor ??
        (isSelected
            ? colors.accent
            : (isDestructive
                ? colors.error
                : (isPrimaryAction ? colors.accent : colors.textPrimary)));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 14.0,
          ),
          child: Row(
            crossAxisAlignment: subtitle != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: leading ??
                      Icon(
                        icon,
                        size: 20,
                        color: resolvedIconColor,
                      ),
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        color: resolvedTitleColor,
                        fontWeight: (isSelected || isPrimaryAction)
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 16.0,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 12.0,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (trailingRowText != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingRowText!,
                      style: AppTypography.caption.copyWith(
                        color: colors.textTertiary,
                        fontSize: 13.0,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ],
                )
              else if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                )
              else if (onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDestructive
                      ? colors.error.withValues(alpha: 0.6)
                      : (isPrimaryAction
                          ? colors.accent.withValues(alpha: 0.7)
                          : colors.textTertiary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
