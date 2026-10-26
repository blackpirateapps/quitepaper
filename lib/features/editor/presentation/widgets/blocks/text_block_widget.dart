import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import '../../../application/rich_document_controller.dart';
import '../../../domain/document_selection.dart';
import '../../../domain/markdown_styles.dart';
import '../../../domain/rich_block.dart';
import '../../../domain/rich_inline.dart';
import '../../../domain/text_attributes.dart';
import '../link_enhance_button.dart';

/// Autonomous Flutter widget rendering an individual text block
/// (Paragraph, Heading H1–H6, Bullet List, Ordered List, Quote).
class TextBlockWidget extends StatefulWidget {
  const TextBlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    required this.focusNode,
    this.readOnly = false,
    this.hintText,
    this.onActiveTargetChanged,
    this.onChanged,
    this.onNavigateUp,
    this.onNavigateDown,
  });

  final RichBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final FocusNode focusNode;
  final bool readOnly;
  final String? hintText;
  final void Function(TextEditingController controller, FocusNode focusNode)? onActiveTargetChanged;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onNavigateUp;
  final VoidCallback? onNavigateDown;

  @override
  State<TextBlockWidget> createState() => _TextBlockWidgetState();
}

class _TextBlockWidgetState extends State<TextBlockWidget> {
  late final _BlockTextEditingController _textController;
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _textController = _BlockTextEditingController(
      block: widget.block,
      contextGetter: () => context,
      stylesGetter: () => widget.controller.styles,
      controllerGetter: () => widget.controller,
    );
    _textController.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(TextBlockWidget oldWidget) {
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

    // Check for Markdown trigger auto-conversion at block start (e.g. '# ', '- ', etc.)
    if (widget.block is ParagraphBlock && newText.length >= 2) {
      if (widget.controller.handleAutoMarkdownTrigger(widget.blockIndex, newText)) {
        widget.onChanged?.call(widget.controller.toMarkdown());
        return;
      }
    }

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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // 1. Enter key: split block or convert empty list item to paragraph
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final sel = _textController.selection;
      final offset = sel.isValid ? sel.baseOffset.clamp(0, widget.block.plainText.length) : widget.block.plainText.length;
      widget.controller.handleEnterAt(RichDocumentPosition(
        blockIndex: widget.blockIndex,
        blockId: widget.block.id,
        offset: offset,
      ));
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    // 2. Backspace key at offset 0: merge with previous block or convert to paragraph
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      final sel = _textController.selection;
      if (sel.isValid && sel.isCollapsed && sel.baseOffset == 0) {
        // If empty block and not the only block in the document, delete this block
        if (widget.block.plainText.isEmpty && widget.controller.document.blocks.length > 1) {
          widget.controller.deleteBlock(widget.blockIndex);
          widget.onChanged?.call(widget.controller.toMarkdown());
          return KeyEventResult.handled;
        }

        // If non-paragraph text block, convert to paragraph
        if (widget.block is! ParagraphBlock) {
          widget.controller.convertBlockToParagraph(widget.blockIndex);
          widget.onChanged?.call(widget.controller.toMarkdown());
          return KeyEventResult.handled;
        }

        // If paragraph with previous block, merge into previous block
        if (widget.blockIndex > 0) {
          final prevBlock = widget.controller.document.blocks[widget.blockIndex - 1];
          if (prevBlock.isTextBlock) {
            final prevLen = prevBlock.plainText.length;
            final mergedSpans = [...prevBlock.spans, ...widget.block.spans].normalized();
            final updatedPrev = (prevBlock as dynamic).copyWith(spans: mergedSpans) as RichBlock;
            final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
            newBlocks[widget.blockIndex - 1] = updatedPrev;
            newBlocks.removeAt(widget.blockIndex);
            widget.controller.setDocument(
              widget.controller.document.copyWith(blocks: newBlocks),
              newSelection: RichDocumentSelection.collapsed(RichDocumentPosition(
                blockIndex: widget.blockIndex - 1,
                blockId: prevBlock.id,
                offset: prevLen,
              )),
            );
            widget.onChanged?.call(widget.controller.toMarkdown());
            return KeyEventResult.handled;
          }
        }
      }
    }

    // 3. Arrow Up: navigate to previous block
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final sel = _textController.selection;
      if (sel.isValid && sel.baseOffset == 0) {
        widget.onNavigateUp?.call();
        return KeyEventResult.handled;
      }
    }

    // 4. Arrow Down: navigate to next block
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final sel = _textController.selection;
      if (sel.isValid && sel.baseOffset >= widget.block.plainText.length) {
        widget.onNavigateDown?.call();
        return KeyEventResult.handled;
      }
    }

    // 5. Tab / Shift+Tab: Indent / un-indent lists
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      widget.controller.indentBlock(widget.blockIndex, isShift ? -1 : 1);
      widget.onChanged?.call(widget.controller.toMarkdown());
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  TextStyle _computeBaseTextStyle(BuildContext context) {
    final colors = context.appColors;
    final block = widget.block;

    if (block is HeadingBlock) {
      switch (block.level) {
        case 1:
          return AppTypography.editorH1.copyWith(color: colors.textPrimary);
        case 2:
          return AppTypography.editorH2.copyWith(color: colors.textPrimary);
        case 3:
          return AppTypography.editorH3.copyWith(color: colors.textPrimary);
        case 4:
          return AppTypography.editorH3.copyWith(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          );
        case 5:
          return AppTypography.editorH3.copyWith(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          );
        case 6:
        default:
          return AppTypography.editorH3.copyWith(
            fontSize: 14.0,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          );
      }
    }

    if (block is QuoteBlock) {
      return AppTypography.editorBody.copyWith(
        fontStyle: FontStyle.italic,
        color: colors.textSecondary,
        height: 1.6,
      );
    }

    return AppTypography.editorBody.copyWith(
      color: colors.textPrimary,
      height: 1.6,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final block = widget.block;
    final baseStyle = _computeBaseTextStyle(context);

    Widget content = Focus(
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
        child: TextField(
          controller: _textController,
          focusNode: widget.focusNode,
          readOnly: widget.readOnly,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          cursorColor: colors.accent,
          style: baseStyle,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            hintText: widget.blockIndex == 0 && block.plainText.isEmpty ? widget.hintText : null,
            hintStyle: baseStyle.copyWith(color: colors.textTertiary),
          ),
          onTap: () {
            widget.onActiveTargetChanged?.call(_textController, widget.focusNode);
          },
        ),
      ),
    );

    // List Item prefix & indent decoration
    if (block is BulletedListItemBlock) {
      final indentPadding = block.indent * 20.0;
      content = Padding(
        padding: EdgeInsets.only(left: indentPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 8.0),
              child: Text(
                '•',
                style: baseStyle.copyWith(
                  color: colors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    } else if (block is OrderedListItemBlock) {
      final indentPadding = block.indent * 20.0;
      content = Padding(
        padding: EdgeInsets.only(left: indentPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0, right: 8.0),
              child: Text(
                '${block.order}.',
                style: baseStyle.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      );
    } else if (block is QuoteBlock) {
      content = Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colors.accent.withValues(alpha: 0.6),
              width: 3.0,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 14.0, top: 2.0, bottom: 2.0),
        child: content,
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: block is HeadingBlock ? 6.0 : 2.5,
      ),
      child: content,
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

class _BlockTextEditingController extends TextEditingController {
  _BlockTextEditingController({
    required this.block,
    required this.contextGetter,
    required this.stylesGetter,
    required this.controllerGetter,
  }) : super(text: block.plainText);

  RichBlock block;
  final BuildContext Function() contextGetter;
  final MarkdownStyles? Function() stylesGetter;
  final RichDocumentController Function() controllerGetter;

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
    final baseStyle = style ?? AppTypography.editorBody.copyWith(color: colors.textPrimary);

    return TextSpan(
      style: baseStyle,
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
      if (attr.isStrike) {
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
