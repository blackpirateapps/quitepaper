import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/email_import/application/email_import_gateway.dart';
import 'package:quitepaper/features/email_import/presentation/email_import_screen.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_normalizer.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';
import 'package:quitepaper/features/quick_capture/presentation/quick_capture_screen.dart';
import 'email_import_screen_test.dart' show FakeEmailGateway;

void main() {
  testWidgets(
    'shared paragraph stays in Quick Capture until explicit Save as Email; cancel keeps draft',
    (tester) async {
      final db = AppDatabase.memory();
      final gateway = FakeEmailGateway();
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: 'Shared email paragraph',
        rawSubject: 'Shared subject',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            emailImportGatewayProvider.overrideWithValue(gateway),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: QuickCaptureScreen(payload: payload),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Quick Capture'), findsOneWidget);
      expect(find.byType(EmailImportScreen), findsNothing);
      await tester.tap(find.text('Save as Email'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailImportScreen), findsOneWidget);
      expect(find.text('Shared subject'), findsOneWidget);
      expect(find.text('Shared email paragraph'), findsOneWidget);
      expect(await db.getAllNotesRaw(), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Quick Capture'), findsOneWidget);
      expect(
        (await db.getAllQuickCaptureDrafts()).single.content,
        'Shared email paragraph',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await db.close();
    },
  );
  testWidgets(
    'URL-only share retains web clipping and is not labeled full email',
    (tester) async {
      final db = AppDatabase.memory();
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: 'https://example.test/article',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: QuickCaptureScreen(payload: payload),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Save as Email'), findsNothing);
      expect(find.text('Quick Capture'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await db.close();
    },
  );
}
