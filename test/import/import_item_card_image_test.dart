import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/import/domain/import_image_reference.dart';
import 'package:quitepaper/features/import/domain/markdown_import_item.dart';
import 'package:quitepaper/features/import/presentation/widgets/import_item_card.dart';

void main() {
  group('ImportItemCard Image Attachments & Expandable Tray Tests', () {
    late Directory tempDir;
    late File img1;
    late File img2;
    late File img3;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('qp_card_test_');
      img1 = File(p.join(tempDir.path, 'img1.png'))..writeAsBytesSync([1, 2]);
      img2 = File(p.join(tempDir.path, 'img2.jpg'))..writeAsBytesSync([3, 4]);
      img3 = File(p.join(tempDir.path, 'img3.webp'))..writeAsBytesSync([5, 6]);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Widget buildTestWidget({
      required MarkdownImportItem item,
      ValueChanged<ImportImageReference>? onRelinkImage,
    }) {
      return MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ImportItemCard(
              item: item,
              onToggleSelect: (_) {},
              onAddTag: (_) {},
              onRemoveTag: (_) {},
              onEditTitle: (_) {},
              onRelinkImage: onRelinkImage,
            ),
          ),
        ),
      );
    }

    testWidgets('renders inline attachments when note has 2 or fewer images', (tester) async {
      final ref1 = ImportImageReference(
        originalSyntax: '![One](img1.png)',
        rawTarget: 'img1.png',
        altText: 'One',
        resolvedFilePath: img1.path,
        fileSizeBytes: 2,
        status: ImportImageStatus.resolved,
      );

      final ref2 = ImportImageReference(
        originalSyntax: '![Missing](ghost.png)',
        rawTarget: 'ghost.png',
        altText: 'Missing',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note with 2 Images',
        content: 'Content',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref1, ref2],
      );

      await tester.pumpWidget(buildTestWidget(item: item));
      await tester.pumpAndSettle();

      expect(find.text('ATTACHMENTS (2)'), findsOneWidget);
      expect(find.text('1 missing'), findsOneWidget);
      expect(find.text('img1.png'), findsOneWidget);
      expect(find.text('ghost.png'), findsOneWidget);
      expect(find.text('Relink'), findsOneWidget);

      // Should not show expandable toggle button because <= 2 images
      expect(find.textContaining('Show all'), findsNothing);
    });

    testWidgets('renders expandable tray when note has more than 2 images and toggles expansion', (tester) async {
      final ref1 = ImportImageReference(
        originalSyntax: '![One](img1.png)',
        rawTarget: 'img1.png',
        altText: 'One',
        resolvedFilePath: img1.path,
        fileSizeBytes: 2,
        status: ImportImageStatus.resolved,
      );

      final ref2 = ImportImageReference(
        originalSyntax: '![Two](img2.jpg)',
        rawTarget: 'img2.jpg',
        altText: 'Two',
        resolvedFilePath: img2.path,
        fileSizeBytes: 2,
        status: ImportImageStatus.resolved,
      );

      final ref3 = ImportImageReference(
        originalSyntax: '![Three](img3.webp)',
        rawTarget: 'img3.webp',
        altText: 'Three',
        resolvedFilePath: img3.path,
        fileSizeBytes: 2,
        status: ImportImageStatus.resolved,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note with 3 Images',
        content: 'Content',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref1, ref2, ref3],
      );

      await tester.pumpWidget(buildTestWidget(item: item));
      await tester.pumpAndSettle();

      expect(find.text('ATTACHMENTS (3)'), findsOneWidget);
      expect(find.text('img1.png'), findsOneWidget);
      expect(find.text('img2.jpg'), findsOneWidget);
      // img3 should be hidden initially in collapsed tray
      expect(find.text('img3.webp'), findsNothing);

      expect(find.text('Show all 3 attachments'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Show all 3 attachments'));
      await tester.pumpAndSettle();

      expect(find.text('img3.webp'), findsOneWidget);
      expect(find.text('Show fewer attachments'), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('Show fewer attachments'));
      await tester.pumpAndSettle();

      expect(find.text('img3.webp'), findsNothing);
      expect(find.text('Show all 3 attachments'), findsOneWidget);
    });

    testWidgets('triggers onRelinkImage callback when tapping Relink', (tester) async {
      ImportImageReference? relinkedRef;

      final ref = ImportImageReference(
        originalSyntax: '![Broken](broken.png)',
        rawTarget: 'broken.png',
        altText: 'Broken',
        status: ImportImageStatus.missing,
      );

      final item = MarkdownImportItem(
        filePath: '/tmp/note.md',
        relativePath: 'note.md',
        title: 'Note with Missing Image',
        content: 'Content',
        tags: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        fileSizeBytes: 100,
        imageReferences: [ref],
      );

      await tester.pumpWidget(
        buildTestWidget(
          item: item,
          onRelinkImage: (r) => relinkedRef = r,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Relink'), findsOneWidget);
      await tester.tap(find.text('Relink'));
      await tester.pumpAndSettle();

      expect(relinkedRef, isNotNull);
      expect(relinkedRef!.displayName, equals('broken.png'));
    });
  });
}
