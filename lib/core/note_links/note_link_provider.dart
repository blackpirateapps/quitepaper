import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../../features/notes/application/notes_provider.dart';
import 'note_link_models.dart';
import 'note_link_search_service.dart';

/// Provider for the [NoteLinkSearchService].
final noteLinkSearchServiceProvider = Provider<NoteLinkSearchService>((ref) {
  final db = ref.watch(databaseProvider);
  return NoteLinkSearchService(db);
});

/// Reactive stream provider for backlinks pointing to a given [noteId].
final backlinksForNoteProvider = StreamProvider.family<List<BacklinkItem>, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.watchBacklinksForNote(noteId);
});

/// Reactive stream provider for outgoing links originating from a given [noteId].
final outgoingLinksForNoteProvider = StreamProvider.family<List<NoteLinkEntity>, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.watchOutgoingLinksForNote(noteId);
});
