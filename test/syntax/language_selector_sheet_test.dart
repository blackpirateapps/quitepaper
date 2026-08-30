import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';
import 'package:quitepaper/core/syntax/presentation/language_selector_sheet.dart';

void main() {
  Widget buildTestWidget({void Function(SyntaxLanguage)? onSelected}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                LanguageSelectorSheet.show(
                  context,
                  currentLanguageId: 'dart',
                );
              },
              child: const Text('Open Picker'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('LanguageSelectorSheet opens, filters by search query, and displays languages', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();

    expect(find.text('Select Code Language'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Verify initial languages appear
    expect(find.text('Dart'), findsWidgets);

    // Search for 'rust'
    await tester.enterText(find.byType(TextField), 'rust');
    await tester.pumpAndSettle();

    expect(find.text('Rust'), findsOneWidget);

    // Select Rust
    await tester.tap(find.text('Rust'));
    await tester.pumpAndSettle();

    // Sheet should be dismissed
    expect(find.text('Select Code Language'), findsNothing);
  });
}
