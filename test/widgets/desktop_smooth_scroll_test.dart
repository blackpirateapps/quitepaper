import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/widgets/desktop_smooth_scroll.dart';

void main() {
  group('DesktopSmoothScroll Widget Tests', () {
    testWidgets('renders child correctly', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopSmoothScroll(
              controller: controller,
              child: ListView.builder(
                controller: controller,
                itemCount: 50,
                itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 5'), findsOneWidget);
    });

    testWidgets('intercepts pointer scroll event on desktop and animates offset', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: DesktopSmoothScroll(
                controller: controller,
                scrollSpeedMultiplier: 1.5,
                animationDuration: const Duration(milliseconds: 200),
                child: ListView.builder(
                  controller: controller,
                  itemCount: 100,
                  itemExtent: 50,
                  itemBuilder: (context, index) => Text('Row $index'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, 0.0);

      // Dispatch PointerScrollEvent
      final pointerLocation = tester.getCenter(find.byType(DesktopSmoothScroll));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: pointerLocation,
          scrollDelta: const Offset(0, 40), // scroll down 40px
        ),
      );

      // Let animation run
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.offset, greaterThan(0.0));
    });

    testWidgets('resolves ambient PrimaryScrollController when no controller is explicitly passed',
        (tester) async {
      final primaryController = ScrollController();
      addTearDown(primaryController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrimaryScrollController(
              controller: primaryController,
              child: DesktopSmoothScroll(
                child: ListView.builder(
                  primary: true,
                  itemCount: 50,
                  itemBuilder: (context, index) => Text('Primary $index'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Primary 0'), findsOneWidget);
      expect(primaryController.hasClients, isTrue);
    });
  });
}
