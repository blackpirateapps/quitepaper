import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_coordinator.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_normalizer.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';
import 'package:quitepaper/features/quick_capture/presentation/quick_capture_screen.dart';

void main() {
  testWidgets(
    'queues distinct shares and opens each once after active capture closes',
    (tester) async {
      final db = AppDatabase.memory();
      final key = GlobalKey<NavigatorState>();
      addTearDown(() async {
        QuickCaptureCoordinator.dispose();
        await db.close();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            navigatorKey: key,
            theme: AppTheme.light(),
            home: const Scaffold(),
          ),
        ),
      );
      QuickCaptureCoordinator.initialize(key);
      QuickCapturePayload share(String path) =>
          QuickCaptureNormalizer.normalize(
            origin: CaptureOrigin.share,
            rawText: 'https://example.com/$path',
          );
      QuickCaptureCoordinator.openCapture(share('first'));
      await tester.pumpAndSettle();
      QuickCaptureCoordinator.openCapture(share('first'));
      QuickCaptureCoordinator.openCapture(share('second'));
      QuickCaptureCoordinator.openCapture(share('second'));
      QuickCaptureCoordinator.openCapture(share('third'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<QuickCaptureScreen>(find.byType(QuickCaptureScreen))
            .payload
            .sourceUrl,
        'https://example.com/first',
      );
      for (final path in ['second', 'third']) {
        key.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(QuickCaptureScreen), findsOneWidget);
        expect(
          tester
              .widget<QuickCaptureScreen>(find.byType(QuickCaptureScreen))
              .payload
              .sourceUrl,
          'https://example.com/$path',
        );
      }
      key.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byType(QuickCaptureScreen), findsNothing);
      expect(QuickCaptureCoordinator.isRouteOpen, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
