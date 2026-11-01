import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:super_editor/super_editor.dart';

/// Component builder that produces [QuietHorizontalRuleComponent]s for
/// [HorizontalRuleNode]s.
class QuietHorizontalRuleComponentBuilder implements ComponentBuilder {
  const QuietHorizontalRuleComponentBuilder(this.editor);

  final Editor editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! HorizontalRuleNode) {
      return null;
    }

    return HorizontalRuleComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      selectionColor: const Color(0x00000000),
      caretColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! HorizontalRuleComponentViewModel) {
      return null;
    }

    return QuietHorizontalRuleComponent(
      componentKey: componentContext.componentKey,
      editor: editor,
      nodeId: componentViewModel.nodeId,
      selection: componentViewModel.selection?.nodeSelection
          as UpstreamDownstreamNodeSelection?,
      selectionColor: componentViewModel.selectionColor,
      opacity: componentViewModel.opacity,
    );
  }
}

/// A horizontal rule (divider) component that integrates with Quiet Paper's
/// theme and enables intuitive interaction without blocking pointer events.
class QuietHorizontalRuleComponent extends StatelessWidget {
  const QuietHorizontalRuleComponent({
    super.key,
    required this.componentKey,
    required this.editor,
    required this.nodeId,
    this.color,
    this.thickness = 1,
    this.selectionColor = Colors.transparent,
    this.selection,
    this.opacity = 1.0,
  });

  final GlobalKey componentKey;
  final Editor editor;
  final String nodeId;
  final Color? color;
  final double thickness;
  final Color selectionColor;
  final UpstreamDownstreamNodeSelection? selection;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final dividerColor = color ?? colors.divider;

    return SelectableBox(
      selection: selection,
      selectionColor: selectionColor,
      child: BoxComponent(
        key: componentKey,
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            color: dividerColor,
            thickness: thickness,
            height: 16,
          ),
        ),
      ),
    );
  }
}

/// Content tap delegate that catches taps on or below a terminal
/// [HorizontalRuleNode] and spawns an editable [ParagraphNode] following it.
class QuietDividerTapHandler extends ContentTapDelegate {
  QuietDividerTapHandler({
    required this.editContext,
  });

  final SuperEditorContext editContext;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final tapPosition = details.documentLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    if (tapPosition == null) {
      return TapHandlingInstruction.continueHandling;
    }

    final editor = editContext.editor;
    final document = editContext.document;

    final node = document.getNodeById(tapPosition.nodeId);
    if (node is! HorizontalRuleNode) {
      return TapHandlingInstruction.continueHandling;
    }

    final nextNode = document.getNodeAfterById(node.id);
    if (nextNode == null) {
      // The user tapped on or below the terminal divider.
      // Append an empty paragraph and place the caret there.
      final newParagraphId = Editor.createNodeId();
      editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: node.id,
          newNode: ParagraphNode(
            id: newParagraphId,
            text: AttributedText(),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newParagraphId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);

      return TapHandlingInstruction.halt;
    }

    return TapHandlingInstruction.continueHandling;
  }
}

QuietDividerTapHandler quietDividerTapHandlerFactory(SuperEditorContext editContext) =>
    QuietDividerTapHandler(editContext: editContext);

/// [SuperEditorKeyboardAction] that handles navigating past dividers, pressing
/// Enter on dividers, and typing immediately after dividers.
ExecutionInstruction handleDividerKeyboardActions({
  required SuperEditorContext editContext,
  required KeyEvent keyEvent,
}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
    return ExecutionInstruction.continueExecution;
  }

  final selection = editContext.composer.selection;
  if (selection == null) {
    return ExecutionInstruction.continueExecution;
  }

  final document = editContext.document;
  final editor = editContext.editor;

  final selectedNode = document.getNodeById(selection.extent.nodeId);
  if (selectedNode is HorizontalRuleNode) {
    final nextNode = document.getNodeAfterById(selectedNode.id);

    // 1. Enter pressed on divider -> insert empty paragraph after divider and move caret there.
    if (keyEvent.logicalKey == LogicalKeyboardKey.enter ||
        keyEvent.logicalKey == LogicalKeyboardKey.numpadEnter) {
      final newParagraphId = Editor.createNodeId();
      editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: selectedNode.id,
          newNode: ParagraphNode(
            id: newParagraphId,
            text: AttributedText(),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newParagraphId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);
      return ExecutionInstruction.haltExecution;
    }

    // 2. ArrowDown pressed on terminal divider -> insert empty paragraph after divider and move caret there.
    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowDown && nextNode == null) {
      final newParagraphId = Editor.createNodeId();
      editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: selectedNode.id,
          newNode: ParagraphNode(
            id: newParagraphId,
            text: AttributedText(),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newParagraphId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);
      return ExecutionInstruction.haltExecution;
    }

    // 3. ArrowRight pressed on terminal divider -> insert empty paragraph after divider and move caret there.
    if (keyEvent.logicalKey == LogicalKeyboardKey.arrowRight && nextNode == null) {
      final newParagraphId = Editor.createNodeId();
      editor.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: selectedNode.id,
          newNode: ParagraphNode(
            id: newParagraphId,
            text: AttributedText(),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: newParagraphId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
        const ClearComposingRegionRequest(),
      ]);
      return ExecutionInstruction.haltExecution;
    }

    // 4. Typing a printable character when divider is selected.
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      const arrowKeys = [
        LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowUp,
        LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowRight,
      ];
      var character = keyEvent.character;
      if (character != null &&
          character.isNotEmpty &&
          !LogicalKeyboardKey.isControlCharacter(character) &&
          !arrowKeys.contains(keyEvent.logicalKey) &&
          !_isBlacklistedCharacter(character)) {
        if (character == 'Tab') {
          character = ' ';
        }

        final newParagraphId = Editor.createNodeId();
        editor.execute([
          InsertNodeAfterNodeRequest(
            existingNodeId: selectedNode.id,
            newNode: ParagraphNode(
              id: newParagraphId,
              text: AttributedText(character),
            ),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: newParagraphId,
                nodePosition: TextNodePosition(offset: character.length),
              ),
            ),
            SelectionChangeType.insertContent,
            SelectionReason.userInteraction,
          ),
          const ClearComposingRegionRequest(),
        ]);
        return ExecutionInstruction.haltExecution;
      }
    }
  }

  return ExecutionInstruction.continueExecution;
}

bool _isBlacklistedCharacter(String character) {
  if (character.length > 1 &&
      character != 'Tab' &&
      character.codeUnitAt(0) >= 0x41 &&
      character.codeUnitAt(0) <= 0x5a) {
    return true;
  }
  return false;
}

/// Plugin that equips SuperEditor with divider navigation and typing behaviors.
class QuietDividerPlugin extends SuperEditorPlugin {
  QuietDividerPlugin();

  @override
  List<SuperEditorKeyboardAction> get keyboardActions => [
    handleDividerKeyboardActions,
  ];
}
