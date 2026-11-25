import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/presentation/task_edit_sheet.dart';
import 'package:quitepaper/features/tasks/presentation/task_tag_filter.dart';

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  Widget app(Widget child, {bool desktop = false}) => MaterialApp(
    theme: ThemeData(
      platform: desktop ? TargetPlatform.linux : TargetPlatform.android,
      extensions: [AppColors.light],
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.4)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );

  testWidgets(
    'tag filter remains usable above keyboard with large text and retains hidden selections',
    (tester) async {
      phone(tester);
      Set<String>? result;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showTaskTagFilter(
                  context,
                  available: const ['work/client', 'home'],
                  selected: const {'home'},
                );
              },
              child: const Text('Filter'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'client');
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('task-filter-tag-work/client')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.text('Apply')).dy,
        lessThanOrEqualTo(544),
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result, {'work/client', 'home'});
    },
  );

  testWidgets('rename failure retains draft and allows retry above keyboard', (
    tester,
  ) async {
    phone(tester);
    var attempts = 0;
    TaskCommit? result;
    final note = Note(
      id: 'n',
      title: 'Source',
      content: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showTaskRename(
                context,
                text: 'Original',
                onSave: (text) async {
                  attempts++;
                  if (attempts == 1) {
                    throw const StaleTask('Could not save. Try again.');
                  }
                  return TaskCommit(note, TaskUndo(() async {}));
                },
              );
            },
            child: const Text('Rename'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Retained draft');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Retained draft',
    );
    expect(result, isNull);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(result, isNotNull);
  });

  testWidgets(
    'desktop empty tag picker uses a compact dialog and explains missing tags',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showTaskTagFilter(
                context,
                available: const [],
                selected: const {},
              ),
              child: const Text('Filter'),
            ),
          ),
          desktop: true,
        ),
      );
      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.text('Add tags to your task notes to filter them here.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
