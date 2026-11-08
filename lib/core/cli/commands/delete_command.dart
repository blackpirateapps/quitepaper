import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';
import '../interactive_picker.dart';

/// Command to move notes to trash, restore notes, or permanently delete them.
class DeleteCommand extends Command<int> {
  DeleteCommand(this._dbProvider, {InteractivePicker? picker})
      : _picker = picker ?? const InteractivePicker() {
    argParser
      ..addFlag('permanent', abbr: 'f', negatable: false, help: 'Permanently remove note instead of moving to trash')
      ..addFlag('restore', abbr: 'r', negatable: false, help: 'Restore note from trash');
  }

  final CliDatabase Function() _dbProvider;
  final InteractivePicker _picker;

  @override
  String get name => 'delete';

  @override
  List<String> get aliases => const ['rm', 'del'];

  @override
  String get description => 'Move a note to trash or delete it permanently.';

  @override
  Future<int> run() async {
    final db = _dbProvider();
    final permanent = argResults?['permanent'] as bool? ?? false;
    final restore = argResults?['restore'] as bool? ?? false;

    CliNote? targetNote;
    final rest = argResults?.rest ?? const [];

    if (rest.isEmpty) {
      final notes = db.listNotes(showTrash: restore, limit: 50);
      if (notes.isEmpty) {
        stdout.writeln(CliFormatters.dim(restore ? 'Trash is empty.' : 'No notes found to delete.'));
        return 0;
      }
      targetNote = await _picker.pickNote(
        notes,
        promptTitle: restore ? 'Select note to restore' : 'Select note to delete',
      );
      if (targetNote == null) return 0;
    } else {
      final query = rest.join(' ').trim();
      targetNote = db.getNoteByIdOrPrefix(query);
      if (targetNote == null) {
        final candidates = db.findNotesByTitle(query);
        if (candidates.isEmpty) {
          stderr.writeln(CliFormatters.red('Error: No note found matching "$query".'));
          return 1;
        } else if (candidates.length == 1) {
          targetNote = candidates.first;
        } else {
          targetNote = await _picker.pickNote(candidates, promptTitle: 'Select matching note');
          if (targetNote == null) return 0;
        }
      }
    }

    if (restore) {
      db.restoreNote(targetNote.id);
      stdout.writeln(CliFormatters.green('✓ Restored note: ${targetNote.displayTitle} [${targetNote.shortId}]'));
      return 0;
    }

    if (permanent) {
      db.deletePermanently(targetNote.id);
      stdout.writeln(CliFormatters.red('✓ Permanently deleted note: ${targetNote.displayTitle} [${targetNote.shortId}]'));
      return 0;
    }

    db.trashNote(targetNote.id);
    stdout.writeln(CliFormatters.yellow('✓ Moved to trash: ${targetNote.displayTitle} [${targetNote.shortId}]'));
    stdout.writeln(CliFormatters.dim('  (Use "qp delete --restore ${targetNote.shortId}" to restore)'));
    return 0;
  }
}
