import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/markdown/markdown_preview.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildPreviewTestWidget({
    required String markdownData,
    ValueChanged<String>? onMarkdownChanged,
    bool? interactiveChecklists,
    bool shrinkWrap = false,
    SharedPreferences? prefs,
  }) {
    return ProviderScope(
      overrides: [
        if (prefs != null)
          sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: QuietMarkdownPreview(
            markdownData: markdownData,
            onMarkdownChanged: onMarkdownChanged,
            interactiveChecklists: interactiveChecklists,
            shrinkWrap: shrinkWrap,
          ),
        ),
      ),
    );
  }

  group('QuietMarkdownPreview Checklist Tests', () {
    testWidgets('renders PhosphorIconsRegular.square for unchecked and PhosphorIconsFill.checkSquare for checked', (tester) async {
      const md = '''
- [ ] Milk
- [x] Eggs
''';
      await tester.pumpWidget(buildPreviewTestWidget(markdownData: md));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);
    });

    testWidgets('tapping unchecked checkbox triggers onMarkdownChanged with - [x]', (tester) async {
      const md = '- [ ] Buy bread';
      String? updated;

      await tester.pumpWidget(buildPreviewTestWidget(
        markdownData: md,
        onMarkdownChanged: (val) => updated = val,
      ));
      await tester.pumpAndSettle();

      final squareFinder = find.byIcon(PhosphorIconsRegular.square);
      expect(squareFinder, findsOneWidget);

      await tester.tap(squareFinder);
      await tester.pumpAndSettle();

      expect(updated, equals('- [x] Buy bread'));
    });

    testWidgets('tapping checked checkbox triggers onMarkdownChanged with - [ ]', (tester) async {
      const md = '- [x] Clean room';
      String? updated;

      await tester.pumpWidget(buildPreviewTestWidget(
        markdownData: md,
        onMarkdownChanged: (val) => updated = val,
      ));
      await tester.pumpAndSettle();

      final checkedFinder = find.byIcon(PhosphorIconsFill.checkSquare);
      expect(checkedFinder, findsOneWidget);

      await tester.tap(checkedFinder);
      await tester.pumpAndSettle();

      expect(updated, equals('- [ ] Clean room'));
    });

    testWidgets('renders completed item text with strikethrough style', (tester) async {
      const md = '''
- [ ] Active task
- [x] Completed task
''';
      await tester.pumpWidget(buildPreviewTestWidget(markdownData: md));
      await tester.pumpAndSettle();

      // Find RichText widgets rendered by MarkdownBody
      final richTexts = tester.widgetList<RichText>(find.byType(RichText));
      bool foundStrikethrough = false;

      for (final rt in richTexts) {
        rt.text.visitChildren((span) {
          if (span is TextSpan && span.text?.contains('Completed task') == true) {
            if (span.style?.decoration == TextDecoration.lineThrough) {
              foundStrikethrough = true;
            }
          }
          return true;
        });
      }

      expect(foundStrikethrough, isTrue);
    });

    testWidgets('does NOT trigger onMarkdownChanged when interactiveChecklists is false', (tester) async {
      const md = '- [ ] Buy tea';
      String? updated;

      await tester.pumpWidget(buildPreviewTestWidget(
        markdownData: md,
        interactiveChecklists: false,
        onMarkdownChanged: (val) => updated = val,
      ));
      await tester.pumpAndSettle();

      final squareFinder = find.byIcon(PhosphorIconsRegular.square);
      expect(squareFinder, findsOneWidget);

      await tester.tap(squareFinder);
      await tester.pumpAndSettle();

      expect(updated, isNull);
    });

    testWidgets('does NOT trigger onMarkdownChanged when onMarkdownChanged is null (read only)', (tester) async {
      const md = '- [ ] Read only item';

      await tester.pumpWidget(buildPreviewTestWidget(
        markdownData: md,
        onMarkdownChanged: null,
      ));
      await tester.pumpAndSettle();

      final squareFinder = find.byIcon(PhosphorIconsRegular.square);
      expect(squareFinder, findsOneWidget);

      // Tapping should not cause errors
      await tester.tap(squareFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('works in shrinkWrap: true mode', (tester) async {
      const md = '''
- [ ] Shrink task 1
- [x] Shrink task 2
''';
      String? updated;

      await tester.pumpWidget(buildPreviewTestWidget(
        markdownData: md,
        shrinkWrap: true,
        onMarkdownChanged: (val) => updated = val,
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);

      await tester.tap(find.byIcon(PhosphorIconsRegular.square));
      await tester.pumpAndSettle();

      expect(updated, equals('''
- [x] Shrink task 1
- [x] Shrink task 2
'''));
    });

    testWidgets('toggles multiple checklist items individually in order', (tester) async {
      const md = '''
- [ ] Task A
- [ ] Task B
- [ ] Task C
''';
      String currentMd = md;

      Widget buildWidget() {
        return ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return QuietMarkdownPreview(
                    markdownData: currentMd,
                    onMarkdownChanged: (val) {
                      setState(() {
                        currentMd = val;
                      });
                    },
                  );
                },
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(3));
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNothing);

      // Tap second item (Task B)
      await tester.tap(find.byIcon(PhosphorIconsRegular.square).at(1));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(2));
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);
      expect(currentMd, equals('''
- [ ] Task A
- [x] Task B
- [ ] Task C
'''));

      // Tap first item (Task A)
      await tester.tap(find.byIcon(PhosphorIconsRegular.square).at(0));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsOneWidget);
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsNWidgets(2));
      expect(currentMd, equals('''
- [x] Task A
- [x] Task B
- [ ] Task C
'''));

      // Uncheck Task B (now checked)
      await tester.tap(find.byIcon(PhosphorIconsFill.checkSquare).at(1));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.square), findsNWidgets(2));
      expect(find.byIcon(PhosphorIconsFill.checkSquare), findsOneWidget);
      expect(currentMd, equals('''
- [x] Task A
- [ ] Task B
- [ ] Task C
'''));
    });
  });
}
