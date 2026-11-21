import 'reveal_watched_source.dart';
import 'package:drift/drift.dart' show QueryRow;
import '../domain/watched_file_type.dart';
import 'package:file_selector_linux/file_selector_linux.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../application/android_folder_access.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../application/watched_import_provider.dart';
import '../application/watched_import_controller.dart';

class WatchedFoldersScreen extends ConsumerWidget {
  const WatchedFoldersScreen({super.key});
  Future<void> _choose(
    BuildContext context,
    WatchedImportController controller,
  ) async {
    try {
      final path = defaultTargetPlatform == TargetPlatform.android
          ? await const MethodChannelAndroidFolderAccess().chooseFolder()
          : await FileSelectorLinux().getDirectoryPath(
              confirmButtonText: 'Watch folder',
            );
      if (path != null) await controller.enroll(path);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Folder access could not be retained. Choose the folder again.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _openSource(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open the source. Restore folder access and try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(watchedImportControllerProvider);
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(title: const Text('Watched Folders')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Import & Capture', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 16),
              const Text(
                'Save a file. Find it in your notebook.',
                style: TextStyle(fontSize: 24),
              ),
              const SizedBox(height: 12),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? 'Quiet Paper checks your selected folders about every 30 seconds while the app is open. It catches up when you return. Originals stay exactly as they are. Android may restrict some folders; choose a subfolder such as Downloads/Quiet Paper.'
                    : 'On Linux, Quiet Paper can import files from your watched folders while the app is running. Files saved while it is closed are found next time. Originals stay exactly as they are.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Includes subfolders · Skips already imported files · Keeps originals',
              ),
              const SizedBox(height: 12),
              const Text(
                'Email (.eml), PDF, Markdown, text, PNG, JPEG and WebP. No automatic OCR.',
              ),
              const SizedBox(height: 20),
              if (controller.error != null)
                Text(
                  _error(controller.error!),
                  style: TextStyle(color: colors.accent),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: controller.busy
                      ? null
                      : () => _choose(context, controller),
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(
                    controller.folders.isEmpty ? 'Choose folder' : 'Add folder',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final folder in controller.folders)
                _folderCard(context, controller, folder),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                'Import history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              if (controller.history.isNotEmpty)
                Text(
                  'Recent: ${controller.history.where((row) => row.read<String>('type') == 'imported').length} imported · ${controller.history.where((row) => row.read<String>('type') == 'duplicate_skipped').length} duplicates · ${controller.history.where((row) => const {'failed', 'needs_attention', 'retry_scheduled'}.contains(row.read<String>('type'))).length} need attention',
                ),
              if (controller.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No imports yet.'),
                ),
              for (final event in controller.history)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(event.read<String>('display_name')),
                  subtitle: Text(
                    '${event.read<String>('type').replaceAll('_', ' ')} · ${event.read<String>('format')}\n${DateTime.fromMillisecondsSinceEpoch(event.read<int>('time')).toLocal()}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Import actions',
                    onSelected: (action) async {
                      final id = event.read<String>('job_id');
                      if (action == 'retry') {
                        await controller.retry(id);
                      } else if (action == 'again') {
                        if (await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Import another copy?'),
                                content: const Text(
                                  'This explicitly creates another note from this source file. The original file stays untouched.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Import again anyway'),
                                  ),
                                ],
                              ),
                            ) ==
                            true) {
                          await controller.importAgain(id);
                        }
                      } else if (action == 'open') {
                        final note = await ref
                            .read(notesRepositoryProvider)
                            .getNoteById(event.read<String>('note_id'));
                        if (note != null && context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EditorScreen(note: note),
                            ),
                          );
                        }
                      } else {
                        final job = (await controller.store.rows(
                          'SELECT * FROM watched_import_jobs WHERE id=?',
                          [id],
                        )).single;
                        if (context.mounted) {
                          await _openSource(
                            context,
                            () => revealWatchedSource(job),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      if (event.readNullable<String>('note_id') != null &&
                          controller.isUnlocked())
                        const PopupMenuItem(
                          value: 'open',
                          child: Text('Open imported note'),
                        ),
                      if (controller.folders.any(
                        (folder) =>
                            folder.read<String>('id') ==
                            event.readNullable<String>('folder_id'),
                      )) ...[
                        const PopupMenuItem(
                          value: 'retry',
                          child: Text('Retry'),
                        ),
                        const PopupMenuItem(
                          value: 'again',
                          child: Text('Import again anyway'),
                        ),
                        const PopupMenuItem(
                          value: 'reveal',
                          child: Text('Reveal source file'),
                        ),
                      ],
                    ],
                  ),
                ),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'From Proton Mail Free: open a message in your browser, choose Export, and save the .eml file into a watched folder with Email selected. Quiet Paper uses the same email importer as Import Email.',
              ),
              const SizedBox(height: 12),
              Text(
                defaultTargetPlatform == TargetPlatform.android
                    ? 'Android grants read access only to folders you select. Access is retained after restart. If access is revoked or a folder is moved, remove the watch and select it again. No background service or automatic OCR runs.'
                    : 'Folder access is local to this Linux installation. In Flatpak, the native folder chooser grants access through the desktop portal. If access is revoked or the folder changes identity, select it again.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folderCard(
    BuildContext context,
    WatchedImportController controller,
    QueryRow folder,
  ) {
    final id = folder.read<String>('id');
    final root = folder.read<String>('canonical_root');
    final name = folder.read<String>('display_name');
    final label = name.isNotEmpty
        ? name
        : root.startsWith('content:')
        ? 'Selected folder'
        : root;
    final enabled = folder.read<int>('enabled') == 1;
    final pending = folder.read<String>('review_state') == 'pending';
    final complete = folder.read<int>('inventory_complete') == 1;
    final changing = controller.changing(id);
    final selected = WatchedFileType.decode(folder.read<String>('file_types'));
    final error = controller.errorFor(id);
    return Card(
      key: ValueKey('watched-folder-$id'),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(controller.healthFor(id)),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Watch $label',
                  child: Switch.adaptive(
                    key: ValueKey('enable-$id'),
                    value: enabled,
                    onChanged: changing
                        ? null
                        : (value) => value
                              ? controller.resume(id)
                              : controller.pause(id),
                  ),
                ),
              ],
            ),
            if (folder.readNullable<int>('last_reconcile') case final int last)
              Text(
                'Last scan: ${DateTime.fromMillisecondsSinceEpoch(last).toLocal()}',
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error(error),
                  style: TextStyle(color: context.appColors.accent),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'File types to import',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in WatchedFileType.values)
                  FilterChip(
                    key: ValueKey('type-$id-${type.name}'),
                    label: Text(type.label),
                    selected: selected.contains(type),
                    onSelected: changing
                        ? null
                        : (value) {
                            final next = {...selected};
                            value ? next.add(type) : next.remove(type);
                            controller.setFileTypes(id, next);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              selected.isEmpty
                  ? 'Select a file type to import files from this folder.'
                  : 'Type changes apply on the next scan. Only new files keeps the original baseline. Images linked in Markdown are included with the note.',
            ),
            if (pending) ...[
              const SizedBox(height: 16),
              Text(
                complete ? 'Review existing files' : 'Scanning existing files…',
              ),
              Text(
                '${controller.countFor(id)} eligible files · ${(controller.bytesFor(id) / 1024 / 1024).toStringAsFixed(1)} MB',
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose what to do with the files already here. Nothing imports until you decide.',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        complete && enabled && !changing && !controller.busy
                        ? () => controller.decide(true, id)
                        : null,
                    child: const Text('Import existing files'),
                  ),
                  OutlinedButton(
                    onPressed:
                        complete && enabled && !changing && !controller.busy
                        ? () => controller.decide(false, id)
                        : null,
                    child: const Text('Only import new files'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: enabled && !changing
                      ? () => controller.rescan(id)
                      : null,
                  child: const Text('Rescan now'),
                ),
                TextButton(
                  onPressed: () =>
                      _openSource(context, () => openWatchedFolder(root)),
                  child: const Text('Open folder'),
                ),
                TextButton(
                  onPressed: changing
                      ? null
                      : () => _confirmRemove(context, controller, id),
                  child: const Text('Remove folder'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WatchedImportController controller,
    String id,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove watched folder?'),
        content: const Text(
          'Imported notes, duplicate receipts and original files are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.remove(id);
    }
  }

  static String _error(String code) => switch (code) {
    'permission_needed' || 'invalid_tree' =>
      'Folder access is unavailable. Remove this watch and choose the folder again to grant access.',
    'provider_loading' =>
      'This folder provider is still loading. Keep the folder available and rescan when loading finishes.',
    'provider_document_incomplete' =>
      'A provider file is incomplete or virtual. Make it available as a regular local file and rescan before choosing.',
    'scan_limit' || 'scan_limit_or_cycle' =>
      'This folder exceeds the safe scan limits or contains a directory cycle. Choose smaller subfolders.',
    'folder_already_watched' =>
      'This folder is already being watched. Use its switch to enable it.',
    'html_complexity' =>
      'This email’s HTML exceeds the safe import limits. Its original file is unchanged. After updating Quiet Paper, use Retry in its import history menu. Code: html_complexity.',
    'message_id_changed' =>
      'A changed version of an imported email needs review. Use Import again anyway to create another note.',
    'review_interrupted' =>
      'The initial review was interrupted before its baseline was complete. Cancel and select the folder again to start a new review.',
    'inventory_incomplete' =>
      'Some existing files could not be checked. Restore access and rescan before choosing.',
    'account_changed_select_folder_again' =>
      'The notebook account changed. Select the folder again to enable imports for this notebook.',
    'locked' => 'Unlock your notebook to continue.',
    'native_unavailable_or_incompatible' =>
      'The native import engine is unavailable or incompatible. Reinstall a complete Linux bundle. Code: native_load.',
    _ =>
      'Import needs attention. Check folder permissions, available storage and notebook unlock state. Code: $code',
  };
}
