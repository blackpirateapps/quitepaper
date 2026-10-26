import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import '../../../application/rich_document_controller.dart';
import '../../../domain/document_selection.dart';
import '../../../domain/markdown_styles.dart';
import '../../../domain/rich_block.dart';
import '../../../domain/rich_inline.dart';
import '../../../domain/text_attributes.dart';
import '../link_enhance_button.dart';

/// Autonomous Flutter widget rendering an interactive checklist task block.
class ChecklistBlockWidget extends StatefulWidget {
  const ChecklistBlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  final ChecklistItemBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  @override
  State<ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<ChecklistBlockWidget> {
  late final _ChecklistTextController _textController;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _textController = _ChecklistTextController(
      block: widget.block,
      contextGetter: () => context,
      stylesGetter: () => widget.controller.styles,
    );
    _textController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(ChecklistBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block != widget.block) {
      _textController.block = widget.block;
      if (!_isInternalUpdate && _textController.text != widget.block.plainText) {
        final sel = _textController.selection;
        _isInternalUpdate = true;
        try {
          _textController.value = TextEditingValue(
            text: widget.block.plainText,
            selection: TextSelection(
              baseOffset: sel.baseOffset.clamp(0, widget.block.plainText.length),
              extentOffset: sel.extentOffset.clamp(0, widget.block.plainText.length),
            ),
          );
        } finally {
          _isInternalUpdate = false;
        }
      } else {
        _textController.markNeedsRebuild();
      }
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      widget.onActiveTargetChanged?.call(_textController, widget.focusNode);
      final sel = _textController.selection;
      if (sel.isValid) {
        widget.controller.updateSelection(
          RichDocumentSelection.collapsed(
            RichDocumentPosition(
              blockIndex: widget.blockIndex,
              blockId: widget.block.id,
              offset: sel.baseOffset.clamp(0, widget.block.plainText.length),
            ),
          ),
        );
      }
    }
  }

  void _onTextChanged() {
    if (_isInternalUpdate) return;
    final newText = _textController.text;

    if (newText != widget.block.plainText) {
      _isInternalUpdate = true;
      try {
        final updatedSpans = _spliceSpans(
          spans: widget.block.spans,
          oldText: widget.block.plainText,
          newText: newText,
          defaultAttributes: widget.controller.typingAttributes,
        );
        widget.controller.updateBlockSpans(widget.blockIndex, updatedSpans);
        widget.onChanged?.call(widget.controller.toMarkdown());
      } finally {
        _isInternalUpdate = false;
      }
    }

    final sel = _textController.selection;
    if (sel.isValid && widget.focusNode.hasFocus) {
      widget.controller.updateSelection(
        RichDocumentSelection.collapsed(
          RichDocumentPosition(
            blockIndex: widget.blockIndex,
            blockId: widget.block.id,
            offset: sel.baseOffset.clamp(0, widget.block.plainText.length),
          ),
        ),
      );
    }
  }

  void _toggleChecked() {
    if (widget.readOnly) return;
    widget.controller.toggleChecklistItemChecked(widget.blockIndex);
    widget.onChanged?.call(widget.controller.toMarkdown());
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 1. Enter key: split or exit to paragraph
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final sel = _textController.selection;
      final cursorOffset = sel.isValid ? sel.baseOffset.clamp(0, widget.block.plainText.length) : widget.block.plainText.length;
      widget.controller.handleEnterAt(RichDocumentPosition(
        blockIndex: widget.blockIndex,
        blockId: widget.block.id,
        offset: cursorOffset,
      ));
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    // 2. Backspace key at offset 0
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = _textController.selection;
      if (sel.isValid && sel.isCollapsed && sel.baseOffset == 0) {
        if (widget.block.plainText.isEmpty) {
          if (widget.blockIndex > 0) {
            final prevBlock = widget.controller.document.blocks[widget.blockIndex - 1];
            final prevLength = prevBlock.plainText.length;
            final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
            newBlocks.removeAt(widget.blockIndex);
            widget.controller.setDocument(
              widget.controller.document.copyWith(blocks: newBlocks),
              newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
                blockIndex: widget.blockIndex - 1,
                blockId: prevBlock.id,
                offset: prevLength,
              )),
            );
            widget.onChanged?.call(widget.controller.toMarkdown());
            return KeyEventResult.handled;
          }
          widget.controller.handleBackspaceAtStart();
          widget.onChanged?.call(widget.controller.toMarkdown());
          return KeyEventResult.handled;
        }

        // At offset 0 with text: merge into previous block if it is a checklist item
        if (widget.blockIndex > 0) {
          final prevBlock = widget.controller.document.blocks[widget.blockIndex - 1];
          if (prevBlock is ChecklistItemBlock) {
            final prevLength = prevBlock.plainText.length;
            final mergedSpans = [...prevBlock.spans, ...widget.block.spans].normalized();
            final updatedPrev = prevBlock.copyWith(spans: mergedSpans);
            final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
            newBlocks[widget.blockIndex - 1] = updatedPrev;
            newBlocks.removeAt(widget.blockIndex);
            widget.controller.setDocument(
              widget.controller.document.copyWith(blocks: newBlocks),
              newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
                blockIndex: widget.blockIndex - 1,
                blockId: prevBlock.id,
                offset: prevLength,
              )),
            );
            widget.onChanged?.call(widget.controller.toMarkdown());
            return KeyEventResult.handled;
          }
        }

        widget.controller.handleBackspaceAtStart();
        widget.onChanged?.call(widget.controller.toMarkdown());
        return KeyEventResult.handled;
      }
    }

    // 3. Arrow Up
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final sel = _textController.selection;
      if (sel.isValid && sel.baseOffset == 0) {
        widget.onNavigateUp?.call();
        return KeyEventResult.handled;
      }
    }

    // 4. Arrow Down
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final sel = _textController.selection;
      if (sel.isValid && sel.baseOffset >= widget.block.plainText.length) {
        widget.onNavigateDown?.call();
        return KeyEventResult.handled;
      }
    }

    // 5. Tab / Shift+Tab
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      widget.controller.indentBlock(widget.blockIndex, isShift ? -1 : 1);
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final styles = widget.controller.styles ?? MarkdownStyles.fromColors(colors);
    final isChecked = widget.block.isChecked;
    final indentPadding = widget.block.indent * 20.0;

    return Padding(
      padding: EdgeInsets.only(left: indentPadding, top: 2.0, bottom: 2.0),
      child: Focus(
        onKeyEvent: _onKeyEvent,
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
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true): widget.controller.undo,
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): widget.controller.undo,
            const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): widget.controller.redo,
            const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): widget.controller.redo,
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): widget.controller.redo,
            const SingleActivator(LogicalKeyboardKey.keyY, meta: true): widget.controller.redo,
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox icon
              Padding(
                padding: const EdgeInsets.only(top: 2.5, right: 8.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.readOnly ? null : _toggleChecked,
                  child: MouseRegion(
                    cursor: widget.readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
                    child: Icon(
                      isChecked ? PhosphorIconsRegular.checkSquare : PhosphorIconsRegular.square,
                      size: 20,
                      color: isChecked ? colors.textTertiary : colors.accent,
                    ),
                  ),
                ),
              ),

              // Task text field
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: widget.focusNode,
                  readOnly: widget.readOnly,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  cursorColor: colors.accent,
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
                    hintText: widget.block.plainText.isEmpty ? 'To-do' : null,
                    hintStyle: styles.body.copyWith(
                      color: colors.textTertiary,
                      height: 1.6,
                    ),
                  ),
                  onTap: () {
                    widget.onActiveTargetChanged?.call(_textController, widget.focusNode);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
    var currentOffset = 0;
    var insertedHandled = false;

    for (final span in spans) {
      final spanStart = currentOffset;
      final spanEnd = currentOffset + span.length;
      currentOffset = spanEnd;

      if (spanEnd <= deleteStart || spanStart >= deleteEnd) {
        if (spanStart >= deleteEnd && !insertedHandled && inserted.isNotEmpty) {
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

class _ChecklistTextController extends TextEditingController {
  _ChecklistTextController({
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
      if (block.isChecked || attr.isStrike) {
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
          backgroundColor: colors.surfaceSecondary,
          fontSize: (spanStyle.fontSize ?? 16.0) * 0.92,
        );
      }
      if (attr.hasLink) {
        spanStyle = spanStyle.copyWith(color: colors.accent);
      }
      if (attr.hasTag) {
        spanStyle = spanStyle.copyWith(
          color: colors.accent,
          fontWeight: FontWeight.w600,
        );
      }

      result.add(TextSpan(text: span.text, style: spanStyle));

      if (attr.hasLink &&
          !block.isChecked &&
          attr.linkUrl != null &&
          (attr.linkUrl!.startsWith('http://') || attr.linkUrl!.startsWith('https://'))) {
        final isLastInRun =
            i == spans.length - 1 || spans[i + 1].attributes.linkUrl != attr.linkUrl;
        if (isLastInRun) {
          result.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: LinkEnhanceButton(
                url: attr.linkUrl!,
                onEnhanced: (newTitle) async {},
              ),
            ),
          );
        }
      }
    }

    return result;
  }
}
