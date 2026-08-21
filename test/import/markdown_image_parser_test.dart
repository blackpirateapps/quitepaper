import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/features/import/application/markdown_image_parser.dart';
import 'package:quitepaper/features/import/domain/import_image_reference.dart';

void main() {
  group('MarkdownImageParser Tests', () {
    late Directory tempDir;
    late Directory subDir;
    late Directory assetsDir;
    late File sampleImage;
    late File subImage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qp_image_parser_test_');
      subDir = Directory(p.join(tempDir.path, 'notes'))..createSync();
      assetsDir = Directory(p.join(tempDir.path, 'assets'))..createSync();

      sampleImage = File(p.join(tempDir.path, 'sample.png'))
        ..writeAsBytesSync([1, 2, 3, 4]);
      subImage = File(p.join(assetsDir.path, 'diagram.jpg'))
        ..writeAsBytesSync([5, 6, 7, 8]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('extracts standard markdown image and resolves relative path', () {
      final mdPath = p.join(tempDir.path, 'test.md');
      const content = '# Note\n\n![Sample Image](sample.png)\nSome text.';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images.length, equals(1));
      final img = images.first;
      expect(img.altText, equals('Sample Image'));
      expect(img.rawTarget, equals('sample.png'));
      expect(img.status, equals(ImportImageStatus.resolved));
      expect(img.resolvedFilePath, equals(sampleImage.path));
      expect(img.isFound, isTrue);
      expect(img.fileSizeBytes, equals(4));
    });

    test('extracts angle bracketed path with spaces and decodes target', () {
      final spaceImage = File(p.join(tempDir.path, 'my vacation photo.png'))
        ..writeAsBytesSync([1, 2, 3]);

      final mdPath = p.join(tempDir.path, 'test.md');
      const content = '![Vacation](<my vacation photo.png>)';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images.length, equals(1));
      expect(images.first.isFound, isTrue);
      expect(images.first.resolvedFilePath, equals(spaceImage.path));
    });

    test('extracts Obsidian wikilink image embed', () {
      final mdPath = p.join(subDir.path, 'subnote.md');
      const content = 'Check this out:\n![[diagram.jpg|Architecture]]';

      final vaultMap = {'diagram.jpg': subImage.path};

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
        vaultImagesMap: vaultMap,
      );

      expect(images.length, equals(1));
      final img = images.first;
      expect(img.altText, equals('Architecture'));
      expect(img.isFound, isTrue);
      expect(img.resolvedFilePath, equals(subImage.path));
    });

    test('resolves image from common assets subdirectory', () {
      final mdPath = p.join(tempDir.path, 'root_note.md');
      const content = '![Diagram](diagram.jpg)';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images.length, equals(1));
      expect(images.first.isFound, isTrue);
      expect(images.first.resolvedFilePath, equals(subImage.path));
    });

    test('marks missing image when file does not exist on disk', () {
      final mdPath = p.join(tempDir.path, 'test.md');
      const content = '![Ghost](nonexistent_folder/ghost.png)';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images.length, equals(1));
      expect(images.first.isFound, isFalse);
      expect(images.first.status, equals(ImportImageStatus.missing));
      expect(images.first.displayName, equals('ghost.png'));
    });

    test('ignores web images and images inside code blocks', () {
      final mdPath = p.join(tempDir.path, 'test.md');
      const content = '''
# Web & Code Note
![Online Logo](https://example.com/logo.png)
![Data URI](data:image/png;base64,iVBORw0KGgo=)

```markdown
![Code Sample](sample.png)
```
''';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images, isEmpty);
    });

    test('ignores non-image Obsidian wikilinks', () {
      final mdPath = p.join(tempDir.path, 'test.md');
      const content = '![[Another Note Title]]';

      final images = MarkdownImageParser.extractAndResolveImages(
        markdownContent: content,
        filePath: mdPath,
        rootFolderPath: tempDir.path,
      );

      expect(images, isEmpty);
    });
  });
}
