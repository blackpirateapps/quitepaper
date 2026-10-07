import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../domain/document_selection.dart';
import '../../domain/markdown_styles.dart';
import '../../domain/rich_block.dart';
import '../../domain/rich_document.dart';
import '../../domain/rich_inline.dart';
import '../../domain/text_attributes.dart';
import '../../application/rich_document_controller.dart';

const _uuid = Uuid();

/// A continuous visual rich-text writing surface for text blocks (Headings, Paragraphs,
/// Checklists, Lists, Quotes) in Quiet Paper's Visual mode.
///
/// **Architectural Invariant**: Operates directly on the authoritative [RichDocument].
/// Never rewrites Markdown source or reparses regex syntax on keystrokes.
class RichTextEditor extends StatefulWidget {
  const RichTextEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    this.blockIndices,
    this.readOnly = false,
    this.hintText = 'Start writing...',
    this.onActiveTargetChanged,
    this.onChanged,
    this.onKeyEvent,
  });

  final RichDocumentController controller;
  final FocusNode focusNode;

  /// Optional subset of block indices to render in this continuous segment.
  /// If null, renders all text blocks in the document.
  final List<int>? blockIndices;

  final bool readOnly;
  final String hintText;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends State<RichTextEditor> {
  late final _RichTextEditingController _textController;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _textController = _RichTextEditingController(
      editorController: widget.controller,
      blockIndices: widget.blockIndices,
      contextGetter: () => context,
      onToggleChecklist: (blockIndex) {
        widget.controller.toggleChecklistItemChecked(blockIndex);
      },
    );
    _textController.addListener(_onTextControllerChanged);
    widget.controller.addListener(_onDocumentControllerChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      widget.onActiveTargetChanged?.call(_textController, widget.focusNode);
    }
  }

  @override
  void didUpdateWidget(RichTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocumentControllerChanged);
      widget.controller.addListener(_onDocumentControllerChanged);
      _textController.editorController = widget.controller;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.blockIndices != widget.blockIndices) {
      _textController.blockIndices = widget.blockIndices;
      _syncFromDocument();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onDocumentControllerChanged);
    _textController.removeListener(_onTextControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onDocumentControllerChanged() {
    if (_isInternalUpdate) return;
    _syncFromDocument();
  }

  void _syncFromDocument() {
    final newText = _textController.computeSegmentText();
    _isInternalUpdate = true;
    try {
      TextSelection newSelection;
      final docSel = widget.controller.selection;
      final baseOffset = _textController.resolveSegmentOffset(docSel.base);
      final extentOffset = _textController.resolveSegmentOffset(docSel.extent);
      if (baseOffset != null && extentOffset != null) {
        newSelection = TextSelection(
          baseOffset: baseOffset.clamp(0, newText.length),
          extentOffset: extentOffset.clamp(0, newText.length),
          affinity: docSel.affinity,
        );
      } else {
        final currentSelection = _textController.selection;
        newSelection = TextSelection(
          baseOffset: currentSelection.baseOffset.clamp(0, newText.length),
          extentOffset: currentSelection.extentOffset.clamp(0, newText.length),
        );
      }

      if (_textController.text != newText || _textController.selection != newSelection) {
        _textController.value = TextEditingValue(
          text: newText,
          selection: newSelection,
        );
      } else {
        _textController.markNeedsRebuild();
      }
    } finally {
      _isInternalUpdate = false;
    }
  }

  void _onTextControllerChanged() {
    if (_isInternalUpdate) return;

    // Check if user changed text in the controller
    final currentText = _textController.text;
    final expectedText = _textController.computeSegmentText();

    if (currentText != expectedText) {
      _isInternalUpdate = true;
      try {
        _textController.applyTextChangesToDocument(currentText);
        widget.controller.notifyContentMutated();
      } finally {
        _isInternalUpdate = false;
      }
    }

    // Sync selection back to RichDocumentController preserving full range
    final sel = _textController.selection;
    if (sel.isValid) {
      if (sel.isCollapsed) {
        final docPos = _textController.resolveDocumentPosition(sel.extentOffset);
        if (docPos != null) {
          widget.controller.updateSelection(RichDocumentSelection.collapsed(docPos));
        }
      } else {
        final basePos = _textController.resolveDocumentPosition(sel.baseOffset);
        final extentPos = _textController.resolveDocumentPosition(sel.extentOffset);
        if (basePos != null && extentPos != null) {
          widget.controller.updateSelection(RichDocumentSelection(
            base: basePos,
            extent: extentPos,
            affinity: sel.affinity,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            // Check if Enter can be handled structurally across text blocks
            final sel = _textController.selection;
            if (sel.isValid && sel.isCollapsed) {
              final docPos = _textController.resolveDocumentPosition(sel.baseOffset);
              if (docPos != null) {
                final block = widget.controller.document.blocks[docPos.blockIndex];
                if (block.isTextBlock) {
                  widget.controller.handleEnter();
                  _syncFromDocument();
                  return KeyEventResult.handled;
                }
              }
            }
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            final sel = _textController.selection;
            if (sel.isValid && sel.isCollapsed) {
              final docPos = _textController.resolveDocumentPosition(sel.baseOffset);
              if (docPos != null && docPos.offset == 0) {
                final block = widget.controller.document.blocks[docPos.blockIndex];
                if (block.isTextBlock) {
                  widget.controller.handleBackspaceAtStart();
                  _syncFromDocument();
                  return KeyEventResult.handled;
                }
              }
            }
          }
        }
        return widget.onKeyEvent?.call(node, event) ?? KeyEventResult.ignored;
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): widget.controller.toggleBold,
          const SingleActivator(LogicalKeyboardKey.keyB, meta: true): widget.controller.toggleBold,
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): widget.controller.toggleItalic,
          const SingleActivator(LogicalKeyboardKey.keyI, meta: true): widget.controller.toggleItalic,
          const SingleActivator(LogicalKeyboardKey.keyX, control: true, shift: true): widget.controller.toggleStrike,
          const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true): widget.controller.toggleStrike,
          const SingleActivator(LogicalKeyboardKey.keyH, control: true, shift: true): widget.controller.toggleHighlight,
          const SingleActivator(LogicalKeyboardKey.keyH, meta: true, shift: true): widget.controller.toggleHighlight,
          const SingleActivator(LogicalKeyboardKey.backquote, control: true): widget.controller.toggleCode,
          const SingleActivator(LogicalKeyboardKey.backquote, meta: true): widget.controller.toggleCode,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true): widget.controller.undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): widget.controller.undo,
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): widget.controller.redo,
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): widget.controller.redo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): widget.controller.redo,
          const SingleActivator(LogicalKeyboardKey.keyY, meta: true): widget.controller.redo,
        },
        child: TextField(
          controller: _textController,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          maxLines: null,
          cursorColor: colors.accent,
          style: AppTypography.editorBody.copyWith(
            color: colors.textPrimary,
            height: 1.6,
          ),
          onTap: () {
            widget.onActiveTargetChanged?.call(_textController, widget.focusNode);
          },
          contextMenuBuilder: (context, editableTextState) {
            return AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            );
          },
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: AppTypography.editorBody.copyWith(
              color: colors.textTertiary,
            ),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

/// Custom [TextEditingController] rendering composable [TextSpan] and [WidgetSpan]
/// elements for rich document blocks directly from authoritative [RichDocument].
class _RichTextEditingController extends TextEditingController {
  _RichTextEditingController({
    required this.editorController,
    this.blockIndices,
    required this.contextGetter,
    required this.onToggleChecklist,
  }) {
    text = computeSegmentText();
  }

  RichDocumentController editorController;
  List<int>? blockIndices;
  final BuildContext Function() contextGetter;
  final void Function(int blockIndex) onToggleChecklist;

  void markNeedsRebuild() {
    notifyListeners();
  }

  List<int> get effectiveIndices {
    if (blockIndices != null) return blockIndices!;
    // Default to all text blocks
    final doc = editorController.document;
    final indices = <int>[];
    for (var i = 0; i < doc.blocks.length; i++) {
      if (doc.blocks[i].isTextBlock) {
        indices.add(i);
      }
    }
    return indices;
  }

  String computeSegmentText() {
    final doc = editorController.document;
    final lines = <String>[];
    for (final idx in effectiveIndices) {
      if (idx < doc.blocks.length) {
        lines.add(doc.blocks[idx].plainText);
      }
    }
    return lines.join('\n');
  }

  RichDocumentPosition? resolveDocumentPosition(int segmentOffset) {
    final doc = editorController.document;
    final indices = effectiveIndices;
    if (indices.isEmpty) return null;

    int runningOffset = 0;
    for (final idx in indices) {
      final block = doc.blocks[idx];
      final int blockLength = block.plainText.length;
      final int blockEnd = runningOffset + blockLength;

      if (segmentOffset <= blockEnd || idx == indices.last) {
        final int inner = (segmentOffset - runningOffset).clamp(0, blockLength).toInt();
        return RichDocumentPosition(
          blockIndex: idx,
          blockId: block.id,
          offset: inner,
        );
      }
      runningOffset = blockEnd + 1; // +1 for '\n'
    }
    return null;
  }

  int? resolveSegmentOffset(RichDocumentPosition position) {
    final doc = editorController.document;
    final indices = effectiveIndices;
    if (indices.isEmpty) return null;

    int runningOffset = 0;
    for (var i = 0; i < indices.length; i++) {
      final idx = indices[i];
      if (idx == position.blockIndex) {
        final block = doc.blocks[idx];
        final int blockLength = block.plainText.length;
        final int clampedInner = position.offset.clamp(0, blockLength).toInt();
        return runningOffset + clampedInner;
      }
      if (idx < doc.blocks.length) {
        runningOffset += doc.blocks[idx].plainText.length + 1; // +1 for '\n'
      }
    }
    return null;
  }

  void applyTextChangesToDocument(String newSegmentText) {
    final oldSegmentText = computeSegmentText();
    final lines = newSegmentText.split('\n');
    final indices = effectiveIndices;
    final doc = editorController.document;

    if (lines.length == indices.length) {
      // 1:1 line correspondence: update individual block spans preserving formatted runs
      for (var i = 0; i < indices.length; i++) {
        final blockIdx = indices[i];
        final block = doc.blocks[blockIdx];
        final newLine = lines[i];

        if (block.plainText != newLine) {
          final updatedSpans = _spliceSpans(
            spans: block.spans,
            oldText: block.plainText,
            newText: newLine,
            defaultAttributes: editorController.typingAttributes,
          );
          editorController.updateBlockSpans(blockIdx, updatedSpans);
        }
      }
      return;
    }

    // Line count changed. Diff old text and new text to identify the exact change.
    var prefixLen = 0;
    final minLen = math.min(oldSegmentText.length, newSegmentText.length);
    while (prefixLen < minLen && oldSegmentText.codeUnitAt(prefixLen) == newSegmentText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    var oldSuffixLen = 0;
    while (oldSuffixLen < oldSegmentText.length - prefixLen &&
        oldSuffixLen < newSegmentText.length - prefixLen &&
        oldSegmentText.codeUnitAt(oldSegmentText.length - 1 - oldSuffixLen) ==
            newSegmentText.codeUnitAt(newSegmentText.length - 1 - oldSuffixLen)) {
      oldSuffixLen++;
    }

    final deleteStart = prefixLen;
    final deleteEnd = oldSegmentText.length - oldSuffixLen;
    final inserted = newSegmentText.substring(prefixLen, newSegmentText.length - oldSuffixLen);

    // Case 1: Simple Enter key insertion (\n inserted at deleteStart with no deletion)
    if (inserted == '\n' && deleteStart == deleteEnd) {
      final docPos = resolveDocumentPosition(deleteStart);
      if (docPos != null) {
        editorController.handleEnterAt(docPos);
        return;
      }
    }

    // Case 2: Enter key replacing a selection range
    if (inserted == '\n' && deleteStart < deleteEnd) {
      final startPos = resolveDocumentPosition(deleteStart);
      final endPos = resolveDocumentPosition(deleteEnd);
      if (startPos != null && endPos != null) {
        final docAfterDelete = _deleteRange(doc, startPos, endPos);
        editorController.setDocument(docAfterDelete, newSelection: RichDocumentSelection.collapsed(startPos));
        editorController.handleEnterAt(startPos);
        return;
      }
    }

    // Case 3: Deletion across block boundaries (e.g. Backspace / Delete joining lines)
    if (inserted.isEmpty && deleteStart < deleteEnd) {
      final startPos = resolveDocumentPosition(deleteStart);
      final endPos = resolveDocumentPosition(deleteEnd);
      if (startPos != null && endPos != null) {
        final docAfterDelete = _deleteRange(doc, startPos, endPos);
        editorController.setDocument(docAfterDelete, newSelection: RichDocumentSelection.collapsed(startPos));
        return;
      }
    }

    // Case 4: General multiline paste or replacement
    final startPos = resolveDocumentPosition(deleteStart) ??
        RichDocumentPosition(blockIndex: indices.first, blockId: doc.blocks[indices.first].id, offset: 0);
    final endPos = resolveDocumentPosition(deleteEnd) ??
        RichDocumentPosition(blockIndex: indices.last, blockId: doc.blocks[indices.last].id, offset: doc.blocks[indices.last].plainText.length);

    final docAfterReplacement = _replaceRangeWithText(doc, startPos, endPos, inserted);
    editorController.setDocument(docAfterReplacement);
  }

  static RichDocument _deleteRange(
    RichDocument doc,
    RichDocumentPosition startPos,
    RichDocumentPosition endPos,
  ) {
    if (startPos.blockIndex == endPos.blockIndex) {
      final block = doc.blocks[startPos.blockIndex];
      if (!block.isTextBlock) return doc;
      final (left, _) = _splitSpans(block.spans, startPos.offset);
      final (_, right) = _splitSpans(block.spans, endPos.offset);
      final merged = [...left, ...right].normalized();
      final updated = _copyBlockWithSpans(block, merged);
      final newBlocks = List<RichBlock>.from(doc.blocks);
      newBlocks[startPos.blockIndex] = updated;
      return doc.copyWith(blocks: newBlocks);
    }

    final startBlock = doc.blocks[startPos.blockIndex];
    final endBlock = doc.blocks[endPos.blockIndex];
    final startSpans = startBlock.isTextBlock ? startBlock.spans : [RichInlineSpan(text: startBlock.plainText)];
    final endSpans = endBlock.isTextBlock ? endBlock.spans : [RichInlineSpan(text: endBlock.plainText)];

    final (startLeft, _) = _splitSpans(startSpans, startPos.offset);
    final (_, endRight) = _splitSpans(endSpans, endPos.offset);

    final mergedSpans = [...startLeft, ...endRight].normalized();
    final updatedStartBlock = _copyBlockWithSpans(startBlock, mergedSpans);

    final newBlocks = List<RichBlock>.from(doc.blocks);
    newBlocks[startPos.blockIndex] = updatedStartBlock;
    newBlocks.removeRange(startPos.blockIndex + 1, endPos.blockIndex + 1);
    return doc.copyWith(blocks: newBlocks);
  }

  static RichDocument _replaceRangeWithText(
    RichDocument doc,
    RichDocumentPosition startPos,
    RichDocumentPosition endPos,
    String insertedText,
  ) {
    final deletedDoc = _deleteRange(doc, startPos, endPos);
    if (insertedText.isEmpty) return deletedDoc;

    final targetBlockIdx = startPos.blockIndex.clamp(0, deletedDoc.blocks.length - 1);
    final targetBlock = deletedDoc.blocks[targetBlockIdx];
    final insertedLines = insertedText.split('\n');

    if (insertedLines.length == 1) {
      final spans = targetBlock.isTextBlock ? targetBlock.spans : [RichInlineSpan(text: targetBlock.plainText)];
      final (left, right) = _splitSpans(spans, startPos.offset);
      final insertedSpan = RichInlineSpan(text: insertedLines.first);
      final merged = [...left, insertedSpan, ...right].normalized();
      final updated = _copyBlockWithSpans(targetBlock, merged);
      final newBlocks = List<RichBlock>.from(deletedDoc.blocks);
      newBlocks[targetBlockIdx] = updated;
      return deletedDoc.copyWith(blocks: newBlocks);
    }

    final spans = targetBlock.isTextBlock ? targetBlock.spans : [RichInlineSpan(text: targetBlock.plainText)];
    final (left, right) = _splitSpans(spans, startPos.offset);

    final firstBlockSpans = [...left, RichInlineSpan(text: insertedLines.first)].normalized();
    final firstBlock = _copyBlockWithSpans(targetBlock, firstBlockSpans);

    final middleBlocks = <RichBlock>[];
    for (var i = 1; i < insertedLines.length - 1; i++) {
      middleBlocks.add(ParagraphBlock(
        id: _uuid.v4(),
        spans: [RichInlineSpan(text: insertedLines[i])],
      ));
    }

    final lastBlockSpans = [RichInlineSpan(text: insertedLines.last), ...right].normalized();
    final lastBlock = ParagraphBlock(
      id: _uuid.v4(),
      spans: lastBlockSpans,
    );

    final newBlocks = List<RichBlock>.from(deletedDoc.blocks);
    newBlocks[targetBlockIdx] = firstBlock;
    newBlocks.insertAll(targetBlockIdx + 1, [...middleBlocks, lastBlock]);
    return deletedDoc.copyWith(blocks: newBlocks);
  }

  static (List<RichInlineSpan>, List<RichInlineSpan>) _splitSpans(List<RichInlineSpan> spans, int offset) {
    final left = <RichInlineSpan>[];
    final right = <RichInlineSpan>[];
    var current = 0;

    for (final span in spans) {
      final start = current;
      final end = current + span.length;
      current = end;

      if (end <= offset) {
        left.add(span);
      } else if (start >= offset) {
        right.add(span);
      } else {
        final splitAt = offset - start;
        left.add(span.slice(0, splitAt));
        right.add(span.slice(splitAt));
      }
    }
    return (left.normalized(), right.normalized());
  }

  static RichBlock _copyBlockWithSpans(RichBlock block, List<RichInlineSpan> spans) {
    if (block is ParagraphBlock) return block.copyWith(spans: spans);
    if (block is HeadingBlock) return block.copyWith(spans: spans);
    if (block is ChecklistItemBlock) return block.copyWith(spans: spans);
    if (block is BulletedListItemBlock) return block.copyWith(spans: spans);
    if (block is OrderedListItemBlock) return block.copyWith(spans: spans);
    if (block is QuoteBlock) return block.copyWith(spans: spans);
    return ParagraphBlock(id: block.id, spans: spans);
  }

  static List<RichInlineSpan> _spliceSpans({
    required List<RichInlineSpan> spans,
    required String oldText,
    required String newText,
    required TextAttributes defaultAttributes,
  }) {
    if (spans.isEmpty || oldText.isEmpty) {
      return [RichInlineSpan(text: newText, attributes: defaultAttributes)].normalized();
    }
    if (oldText == newText) return spans;

    var prefixLen = 0;
    final minLen = math.min(oldText.length, newText.length);
    while (prefixLen < minLen && oldText.codeUnitAt(prefixLen) == newText.codeUnitAt(prefixLen)) {
      prefixLen++;
    }

    var oldSuffixLen = 0;
    while (oldSuffixLen < oldText.length - prefixLen &&
        oldSuffixLen < newText.length - prefixLen &&
        oldText.codeUnitAt(oldText.length - 1 - oldSuffixLen) ==
            newText.codeUnitAt(newText.length - 1 - oldSuffixLen)) {
      oldSuffixLen++;
    }

    final deleteStart = prefixLen;
    final deleteEnd = oldText.length - oldSuffixLen;
    final inserted = newText.substring(prefixLen, newText.length - oldSuffixLen);

    final result = <RichInlineSpan>[];
    var insertedHandled = false;
    var currentOffset = 0;

    for (final span in spans) {
      final spanStart = currentOffset;
      final spanEnd = currentOffset + span.length;
      currentOffset = spanEnd;

      if (spanEnd <= deleteStart) {
        result.add(span);
        continue;
      }

      if (spanStart >= deleteEnd) {
        if (!insertedHandled && inserted.isNotEmpty) {
          result.add(RichInlineSpan(text: inserted, attributes: defaultAttributes));
          insertedHandled = true;
        }
        result.add(span);
        continue;
      }

      // Intersects delete range
      // 1. Prefix before deleteStart
      if (spanStart < deleteStart) {
        result.add(span.slice(0, deleteStart - spanStart));
      }

      // 2. Inserted text
      if (!insertedHandled && inserted.isNotEmpty) {
        final insertAttrs = defaultAttributes.isEmpty ? span.attributes : defaultAttributes;
        result.add(RichInlineSpan(text: inserted, attributes: insertAttrs));
        insertedHandled = true;
      }

      // 3. Suffix after deleteEnd
      if (spanEnd > deleteEnd) {
        result.add(span.slice(deleteEnd - spanStart));
      }
    }

    if (!insertedHandled && inserted.isNotEmpty) {
      final lastAttrs = spans.isNotEmpty ? spans.last.attributes : defaultAttributes;
      final insertAttrs = defaultAttributes.isEmpty ? lastAttrs : defaultAttributes;
      result.add(RichInlineSpan(text: inserted, attributes: insertAttrs));
    }

    return result.normalized();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = context.appColors;
    final styles = editorController.styles ?? MarkdownStyles.fromColors(colors);
    final doc = editorController.document;
    final indices = effectiveIndices;
    final children = <InlineSpan>[];

    for (var i = 0; i < indices.length; i++) {
      final blockIdx = indices[i];
      if (blockIdx >= doc.blocks.length) continue;
      final block = doc.blocks[blockIdx];

      // 1. Heading Block
      if (block is HeadingBlock) {
        final headingStyle = _getHeadingStyle(block.level, styles, colors);
        children.addAll(_buildInlineSpans(block.spans, headingStyle, colors));
      }
      // 2. Checklist Item Block
      else if (block is ChecklistItemBlock) {
        final itemChecked = block.isChecked;
        // Interactive Phosphor checkbox widget
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => onToggleChecklist(blockIdx),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: Icon(
                  itemChecked
                      ? PhosphorIconsRegular.checkSquare
                      : PhosphorIconsRegular.square,
                  size: 19,
                  color: itemChecked ? colors.textTertiary : colors.accent,
                ),
              ),
            ),
          ),
        );
        final baseStyle = itemChecked
            ? styles.taskTextCompleted.copyWith(
                decoration: TextDecoration.lineThrough,
                color: colors.textSecondary,
              )
            : styles.body.copyWith(color: colors.textPrimary);
        children.addAll(_buildInlineSpans(block.spans, baseStyle, colors));
      }
      // 3. Bulleted List Item
      else if (block is BulletedListItemBlock) {
        final indentSpace = '  ' * block.indent;
        children.add(TextSpan(
          text: '$indentSpace• ',
          style: styles.listMarker.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.bold,
          ),
        ));
        children.addAll(_buildInlineSpans(block.spans, styles.body, colors));
      }
      // 4. Ordered List Item
      else if (block is OrderedListItemBlock) {
        final indentSpace = '  ' * block.indent;
        children.add(TextSpan(
          text: '$indentSpace${block.order}. ',
          style: styles.body.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ));
        children.addAll(_buildInlineSpans(block.spans, styles.body, colors));
      }
      // 5. Quote Block
      else if (block is QuoteBlock) {
        children.add(TextSpan(
          text: '▌ ',
          style: styles.body.copyWith(
            color: colors.accent.withValues(alpha: 0.7),
          ),
        ));
        children.addAll(_buildInlineSpans(block.spans, styles.blockquote, colors));
      }
      // 6. Standard Paragraph
      else if (block is ParagraphBlock) {
        children.addAll(_buildInlineSpans(block.spans, styles.body, colors));
      }

      // Add newline delimiter between lines in the segment
      if (i < indices.length - 1) {
        children.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(style: style, children: children);
  }

  TextStyle _getHeadingStyle(int level, MarkdownStyles styles, AppColors colors) {
    switch (level) {
      case 1:
        return styles.heading1.copyWith(color: colors.textPrimary);
      case 2:
        return styles.heading2.copyWith(color: colors.textPrimary);
      case 3:
        return styles.heading3.copyWith(color: colors.textPrimary);
      case 4:
        return styles.heading4.copyWith(color: colors.textPrimary);
      case 5:
        return styles.heading5.copyWith(color: colors.textPrimary);
      case 6:
      default:
        return styles.heading6.copyWith(color: colors.textPrimary);
    }
  }

  List<InlineSpan> _buildInlineSpans(
    List<RichInlineSpan> spans,
    TextStyle baseStyle,
    AppColors colors,
  ) {
    if (spans.isEmpty) {
      return [TextSpan(text: '', style: baseStyle)];
    }

    final result = <InlineSpan>[];
    for (final span in spans) {
      var spanStyle = baseStyle;
      final attr = span.attributes;

      if (attr.isBold) {
        spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      }
      if (attr.isItalic) {
        spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      }
      if (attr.isStrike) {
        spanStyle = spanStyle.copyWith(decoration: TextDecoration.lineThrough);
      }
      if (attr.isHighlight) {
        spanStyle = spanStyle.copyWith(
          backgroundColor: colors.accent.withValues(alpha: 0.22),
        );
      }
      if (attr.isCode) {
        spanStyle = spanStyle.copyWith(
          fontFamily: AppTypography.editorCode.fontFamily,
          backgroundColor: colors.surface,
          fontSize: (spanStyle.fontSize ?? 16.0) * 0.92,
        );
      }
      if (attr.hasLink) {
        spanStyle = spanStyle.copyWith(
          color: colors.accent,
          decoration: TextDecoration.underline,
        );
      }
      if (attr.hasTag) {
        spanStyle = spanStyle.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w600,
        );
      }

      result.add(TextSpan(text: span.text, style: spanStyle));
    }

    return result;
  }
}
