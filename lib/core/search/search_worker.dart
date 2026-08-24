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
  final matchedNoteIds = <String>{};

  for (final candidate in request.noteCandidates) {
    final match = FuzzySearchEngine.evaluateCandidate(
      candidate: candidate,
      query: compiled,
      config: config,
    );
    if (match != null && match.score > 0.0) {
      noteMatches.add(match);
      matchedNoteIds.add(candidate.id);
    }
  }

  // 2. Process OCR candidates (PDF documents and image attachments)
  final documentMatches = <DocumentSearchMatchDto>[];
  final parentCandidatesById = {for (final c in request.noteCandidates) c.id: c};

  for (final ocrCandidate in request.ocrCandidates) {
    final match = FuzzySearchEngine.evaluateOcrPage(
      candidate: ocrCandidate,
      query: compiled,
      config: config,
    );
    if (match != null && match.score > 0.0) {
      documentMatches.add(match);

      // If the OCR match belongs to a parent note not yet matched in title/body/tags,
      // synthesize a parent note match with OCR preview snippet
      final parentId = ocrCandidate.parentNoteId;
      if (parentId != null && parentId.isNotEmpty && !matchedNoteIds.contains(parentId)) {
        final parentCandidate = parentCandidatesById[parentId];
        var totalScore = match.score * 0.95;

        if (parentCandidate != null) {
          final daysSinceUpdate = DateTime.now().difference(parentCandidate.updatedAt).inDays;
          if (daysSinceUpdate >= 0) {
            totalScore += config.recencyMaxBonus / (1.0 + (daysSinceUpdate / 30.0));
          }
          if (parentCandidate.isPinned) {
            totalScore += 10.0;
          }
        }

        noteMatches.add(
          NoteSearchMatchDto(
            noteId: parentId,
            score: totalScore,
            snippet: match.snippet,
            titleHighlightSpans: const [],
            snippetHighlightSpans: match.snippetHighlightSpans,
            matchedInTitle: false,
            matchedInContent: false,
            matchedInTags: false,
            matchedInOcr: true,
            isFuzzy: match.isFuzzy,
            matchedTokensCount: match.matchedTokensCount,
          ),
        );
        matchedNoteIds.add(parentId);
      }
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

  // Sort documents: highest score first, then documentId
  documentMatches.sort((a, b) {
    final scoreCmp = b.score.compareTo(a.score);
    if (scoreCmp != 0) return scoreCmp;
    final docIdA = a.documentId.isNotEmpty ? a.documentId : (a.attachmentId ?? '');
    final docIdB = b.documentId.isNotEmpty ? b.documentId : (b.attachmentId ?? '');
    return docIdA.compareTo(docIdB);
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
