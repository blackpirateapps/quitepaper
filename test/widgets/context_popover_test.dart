import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/editor/presentation/widgets/heading/markdown_heading_action_sheet.dart';
import 'package:quitepaper/features/tags/presentation/widgets/tag_color_picker_sheet.dart';

void main() {
  Widget buildTestApp({
    required Widget child,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    return MaterialApp(
      theme: ThemeData(
        platform: platform,
        extensions: const [
          AppColors.light,
        ],
      ),
      home: Scaffold(body: child),
    );
  }

  group('Phase 2: Context Popovers Migration', () {
    testWidgets('MarkdownHeadingActionSheet opens as popover on Linux and dismisses with Escape', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final anchorKey = GlobalKey();
      int selected = 0;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Align(
            alignment: Alignment.topCenter,
            child: ElevatedButton(
              key: anchorKey,
              onPressed: () {
                final ctx = anchorKey.currentContext!;
                MarkdownHeadingActionSheet.show(
                  ctx,
                  currentLevel: 1,
                  anchorKey: anchorKey,
                  onSelectLevel: (lvl) => selected = lvl,
                );
              },
              child: const Text('Heading Tool'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();

      expect(find.text('Heading Level'), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Select H2
      await tester.tap(find.text('H2'));
      await tester.pumpAndSettle();

      expect(selected, 2);
      expect(find.text('Heading Level'), findsNothing);
    });

    testWidgets('MarkdownHeadingActionSheet opens as bottom sheet on Android', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  MarkdownHeadingActionSheet.show(
                    ctx,
                    currentLevel: 1,
                    onSelectLevel: (_) {},
                  );
                },
                child: const Text('Heading Tool'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Heading Tool'));
      await tester.pumpAndSettle();

      expect(find.text('Heading Level'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('TagColorPickerSheet opens as popover on Linux and selects color', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? chosenColor;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  chosenColor = await TagColorPickerSheet.show(
                    ctx,
                    currentColorId: null,
                  );
                },
                child: const Text('Color Tool'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Color Tool'));
      await tester.pumpAndSettle();

      expect(find.text('Tag Color'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Dismiss with Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Tag Color'), findsNothing);
      expect(chosenColor, isNull);
    });

    testWidgets('TagColorPickerSheet opens as bottom sheet on Android', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  TagColorPickerSheet.show(ctx);
                },
                child: const Text('Color Tool'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Color Tool'));
      await tester.pumpAndSettle();

      expect(find.text('Tag Color'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
    });
  });
}
