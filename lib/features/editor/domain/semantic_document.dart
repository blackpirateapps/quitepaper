import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'document_position.dart';
import 'frontmatter_document.dart';
import 'semantic_nodes.dart';
import 'source_range.dart';

/// An ephemeral, in-memory semantic representation of a Markdown document during visual editing.
///
/// **Product Invariant**: This document structure is never persisted directly to SQLite or cloud sync.
/// [canonicalMarkdown] remains the sole canonical source of truth.
@immutable
class SemanticDocument {
  const SemanticDocument({
    required this.blocks,
    required this.canonicalMarkdown,
    this.frontmatter,
    this.frontmatterRange,
  });

  /// The list of semantic blocks constituting this document.
  final List<SemanticBlock> blocks;

  /// Canonical Markdown source string representing this document.
  final String canonicalMarkdown;

  /// Parsed YAML frontmatter, if present in the document.
  final FrontmatterDocument? frontmatter;

  /// The exact source range occupied by the YAML frontmatter block in [canonicalMarkdown].
  final SourceRange? frontmatterRange;

  /// Whether this document has frontmatter.
  bool get hasFrontmatter => frontmatter != null && frontmatterRange != null;

  /// Whether this document contains zero blocks or only empty content.
  bool get isEmpty => blocks.isEmpty || (blocks.length == 1 && blocks.first.plainText.isEmpty);

  /// Whether this document contains content.
  bool get isNotEmpty => !isEmpty;

  /// Plain text representation of all blocks in the document.
  String get plainText => blocks.map((b) => b.plainText).join('\n');

  /// Finds a block by its unique identifier.
  SemanticBlock? findBlockById(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
      if (block is ListBlock) {
        for (final item in block.items) {
          if (item.id == id) return item;
        }
      } else if (block is OrderedListBlock) {
        for (final item in block.items) {
          if (item.id == id) return item;
        }
      } else if (block is ChecklistBlock) {
        for (final item in block.items) {
          if (item.id == id) return item;
        }
      }
    }
    return null;
  }

  /// Finds the index of a top-level block by its ID.
  int findBlockIndexById(String id) {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].id == id) return i;
      if (blocks[i] is ListBlock) {
        final list = blocks[i] as ListBlock;
        if (list.items.any((item) => item.id == id)) return i;
      } else if (blocks[i] is OrderedListBlock) {
        final list = blocks[i] as OrderedListBlock;
        if (list.items.any((item) => item.id == id)) return i;
      } else if (blocks[i] is ChecklistBlock) {
        final list = blocks[i] as ChecklistBlock;
        if (list.items.any((item) => item.id == id)) return i;
      }
    }
    return -1;
  }

  /// Finds the semantic block at a given [sourceOffset] in [canonicalMarkdown].
  SemanticBlock? findBlockAtSourceOffset(int sourceOffset) {
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final isLast = i == blocks.length - 1;
      final inRange = isLast
          ? block.sourceRange.contains(sourceOffset)
          : block.sourceRange.containsStrict(sourceOffset);
      if (inRange) {
        if (block is ListBlock) {
          for (var j = 0; j < block.items.length; j++) {
            final item = block.items[j];
            final isLastItem = isLast && j == block.items.length - 1;
            final inItemRange = isLastItem
                ? item.sourceRange.contains(sourceOffset)
                : item.sourceRange.containsStrict(sourceOffset);
            if (inItemRange) return item;
          }
        } else if (block is OrderedListBlock) {
          for (var j = 0; j < block.items.length; j++) {
            final item = block.items[j];
            final isLastItem = isLast && j == block.items.length - 1;
            final inItemRange = isLastItem
                ? item.sourceRange.contains(sourceOffset)
                : item.sourceRange.containsStrict(sourceOffset);
            if (inItemRange) return item;
          }
        } else if (block is ChecklistBlock) {
          for (var j = 0; j < block.items.length; j++) {
            final item = block.items[j];
            final isLastItem = isLast && j == block.items.length - 1;
            final inItemRange = isLastItem
                ? item.sourceRange.contains(sourceOffset)
                : item.sourceRange.containsStrict(sourceOffset);
            if (inItemRange) return item;
          }
        }
        return block;
      }
    }
    return blocks.isNotEmpty ? blocks.last : null;
  }

  /// Maps a canonical Markdown [sourceOffset] to a logical [DocumentPosition].
  DocumentPosition? findPositionAtSourceOffset(int sourceOffset) {
    final block = findBlockAtSourceOffset(sourceOffset);
    if (block == null) return null;

    if (block is ParagraphBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is HeadingBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is ListItemBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is OrderedListItemBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is ChecklistItemBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is QuoteBlock) {
      return _findPositionInRuns(block.runs, block.id, sourceOffset);
    } else if (block is CodeBlock) {
      final codeStart = block.codeRange.start;
      final offsetInCode = (sourceOffset - codeStart).clamp(0, block.code.length);
      return DocumentPosition(blockId: block.id, offset: offsetInCode);
    }

    return DocumentPosition(blockId: block.id, offset: 0);
  }

  static DocumentPosition _findPositionInRuns(
    List<SemanticInline> runs,
    String blockId,
    int sourceOffset,
  ) {
    var currentVisibleOffset = 0;
    for (final run in runs) {
      if (run.sourceRange.contains(sourceOffset)) {
        final runInnerStart = run.contentRange?.start ?? run.sourceRange.start;
        final runOffset = (sourceOffset - runInnerStart).clamp(0, run.text.length);
        return DocumentPosition(
          blockId: blockId,
          offset: currentVisibleOffset + runOffset,
        );
      }
      currentVisibleOffset += run.text.length;
    }
    return DocumentPosition(blockId: blockId, offset: currentVisibleOffset);
  }

  /// Maps a logical [DocumentPosition] back to a canonical Markdown source offset.
  int sourceOffsetAtPosition(
    DocumentPosition position, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    final block = findBlockById(position.blockId);
    if (block == null) return canonicalMarkdown.length;

    if (block is ParagraphBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.sourceRange.end);
    } else if (block is HeadingBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.contentRange.end);
    } else if (block is ListItemBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.contentRange.end);
    } else if (block is OrderedListItemBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.contentRange.end);
    } else if (block is ChecklistItemBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.contentRange.end);
    } else if (block is QuoteBlock) {
      return _sourceOffsetInRuns(block.runs, position.offset, affinity: affinity, fallbackEnd: block.contentRange.end);
    } else if (block is CodeBlock) {
      return (block.codeRange.start + position.offset).clamp(block.codeRange.start, block.codeRange.end);
    }

    return block.sourceRange.start;
  }

  static int _sourceOffsetInRuns(
    List<SemanticInline> runs,
    int offset, {
    required TextAffinity affinity,
    required int fallbackEnd,
  }) {
    var remaining = offset;
    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      final isLast = i == runs.length - 1;
      final runLen = run.text.length;

      if (affinity == TextAffinity.upstream) {
        if (remaining <= runLen || isLast) {
          final innerStart = run.contentRange?.start ?? run.sourceRange.start;
          return innerStart + remaining.clamp(0, runLen);
        }
      } else {
        if (remaining < runLen || isLast) {
          final innerStart = run.contentRange?.start ?? run.sourceRange.start;
          return innerStart + remaining.clamp(0, runLen);
        }
      }
      remaining -= runLen;
    }
    return fallbackEnd;
  }

  /// Maps a logical [DocumentSelection] to a canonical Markdown [SourceRange].
  SourceRange sourceRangeAtSelection(DocumentSelection selection) {
    final startOffset = sourceOffsetAtPosition(selection.start, affinity: TextAffinity.downstream);
    final endOffset = sourceOffsetAtPosition(selection.end, affinity: TextAffinity.upstream);
    final minOffset = startOffset < endOffset ? startOffset : endOffset;
    final maxOffset = startOffset < endOffset ? endOffset : startOffset;
    return SourceRange(minOffset, maxOffset);
  }

  @override
  String toString() => 'SemanticDocument(${blocks.length} blocks, ${canonicalMarkdown.length} chars)';
}
