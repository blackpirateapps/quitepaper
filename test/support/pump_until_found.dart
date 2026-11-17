import 'package:flutter_test/flutter_test.dart';

/// Pumps frames while allowing real file/database/isolate work to complete.
///
/// Unlike pumpAndSettle, this can wait through an animated progress indicator.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final elapsed = Stopwatch()..start();
  const interval = Duration(milliseconds: 20);
  while (finder.evaluate().isEmpty && elapsed.elapsed < timeout) {
    await tester.runAsync(() => Future<void>.delayed(interval));
    await tester.pump(interval);
  }
  expect(
    finder,
    findsWidgets,
    reason: 'Expected UI did not appear within $timeout',
  );
}
