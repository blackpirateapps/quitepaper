import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';
import '../external_editor_runner.dart';

/// Command to create a new note via external editor or stdin pipe.
class NewCommand extends Command<int> {
  NewCommand(this._dbProvider, {ExternalEditorRunner? editorRunner})
      : _editorRunner = editorRunner ?? const ExternalEditorRunner() {
    argParser
      ..addOption('title', abbr: 't', help: 'Title for the new note')
      ..addMultiOption('tag', abbr: 'T', help: 'Initial tag(s) to attach (e.g. -T work -T ideas)')
      ..addOption('editor', abbr: 'e', help: 'Editor command to use (overrides \$EDITOR / \$VISUAL)')
      ..addFlag('pinned', abbr: 'p', negatable: false, help: 'Pin the new note');
  }

  final CliDatabase Function() _dbProvider;
  final ExternalEditorRunner _editorRunner;

  @override
  String get name => 'new';

  @override
  List<String> get aliases => const ['create', 'add', 'n'];

  @override
  String get description => 'Create a new note using your external editor (nvim/vim/nano) or stdin.';

  @override
  Future<int> run() async {
    final db = _dbProvider();
    final explicitTitle = argResults?['title'] as String?;
    final explicitTags = argResults?['tag'] as List<String>? ?? const [];
    final explicitEditor = argResults?['editor'] as String?;
    final isPinned = argResults?['pinned'] as bool? ?? false;

    // First check if a title was passed as a positional argument
    String? title = explicitTitle;
    if (title == null && (argResults?.rest.isNotEmpty ?? false)) {
      title = argResults!.rest.join(' ');
    }

    // Check if input is being piped via stdin (e.g. `cat file.md | qp new`)
    if (!stdin.hasTerminal) {
      final content = await stdin.transform(utf8.decoder).join();
      if (content.trim().isEmpty) {
        stderr.writeln(CliFormatters.red('Error: Stdin was empty. Note not created.'));
        return 1;
      }

      final parsed = _editorRunner.parseTitleAndContent(content, fallbackTitle: title);
      final note = db.createNote(
        title: parsed.$1,
        content: parsed.$2,
        tags: explicitTags,
        isPinned: isPinned,
      );

      stdout.writeln(CliFormatters.green('Created note: ${note.displayTitle} (${note.shortId})'));
      return 0;
    }

    // Interactive external editor flow
    final result = await _editorRunner.openInEditor(
      initialTitle: title,
      explicitEditor: explicitEditor,
      prefix: 'qp_new',
    );

    if (result == null || !result.wasModified || result.content.trim().isEmpty) {
      stdout.writeln(CliFormatters.dim('Note creation cancelled (empty or unchanged).'));
      return 0;
    }

    final note = db.createNote(
      title: result.title,
      content: result.content,
      tags: explicitTags,
      isPinned: isPinned,
    );

    stdout.writeln(CliFormatters.green('✓ Created note: ${note.displayTitle} [${note.shortId}]'));
    if (note.tags.isNotEmpty) {
      stdout.writeln(CliFormatters.blue('  Tags: #${note.tags.join(' #')}'));
    }
    return 0;
  }
}
