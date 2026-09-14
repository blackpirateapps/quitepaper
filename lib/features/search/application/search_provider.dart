import 'dart:isolate';
import 'dart:math';
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
/// using a progressive 3-tier pipeline:
/// Tier 1: Instant Titles & Tags (~5ms)
/// Tier 2: Fast Body Content via background isolate (~50-200ms)
/// Tier 3: Complete Scanned Documents & Image OCR (~200-500ms)
final globalSearchResultsProvider = StreamProvider<GlobalSearchResults>((ref) async* {
  final query = ref.watch(searchQueryProvider).trim();
  if (query.isEmpty) {
    yield const GlobalSearchResults(query: '', searchPhase: SearchPhase.complete);
    return;
  }

  final currentRequestId = ++_latestSearchRequestId;
  final db = ref.watch(databaseProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);
  final notesRepo = ref.watch(notesRepositoryProvider);

  // 1. Deterministic query compilation
  final compiledQuery = SearchTokenizer.compileQuery(query);
  if (compiledQuery.isEmpty) {
    yield const GlobalSearchResults(query: '', searchPhase: SearchPhase.complete);
    return;
  }

  // ════════════════════════════════════════════════════════════════
  // TIER 1: Instant Title & Tag Search (~5ms)
  // ════════════════════════════════════════════════════════════════
  final candidateNoteIds = await db.searchNoteCandidateIds(compiledQuery, limit: 200);
  if (currentRequestId != _latestSearchRequestId) return;

  // Retrieve lightweight candidates (title + tags only; body omitted for 0ms memory footprint)
  final lightCandidates = await db.getSearchCandidatesLightweight(candidateNoteIds);
  if (currentRequestId != _latestSearchRequestId) return;

  // Instant evaluate titles and tags in-memory
  final phase1NoteMatches = await _evaluateAndHydratePhase1(
    db: db,
    candidates: lightCandidates,
    compiledQuery: compiledQuery,
    rawQuery: query,
  );
  if (currentRequestId != _latestSearchRequestId) return;

  // Query matching tag names
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

  // Yield Phase 1: Instant feedback to the user
  yield GlobalSearchResults(
    query: query,
    noteMatches: phase1NoteMatches,
    documentMatches: const [],
    matchingTags: matchingTags,
    searchPhase: SearchPhase.titlesAndTags,
  );

  // ════════════════════════════════════════════════════════════════
  // TIER 2: Fast Body Content Search via Background Isolate (~50-200ms)
  // ════════════════════════════════════════════════════════════════
  final fullNoteCandidates = await db.getSearchCandidatesByIds(candidateNoteIds);
  if (currentRequestId != _latestSearchRequestId) return;

  List<NoteSearchMatch> phase2NoteMatches = phase1NoteMatches;
  if (fullNoteCandidates.isNotEmpty) {
    final bodyIsolateRequest = SearchIsolateRequest(
      requestId: currentRequestId,
      rawQuery: query,
      noteCandidates: fullNoteCandidates,
      ocrCandidates: const [], // Deferred to Tier 3
    );

    final bodyIsolateResponse = await Isolate.run(() => searchIsolateWorker(bodyIsolateRequest));
    if (bodyIsolateResponse.requestId != _latestSearchRequestId) return;

    phase2NoteMatches = await _hydrateNoteMatches(db, bodyIsolateResponse.noteMatches);
    if (currentRequestId != _latestSearchRequestId) return;
  }

  // Yield Phase 2: Full body content matches streamed
  yield GlobalSearchResults(
    query: query,
    noteMatches: phase2NoteMatches,
    documentMatches: const [],
    matchingTags: matchingTags,
    searchPhase: SearchPhase.bodyContent,
  );

  // ════════════════════════════════════════════════════════════════
  // TIER 3: Complete Scanned Documents & Image OCR (~200-500ms)
  // ════════════════════════════════════════════════════════════════
  final ocrCandidates = await ocrSearchService.getOcrPageCandidates();
  if (currentRequestId != _latestSearchRequestId) return;

  if (ocrCandidates.isEmpty) {
    // No OCR documents exist; search is already complete
    yield GlobalSearchResults(
      query: query,
      noteMatches: phase2NoteMatches,
      documentMatches: const [],
      matchingTags: matchingTags,
      searchPhase: SearchPhase.complete,
    );
    return;
  }

  // Pre-fetch parent notes referenced by OCR candidates so they are surfaced if matched
  final ocrParentNoteIds = ocrCandidates
      .map((c) => c.parentNoteId)
      .where((id) => id != null && id.isNotEmpty)
      .cast<String>()
      .toSet();

  final allCandidateNoteIds = {...candidateNoteIds, ...ocrParentNoteIds}.toList();
  final allCandidates = await db.getSearchCandidatesByIds(allCandidateNoteIds);
  if (currentRequestId != _latestSearchRequestId) return;

  final fullIsolateRequest = SearchIsolateRequest(
    requestId: currentRequestId,
    rawQuery: query,
    noteCandidates: allCandidates,
    ocrCandidates: ocrCandidates,
  );

  final fullIsolateResponse = await Isolate.run(() => searchIsolateWorker(fullIsolateRequest));
  if (fullIsolateResponse.requestId != _latestSearchRequestId) return;

  final finalNoteMatches = await _hydrateNoteMatches(db, fullIsolateResponse.noteMatches);
  if (currentRequestId != _latestSearchRequestId) return;

  final finalDocumentMatches = await _hydrateDocumentMatches(db, fullIsolateResponse.documentMatches);
  if (currentRequestId != _latestSearchRequestId) return;

  // Yield Phase 3: Complete unified results
  yield GlobalSearchResults(
    query: query,
    noteMatches: finalNoteMatches,
    documentMatches: finalDocumentMatches,
    matchingTags: matchingTags,
    searchPhase: SearchPhase.complete,
  );
});

/// Evaluates lightweight candidates in-memory for instant Phase 1 title and tag matching.
Future<List<NoteSearchMatch>> _evaluateAndHydratePhase1({
  required AppDatabase db,
  required List<SearchCandidateDto> candidates,
  required CompiledSearchQuery compiledQuery,
  required String rawQuery,
}) async {
  final dtos = <NoteSearchMatchDto>[];

  for (final candidate in candidates) {
    final titleMatch = FuzzySearchEngine.evaluate(
      query: compiledQuery.cleanQuery,
      text: candidate.title,
      isTitle: true,
    );

    final tagsText = candidate.tags.map((t) => '#$t $t').join(' ');
    final tagMatch = FuzzySearchEngine.evaluate(
      query: compiledQuery.cleanQuery,
      text: tagsText,
      isTag: true,
    );

    if (!titleMatch.hasMatch && !tagMatch.hasMatch) continue;

    var totalScore = titleMatch.score + tagMatch.score;

    final daysSinceUpdate = DateTime.now().difference(candidate.updatedAt).inDays;
    if (daysSinceUpdate >= 0) {
      totalScore += 15.0 / (1.0 + (daysSinceUpdate / 30.0));
    }
    if (candidate.isPinned) {
      totalScore += 10.0;
    }

    final isFuzzy = titleMatch.isFuzzy || tagMatch.isFuzzy;
    final maxTokens = max(titleMatch.matchedTokensCount, tagMatch.matchedTokensCount);

    dtos.add(
      NoteSearchMatchDto(
        noteId: candidate.id,
        score: totalScore,
        snippet: candidate.title.isNotEmpty ? candidate.title : tagsText,
        titleHighlightSpans: titleMatch.highlightSpans,
        snippetHighlightSpans: const [],
        matchedInTitle: titleMatch.hasMatch,
        matchedInContent: false,
        matchedInTags: tagMatch.hasMatch,
        isFuzzy: isFuzzy,
        matchedTokensCount: maxTokens,
      ),
    );
  }

  // Sort descending by score, then token count
  dtos.sort((a, b) {
    final s = b.score.compareTo(a.score);
    if (s != 0) return s;
    return b.matchedTokensCount.compareTo(a.matchedTokensCount);
  });

  return _hydrateNoteMatches(db, dtos);
}

/// Hydrates Note domain models for a list of NoteSearchMatchDto objects.
Future<List<NoteSearchMatch>> _hydrateNoteMatches(
  AppDatabase db,
  List<NoteSearchMatchDto> dtos,
) async {
  if (dtos.isEmpty) return const [];

  final matchedIds = dtos.map((m) => m.noteId).toList();
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

  final matches = <NoteSearchMatch>[];
  for (final matchDto in dtos) {
    final note = notesById[matchDto.noteId];
    if (note != null) {
      matches.add(
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
  return matches;
}

/// Hydrates Document and Image Attachment domain models for DocumentSearchMatchDto objects.
Future<List<DocumentSearchMatch>> _hydrateDocumentMatches(
  AppDatabase db,
  List<DocumentSearchMatchDto> dtos,
) async {
  if (dtos.isEmpty) return const [];

  final docIds = dtos.where((m) => !m.isAttachment).map((m) => m.documentId).toList();
  final attIds = dtos.where((m) => m.isAttachment).map((m) => m.attachmentId ?? m.documentId).toList();

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

  final matches = <DocumentSearchMatch>[];
  for (final matchDto in dtos) {
    if (matchDto.isAttachment) {
      final attId = matchDto.attachmentId ?? matchDto.documentId;
      final attEntity = attachmentsById[attId];
      if (attEntity != null) {
        matches.add(
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
        matches.add(
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
  return matches;
}
