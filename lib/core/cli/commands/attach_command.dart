import 'dart:convert';
import 'dart:io';
import 'package:args/command_runner.dart';
import '../cli_workspace.dart';

class AttachCommand extends Command<int> {
  AttachCommand(this.workspace) {
    CliWorkspace.addImportOptions(argParser, allowFiles: false);
  }
  final CliWorkspace Function() workspace;
  @override
  String get name => 'attach';
  @override
  String get description =>
      'Append images: qp attach <note> <files...> or --clipboard.';
  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.isEmpty || (args.rest.length < 2 && !args['clipboard'])) {
      usageException('Specify a note and image files, or --clipboard.');
    }
    final work = workspace();
    final note = await work.resolve(args.rest.first);
    if (note == null) return 0;
    final saved = await work.attachments.save(
      title: note.title,
      content: note.content,
      existing: note,
      tags: note.tags,
      files: args.rest.skip(1).toList(),
      clipboard: args['clipboard'],
      compress: args['compress'],
      baseDir: args['base-dir'],
    );
    stdout.writeln('Saved images to ${saved.displayTitle} [${saved.shortId}]');
    await work.sync(saved.id);
    return 0;
  }
}

class AttachmentsCommand extends Command<int> {
  AttachmentsCommand(this.workspace) {
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Print attachment metadata as JSON',
    );
  }
  final CliWorkspace Function() workspace;
  @override
  String get name => 'attachments';
  @override
  String get description =>
      'List images: qp attachments <note>; open: qp attachments <note> open <image-id>.';
  @override
  Future<int> run() async {
    final args = argResults!;
    if (args.rest.length != 1 &&
        !(args.rest.length == 3 && args.rest[1] == 'open')) {
      usageException('Specify a note, optionally followed by open <image-id>.');
    }
    if (args.rest.length == 3 && !stdin.hasTerminal) {
      usageException(
        'Opening images requires an interactive terminal for temporary-file cleanup.',
      );
    }
    final work = workspace();
    final note = await work.resolve(args.rest.first);
    if (note == null) return 0;
    if (args.rest.length == 3) {
      await work.attachments.open(note, args.rest[2]);
    } else {
      final rows = work.attachments.list(note);
      if (args['json']) {
        stdout.writeln(jsonEncode(rows));
      } else {
        for (final row in rows) {
          stdout.writeln(
            '${row['id']}  ${row['file_name']}  ${row['byte_size']} bytes  ${row['upload_state']}',
          );
        }
        if (rows.isEmpty) stdout.writeln('No attached images.');
      }
    }
    return 0;
  }
}

class SyncCommand extends Command<int> {
  SyncCommand(this.workspace);
  final CliWorkspace Function() workspace;
  @override
  String get name => 'sync';
  @override
  String get description =>
      'Retry uploading pending local notes and their images (remote conflicts require the desktop app).';
  @override
  Future<int> run() async {
    final work = workspace();
    final ids = <String>[];
    if (argResults!.rest.isNotEmpty) {
      final note = await work.resolve(argResults!.rest.join(' '));
      if (note != null) ids.add(note.id);
    } else {
      ids.addAll(
        work.db.connection
            .select('SELECT id FROM notes WHERE is_dirty=1')
            .map((r) => r['id'] as String),
      );
    }
    var success = true;
    for (final id in ids) {
      if (!await work.sync(id, explicit: true)) success = false;
    }
    if (ids.isEmpty) stdout.writeln('No pending notes.');
    return success ? 0 : 1;
  }
}
