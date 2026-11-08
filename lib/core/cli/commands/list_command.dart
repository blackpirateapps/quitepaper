import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_database.dart';
import '../cli_formatters.dart';

/// Command to list notes with formatting, filtering, search, and JSON export.
class ListCommand extends Command<int> {
  ListCommand(this._dbProvider) {
    argParser
      ..addOption('tag', abbr: 't', help: 'Filter notes by tag (e.g. -t ideas or -t journal/2026)')
      ..addOption('search', abbr: 's', aliases: ['query', 'q'], help: 'Search note titles and contents')
      ..addFlag('pinned', abbr: 'p', negatable: false, help: 'Show only pinned notes')
      ..addFlag('archived', abbr: 'a', negatable: false, help: 'Show archived notes')
      ..addFlag('trash', negatable: false, help: 'Show notes in the trash')
      ..addOption('limit', abbr: 'n', help: 'Maximum number of notes to display')
      ..addFlag('json', negatable: false, help: 'Output in JSON format for scripting')
      ..addFlag('plain', negatable: false, help: 'Output tab-separated plain text without styling');
  }

  final CliDatabase Function() _dbProvider;

  @override
  String get name => 'list';

  @override
  List<String> get aliases => const ['ls'];

  @override
  String get description => 'List notes with optional tag filters, search queries, or JSON export.';

  @override
  int run() {
    final db = _dbProvider();
    final tag = argResults?['tag'] as String?;
    final search = argResults?['search'] as String?;
    final pinnedOnly = argResults?['pinned'] as bool? ?? false;
    final archived = argResults?['archived'] as bool? ?? false;
    final trash = argResults?['trash'] as bool? ?? false;
    final limitStr = argResults?['limit'] as String?;
    final limit = limitStr != null ? int.tryParse(limitStr) : null;
    final isJson = argResults?['json'] as bool? ?? false;
    final isPlain = argResults?['plain'] as bool? ?? false;

    final notes = db.listNotes(
      tag: tag,
      query: search,
      pinnedOnly: pinnedOnly ? true : null,
      showArchived: archived,
      showTrash: trash,
      limit: limit,
    );

    if (isJson) {
      final jsonList = notes.map((n) => n.toJson()).toList();
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(jsonList));
      return 0;
    }

    if (isPlain) {
      for (final n in notes) {
        final tagsStr = n.tags.join(',');
        stdout.writeln('${n.shortId}\t${n.displayTitle}\t$tagsStr\t${n.updatedAt.toIso8601String()}');
      }
      return 0;
    }

    if (notes.isEmpty) {
      if (trash) {
        stdout.writeln(CliFormatters.dim('Trash is empty.'));
      } else if (archived) {
        stdout.writeln(CliFormatters.dim('No archived notes found.'));
      } else if (tag != null) {
        stdout.writeln(CliFormatters.dim('No notes found with tag #$tag.'));
      } else if (search != null) {
        stdout.writeln(CliFormatters.dim('No notes matched "$search".'));
      } else {
        stdout.writeln(CliFormatters.dim('No notes found in vault. Create one with: qp new'));
      }
      return 0;
    }

    // Determine terminal column width if available
    int termWidth = 100;
    if (stdout.hasTerminal) {
      termWidth = stdout.terminalColumns;
    }

    final idColWidth = 8;
    final timeColWidth = 10;
    final tagsColWidth = 22;
    final titleColWidth = (termWidth - idColWidth - timeColWidth - tagsColWidth - 10).clamp(20, 80);

    // Header
    final headerPin = ' ';
    final headerId = 'ID'.padRight(idColWidth);
    final headerTitle = 'TITLE'.padRight(titleColWidth);
    final headerTags = 'TAGS'.padRight(tagsColWidth);
    final headerTime = 'UPDATED'.padLeft(timeColWidth);
    stdout.writeln(CliFormatters.bold('$headerPin $headerId  $headerTitle  $headerTags  $headerTime'));
    stdout.writeln(CliFormatters.dim('─' * (idColWidth + titleColWidth + tagsColWidth + timeColWidth + 7)));

    for (final note in notes) {
      final pin = note.isPinned ? CliFormatters.yellow('📌') : ' ';
      final id = CliFormatters.cyan(note.shortId.padRight(idColWidth));
      final title = CliFormatters.bold(CliFormatters.truncate(note.displayTitle, titleColWidth).padRight(titleColWidth));
      final tagsStr = note.tags.isNotEmpty
          ? CliFormatters.blue(CliFormatters.truncate('#${note.tags.join(' #')}', tagsColWidth).padRight(tagsColWidth))
          : ''.padRight(tagsColWidth);
      final relTime = CliFormatters.dim(CliFormatters.formatRelativeTime(note.updatedAt).padLeft(timeColWidth));

      stdout.writeln('$pin $id  $title  $tagsStr  $relTime');
    }

    stdout.writeln();
    final countLabel = notes.length == 1 ? '1 note' : '${notes.length} notes';
    stdout.writeln(CliFormatters.dim('$countLabel displayed.'));
    return 0;
  }
}
