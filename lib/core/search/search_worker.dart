import 'fuzzy_search_engine.dart';

/// Top-level pure Dart entry point for background isolate execution.
SearchIsolateResponse searchIsolateWorker(SearchIsolateRequest request) {
  final compiled = SearchTokenizer.compileQuery(request.rawQuery);
  if (compiled.isEmpty) {
    return SearchIsolateResponse(
      requestId: request.requestId,
      query: request.rawQuery,
      noteMatches: const [],
      documentMatches: const [],
    );
  }

  final config = request.rankingConfig;

  // 1. Process Note candidates
  final noteMatches = <NoteSearchMatchDto>[];
  for (final candidate in request.noteCandidates) {
    final match = FuzzySearchEngine.evaluateCandidate(
      candidate: candidate,
      query: compiled,
      config: config,
    );
    if (match != null && match.score > 0.0) {
      noteMatches.add(match);
    }
  }

  // Sort notes: highest score first, then matchedTokensCount, then stable noteId
  noteMatches.sort((a, b) {
    final scoreCmp = b.score.compareTo(a.score);
    if (scoreCmp != 0) return scoreCmp;
    final tokenCmp = b.matchedTokensCount.compareTo(a.matchedTokensCount);
    if (tokenCmp != 0) return tokenCmp;
    return a.noteId.compareTo(b.noteId);
  });

  final limitedNoteMatches = noteMatches.length > config.maxCandidatesToReturn
      ? noteMatches.sublist(0, config.maxCandidatesToReturn)
      : noteMatches;

  // 2. Process OCR candidates
  final documentMatches = <DocumentSearchMatchDto>[];
  for (final ocrCandidate in request.ocrCandidates) {
    final match = FuzzySearchEngine.evaluateOcrPage(
      candidate: ocrCandidate,
      query: compiled,
      config: config,
    );
    if (match != null && match.score > 0.0) {
      documentMatches.add(match);
    }
  }

  // Sort documents: highest score first, then documentId
  documentMatches.sort((a, b) {
    final scoreCmp = b.score.compareTo(a.score);
    if (scoreCmp != 0) return scoreCmp;
    return a.documentId.compareTo(b.documentId);
  });

  final limitedDocMatches = documentMatches.length > config.maxCandidatesToReturn
      ? documentMatches.sublist(0, config.maxCandidatesToReturn)
      : documentMatches;

  return SearchIsolateResponse(
    requestId: request.requestId,
    query: request.rawQuery,
    noteMatches: limitedNoteMatches,
    documentMatches: limitedDocMatches,
  );
}
