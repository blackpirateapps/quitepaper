import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ocr/ocr_provider.dart';
import '../../../core/search/fuzzy_search_engine.dart';
import '../../../core/search/search_worker.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../domain/search_result.dart';

export '../domain/search_result.dart';

/// Provider for active search filter chip (All, Notes, Documents, Tags)
final searchFilterProvider = StateProvider<SearchFilter>((ref) => SearchFilter.all);

/// Monotonic generation ID for search race condition protection
int _latestSearchRequestId = 0;

/// Reactive provider yielding unified notes, documents, and OCR search results
/// using two-tier FTS5 candidate retrieval and background isolate evaluation.
final globalSearchResultsProvider = StreamProvider<GlobalSearchResults>((ref) async* {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    yield const GlobalSearchResults(query: '');
    return;
  }

  final currentRequestId = ++_latestSearchRequestId;
  final db = ref.watch(databaseProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);

  // 1. Deterministic query compilation
  final compiledQuery = SearchTokenizer.compileQuery(query);
  if (compiledQuery.isEmpty) {
    yield const GlobalSearchResults(query: '');
    return;
  }

  // 2. Tier 1: Candidate retrieval via SQLite FTS5 (prefix + trigram) and Decrypted OCR
  final candidateNoteIds = await db.searchNoteCandidateIds(compiledQuery, limit: 200);
  final ocrCandidates = await ocrSearchService.getOcrPageCandidates();

  // Pre-fetch parent notes of OCR candidates so they are evaluated and surfaced in note matches
  final ocrParentNoteIds = ocrCandidates
      .map((c) => c.parentNoteId)
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet();

  final allCandidateNoteIds = {...candidateNoteIds, ...ocrParentNoteIds}.toList();
  final noteCandidates = await db.getSearchCandidatesByIds(allCandidateNoteIds);

  // 3. Tier 2: Background Isolate scoring, highlighting, and snippet generation
  final isolateRequest = SearchIsolateRequest(
    requestId: currentRequestId,
    rawQuery: query,
    noteCandidates: noteCandidates,
    ocrCandidates: ocrCandidates,
  );

  final isolateResponse = await Isolate.run(() => searchIsolateWorker(isolateRequest));

  // 4. Race condition protection: discard if superseded by a newer query
  if (isolateResponse.requestId != _latestSearchRequestId) {
    return;
  }

  // 5. Hydrate Note domain models
  final noteMatches = <NoteSearchMatch>[];
  if (isolateResponse.noteMatches.isNotEmpty) {
    final matchedIds = isolateResponse.noteMatches.map((m) => m.noteId).toList();
    final noteEntities = await (db.select(db.notesTable)
          ..where((n) => n.id.isIn(matchedIds) & n.isTrashed.equals(false)))
        .get();
    final tagsMap = await db.getTagsForNoteIds(matchedIds);

    final notesById = <String, Note>{};
    for (final entity in noteEntities) {
      final tags = (tagsMap[entity.id] ?? []).map((t) => t.name).toList();
      notesById[entity.id] = Note(
        id: entity.id,
        title: entity.title,
        content: entity.content,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
        isPinned: entity.isPinned,
        isArchived: entity.isArchived,
        isTrashed: entity.isTrashed,
        deletedAt: entity.deletedAt,
        tags: tags,
      );
    }

    for (final matchDto in isolateResponse.noteMatches) {
      final note = notesById[matchDto.noteId];
      if (note != null) {
        noteMatches.add(
          NoteSearchMatch(
            note: note,
            matchedSnippet: matchDto.snippet,
            titleHighlightSpans: matchDto.titleHighlightSpans,
            snippetHighlightSpans: matchDto.snippetHighlightSpans,
            matchedInTitle: matchDto.matchedInTitle,
            matchedInContent: matchDto.matchedInContent,
            matchedInTags: matchDto.matchedInTags,
            matchedInOcr: matchDto.matchedInOcr,
            isFuzzy: matchDto.isFuzzy,
            matchedTokensCount: matchDto.matchedTokensCount,
            score: matchDto.score,
          ),
        );
      }
    }
  }

  // 6. Hydrate Document and Image Attachment domain models
  final documentMatches = <DocumentSearchMatch>[];
  if (isolateResponse.documentMatches.isNotEmpty) {
    final docIds = isolateResponse.documentMatches
        .where((m) => !m.isAttachment)
        .map((m) => m.documentId)
        .toList();
    final attIds = isolateResponse.documentMatches
        .where((m) => m.isAttachment)
        .map((m) => m.attachmentId ?? m.documentId)
        .toList();

    final docsById = <String, DocumentEntity>{};
    if (docIds.isNotEmpty) {
      final docEntities = await (db.select(db.documentsTable)
            ..where((d) => d.id.isIn(docIds) & d.isDeleted.equals(false)))
          .get();
      for (final doc in docEntities) {
        docsById[doc.id] = doc;
      }
    }

    final attachmentsById = <String, AttachmentEntity>{};
    if (attIds.isNotEmpty) {
      final attEntities = await (db.select(db.attachmentsTable)
            ..where((a) => a.id.isIn(attIds) & a.isDeleted.equals(false)))
          .get();
      for (final att in attEntities) {
        attachmentsById[att.id] = att;
      }
    }

    for (final matchDto in isolateResponse.documentMatches) {
      if (matchDto.isAttachment) {
        final attId = matchDto.attachmentId ?? matchDto.documentId;
        final attEntity = attachmentsById[attId];
        if (attEntity != null) {
          documentMatches.add(
            DocumentSearchMatch(
              attachment: attEntity,
              title: 'Image Attachment',
              parentNoteTitle: matchDto.parentNoteTitle,
              parentNoteId: matchDto.parentNoteId,
              matchedPageNumber: matchDto.matchedPageNumber,
              snippet: matchDto.snippet,
              snippetHighlightSpans: matchDto.snippetHighlightSpans,
              titleHighlightSpans: matchDto.titleHighlightSpans,
              isOcrMatch: matchDto.isOcrMatch,
              isFuzzy: matchDto.isFuzzy,
              matchedTokensCount: matchDto.matchedTokensCount,
              score: matchDto.score,
            ),
          );
        }
      } else {
        final docEntity = docsById[matchDto.documentId];
        if (docEntity != null) {
          documentMatches.add(
            DocumentSearchMatch(
              document: docEntity,
              title: docEntity.title,
              parentNoteTitle: matchDto.parentNoteTitle,
              parentNoteId: matchDto.parentNoteId,
              matchedPageNumber: matchDto.matchedPageNumber,
              snippet: matchDto.snippet,
              snippetHighlightSpans: matchDto.snippetHighlightSpans,
              titleHighlightSpans: matchDto.titleHighlightSpans,
              isOcrMatch: matchDto.isOcrMatch,
              isFuzzy: matchDto.isFuzzy,
              matchedTokensCount: matchDto.matchedTokensCount,
              score: matchDto.score,
            ),
          );
        }
      }
    }
  }

  // 7. Query matching tags
  final allTags = await notesRepo.getAllTagNames();
  final matchingTags = <String>[];
  for (final tag in allTags) {
    final tagEval = FuzzySearchEngine.evaluate(
      query: query,
      text: tag,
      isTag: true,
    );
    if (tagEval.hasMatch) {
      matchingTags.add(tag);
    }
  }

  yield GlobalSearchResults(
    query: query,
    noteMatches: noteMatches,
    documentMatches: documentMatches,
    matchingTags: matchingTags,
  );
});
