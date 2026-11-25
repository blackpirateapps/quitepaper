import '../../tasks/application/task_providers.dart';
import '../../tasks/presentation/task_capture_dialog.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/speech/presentation/speech_settings_view.dart';
import '../../../core/sync/sync_provider.dart';
import '../../settings/domain/default_settings.dart';
import '../../settings/presentation/settings_command_catalog.dart';
import '../../settings/presentation/storage_management_screen.dart';
import '../../settings/presentation/cloud_storage_screen.dart';
import '../../settings/presentation/default_settings_screen.dart';
import '../../settings/presentation/widgets/settings_target.dart';
import '../../sync/presentation/sync_auth_screen.dart';
import '../../sync/presentation/change_account_password_dialog.dart';
import '../../sync/presentation/change_encryption_password_screen.dart';
import '../../sync/presentation/conflict_list_screen.dart';
import '../../devices/presentation/devices_screen.dart';
import '../../share/presentation/manage_shares_screen.dart';
import '../../templates/presentation/templates_screen.dart';
import '../../tags/application/tag_providers.dart';
import '../../tags/application/tag_suggestions.dart';
import '../../watched_import/application/watched_import_provider.dart';
import '../../watched_import/presentation/watched_folders_screen.dart';
import '../application/notes_provider.dart';
import '../application/notes_query_provider.dart';
import '../domain/note_model.dart';
import '../domain/notes_query.dart';
import '../domain/notes_filter.dart';
import '../domain/notes_sort.dart';
import 'widgets/notes_command_palette.dart';
import 'widgets/notes_filter_sheet.dart';
import 'widgets/notes_sort_sheet.dart';

typedef WorkspaceCommandAction = FutureOr<void> Function();

Future<WorkspaceCommandAction?> showWorkspaceCommandPalette(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function(NotesCommand) onCommand,
  required Future<void> Function(Note) onNote,
  required Future<void> Function(String) onTag,
  required VoidCallback onSearch,
}) async {
  CommandPaletteEntry action(
    String label,
    String description,
    WorkspaceCommandAction callback, [
    IconData icon = Icons.tune,
  ]) => CommandPaletteEntry(
    label: label,
    description: description,
    icon: icon,
    value: callback,
  );
  Future<void> push(Widget page) =>
      Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  Future<void> account(WorkspaceCommandAction callback) async {
    if (ref.read(currentUserProvider) == null) {
      await push(const SyncAuthScreen());
    } else {
      await callback();
    }
  }

  final entries = <CommandPaletteEntry>[
    for (final command in NotesCommand.values)
      action(
        command.label,
        command.description,
        () => onCommand(command),
        command.icon,
      ),
    action('Tasks', 'Browse note checkboxes and due dates', () {
      ref.read(currentDestinationProvider.notifier).state =
          AppDestination.tasks;
    }, Icons.check_box_outlined),
    action(
      'New task',
      'Capture into Task Inbox, Today’s Journal or a note',
      () async {
        final result = await showTaskCapture(context);
        if (result != null && context.mounted && ref.read(taskSessionProvider)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added to ${result.note.displayTitle}'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await result.undo.run();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Undo is no longer available. The task was preserved.',
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
        }
      },
      Icons.add_task,
    ),
    action(
      'Quick Search Notes',
      'Type a title or text here • @ searches only notes',
      onSearch,
      Icons.search,
    ),
    action(
      'Jump to a Tag',
      'Type # followed by a tag, including parent/child',
      () async {
        await onTag('');
      },
      Icons.tag,
    ),
    action(
      'Sort notes',
      'Choose field, direction and pinned order',
      () => NotesSortSheet.show(context),
    ),
    for (final field in SortField.values)
      for (final direction in SortDirection.values)
        action(
          'Sort: ${field.displayName} • ${direction.getDisplayName(field)}',
          'Sort notes in the current workspace',
          () {
            final notifier = ref.read(notesQueryProvider.notifier);
            notifier.setSort(
              ref
                  .read(notesQueryProvider)
                  .sort
                  .copyWith(field: field, direction: direction),
            );
          },
        ),
    action('Sort: Pinned first', 'Toggle pinned notes before other notes', () {
      final sort = ref.read(notesQueryProvider).sort;
      ref
          .read(notesQueryProvider.notifier)
          .setSort(sort.copyWith(pinnedFirst: !sort.pinnedFirst));
    }),
    action(
      'Filter notes',
      'Tags, dates, security, content and attachments',
      () => NotesFilterSheet.show(context),
    ),
    action(
      'Clear all filters',
      'Reset the current workspace filters',
      () => ref.read(notesQueryProvider.notifier).clearAllFilters(),
    ),
    for (final filter in ContentFilter.values)
      action(
        'Filter: ${filter.displayName}',
        'Toggle content filter',
        () => ref.read(notesQueryProvider.notifier).toggleContentFilter(filter),
      ),
    for (final filter in AttachmentFilter.values)
      action(
        'Filter: ${filter.displayName}',
        'Toggle attachment filter',
        () => ref
            .read(notesQueryProvider.notifier)
            .toggleAttachmentFilter(filter),
      ),
    for (final filter in SecurityFilter.values)
      action('Filter: ${filter.displayName}', 'Filter by note protection', () {
        final query = ref.read(notesQueryProvider);
        ref
            .read(notesQueryProvider.notifier)
            .setFilters(query.filter.copyWith(securityFilter: filter));
      }),
    for (final destination in settingsCommandDestinations)
      action(destination.entry.label, destination.entry.description, () async {
        if (destination.page == 'Cloud Sync & Encryption') {
          await account(() => push(destination.build(context)));
        } else {
          await push(destination.build(context));
        }
      }, Icons.settings_outlined),
    action(
      'Settings: Templates',
      'Manage reusable note templates',
      () => push(const TemplatesScreen()),
      Icons.description_outlined,
    ),
    action(
      'Settings: Speech Recognition',
      'Offline voice models • download, select and delete models',
      () => SpeechSettingsView.show(context),
      Icons.mic_none,
    ),
    for (final option in ImageCompressionAction.values)
      action(
        'Image Compression: ${option.label}',
        'Settings → Default Settings → Image Compression',
        () => push(
          const SettingsTarget(
            title: 'Image Compression',
            child: DefaultSettingsScreen(),
          ),
        ),
      ),
    for (final option in ImageCompressionPreset.values)
      action(
        'Compression Quality: ${option.label}',
        option.description,
        () => push(
          const SettingsTarget(
            title: 'Compression Quality',
            child: DefaultSettingsScreen(),
          ),
        ),
      ),
    if (supportsWatchedImport)
      action(
        'Settings: Watched Folders',
        'Import & Capture • folders, file types, history, rescan and removal',
        () => push(const WatchedFoldersScreen()),
        Icons.folder_outlined,
      ),
    action(
      'Settings: Devices & Sessions',
      'Cloud Sync & Encryption • manage signed-in devices',
      () => account(() => push(const DevicesScreen())),
    ),
    action(
      'Settings: Account Password',
      'Cloud Sync & Encryption • change login password',
      () => account(() => ChangeAccountPasswordDialog.show(context)),
    ),
    action(
      'Settings: Encryption Password',
      'Cloud Sync & Encryption • vault password and recovery key',
      () => account(() => push(const ChangeEncryptionPasswordScreen())),
    ),
    action(
      'Settings: Review Sync Conflicts',
      'Cloud Sync & Encryption • resolve conflicting notes',
      () => account(() => push(const ConflictListScreen())),
    ),
    action(
      'Settings: Shared links',
      'Cloud Sync & Encryption • visibility, passwords and unshare',
      () => account(() => push(const ManageSharesScreen())),
    ),
    action(
      'Settings: Cloud Storage',
      'Cloud Sync & Encryption • storage usage and limits',
      () => account(() => push(const CloudStorageScreen())),
    ),
    for (final (tab, label) in [
      'Storage & Cleanup',
      'Attached Assets',
      'Orphaned Assets',
    ].indexed)
      action(
        'Settings: $label',
        'Cloud Sync & Encryption • local and cloud assets',
        () => account(() => push(StorageManagementScreen(initialTab: tab))),
      ),
  ];
  final result = await showCommandPalette(
    context,
    entries: entries,
    search: (query) async {
      final onlyTags = query.startsWith('#');
      final onlyNotes = query.startsWith('@');
      final term = (onlyTags || onlyNotes) ? query.substring(1).trim() : query;
      // The SQL/FTS repository bounds note results without loading the notebook.
      final notesFuture = onlyTags
          ? Future.value(<Note>[])
          : ref
                .read(notesRepositoryProvider)
                .executeNotesQuery(
                  NotesQuery(
                    searchQuery: term.isEmpty ? null : term,
                    limit: 12,
                  ),
                )
                .then((result) => result.notes);
      final tagsFuture = onlyNotes
          ? Future.value(<String>[])
          : ref
                .read(allTagsProvider.future)
                .then(
                  (tags) => ref
                      .read(tagSuggestionServiceProvider)
                      .search(
                        tags: tags,
                        query: term,
                        recent: ref.read(recentTagNamesProvider),
                        excluded: {},
                        limit: 12,
                      ),
                );
      final results = await Future.wait([notesFuture, tagsFuture]);
      return [
        for (final note in results[0] as List<Note>)
          action(
            note.isPasswordProtected
                ? 'Protected note'
                : (note.title.isEmpty ? 'Untitled' : note.title),
            'Note${note.isPasswordProtected || note.tags.isEmpty ? '' : ' • ${note.tags.map((t) => '#$t').join(' ')}'}',
            () => onNote(note),
            Icons.description_outlined,
          ),
        for (final tag in results[1] as List<String>)
          action('#$tag', 'Jump to tag', () => onTag(tag), Icons.tag),
      ];
    },
  );
  if (!context.mounted || result == null) return null;
  return result.value as WorkspaceCommandAction;
}
