import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/search_models.dart';
import 'package:quitepaper/core/search/search_worker.dart';

void main() {
  group('Search Worker & Concurrency Isolation', () {
    test('searchIsolateWorker scores note and OCR candidates in background isolate', () async {
      final now = DateTime.now();

      final noteCandidates = [
        SearchCandidateDto(
          id: 'note-1',
          title: 'Quarterly Planning',
          content: '# Q3 Roadmap\nDetailed goals for **search latency** optimization.',
          tags: ['roadmap', 'planning'],
          updatedAt: now,
        ),
        SearchCandidateDto(
          id: 'note-2',
          title: 'Shopping List',
          content: 'Milk, bread, eggs, apples.',
          tags: ['groceries'],
          updatedAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      final ocrCandidates = [
        OcrPageCandidateDto(
          documentId: 'doc-1',
          documentTitle: 'Architecture Spec',
          parentNoteId: 'note-1',
          parentNoteTitle: 'Quarterly Planning',
          pageNumber: 1,
          plainText: 'Page 1: Overview of Two-Tier FTS5 search architecture.',
        ),
      ];

      final request = SearchIsolateRequest(
        requestId: 42,
        rawQuery: 'search',
        noteCandidates: noteCandidates,
        ocrCandidates: ocrCandidates,
      );

      final response = await Isolate.run(() => searchIsolateWorker(request));

      expect(response.requestId, 42);
      expect(response.noteMatches.length, 1);
      expect(response.noteMatches.first.noteId, 'note-1');
      expect(response.noteMatches.first.snippet, contains('search latency'));
      expect(response.noteMatches.first.snippetHighlightSpans.isNotEmpty, true);

      expect(response.documentMatches.length, 1);
      expect(response.documentMatches.first.documentId, 'doc-1');
      expect(response.documentMatches.first.matchedPageNumber, 1);
      expect(response.documentMatches.first.snippet, contains('search architecture'));
    });

    test('Ranks exact phrase matches above prefix and fuzzy matches', () async {
      final now = DateTime.now();

      final candidates = [
        SearchCandidateDto(
          id: 'fuzzy-note',
          title: 'Synchronise Engine', // Fuzzy match for 'synchronization engine'
          content: 'Background sync worker.',
          tags: [],
          updatedAt: now,
        ),
        SearchCandidateDto(
          id: 'exact-phrase-note',
          title: 'Design Doc',
          content: 'Detailed specifications for synchronization engine components.',
          tags: [],
          updatedAt: now,
        ),
      ];

      final request = SearchIsolateRequest(
        requestId: 100,
        rawQuery: 'synchronization engine',
        noteCandidates: candidates,
        ocrCandidates: [],
      );

      final response = searchIsolateWorker(request);

      expect(response.noteMatches.isNotEmpty, true);
      // 'exact-phrase-note' should rank first
      expect(response.noteMatches.first.noteId, 'exact-phrase-note');
    });

    test('Enforces maxResults limit in SearchIsolateResponse', () {
      final now = DateTime.now();
      final manyCandidates = List.generate(
        100,
        (i) => SearchCandidateDto(
          id: 'note-$i',
          title: 'Invoice Item $i',
          content: 'Details for payment #$i',
          tags: [],
          updatedAt: now,
        ),
      );

      final request = SearchIsolateRequest(
        requestId: 200,
        rawQuery: 'invoice',
        noteCandidates: manyCandidates,
        ocrCandidates: [],
        rankingConfig: const SearchRankingConfig(maxCandidatesToReturn: 15),
      );

      final response = searchIsolateWorker(request);

      expect(response.noteMatches.length, 15);
    });
  });
}
