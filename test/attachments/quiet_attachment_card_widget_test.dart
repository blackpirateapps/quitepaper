import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/attachments/presentation/quiet_attachment_card.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp(Widget child, {AppDatabase? db}) {
    return ProviderScope(
      overrides: [
        if (db != null) databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('QuietAttachmentCard Widget Tests', () {
    testWidgets('renders filename, type label, size, and E2EE badge', (tester) async {
      final now = DateTime.now();
      final entity = AttachmentEntity(
        id: 'att-test-xlsx-1',
        fileName: 'quarterly_financials.xlsx',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        byteSize: 8,
        sha256: '0123456789abcdef',
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
          QuietAttachmentCard(
            attachmentId: entity.id,
            title: entity.fileName,
            uriString: 'qp://asset/${entity.id}',
            initialEntity: entity,
          ),
        ),
      );

      await tester.pump();

      expect(find.text('quarterly_financials.xlsx'), findsOneWidget);
      expect(find.text('Microsoft Excel • 8 B'), findsOneWidget);
      expect(find.text('ENC (QPA1)'), findsOneWidget);
      expect(find.byIcon(Icons.table_chart_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
    });

    testWidgets('renders QuietAttachmentCard with PDF document metadata and styles', (tester) async {
      final now = DateTime.now();
      final entity = AttachmentEntity(
        id: 'att-test-pdf-1',
        fileName: 'setup_guide.pdf',
        kind: 'file',
        createdAt: now,
        updatedAt: now,
        mimeType: 'application/pdf',
        byteSize: 3,
        sha256: 'fedcba9876543210',
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
          QuietAttachmentCard(
            attachmentId: entity.id,
            title: entity.fileName,
            uriString: 'qp://asset/${entity.id}',
            initialEntity: entity,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(QuietAttachmentCard), findsOneWidget);
      expect(find.text('setup_guide.pdf'), findsOneWidget);
      expect(find.text('PDF Document • 3 B'), findsOneWidget);
    });
  });
}
