import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/features/journal/application/journal_providers.dart';
import 'package:quitepaper/features/journal/presentation/on_this_day_view.dart';
import 'package:quitepaper/features/notes/application/notes_provider.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late DriftNotesRepository repository;
  setUp(() {
    db = AppDatabase.memory();
    repository = DriftNotesRepository(db);
  });
  tearDown(() => db.close());

  test('earliest year and pagination react to add, Trash, restore and delete', () async {
    await repository.getOrCreateJournalEntry(DateTime(2025, 11, 24));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repository),
      historicalReferenceDateProvider.overrideWithValue(DateTime(2026, 11, 24)),
    ]);
    addTearDown(container.dispose);
    container.listen(historicalWeekProvider, (_, _) {});
    await container.read(earliestJournalYearStreamProvider.future);
    await container.read(historicalWeekNotesStreamProvider.future);
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isFalse);
    final older = await repository.getOrCreateJournalEntry(DateTime(2010, 5, 1));
    await pumpEventQueue();
    expect(container.read(earliestJournalYearStreamProvider).value, 2010);
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isTrue);
    await repository.trashNote(older.id);
    await pumpEventQueue();
    expect(container.read(earliestJournalYearStreamProvider).value, 2025);
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isFalse);
    await repository.restoreFromTrash(older.id);
    await pumpEventQueue();
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isTrue);
    await repository.deletePermanently(older.id);
    await pumpEventQueue();
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isFalse);
  });

  testWidgets('older backfill reveals the load control and can be loaded without restart', (tester) async {
    await repository.getOrCreateJournalEntry(DateTime(2025, 11, 24));
    await tester.pumpWidget(ProviderScope(overrides: [
      databaseProvider.overrideWithValue(db),
      notesRepositoryProvider.overrideWithValue(repository),
      historicalReferenceDateProvider.overrideWithValue(DateTime(2026, 11, 24)),
    ], child: const MaterialApp(home: OnThisDayView())));
    await tester.pumpAndSettle();
    expect(find.text('Show older memories'), findsNothing);
    final older = await repository.getOrCreateJournalEntry(DateTime(2010, 11, 23));
    await repository.saveNote(older.copyWith(title: 'Paper diary memory'));
    await tester.pumpAndSettle();
    expect(find.text('Show older memories'), findsOneWidget);
    for (var batch = 0; batch < 3; batch++) {
      await tester.ensureVisible(find.text('Show older memories'));
      await tester.tap(find.text('Show older memories'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Paper diary memory'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(OnThisDayView)));
    expect(container.read(historicalWeekProvider).hasMoreOlderYears, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
