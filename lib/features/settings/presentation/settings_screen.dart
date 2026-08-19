import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
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
import '../../notes/application/notes_provider.dart';
import '../../notes/application/sample_notes.dart';
import '../../sync/presentation/change_encryption_password_screen.dart';
import '../../sync/presentation/sync_auth_screen.dart';
import '../application/settings_provider.dart';
import '../application/typography_provider.dart';
import 'typography_settings_screen.dart';

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
                      _SettingsInfoTile(
                        icon: Icons.account_circle_outlined,
                        iconColor: colors.accent,
                        title: currentUser.email,
                        description: _formatSyncStatus(syncState),
                        descriptionColor: syncState.status == SyncStatus.syncError
                            ? colors.error
                            : colors.textSecondary,
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.sync_rounded,
                        title: 'Sync Now',
                        trailing: syncState.status == SyncStatus.syncing
                            ? const CupertinoActivityIndicator(radius: 8)
                            : null,
                        onTap: () {
                          ref.read(syncEngineProvider).syncNow();
                        },
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.lock_reset_rounded,
                        title: 'Change Password',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ChangeEncryptionPasswordScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(colors),
                      _SettingsRow(
                        icon: Icons.logout_rounded,
                        iconColor: colors.error,
                        title: 'Sign Out',
                        titleColor: colors.error,
                        isDestructive: true,
                        onTap: () async {
                          await ref.read(authServiceProvider).signOut();
                          await ref.read(keyManagerProvider).clearLocalKeys();
                        },
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 24),

                // ==========================================
                // Section: Appearance
                // ==========================================
                _buildSectionHeader(context, 'Appearance'),
                _SettingsGroup(
                  children: [
                    _SettingsRow(
                      icon: Icons.brightness_auto_rounded,
                      title: 'System default',
                      isSelected: currentTheme == ThemeMode.system,
                      onTap: () {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.system);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.light_mode_outlined,
                      title: 'Light paper',
                      isSelected: currentTheme == ThemeMode.light,
                      onTap: () {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.light);
                      },
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      title: 'Dark paper',
                      isSelected: currentTheme == ThemeMode.dark,
                      onTap: () {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(ThemeMode.dark);
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
                            builder: (_) => const TypographySettingsScreen(),
                          ),
                        );
                      },
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
                          final result = await FilePicker.platform.pickFiles(
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
                      subtitle: 'Automatically saves snapshots on app launch',
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
                                .read(autoBackupConfigProvider.notifier)
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
                                    .read(autoBackupConfigProvider.notifier)
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
                          'A quiet place to think.\nVersion 1.3.1 • Offline-first • End-to-End Encrypted Sync',
                    ),
                    _buildDivider(colors),
                    _SettingsRow(
                      icon: Icons.system_update_rounded,
                      title: 'Check for updates',
                      trailing: _isCheckingForUpdates
                          ? const CupertinoActivityIndicator(radius: 8)
                          : null,
                      onTap: _isCheckingForUpdates ? null : _checkManualUpdate,
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
      thickness: 0.8,
      indent: 52, // 16 horizontal padding + 24 icon box + 12 gap = 52
      endIndent: 0,
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
        borderRadius: BorderRadius.circular(11.0),
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
                    fontSize: 15.0,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  description,
                  style: AppTypography.caption.copyWith(
                    color: descriptionColor ?? colors.textSecondary,
                    fontSize: 12.5,
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
    required this.icon,
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
  });

  final IconData icon;
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
                  child: Icon(
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
                        fontSize: 15.0,
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

