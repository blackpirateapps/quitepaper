import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/widgets/quiet_button.dart';
import '../../../core/widgets/quiet_icon_button.dart';
import '../../../core/backup/backup_provider.dart';
import '../../../core/backup/presentation/auto_backup_password_dialog.dart';
import '../../../core/backup/presentation/create_backup_dialog.dart';
import '../../../core/backup/presentation/restore_backup_dialog.dart';
import '../../../core/update/update_dialog.dart';
import '../../../core/update/update_provider.dart';
import '../../import/application/markdown_import_scanner.dart';
import '../../import/presentation/markdown_import_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/application/sample_notes.dart';
import '../../sync/presentation/change_encryption_password_screen.dart';
import '../../sync/presentation/sync_auth_screen.dart';
import '../application/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCheckingForUpdates = false;

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

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final currentTheme = ref.watch(themeModeProvider);
    final currentUser = ref.watch(currentUserProvider);
    final syncState = ref.watch(syncStateProvider);
    final autoBackupConfig = ref.watch(autoBackupConfigProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
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
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          children: [
            // Section: Cloud Sync & Encryption
            Text(
              'Cloud Sync & Encryption',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentUser == null) ...[
                    Text(
                      'End-to-End Encrypted Cloud Sync',
                      style: AppTypography.title.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Quiet Paper keeps notes offline on device. Sign in and set an encryption password to sync securely across devices with zero-knowledge encryption.',
                      style: AppTypography.bodySmall.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    QuietButton(
                      label: 'Set up Encrypted Sync',
                      icon: Icons.cloud_sync_outlined,
                      variant: QuietButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SyncAuthScreen(),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle_outlined,
                          size: 24,
                          color: colors.accent,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser.email,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatSyncStatus(syncState),
                                style: AppTypography.caption.copyWith(
                                  color: syncState.status == SyncStatus.syncError
                                      ? colors.error
                                      : colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        QuietButton(
                          label: 'Sync Now',
                          icon: Icons.sync_rounded,
                          variant: QuietButtonVariant.secondary,
                          onPressed: () {
                            ref.read(syncEngineProvider).syncNow();
                          },
                        ),
                        QuietButton(
                          label: 'Change Password',
                          icon: Icons.lock_reset_rounded,
                          variant: QuietButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ChangeEncryptionPasswordScreen(),
                              ),
                            );
                          },
                        ),
                        QuietButton(
                          label: 'Sign Out',
                          icon: Icons.logout_rounded,
                          variant: QuietButtonVariant.destructive,
                          onPressed: () async {
                            await ref.read(authServiceProvider).signOut();
                            await ref.read(keyManagerProvider).clearLocalKeys();
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: Appearance
            Text(
              'Appearance',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                children: [
                  _ThemeOptionTile(
                    title: 'System default',
                    icon: Icons.brightness_auto_rounded,
                    isSelected: currentTheme == ThemeMode.system,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.system);
                    },
                  ),
                  Divider(color: colors.divider, height: 1),
                  _ThemeOptionTile(
                    title: 'Light paper',
                    icon: Icons.light_mode_outlined,
                    isSelected: currentTheme == ThemeMode.light,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.light);
                    },
                  ),
                  Divider(color: colors.divider, height: 1),
                  _ThemeOptionTile(
                    title: 'Dark paper',
                    icon: Icons.dark_mode_outlined,
                    isSelected: currentTheme == ThemeMode.dark,
                    onTap: () {
                      ref
                          .read(themeModeProvider.notifier)
                          .setThemeMode(ThemeMode.dark);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: Import
            Text(
              'Import',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Import Markdown Folder',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Select a folder to scan and import all Markdown (.md) documents recursively, including frontmatter, file creation/modification dates, and subfolder tags.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      QuietButton(
                        label: 'Choose folder to import',
                        icon: Icons.folder_open_rounded,
                        variant: QuietButtonVariant.secondary,
                        onPressed: () async {
                          try {
                            final folderPath = await FilePicker.platform.getDirectoryPath();
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
                      QuietButton(
                        label: 'Select markdown files',
                        icon: Icons.file_open_outlined,
                        variant: QuietButtonVariant.secondary,
                        onPressed: () async {
                          try {
                            final result = await FilePicker.platform.pickFiles(
                              allowMultiple: true,
                              type: FileType.custom,
                              allowedExtensions: ['md', 'markdown'],
                            );
                            if (result != null && result.files.isNotEmpty && context.mounted) {
                              final items = await MarkdownImportScanner.processPickedFiles(result.files);
                              if (context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MarkdownImportScreen(
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
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: Local Backup & Restore
            Text(
              'Local Backup & Restore',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notebook Backups',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Export and restore complete .qpbackup snapshots, optionally protected with Argon2id encryption.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      QuietButton(
                        label: 'Create Backup',
                        icon: Icons.backup_rounded,
                        variant: QuietButtonVariant.primary,
                        onPressed: () => CreateBackupDialog.show(context),
                      ),
                      QuietButton(
                        label: 'Restore Backup',
                        icon: Icons.settings_backup_restore_rounded,
                        variant: QuietButtonVariant.secondary,
                        onPressed: () => RestoreBackupDialog.show(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Divider(color: colors.divider, height: 1),
                  const SizedBox(height: AppSpacing.md),

                  // Automated Rolling Backups
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Auto-Backup',
                              style: AppTypography.bodySmall.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Automatically saves snapshots on app launch',
                              style: AppTypography.caption.copyWith(
                                color: colors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: autoBackupConfig.enabled,
                        activeTrackColor: colors.accent,
                        onChanged: (val) async {
                          if (val && autoBackupConfig.folderPath == null) {
                            // Prompt for folder first
                            final folder =
                                await FilePicker.platform.getDirectoryPath(
                              dialogTitle: 'Select Auto-Backup Folder',
                            );
                            if (folder != null) {
                              await ref
                                  .read(autoBackupConfigProvider.notifier)
                                  .setFolderPath(folder);
                              await ref
                                  .read(autoBackupConfigProvider.notifier)
                                  .setEnabled(true);
                            }
                          } else {
                            await ref
                                .read(autoBackupConfigProvider.notifier)
                                .setEnabled(val);
                          }
                        },
                      ),
                    ],
                  ),

                  if (autoBackupConfig.enabled) ...[
                    const SizedBox(height: AppSpacing.md),
                    // Folder destination tile
                    InkWell(
                      onTap: () async {
                        final folder =
                            await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Change Auto-Backup Folder',
                        );
                        if (folder != null) {
                          await ref
                              .read(autoBackupConfigProvider.notifier)
                              .setFolderPath(folder);
                        }
                      },
                      borderRadius: AppRadii.borderSm,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.background,
                          borderRadius: AppRadii.borderSm,
                          border: Border.all(color: colors.divider),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.folder_open_rounded,
                                size: 20, color: colors.accent),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Backup Folder',
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    autoBackupConfig.folderPath ??
                                        'No folder selected',
                                    style: AppTypography.caption.copyWith(
                                      color: colors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: colors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Retention count dropdown & encryption config
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.background,
                              borderRadius: AppRadii.borderSm,
                              border: Border.all(color: colors.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.history_rounded,
                                    size: 18, color: colors.textSecondary),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Keep:',
                                  style: AppTypography.caption.copyWith(
                                      color: colors.textSecondary),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                DropdownButton<int>(
                                  value: autoBackupConfig.retentionCount,
                                  underline: const SizedBox.shrink(),
                                  dropdownColor: colors.surface,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                AutoBackupPasswordDialog.show(context),
                            borderRadius: AppRadii.borderSm,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm, vertical: 10),
                              decoration: BoxDecoration(
                                color: colors.background,
                                borderRadius: AppRadii.borderSm,
                                border: Border.all(color: colors.divider),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    autoBackupConfig.hasPassword
                                        ? Icons.lock_rounded
                                        : Icons.lock_open_rounded,
                                    size: 18,
                                    color: autoBackupConfig.hasPassword
                                        ? colors.accent
                                        : colors.textSecondary,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      autoBackupConfig.hasPassword
                                          ? 'Encrypted'
                                          : 'Plaintext',
                                      style: AppTypography.caption.copyWith(
                                        color: colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (autoBackupConfig.lastBackupAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Last backup: ${DateFormat.yMMMd().add_jm().format(autoBackupConfig.lastBackupAt!)}',
                        style: AppTypography.caption.copyWith(
                          color: colors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: Sample Data
            Text(
              'Sample Notes',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Populate example notes demonstrating Markdown, hashtags, and editorial formatting.',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  QuietButton(
                    label: 'Load sample notes',
                    icon: Icons.auto_stories_rounded,
                    variant: QuietButtonVariant.secondary,
                    onPressed: () async {
                      final repository = ref.read(notesRepositoryProvider);
                      await SampleNotes.populateSampleNotes(repository);
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
            ),

            const SizedBox(height: AppSpacing.xl),

            // Section: About
            Text(
              'About',
              style: AppTypography.caption.copyWith(
                color: colors.textTertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderMd,
                border: Border.all(color: colors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quiet Paper',
                    style: AppTypography.headline.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A quiet place to think.',
                    style: AppTypography.body.copyWith(
                      color: colors.accentDark,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Version 1.2.0 • Offline-first • End-to-End Encrypted Sync',
                    style: AppTypography.bodySmall.copyWith(
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  QuietButton(
                    label: 'Check for updates',
                    icon: Icons.system_update_rounded,
                    variant: QuietButtonVariant.secondary,
                    isLoading: _isCheckingForUpdates,
                    onPressed:
                        _isCheckingForUpdates ? null : _checkManualUpdate,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSyncStatus(SyncState state) {
    switch (state.status) {
      case SyncStatus.syncing:
        return 'Syncing changes...';
      case SyncStatus.synced:
        if (state.lastSyncedAt != null) {
          final time = DateFormat.jm().format(state.lastSyncedAt!);
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
        return state.errorMessage ?? 'Sync error occurred';
      case SyncStatus.localOnly:
        return 'Local storage only';
    }
  }
}

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14.0,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? colors.accent : colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isSelected ? colors.accent : colors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: colors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
