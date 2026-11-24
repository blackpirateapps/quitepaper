import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_day_clock.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/on_this_day_view.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  testWidgets(
    'midnight refreshes Today, memories queries and the visible heading',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repository = DriftNotesRepository(db);
      final oldToday = await repository.getOrCreateJournalEntry(
        DateTime(2026, 11, 24),
      );
      final newToday = await repository.getOrCreateJournalEntry(
        DateTime(2026, 11, 25),
      );
      await repository.getOrCreateJournalEntry(DateTime(2025, 11, 24));
      await repository.getOrCreateJournalEntry(DateTime(2025, 11, 25));
      var now = DateTime(2026, 11, 24, 23, 59, 59);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            notesRepositoryProvider.overrideWithValue(repository),
            sharedPreferencesProvider.overrideWithValue(prefs),
            journalNowProvider.overrideWithValue(() => now),
            historicalWeekNotesStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            earliestJournalYearFutureProvider.overrideWith(
              (ref) => Future.value(null),
            ),
          ],
          child: const MaterialApp(home: OnThisDayView()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnThisDayView)),
      );
      final subscription = container.listen(
        todayJournalEntryStreamProvider,
        (_, _) {},
      );
      expect(
        (await container.read(todayJournalEntryStreamProvider.future))!.id,
        oldToday.id,
      );
      expect(find.text('November 24'), findsOneWidget);
      expect(find.text('November 24, 2025'), findsNWidgets(2));
      now = DateTime(2026, 11, 25, 0, 0, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(container.read(todayJournalDateProvider), '2026-11-25');
      expect(
        (await container.read(todayJournalEntryStreamProvider.future))!.id,
        newToday.id,
      );
      expect(
        container.read(historicalReferenceDateProvider),
        DateTime(2026, 11, 25),
      );
      expect(find.text('November 25'), findsOneWidget);
      expect(find.text('November 25, 2025'), findsNWidgets(2));
      expect(find.text('November 24, 2025'), findsNothing);
      subscription.close();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'resume refreshes forward and backward dates and year boundaries',
    (tester) async {
      var now = DateTime(2026, 12, 31, 12);
      final container = ProviderContainer(
        overrides: [journalNowProvider.overrideWithValue(() => now)],
      );
      expect(container.read(todayJournalDateProvider), '2026-12-31');
      for (final next in [DateTime(2027, 1, 1), DateTime(2026, 12, 30)]) {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        now = next;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(container.read(historicalReferenceDateProvider), next);
        expect(
          container.read(historicalWeekQueryDescriptorProvider).referenceYear,
          next.year,
        );
        expect(
          container.read(todayJournalDateProvider),
          next == DateTime(2027, 1, 1) ? '2027-01-01' : '2026-12-30',
        );
      }
      container.dispose();
      await tester.pump(const Duration(days: 2));
    },
  );

  testWidgets('midnight timer reschedules across leap day and is disposed', (
    tester,
  ) async {
    var now = DateTime(2028, 2, 28, 23, 59, 59);
    final container = ProviderContainer(
      overrides: [journalNowProvider.overrideWithValue(() => now)],
    );
    expect(container.read(todayJournalDateProvider), '2028-02-28');
    now = DateTime(2028, 2, 29);
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(todayJournalDateProvider), '2028-02-29');
    now = DateTime(2028, 3, 1);
    await tester.pump(const Duration(days: 1));
    expect(container.read(todayJournalDateProvider), '2028-03-01');
    container.dispose();
    await tester.pump(const Duration(days: 1));
  });
  testWidgets('next midnight uses local calendar time across a DST day', (
    tester,
  ) async {
    var now = DateTime(2026, 3, 8);
    final untilMidnight = DateTime(2026, 3, 9).difference(now);
    final container = ProviderContainer(
      overrides: [journalNowProvider.overrideWithValue(() => now)],
    );
    expect(container.read(todayJournalDateProvider), '2026-03-08');
    now = DateTime(2026, 3, 9);
    await tester.pump(untilMidnight - const Duration(microseconds: 1));
    expect(container.read(todayJournalDateProvider), '2026-03-08');
    await tester.pump(const Duration(microseconds: 1));
    expect(container.read(todayJournalDateProvider), '2026-03-09');
    container.dispose();
  });
}
