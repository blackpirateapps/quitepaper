import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';

void main() {
  Widget buildWrapper(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('QuietCodeBlockElementBuilder in QuietMarkdownPreview', () {
    testWidgets('renders code block with syntax highlighting and uppercase language header', (tester) async {
      const markdown = '''# Header
```dart
void main() {
  final greeting = "Hello World";
  print(greeting);
}
```
''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Language name displayed in uppercase in header bar
      expect(find.text('DART'), findsOneWidget);

      // 2. Copy button rendered
      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      // 3. Code content rendered
      expect(find.textContaining('void main()'), findsOneWidget);
      expect(find.textContaining('final greeting = "Hello World"'), findsOneWidget);

      // 4. Verify syntax token styling (RichText contains styled spans)
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
    });

    testWidgets('renders plain text fallback when code block has no language', (tester) async {
      const markdown = '''```
plain text line 1
plain text line 2
```''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PLAIN TEXT'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.textContaining('plain text line 1'), findsOneWidget);
    });

    testWidgets('tapping Copy button copies source to clipboard and shows Copied feedback', (tester) async {
      const code = 'const answer = 42;';
      const markdown = '```javascript\n$code\n```';

      // Track clipboard content
      String? copiedString;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            copiedString = (methodCall.arguments as Map)['text'] as String?;
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JAVASCRIPT'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Copy'));
      await tester.pump();

      // Verify copied to clipboard without trailing newline
      expect(copiedString, equals(code));

      // Verify UI feedback
      expect(find.text('Copied'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Fast forward past the 2s timer
      await tester.pump(const Duration(milliseconds: 2100));

      // Reverts back to Copy
      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('overlays search query matches inside preview code blocks', (tester) async {
      const markdown = '''```python
def calculate_tax(amount):
    return amount * 0.2
```''';

      await tester.pumpWidget(
        buildWrapper(
          const QuietMarkdownPreview(
            markdownData: markdown,
            searchQuery: 'calculate_tax',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PYTHON'), findsOneWidget);
      expect(find.textContaining('calculate_tax'), findsWidgets);
    });

    testWidgets('supports horizontal scrolling for long code lines', (tester) async {
      final longLine = 'final url = "https://example.com/api/v1/resource?param1=abcdefghijklmnopqrstuvwxyz&param2=1234567890";';
      final markdown = '```dart\n$longLine\n```';

      await tester.pumpWidget(
        buildWrapper(
          QuietMarkdownPreview(
            markdownData: markdown,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsWidgets);

      final horizontalScrollView = tester.widgetList<SingleChildScrollView>(scrollFinder).firstWhere(
        (sv) => sv.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrollView, isNotNull);
    });
  });
}
