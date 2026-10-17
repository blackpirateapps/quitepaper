import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/widgets/quiet_adaptive_modal.dart';
import 'package:quitepaper/core/widgets/quiet_editorial_dialog.dart';

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

  group('QuietAdaptiveModal - Platform Routing', () {
    testWidgets('Renders bottom sheet on Android', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    builder: (sheetCtx) => const Text('Sheet Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sheet Content'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsNothing);
    });

    testWidgets('Renders QuietEditorialDialog on Linux with dialog type', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    type: AdaptiveModalType.dialog,
                    title: 'Test Dialog Title',
                    subtitle: 'Test Subtitle',
                    builder: (dialogCtx) => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Dialog Content'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Dialog Title'), findsOneWidget);
      expect(find.text('Test Subtitle'), findsOneWidget);
      expect(find.text('Dialog Content'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Close button dismisses
      await tester.tap(find.byTooltip('Close (Esc)'));
      await tester.pumpAndSettle();

      expect(find.text('Dialog Content'), findsNothing);
    });

    testWidgets('Escape key dismisses QuietEditorialDialog on Linux', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    type: AdaptiveModalType.dialog,
                    title: 'Escape Test',
                    builder: (dialogCtx) => const Text('Dialog Content'),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Escape Test'), findsOneWidget);

      // Send Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Escape Test'), findsNothing);
    });

    testWidgets('Renders Spotlight palette on Linux with spotlight type and dismisses on Escape', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    type: AdaptiveModalType.spotlight,
                    maxWidth: 500,
                    builder: (dialogCtx) => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Spotlight Content'),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Spotlight Content'), findsOneWidget);

      // Send Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Spotlight Content'), findsNothing);
    });

    testWidgets('Renders anchored popover on Linux with anchorKey and dismisses on Escape', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ElevatedButton(
                key: anchorKey,
                onPressed: () {
                  final ctx = anchorKey.currentContext!;
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    type: AdaptiveModalType.popover,
                    anchorKey: anchorKey,
                    builder: (popoverCtx) => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Popover Item 1'),
                    ),
                  );
                },
                child: const Text('Anchor Button'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();

      expect(find.text('Popover Item 1'), findsOneWidget);

      // Send Escape key
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Popover Item 1'), findsNothing);
    });

    testWidgets('Anchored popover flips vertically when near bottom of viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show<void>(
                    context: ctx,
                    type: AdaptiveModalType.popover,
                    cursorPosition: const Offset(300, 760), // Near bottom of 800h screen
                    builder: (popCtx) => const SizedBox(
                      width: 200,
                      height: 150,
                      child: Text('Flipped Popover'),
                    ),
                  );
                },
                child: const Text('Open Bottom'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Bottom'));
      await tester.pumpAndSettle();

      expect(find.text('Flipped Popover'), findsOneWidget);

      final popoverTop = tester.getTopLeft(find.text('Flipped Popover')).dy;
      // Because cursor is at 760, and height is 150 + padding, it must open ABOVE 760
      expect(popoverTop, lessThan(760));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Flipped Popover'), findsNothing);
    });

    testWidgets('Renders anchored popover on Linux with anchorContext and PopoverAlignment.end', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 300, top: 100),
              child: SizedBox(
                width: 100,
                height: 48,
                child: Builder(
                  builder: (btnCtx) => ElevatedButton(
                    onPressed: () {
                      QuietAdaptiveModal.show<void>(
                        context: btnCtx,
                        type: AdaptiveModalType.popover,
                        anchorContext: btnCtx,
                        alignment: PopoverAlignment.end,
                        minWidth: 200,
                        maxWidth: 200,
                        builder: (popCtx) => const SizedBox(
                          width: 200,
                          height: 100,
                          child: Text('End Aligned Popover'),
                        ),
                      );
                    },
                    child: const Text('...'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('...'));
      await tester.pumpAndSettle();

      expect(find.text('End Aligned Popover'), findsOneWidget);

      final buttonRect = tester.getRect(find.byType(ElevatedButton));
      final popoverRect = tester.getRect(find.text('End Aligned Popover'));

      expect(popoverRect.top, greaterThanOrEqualTo(buttonRect.bottom));
      expect(popoverRect.right, lessThanOrEqualTo(buttonRect.right));
      expect(popoverRect.left, closeTo(buttonRect.right - 200, 1.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('End Aligned Popover'), findsNothing);
    });

    testWidgets('Renders anchored popover on Linux with PopoverAlignment.start', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 300, top: 100),
              child: SizedBox(
                width: 100,
                height: 48,
                child: Builder(
                  builder: (btnCtx) => ElevatedButton(
                    onPressed: () {
                      QuietAdaptiveModal.show<void>(
                        context: btnCtx,
                        type: AdaptiveModalType.popover,
                        anchorContext: btnCtx,
                        alignment: PopoverAlignment.start,
                        minWidth: 200,
                        maxWidth: 200,
                        builder: (popCtx) => const SizedBox(
                          width: 200,
                          height: 100,
                          child: Text('Start Aligned Popover'),
                        ),
                      );
                    },
                    child: const Text('StartBtn'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('StartBtn'));
      await tester.pumpAndSettle();

      expect(find.text('Start Aligned Popover'), findsOneWidget);

      final buttonRect = tester.getRect(find.byType(ElevatedButton));
      final popoverRect = tester.getRect(find.text('Start Aligned Popover'));

      expect(popoverRect.top, greaterThanOrEqualTo(buttonRect.bottom));
      expect(popoverRect.left, closeTo(buttonRect.left, 1.0));

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Start Aligned Popover'), findsNothing);
    });
  });

  group('AdaptiveSheetDragHandle', () {
    testWidgets('Renders container on Android', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: const AdaptiveSheetDragHandle(),
        ),
      );

      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('Renders SizedBox.shrink on Linux', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: const AdaptiveSheetDragHandle(),
        ),
      );

      expect(find.byType(Container), findsNothing);
    });
  });
}
