import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/web_clipper/presentation/web_clip_dialog.dart';

import 'package:quitepaper/core/web_clipper/web_clipper_models.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_provider.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_service.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'web_clipper_service_test.dart' as fakes;

class PendingClipper extends WebClipperService {
  PendingClipper() : super(notesRepository: fakes.InMemoryNotesRepository());
  final result = Completer<WebClipScanResult>();
  @override
  Future<WebClipScanResult> scanUrl(String url) => result.future;
}

void main() {
  for (final width in [320.0, 360.0, 392.7]) {
    testWidgets('URL dialog loading actions fit at $width dp', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final service = PendingClipper();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [webClipperServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const Scaffold(
              body: WebClipDialog(initialUrl: 'https://example.com/article'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
      final dialog = tester.getRect(find.byType(Dialog));
      final button = tester.getRect(find.byType(QuietButton));
      expect(button.right, lessThanOrEqualTo(dialog.right));
      expect(button.left, greaterThanOrEqualTo(dialog.left));
      await tester.pumpWidget(const SizedBox.shrink());
      service.result.completeError(StateError('test finished'));
      await tester.pump();
    });
  }

  testWidgets(
    'WebClipDialog renders title, textfield, Browser button, and action buttons',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: WebClipDialog(
                initialUrl: 'https://example.com/test-article',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Clip Webpage'), findsOneWidget);
      expect(find.text('https://example.com/test-article'), findsOneWidget);
      expect(find.text('Browser'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    },
  );
}
