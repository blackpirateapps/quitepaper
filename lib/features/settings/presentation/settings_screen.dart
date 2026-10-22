import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/flavor/app_flavor.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
import 'package:quitepaper/core/update/update_dialog.dart';
import 'package:quitepaper/core/update/update_provider.dart';
import 'package:quitepaper/core/utils/link_launcher_helper.dart';
import 'package:quitepaper/core/version/app_version_provider.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/sync/presentation/conflict_list_screen.dart';
import 'package:quitepaper/features/sync/presentation/sync_auth_screen.dart';
import 'about_app_screen.dart';
import 'appearance_settings_screen.dart';
import 'backup_import_settings_screen.dart';
import 'default_settings_screen.dart';
import 'general_advanced_settings_screen.dart';
import 'sync_advanced_settings_screen.dart';
import 'widgets/settings_shared_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _syncRotationController;
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncRotationController.dispose();
    super.dispose();
  }

  Future<void> _checkManualUpdate() async {
    final flavor = ref.read(appFlavorProvider);
    if (flavor.isPlayStore) {
      LinkLauncherHelper.handleLinkTap(
        context,
        AppDistributionFlavor.playStoreUrl,
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final flavor = ref.watch(appFlavorProvider);
    final appVersionInfo = ref.watch(appVersionInfoProvider);

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
                // Section: Cloud Sync & Encryption (3 Rows)
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
                      // Row 1: Email & Sync Status
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

                      // Row 2: Sync Now
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
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                      backgroundColor: Colors.orange.shade800,
                                      duration: const Duration(seconds: 4),
                                      action: SnackBarAction(
                                        label: 'Review',
                                        textColor: Colors.white,
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ConflictListScreen(),
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

                      // Row 3: Advanced
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.tune_rounded,
                        title: 'Advanced',
                        subtitle: 'Passwords, devices, sessions & storage',
                        trailing: Icon(
                          CupertinoIcons.chevron_forward,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const SyncAdvancedSettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: General
                // ==========================================
                _buildSectionHeader(context, 'GENERAL'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.tune_rounded,
                      title: 'Default Settings',
                      subtitle: 'Gestures, search shortcuts, and editor',
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
                            builder: (_) => const DefaultSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: 'Themes and typography',
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
                                const AppearanceSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.settings_backup_restore_rounded,
                      title: 'Backup and import',
                      subtitle: 'Markdown import and local backups',
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
                                const BackupImportSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.construction_rounded,
                      title: 'Advanced',
                      subtitle: 'Maintenance, debug tools, and sample notes',
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
                                const GeneralAdvancedSettingsScreen(),
                          ),
                        );
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
                          'A quiet place to think.\n${appVersionInfo.displayVersion} • Offline-first • End-to-End Encrypted Sync',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutAppScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () {
                        LinkLauncherHelper.handleLinkTap(
                          context,
                          'https://quitepaper.vercel.app/privacy.html',
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.description_outlined,
                      title: 'Terms & Conditions',
                      trailing: Icon(
                        CupertinoIcons.chevron_forward,
                        size: 14,
                        color: colors.textTertiary,
                      ),
                      onTap: () {
                        LinkLauncherHelper.handleLinkTap(
                          context,
                          'https://quitepaper.vercel.app/terms.html',
                        );
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.system_update_rounded,
                      title: 'Check for updates',
                      trailing: flavor.isPlayStore
                          ? Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: colors.textTertiary,
                            )
                          : (_isCheckingForUpdates
                              ? const CupertinoActivityIndicator(radius: 8)
                              : null),
                      onTap: flavor.isPlayStore
                          ? () {
                              LinkLauncherHelper.handleLinkTap(
                                context,
                                AppDistributionFlavor.playStoreUrl,
                              );
                            }
                          : (_isCheckingForUpdates ? null : _checkManualUpdate),
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
    return buildSectionHeader(context, title);
  }

  Widget _buildDivider(AppColors colors) {
    return buildDivider(colors);
  }

  String _formatSyncStatus(SyncState state) {
    switch (state.status) {
      case SyncStatus.localOnly:
        return 'Local storage only';
      case SyncStatus.pendingSync:
        return 'Pending sync…';
      case SyncStatus.syncing:
        return 'Syncing changes…';
      case SyncStatus.synced:
        return 'All notes synced';
      case SyncStatus.offline:
        return 'Offline • Changes saved locally';
      case SyncStatus.conflict:
        return '${state.conflictsCount} conflict(s) need review';
      case SyncStatus.syncError:
        return state.errorMessage ?? 'Sync failed • Check Cloudinary config';
    }
  }
}

// Re-exports/aliases for backward compatibility with existing tests
typedef _SettingsGroup = SettingsGroup;
typedef _SettingsInfoTile = SettingsInfoTile;
typedef _SettingsRow = SettingsRow;
