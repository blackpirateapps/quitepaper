import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/documents/document_provider.dart';
import 'package:quitepaper/core/documents/pdf_thumbnail_service.dart';
import 'package:quitepaper/core/documents/presentation/widgets/pdf_thumbnail_sidebar.dart';

class SidebarThumbnails extends Fake implements PdfThumbnailService {
  final requests = <int>[];
  @override
  Future<Uint8List?> getPageThumbnail({
    required String documentId,
    required int pageIndex,
    required Uint8List pdfBytes,
  }) async {
    requests.add(pageIndex);
    return null;
  }
}

void main() {
  for (final width in [100.0, 140.0, 200.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'active thumbnail stays visible at width $width text scale $scale',
        (tester) async {
          final selected = ValueNotifier<int>(0);
          final service = SidebarThumbnails();
          addTearDown(selected.dispose);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                pdfThumbnailServiceProvider.overrideWithValue(service),
              ],
              child: MaterialApp(
                theme: AppTheme.light(),
                home: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: SizedBox(
                      width: width,
                      height: 600,
                      child: PdfThumbnailSidebar(
                        documentId: 'sidebar',
                        pdfBytes: Uint8List(1),
                        width: width,
                        pageCount: 250,
                        selectedPageIndexListenable: selected,
                        onPageSelected: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final page in [2, 125, 200, 50, 249, 250, 1]) {
            selected.value = page - 1;
            await tester.pumpAndSettle();
            final tile = find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.selected == true,
            );
            expect(tile, findsOneWidget, reason: 'page $page');
            final rect = tester.getRect(tile);
            expect(rect.top, greaterThanOrEqualTo(-0.01));
            expect(rect.bottom, lessThanOrEqualTo(600.01));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets('random navigation renders only destination thumbnails', (
    tester,
  ) async {
    final selected = ValueNotifier<int>(0);
    final service = SidebarThumbnails();
    addTearDown(selected.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pdfThumbnailServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 140,
              height: 600,
              child: PdfThumbnailSidebar(
                documentId: 'bounded',
                pdfBytes: Uint8List(1),
                pageCount: 250,
                selectedPageIndexListenable: selected,
                onPageSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final page in [125, 200, 50, 249, 1]) {
      service.requests.clear();
      selected.value = page - 1;
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        service.requests.length,
        lessThanOrEqualTo(8),
        reason:
            'page $page should not render intervening pages: ${service.requests}',
      );
      final tile = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.selected == true,
      );
      expect(tile, findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });
}
