import 'package:flutter/foundation.dart';
import 'document_selection.dart';
import 'rich_block.dart';

/// Authoritative rich-text document model for Quiet Paper's Visual mode.
///
/// Contains a structured list of [RichBlock] instances representing the
/// semantic hierarchy of the note without syntax noise.
@immutable
class RichDocument {
  const RichDocument({required this.blocks});

  /// Creates an empty document containing a single empty paragraph.
  factory RichDocument.empty() => RichDocument(
        blocks: [ParagraphBlock.empty()],
      );

  /// Deserializes a [RichDocument] from JSON.
  factory RichDocument.fromJson(Map<String, dynamic> json) {
    final rawBlocks = json['blocks'] as List<dynamic>? ?? [];
    return RichDocument(
      blocks: rawBlocks
          .map((b) => RichBlock.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Structural blocks of this document in presentation order.
  final List<RichBlock> blocks;

  /// Serializes the document to JSON.
  Map<String, dynamic> toJson() => {
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  /// Whether the document contains no blocks, or only a single empty paragraph.
  bool get isEmpty =>
      blocks.isEmpty ||
      (blocks.length == 1 &&
          blocks.first is ParagraphBlock &&
          blocks.first.plainText.isEmpty);

  /// Whether the document contains non-empty content.
  bool get isNotEmpty => !isEmpty;

  /// Total number of blocks in the document.
  int get blockCount => blocks.length;

  /// Combined plain text of all blocks joined by line breaks.
  String get plainText => blocks.map((b) => b.plainText).join('\n');

  /// Finds a block by its editor-local [id]. Returns `null` if not found.
  RichBlock? findBlockById(String id) {
    for (final block in blocks) {
      if (block.id == id) return block;
    }
    return null;
  }

  /// Finds the 0-based index of a block by its [id]. Returns -1 if not found.
  int findBlockIndexById(String id) {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].id == id) return i;
    }
    return -1;
  }

  /// Calculates the global character start offset for the block at [blockIndex].
  /// Accounts for a `\n` delimiter between adjacent blocks.
  int globalOffsetOfBlock(int blockIndex) {
    var offset = 0;
    final maxIndex = blockIndex.clamp(0, blocks.length);
    for (var i = 0; i < maxIndex; i++) {
      offset += blocks[i].plainText.length + 1; // +1 for '\n'
    }
    return offset;
  }

  /// Resolves a global character offset in [plainText] to a [RichDocumentPosition].
  RichDocumentPosition documentPositionAtGlobalOffset(int globalOffset) {
    if (blocks.isEmpty) {
      return const RichDocumentPosition(blockIndex: 0, blockId: '', offset: 0);
    }

    var runningOffset = 0;
    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final blockLength = block.plainText.length;
      final blockEnd = runningOffset + blockLength;

      if (globalOffset <= blockEnd || i == blocks.length - 1) {
        final innerOffset = (globalOffset - runningOffset).clamp(0, blockLength);
        return RichDocumentPosition(
          blockIndex: i,
          blockId: block.id,
          offset: innerOffset,
        );
      }

      runningOffset = blockEnd + 1; // +1 for '\n'
    }

    final lastBlock = blocks.last;
    return RichDocumentPosition(
      blockIndex: blocks.length - 1,
      blockId: lastBlock.id,
      offset: lastBlock.plainText.length,
    );
  }

  /// Resolves a [RichDocumentPosition] to a global character offset in [plainText].
  int globalOffsetAtDocumentPosition(RichDocumentPosition pos) {
    final blockOffset = globalOffsetOfBlock(pos.blockIndex);
    return blockOffset + pos.offset;
  }

  /// Returns a copy of this document with [blocks] replaced.
  RichDocument copyWith({List<RichBlock>? blocks}) {
    return RichDocument(
      blocks: blocks ?? this.blocks,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RichDocument &&
          runtimeType == other.runtimeType &&
          listEquals(blocks, other.blocks);

  @override
  int get hashCode => Object.hashAll(blocks);

  @override
  String toString() => 'RichDocument(${blocks.length} blocks)';
}
