import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../attachments/attachment_crypto.dart';
import 'cli_credentials.dart';
import 'cli_database.dart';
import 'cli_image_paths.dart';

class CliAttachments {
  CliAttachments(this.db, this.credentials);
  final CliDatabase db;
  final CliCredentials credentials;
  static const maxBytes = 10 * 1024 * 1024;

  Directory get directory =>
      Directory(p.join(p.dirname(db.path), 'attachments'));

  void ensureSchema() {
    db.connection.execute('''CREATE TABLE IF NOT EXISTS attachments (
      id TEXT NOT NULL PRIMARY KEY, note_id TEXT, created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL, file_name TEXT NOT NULL DEFAULT 'attachment',
      kind TEXT NOT NULL DEFAULT 'image', mime_type TEXT NOT NULL DEFAULT 'image/png',
      byte_size INTEGER NOT NULL DEFAULT 0, width INTEGER, height INTEGER,
      sha256 TEXT NOT NULL DEFAULT '', encryption_key_version INTEGER NOT NULL DEFAULT 1,
      is_dirty INTEGER NOT NULL DEFAULT 1, is_deleted INTEGER NOT NULL DEFAULT 0,
      deleted_at INTEGER, server_revision INTEGER NOT NULL DEFAULT 0, synced_at INTEGER,
      upload_state TEXT NOT NULL DEFAULT 'local_only', cloud_public_id TEXT, cloud_url TEXT,
      local_path TEXT, ocr_state TEXT NOT NULL DEFAULT 'not_requested',
      ocr_language TEXT NOT NULL DEFAULT 'en'
    );''');
  }

  Future<CliNote> save({
    required String title,
    required String content,
    CliNote? existing,
    List<String>? tags,
    bool? pinned,
    List<String> files = const [],
    bool clipboard = false,
    bool compress = false,
    String? baseDir,
  }) async {
    final originalDraft = content;
    final staged = <Map<String, Object?>>[];
    final written = <File>[];
    final noteId = existing?.id ?? const Uuid().v4();
    final base = p.absolute(baseDir ?? Directory.current.path);
    final cache = <String, String>{};
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    try {
      Future<String> prepare(Uint8List bytes, String name) async {
        var mime = detectMime(bytes);
        if (mime == null) {
          throw FormatException(
            'Unsupported or invalid image: $name. Use PNG, JPEG, GIF, WebP or AVIF.',
          );
        }
        if (compress) {
          final decoded = img.decodeImage(bytes);
          if (decoded == null || decoded.numFrames > 1) {
            throw FormatException(
              'Cannot compress $name without losing animation or unsupported encoding. Attach the original instead.',
            );
          }
          final scaled = decoded.width > 2560 || decoded.height > 2560
              ? img.copyResize(
                  decoded,
                  width: decoded.width >= decoded.height ? 2560 : null,
                  height: decoded.height > decoded.width ? 2560 : null,
                )
              : decoded;
          bytes = Uint8List.fromList(
            img.encodeJpg(img.bakeOrientation(scaled), quality: 85),
          );
          mime = 'image/jpeg';
          name = '${p.basenameWithoutExtension(name)}.jpg';
        }
        if (bytes.length > maxBytes) {
          throw StateError(
            '$name exceeds 10 MB. Use --compress or resize it first.',
          );
        }
        final key = await credentials.masterKey();
        final id = const Uuid().v4();
        final encrypted = await AttachmentCrypto().encryptAttachment(
          plaintextBytes: bytes,
          masterKeyBytes: key,
          attachmentId: id,
        );
        await directory.create(recursive: true);
        final file = File(p.join(directory.path, '$id.enc'));
        written.add(file);
        await file.writeAsBytes(encrypted, flush: true);
        await Process.run('chmod', ['600', file.path]);
        staged.add({
          'id': id,
          'note_id': noteId,
          'created_at': now,
          'updated_at': now,
          'file_name': name,
          'mime_type': mime,
          'byte_size': bytes.length,
          'sha256': AttachmentCrypto.computeSha256(bytes),
          'local_path': file.path,
        });
        return 'qp://asset/$id';
      }

      Future<String> importFile(String target) async {
        final uri = Uri.tryParse(target);
        var path = uri?.scheme == 'file'
            ? uri!.toFilePath()
            : Uri.decodeComponent(target);
        if (path.startsWith('~/')) {
          path = p.join(Platform.environment['HOME'] ?? '', path.substring(2));
        }
        path = p.normalize(p.isAbsolute(path) ? path : p.join(base, path));
        if (cache.containsKey(path)) return cache[path]!;
        final file = File(path);
        if (!await file.exists()) {
          throw FileSystemException('Image not found', path);
        }
        final length = await file.length();
        if (length > maxBytes && !compress) {
          throw StateError(
            '$path exceeds 10 MB. Use --compress or resize it first.',
          );
        }
        if (length > 100 * 1024 * 1024) {
          throw StateError(
            '$path exceeds the 100 MB compression input limit. Resize it first.',
          );
        }
        return cache[path] = await prepare(
          await file.readAsBytes(),
          p.basename(path),
        );
      }

      final replacements = <(CliImagePath, String)>[];
      for (final reference in CliImagePath.find(content)) {
        replacements.add((reference, await importFile(reference.target)));
      }
      for (final (reference, uri) in replacements.reversed) {
        content = content.replaceRange(reference.start, reference.end, uri);
      }
      for (final path in files) {
        final uri = await importFile(path);
        final alt = p
            .basenameWithoutExtension(path)
            .replaceAll(RegExp(r'[\[\]\\\r\n]'), '');
        content = '${content.trimRight()}\n\n![$alt]($uri)\n';
      }
      if (clipboard) {
        final (bytes, name) = await readClipboard();
        final uri = await prepare(bytes, name);
        content = '${content.trimRight()}\n\n![Screenshot]($uri)\n';
      }
      if (staged.isNotEmpty) ensureSchema();
      return db.transaction<CliNote>(() {
        if (existing != null) {
          final current = db.getNoteByIdOrPrefix(existing.id);
          if (current == null ||
              current.content != existing.content ||
              current.title != existing.title ||
              current.isPinned != existing.isPinned ||
              current.isTrashed != existing.isTrashed ||
              current.isArchived != existing.isArchived) {
            throw StateError(
              'The note changed while you were editing. Your draft will be preserved.',
            );
          }
        }
        final note = existing == null
            ? db.createNote(
                noteId: noteId,
                title: title,
                content: content,
                tags: tags,
                isPinned: pinned ?? false,
              )
            : db.updateNote(
                id: noteId,
                title: title,
                content: content,
                tags: tags,
                isPinned: pinned,
              );
        for (final row in staged) {
          db.connection.execute(
            '''INSERT INTO attachments
            (id,note_id,created_at,updated_at,file_name,mime_type,byte_size,sha256,local_path,
             kind,is_dirty,upload_state,ocr_state,ocr_language)
            VALUES (?,?,?,?,?,?,?,?,?,'image',1,'upload_pending','queued','en')''',
            row.values.toList(),
          );
        }
        return note;
      });
    } catch (error) {
      for (final file in written) {
        if (await file.exists()) await file.delete();
      }
      final recovery = await preserveDraft(originalDraft);
      throw StateError('$error\nDraft preserved at ${recovery.path}');
    }
  }

  Future<File> preserveDraft(String content) async {
    final root = Directory(p.join(p.dirname(db.path), 'cli-drafts'));
    await root.create(recursive: true);
    await Process.run('chmod', ['700', root.path]);
    final file = File(p.join(root.path, '${const Uuid().v4()}.md'));
    await file.writeAsString(content, flush: true);
    await Process.run('chmod', ['600', file.path]);
    return file;
  }

  List<Map<String, Object?>> list(CliNote note) {
    ensureSchema();
    final ids = RegExp(
      r'qp://asset/([0-9a-fA-F-]{36})',
    ).allMatches(note.content).map((m) => m[1]!).toSet();
    if (ids.isEmpty) return [];
    return db.connection
        .select(
          'SELECT * FROM attachments WHERE is_deleted=0 AND id IN (${List.filled(ids.length, '?').join(',')})',
          ids.toList(),
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  Future<void> open(CliNote note, String prefix) async {
    final matches = list(
      note,
    ).where((a) => (a['id'] as String).startsWith(prefix)).toList();
    if (matches.length != 1) {
      throw StateError('Specify a unique attachment ID from qp attachments.');
    }
    final attachment = matches.single;
    final path = attachment['local_path'] as String?;
    if (path == null || !await File(path).exists()) {
      throw StateError(
        'Image is not downloaded locally. Open it in the desktop app to download it first.',
      );
    }
    final bytes = await AttachmentCrypto().decryptAttachment(
      encryptedEnvelopeBytes: await File(path).readAsBytes(),
      masterKeyBytes: await credentials.masterKey(),
      attachmentId: attachment['id'] as String,
    );
    final temp = await Directory.systemTemp.createTemp('qp-view-');
    try {
      await Process.run('chmod', ['700', temp.path]);
      final file = File(
        p.join(temp.path, p.basename(attachment['file_name'] as String)),
      );
      await file.writeAsBytes(bytes, flush: true);
      final process = await Process.start('xdg-open', [
        file.path,
      ], mode: ProcessStartMode.inheritStdio);
      if (await process.exitCode != 0) {
        throw StateError('Could not launch an image viewer.');
      }
      stdout.writeln(
        'Press Enter after closing the viewer to remove its temporary image.',
      );
      stdin.readLineSync();
    } finally {
      await temp.delete(recursive: true);
    }
  }

  static String? detectMime(Uint8List b) {
    bool starts(List<int> signature) =>
        b.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => b[i] == signature[i],
        ).every((v) => v);
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
    if (starts([255, 216, 255])) return 'image/jpeg';
    if (b.length >= 6 &&
        [
          'GIF87a',
          'GIF89a',
        ].contains(ascii.decode(b.sublist(0, 6), allowInvalid: true))) {
      return 'image/gif';
    }
    if (b.length >= 12 &&
        ascii.decode(b.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(b.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    if (b.length >= 16 &&
        ascii.decode(b.sublist(4, 8), allowInvalid: true) == 'ftyp' &&
        [
          'avif',
          'avis',
        ].contains(ascii.decode(b.sublist(8, 12), allowInvalid: true))) {
      return 'image/avif';
    }
    return null;
  }

  static Future<(Uint8List, String)> readClipboard() async {
    final wayland =
        Platform.environment['WAYLAND_DISPLAY']?.isNotEmpty ?? false;
    final command = wayland ? 'wl-paste' : 'xclip';
    for (final mime in ['image/png', 'image/jpeg']) {
      try {
        final process = await Process.start(
          command,
          wayland
              ? ['--no-newline', '--type', mime]
              : ['-selection', 'clipboard', '-target', mime, '-out'],
        );
        final output = process.stdout.fold<BytesBuilder>(BytesBuilder(), (
          builder,
          chunk,
        ) {
          if (builder.length + chunk.length > maxBytes) {
            process.kill();
            throw StateError(
              'Clipboard image exceeds 10 MB. Save it to a file and use --compress.',
            );
          }
          return builder..add(chunk);
        });
        final errors = process.stderr.drain<void>();
        final bytes = await output.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill();
            throw StateError('Clipboard read timed out.');
          },
        );
        final code = await process.exitCode;
        await errors;
        if (code == 0 && bytes.length > 0) {
          return (
            bytes.takeBytes(),
            mime == 'image/png' ? 'clipboard.png' : 'clipboard.jpg',
          );
        }
      } on ProcessException catch (_) {
        throw StateError(
          'Install ${wayland ? 'wl-clipboard' : 'xclip'} to attach clipboard images.',
        );
      }
    }
    throw StateError('No PNG or JPEG image on the clipboard of this machine.');
  }
}
