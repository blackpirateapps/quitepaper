import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/core/cli/cli_args_provider.dart';
import 'package:quitepaper/core/storage/app_storage_path_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppStoragePathResolver', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quitepaper_test_storage_');
      AppStoragePathResolver.resetMigrationState();
    });

    tearDown(() async {
      AppStoragePathResolver.resetMigrationState();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('customDataDirectory override is respected', () async {
      final customDir = Directory(p.join(tempDir.path, 'custom_vault'));
      AppStoragePathResolver.customDataDirectory = customDir;

      final resolved = await AppStoragePathResolver.getDataDirectory();
      expect(resolved.path, equals(customDir.path));
      expect(await customDir.exists(), isTrue);
    });

    test('migrateDirectories moves sqlite files and subdirectories with zero data loss', () async {
      final sourceDir = Directory(p.join(tempDir.path, 'legacy_docs'));
      final targetDir = Directory(p.join(tempDir.path, 'xdg_share'));
      await sourceDir.create(recursive: true);

      // Create dummy sqlite, wal, and attachment files
      final dbFile = File(p.join(sourceDir.path, 'quiet_paper.sqlite'));
      await dbFile.writeAsString('sqlite-magic-header');

      final walFile = File(p.join(sourceDir.path, 'quiet_paper.sqlite-wal'));
      await walFile.writeAsString('wal-data');

      final attachmentsDir = Directory(p.join(sourceDir.path, 'attachments'));
      await attachmentsDir.create(recursive: true);
      final attFile = File(p.join(attachmentsDir.path, 'att1.bin'));
      await attFile.writeAsString('encrypted-attachment');

      final documentsDir = Directory(p.join(sourceDir.path, 'documents'));
      await documentsDir.create(recursive: true);
      final docFile = File(p.join(documentsDir.path, 'doc1.pdf'));
      await docFile.writeAsString('encrypted-pdf');

      // Execute migration
      await AppStoragePathResolver.migrateDirectories(
        sourceDir: sourceDir,
        targetDir: targetDir,
      );

      // Verify files in target directory
      final targetDb = File(p.join(targetDir.path, 'quiet_paper.sqlite'));
      expect(await targetDb.exists(), isTrue);
      expect(await targetDb.readAsString(), equals('sqlite-magic-header'));

      final targetWal = File(p.join(targetDir.path, 'quiet_paper.sqlite-wal'));
      expect(await targetWal.exists(), isTrue);
      expect(await targetWal.readAsString(), equals('wal-data'));

      final targetAtt = File(p.join(targetDir.path, 'attachments', 'att1.bin'));
      expect(await targetAtt.exists(), isTrue);
      expect(await targetAtt.readAsString(), equals('encrypted-attachment'));

      final targetDoc = File(p.join(targetDir.path, 'documents', 'doc1.pdf'));
      expect(await targetDoc.exists(), isTrue);
      expect(await targetDoc.readAsString(), equals('encrypted-pdf'));
    });

    test('CliArgsHelper detects flags and files accurately', () {
      expect(CliArgsHelper.hasFlag(['--new-note'], 'new-note'), isTrue);
      expect(CliArgsHelper.hasFlag(['-n'], 'new-note'), isTrue);
      expect(CliArgsHelper.hasFlag(['--other'], 'new-note'), isFalse);

      expect(CliArgsHelper.findMarkdownFile(['--new-note', '/path/to/my_note.md']), equals('/path/to/my_note.md'));
      expect(CliArgsHelper.findMarkdownFile(['file.txt']), equals('file.txt'));
      expect(CliArgsHelper.findMarkdownFile(['--flag', 'other.png']), isNull);
    });
  });
}
