import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/rich_block.dart';
import '../../domain/document_selection.dart';
import '../../application/rich_document_controller.dart';
import 'rich_attachment_block.dart';
import 'rich_checklist_editor.dart';
import 'rich_code_block.dart';
import 'rich_image_block.dart';
import 'rich_link_preview_block.dart';
import 'rich_table_editor.dart';
import 'rich_text_editor.dart';

/// Complete editorial continuous writing surface for Quiet Paper's Visual mode.
///
/// Seamlessly composes continuous text editors with specialized non-text elements
/// (tables, code blocks, images, dividers) while preserving a calm, unified writing canvas.
class RichEditorSurface extends StatefulWidget {
  const RichEditorSurface({
    super.key,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.hintText = 'Start writing...',
    this.searchQuery,
    this.noteId,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onKeyEvent,
    this.onPaste,
  });

  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String hintText;
  final String? searchQuery;

  /// Owning note id, used to resolve encrypted `qp://asset` images and provide
  /// gallery context to embedded cards.
  final String? noteId;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onPaste;

  @override
  State<RichEditorSurface> createState() => _RichEditorSurfaceState();
}

class _RichEditorSurfaceState extends State<RichEditorSurface> {
  final Map<String, FocusNode> _segmentFocusNodes = {};
  final Map<String, FocusNode> _textTargets = {};
  late RichDocumentSelection _lastSelection;
  Type? _lastSelectionBlockType;

  FocusNode _focusFor(String blockId) =>
      _segmentFocusNodes.putIfAbsent(blockId, () => FocusNode());
  @override
  void initState() {
    super.initState();
    _lastSelection = widget.controller.selection;
    _lastSelectionBlockType = widget.controller.document.blocks
        .where((block) => block.id == _lastSelection.extent.blockId)
        .firstOrNull?.runtimeType;
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(RichEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final node in _segmentFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final selection = widget.controller.selection;
    final blockType = widget.controller.document.blocks
        .where((block) => block.id == selection.extent.blockId)
        .firstOrNull?.runtimeType;
    if (selection != _lastSelection || blockType != _lastSelectionBlockType) {
      _lastSelection = selection;
      _lastSelectionBlockType = blockType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.readOnly || widget.controller.selection != selection) return;
        // Structural edits can move the caret from a checklist into a newly
        // created paragraph. Focus it after its field has been mounted.
        final node = _textTargets[selection.extent.blockId];
        if (node != null && !node.hasFocus) node.requestFocus();
      });
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final blocks = widget.controller.document.blocks;
    _textTargets.clear();

    // Segmented layout: Group contiguous text blocks around non-text and checklist elements
    final segments = <Widget>[];
    final currentTextIndices = <int>[];
    final currentChecklistIndices = <int>[];

    void flushTextSegment() {
      if (currentTextIndices.isNotEmpty) {
        final indicesCopy = List<int>.from(currentTextIndices);
        final node = indicesCopy.first == 0
            ? widget.focusNode
            : _focusFor(blocks[indicesCopy.first].id);
        for (final index in indicesCopy) {
          _textTargets[blocks[index].id] = node;
        }
        segments.add(
          RichTextEditor(
            key: ValueKey('text_segment_${blocks[indicesCopy.first].id}'),
            controller: widget.controller,
            focusNode: node,
            blockIndices: indicesCopy,
            readOnly: widget.readOnly,
            hintText: indicesCopy.first == 0 ? widget.hintText : '',
            onActiveTargetChanged: widget.onActiveTargetChanged,
            onChanged: widget.onChanged,
            onKeyEvent: widget.onKeyEvent,
            onPaste: widget.onPaste,
          ),
        );
        currentTextIndices.clear();
      }
    }

    void flushChecklistSegment() {
      if (currentChecklistIndices.isNotEmpty) {
        final indicesCopy = List<int>.from(currentChecklistIndices);
        segments.add(
          RichChecklistEditor(
            key: ValueKey('checklist_segment_${blocks[indicesCopy.first].id}'),
            focusNode: indicesCopy.first == 0 ? widget.focusNode : null,
            controller: widget.controller,
            blockIndices: indicesCopy,
            readOnly: widget.readOnly,
            onActiveTargetChanged: widget.onActiveTargetChanged,
            onChanged: widget.onChanged,
            onKeyEvent: widget.onKeyEvent,
            onPaste: widget.onPaste,
          ),
        );
        currentChecklistIndices.clear();
      }
    }

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block is ChecklistItemBlock) {
        flushTextSegment();
        currentChecklistIndices.add(i);
      } else if (block.isTextBlock) {
        flushChecklistSegment();
        currentTextIndices.add(i);
      } else {
        flushTextSegment();
        flushChecklistSegment();

        if (block is TableBlock) {
          segments.add(
            RichTableEditor(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
              readOnly: widget.readOnly,
            ),
          );
        } else if (block is CodeBlock) {
          final node = _focusFor(block.id);
          _textTargets[block.id] = node;
          segments.add(
            RichCodeBlock(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
              focusNode: node,
              onActiveTargetChanged: widget.onActiveTargetChanged,
              readOnly: widget.readOnly,
            ),
          );
        } else if (block is ImageBlock) {
          segments.add(
            RichImageBlock(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
              readOnly: widget.readOnly,
              noteId: widget.noteId,
            ),
          );
        } else if (block is AttachmentBlock) {
          segments.add(
            RichAttachmentBlock(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
              readOnly: widget.readOnly,
            ),
          );
        } else if (block is LinkPreviewBlock) {
          segments.add(
            RichLinkPreviewBlock(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
              readOnly: widget.readOnly,
              noteId: widget.noteId,
            ),
          );
        } else if (block is HorizontalRuleBlock) {
          segments.add(
            Padding(
              key: ValueKey(block.id),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(color: colors.divider, thickness: 1.0),
            ),
          );
        }
      }
    }

    flushTextSegment();
    flushChecklistSegment();

    final blockIds = blocks.map((block) => block.id).toSet();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final removed = _segmentFocusNodes.keys.where((id) => !blockIds.contains(id)).toList();
      for (final id in removed) {
        if (!widget.controller.document.blocks.any((block) => block.id == id)) {
          _segmentFocusNodes.remove(id)?.dispose();
        }
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: segments,
    );
  }
}
