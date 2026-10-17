import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/syntax/domain/syntax_language.dart';
import 'package:quitepaper/core/syntax/presentation/language_selector_sheet.dart';
import 'package:quitepaper/features/editor/presentation/widgets/moment_picker_sheet.dart';
import 'package:quitepaper/features/editor/presentation/widgets/mood_picker_sheet.dart';

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

  group('Phase 3: Spotlight Command Palettes Migration', () {
    testWidgets('LanguageSelectorSheet opens as spotlight on Linux, filters, and selects item', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      SyntaxLanguage? selectedLanguage;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  final lang = await LanguageSelectorSheet.show(
                    ctx,
                    title: 'Select Code Language',
                  );
                  selectedLanguage = lang;
                },
                child: const Text('Open Languages'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Languages'));
      await tester.pumpAndSettle();

      // Verify it opened as a dialog, not a BottomSheet
      expect(find.text('Select Code Language'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      // Filter by "dart"
      await tester.enterText(find.byType(TextField), 'dart');
      await tester.pumpAndSettle();

      expect(find.text('Dart'), findsOneWidget);

      // Tap on Dart
      await tester.tap(find.text('Dart'));
      await tester.pumpAndSettle();

      expect(selectedLanguage, isNotNull);
      expect(selectedLanguage!.id, 'dart');
      expect(find.text('Select Code Language'), findsNothing);
    });

    testWidgets('LanguageSelectorSheet opens as spotlight on Linux and dismisses on Escape key', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  LanguageSelectorSheet.show(ctx);
                },
                child: const Text('Open Languages'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Languages'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelectorSheet), findsOneWidget);

      // Press Escape
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(LanguageSelectorSheet), findsNothing);
    });

    testWidgets('LanguageSelectorSheet opens as BottomSheet on Android', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  LanguageSelectorSheet.show(ctx);
                },
                child: const Text('Open Languages'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Languages'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(LanguageSelectorSheet), findsOneWidget);
    });

    testWidgets('MoodPickerSheet opens adaptively on Linux and selects mood level', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      int? pickedMood;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  MoodPickerSheet.show(
                    context: ctx,
                    currentMood: null,
                    onMoodSelected: (m) => pickedMood = m,
                    onMoodCleared: () {},
                  );
                },
                child: const Text('Open Moods'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Moods'));
      await tester.pumpAndSettle();

      expect(find.text('Record Mood'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Tap mood level 8
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      expect(pickedMood, 8);
      expect(find.text('Record Mood'), findsNothing);
    });

    testWidgets('MomentPickerSheet opens adaptively on Linux and selects moment', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      String? pickedMoment;

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  MomentPickerSheet.show(
                    context: ctx,
                    currentMoment: null,
                    onMomentSelected: (m) => pickedMoment = m,
                    onMomentCleared: () {},
                  );
                },
                child: const Text('Open Moments'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Moments'));
      await tester.pumpAndSettle();

      expect(find.text('Select Moment'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Tap Ordinary
      await tester.tap(find.text('Ordinary'));
      await tester.pumpAndSettle();

      expect(pickedMoment, 'ordinary');
      expect(find.text('Select Moment'), findsNothing);
    });
  });
}
