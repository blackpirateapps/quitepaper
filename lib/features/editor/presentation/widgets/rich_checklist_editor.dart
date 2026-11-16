import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../features/tags/domain/phosphor_icons.dart';
import '../../application/rich_document_controller.dart';
import '../../domain/document_selection.dart';
import '../../domain/markdown_styles.dart';
import '../../domain/rich_block.dart';
import '../../domain/rich_inline.dart';
import '../../domain/text_attributes.dart';

/// Dedicated visual editor widget for checklist task items in Quiet Paper's Visual mode.
///
/// Each checklist item is rendered as a clean, baseline-aligned row with a clickable
/// Phosphor checkbox icon on the left and a dedicated [TextField] on the right.
///
/// Architectural invariants:
/// - The caret is physically inside the [TextField], entirely separate from the checkbox icon.
/// - Never uses `\uFFFC` placeholder characters or inline `WidgetSpan` hacks.
/// - Pressing Enter at the end of an item creates a new checklist item with a checkbox and focuses it.
/// - Pressing Enter on an empty checklist item exits checklist mode to a standard paragraph.
/// - Pressing Backspace at offset 0 of an empty item deletes it or exits to a paragraph.
class RichChecklistEditor extends StatefulWidget {
  const RichChecklistEditor({
    super.key,
    required this.controller,
    required this.blockIndices,
    this.focusNode,
    this.readOnly = false,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onKeyEvent,
    this.onPaste,
  });

  final RichDocumentController controller;
  final List<int> blockIndices;
  final FocusNode? focusNode;
  final bool readOnly;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final FocusOnKeyEventCallback? onKeyEvent;
  final VoidCallback? onPaste;

  @override
  State<RichChecklistEditor> createState() => _RichChecklistEditorState();
}

class _RichChecklistEditorState extends State<RichChecklistEditor> {
  final Map<String, _ChecklistItemTextController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, VoidCallback> _focusListeners = {};
  final Set<FocusNode> _ownedFocusNodes = {};
  bool _isInternalUpdate = false;
  bool _isReconcilingStructure = false;
  RichDocumentSelection? _lastFocusSelection;

  @override
  void initState() {
    super.initState();
    _syncItems();
    widget.controller.addListener(_onDocumentControllerChanged);
    _checkSelectionFocus();
  }

  @override
  void didUpdateWidget(RichChecklistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onDocumentControllerChanged);
      widget.controller.addListener(_onDocumentControllerChanged);
    }
    _syncItems(rebuildSpans: false);
    _checkSelectionFocus();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onDocumentControllerChanged);
    for (final entry in _focusNodes.entries) {
      entry.value.removeListener(_focusListeners[entry.key]!);
      if (_ownedFocusNodes.remove(entry.value)) entry.value.dispose();
    }
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _focusNodes.clear();
    _controllers.clear();
    super.dispose();
  }

  void _syncItems({bool rebuildSpans = true}) {
    _isInternalUpdate = true;
    try {
      final doc = widget.controller.document;
      final currentBlockIds = <String>{};

      for (final idx in widget.blockIndices) {
        if (idx >= doc.blocks.length) continue;
        final block = doc.blocks[idx];
        if (block is! ChecklistItemBlock) continue;
        currentBlockIds.add(block.id);

        if (!_controllers.containsKey(block.id)) {
          final ctrl = _ChecklistItemTextController(
            block: block,
            contextGetter: () => context,
            stylesGetter: () => widget.controller.styles,
          );
          ctrl.addListener(() => _onTextChanged(block.id, ctrl));
          _controllers[block.id] = ctrl;
          if (widget.controller.selection.base.blockId == block.id) {
            _lastFocusSelection = null;
          }
        } else {
          final ctrl = _controllers[block.id]!;
          ctrl.block = block;
          if (ctrl.text != block.plainText) {
            final sel = ctrl.selection;
            ctrl.value = TextEditingValue(
              text: block.plainText,
              selection: TextSelection(
                baseOffset: sel.baseOffset.clamp(0, block.plainText.length),
                extentOffset: sel.extentOffset.clamp(0, block.plainText.length),
              ),
            );
          } else if (rebuildSpans) {
            ctrl.markNeedsRebuild();
          }
        }

        final externalNode = idx == 0 ? widget.focusNode : null;
        final existingNode = _focusNodes[block.id];
        if (existingNode == null ||
            (externalNode != null && existingNode != externalNode) ||
            (externalNode == null && !_ownedFocusNodes.contains(existingNode))) {
          if (existingNode != null) {
            existingNode.removeListener(_focusListeners.remove(block.id)!);
            if (_ownedFocusNodes.remove(existingNode)) existingNode.dispose();
          }
          final ctrl = _controllers[block.id]!;
          final node = externalNode ?? FocusNode();
          if (externalNode == null) _ownedFocusNodes.add(node);
          void onFocus() => _onFocusChanged(block.id, ctrl, node);
          _focusListeners[block.id] = onFocus;
          node.addListener(onFocus);
          _focusNodes[block.id] = node;
          if (widget.controller.selection.base.blockId == block.id) {
            _lastFocusSelection = null;
          }
        }
      }

      // Clean up removed blocks
      final removedIds = _controllers.keys.where((id) => !currentBlockIds.contains(id)).toList();
      for (final id in removedIds) {
        final node = _focusNodes[id];
        node?.removeListener(_focusListeners.remove(id)!);
        if (node != null && _ownedFocusNodes.remove(node)) node.dispose();
        _focusNodes.remove(id);
        _controllers[id]?.dispose();
        _controllers.remove(id);
      }
    } finally {
      _isInternalUpdate = false;
    }
  }

  void _onDocumentControllerChanged() {
    if (_isInternalUpdate) return;
    if (!mounted) return;

    // The parent rebuild supplies current indices after structural edits.
    // Reading the old indices here can dispose or update the wrong item.
    final doc = widget.controller.document;
    final ids = widget.blockIndices
        .where((index) => index < doc.blocks.length && doc.blocks[index] is ChecklistItemBlock)
        .map((index) => doc.blocks[index].id)
        .toSet();
    if (!setEquals(ids, _controllers.keys.toSet())) {
      _isReconcilingStructure = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isReconcilingStructure = false;
      });
      return;
    }
    _syncItems();

    _checkSelectionFocus();
  }

  void _checkSelectionFocus() {
    if (_isInternalUpdate) return;
    final sel = widget.controller.selection;
    if (sel == _lastFocusSelection) return;
    _lastFocusSelection = sel;
    final doc = widget.controller.document;
    final blockIdx = sel.base.blockIndex;
    if (widget.blockIndices.contains(blockIdx) && blockIdx < doc.blocks.length) {
      final block = doc.blocks[blockIdx];
      final fn = _focusNodes[block.id];
      final ctrl = _controllers[block.id];
      if (fn != null && ctrl != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || widget.readOnly ||
              widget.controller.selection != sel ||
              _focusNodes[block.id] != fn) {
            return;
          }
          final selection = TextSelection(
            baseOffset: sel.base.offset.clamp(0, ctrl.text.length),
            extentOffset: sel.extent.offset.clamp(0, ctrl.text.length),
            affinity: sel.affinity,
          );
          // Apply before focus listeners publish the previous local caret.
          _isInternalUpdate = true;
          try {
            if (ctrl.selection != selection) ctrl.selection = selection;
            if (!fn.hasFocus) fn.requestFocus();
          } finally {
            _isInternalUpdate = false;
          }
          widget.onActiveTargetChanged?.call(ctrl, fn);
        });
      }
    }
  }

  void _onFocusChanged(String blockId, _ChecklistItemTextController ctrl, FocusNode fn) {
    if (fn.hasFocus && !_isInternalUpdate && !_isReconcilingStructure) {
      final blockIndex = widget.controller.document.blocks.indexWhere((b) => b.id == blockId);
      if (blockIndex < 0) return;
      final offset = ctrl.selection.isValid ? ctrl.selection.baseOffset : ctrl.text.length;
      final currentSel = widget.controller.selection;
      if (currentSel.base.blockIndex != blockIndex ||
          currentSel.base.blockId != blockId ||
          currentSel.base.offset != offset ||
          !currentSel.isCollapsed) {
        _isInternalUpdate = true;
        try {
          widget.controller.updateSelection(
            RichDocumentSelection.collapsed(
              RichDocumentPosition(
                blockIndex: blockIndex,
                blockId: blockId,
                offset: offset,
              ),
            ),
          );
        } finally {
          _isInternalUpdate = false;
        }
      }
      widget.onActiveTargetChanged?.call(ctrl, fn);
    }
  }

  void _onTextChanged(String blockId, _ChecklistItemTextController ctrl) {
    if (_isInternalUpdate || _isReconcilingStructure) return;
    final fn = _focusNodes[blockId];
    if (fn == null || !fn.hasFocus) return;

    final doc = widget.controller.document;
    final blockIndex = doc.blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex < 0) return;
    final block = doc.blocks[blockIndex];
    if (block is! ChecklistItemBlock) return;

    final newText = ctrl.text;
    if (newText != block.plainText) {
      _isInternalUpdate = true;
      try {
        final updatedSpans = _spliceSpans(
          spans: block.spans,
          oldText: block.plainText,
          newText: newText,
          defaultAttributes: widget.controller.typingAttributes,
        );
        widget.controller.updateBlockSpans(blockIndex, updatedSpans);
        ctrl.block = widget.controller.document.blocks[blockIndex] as ChecklistItemBlock;
        widget.onChanged?.call(widget.controller.toMarkdown());
      } finally {
        _isInternalUpdate = false;
      }
    }

    final sel = ctrl.selection;
    if (sel.isValid) {
      final currentSel = widget.controller.selection;
      final newBaseOffset = sel.baseOffset.clamp(0, newText.length);
      final newExtentOffset = sel.extentOffset.clamp(0, newText.length);
      if (currentSel.base.blockIndex != blockIndex ||
          currentSel.base.offset != newBaseOffset ||
          currentSel.extent.offset != newExtentOffset) {
        _isInternalUpdate = true;
        try {
          widget.controller.updateSelection(
            RichDocumentSelection(
              base: RichDocumentPosition(
                blockIndex: blockIndex,
                blockId: blockId,
                offset: newBaseOffset,
              ),
              extent: RichDocumentPosition(
                blockIndex: blockIndex,
                blockId: blockId,
                offset: newExtentOffset,
              ),
              affinity: sel.affinity,
            ),
          );
        } finally {
          _isInternalUpdate = false;
        }
      }
    }
  }

  void _toggleChecked(int blockIndex) {
    if (widget.readOnly) return;
    widget.controller.toggleChecklistItemChecked(blockIndex);
    widget.onChanged?.call(widget.controller.toMarkdown());
  }

  KeyEventResult _handleEnter(int blockIndex, ChecklistItemBlock block, _ChecklistItemTextController ctrl) {
    if (widget.readOnly) return KeyEventResult.ignored;
    final sel = ctrl.selection;
    final cursorOffset = sel.isValid ? sel.start.clamp(0, block.plainText.length) : block.plainText.length;

    // If checklist item is empty: exit checklist -> converts to paragraph
    if (block.plainText.trim().isEmpty) {
      widget.controller.handleEnterAt(RichDocumentPosition(
        blockIndex: blockIndex,
        blockId: block.id,
        offset: 0,
      ));
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    // Non-empty checklist item: split or create new checklist item below
    widget.controller.handleEnterAt(RichDocumentPosition(
      blockIndex: blockIndex,
      blockId: block.id,
      offset: cursorOffset,
    ), replacementEnd: sel.isValid ? sel.end : cursorOffset);

    widget.onChanged?.call(widget.controller.toMarkdown());
    return KeyEventResult.handled;
  }

  KeyEventResult _handleBackspace(int blockIndex, int itemPosition, ChecklistItemBlock block, _ChecklistItemTextController ctrl) {
    if (widget.readOnly) return KeyEventResult.ignored;
    final sel = ctrl.selection;
    if (!sel.isValid || !sel.isCollapsed || sel.baseOffset != 0) {
      return KeyEventResult.ignored;
    }

    // At offset 0 of an empty item:
    if (block.plainText.isEmpty) {
      // If there is a preceding block, delete this empty item and focus preceding block
      if (blockIndex > 0) {
        final prevBlock = widget.controller.document.blocks[blockIndex - 1];
        final prevLength = prevBlock.plainText.length;
        final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
        newBlocks.removeAt(blockIndex);
        widget.controller.setDocument(
          widget.controller.document.copyWith(blocks: newBlocks),
          newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
            blockIndex: blockIndex - 1,
            blockId: prevBlock.id,
            offset: prevLength,
          )),
        );
        widget.onChanged?.call(widget.controller.toMarkdown());
        return KeyEventResult.handled;
      }

      // If it's the very first block, convert to paragraph
      widget.controller.handleBackspaceAtStart();
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    // At offset 0 of a non-empty item:
    // If there is a preceding checklist item, merge this item's text into it
    if (itemPosition > 0) {
      final prevBlockIdx = widget.blockIndices[itemPosition - 1];
      final prevBlock = widget.controller.document.blocks[prevBlockIdx];
      if (prevBlock is ChecklistItemBlock) {
        final prevLength = prevBlock.plainText.length;
        final mergedSpans = [...prevBlock.spans, ...block.spans].normalized();
        final updatedPrev = prevBlock.copyWith(spans: mergedSpans);
        final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
        newBlocks[prevBlockIdx] = updatedPrev;
        newBlocks.removeAt(blockIndex);
        widget.controller.setDocument(
          widget.controller.document.copyWith(blocks: newBlocks),
          newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
            blockIndex: prevBlockIdx,
            blockId: prevBlock.id,
            offset: prevLength,
          )),
        );
        widget.onChanged?.call(widget.controller.toMarkdown());
        return KeyEventResult.handled;
      }
    }

    // Otherwise, convert item to paragraph
    widget.controller.handleBackspaceAtStart();
    widget.onChanged?.call(widget.controller.toMarkdown());
    return KeyEventResult.handled;
  }

  KeyEventResult _handleDelete(int blockIndex, ChecklistItemBlock block, _ChecklistItemTextController ctrl) {
    if (widget.readOnly || !ctrl.selection.isValid ||
        !ctrl.selection.isCollapsed || ctrl.selection.extentOffset != ctrl.text.length) {
      return KeyEventResult.ignored;
    }
    final doc = widget.controller.document;
    if (blockIndex + 1 >= doc.blocks.length) return KeyEventResult.ignored;
    final next = doc.blocks[blockIndex + 1];
    if (next is! ChecklistItemBlock) return KeyEventResult.ignored;
    final blocks = List<RichBlock>.from(doc.blocks);
    blocks[blockIndex] = block.copyWith(spans: [...block.spans, ...next.spans].normalized());
    blocks.removeAt(blockIndex + 1);
    widget.controller.setDocument(doc.copyWith(blocks: blocks),
      newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
        blockIndex: blockIndex, blockId: block.id, offset: ctrl.text.length,
      )),
    );
    widget.onChanged?.call(widget.controller.toMarkdown());
    return KeyEventResult.handled;
  }

  bool _atVerticalBoundary(int position, {required bool up}) {
    final block = widget.controller.document.blocks[widget.blockIndices[position]];
    final ctrl = _controllers[block.id]!;
    if (!ctrl.selection.isValid || !ctrl.selection.isCollapsed) return false;
    final state = _focusNodes[block.id]?.context?.findAncestorStateOfType<EditableTextState>();
    if (state == null) return ctrl.selection.extentOffset == (up ? 0 : ctrl.text.length);
    final render = state.renderEditable;
    final caret = render.getLocalRectForCaret(TextPosition(offset: ctrl.selection.extentOffset));
    final boundary = render.getLocalRectForCaret(TextPosition(offset: up ? 0 : ctrl.text.length));
    return (caret.top - boundary.top).abs() < 0.5;
  }

  KeyEventResult _moveVertically(int position, {required bool up}) {
    if (!_atVerticalBoundary(position, up: up)) return KeyEventResult.ignored;
    final target = position + (up ? -1 : 1);
    if (target < 0 || target >= widget.blockIndices.length) return KeyEventResult.ignored;
    final doc = widget.controller.document;
    final currentId = doc.blocks[widget.blockIndices[position]].id;
    final targetId = doc.blocks[widget.blockIndices[target]].id;
    final ctrl = _controllers[targetId]!;
    final node = _focusNodes[targetId]!;
    final currentState = _focusNodes[currentId]?.context?.findAncestorStateOfType<EditableTextState>();
    final targetState = node.context?.findAncestorStateOfType<EditableTextState>();
    var offset = up ? ctrl.text.length : 0;
    if (currentState != null && targetState != null) {
      final currentRender = currentState.renderEditable;
      final targetRender = targetState.renderEditable;
      final caret = currentRender.getLocalRectForCaret(
        TextPosition(offset: _controllers[currentId]!.selection.extentOffset),
      );
      final boundary = targetRender.getLocalRectForCaret(TextPosition(offset: offset));
      final x = currentRender.localToGlobal(caret.center).dx;
      final y = targetRender.localToGlobal(boundary.center).dy;
      offset = targetRender.getPositionForPoint(Offset(x, y)).offset.clamp(0, ctrl.text.length);
    }
    ctrl.selection = TextSelection.collapsed(offset: offset);
    node.requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final styles = widget.controller.styles ?? MarkdownStyles.fromColors(colors);
    final doc = widget.controller.document;

    final children = <Widget>[];

    for (var i = 0; i < widget.blockIndices.length; i++) {
      final blockIdx = widget.blockIndices[i];
      if (blockIdx >= doc.blocks.length) continue;
      final block = doc.blocks[blockIdx];
      if (block is! ChecklistItemBlock) continue;

      final ctrl = _controllers[block.id];
      final fn = _focusNodes[block.id];
      if (ctrl == null || fn == null) continue;

      final isChecked = block.isChecked;

      children.add(
        Padding(
          key: ValueKey(block.id),
          padding: EdgeInsets.only(left: block.indent * 24.0, top: 2, bottom: 2),
          child: Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent) {
                if ((event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                  return _handleEnter(blockIdx, block, ctrl);
                } else if (event.logicalKey == LogicalKeyboardKey.delete) {
                  return _handleDelete(blockIdx, block, ctrl);
                } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
                  return _handleBackspace(blockIdx, i, block, ctrl);
                } else if (!HardwareKeyboard.instance.isShiftPressed &&
                    !HardwareKeyboard.instance.isControlPressed &&
                    !HardwareKeyboard.instance.isMetaPressed &&
                    !HardwareKeyboard.instance.isAltPressed) {
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    return _moveVertically(i, up: true);
                  } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    return _moveVertically(i, up: false);
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
                const SingleActivator(LogicalKeyboardKey.keyC, control: true, shift: true): widget.controller.toggleChecklist,
                const SingleActivator(LogicalKeyboardKey.keyC, meta: true, shift: true): widget.controller.toggleChecklist,
                const SingleActivator(LogicalKeyboardKey.keyZ, control: true): widget.controller.undo,
                const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): widget.controller.undo,
                const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): widget.controller.redo,
                const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): widget.controller.redo,
                const SingleActivator(LogicalKeyboardKey.keyY, control: true): widget.controller.redo,
                const SingleActivator(LogicalKeyboardKey.keyY, meta: true): widget.controller.redo,
                if (widget.onPaste != null) ...{
                  const SingleActivator(LogicalKeyboardKey.keyV, control: true): widget.onPaste!,
                  const SingleActivator(LogicalKeyboardKey.keyV, meta: true): widget.onPaste!,
                },
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dedicated Checkbox Icon Button (Physical isolation from text)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.5, right: 8.0),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.readOnly ? null : () => _toggleChecked(blockIdx),
                      child: MouseRegion(
                        cursor: widget.readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
                        child: Icon(
                          isChecked
                              ? PhosphorIconsRegular.checkSquare
                              : PhosphorIconsRegular.square,
                          size: 20,
                          color: isChecked ? colors.textTertiary : colors.accent,
                        ),
                      ),
                    ),
                  ),

                  // Dedicated Task Text Field
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      focusNode: fn,
                      readOnly: widget.readOnly,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      cursorColor: colors.accent,
                      contextMenuBuilder: (context, editableTextState) {
                        final rawButtonItems = editableTextState.contextMenuButtonItems;
                        final buttonItems = rawButtonItems.map((item) {
                          if (item.type == ContextMenuButtonType.paste && widget.onPaste != null) {
                            return ContextMenuButtonItem(
                              type: ContextMenuButtonType.paste,
                              label: item.label,
                              onPressed: () {
                                ContextMenuController.removeAny();
                                widget.onPaste!();
                              },
                            );
                          }
                          return item;
                        }).toList();
                        return AdaptiveTextSelectionToolbar.buttonItems(
                          anchors: editableTextState.contextMenuAnchors,
                          buttonItems: buttonItems,
                        );
                      },
                      style: isChecked
                          ? styles.taskTextCompleted.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: colors.textSecondary,
                              height: 1.6,
                            )
                          : styles.body.copyWith(
                              color: colors.textPrimary,
                              height: 1.6,
                            ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        hintText: widget.blockIndices.length == 1 && block.plainText.isEmpty ? 'To-do' : null,
                        hintStyle: styles.body.copyWith(
                          color: colors.textTertiary,
                          height: 1.6,
                        ),
                      ),
                      onTap: () {
                        widget.onActiveTargetChanged?.call(ctrl, fn);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
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

      if (spanStart < deleteStart) {
        result.add(span.slice(0, deleteStart - spanStart));
      }

      if (!insertedHandled && inserted.isNotEmpty) {
        result.add(RichInlineSpan(text: inserted, attributes: defaultAttributes));
        insertedHandled = true;
      }

      if (spanEnd > deleteEnd) {
        result.add(span.slice(deleteEnd - spanStart));
      }
    }

    if (!insertedHandled && inserted.isNotEmpty) {
      result.add(RichInlineSpan(text: inserted, attributes: defaultAttributes));
    }

    return result.normalized();
  }
}

/// Custom [TextEditingController] rendering rich inline spans (bold, italic, code, links)
/// directly inside each checklist item.
class _ChecklistItemTextController extends TextEditingController {
  _ChecklistItemTextController({
    required this.block,
    required this.contextGetter,
    required this.stylesGetter,
  }) : super(text: block.plainText);

  ChecklistItemBlock block;
  final BuildContext Function() contextGetter;
  final MarkdownStyles? Function() stylesGetter;

  void markNeedsRebuild() {
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final colors = context.appColors;
    final styles = stylesGetter() ?? MarkdownStyles.fromColors(colors);
    final baseStyle = block.isChecked
        ? styles.taskTextCompleted.copyWith(
            decoration: TextDecoration.lineThrough,
            color: colors.textSecondary,
            height: 1.6,
          )
        : styles.body.copyWith(
            color: colors.textPrimary,
            height: 1.6,
          );

    return TextSpan(
      style: style,
      children: _buildInlineSpans(block.spans, baseStyle, colors),
    );
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
    for (var i = 0; i < spans.length; i++) {
      final span = spans[i];
      var spanStyle = baseStyle;
      final attr = span.attributes;

      if (attr.isBold) {
        spanStyle = spanStyle.copyWith(fontWeight: FontWeight.bold);
      }
      if (attr.isItalic) {
        spanStyle = spanStyle.copyWith(fontStyle: FontStyle.italic);
      }
      final decorations = <TextDecoration>[];
      if (block.isChecked) {
        decorations.add(TextDecoration.lineThrough);
      } else if (attr.isStrike) {
        decorations.add(TextDecoration.lineThrough);
      }
      if (attr.hasLink) {
        decorations.add(TextDecoration.underline);
      }
      if (decorations.isNotEmpty) {
        spanStyle = spanStyle.copyWith(
          decoration: TextDecoration.combine(decorations),
        );
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
