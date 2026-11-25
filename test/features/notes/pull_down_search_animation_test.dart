import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/presentation/widgets/pull_down_search_reveal.dart';

void main() {
  late GlobalKey<PullDownSearchRevealState> reveal;
  late ScrollController scroll;
  late int opened;
  const card = ValueKey('notes-card');

  setUp(() {
    reveal = GlobalKey<PullDownSearchRevealState>();
    scroll = ScrollController();
    opened = 0;
  });

  tearDown(() => scroll.dispose());

  Future<void> mount(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PullDownSearchReveal(
          key: reveal,
          enabled: enabled,
          onOpenSearch: () => opened++,
          searchViewBuilder: (_, _, close) => Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: TextButton(onPressed: close, child: const Text('Back')),
            ),
          ),
          child: ColoredBox(
            key: card,
            color: Colors.white,
            child: ListView.builder(
              controller: scroll,
              physics: PullDownSearchScrollPhysics(
                revealState: () => reveal.currentState,
                parent: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
              ),
              itemExtent: 50,
              itemCount: 40,
              itemBuilder: (_, i) => Text('Note $i'),
            ),
          ),
        ),
      ),
    );
  }

  Future<TestGesture> pull(WidgetTester tester, double distance) async {
    final gesture = await tester.startGesture(const Offset(250, 180));
    // Cross gesture slop first, then measure actual reveal movement.
    await gesture.moveBy(const Offset(0, 25));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(Offset(0, distance / 5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    return gesture;
  }

  testWidgets('pull moves the card once and commits at finger release', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await pull(tester, 200);
    final offset = reveal.currentState!.pullOffset;
    expect(offset, greaterThanOrEqualTo(200));
    expect(scroll.offset, 0, reason: 'The list must not also rubber-band');
    expect(tester.getTopLeft(find.byKey(card)).dy, closeTo(offset, .01));
    await gesture.up();
    await tester.pump();
    expect(reveal.currentState!.isSearchActive, isTrue);
    expect(reveal.currentState!.isSearchReady, isFalse);
    expect(opened, 1);
    await tester.pumpAndSettle();
    expect(reveal.currentState!.isSearchReady, isTrue);
    expect(scroll.offset, 0);
  });

  testWidgets('upward reversal consumes pull before scrolling notes', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await pull(tester, 220);
    final before = reveal.currentState!.pullOffset;
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(reveal.currentState!.pullOffset, closeTo(before - 180, .01));
    expect(scroll.offset, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(tester.getTopLeft(find.byKey(card)).dy, 0);
    expect(scroll.offset, 0);
  });

  testWidgets('canceling a pointer above threshold restores the list', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await pull(tester, 220);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(reveal.currentState!.isSearchActive, isFalse);
    expect(reveal.currentState!.pullOffset, 0);
    expect(scroll.offset, 0);
  });

  testWidgets('Back reverses opening from its current position', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await pull(tester, 220);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final before = tester.getTopLeft(find.byKey(card)).dy;
    reveal.currentState!.closeSearch();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(card)).dy, closeTo(before, .01));
    await tester.pump(const Duration(milliseconds: 40));
    expect(tester.getTopLeft(find.byKey(card)).dy, lessThan(before));
    await tester.pumpAndSettle();
    expect(reveal.currentState!.isSearchActive, isFalse);
    expect(tester.getTopLeft(find.byKey(card)).dy, 0);
  });

  testWidgets('system Back dismisses inline search', (tester) async {
    await mount(tester);
    reveal.currentState!.openSearch(animate: false);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(reveal.currentState!.isSearchActive, isFalse);
    expect(tester.getTopLeft(find.byKey(card)).dy, 0);
  });

  testWidgets('toolbar opening during spring-back preserves card position', (
    tester,
  ) async {
    await mount(tester);
    final gesture = await pull(tester, 60);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final before = tester.getTopLeft(find.byKey(card)).dy;
    expect(before, greaterThan(0));
    reveal.currentState!.openSearch();
    await tester.pump();
    expect(tester.getTopLeft(find.byKey(card)).dy, closeTo(before, .01));
    await tester.pumpAndSettle();
    expect(reveal.currentState!.isSearchReady, isTrue);
    expect(opened, 1);
  });

  testWidgets(
    'opening during closing preserves position and accepts later Back',
    (tester) async {
      await mount(tester);
      reveal.currentState!.openSearch(animate: false);
      await tester.pump();
      reveal.currentState!.closeSearch();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final before = tester.getTopLeft(find.byKey(card)).dy;
      reveal.currentState!.openSearch();
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(card)).dy, closeTo(before, .01));
      await tester.pumpAndSettle();
      expect(reveal.currentState!.isSearchReady, isTrue);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(reveal.currentState!.isSearchActive, isFalse);
    },
  );

  testWidgets('mid-list flings retain normal scrolling without arming search', (
    tester,
  ) async {
    await mount(tester);
    scroll.jumpTo(300);
    await tester.pump();
    await tester.fling(find.byKey(card), const Offset(0, 400), 1400);
    await tester.pumpAndSettle();
    expect(opened, 0);
    expect(reveal.currentState!.pullOffset, 0);
  });
}
