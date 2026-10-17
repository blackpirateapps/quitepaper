import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/pixel_snap.dart';

void main() {
  group('PixelSnap Tests', () {
    testWidgets('hairlineWidth computes correct physical pixel mapping', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 1.25),
            child: Builder(
              builder: (context) {
                final width = PixelSnap.hairlineWidth(context);
                expect(width, closeTo(1.0 / 1.25, 0.001));
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    testWidgets('hairlineWidth clamps to minimum safe width on ultra-high DPR', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(devicePixelRatio: 4.0),
            child: Builder(
              builder: (context) {
                final width = PixelSnap.hairlineWidth(context);
                expect(width, 0.5);
                return const SizedBox();
              },
            ),
          ),
        ),
      );
    });

    test('snap rounds logical pixels to nearest physical device pixel grid', () {
      const dpr = 1.25;
      // 1.0 * 1.25 = 1.25 -> rounds to 1.0 -> 1.0 / 1.25 = 0.8
      expect(PixelSnap.snap(1.0, dpr), 0.8);
      // 1.6 * 1.25 = 2.0 -> rounds to 2.0 -> 2.0 / 1.25 = 1.6
      expect(PixelSnap.snap(1.6, dpr), 1.6);
    });

    test('snapOffset snaps both dx and dy', () {
      const dpr = 1.25;
      final snapped = PixelSnap.snapOffset(const Offset(1.0, 1.6), dpr);
      expect(snapped.dx, 0.8);
      expect(snapped.dy, 1.6);
    });
  });
}
