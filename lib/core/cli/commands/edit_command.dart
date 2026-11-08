import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';
import '../external_editor_runner.dart';
import '../interactive_picker.dart';

/// Command to edit an existing note using an external editor (nvim/vim/nano).
class EditCommand extends Command<int> {
  EditCommand(
    this._dbProvider, {
    ExternalEditorRunner? editorRunner,
    InteractivePicker? picker,
  })  : _editorRunner = editorRunner ?? const ExternalEditorRunner(),
        _picker = picker ?? const InteractivePicker() {
    argParser
      ..addOption('editor', abbr: 'e', help: 'Editor command to use (overrides \$EDITOR / \$VISUAL)')
      ..addFlag('pinned', abbr: 'p', negatable: true, defaultsTo: null, help: 'Update pinned status');
  }

  final CliDatabase Function() _dbProvider;
  final ExternalEditorRunner _editorRunner;
  final InteractivePicker _picker;

  @override
  String get name => 'edit';

  @override
  List<String> get aliases => const ['e', 'modify'];

  @override
  String get description => 'Edit an existing note using your external editor (nvim/vim/nano).';

  @override
  Future<int> run() async {
    final db = _dbProvider();
    final explicitEditor = argResults?['editor'] as String?;
    final isPinned = argResults?['pinned'] as bool?;

    CliNote? targetNote;

    final rest = argResults?.rest ?? const [];
    if (rest.isEmpty) {
      // Interactive selection if no note specified
      final notes = db.listNotes(limit: 50);
      if (notes.isEmpty) {
        stdout.writeln(CliFormatters.dim('No notes found in vault to edit.'));
        return 0;
      }
      targetNote = await _picker.pickNote(notes, promptTitle: 'Select note to edit');
      if (targetNote == null) {
        stdout.writeln(CliFormatters.dim('Edit cancelled.'));
        return 0;
      }
    } else {
      final query = rest.join(' ').trim();
      targetNote = db.getNoteByIdOrPrefix(query);

      if (targetNote == null) {
        // Try searching by title
        final candidates = db.findNotesByTitle(query);
        if (candidates.isEmpty) {
          stderr.writeln(CliFormatters.red('Error: No note found matching "$query".'));
          return 1;
        } else if (candidates.length == 1) {
          targetNote = candidates.first;
        } else {
          // Disambiguate multiple matches
          stdout.writeln('Multiple notes matched "$query":');
          targetNote = await _picker.pickNote(candidates, promptTitle: 'Select matching note');
          if (targetNote == null) {
            stdout.writeln(CliFormatters.dim('Edit cancelled.'));
            return 0;
          }
        }
      }
    }

    final result = await _editorRunner.openInEditor(
      initialTitle: targetNote.title,
      initialContent: targetNote.content,
      explicitEditor: explicitEditor,
      prefix: 'qp_edit_${targetNote.shortId}',
    );

    if (result == null || !result.wasModified) {
      if (isPinned != null && isPinned != targetNote.isPinned) {
        db.updateNote(
          id: targetNote.id,
          title: targetNote.title,
          content: targetNote.content,
          isPinned: isPinned,
        );
        stdout.writeln(CliFormatters.green('✓ Updated pin status for [${targetNote.shortId}]'));
        return 0;
      }
      stdout.writeln(CliFormatters.dim('No changes made.'));
      return 0;
    }

    final updated = db.updateNote(
      id: targetNote.id,
      title: result.title,
      content: result.content,
      isPinned: isPinned ?? targetNote.isPinned,
    );

    stdout.writeln(CliFormatters.green('✓ Saved note: ${updated.displayTitle} [${updated.shortId}]'));
    if (updated.tags.isNotEmpty) {
      stdout.writeln(CliFormatters.blue('  Tags: #${updated.tags.join(' #')}'));
    }
    return 0;
  }
}
