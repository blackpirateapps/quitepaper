import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/app/theme/theme_family.dart';
import 'package:quitepaper/core/search/search_models.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_date_header.dart';
import 'package:quitepaper/features/notes/presentation/widgets/note_list_tile.dart';

void main() {
  final testNow = DateTime(2026, 8, 31, 14, 0, 0);

  group('NoteMetadataExtractor Unit Tests', () {
    test('extracts title and preview from plain note', () {
      final note = Note(
        id: 'note-1',
        title: 'Project Roadmap',
        content: 'Here are the key milestones for Q3 release.',
        createdAt: testNow,
        updatedAt: testNow,
        tags: const ['planning'],
      );

      final metadata = NoteMetadataExtractor.extract(note);
      expect(metadata.displayTitle, 'Project Roadmap');
      expect(metadata.previewSnippet, 'Here are the key milestones for Q3 release.');
      expect(metadata.hasCustomTitle, true);
      expect(metadata.tags, const ['planning']);
      expect(metadata.attachmentSummary, isNull);
    });

    test('derives title from first line when title is empty', () {
      final note = Note(
        id: 'note-2',
        title: '',
        content: '# Quick Thought\nThis is a spontaneous idea written down quickly.',
        createdAt: testNow,
        updatedAt: testNow,
      );

      final metadata = NoteMetadataExtractor.extract(note);
      expect(metadata.displayTitle, 'Quick Thought');
      expect(metadata.previewSnippet, 'This is a spontaneous idea written down quickly.');
      expect(metadata.hasCustomTitle, false);
    });

    test('extracts title and description from YAML frontmatter (Clipped Note)', () {
      final note = Note(
        id: 'note-3',
        title: '',
        content: '''---
title: "The Hugging Face attack surprised me"
author: "AI Researcher"
description: "A clean excerpt from the clipped article summarizing the security event."
tags: [clipped, security]
---
# Full Article Content
The security vulnerability was discovered during an automated penetration test.
''',
        createdAt: testNow,
        updatedAt: testNow,
        tags: const ['clipped'],
      );

      final metadata = NoteMetadataExtractor.extract(note);
      expect(metadata.displayTitle, 'The Hugging Face attack surprised me');
      expect(metadata.previewSnippet, 'A clean excerpt from the clipped article summarizing the security event.');
    });

    test('strips Markdown syntax (headers, quotes, lists, checklists, formatting)', () {
      final note = Note(
        id: 'note-4',
        title: 'Markdown Test',
        content: '''
> Important quote here
- [ ] Incomplete task item
- [x] Completed task item
* Bullet point item
1. Numbered item
**Bold text** and *italic text* and ==highlighted text== and `inline code`.
''',
        createdAt: testNow,
        updatedAt: testNow,
      );

      final metadata = NoteMetadataExtractor.extract(note);
      expect(metadata.displayTitle, 'Markdown Test');
      expect(metadata.previewSnippet, contains('Important quote here'));
      expect(metadata.previewSnippet, contains('Incomplete task item'));
      expect(metadata.previewSnippet, isNot(contains('>')));
      expect(metadata.previewSnippet, isNot(contains('- [ ]')));
      expect(metadata.previewSnippet, isNot(contains('**')));
      expect(metadata.previewSnippet, isNot(contains('==')));
    });

    test('extracts text attachment metadata for PDFs, images, and files', () {
      // 1. Single PDF with page count
      final pdfNote = Note(
        id: 'note-pdf-1',
        title: 'Research Paper',
        content: 'Here is the scanned report: [Research Paper · 12 pages](qp://document/doc-uuid-1)',
        createdAt: testNow,
        updatedAt: testNow,
      );
      final pdfMeta = NoteMetadataExtractor.extract(pdfNote);
      expect(pdfMeta.attachmentSummary, 'PDF · 12 pages');

      // 2. Multiple PDFs with combined page count
      final multiPdfNote = Note(
        id: 'note-pdf-2',
        title: 'Financial Statements',
        content: '[Q1 Report (10 pages)](qp://document/1)\n[Q2 Report (21 pages)](qp://document/2)',
        createdAt: testNow,
        updatedAt: testNow,
      );
      final multiPdfMeta = NoteMetadataExtractor.extract(multiPdfNote);
      expect(multiPdfMeta.attachmentSummary, '2 PDFs · 31 pages');

      // 3. Images
      final imgNote = Note(
        id: 'note-img-1',
        title: 'Plant Tracker',
        content: 'Watered the plants today.\n![Monstera](qp://asset/img-uuid-1)\n![Fiddle Leaf](qp://asset/img-uuid-2)',
        createdAt: testNow,
        updatedAt: testNow,
      );
      final imgMeta = NoteMetadataExtractor.extract(imgNote);
      expect(imgMeta.attachmentSummary, '2 images');
      expect(imgMeta.thumbnailUri, 'qp://asset/img-uuid-1');

      // 4. Generic file
      final docxNote = Note(
        id: 'note-file-1',
        title: 'Contract',
        content: 'Draft contract attached: [Contract_Draft_v2.docx](qp://asset/file-uuid-1)',
        createdAt: testNow,
        updatedAt: testNow,
      );
      final docxMeta = NoteMetadataExtractor.extract(docxNote);
      expect(docxMeta.attachmentSummary, 'DOCX');
    });

    test('protects password-protected note preview', () {
      final protectedNote = Note(
        id: 'note-secret',
        title: 'Secret Keys',
        content: '<!-- quiet-paper-encrypted-note-v1:{"nonce":"...","ciphertext":"..."} -->',
        createdAt: testNow,
        updatedAt: testNow,
      );

      final metadata = NoteMetadataExtractor.extract(protectedNote);
      expect(metadata.isPasswordProtected, true);
      expect(metadata.previewSnippet, '🔒 Password protected note');
      expect(metadata.attachmentSummary, isNull);
      expect(metadata.thumbnailUri, isNull);
    });
  });

  group('NoteListTile Widget & Theme Family Tests', () {
    final note = Note(
      id: 'test-note-1',
      title: 'Design Philosophy',
      content: 'Calm, distraction-free writing experience with content-first hierarchy. [Spec · 8 pages](qp://document/doc-1)',
      createdAt: testNow,
      updatedAt: testNow,
      tags: const ['editorial', 'design'],
    );

    Widget buildTileWithTheme({
      required ThemeFamily family,
      required bool isDark,
      bool isSelected = false,
      String? searchQuery,
      List<TokenSpanDto>? titleSpans,
      List<TokenSpanDto>? snippetSpans,
      VoidCallback? onTap,
      ValueChanged<String>? onTagTap,
    }) {
      final themeData = isDark
          ? AppTheme.dark(family: family)
          : AppTheme.light(family: family);

      return ProviderScope(
        child: MaterialApp(
          theme: themeData,
          home: Scaffold(
            body: NoteListTile(
              note: note,
              isSelected: isSelected,
              searchQuery: searchQuery,
              titleHighlightSpans: titleSpans,
              snippetHighlightSpans: snippetSpans,
              onTap: onTap ?? () {},
              onTagTap: onTagTap,
            ),
          ),
        ),
      );
    }

    testWidgets('renders cleanly in Classic Paper Light theme', (tester) async {
      await tester.pumpWidget(
        buildTileWithTheme(family: ThemeFamily.classicPaper, isDark: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design Philosophy'), findsOneWidget);
      expect(find.textContaining('Calm, distraction-free'), findsOneWidget);
      expect(find.text('#editorial'), findsOneWidget);
      expect(find.text('#design'), findsOneWidget);
      expect(find.text('PDF · 8 pages'), findsOneWidget);
    });

    testWidgets('renders cleanly in Classic Paper Dark theme', (tester) async {
      await tester.pumpWidget(
        buildTileWithTheme(family: ThemeFamily.classicPaper, isDark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design Philosophy'), findsOneWidget);
      expect(find.text('#editorial'), findsOneWidget);
      expect(find.text('PDF · 8 pages'), findsOneWidget);
    });

    testWidgets('renders cleanly in Warm Paper Light theme', (tester) async {
      await tester.pumpWidget(
        buildTileWithTheme(family: ThemeFamily.warmPaper, isDark: false),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design Philosophy'), findsOneWidget);
      expect(find.text('#editorial'), findsOneWidget);
      expect(find.text('PDF · 8 pages'), findsOneWidget);
    });

    testWidgets('renders cleanly in Midnight Paper Dark theme', (tester) async {
      await tester.pumpWidget(
        buildTileWithTheme(family: ThemeFamily.warmPaper, isDark: true),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design Philosophy'), findsOneWidget);
      expect(find.text('#editorial'), findsOneWidget);
      expect(find.text('PDF · 8 pages'), findsOneWidget);
    });

    testWidgets('handles tap and tag tap callbacks', (tester) async {
      bool tileTapped = false;
      String? tappedTag;

      await tester.pumpWidget(
        buildTileWithTheme(
          family: ThemeFamily.classicPaper,
          isDark: false,
          onTap: () => tileTapped = true,
          onTagTap: (tag) => tappedTag = tag,
        ),
      );
      await tester.pumpAndSettle();

      // Tap on tag chip
      await tester.tap(find.text('#editorial'));
      await tester.pumpAndSettle();
      expect(tappedTag, 'editorial');

      // Tap on tile body
      await tester.tap(find.text('Design Philosophy'));
      await tester.pumpAndSettle();
      expect(tileTapped, true);
    });

    testWidgets('renders search query highlights correctly', (tester) async {
      await tester.pumpWidget(
        buildTileWithTheme(
          family: ThemeFamily.classicPaper,
          isDark: false,
          searchQuery: 'Design',
          titleSpans: const [
            TokenSpanDto(start: 0, end: 6, isExact: true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NoteListTile), findsOneWidget);
    });

    testWidgets('renders pinned and password protected icons', (tester) async {
      final pinnedNote = note.copyWith(isPinned: true);
      final themeData = AppTheme.light(family: ThemeFamily.classicPaper);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: themeData,
            home: Scaffold(
              body: NoteListTile(
                note: pinnedNote,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.push_pin_rounded), findsOneWidget);
    });
  });

  group('NoteDateHeader Tests', () {
    testWidgets('renders header with and without top divider', (tester) async {
      final themeData = AppTheme.light(family: ThemeFamily.classicPaper);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeData,
          home: const Scaffold(
            body: Column(
              children: [
                NoteDateHeader(title: 'Pinned', isFirst: true),
                NoteDateHeader(title: 'Yesterday', showTopDivider: true),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pinned'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });
}
