import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/rich_block.dart';
import '../../application/rich_document_controller.dart';
import 'rich_attachment_block.dart';
import 'rich_code_block.dart';
import 'rich_image_block.dart';
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

  @override
  State<RichEditorSurface> createState() => _RichEditorSurfaceState();
}

class _RichEditorSurfaceState extends State<RichEditorSurface> {
  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final blocks = widget.controller.document.blocks;

    // Fast-path: If all blocks are standard text blocks, render one continuous RichTextEditor
    final hasNonTextBlocks = blocks.any((b) => !b.isTextBlock);
    if (!hasNonTextBlocks) {
      return RichTextEditor(
        controller: widget.controller,
        focusNode: widget.focusNode,
        readOnly: widget.readOnly,
        hintText: widget.hintText,
        onActiveTargetChanged: widget.onActiveTargetChanged,
        onChanged: widget.onChanged,
        onKeyEvent: widget.onKeyEvent,
      );
    }

    // Segmented layout: Group contiguous text blocks around non-text elements
    final segments = <Widget>[];
    final currentTextIndices = <int>[];

    void flushTextSegment() {
      if (currentTextIndices.isNotEmpty) {
        final indicesCopy = List<int>.from(currentTextIndices);
        segments.add(
          RichTextEditor(
            key: ValueKey('text_segment_${indicesCopy.first}'),
            controller: widget.controller,
            focusNode: indicesCopy.first == 0 ? widget.focusNode : FocusNode(),
            blockIndices: indicesCopy,
            readOnly: widget.readOnly,
            hintText: indicesCopy.first == 0 ? widget.hintText : '',
            onActiveTargetChanged: widget.onActiveTargetChanged,
            onChanged: widget.onChanged,
            onKeyEvent: widget.onKeyEvent,
          ),
        );
        currentTextIndices.clear();
      }
    }

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (block.isTextBlock) {
        currentTextIndices.add(i);
      } else {
        flushTextSegment();

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
          segments.add(
            RichCodeBlock(
              key: ValueKey(block.id),
              block: block,
              blockIndex: i,
              controller: widget.controller,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: segments,
    );
  }
}
