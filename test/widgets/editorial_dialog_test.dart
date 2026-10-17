import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/core/maintenance/maintenance_models.dart';
import 'package:quitepaper/core/widgets/quiet_adaptive_modal.dart';
import 'package:quitepaper/core/widgets/quiet_editorial_dialog.dart';
import 'package:quitepaper/features/notes/presentation/widgets/notes_sort_sheet.dart';
import 'package:quitepaper/features/notes/presentation/widgets/saved_filters_sheet.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:quitepaper/features/settings/presentation/widgets/maintenance_progress_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({
    required Widget child,
    TargetPlatform platform = TargetPlatform.linux,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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

  group('Phase 4: Centered Editorial Dialogs Migration', () {
    testWidgets('QuietAdaptiveModal.show with AdaptiveModalType.dialog renders card dialog on Linux and closes with Escape', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show(
                    context: ctx,
                    type: AdaptiveModalType.dialog,
                    title: 'Editorial Test Dialog',
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Dialog Content Body'),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Editorial Test Dialog'), findsOneWidget);
      expect(find.text('Dialog Content Body'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Press escape to dismiss
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('Editorial Test Dialog'), findsNothing);
    });

    testWidgets('QuietAdaptiveModal.show with AdaptiveModalType.dialog renders BottomSheet on Android', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.android,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  QuietAdaptiveModal.show(
                    context: ctx,
                    type: AdaptiveModalType.dialog,
                    title: 'Mobile Dialog Test',
                    builder: (_) => const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Mobile Bottom Sheet Body'),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Mobile Bottom Sheet Body'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsNothing);
    });

    testWidgets('NotesSortSheet renders as dialog on Linux without BottomSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => NotesSortSheet.show(ctx),
                child: const Text('Open Sort Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sort Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Sort Notes'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      // Close button inside sort sheet dismisses
      await tester.tap(find.byTooltip('Close sort menu'));
      await tester.pumpAndSettle();

      expect(find.text('Sort Notes'), findsNothing);
    });

    testWidgets('SavedFiltersSheet renders as dialog on Linux and closes properly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => SavedFiltersSheet.show(ctx),
                child: const Text('Open Saved Filters'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Saved Filters'));
      await tester.pumpAndSettle();

      expect(find.text('SAVED SMART VIEWS'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.tap(find.byTooltip('Close smart views'));
      await tester.pumpAndSettle();

      expect(find.text('SAVED SMART VIEWS'), findsNothing);
    });

    testWidgets('MaintenanceProgressSheet opens on Linux as modal dialog with barrierDismissible: false', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestApp(
          platform: TargetPlatform.linux,
          child: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () {
                  MaintenanceProgressSheet.show(
                    ctx,
                    taskType: MaintenanceTaskType.rebuildSearchIndex,
                  );
                },
                child: const Text('Start Maintenance'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Maintenance'));
      await tester.pump();

      expect(find.text('Rebuilding Search Index'), findsOneWidget);
      expect(find.byType(QuietEditorialDialogCard), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });
  });
}
