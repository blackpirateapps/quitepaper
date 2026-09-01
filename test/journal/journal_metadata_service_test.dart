import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/journal/application/journal_metadata_service.dart';

void main() {
  group('JournalMetadataService Unit Tests', () {
    test('createInitialJournalContent produces canonical YAML frontmatter', () {
      final content = JournalMetadataService.createInitialJournalContent(
        journalDate: '2026-09-01',
      );
      expect(content, contains('---'));
      expect(content, contains('journal: true'));
      expect(content, contains('date: 2026-09-01'));
    });

    test('extractJournalMetadata extracts journal: true and date: YYYY-MM-DD', () {
      const markdown = '''---
journal: true
date: 2026-09-01
---
# Morning Reflection
Today was a quiet day.
''';
      final meta = JournalMetadataService.extractJournalMetadata(markdown);
      expect(meta.isJournal, isTrue);
      expect(meta.journalDate, '2026-09-01');
    });

    test('extractJournalMetadata handles quotes and variations safely', () {
      const markdown = '''---
journal: 'true'
date: "2026-09-01"
author: 'John'
---
Content
''';
      final meta = JournalMetadataService.extractJournalMetadata(markdown);
      expect(meta.isJournal, isTrue);
      expect(meta.journalDate, '2026-09-01');
    });

    test('extractJournalMetadata returns none when journal is false or missing', () {
      const markdown = '''---
title: My Regular Note
date: 2026-09-01
---
Just a normal note with a date
''';
      final meta = JournalMetadataService.extractJournalMetadata(markdown);
      expect(meta.isJournal, isFalse);
    });

    test('ensureJournalFrontmatter is idempotent and does not duplicate headers', () {
      const initial = '''---
journal: true
date: 2026-09-01
---
Initial content
''';
      final pass1 = JournalMetadataService.ensureJournalFrontmatter(
        content: initial,
        journalDate: '2026-09-01',
      );
      final pass2 = JournalMetadataService.ensureJournalFrontmatter(
        content: pass1,
        journalDate: '2026-09-01',
      );

      // Verify that '---' only appears twice (opening and closing)
      final openingCount = '---'.allMatches(pass2).length;
      expect(openingCount, 2);
      expect(pass2, equals(pass1));
    });

    test('ensureJournalFrontmatter preserves pre-existing frontmatter properties', () {
      const customMarkdown = '''---
author: Alice
tags: [journal, reflection]
description: A quiet day
---
Body text
''';
      final updated = JournalMetadataService.ensureJournalFrontmatter(
        content: customMarkdown,
        journalDate: '2026-09-01',
      );

      expect(updated, contains('author: Alice'));
      expect(updated, contains('tags: [journal, reflection]'));
      expect(updated, contains('description: A quiet day'));
      expect(updated, contains('journal: true'));
      expect(updated, contains('date: 2026-09-01'));
      expect(updated, contains('Body text'));
    });

    test('removeJournalFrontmatter strips journal keys from conflict copies', () {
      const journalMarkdown = '''---
journal: true
date: 2026-09-01
author: Bob
---
My conflict copy content
''';
      final cleaned = JournalMetadataService.removeJournalFrontmatter(journalMarkdown);
      expect(cleaned, isNot(contains('journal: true')));
      expect(cleaned, isNot(contains('date: 2026-09-01')));
      expect(cleaned, contains('author: Bob'));
      expect(cleaned, contains('My conflict copy content'));

      // If only journal keys were present, removes entire block
      const pureJournalMarkdown = '''---
journal: true
date: 2026-09-01
---
Body only
''';
      final pureCleaned = JournalMetadataService.removeJournalFrontmatter(pureJournalMarkdown);
      expect(pureCleaned, isNot(contains('---')));
      expect(pureCleaned, contains('Body only'));
    });
  });
}
