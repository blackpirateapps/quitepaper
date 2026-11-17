import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/domain/note_metadata_extractor.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  final now = DateTime(2026, 11, 17);
  final original = Note(
    id: 'note',
    title: 'Title',
    content: 'First body',
    tags: const ['before'],
    createdAt: now,
    updatedAt: now,
  );
  setUp(NoteMetadataExtractor.clearCache);

  test(
    'NL-03: same-time tag changes and same-length content refresh metadata',
    () {
      final before = NoteMetadataExtractor.extract(original);
      final tagEdit = original.copyWith(tags: ['after']);
      final after = NoteMetadataExtractor.extract(tagEdit);
      expect(after.tags, ['after']);
      expect(identical(before, after), isFalse);
      final bodyEdit = tagEdit.copyWith(content: 'Other body');
      expect(bodyEdit.content.length, original.content.length);
      final body = NoteMetadataExtractor.extract(bodyEdit);
      expect(body.previewSnippet, contains('Other body'));
      expect(identical(after, body), isFalse);
      expect(
        NoteMetadataExtractor.extract(bodyEdit.copyWith(tags: ['after'])),
        same(body),
      );
    },
  );

  test(
    'NL-03: snippets, protection and exact ID invalidation remain isolated',
    () {
      final first = NoteMetadataExtractor.extract(
        original,
        precomputedSnippet: 'first',
      );
      final second = NoteMetadataExtractor.extract(
        original,
        precomputedSnippet: 'second',
      );
      expect(first.previewSnippet, 'first');
      expect(second.previewSnippet, 'second');
      final other = original.copyWith(id: 'note_child');
      final otherMeta = NoteMetadataExtractor.extract(other);
      NoteMetadataExtractor.invalidate('note');
      expect(NoteMetadataExtractor.cacheSize, 1);
      expect(NoteMetadataExtractor.extract(other), same(otherMeta));
      final protected = NoteMetadataExtractor.extract(
        original.copyWith(
          content: '<!-- quiet-paper-encrypted-note-v1: secret -->',
        ),
      );
      expect(protected.isPasswordProtected, isTrue);
      expect(protected.thumbnailData, isNull);
    },
  );
  for (final count in [600, 1000]) {
    test(
      'NL-08: repeated $count-note prewarm preserves useful cache instances',
      () {
        final notes = List.generate(
          count,
          (i) => original.copyWith(id: 'cache-$i'),
        );
        NoteMetadataExtractor.prewarmAll(notes);
        final tail = notes
            .skip(count - NoteMetadataExtractor.maxCacheSize)
            .toList();
        final refs = tail.map(NoteMetadataExtractor.extract).toList();
        for (var sweep = 0; sweep < 5; sweep++) {
          NoteMetadataExtractor.prewarmAll(notes);
          for (var i = tail.length - 1; i >= 0; i--) {
            expect(NoteMetadataExtractor.extract(tail[i]), same(refs[i]));
          }
          expect(
            NoteMetadataExtractor.cacheSize,
            NoteMetadataExtractor.maxCacheSize,
          );
        }
      },
    );
  }
}
