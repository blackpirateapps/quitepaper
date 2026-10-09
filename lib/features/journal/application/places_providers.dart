import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/journal/application/place_grouping_service.dart';
import '../../../core/journal/domain/journal_date_helper.dart';
import '../../../core/journal/domain/journal_place.dart';
import '../../notes/domain/note_metadata_extractor.dart';
import '../../notes/domain/note_model.dart';
import '../domain/journal_visit.dart';
import 'journal_providers.dart';
import 'place_alias_store.dart';

/// User-selected grouping lens for the Places surface (default: city).
final placeGranularityProvider =
    StateProvider<PlaceGranularity>((ref) => PlaceGranularity.city);

/// User-selected ordering for the Places list (default: recency).
final placeSortOrderProvider =
    StateProvider<PlaceSortOrder>((ref) => PlaceSortOrder.recency);

/// Grouped list of [JournalPlace]s for the Places page.
///
/// Reads active, non-locked journal notes from [allJournalEntriesStreamProvider]
/// (empty while loading), reduces each located entry to a [PlaceEntryInput] via
/// cached [NoteMetadata], and defers all grouping to [PlaceGroupingService].
/// Entries with no location are **silently excluded** (§6.4) — never bucketed.
final placeListProvider = Provider<List<JournalPlace>>((ref) {
  final notes =
      ref.watch(allJournalEntriesStreamProvider).valueOrNull ?? const <Note>[];
  final granularity = ref.watch(placeGranularityProvider);
  final sortOrder = ref.watch(placeSortOrderProvider);
  final aliases = ref.watch(placeAliasStoreProvider);

  return const PlaceGroupingService().group(
    _buildInputs(notes),
    granularity: granularity,
    aliases: aliases,
    sortOrder: sortOrder,
  );
});

/// The member notes of the place identified by [matchKey], reverse-chronological.
///
/// Recomputes the grouping at the current granularity + alias map to locate the
/// place, then maps its member ids back to [Note]s from the entries stream.
final placeEntriesProvider = Provider.family<List<Note>, String>((ref, matchKey) {
  final notes =
      ref.watch(allJournalEntriesStreamProvider).valueOrNull ?? const <Note>[];
  final granularity = ref.watch(placeGranularityProvider);
  final aliases = ref.watch(placeAliasStoreProvider);

  final places = const PlaceGroupingService().group(
    _buildInputs(notes),
    granularity: granularity,
    aliases: aliases,
    // Order of the place list is irrelevant for a single-place lookup.
    sortOrder: PlaceSortOrder.recency,
  );

  JournalPlace? match;
  for (final place in places) {
    if (place.matchKey == matchKey) {
      match = place;
      break;
    }
  }
  if (match == null) return const <Note>[];

  final byId = {for (final note in notes) note.id: note};
  final members = <Note>[];
  for (final id in match.noteIds) {
    final note = byId[id];
    if (note != null) members.add(note);
  }

  members.sort((a, b) {
    final cmp = _dateOf(b).compareTo(_dateOf(a)); // reverse-chronological
    if (cmp != 0) return cmp;
    return b.id.compareTo(a.id);
  });
  return members;
});

/// Visit sub-groups (§6.3) for the place identified by [matchKey], newest first.
final placeVisitsProvider =
    Provider.family<List<JournalVisit>, String>((ref, matchKey) {
  final notes = ref.watch(placeEntriesProvider(matchKey));
  return clusterVisits(notes);
});

/// Reduces active, non-locked, located notes into grouping inputs. Unlocated
/// and locked notes are skipped silently (§6.4 / §8).
List<PlaceEntryInput> _buildInputs(List<Note> notes) {
  final inputs = <PlaceEntryInput>[];
  for (final note in notes) {
    if (!note.isActive || note.isPasswordProtected) continue;
    final location = NoteMetadataExtractor.extract(note).location;
    if (location == null) continue; // silent exclusion — never bucketed
    inputs.add(
      PlaceEntryInput(
        noteId: note.id,
        location: location,
        date: _dateOf(note),
      ),
    );
  }
  return inputs;
}

/// Resolves a note's grouping date: its journal date when valid, else createdAt.
DateTime _dateOf(Note note) =>
    JournalDateHelper.tryParseDateString(note.journalDate) ??
    JournalDateHelper.toLocalDate(note.createdAt);
