import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/markdown/heading_item.dart';
import 'package:quitepaper/core/markdown/heading_parser.dart';

void main() {
  group('HeadingParser - cleanTitle', () {
    test('cleans bold, italic, and bold-italic markdown formatting', () {
      expect(HeadingParser.cleanTitle('**Bold Title**'), equals('Bold Title'));
      expect(HeadingParser.cleanTitle('__Bold Title__'), equals('Bold Title'));
      expect(HeadingParser.cleanTitle('*Italic Title*'), equals('Italic Title'));
      expect(HeadingParser.cleanTitle('_Italic Title_'), equals('Italic Title'));
      expect(HeadingParser.cleanTitle('***Bold Italic***'), equals('Bold Italic'));
      expect(HeadingParser.cleanTitle('___Bold Italic___'), equals('Bold Italic'));
      expect(
        HeadingParser.cleanTitle('Prefix **Bold** and *Italic* Suffix'),
        equals('Prefix Bold and Italic Suffix'),
      );
    });

    test('cleans strikethrough, highlight, and inline code formatting', () {
      expect(HeadingParser.cleanTitle('~~Strikethrough~~'), equals('Strikethrough'));
      expect(HeadingParser.cleanTitle('==Highlighted Text=='), equals('Highlighted Text'));
      expect(HeadingParser.cleanTitle('`Inline Code`'), equals('Inline Code'));
      expect(
        HeadingParser.cleanTitle('API for `getOffsetForPosition()` ==Important=='),
        equals('API for getOffsetForPosition() Important'),
      );
    });

    test('cleans links and images to text and alt representations', () {
      expect(
        HeadingParser.cleanTitle('[Quiet Paper Docs](https://quietpaper.app)'),
        equals('Quiet Paper Docs'),
      );
      expect(
        HeadingParser.cleanTitle('![Diagram](qp://asset/123-456) Architecture'),
        equals('Diagram Architecture'),
      );
    });

    test('preserves emojis, punctuation, and Unicode characters', () {
      expect(
        HeadingParser.cleanTitle('🚀 Launching Quiet Paper: Version 2.0!'),
        equals('🚀 Launching Quiet Paper: Version 2.0!'),
      );
      expect(
        HeadingParser.cleanTitle('日本語のタイトル (Japanese Title) & Français'),
        equals('日本語のタイトル (Japanese Title) & Français'),
      );
    });

    test('strips HTML tags and normalizes whitespace', () {
      expect(
        HeadingParser.cleanTitle('<span>Title</span> with   spaces'),
        equals('Title with spaces'),
      );
    });
  });

  group('HeadingParser - extractHeadings', () {
    test('extracts H1 to H6 headings accurately', () {
      const markdown = '''
# Heading 1
Some paragraph text.

## Heading 2
Another paragraph.

### Heading 3
More text.

#### Heading 4
Content.

##### Heading 5
Detail.

###### Heading 6
Deep detail.
''';

      final headings = HeadingParser.extractHeadings(markdown);
      expect(headings.length, equals(6));

      expect(headings[0].level, equals(1));
      expect(headings[0].title, equals('Heading 1'));
      expect(headings[0].lineIndex, equals(0));

      expect(headings[1].level, equals(2));
      expect(headings[1].title, equals('Heading 2'));

      expect(headings[2].level, equals(3));
      expect(headings[2].title, equals('Heading 3'));

      expect(headings[3].level, equals(4));
      expect(headings[3].title, equals('Heading 4'));

      expect(headings[4].level, equals(5));
      expect(headings[4].title, equals('Heading 5'));

      expect(headings[5].level, equals(6));
      expect(headings[5].title, equals('Heading 6'));
    });

    test('skips YAML frontmatter at beginning of document', () {
      const markdown = '''---
title: My Document
tags: [architecture, sync]
# This is a YAML comment not a markdown heading
---

# Real Document Heading
Body text.

## Section 1
More text.
''';

      final headings = HeadingParser.extractHeadings(markdown);
      expect(headings.length, equals(2));
      expect(headings[0].title, equals('Real Document Heading'));
      expect(headings[1].title, equals('Section 1'));
    });

    test('skips headings inside fenced code blocks', () {
      const markdown = '''
# Introduction

```markdown
# Fake Heading in Code Block
## Another Fake Heading
```

## Architecture

~~~python
# Python comment not heading
print("hello")
~~~

### Conclusion
''';

      final headings = HeadingParser.extractHeadings(markdown);
      expect(headings.length, equals(3));
      expect(headings[0].title, equals('Introduction'));
      expect(headings[1].title, equals('Architecture'));
      expect(headings[2].title, equals('Conclusion'));
    });

    test('handles duplicate heading titles with unique IDs and offsets', () {
      const markdown = '''
# Overview
First section.

## Introduction
First intro.

## Introduction
Second intro with identical title.
''';

      final headings = HeadingParser.extractHeadings(markdown);
      expect(headings.length, equals(3));
      expect(headings[1].title, equals('Introduction'));
      expect(headings[2].title, equals('Introduction'));
      expect(headings[1].id, isNot(equals(headings[2].id)));
      expect(headings[1].charOffset, isNot(equals(headings[2].charOffset)));
      expect(headings[1].lineIndex, isNot(equals(headings[2].lineIndex)));
    });

    test('handles empty or special heading cases gracefully', () {
      const markdown = '''
# 
##   
### Normal Heading
''';

      final headings = HeadingParser.extractHeadings(markdown);
      expect(headings.length, equals(3));
      expect(headings[0].title, equals('Heading 1'));
      expect(headings[1].title, equals('Heading 2'));
      expect(headings[2].title, equals('Normal Heading'));
    });
  });

  group('HeadingParser - computeVisibleWindow', () {
    test('returns all headings if count is within available height / maxItems', () {
      final headings = List.generate(
        5,
        (i) => HeadingItem(
          id: 'h_$i',
          rawTitle: 'Heading $i',
          title: 'Heading $i',
          level: (i % 3) + 1,
          charOffset: i * 100,
          lineIndex: i * 5,
        ),
      );

      final window = HeadingParser.computeVisibleWindow(
        headings: headings,
        activeIndex: 2,
        availableHeight: 600.0,
        itemHeight: 30.0,
        maxItems: 8,
      );

      expect(window.length, equals(5));
      expect(window, equals(headings));
    });

    test('slides dynamic window smoothly for large documents with 50+ headings', () {
      final headings = List.generate(
        50,
        (i) => HeadingItem(
          id: 'h_$i',
          rawTitle: 'Heading $i',
          title: 'Heading $i',
          level: (i % 3) + 1,
          charOffset: i * 100,
          lineIndex: i * 5,
        ),
      );

      // 1. Near start (active: 0)
      final windowStart = HeadingParser.computeVisibleWindow(
        headings: headings,
        activeIndex: 0,
        availableHeight: 300.0,
        itemHeight: 30.0,
        maxItems: 6,
      );
      expect(windowStart.length, equals(6));
      expect(windowStart.first.title, equals('Heading 0'));
      expect(windowStart.last.title, equals('Heading 5'));

      // 2. In middle (active: 25)
      final windowMid = HeadingParser.computeVisibleWindow(
        headings: headings,
        activeIndex: 25,
        availableHeight: 300.0,
        itemHeight: 30.0,
        maxItems: 6,
      );
      expect(windowMid.length, equals(6));
      expect(windowMid.map((h) => h.title), contains('Heading 25'));

      // 3. Near end (active: 49)
      final windowEnd = HeadingParser.computeVisibleWindow(
        headings: headings,
        activeIndex: 49,
        availableHeight: 300.0,
        itemHeight: 30.0,
        maxItems: 6,
      );
      expect(windowEnd.length, equals(6));
      expect(windowEnd.last.title, equals('Heading 49'));
      expect(windowEnd.first.title, equals('Heading 44'));
    });
  });

  group('HeadingParser - findActiveHeadingIndex', () {
    test('finds active heading accurately using binary search', () {
      final offsets = [0.0, 300.0, 800.0, 1500.0, 2400.0];

      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 0.0, headingOffsets: offsets), equals(0));
      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 150.0, headingOffsets: offsets), equals(0));
      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 310.0, headingOffsets: offsets), equals(1));
      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 790.0, headingOffsets: offsets), equals(2));
      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 1600.0, headingOffsets: offsets), equals(3));
      expect(HeadingParser.findActiveHeadingIndex(scrollOffset: 3000.0, headingOffsets: offsets), equals(4));
    });
  });
}
