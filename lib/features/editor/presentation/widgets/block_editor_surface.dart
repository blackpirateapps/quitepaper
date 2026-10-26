import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/features/editor/domain/document_selection.dart';
import 'package:quitepaper/features/editor/domain/rich_block.dart';
import 'package:quitepaper/features/editor/application/rich_document_controller.dart';
import 'blocks/block_wrapper.dart';
import 'blocks/callout_block_widget.dart';
import 'rich_attachment_block.dart';
import 'rich_checklist_editor.dart';
import 'rich_code_block.dart';
import 'rich_image_block.dart';
import 'rich_link_preview_block.dart';
import 'rich_table_editor.dart';
import 'rich_text_editor.dart';

/// Complete block-based visual editing surface for Quiet Paper's Visual mode.
///
/// Every structural block in the document is rendered as an independent, autonomous
/// Flutter widget with its own local focus and editing state, wrapped in a quiet
/// editorial gutter (`BlockWrapper`) supporting hover affordances and drag-reordering.
class BlockEditorSurface extends StatefulWidget {
  const BlockEditorSurface({
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
  });

  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String hintText;
  final String? searchQuery;
  final String? noteId;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  State<BlockEditorSurface> createState() => _BlockEditorSurfaceState();
}

class _BlockEditorSurfaceState extends State<BlockEditorSurface> {
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _syncFocusNodes();
    _checkInitialFocus();
  }

  @override
  void didUpdateWidget(BlockEditorSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _syncFocusNodes();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    for (final fn in _focusNodes.values) {
      fn.dispose();
    }
    _focusNodes.clear();
    super.dispose();
  }

  void _onControllerChanged() {
    _syncFocusNodes();
    if (mounted) setState(() {});
  }

  void _syncFocusNodes() {
    final blocks = widget.controller.document.blocks;
    final currentIds = <String>{};

    for (final b in blocks) {
      currentIds.add(b.id);
      if (!_focusNodes.containsKey(b.id)) {
        _focusNodes[b.id] = FocusNode(debugLabel: 'Block_${b.id}');
      }
    }

    // Clean up removed focus nodes
    final removed = _focusNodes.keys.where((id) => !currentIds.contains(id)).toList();
    for (final id in removed) {
      _focusNodes[id]?.dispose();
      _focusNodes.remove(id);
    }
  }

  void _checkInitialFocus() {
    if (widget.focusNode.hasFocus && widget.controller.document.blocks.isNotEmpty) {
      final firstBlock = widget.controller.document.blocks.first;
      final fn = _focusNodes[firstBlock.id];
      if (fn != null && !fn.hasFocus) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) fn.requestFocus();
        });
      }
    }
  }

  void _navigateToPreviousBlock(int currentIndex) {
    if (currentIndex > 0) {
      final prevBlock = widget.controller.document.blocks[currentIndex - 1];
      final fn = _focusNodes[prevBlock.id];
      if (fn != null) {
        fn.requestFocus();
        widget.controller.updateSelection(
          RichDocumentSelection.collapsed(
            RichDocumentPosition(
              blockIndex: currentIndex - 1,
              blockId: prevBlock.id,
              offset: prevBlock.plainText.length,
            ),
          ),
        );
      }
    }
  }

  void _navigateToNextBlock(int currentIndex) {
    if (currentIndex < widget.controller.document.blocks.length - 1) {
      final nextBlock = widget.controller.document.blocks[currentIndex + 1];
      final fn = _focusNodes[nextBlock.id];
      if (fn != null) {
        fn.requestFocus();
        widget.controller.updateSelection(
          RichDocumentSelection.collapsed(
            RichDocumentPosition(
              blockIndex: currentIndex + 1,
              blockId: nextBlock.id,
              offset: 0,
            ),
          ),
        );
      }
    }
  }

  Widget _buildBlockWidget(RichBlock block, int index) {
    final fn = index == 0 ? widget.focusNode : (_focusNodes[block.id] ?? FocusNode());

    if (block is ChecklistItemBlock) {
      return RichChecklistEditor(
        key: ValueKey('checklist_${block.id}'),
        controller: widget.controller,
        blockIndices: [index],
        readOnly: widget.readOnly,
        onActiveTargetChanged: widget.onActiveTargetChanged,
        onChanged: widget.onChanged,
        onKeyEvent: widget.onKeyEvent,
      );
    }

    if (block is CalloutBlock) {
      return CalloutBlockWidget(
        key: ValueKey('callout_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        focusNode: fn,
        readOnly: widget.readOnly,
        onActiveTargetChanged: widget.onActiveTargetChanged,
        onChanged: widget.onChanged,
        onNavigateUp: () => _navigateToPreviousBlock(index),
        onNavigateDown: () => _navigateToNextBlock(index),
      );
    }

    if (block.isTextBlock) {
      return RichTextEditor(
        key: ValueKey('text_${block.id}'),
        controller: widget.controller,
        focusNode: fn,
        blockIndices: [index],
        readOnly: widget.readOnly,
        hintText: index == 0 ? widget.hintText : '',
        onActiveTargetChanged: widget.onActiveTargetChanged,
        onChanged: widget.onChanged,
        onKeyEvent: widget.onKeyEvent,
      );
    }

    if (block is TableBlock) {
      return RichTableEditor(
        key: ValueKey('table_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        readOnly: widget.readOnly,
      );
    }

    if (block is CodeBlock) {
      return RichCodeBlock(
        key: ValueKey('code_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        readOnly: widget.readOnly,
      );
    }

    if (block is ImageBlock) {
      return RichImageBlock(
        key: ValueKey('image_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        readOnly: widget.readOnly,
        noteId: widget.noteId,
      );
    }

    if (block is AttachmentBlock) {
      return RichAttachmentBlock(
        key: ValueKey('attachment_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        readOnly: widget.readOnly,
      );
    }

    if (block is LinkPreviewBlock) {
      return RichLinkPreviewBlock(
        key: ValueKey('link_preview_${block.id}'),
        block: block,
        blockIndex: index,
        controller: widget.controller,
        readOnly: widget.readOnly,
        noteId: widget.noteId,
      );
    }

    if (block is HorizontalRuleBlock) {
      final colors = context.appColors;
      return Padding(
        key: ValueKey('hr_${block.id}'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Divider(color: colors.divider, thickness: 1.0),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.controller.document.blocks;

    if (widget.readOnly) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++)
            _buildBlockWidget(blocks[i], i),
        ],
      );
    }

    // Reorderable layout in edit mode
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: blocks.length,
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) {
        final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
        widget.controller.moveBlock(oldIndex, targetIndex);
        widget.onChanged?.call(widget.controller.toMarkdown());
      },
      itemBuilder: (context, i) {
        final block = blocks[i];
        return BlockWrapper(
          key: ValueKey(block.id),
          block: block,
          blockIndex: i,
          controller: widget.controller,
          readOnly: widget.readOnly,
          child: _buildBlockWidget(block, i),
        );
      },
    );
  }
}
