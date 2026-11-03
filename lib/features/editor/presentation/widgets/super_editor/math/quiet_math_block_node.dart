import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// Supported delimiter styles for LaTeX math blocks in Quiet Paper.
enum MathDelimiterType {
  /// LaTeX display bracket delimiters: `\[ ... \]`
  brackets,

  /// TeX / Obsidian display dollar delimiters: `$$ ... $$`
  dollars,

  /// CommonMark / GitHub fenced code block syntax: ````math ... ````
  codeFence;

  String get label {
    switch (this) {
      case MathDelimiterType.brackets:
        return r'\[ \]';
      case MathDelimiterType.dollars:
        return r'$$';
      case MathDelimiterType.codeFence:
        return '```math';
    }
  }
}

/// A block [DocumentNode] representing a LaTeX mathematical equation or formula
/// block in Quiet Paper's SuperEditor.
///
/// Features:
/// - Preserves raw TeX formulas verbatim without CommonMark escaping of `_` or `*`.
/// - Supports bracket (`\[ \]`), dollar (`$$`), and code fence (````math````) delimiters.
/// - Bidirectionally serialized via [QuietMathBlockNodeSerializer].
@immutable
class QuietMathBlockNode extends BlockNode {
  QuietMathBlockNode({
    required this.id,
    required this.latex,
    this.delimiterType = MathDelimiterType.brackets,
    super.metadata,
  }) {
    initAddToMetadata({
      NodeMetadata.blockType: const NamedAttribution('quietMathBlock'),
    });
  }

  @override
  final String id;

  /// The raw LaTeX mathematical formula without enclosing delimiters.
  final String latex;

  /// The delimiter format used to serialize this formula back to Markdown.
  final MathDelimiterType delimiterType;

  /// Copies this node with optional updated fields.
  QuietMathBlockNode copyWith({
    String? id,
    String? latex,
    MathDelimiterType? delimiterType,
    Map<String, dynamic>? metadata,
  }) {
    return QuietMathBlockNode(
      id: id ?? this.id,
      latex: latex ?? this.latex,
      delimiterType: delimiterType ?? this.delimiterType,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  DocumentNode copyWithAddedMetadata(Map<String, dynamic> newProperties) {
    return QuietMathBlockNode(
      id: id,
      latex: latex,
      delimiterType: delimiterType,
      metadata: {...metadata, ...newProperties},
    );
  }

  @override
  DocumentNode copyAndReplaceMetadata(Map<String, dynamic> newMetadata) {
    return QuietMathBlockNode(
      id: id,
      latex: latex,
      delimiterType: delimiterType,
      metadata: newMetadata,
    );
  }

  @override
  String? copyContent(dynamic selection) {
    if (selection is! UpstreamDownstreamNodeSelection) {
      throw Exception(
        'QuietMathBlockNode can only copy content from a UpstreamDownstreamNodeSelection.',
      );
    }
    return !selection.isCollapsed ? serializeMathString() : null;
  }

  /// Formats this formula with its enclosing delimiters.
  String serializeMathString() {
    final trimmed = latex.trim();
    switch (delimiterType) {
      case MathDelimiterType.brackets:
        return '\\[ $trimmed \\]';
      case MathDelimiterType.dollars:
        return trimmed.contains('\n') ? '\$\$\n$trimmed\n\$\$' : '\$\$ $trimmed \$\$';
      case MathDelimiterType.codeFence:
        return '```math\n$trimmed\n```';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietMathBlockNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          latex == other.latex &&
          delimiterType == other.delimiterType;

  @override
  int get hashCode => Object.hash(id, latex, delimiterType);
}

/// Custom [DocumentNodeMarkdownSerializer] for serializing [QuietMathBlockNode]
/// into clean Markdown without escaping underscores (`_`) or asterisks (`*`).
class QuietMathBlockNodeSerializer implements DocumentNodeMarkdownSerializer {
  const QuietMathBlockNodeSerializer();

  @override
  String? serialize(
    Document document,
    DocumentNode node, {
    NodeSelection? selection,
  }) {
    if (node is! QuietMathBlockNode) {
      return null;
    }

    if (selection != null && selection is! UpstreamDownstreamNodeSelection) {
      return '';
    }
    final upstreamDownstream = selection as UpstreamDownstreamNodeSelection?;
    if (upstreamDownstream != null && upstreamDownstream.isCollapsed) {
      return '';
    }

    final trimmed = node.latex.trim();
    final buffer = StringBuffer();

    switch (node.delimiterType) {
      case MathDelimiterType.brackets:
        // Use single-line if no internal newlines, else multi-line.
        if (trimmed.contains('\n')) {
          buffer.writeln(r'\[');
          buffer.writeln(trimmed);
          buffer.write(r'\]');
        } else {
          buffer.write('\\[ $trimmed \\]');
        }
        break;

      case MathDelimiterType.dollars:
        if (trimmed.contains('\n')) {
          buffer.writeln(r'$$');
          buffer.writeln(trimmed);
          buffer.write(r'$$');
        } else {
          buffer.write('\$\$ $trimmed \$\$');
        }
        break;

      case MathDelimiterType.codeFence:
        buffer.writeln('```math');
        buffer.writeln(trimmed);
        buffer.write('```');
        break;
    }

    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Request handler that intercepts [InsertNewlineAtCaretRequest] when the user
/// types `$$` or `\[` on an empty paragraph and presses Enter, converting it
/// directly into a [QuietMathBlockNode].
EditCommand? handleMathBlockFenceNewlineRequest(
  Editor editor,
  EditRequest request,
) {
  if (request is! InsertNewlineAtCaretRequest) return null;

  final selection = editor.composer.selection;
  if (selection == null || !selection.isCollapsed) return null;

  final base = selection.base;
  final node = editor.document.getNodeById(base.nodeId);
  if (node is! ParagraphNode) return null;

  final text = node.text.toPlainText().trim();
  if (text == r'$$') {
    return _ConvertParagraphToMathBlockCommand(
      nodeId: node.id,
      delimiterType: MathDelimiterType.dollars,
    );
  } else if (text == r'\[' || text == r'\[\]') {
    return _ConvertParagraphToMathBlockCommand(
      nodeId: node.id,
      delimiterType: MathDelimiterType.brackets,
    );
  }

  return null;
}

class _ConvertParagraphToMathBlockCommand extends EditCommand {
  const _ConvertParagraphToMathBlockCommand({
    required this.nodeId,
    required this.delimiterType,
  });

  final String nodeId;
  final MathDelimiterType delimiterType;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    executor.executeCommand(
      ReplaceNodeCommand(
        existingNodeId: nodeId,
        newNode: QuietMathBlockNode(
          id: nodeId,
          latex: '',
          delimiterType: delimiterType,
        ),
      ),
    );
  }
}
