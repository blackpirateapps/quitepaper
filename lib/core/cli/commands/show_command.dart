import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';
import '../interactive_picker.dart';

/// Command to print note content or metadata to stdout for terminal viewing and piping.
class ShowCommand extends Command<int> {
  ShowCommand(this._dbProvider, {InteractivePicker? picker})
      : _picker = picker ?? const InteractivePicker() {
    argParser
      ..addFlag('raw', negatable: false, help: 'Print raw Markdown content only without headers')
      ..addFlag('info', abbr: 'i', negatable: false, help: 'Display note metadata (dates, word count, tags)')
      ..addFlag('json', negatable: false, help: 'Output note object in JSON format');
  }

  final CliDatabase Function() _dbProvider;
  final InteractivePicker _picker;

  @override
  String get name => 'show';

  @override
  List<String> get aliases => const ['cat', 'view', 's'];

  @override
  String get description => 'Display note content or metadata to stdout for terminal viewing and piping.';

  @override
  Future<int> run() async {
    final db = _dbProvider();
    final isRaw = argResults?['raw'] as bool? ?? false;
    final isInfo = argResults?['info'] as bool? ?? false;
    final isJson = argResults?['json'] as bool? ?? false;

    CliNote? targetNote;
    final rest = argResults?.rest ?? const [];

    if (rest.isEmpty) {
      final notes = db.listNotes(limit: 50);
      if (notes.isEmpty) {
        stdout.writeln(CliFormatters.dim('No notes found in vault.'));
        return 0;
      }
      targetNote = await _picker.pickNote(notes, promptTitle: 'Select note to view');
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

    if (isJson) {
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(targetNote.toJson()));
      return 0;
    }

    if (isInfo) {
      stdout.writeln('=== Note Metadata ===');
      stdout.writeln('ID:        ${targetNote.id} (Short: ${targetNote.shortId})');
      stdout.writeln('Title:     ${targetNote.displayTitle}');
      stdout.writeln('Pinned:    ${targetNote.isPinned ? "Yes" : "No"}');
      stdout.writeln('Archived:  ${targetNote.isArchived ? "Yes" : "No"}');
      stdout.writeln('Trashed:   ${targetNote.isTrashed ? "Yes" : "No"}');
      stdout.writeln('Created:   ${targetNote.createdAt.toIso8601String()}');
      stdout.writeln('Updated:   ${targetNote.updatedAt.toIso8601String()} (${CliFormatters.formatRelativeTime(targetNote.updatedAt)})');
      if (targetNote.tags.isNotEmpty) {
        stdout.writeln('Tags:      #${targetNote.tags.join(' #')}');
      }
      if (targetNote.journalDate != null) {
        stdout.writeln('Journal:   ${targetNote.journalDate}');
      }
      final words = targetNote.content.trim().isEmpty ? 0 : targetNote.content.trim().split(RegExp(r'\s+')).length;
      stdout.writeln('Length:    ${targetNote.content.length} characters, $words words');
      return 0;
    }

    if (isRaw) {
      stdout.write(targetNote.content);
      if (!targetNote.content.endsWith('\n')) stdout.writeln();
      return 0;
    }

    // Default formatting: if content already has the title heading, print as is; else print # Title
    final trimmed = targetNote.content.trim();
    if (targetNote.title.isNotEmpty && !trimmed.startsWith('#') && !trimmed.startsWith('---')) {
      stdout.writeln('# ${targetNote.title}');
      stdout.writeln();
    }
    stdout.write(targetNote.content);
    if (!targetNote.content.endsWith('\n')) stdout.writeln();
    return 0;
  }
}
