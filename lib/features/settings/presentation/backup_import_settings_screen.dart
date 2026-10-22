import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/backup/backup_provider.dart';
import 'package:quitepaper/core/backup/presentation/auto_backup_password_dialog.dart';
import 'package:quitepaper/core/backup/presentation/create_backup_dialog.dart';
import 'package:quitepaper/core/backup/presentation/restore_backup_dialog.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/import/application/markdown_import_scanner.dart';
import 'package:quitepaper/features/import/presentation/markdown_import_screen.dart';
import 'widgets/settings_shared_widgets.dart';

/// Screen allowing the user to import notes and manage notebook backups.
class BackupImportSettingsScreen extends ConsumerWidget {
  const BackupImportSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
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
          'Backup & Import',
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
                // Section: Import
                // ==========================================
                buildSectionHeader(context, 'Import'),
                SettingsGroup(
                  children: [
                    SettingsInfoTile(
                      icon: Icons.import_contacts_outlined,
                      iconColor: colors.textSecondary,
                      title: 'Import Markdown Folder',
                      description:
                          'Select a folder to scan and import all Markdown (.md) documents recursively, including frontmatter, file creation/modification dates, and subfolder tags.',
                    ),
                    buildDivider(colors),
                    SettingsRow(
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
                    buildDivider(colors),
                    SettingsRow(
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
                buildSectionHeader(context, 'Local Backup & Restore'),
                SettingsGroup(
                  children: [
                    SettingsInfoTile(
                      icon: Icons.storage_outlined,
                      iconColor: colors.textSecondary,
                      title: 'Notebook Backups',
                      description:
                          'Export and restore complete .qpbackup snapshots, optionally protected with Argon2id encryption.',
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.backup_rounded,
                      iconColor: colors.accent,
                      title: 'Create Backup',
                      titleColor: colors.accent,
                      isPrimaryAction: true,
                      onTap: () => CreateBackupDialog.show(context),
                    ),
                    buildDivider(colors),
                    SettingsRow(
                      icon: Icons.settings_backup_restore_rounded,
                      title: 'Restore Backup',
                      onTap: () => RestoreBackupDialog.show(context),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Subgroup: Daily Auto-Backup
                SettingsGroup(
                  children: [
                    SettingsRow(
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
                      buildDivider(colors),
                      SettingsRow(
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
                      buildDivider(colors),
                      SettingsRow(
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
                      buildDivider(colors),
                      SettingsRow(
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
                  buildSectionFooter(
                    context,
                    'Last backup: ${DateFormat.yMMMd().add_jm().format(autoBackupConfig.lastBackupAt!)}',
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
