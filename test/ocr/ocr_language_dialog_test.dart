import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/ocr/ocr_models.dart';
import 'package:quitepaper/core/ocr/presentation/ocr_language_dialog.dart';

void main() {
  testWidgets('OcrLanguageDialog renders English and confirms selection', (tester) async {
    OcrLanguage? selectedResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await OcrLanguageDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('OCR Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('EN'), findsOneWidget);

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('OCR Language'), findsNothing);
    expect(selectedResult, equals(OcrLanguage.english));
  });

  testWidgets('OcrLanguageDialog cancel dismisses without selection', (tester) async {
    OcrLanguage? selectedResult;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await OcrLanguageDialog.show(context);
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('OCR Language'), findsNothing);
    expect(selectedResult, isNull);
  });
}
