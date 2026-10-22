import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/storage/cloud_storage_provider.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/devices/presentation/devices_screen.dart';
import 'package:quitepaper/features/share/presentation/manage_shares_screen.dart';
import 'package:quitepaper/features/sync/presentation/change_account_password_dialog.dart';
import 'package:quitepaper/features/sync/presentation/change_encryption_password_screen.dart';
import 'package:quitepaper/features/sync/presentation/conflict_list_screen.dart';
import 'cloud_storage_screen.dart';
import 'storage_management_screen.dart';
import 'widgets/settings_shared_widgets.dart';

/// Advanced configuration screen for Cloud Sync, Encryption, Sessions, and Storage.
class SyncAdvancedSettingsScreen extends ConsumerStatefulWidget {
  const SyncAdvancedSettingsScreen({super.key});

  @override
  ConsumerState<SyncAdvancedSettingsScreen> createState() =>
      _SyncAdvancedSettingsScreenState();
}

class _SyncAdvancedSettingsScreenState
    extends ConsumerState<SyncAdvancedSettingsScreen> {
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _isSendingVerification = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() {
      _resendCooldownSeconds = 60;
    });
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
    final colors = context.appColors;
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

  Future<void> _confirmSignOut(String email) async {
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
            'Sign out of this device?',
            style: AppTypography.headline.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Your local notes will stay on this device and remain available offline. Cloud synchronization will stop until you sign in again.',
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

    if (confirmed == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final cloudStorageSubtitle = ref.watch(cloudStorageSubtitleProvider);

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
          'Sync & Security',
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
                // Section: Security & Credentials
                // ==========================================
                buildSectionHeader(context, 'Security & Credentials'),
                SettingsGroup(
                  children: [
                    if (currentUser != null && !currentUser.emailVerified) ...[
                      SettingsRow(
                        icon: Icons.mark_email_unread_outlined,
                        iconColor: colors.accent,
                        title: 'Verify Email Address',
                        subtitle: 'Verification required for account recovery.',
                        trailing: GestureDetector(
                          onTap: (_resendCooldownSeconds > 0 ||
                                  _isSendingVerification)
                              ? null
                              : () =>
                                  _sendVerificationEmail(currentUser.email),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _resendCooldownSeconds > 0
                                  ? colors.elevated
                                  : colors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _resendCooldownSeconds > 0
                                    ? colors.divider
                                    : colors.accent.withValues(alpha: 0.4),
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
                            : () =>
                                _sendVerificationEmail(currentUser.email),
                      ),
                      buildDivider(colors),
                    ],

                    // Devices & Sessions
                    SettingsRow(
                      icon: Icons.devices_rounded,
                      title: 'Devices & Sessions',
                      subtitle: 'Manage signed-in devices and sessions',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: colors.textTertiary,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DevicesScreen(),
                          ),
                        );
                      },
                    ),
                    buildDivider(colors),

                    // Account Password
                    SettingsRow(
                      icon: Icons.key_outlined,
                      title: 'Account Password',
                      subtitle: 'Login & cloud account credentials',
                      trailingRowText: 'Change',
                      onTap: () {
                        ChangeAccountPasswordDialog.show(context);
                      },
                    ),
                    buildDivider(colors),

                    // Encryption Password
                    SettingsRow(
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

                    if (syncState.conflictsCount > 0) ...[
                      buildDivider(colors),
                      SettingsRow(
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

                    if (currentUser != null) ...[
                      buildDivider(colors),
                      SettingsRow(
                        icon: Icons.logout_rounded,
                        iconColor: colors.error,
                        title: 'Sign Out',
                        titleColor: colors.error,
                        isDestructive: true,
                        onTap: () =>
                            _confirmSignOut(currentUser.email),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Storage & Attachments
                // ==========================================
                buildSectionHeader(context, 'Storage & Attachments'),
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.cloud_outlined,
                      title: 'Cloud Storage',
                      subtitle: cloudStorageSubtitle,
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
                            builder: (_) => const CloudStorageScreen(),
                          ),
                        );
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.link_rounded,
                      title: 'Shared links',
                      subtitle:
                          'Manage or delete notes you shared as public URLs',
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
                            builder: (_) => const ManageSharesScreen(),
                          ),
                        );
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.pie_chart_outline_rounded,
                      title: 'Storage & Cleanup',
                      subtitle:
                          'Storage breakdown, GC maintenance, and reclaimable space',
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
                            builder: (_) =>
                                const StorageManagementScreen(initialTab: 0),
                          ),
                        );
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
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
                            builder: (_) =>
                                const StorageManagementScreen(initialTab: 1),
                          ),
                        );
                      },
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.delete_sweep_outlined,
                      title: 'Orphaned Assets',
                      subtitle:
                          'Unreferenced cloud assets pending destruction',
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
                            builder: (_) =>
                                const StorageManagementScreen(initialTab: 2),
                          ),
                        );
                      },
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
}
