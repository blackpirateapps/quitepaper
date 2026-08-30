import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/presentation/attachment_viewer_screen.dart';
import 'package:quitepaper/core/attachments/presentation/csv_attachment_viewer.dart';
import 'package:quitepaper/core/attachments/presentation/markdown_attachment_viewer.dart';
import 'package:quitepaper/core/attachments/presentation/plain_text_viewer.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotesRepository notesRepo;

  setUp(() {
    db = AppDatabase.memory();
    notesRepo = DriftNotesRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        notesRepositoryProvider.overrideWithValue(notesRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: child,
      ),
    );
  }

  group('AttachmentViewerScreen Widget Tests', () {
    testWidgets('renders plain text attachment with header and PlainTextViewer', (tester) async {
      final now = DateTime.now();
      final textContent = 'First line of text\nSecond line with keyword\nThird line';
      final rawBytes = Uint8List.fromList(utf8.encode(textContent));

      final entity = AttachmentEntity(
        id: 'att-txt-1',
        fileName: 'notes.txt',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'text/plain',
        byteSize: rawBytes.length,
        sha256: 'hash-notes-1',
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      await tester.pumpWidget(
        buildTestApp(
          AttachmentViewerScreen(
            attachmentId: entity.id,
            initialEntity: entity,
            initialBytes: rawBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('Plain Text • ${rawBytes.length} B'), findsOneWidget);
      expect(find.text('ENC (QPA1)'), findsOneWidget);
      expect(find.byType(PlainTextViewer), findsOneWidget);
      expect(find.textContaining('First line of text'), findsOneWidget);
    });

    testWidgets('renders Markdown attachment with Rendered preview and toggles to Source', (tester) async {
      final now = DateTime.now();
      final mdContent = '# Project Overview\n\nThis is a *markdown* document with a checklist:\n- [x] Task 1\n- [ ] Task 2';
      final rawBytes = Uint8List.fromList(utf8.encode(mdContent));

      final entity = AttachmentEntity(
        id: 'att-md-1',
        fileName: 'overview.md',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'text/markdown',
        byteSize: rawBytes.length,
        sha256: 'hash-md-1',
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      await tester.pumpWidget(
        buildTestApp(
          AttachmentViewerScreen(
            attachmentId: entity.id,
            initialEntity: entity,
            initialBytes: rawBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('overview.md'), findsOneWidget);
      expect(find.text('Markdown • ${rawBytes.length} B'), findsOneWidget);
      expect(find.byType(MarkdownAttachmentViewer), findsOneWidget);
      expect(find.text('Project Overview'), findsOneWidget);

      // Toggle to Source mode via appbar button
      final toggleButton = find.byIcon(Icons.code_rounded);
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // In Source mode, raw markdown is displayed in PlainTextViewer
      expect(find.byType(PlainTextViewer), findsOneWidget);
    });

    testWidgets('renders CSV spreadsheet in Table grid and toggles to Source', (tester) async {
      final now = DateTime.now();
      final csvContent = 'Item,Count,Cost\nLaptop,5,1200\nChair,10,150';
      final rawBytes = Uint8List.fromList(utf8.encode(csvContent));

      final entity = AttachmentEntity(
        id: 'att-csv-1',
        fileName: 'budget.csv',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'text/csv',
        byteSize: rawBytes.length,
        sha256: 'hash-csv-1',
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      await tester.pumpWidget(
        buildTestApp(
          AttachmentViewerScreen(
            attachmentId: entity.id,
            initialEntity: entity,
            initialBytes: rawBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('budget.csv'), findsOneWidget);
      expect(find.text('CSV Spreadsheet • ${rawBytes.length} B'), findsOneWidget);
      expect(find.byType(CsvAttachmentViewer), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Laptop'), findsOneWidget);
      expect(find.text('Chair'), findsOneWidget);

      // Toggle to Source mode
      final toggleButton = find.byIcon(Icons.code_rounded);
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.byType(PlainTextViewer), findsOneWidget);
    });

    testWidgets('search bar toggles, searches text, and displays match count', (tester) async {
      final now = DateTime.now();
      final textContent = 'Alpha line\nBeta line with target\nGamma target line\nDelta line';
      final rawBytes = Uint8List.fromList(utf8.encode(textContent));

      final entity = AttachmentEntity(
        id: 'att-search-1',
        fileName: 'log.txt',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'text/plain',
        byteSize: rawBytes.length,
        sha256: 'hash-search-1',
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      await tester.pumpWidget(
        buildTestApp(
          AttachmentViewerScreen(
            attachmentId: entity.id,
            initialEntity: entity,
            initialBytes: rawBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open search bar
      final searchIcon = find.byIcon(Icons.search_rounded);
      expect(searchIcon, findsOneWidget);
      await tester.tap(searchIcon);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'target');
      await tester.pumpAndSettle();

      // Should find 2 matches: "1/2"
      expect(find.text('1/2'), findsOneWidget);

      // Next match button
      final downArrow = find.byIcon(Icons.keyboard_arrow_down_rounded);
      await tester.tap(downArrow);
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);

      // Close search
      final closeButton = find.byIcon(Icons.close_rounded);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('renders fallback view for non-previewable binary files', (tester) async {
      final now = DateTime.now();
      final rawBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x00, 0x00]); // PK ZIP header

      final entity = AttachmentEntity(
        id: 'att-zip-1',
        fileName: 'archive.zip',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'application/zip',
        byteSize: rawBytes.length,
        sha256: 'hash-zip-1',
        encryptionKeyVersion: 1,
        isDirty: false,
        isDeleted: false,
        serverRevision: 0,
        uploadState: 'local_only',
        ocrState: 'not_requested',
        ocrLanguage: 'en',
      );

      await tester.pumpWidget(
        buildTestApp(
          AttachmentViewerScreen(
            attachmentId: entity.id,
            initialEntity: entity,
            initialBytes: rawBytes,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('archive.zip'), findsWidgets);
      expect(find.text("This file can't be previewed directly in Quiet Paper."), findsOneWidget);
      expect(find.text('Open With…'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Save As'), findsOneWidget);
    });
  });
}
