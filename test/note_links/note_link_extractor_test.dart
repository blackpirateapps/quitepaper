import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/note_links/note_link_extractor.dart';

void main() {
  group('NoteLinkExtractor', () {
    const validUuid1 = 'a1b2c3d4-e5f6-4890-a1cd-ef1234567890';
    const validUuid2 = '00112233-4455-4677-8899-aabbccddeeff';

    test('extracts single canonical note link accurately', () {

      const md = 'Here is a reference to [Fourier Analysis](qp://note/$validUuid1) in mathematics.';
      final links = NoteLinkExtractor.extractLinks(md);

      expect(links.length, 1);
      expect(links.first.targetNoteId, validUuid1);
      expect(links.first.displayText, 'Fourier Analysis');
      expect(links.first.sourceOffset, 23);
      expect(links.first.rawText, '[Fourier Analysis](qp://note/$validUuid1)');
      expect(links.first.uri.isNote, true);
    });

    test('extracts multiple note links with distinct offsets', () {
      const md = '''
# Study Plan
- Review [Calculus](qp://note/$validUuid1)
- Then check [Linear Algebra](qp://note/$validUuid2)
- Re-read [Calculus Chapter 2](qp://note/$validUuid1)
''';
      final links = NoteLinkExtractor.extractLinks(md);

      expect(links.length, 3);
      expect(links[0].targetNoteId, validUuid1);
      expect(links[0].displayText, 'Calculus');
      expect(links[1].targetNoteId, validUuid2);
      expect(links[1].displayText, 'Linear Algebra');
      expect(links[2].targetNoteId, validUuid1);
      expect(links[2].displayText, 'Calculus Chapter 2');

      final targets = NoteLinkExtractor.extractTargetNoteIds(md);
      expect(targets, {validUuid1, validUuid2});
      expect(NoteLinkExtractor.containsNoteLink(md, validUuid1), true);
      expect(NoteLinkExtractor.containsNoteLink(md, validUuid2), true);
      expect(NoteLinkExtractor.containsNoteLink(md, 'non-existent'), false);
    });

    test('ignores non-note URIs (assets, documents, external URLs)', () {
      const md = '''
![diagram](qp://asset/12345678-1234-1234-1234-1234567890ab)
[scan](qp://document/abcdef12-3456-7890-abcd-ef1234567890)
[Google](https://google.com)
[Note](qp://note/$validUuid1)
''';
      final links = NoteLinkExtractor.extractLinks(md);
      expect(links.length, 1);
      expect(links.first.targetNoteId, validUuid1);
    });

    test('ignores escaped brackets and invalid UUIDs', () {
      const md = r'\[Escaped](qp://note/a1b2c3d4-e5f6-7890-abcd-ef1234567890) and [Invalid](qp://note/invalid-uuid)';
      final links = NoteLinkExtractor.extractLinks(md);
      expect(links.isEmpty, true);
    });

    test('handles empty and whitespace markdown cleanly', () {
      expect(NoteLinkExtractor.extractLinks(''), isEmpty);
      expect(NoteLinkExtractor.extractLinks('   \n  '), isEmpty);
      expect(NoteLinkExtractor.extractTargetNoteIds(''), isEmpty);
    });
  });
}
