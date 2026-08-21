import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/features/import/application/image_reference_matcher.dart';
import 'package:quitepaper/features/import/domain/import_image_reference.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';

void main() {
  group('ImageReferenceMatcher Tests', () {
    late Directory tempDir;
    late File fileA;
    late File fileB;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qp_matcher_test_');
      fileA = File(p.join(tempDir.path, 'cat.png'))..writeAsBytesSync([1, 2, 3]);
      fileB = File(p.join(tempDir.path, 'architecture_diagram.jpg'))
        ..writeAsBytesSync([4, 5, 6, 7]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('matches exact basename case-insensitively', () {
      final ref = ImportImageReference(
        originalSyntax: '![Cat](images/cat.png)',
        rawTarget: 'images/cat.png',
        altText: 'Cat',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note',
        content: '![Cat](images/cat.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref],
      );

      final picked = [
        PlatformFile(
          name: 'CAT.PNG',
          path: fileA.path,
          size: 3,
        ),
      ];

      final matched = ImageReferenceMatcher.matchMissingImages(
        items: [item],
        pickedFiles: picked,
      );

      expect(matched, equals(1));
      expect(ref.isFound, isTrue);
      expect(ref.resolvedFilePath, equals(fileA.path));
      expect(ref.fileSizeBytes, equals(3));
    });

    test('matches delimiter-tolerant filenames (hyphen vs underscore)', () {
      final ref = ImportImageReference(
        originalSyntax: '![Arch](architecture-diagram.jpg)',
        rawTarget: 'architecture-diagram.jpg',
        altText: 'Arch',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note',
        content: '![Arch](architecture-diagram.jpg)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref],
      );

      final picked = [
        PlatformFile(
          name: 'architecture_diagram.jpg',
          path: fileB.path,
          size: 4,
        ),
      ];

      final matched = ImageReferenceMatcher.matchMissingImages(
        items: [item],
        pickedFiles: picked,
      );

      expect(matched, equals(1));
      expect(ref.isFound, isTrue);
      expect(ref.resolvedFilePath, equals(fileB.path));
    });

    test('matches in-memory picked bytes without filesystem path', () {
      final ref = ImportImageReference(
        originalSyntax: '![Memory](logo.png)',
        rawTarget: 'logo.png',
        altText: 'Memory',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note',
        content: '![Memory](logo.png)',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref],
      );

      final bytes = Uint8List.fromList([10, 20, 30]);
      final picked = [
        PlatformFile(
          name: 'logo.png',
          size: 3,
          bytes: bytes,
        ),
      ];

      final matched = ImageReferenceMatcher.matchMissingImages(
        items: [item],
        pickedFiles: picked,
      );

      expect(matched, equals(1));
      expect(ref.isFound, isTrue);
      expect(ref.pickedBytes, equals(bytes));
    });

    test('relinks single image directly', () {
      final ref = ImportImageReference(
        originalSyntax: '![Target](custom_name.png)',
        rawTarget: 'custom_name.png',
        altText: 'Target',
        status: ImportImageStatus.missing,
      );

      final pf = PlatformFile(
        name: 'different_name.png',
        path: fileA.path,
        size: 3,
      );

      final success = ImageReferenceMatcher.relinkSingleImage(
        ref: ref,
        pickedFile: pf,
      );

      expect(success, isTrue);
      expect(ref.isFound, isTrue);
      expect(ref.resolvedFilePath, equals(fileA.path));
    });
  });
}
