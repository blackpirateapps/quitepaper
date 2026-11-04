import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:super_editor/super_editor.dart';

/// Custom [ComponentBuilder] for SuperEditor that renders blockquotes
/// with Quiet Paper's editorial 3.5px left accent bar, transparent background,
/// compact inter-line spacing, and continuous vertical bar alignment.
class QuietBlockquoteComponentBuilder implements ComponentBuilder {
  const QuietBlockquoteComponentBuilder();

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.getMetadataValue('blockType') != blockquoteAttribution) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.toPlainText());

    TextAlign textAlign = (textDirection == TextDirection.ltr) ? TextAlign.left : TextAlign.right;
    final textAlignName = node.getMetadataValue('textAlign');
    switch (textAlignName) {
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }

    // Determine if adjacent nodes are also blockquotes to compact spacing and shape corner radii.
    final prevNode = document.getNodeBeforeById(node.id);
    final nextNode = document.getNodeAfterById(node.id);
    final isFirstInBlock = prevNode is! ParagraphNode ||
        prevNode.getMetadataValue('blockType') != blockquoteAttribution;
    final isLastInBlock = nextNode is! ParagraphNode ||
        nextNode.getMetadataValue('blockType') != blockquoteAttribution;

    return QuietBlockquoteComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      text: node.text,
      textStyleBuilder: noStyleBuilder,
      indent: node.indent,
      backgroundColor: const Color(0x00000000),
      borderRadius: BorderRadius.zero,
      textDirection: textDirection,
      textAlignment: textAlign,
      selectionColor: const Color(0x00000000),
      isFirstInBlock: isFirstInBlock,
      isLastInBlock: isLastInBlock,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! QuietBlockquoteComponentViewModel) {
      return null;
    }

    return QuietBlockquoteComponent(
      textKey: componentContext.componentKey,
      text: componentViewModel.text,
      styleBuilder: componentViewModel.textStyleBuilder,
      inlineWidgetBuilders: componentViewModel.inlineWidgetBuilders,
      textSelection: componentViewModel.selection,
      selectionColor: componentViewModel.selectionColor,
      highlightWhenEmpty: componentViewModel.highlightWhenEmpty,
      underlines: componentViewModel.createUnderlines(),
      indent: componentViewModel.indent,
      indentCalculator: componentViewModel.indentCalculator,
      isFirstInBlock: componentViewModel.isFirstInBlock,
      isLastInBlock: componentViewModel.isLastInBlock,
    );
  }
}

/// View model for [QuietBlockquoteComponent] carrying block boundary flags.
class QuietBlockquoteComponentViewModel extends BlockquoteComponentViewModel {
  QuietBlockquoteComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = EdgeInsets.zero,
    super.opacity = 1.0,
    required super.text,
    required super.textStyleBuilder,
    super.inlineWidgetBuilders = const [],
    super.textDirection = TextDirection.ltr,
    super.textAlignment = TextAlign.left,
    super.maxLines,
    super.overflow = TextOverflow.clip,
    super.selection,
    required super.selectionColor,
    super.highlightWhenEmpty = false,
    super.indent = 0,
    super.indentCalculator = defaultParagraphIndentCalculator,
    required super.backgroundColor,
    required super.borderRadius,
    required this.isFirstInBlock,
    required this.isLastInBlock,
  });

  final bool isFirstInBlock;
  final bool isLastInBlock;

  @override
  QuietBlockquoteComponentViewModel copy() {
    return QuietBlockquoteComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      text: text.copy(),
      textStyleBuilder: textStyleBuilder,
      inlineWidgetBuilders: inlineWidgetBuilders,
      textDirection: textDirection,
      textAlignment: textAlignment,
      maxLines: maxLines,
      overflow: overflow,
      selection: selection,
      selectionColor: selectionColor,
      highlightWhenEmpty: highlightWhenEmpty,
      indent: indent,
      indentCalculator: indentCalculator,
      backgroundColor: backgroundColor,
      borderRadius: borderRadius,
      isFirstInBlock: isFirstInBlock,
      isLastInBlock: isLastInBlock,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietBlockquoteComponentViewModel &&
          runtimeType == other.runtimeType &&
          isFirstInBlock == other.isFirstInBlock &&
          isLastInBlock == other.isLastInBlock;

  @override
  int get hashCode =>
      super.hashCode ^ isFirstInBlock.hashCode ^ isLastInBlock.hashCode;
}

/// A document component displaying an editorial blockquote with a 3.5px accent bar
/// and compact inter-paragraph spacing.
class QuietBlockquoteComponent extends StatelessWidget {
  const QuietBlockquoteComponent({
    super.key,
    required this.textKey,
    required this.text,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    required this.styleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textSelection,
    this.selectionColor = Colors.transparent,
    this.highlightWhenEmpty = false,
    this.underlines = const [],
    this.showDebugPaint = false,
    this.indent = 0,
    this.indentCalculator = defaultParagraphIndentCalculator,
    this.barColor,
    this.barWidth = 3.5,
    this.isFirstInBlock = true,
    this.isLastInBlock = true,
  });

  final GlobalKey textKey;
  final AttributedText text;
  final int? maxLines;
  final TextOverflow overflow;
  final AttributionStyleBuilder styleBuilder;
  final InlineWidgetBuilderChain inlineWidgetBuilders;
  final TextSelection? textSelection;
  final Color selectionColor;
  final bool highlightWhenEmpty;
  final List<Underlines> underlines;
  final bool showDebugPaint;
  final int indent;
  final TextBlockIndentCalculator indentCalculator;
  final Color? barColor;
  final double barWidth;
  final bool isFirstInBlock;
  final bool isLastInBlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final effectiveBarColor = barColor ?? colors.accent;

    // Compact vertical spacing:
    // When adjacent to another blockquote paragraph, use 2.0dp padding (total 4.0dp gap).
    // When at the outer boundary (start or end of blockquote group), provide 6.0dp padding.
    final topPadding = isFirstInBlock ? 6.0 : 2.0;
    final bottomPadding = isLastInBlock ? 6.0 : 2.0;

    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(
          top: topPadding,
          bottom: bottomPadding,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (indent > 0)
              SizedBox(
                width: indentCalculator(
                  styleBuilder({}),
                  indent,
                ),
              ),
            Expanded(
              child: CustomPaint(
                painter: _BlockquoteBarPainter(
                  barColor: effectiveBarColor,
                  barWidth: barWidth,
                  isFirstInBlock: isFirstInBlock,
                  isLastInBlock: isLastInBlock,
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: barWidth + 12.0, // 3.5 + 12.0 = 15.5dp total left indentation
                  ),
                  child: TextComponent(
                    key: textKey,
                    text: text,
                    maxLines: maxLines,
                    overflow: overflow,
                    textStyleBuilder: styleBuilder,
                    inlineWidgetBuilders: inlineWidgetBuilders,
                    textSelection: textSelection,
                    selectionColor: selectionColor,
                    highlightWhenEmpty: highlightWhenEmpty,
                    underlines: underlines,
                    showDebugPaint: showDebugPaint,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockquoteBarPainter extends CustomPainter {
  const _BlockquoteBarPainter({
    required this.barColor,
    required this.barWidth,
    required this.isFirstInBlock,
    required this.isLastInBlock,
  });

  final Color barColor;
  final double barWidth;
  final bool isFirstInBlock;
  final bool isLastInBlock;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    const radius = Radius.circular(2.0);

    final rrect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, barWidth, size.height),
      topLeft: isFirstInBlock ? radius : Radius.zero,
      topRight: isFirstInBlock ? radius : Radius.zero,
      bottomLeft: isLastInBlock ? radius : Radius.zero,
      bottomRight: isLastInBlock ? radius : Radius.zero,
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_BlockquoteBarPainter oldDelegate) {
    return barColor != oldDelegate.barColor ||
        barWidth != oldDelegate.barWidth ||
        isFirstInBlock != oldDelegate.isFirstInBlock ||
        isLastInBlock != oldDelegate.isLastInBlock;
  }
}

/// [SuperEditorPlugin] providing blockquote Enter auto-continuation
/// and soft keyboard / IME integration.
class QuietBlockquotePlugin extends SuperEditorPlugin {
  QuietBlockquotePlugin();

  EditRequestHandler? _requestHandler;

  @override
  void attach(Editor editor) {
    _requestHandler = (editor, request) {
      if (request is! InsertNewlineAtCaretRequest) {
        return null;
      }

      final composer = editor.context.composer;
      final selection = composer.selection;
      if (selection == null || !selection.isCollapsed) {
        return null;
      }

      final document = editor.context.document;
      final node = document.getNodeById(selection.extent.nodeId);
      if (node is! ParagraphNode || node.getMetadataValue('blockType') != blockquoteAttribution) {
        return null;
      }

      return InsertNewlineInBlockquoteAtCaretCommand(request.newNodeId);
    };

    editor.requestHandlers.insert(0, _requestHandler!);
  }

  @override
  void detach(Editor editor) {
    if (_requestHandler != null) {
      editor.requestHandlers.remove(_requestHandler);
      _requestHandler = null;
    }
  }

  @override
  List<SuperEditorKeyboardAction> get keyboardActions => [
        handleBlockquoteKeyboardActions,
      ];
}

/// An [EditCommand] that continues or exits blockquotes when Enter is pressed.
class InsertNewlineInBlockquoteAtCaretCommand extends BaseInsertNewlineAtCaretCommand {
  const InsertNewlineInBlockquoteAtCaretCommand(this.newNodeId);

  final String newNodeId;

  @override
  void doInsertNewline(
    EditContext context,
    CommandExecutor executor,
    DocumentPosition caretPosition,
    NodePosition caretNodePosition,
  ) {
    final node = context.document.getNodeById(caretPosition.nodeId);
    if (caretNodePosition is! TextNodePosition ||
        node is! ParagraphNode ||
        node.getMetadataValue('blockType') != blockquoteAttribution) {
      return;
    }

    if (node.text.isEmpty) {
      // The blockquote line is empty. Convert it back to a standard paragraph.
      executor.executeCommand(
        ChangeParagraphBlockTypeCommand(
          nodeId: node.id,
          blockType: null,
        ),
      );
      return;
    }

    // Split the paragraph while preserving blockquote metadata on both parts.
    executor
      ..executeCommand(
        SplitParagraphCommand(
          nodeId: node.id,
          splitPosition: TextPosition(offset: caretNodePosition.offset),
          newNodeId: newNodeId,
          replicateExistingMetadata: true,
        ),
      )
      ..executeCommand(
        ChangeSelectionCommand(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newNodeId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
      );
  }
}

/// Keyboard action intercepting Enter on blockquotes.
ExecutionInstruction handleBlockquoteKeyboardActions({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  if (keyEvent.logicalKey != LogicalKeyboardKey.enter &&
      keyEvent.logicalKey != LogicalKeyboardKey.numpadEnter) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null || !selection.isCollapsed) {
    return ExecutionInstruction.continueExecution;
  }

  final node = editContext.document.getNodeById(selection.extent.nodeId);
  if (node is! ParagraphNode || node.getMetadataValue('blockType') != blockquoteAttribution) {
    return ExecutionInstruction.continueExecution;
  }

  final caretPosition = selection.extent.nodePosition;
  if (caretPosition is! TextNodePosition) {
    return ExecutionInstruction.continueExecution;
  }

  final newNodeId = Editor.createNodeId();
  editContext.editor.execute([
    InsertNewlineAtCaretRequest(newNodeId),
  ]);

  return ExecutionInstruction.haltExecution;
}
