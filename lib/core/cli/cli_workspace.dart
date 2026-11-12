import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'cli_attachments.dart';
import 'cli_credentials.dart';
import 'cli_database.dart';
import 'cli_sync.dart';
import 'interactive_picker.dart';

class CliWorkspace {
  CliWorkspace(this.db, {CliCredentials? credentials})
    : credentials =
          credentials ??
          CliCredentials(
            Directory(p.dirname(db.path)),
            useKeyring:
                db.path.isNotEmpty &&
                p.equals(
                  p.absolute(db.path),
                  p.absolute(CliDatabase.resolveDefaultDbPath()),
                ),
          );
  final CliDatabase db;
  final CliCredentials credentials;
  CliAttachments get attachments => CliAttachments(db, credentials);

  static void addImportOptions(ArgParser parser, {bool allowFiles = true}) {
    if (allowFiles) {
      parser.addMultiOption(
        'attach',
        splitCommas: false,
        help: 'Image file to append (repeatable)',
      );
    }
    parser
      ..addFlag(
        'clipboard',
        negatable: false,
        help: 'Append an image from this machine’s clipboard',
      )
      ..addFlag(
        'compress',
        negatable: false,
        help:
            'Convert imported still images to JPEG, quality 85, maximum 2560 pixels',
      )
      ..addOption(
        'base-dir',
        help: 'Resolve relative image paths from this directory',
      );
  }

  Future<CliNote?> resolve(String query) async {
    final rows = db.connection.select(
      'SELECT id FROM notes WHERE lower(id) LIKE ?',
      ['${query.toLowerCase()}%'],
    );
    if (rows.length == 1) {
      return db.getNoteByIdOrPrefix(rows.single['id'] as String);
    }
    final notes = rows.length > 1
        ? rows.map((r) => db.getNoteByIdOrPrefix(r['id'] as String)!).toList()
        : db.findNotesByTitle(query);
    if (notes.isEmpty) throw StateError('No note matches "$query".');
    if (notes.length == 1) return notes.single;
    if (!stdin.hasTerminal) {
      throw StateError('Ambiguous note. Specify its full ID.');
    }
    return const InteractivePicker().pickNote(notes);
  }

  Future<bool> sync(String id, {bool explicit = false}) async {
    if (db.path.isEmpty) return false;
    final sync = CliSync(db, credentials);
    try {
      // Avoid asking for an encryption password if no account is configured.
      if (!(await credentials.read()).containsKey(
        'quietpaper_auth_session_v1',
      )) {
        stderr.writeln(
          'Saved locally. Sign in to the desktop app to enable CLI sync.',
        );
        return false;
      }
      await sync.syncNote(id);
      stderr.writeln('Synced note and attachments.');
      return true;
    } catch (e) {
      stderr.writeln('Saved locally; sync pending: $e');
      return false;
    } finally {
      sync.close();
    }
  }

  void close() => credentials.clear();
}
