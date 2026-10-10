import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_theme.dart';
import 'package:quitepaper/core/image_processing/document_quad.dart';
import 'package:quitepaper/features/scanner/presentation/widgets/interactive_quad_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InteractiveQuadOverlay Widget Tests', () {
    testWidgets('Renders the quad overlay inside a sized box', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: InteractiveQuadOverlay(
                quad: NormalizedQuad.full,
                accentColor: Colors.amber,
                onQuadChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(InteractiveQuadOverlay), findsOneWidget);
    });

    testWidgets('Dragging a corner handle inward moves only that corner and '
        'keeps the quad convex', (tester) async {
      NormalizedQuad? updatedQuad;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: InteractiveQuadOverlay(
                quad: NormalizedQuad.full,
                accentColor: Colors.amber,
                onQuadChanged: (quad) => updatedQuad = quad,
              ),
            ),
          ),
        ),
      );

      // The top-left corner sits at local (0, 0); its 44px touch target spans
      // the top-left of the box, so (10, 10) lands on the handle.
      final gesture = await tester.startGesture(const Offset(10, 10));
      await gesture.moveBy(const Offset(40, 40)); // drag inward (down-right)
      await gesture.up();
      await tester.pump();

      expect(updatedQuad, isNotNull);

      // Only the top-left corner moved inward from the frame origin.
      expect(updatedQuad!.topLeft.x, greaterThan(0.0));
      expect(updatedQuad!.topLeft.y, greaterThan(0.0));

      // The other three corners are untouched.
      expect(updatedQuad!.topRight, NormalizedQuad.full.topRight);
      expect(updatedQuad!.bottomRight, NormalizedQuad.full.bottomRight);
      expect(updatedQuad!.bottomLeft, NormalizedQuad.full.bottomLeft);

      // The emitted shape stays valid.
      expect(updatedQuad!.isConvex, isTrue);
    });
  });
}
