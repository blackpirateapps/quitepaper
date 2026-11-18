import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sync/sync_provider.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/application/notes_query_provider.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../application/email_editor_bridge.dart';
import '../application/email_import_gateway.dart';
import '../application/email_input.dart';
import 'email_import_screen.dart';

class EmailImportLauncher {
  static bool _active = false;
  static Completer<void>? _idle;
  static Future<void> get whenIdle => _idle?.future ?? Future.value();
  static bool get isActive => _active;
  static Future<List<Note>> open(
    BuildContext context,
    EmailImportRequest request, {
    bool openSavedNote = true,
  }) async {
    if (_active) return const [];
    _active = true;
    _idle = Completer<void>();
    try {
      final bridge = EmailEditorBridge.active;
      final current = await bridge?.prepare();
      if (!context.mounted) return const [];
      final container = ProviderScope.containerOf(context, listen: false);
      request.currentNoteId ??= current?.id;
      final notes = await Navigator.of(context, rootNavigator: true)
          .push<List<Note>>(
            MaterialPageRoute(
              settings: const RouteSettings(name: '/email-import'),
              builder: (_) => EmailImportScreen(request: request),
            ),
          );
      request.clear();
      // Even a canceled batch may have committed earlier items. Reconcile the
      // active editor and list before returning so a later edit cannot erase them.
      final committed = request.committedNoteIds.isNotEmpty;
      if (committed && current != null) {
        final latest = await container
            .read(notesRepositoryProvider)
            .getNoteById(current.id);
        if (latest != null &&
            !latest.isTrashed &&
            latest.content != current.content) {
          bridge?.accept(latest);
        }
      }
      if (committed) {
        container.read(notesCollectionProvider.notifier).refresh();
        container.read(syncEngineProvider).triggerSyncDebounced();
      }
      if (notes == null || notes.isEmpty) return const [];
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !committed
                  ? 'Opening existing note'
                  : notes.length == 1
                  ? 'Email saved'
                  : '${notes.length} emails saved',
            ),
          ),
        );
        if (openSavedNote && notes.first.id != current?.id) {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute<void>(
              builder: (_) => EditorScreen(note: notes.first),
            ),
          );
        }
      }
      return notes;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open email import. Check your notebook and try again.',
            ),
          ),
        );
      }
      return const [];
    } finally {
      request.clear();
      request.committedNoteIds.clear();
      _active = false;
      _idle?.complete();
      _idle = null;
    }
  }

  static Future<void> pick(
    BuildContext context, {
    bool allFiles = false,
  }) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Email',
        allowMultiple: true,
        type: allFiles ? FileType.any : FileType.custom,
        allowedExtensions: allFiles ? null : ['eml'],
        withData: false,
      );
      if (!context.mounted || picked == null) return;
      final inputs = picked.files
          .where((f) => f.path != null)
          .map((f) => EmailInput(path: f.path!, name: f.name))
          .toList();
      if (inputs.isEmpty) return;
      await open(context, EmailImportRequest(inputs: inputs));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not select email files. Check file access and try again.',
            ),
          ),
        );
      }
    }
  }
}
