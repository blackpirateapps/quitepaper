import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/import/application/markdown_import_scanner.dart';

void main() {
  group('MarkdownImportScanner', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('quitepaper_test_import_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('recursively scans directory, finds .md and .markdown, extracts subfolder tags and frontmatter', () async {
      // 1. Root level markdown without frontmatter
      final rootFile = File('${tempDir.path}/Root Note.md');
      await rootFile.writeAsString('# Heading in root\n\nContent with #root-tag');

      // 2. Nested markdown with frontmatter inside Articles/Wikipedia/
      final wikiDir = Directory('${tempDir.path}/Articles/Wikipedia');
      await wikiDir.create(recursive: true);
      final wikiFile = File('${wikiDir.path}/Deep Learning.md');
      await wikiFile.writeAsString('''---
title: "Custom Frontmatter Title"
tags: [ai, ml]
---
# Body
Some content with #deep-learning
''');

      // 3. Deeply nested .markdown file
      final deepDir = Directory('${tempDir.path}/Notes/2024/Projects/Alpha');
      await deepDir.create(recursive: true);
      final deepFile = File('${deepDir.path}/Roadmap.markdown');
      await deepFile.writeAsString('Roadmap details');

      // 4. Non-markdown files (should be ignored)
      final txtFile = File('${tempDir.path}/ignore_me.txt');
      await txtFile.writeAsString('text');
      final pngFile = File('${tempDir.path}/image.png');
      await pngFile.writeAsString('image');

      final items = await MarkdownImportScanner.scanFolder(tempDir.path);

      expect(items.length, equals(3));

      // Check root note
      final rootItem = items.firstWhere((i) => i.relativePath == 'Root Note.md');
      expect(rootItem.title, equals('Root Note'));
      expect(rootItem.tags, contains('root-tag'));
      expect(rootItem.fileSizeBytes, greaterThan(0));
      expect(rootItem.isSelected, isTrue);

      // Check nested wiki note
      final wikiItem = items.firstWhere((i) => i.relativePath.contains('Articles'));
      expect(wikiItem.title, equals('Custom Frontmatter Title'));
      // Subfolder tags: 'articles', 'wikipedia'; frontmatter tags: 'ai', 'ml'; in-body: 'deep-learning'
      expect(
        wikiItem.tags,
        containsAll(['articles', 'wikipedia', 'ai', 'ml', 'deep-learning']),
      );

      // Check deeply nested note
      final deepItem = items.firstWhere((i) => i.relativePath.contains('Alpha'));
      expect(deepItem.title, equals('Roadmap'));
      expect(
        deepItem.tags,
        containsAll(['notes', 'projects', 'alpha']),
      );
    });

    test('preserves file properties for dates when frontmatter dates are not present', () async {
      final file = File('${tempDir.path}/dated_note.md');
      await file.writeAsString('Some content');

      final stat = await file.stat();
      final item = await MarkdownImportScanner.processFile(file, tempDir.path);

      expect(item, isNotNull);
      expect(item!.updatedAt.millisecondsSinceEpoch, equals(stat.modified.millisecondsSinceEpoch));
    });
  });
}
