import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_radii.dart';
import 'package:quitepaper/features/settings/presentation/widgets/font_picker_sheet.dart';
import 'package:quitepaper/features/settings/presentation/widgets/google_fonts_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    required Widget child,
    TargetPlatform platform = TargetPlatform.android,
  }) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          platform: platform,
          extensions: const [
            AppColors.light,
          ],
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FontPickerSheet Mobile Background', () {
    testWidgets('Renders with opaque colors.surface container on mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  FontPickerSheet.show(
                    ctx,
                    title: 'Heading Font',
                    currentFont: null,
                    type: FontPickerType.heading,
                    onFontSelected: (_) {},
                  );
                },
                child: const Text('Open Font Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Font Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Heading Font'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      // Verify that DraggableScrollableSheet's child contains a Material with colors.surface
      final materials = tester.widgetList<Material>(find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Material),
      ));

      final surfaceMaterial = materials.firstWhere(
        (m) =>
            m.color == AppColors.light.surface &&
            m.borderRadius == const BorderRadius.vertical(top: AppRadii.rLg),
      );
      expect(surfaceMaterial, isNotNull);
    });

    testWidgets('Selecting a font in FontPickerSheet triggers callback and pops', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? selectedFont;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  FontPickerSheet.show(
                    ctx,
                    title: 'Heading Font',
                    currentFont: null,
                    type: FontPickerType.heading,
                    onFontSelected: (f) => selectedFont = f,
                  );
                },
                child: const Text('Open Font Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Font Picker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('System Serif'));
      await tester.pumpAndSettle();

      expect(selectedFont, equals('serif'));
      expect(find.byType(FontPickerSheet), findsNothing);
    });
  });

  group('GoogleFontsSheet Mobile Background', () {
    testWidgets('Renders with opaque colors.surface container on mobile', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  GoogleFontsSheet.show(
                    ctx,
                    currentFont: null,
                    onFontSelected: (_) {},
                  );
                },
                child: const Text('Open Google Fonts'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Google Fonts'));
      await tester.pumpAndSettle();

      expect(find.text('Google Fonts'), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);

      final materials = tester.widgetList<Material>(find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Material),
      ));

      final surfaceMaterial = materials.firstWhere(
        (m) =>
            m.color == AppColors.light.surface &&
            m.borderRadius == const BorderRadius.vertical(top: AppRadii.rLg),
      );
      expect(surfaceMaterial, isNotNull);
    });
  });
}
