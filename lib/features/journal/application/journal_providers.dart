import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import 'journal_service.dart';

/// Provider for JournalService
final journalServiceProvider = Provider<JournalService>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  return JournalService(repository);
});

/// Current local calendar date for journal operations (YYYY-MM-DD)
final todayJournalDateProvider = Provider<String>((ref) {
  return JournalDateHelper.todayString();
});

/// Watches today's journal entry. Emits null if today's entry does not exist yet.
/// Note: Watching this provider does NOT create today's entry!
final todayJournalEntryStreamProvider = StreamProvider<Note?>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final todayDate = ref.watch(todayJournalDateProvider);
  return repository.watchJournalEntry(todayDate);
});

/// Whether today's journal entry currently exists and is active.
final hasTodayJournalEntryProvider = Provider<bool>((ref) {
  final entry = ref.watch(todayJournalEntryStreamProvider).valueOrNull;
  return entry != null && !entry.isTrashed;
});

/// Watches On This Day entries (matching today's month and day from previous years).
final onThisDayEntriesStreamProvider = StreamProvider<List<Note>>((ref) {
  final repository = ref.watch(notesRepositoryProvider);
  final now = DateTime.now();
  final localNow = JournalDateHelper.toLocalDate(now);

  return repository.watchOnThisDayEntries(
    month: localNow.month,
    day: localNow.day,
    beforeYear: localNow.year,
  );
});
