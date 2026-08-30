import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/features/web_clipper/presentation/web_clip_dialog.dart';

void main() {
  testWidgets('WebClipDialog renders title, textfield, Browser button, and action buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: WebClipDialog(initialUrl: 'https://example.com/test-article'),
          ),
        ),
      ),
    );

    expect(find.text('Clip Webpage'), findsOneWidget);
    expect(find.text('https://example.com/test-article'), findsOneWidget);
    expect(find.text('Browser'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });
}
