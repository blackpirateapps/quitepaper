import 'package:flutter/material.dart';
import '../../notes/presentation/widgets/notes_command_palette.dart';
import 'widgets/settings_target.dart';
import 'settings_screen.dart';
import 'default_settings_screen.dart';
import 'appearance_settings_screen.dart';
import 'typography_settings_screen.dart';
import 'backup_import_settings_screen.dart';
import 'general_advanced_settings_screen.dart';
import 'sync_advanced_settings_screen.dart';
import 'about_app_screen.dart';

/// Explicit destinations keep search independent of widget text/layout. Selecting
/// a setting opens its canonical page and reveals the control; changes retain
/// the setting's normal validation and confirmation flow.
class SettingsCommandDestination {
  const SettingsCommandDestination(this.page, this.control, this.builder);
  final String page;
  final String? control;
  final WidgetBuilder builder;

  Widget build(BuildContext context) => control == null
      ? builder(context)
      : SettingsTarget(
          title: control!,
          fallbackTitle: switch (control) {
            'Backup Folder' ||
            'Keep Backups' ||
            'Encryption' => 'Daily Auto-Backup',
            'Daemon Status' ||
            'Ollama Endpoint' ||
            'OCR Model' => 'Use Local Ollama OCR',
            _ => null,
          },
          child: builder(context),
        );

  CommandPaletteEntry get entry => CommandPaletteEntry(
    label: control == null ? page : '$page: $control',
    description: 'Settings${control == null ? '' : ' → $page'}',
    keywords: 'preferences configuration',
    icon: Icons.settings_outlined,
    value: this,
  );
}

final settingsCommandDestinations = [
  for (final page in _settingsPages) ...[
    SettingsCommandDestination(page.name, null, page.builder),
    for (final control in page.controls)
      SettingsCommandDestination(page.name, control, page.builder),
  ],
];

final _settingsPages =
    <({String name, WidgetBuilder builder, List<String> controls})>[
      (
        name: 'Settings',
        builder: (_) => const SettingsScreen(),
        controls: [
          'Set up Encrypted Sync',
          'Sync Now',
          'Privacy Policy',
          'Terms & Conditions',
          'Check for updates',
        ],
      ),
      (
        name: 'Default Settings',
        builder: (_) => const DefaultSettingsScreen(),
        controls: [
          'Super Editor',
          'WYSIWYG',
          'Markdown',
          'Smart web links',
          'Interactive Checklists in Preview',
          'Swipe to Search in Editor',
          'Swipe Down to Search in Notes List',
          'Image Compression',
          'Compression Quality',
          'Show place & weather on entries',
          'Bengali dates & numerals',
          "Auto-tag today's entry",
        ],
      ),
      (
        name: 'Appearance',
        builder: (_) => const AppearanceSettingsScreen(),
        controls: ['Classic Paper', 'Warm Paper', 'System', 'Light', 'Dark'],
      ),
      (
        name: 'Typography',
        builder: (_) => const TypographySettingsScreen(),
        controls: [
          'Heading Font',
          'Body Font',
          'Interface Font',
          'Code Font',
          'Bengali Font',
          'Font Size',
          'Line Height',
          'Letter Spacing',
          'Paragraph Indent',
          'Paragraph Width',
          'Reset to Default',
        ],
      ),
      (
        name: 'Backup and import',
        builder: (_) => const BackupImportSettingsScreen(),
        controls: [
          'Import Email',
          'Import Email from all files',
          'Choose folder to import',
          'Select markdown files',
          'Create Backup',
          'Restore Backup',
          'Daily Auto-Backup',
          'Backup Folder',
          'Keep Backups',
          'Encryption',
        ],
      ),
      (
        name: 'Advanced',
        builder: (_) => const GeneralAdvancedSettingsScreen(),
        controls: [
          'Use Local Ollama OCR',
          'Daemon Status',
          'Ollama Endpoint',
          'OCR Model',
          'Download All Attachments',
          'Rerun OCR for All Files',
          'Rebuild Search Index',
          'Load sample notes',
          'Link preview debug info',
        ],
      ),
      (
        name: 'Cloud Sync & Encryption',
        builder: (_) => const SyncAdvancedSettingsScreen(),
        controls: ['Verify Email Address', 'Sign Out'],
      ),
      (
        name: 'About Quiet Paper',
        builder: (_) => const AboutAppScreen(),
        controls: [
          'Show welcome tour',
          'Author Blog',
          'Author Website',
          'GitHub Repository',
          'Terms of Service',
          'Privacy Policy',
        ],
      ),
    ];
