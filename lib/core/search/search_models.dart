import 'package:flutter/foundation.dart';

/// Immutable highlight span representing start and end character offsets.
@immutable
class TokenSpanDto {
  final int start;
  final int end;
  final bool isExact;

  const TokenSpanDto({
    required this.start,
    required this.end,
    required this.isExact,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TokenSpanDto &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          isExact == other.isExact;

  @override
  int get hashCode => start.hashCode ^ end.hashCode ^ isExact.hashCode;

  @override
  String toString() => 'TokenSpanDto($start, $end, exact: $isExact)';
}

/// Configurable ranking weights and score parameters for the search engine.
@immutable
class SearchRankingConfig {
  final double exactPhraseTitle;
  final double exactPhraseTag;
  final double exactPhraseBody;

  final double exactTokenTitle;
  final double exactTokenTag;
  final double exactTokenBody;

  final double prefixTitle;
  final double prefixTag;
  final double prefixBody;

  final double substringTitle;
  final double substringTag;
  final double substringBody;

  final double fuzzyDist1Title;
  final double fuzzyDist1Tag;
  final double fuzzyDist1Body;

  final double fuzzyDist2Title;
  final double fuzzyDist2Tag;
  final double fuzzyDist2Body;

  final double allTokensMatchedBonus;
  final double perMatchedTokenBonus;
  final double recencyMaxBonus;
  final int maxCandidatesToReturn;
  final int snippetContextRadius;

  const SearchRankingConfig({
    this.exactPhraseTitle = 200.0,
    this.exactPhraseTag = 140.0,
    this.exactPhraseBody = 100.0,
    this.exactTokenTitle = 140.0,
    this.exactTokenTag = 110.0,
    this.exactTokenBody = 50.0,
    this.prefixTitle = 80.0,
    this.prefixTag = 60.0,
    this.prefixBody = 35.0,
    this.substringTitle = 70.0,
    this.substringTag = 50.0,
    this.substringBody = 30.0,
    this.fuzzyDist1Title = 40.0,
    this.fuzzyDist1Tag = 30.0,
    this.fuzzyDist1Body = 20.0,
    this.fuzzyDist2Title = 20.0,
    this.fuzzyDist2Tag = 15.0,
    this.fuzzyDist2Body = 10.0,
    this.allTokensMatchedBonus = 100.0,
    this.perMatchedTokenBonus = 30.0,
    this.recencyMaxBonus = 15.0,
    this.maxCandidatesToReturn = 100,
    this.snippetContextRadius = 45,
  });
}

/// Lightweight, isolate-safe candidate DTO for Note search evaluation.
@immutable
class SearchCandidateDto {
  final String id;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime updatedAt;
  final bool isPinned;
  final bool isArchived;
  final bool isPasswordProtected;

  const SearchCandidateDto({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.updatedAt,
    this.isPinned = false,
    this.isArchived = false,
    this.isPasswordProtected = false,
  });
}

/// Lightweight, isolate-safe candidate DTO for Document and Image OCR page evaluation.
@immutable
class OcrPageCandidateDto {
  final String documentId;
  final String? attachmentId;
  final int pageNumber;
  final String plainText;
  final String documentTitle;
  final String? parentNoteTitle;
  final String? parentNoteId;

  const OcrPageCandidateDto({
    required this.documentId,
    this.attachmentId,
    required this.pageNumber,
    required this.plainText,
    required this.documentTitle,
    this.parentNoteTitle,
    this.parentNoteId,
  });
}

/// Isolate request carrying query and candidate lists.
@immutable
class SearchIsolateRequest {
  final int requestId;
  final String rawQuery;
  final List<SearchCandidateDto> noteCandidates;
  final List<OcrPageCandidateDto> ocrCandidates;
  final SearchRankingConfig rankingConfig;

  const SearchIsolateRequest({
    required this.requestId,
    required this.rawQuery,
    required this.noteCandidates,
    this.ocrCandidates = const [],
    this.rankingConfig = const SearchRankingConfig(),
  });
}

/// Result DTO for a matched Note produced by the background search worker.
@immutable
class NoteSearchMatchDto {
  final String noteId;
  final double score;
  final String snippet;
  final List<TokenSpanDto> titleHighlightSpans;
  final List<TokenSpanDto> snippetHighlightSpans;
  final bool matchedInTitle;
  final bool matchedInContent;
  final bool matchedInTags;
  final bool isFuzzy;
  final int matchedTokensCount;

  const NoteSearchMatchDto({
    required this.noteId,
    required this.score,
    required this.snippet,
    required this.titleHighlightSpans,
    required this.snippetHighlightSpans,
    this.matchedInTitle = false,
    this.matchedInContent = false,
    this.matchedInTags = false,
    this.isFuzzy = false,
    this.matchedTokensCount = 1,
  });
}

/// Result DTO for a matched Document/OCR page produced by the background search worker.
@immutable
class DocumentSearchMatchDto {
  final String documentId;
  final String? attachmentId;
  final String documentTitle;
  final String? parentNoteTitle;
  final String? parentNoteId;
  final int matchedPageNumber;
  final String snippet;
  final List<TokenSpanDto> snippetHighlightSpans;
  final List<TokenSpanDto> titleHighlightSpans;
  final bool isOcrMatch;
  final bool isFuzzy;
  final int matchedTokensCount;
  final double score;

  const DocumentSearchMatchDto({
    required this.documentId,
    this.attachmentId,
    required this.documentTitle,
    this.parentNoteTitle,
    this.parentNoteId,
    required this.matchedPageNumber,
    required this.snippet,
    required this.snippetHighlightSpans,
    this.titleHighlightSpans = const [],
    required this.isOcrMatch,
    this.isFuzzy = false,
    this.matchedTokensCount = 1,
    required this.score,
  });
}

/// Complete response from background search worker.
@immutable
class SearchIsolateResponse {
  final int requestId;
  final String query;
  final List<NoteSearchMatchDto> noteMatches;
  final List<DocumentSearchMatchDto> documentMatches;

  const SearchIsolateResponse({
    required this.requestId,
    required this.query,
    required this.noteMatches,
    required this.documentMatches,
  });
}
