import 'dart:io';
import 'package:args/command_runner.dart';
import 'cli_database.dart';
import 'cli_workspace.dart';
import 'commands/attach_command.dart';
import 'cli_formatters.dart';
import 'commands/delete_command.dart';
import 'commands/edit_command.dart';
import 'commands/list_command.dart';
import 'commands/new_command.dart';
import 'commands/show_command.dart';
import 'commands/tags_command.dart';

/// Top-level command runner for the Quiet Paper CLI (`qp`).
class CliRunner extends CommandRunner<int> {
  CliRunner({CliDatabase? database})
    : _providedDb = database,
      super(
        'qp',
        'Quiet Paper CLI — Distraction-free, offline-first notes in your terminal.',
      ) {
    argParser
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current CLI version',
      )
      ..addFlag(
        'no-color',
        negatable: false,
        help: 'Disable ANSI colors in terminal output',
      )
      ..addOption(
        'db',
        help: 'Path to custom quiet_paper.sqlite database file',
      );

    addCommand(AttachCommand(_getWorkspace));
    addCommand(AttachmentsCommand(_getWorkspace));
    addCommand(SyncCommand(_getWorkspace));
    addCommand(ListCommand(_getDb));
    addCommand(NewCommand(_getDb, workspace: _getWorkspace));
    addCommand(EditCommand(_getDb, workspace: _getWorkspace));
    addCommand(ShowCommand(_getDb));
    addCommand(TagsCommand(_getDb));
    addCommand(DeleteCommand(_getDb));
  }

  static const String currentVersion = '1.6.2';

  final CliDatabase? _providedDb;
  CliDatabase? _lazyDb;

  CliDatabase _getDb() {
    if (_providedDb != null) return _providedDb;
    if (_lazyDb == null) {
      final customDbPath = _activeDbPath;
      _lazyDb = CliDatabase.open(customDbPath);
    }
    return _lazyDb!;
  }

  String? _activeDbPath;
  CliWorkspace? _workspace;
  CliWorkspace _getWorkspace() => _workspace ??= CliWorkspace(_getDb());

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final argList = args.toList();
      _activeDbPath = null;

      // If invoked with no arguments, display help and usage menu
      if (argList.isEmpty) {
        printUsage();
        return 0;
      }

      // Check early global flags
      if (argList.contains('-v') || argList.contains('--version')) {
        stdout.writeln('Quiet Paper CLI (qp) version $currentVersion');
        return 0;
      }

      if (argList.contains('--no-color')) {
        CliFormatters.setNoColor(true);
      }

      // Inspect if a custom DB path is passed
      final dbIndex = argList.indexOf('--db');
      if (dbIndex != -1 && dbIndex + 1 < argList.length) {
        _activeDbPath = argList[dbIndex + 1];
      }

      for (final arg in argList) {
        if (arg.startsWith('--db=')) _activeDbPath = arg.substring(5);
      }
      final result = await super.run(args);
      return result ?? 0;
    } on UsageException catch (e) {
      stderr.writeln(CliFormatters.red(e.message));
      stderr.writeln();
      stderr.writeln(e.usage);
      return 64; // EX_USAGE
    } catch (e, stack) {
      stderr.writeln(CliFormatters.red('Error: $e'));
      if (Platform.environment.containsKey('QP_DEBUG')) {
        stderr.writeln(stack);
      }
      return 1;
    } finally {
      _workspace?.close();
      _workspace = null;
      _lazyDb?.close();
      _lazyDb = null;
    }
  }

  @override
  void printUsage() {
    stdout.writeln(
      CliFormatters.bold(
        'Quiet Paper CLI (qp) — Offline-first notes in your terminal',
      ),
    );
    stdout.writeln();
    stdout.writeln('Usage: qp <command> [arguments]');
    stdout.writeln();
    stdout.writeln(CliFormatters.bold('Available Commands:'));
    stdout.writeln(
      '  ${CliFormatters.cyan('list')}    (ls)       List notes with filters, search, and JSON export',
    );
    stdout.writeln(
      '  ${CliFormatters.cyan('new')}     (n, add)   Create a note with your editor (nvim/vim/nano) or stdin',
    );
    stdout.writeln(
      '  ${CliFormatters.cyan('edit')}    (e)        Modify an existing note using your external editor',
    );
    stdout.writeln(
      '  ${CliFormatters.cyan('show')}    (cat, s)   Print note markdown or metadata to stdout',
    );
    stdout.writeln(
      '  attach              Append files or a clipboard image to a note',
    );
    stdout.writeln(
      '  attachments         List images or open one in an external viewer',
    );
    stdout.writeln(
      '  sync                Retry uploading pending notes and images',
    );
    stdout.writeln(
      '  ${CliFormatters.cyan('tags')}    (t)        List all tags with note counts',
    );
    stdout.writeln(
      '  ${CliFormatters.cyan('delete')}  (rm, del)  Move note to trash or delete permanently',
    );
    stdout.writeln();
    stdout.writeln(CliFormatters.bold('Global Options:'));
    stdout.writeln('  -h, --help        Print this usage guide');
    stdout.writeln('  -v, --version     Print the CLI version');
    stdout.writeln('      --no-color    Disable ANSI color escape sequences');
    stdout.writeln('      --db <path>   Specify path to quiet_paper.sqlite');
    stdout.writeln();
    stdout.writeln(
      'Run "qp <command> --help" for detailed information on a specific command.',
    );
  }
}
