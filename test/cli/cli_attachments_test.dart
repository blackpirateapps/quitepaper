import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:args/command_runner.dart';
import 'package:quitepaper/core/cli/cli_workspace.dart';
import 'package:quitepaper/core/cli/commands/attach_command.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/cli/cli_attachments.dart';
import 'package:quitepaper/core/cli/cli_credentials.dart';
import 'package:quitepaper/core/cli/cli_database.dart';
import 'package:quitepaper/core/cli/cli_image_paths.dart';

class TestCredentials extends CliCredentials {
  TestCredentials(super.directory) : super(useKeyring: false);
  final key = Uint8List.fromList(List.generate(32, (i) => i));
  @override
  Future<Uint8List> masterKey() async => key;
  @override
  Future<Map<String, String>> read() async => {
    'quietpaper_auth_session_v1': jsonEncode({
      'id': 'test-user',
      'idToken': 'test-token',
      'refreshToken': 'test-refresh',
      'tokenExpiresAt': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    }),
  };
}

class OfflineWorkspace extends CliWorkspace {
  OfflineWorkspace(super.db, {required super.credentials});
  @override
  Future<bool> sync(String id, {bool explicit = false}) async => false;
}

void main() {
  late Directory root;
  late CliDatabase db;
  late TestCredentials credentials;
  late CliAttachments service;
  late File photo;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('qp-attachments-test-');
    db = CliDatabase.open('${root.path}/quiet_paper.sqlite');
    credentials = TestCredentials(root);
    service = CliAttachments(db, credentials);
    photo = File('${root.path}/sample.png');
    await photo.writeAsBytes(img.encodePng(img.Image(width: 4, height: 3)));
  });
  tearDown(() async {
    db.close();
    await root.delete(recursive: true);
  });

  test(
    'imports paths once, preserves placement and encrypts in desktop format',
    () async {
      final note = await service.save(
        title: 'Images',
        content: '# Images\n![a](sample.png)\n![b](sample.png)',
        baseDir: root.path,
      );
      expect(note.content, contains('![a](qp://asset/'));
      final rows = service.list(note);
      expect(rows, hasLength(1));
      expect(rows.single['ocr_state'], 'queued');
      expect(rows.single['upload_state'], 'upload_pending');
      final plaintext = await AttachmentCrypto().decryptAttachment(
        encryptedEnvelopeBytes: await File(
          rows.single['local_path'] as String,
        ).readAsBytes(),
        masterKeyBytes: credentials.key,
        attachmentId: rows.single['id'] as String,
      );
      expect(plaintext, await photo.readAsBytes());
      expect(
        db.connection
            .select('SELECT content FROM note_versions')
            .single['content'],
        note.content,
      );
      expect(db.connection.select('SELECT * FROM sync_queue'), hasLength(1));
    },
  );

  test(
    'missing second image leaves saved note, history and attachment files unchanged',
    () async {
      final before = db.createNote(title: 'Before', content: 'original');
      const draft = '![a](sample.png)\n![missing](missing.png)';
      await expectLater(
        service.save(
          title: 'After',
          content: draft,
          existing: before,
          baseDir: root.path,
        ),
        throwsStateError,
      );
      expect(db.getNoteByIdOrPrefix(before.id)!.content, 'original');
      expect(db.connection.select('SELECT * FROM note_versions'), hasLength(1));
      expect(await service.directory.list().toList(), isEmpty);
      final recovered = await Directory(
        '${root.path}/cli-drafts',
      ).list().single;
      expect(await File(recovered.path).readAsString(), draft);
    },
  );

  test(
    'database failure rolls back attachment records, note and history',
    () async {
      service.ensureSchema();
      db.connection.execute(
        "CREATE TRIGGER reject_image BEFORE INSERT ON attachments BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
      );
      await expectLater(
        service.save(
          title: 'Fail',
          content: '![a](sample.png)',
          baseDir: root.path,
        ),
        throwsStateError,
      );
      expect(db.listNotes(), isEmpty);
      expect(db.connection.select('SELECT * FROM attachments'), isEmpty);
      expect(db.connection.select('SELECT * FROM note_versions'), isEmpty);
      expect(db.connection.select('SELECT * FROM sync_queue'), isEmpty);
      expect(await service.directory.list().toList(), isEmpty);
    },
  );

  test('attach command preserves explicit tags and existing text', () async {
    final old = db.createNote(
      title: 'Tagged',
      content: 'body',
      tags: ['manual'],
    );
    final workspace = OfflineWorkspace(db, credentials: credentials);
    final runner = CommandRunner<int>('qp', 'test')
      ..addCommand(AttachCommand(() => workspace));
    expect(await runner.run(['attach', old.id, photo.path]), 0);
    final updated = db.getNoteByIdOrPrefix(old.id)!;
    expect(updated.tags, contains('manual'));
    expect(updated.content, startsWith('body\n\n!['));
    expect(service.list(updated), hasLength(1));
  });

  test('concurrent edit is preserved with recovery draft', () async {
    final old = db.createNote(title: 'Old', content: 'original');
    db.updateNote(id: old.id, title: 'New', content: 'GUI change');
    await expectLater(
      service.save(title: 'Old', content: 'CLI change', existing: old),
      throwsStateError,
    );
    expect(db.getNoteByIdOrPrefix(old.id)!.content, 'GUI change');
  });

  test(
    'explicit compression produces JPEG while default retains original PNG',
    () async {
      final note = await service.save(
        title: 'Compressed',
        content: '',
        files: [photo.path],
        compress: true,
      );
      final row = service.list(note).single;
      expect(row['mime_type'], 'image/jpeg');
      expect(row['file_name'], 'sample.jpg');
      final decoded = await AttachmentCrypto().decryptAttachment(
        encryptedEnvelopeBytes: await File(
          row['local_path'] as String,
        ).readAsBytes(),
        masterKeyBytes: credentials.key,
        attachmentId: row['id'] as String,
      );
      expect(img.decodeJpg(decoded), isNotNull);
    },
  );

  test(
    'image scanner ignores code, frontmatter, escaped syntax and remote URLs',
    () {
      final text =
          '---\ntitle: "![x](front.png)"\n---\n'
          '```md\n![x](code.png)\n```\n'
          '`![x](inline.png)`\n\\![x](escaped.png)\n'
          '![remote](https://example.org/a.png)\n![asset](qp://asset/id)\n'
          '![real](<photo with spaces.png> "caption")\n![other](photo(1).png)';
      expect(CliImagePath.find(text).map((r) => r.target), [
        'photo with spaces.png',
        'photo(1).png',
      ]);
    },
  );

  test('imports into a desktop-created schema readable by Drift', () async {
    final desktopPath = '${root.path}/desktop.sqlite';
    final desktop = AppDatabase(NativeDatabase(File(desktopPath)));
    await desktop.customSelect('SELECT COUNT(*) FROM notes').get();
    await desktop.close();
    final cli = CliDatabase.open(desktopPath);
    String? attachmentId;
    try {
      final importer = CliAttachments(cli, credentials);
      final note = await importer.save(
        title: 'Desktop-compatible',
        content: '',
        files: [photo.path],
      );
      attachmentId = importer.list(note).single['id'] as String;
    } finally {
      cli.close();
    }
    final reopened = AppDatabase(NativeDatabase(File(desktopPath)));
    try {
      final attachment = await reopened.getAttachment(attachmentId);
      expect(attachment, isNotNull);
      expect(attachment!.uploadState, 'upload_pending');
      expect(attachment.ocrState, 'queued');
      expect(attachment.fileName, 'sample.png');
    } finally {
      await reopened.close();
    }
  });

  test('image reference definitions import only image targets', () {
    const text =
        '![photo][image]\n[normal][link]\n\n[image]: sample.png\n[link]: page.md';
    expect(CliImagePath.find(text).map((r) => r.target), ['sample.png']);
  });
}
