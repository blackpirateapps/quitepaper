import 'reveal_watched_source.dart';
import 'package:file_selector_linux/file_selector_linux.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/theme/app_colors.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_provider.dart';
import '../application/watched_import_provider.dart';
import '../application/watched_import_controller.dart';

class WatchedFoldersScreen extends ConsumerWidget {
  const WatchedFoldersScreen({super.key});
  Future<void> _choose(WatchedImportController controller) async {
    final path = await FileSelectorLinux().getDirectoryPath(
      confirmButtonText: 'Watch folder',
    );
    if (path != null) await controller.enroll(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(watchedImportControllerProvider);
    final folder = controller.configuration;
    final colors = context.appColors;
    final pending = folder?.read<String>('review_state') == 'pending';
    final complete = folder?.read<int>('inventory_complete') == 1;
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
              const Text(
                'On Linux, Quiet Paper can import files from one folder while the app is running. Files saved while it is closed are found next time. Originals stay exactly as they are.',
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
              if (folder == null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: controller.busy
                        ? null
                        : () => _choose(controller),
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Choose folder'),
                  ),
                )
              else ...[
                SelectableText(folder.read<String>('canonical_root')),
                const SizedBox(height: 8),
                Text(
                  controller.health,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (folder.readNullable<int>('last_reconcile')
                    case final int last)
                  Text(
                    'Last scan: ${DateTime.fromMillisecondsSinceEpoch(last).toLocal()}',
                  ),
                const SizedBox(height: 16),
                if (pending) ...[
                  Text(
                    complete
                        ? 'Review existing files'
                        : 'Scanning existing files…',
                  ),
                  Text(
                    '${controller.scanned} eligible files · ${(controller.bytes / 1024 / 1024).toStringAsFixed(1)} MB',
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
                        onPressed: complete && !controller.busy
                            ? () => controller.decide(true)
                            : null,
                        child: const Text('Import existing files'),
                      ),
                      OutlinedButton(
                        onPressed: complete && !controller.busy
                            ? () => controller.decide(false)
                            : null,
                        child: const Text('Only import new files'),
                      ),
                      TextButton(
                        onPressed: controller.busy ? null : controller.remove,
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: folder.read<int>('enabled') == 1
                            ? controller.pause
                            : controller.resume,
                        child: Text(
                          folder.read<int>('enabled') == 1 ? 'Pause' : 'Resume',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: controller.rescan,
                        child: const Text('Rescan now'),
                      ),
                      TextButton(
                        onPressed: () => launchUrl(
                          Uri.directory(folder.read<String>('canonical_root')),
                        ),
                        child: const Text('Open folder'),
                      ),
                      TextButton(
                        onPressed: () =>
                            _confirmRemove(context, controller, change: true),
                        child: const Text('Change folder'),
                      ),
                      TextButton(
                        onPressed: () => _confirmRemove(context, controller),
                        child: const Text('Remove watched folder'),
                      ),
                    ],
                  ),
              ],
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
                        await revealWatchedSource(job);
                      }
                    },
                    itemBuilder: (context) => [
                      if (event.readNullable<String>('note_id') != null &&
                          controller.isUnlocked())
                        const PopupMenuItem(
                          value: 'open',
                          child: Text('Open imported note'),
                        ),
                      if (folder != null) ...[
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
                'From Proton Mail Free: open a message in your browser, choose Export, and save the .eml file into this folder. Quiet Paper uses the same email importer as Import Email.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Folder access is local to this Linux installation. In Flatpak, the native folder chooser grants access through the desktop portal. If access is revoked or the folder changes identity, select it again.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WatchedImportController controller, {
    bool change = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          change ? 'Change watched folder?' : 'Remove watched folder?',
        ),
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
            child: Text(change ? 'Change' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.remove();
      if (change) await _choose(controller);
    }
  }

  static String _error(String code) => switch (code) {
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
