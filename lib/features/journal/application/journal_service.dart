import 'package:flutter/material.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../../../core/journal/domain/journal_date_helper.dart';

class JournalService {
  const JournalService(this._repository);

  final NotesRepository _repository;

  /// Retrieves today's journal entry if it exists, or creates it atomically.
  Future<Note> getOrCreateToday([DateTime? now]) {
    return getOrCreateForDate(now ?? DateTime.now());
  }

  /// Retrieves the journal entry for [date] if it exists, or creates it atomically.
  ///
  /// Works for any calendar date (including historical dates backfilled from paper
  /// diaries). Ordering across the journal is keyed off the `date` frontmatter
  /// property, so the created note's `createdAt` stays the real transcription time.
  Future<Note> getOrCreateForDate(DateTime date) {
    return _repository.getOrCreateJournalEntry(date);
  }

  /// Retrieves the journal entry for a specific calendar date (null if not found).
  Future<Note?> getJournalEntryForDate(DateTime date) {
    final dateStr = JournalDateHelper.toDateString(date);
    return _repository.getJournalEntry(dateStr);
  }

  /// Retrieves the set of calendar date strings (YYYY-MM-DD) for active journal entries in a month.
  Future<Set<String>> getJournalDatesForMonth(int year, int month) {
    return _repository.getJournalDatesForMonth(year, month);
  }

  /// Watches the set of calendar date strings (YYYY-MM-DD) for active journal entries in a month.
  Stream<Set<String>> watchJournalDatesForMonth(int year, int month) {
    return _repository.watchJournalDatesForMonth(year, month);
  }

  /// Retrieves all active journal entries ordered chronologically.
  Future<List<Note>> getAllJournalEntries() {
    return _repository.getAllJournalEntries();
  }

  /// Watches all active journal entries ordered chronologically.
  Stream<List<Note>> watchAllJournalEntries() {
    return _repository.watchAllJournalEntries();
  }

  /// Fetches historical journal entries for On This Day.
  Future<List<Note>> getOnThisDayEntries([DateTime? now]) {
    final reference = JournalDateHelper.toLocalDate(now ?? DateTime.now());
    return _repository.getOnThisDayEntries(
      month: reference.month,
      day: reference.day,
      beforeYear: reference.year,
    );
  }

  /// Opens today's journal entry in the editor, creating it first if it doesn't exist yet.
  Future<Note> openOrCreateTodayFlow(
    BuildContext context, {
    bool isTablet = false,
    void Function(Note note)? onTabletSelectNote,
  }) {
    return openOrCreateEntryFlow(
      context,
      DateTime.now(),
      isTablet: isTablet,
      onTabletSelectNote: onTabletSelectNote,
    );
  }

  /// Opens the journal entry for [date] in the editor, creating it first if it
  /// doesn't exist yet. Used for both Today and backfilling historical entries.
  Future<Note> openOrCreateEntryFlow(
    BuildContext context,
    DateTime date, {
    bool isTablet = false,
    void Function(Note note)? onTabletSelectNote,
  }) async {
    final note = await getOrCreateForDate(date);

    if (!context.mounted) return note;

    if (note.isTrashed) {
      final dateLabel = JournalDateHelper.formatDisplayDate(date);
      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text('$dateLabel is in Trash'),
            content: Text(
              'The journal entry for $dateLabel was moved to Trash. Would you like to restore it to continue writing?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Restore & Open'),
              ),
            ],
          );
        },
      );

      if (shouldRestore == true) {
        await _repository.restoreFromTrash(note.id);
        final restored = await _repository.getNoteById(note.id);
        if (restored != null && context.mounted) {
          _navigateToEditor(context, restored, isTablet: isTablet, onTabletSelectNote: onTabletSelectNote);
          return restored;
        }
      }
      return note;
    }

    _navigateToEditor(context, note, isTablet: isTablet, onTabletSelectNote: onTabletSelectNote);
    return note;
  }

  void _navigateToEditor(
    BuildContext context,
    Note note, {
    bool isTablet = false,
    void Function(Note note)? onTabletSelectNote,
  }) {
    if (isTablet && onTabletSelectNote != null) {
      onTabletSelectNote(note);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(note: note),
        ),
      );
    }
  }
}
