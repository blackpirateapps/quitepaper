import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/editor/application/semantic_markdown_parser.dart';
import 'package:quitepaper/features/editor/domain/document_position.dart';
import 'package:quitepaper/features/editor/domain/semantic_nodes.dart';
import 'package:quitepaper/features/editor/domain/source_range.dart';

void main() {
  group('SemanticDocument & SourceRange Model Tests', () {
    test('SourceRange boundary logic and helpers', () {
      const range = SourceRange(5, 15);
      expect(range.length, equals(10));
      expect(range.isEmpty, isFalse);
      expect(range.isNotEmpty, isTrue);
      expect(range.contains(5), isTrue);
      expect(range.contains(10), isTrue);
      expect(range.contains(15), isTrue);
      expect(range.contains(16), isFalse);

      expect(range.containsStrict(5), isTrue);
      expect(range.containsStrict(15), isFalse);

      expect(range.overlaps(const SourceRange(0, 6)), isTrue);
      expect(range.overlaps(const SourceRange(0, 5)), isFalse);
      expect(range.overlaps(const SourceRange(14, 20)), isTrue);
      expect(range.overlaps(const SourceRange(15, 20)), isFalse);

      expect(range.shift(5), equals(const SourceRange(10, 20)));
      expect(range.slice('01234Hello World56789'), equals('Hello Worl'));
    });

    test('DocumentPosition & DocumentSelection equality and collapsed checks', () {
      const pos1 = DocumentPosition(blockId: 'b1', offset: 4);
      const pos2 = DocumentPosition(blockId: 'b1', offset: 4);
      const pos3 = DocumentPosition(blockId: 'b1', offset: 8);

      expect(pos1, equals(pos2));
      expect(pos1.hashCode, equals(pos2.hashCode));
      expect(pos1, isNot(equals(pos3)));

      final selCollapsed = DocumentSelection.collapsed(pos1);
      expect(selCollapsed.isCollapsed, isTrue);
      expect(selCollapsed.isValid, isTrue);
      expect(selCollapsed.start, equals(pos1));
      expect(selCollapsed.end, equals(pos1));

      const selRange = DocumentSelection(base: pos3, extent: pos1);
      expect(selRange.isCollapsed, isFalse);
      expect(selRange.isSingleBlock, isTrue);
      expect(selRange.start, equals(pos1));
      expect(selRange.end, equals(pos3));
    });

    test('bidirectional mapping between source offset and semantic DocumentPosition', () {
      const md = '# Heading\nThis is **bold** text.\n- [ ] Task item';
      final doc = SemanticMarkdownParser.parse(md);

      // Find heading position
      final headingPos = doc.findPositionAtSourceOffset(4); // inside "Heading"
      expect(headingPos, isNotNull);
      expect(headingPos!.blockId, equals('block_0'));
      expect(headingPos.offset, equals(2)); // '# ' is prefix of 2 chars, so offset 4 is char index 2 ('a')

      // Map back from heading position to source offset
      final sourceOffset = doc.sourceOffsetAtPosition(headingPos);
      expect(sourceOffset, equals(4));

      // Paragraph with bold
      final pPos = doc.findPositionAtSourceOffset(21); // inside "bold"
      expect(pPos, isNotNull);
      expect(doc.sourceOffsetAtPosition(pPos!), equals(21));

      // Checklist item
      final checkPos = doc.findPositionAtSourceOffset(42);
      expect(checkPos, isNotNull);
    });

    test('sourceRangeAtSelection translates semantic range into Markdown range with delimiters', () {
      const md = 'This is **bold text** here.';
      final doc = SemanticMarkdownParser.parse(md);

      final pBlock = doc.blocks.first as ParagraphBlock;
      // Select "bold" (offsets 8 to 12 in visible text "This is bold text here.")
      final sel = DocumentSelection(
        base: DocumentPosition(blockId: pBlock.id, offset: 8),
        extent: DocumentPosition(blockId: pBlock.id, offset: 12),
      );

      final sourceRange = doc.sourceRangeAtSelection(sel);
      expect(sourceRange.slice(md), equals('bold'));
    });
  });
}
