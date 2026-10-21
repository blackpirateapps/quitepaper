import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/search/search_index_projection.dart';

void main() {
  group('SearchIndexProjection', () {
    test('Excludes trashed notes from search indexing', () {
      expect(
        SearchIndexProjection.shouldIndexNote(isTrashed: true),
        false,
      );
      expect(
        SearchIndexProjection.shouldIndexNote(isTrashed: false, deletedAt: DateTime.now()),
        false,
      );
      expect(
        SearchIndexProjection.shouldIndexNote(isTrashed: false),
        true,
      );
    });

    test('Indexes normal active notes with clean markdown-normalized body', () {
      final doc = SearchIndexProjection.project(
        noteId: 'note-2',
        title: 'Weekly Standup',
        content: '## Progress\n- Completed **search overhaul**.\n- See [link](https://example.com).',
        tags: ['work', 'updates'],
        isTrashed: false,
      );

      expect(doc.title, 'Weekly Standup');
      expect(doc.bodyText, contains('Progress'));
      expect(doc.bodyText, contains('Completed search overhaul'));
      expect(doc.bodyText, contains('See link'));
      expect(doc.bodyText, isNot(contains('##')));
      expect(doc.bodyText, isNot(contains('**')));
      expect(doc.bodyText, isNot(contains('https://example.com')));
      expect(doc.tags, 'work #work updates #updates');
    });

    test('Protects password-protected notes from exposing plaintext in persistent FTS5 index', () {
      const encryptedEnvelope = '''<!-- quiet-paper-encrypted-note-v1:{"v":1,"ct":"dGVzdA==","iv":"12345678"} -->''';
      final doc = SearchIndexProjection.project(
        noteId: 'note-locked-1',
        title: 'Personal Passwords',
        content: encryptedEnvelope,
        tags: ['secure'],
        isTrashed: false,
      );

      expect(doc.title, 'Personal Passwords');
      // Body text must be completely empty so ciphertext or metadata is not tokenized into FTS
      expect(doc.bodyText, '');
      expect(doc.tags, 'secure #secure');
    });

    test('Detects password protected notes accurately', () {
      expect(
        SearchIndexProjection.isPasswordProtected(
          '<!-- quiet-paper-encrypted-note-v1:{"v":1,"ct":"xyz"} -->',
        ),
        true,
      );
      expect(
        SearchIndexProjection.isPasswordProtected(
          '   \n<!-- quiet-paper-encrypted-note-v1:{"v":1,"ct":"xyz"} -->',
        ),
        true,
      );
      expect(
        SearchIndexProjection.isPasswordProtected('# Normal Note\nJust regular markdown.'),
        false,
      );
    });

    test('Indexes spoken audio transcript text while stripping internal URI and query parameters', () {
      const markdown = '# Morning Walk\n\n'
          '[Voice Memo: 2026-10-21](qp://asset/96ad766e-646b-4f65-bd12-8c21874f1127?transcript=1&lang=en&edited=0)\n'
          '> Today I noticed the autumn leaves falling by the river.\n'
          '> Need to remember to buy fresh apples later.\n\n'
          'Final written reflection.';

      final projection = SearchIndexProjection.project(
        noteId: 'note-audio-1',
        title: 'Morning Walk',
        content: markdown,
        tags: ['audio', 'journal'],
        isTrashed: false,
      );

      expect(projection.title, 'Morning Walk');
      expect(projection.bodyText, contains('Voice Memo: 2026-10-21'));
      expect(projection.bodyText, contains('Today I noticed the autumn leaves falling by the river'));
      expect(projection.bodyText, contains('Need to remember to buy fresh apples later'));
      expect(projection.bodyText, contains('Final written reflection'));

      // Ensure zero leakage of internal query parameters or URIs in search index
      expect(projection.bodyText, isNot(contains('qp://asset')));
      expect(projection.bodyText, isNot(contains('transcript=1')));
      expect(projection.bodyText, isNot(contains('lang=en')));
      expect(projection.bodyText, isNot(contains('edited=0')));
      expect(projection.bodyText, isNot(contains('96ad766e-646b-4f65-bd12-8c21874f1127')));
    });
  });
}
