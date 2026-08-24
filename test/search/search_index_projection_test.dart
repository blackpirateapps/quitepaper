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
  });
}
