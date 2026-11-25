import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/journal/presentation/widgets/journal_month_year_picker.dart';

void main() {
  for (final size in [const Size(640, 320), const Size(360, 640)]) {
    testWidgets('picker controls remain reachable at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      (int, int)? selected;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(
        builder: (context) => TextButton(
          onPressed: () => JournalMonthYearPicker.show(context,
            initialYear: 2026, initialMonth: 11,
            onMonthSelected: (year, month) => selected = (year, month)),
          child: const Text('Open picker'),
        ),
      ))));
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous year'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      final scrollable = find.descendant(
        of: find.byType(JournalMonthYearPicker),
        matching: find.byType(Scrollable),
      ).first;
      await tester.scrollUntilVisible(find.text('December'), 80,
        scrollable: scrollable);
      await tester.tap(find.text('December'));
      await tester.pumpAndSettle();
      expect(selected, (2025, 12));
      expect(find.byType(JournalMonthYearPicker), findsNothing);
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Current Month'), 80,
        scrollable: scrollable);
      await tester.tap(find.text('Current Month'));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      expect(selected, (now.year, now.month));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Cancel'), 80,
        scrollable: scrollable);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalMonthYearPicker), findsNothing);
    });
  }
}
