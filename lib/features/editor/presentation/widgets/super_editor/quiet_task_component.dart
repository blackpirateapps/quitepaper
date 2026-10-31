import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

import 'smart_task_controller.dart';

/// Custom [ComponentBuilder] for SuperEditor that renders smart checklists
/// using Quiet Paper's calm editorial style with Phosphor icons,
/// optically centered checkboxes, empty to-do placeholder ('New task...'),
/// auto-sorting on check/uncheck, smooth completion animations, and collapsible
/// completed items when count > 3.
class QuietTaskComponentBuilder implements ComponentBuilder {
  QuietTaskComponentBuilder(
    this._editor, {
    this.smartTaskController,
    this.placeholder = 'New task...',
  });

  final Editor _editor;
  final SmartTaskController? smartTaskController;
  final String placeholder;

  @override
  TaskComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! TaskNode) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.toPlainText());

    bool isCollapseSummary = false;
    bool isExpandedHeader = false;
    bool isHiddenInCollapse = false;
    int completedCount = 0;
    VoidCallback? onToggleCollapse;

    if (smartTaskController != null) {
      final block = SmartTaskController.findBlockForNode(document, node.id);
      if (block != null && block.hasCollapsibleCompleted) {
        completedCount = block.completedCount;
        final isExpanded = smartTaskController!.isBlockExpanded(block);
        final firstCompletedId = block.completedTasks.first.id;

        if (!isExpanded) {
          if (node.id == firstCompletedId) {
            isCollapseSummary = true;
            onToggleCollapse = () => smartTaskController!.toggleBlockExpansion(block, editor: _editor);
          } else if (node.isComplete) {
            isHiddenInCollapse = true;
          }
        } else {
          if (node.id == firstCompletedId) {
            isExpandedHeader = true;
            onToggleCollapse = () => smartTaskController!.toggleBlockExpansion(block, editor: _editor);
          }
        }
      }
    }

    return QuietTaskComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      indent: node.indent,
      isComplete: node.isComplete,
      setComplete: (bool isComplete) {
        if (smartTaskController != null) {
          smartTaskController!.toggleTaskCompletion(
            editor: _editor,
            nodeId: node.id,
            isComplete: isComplete,
          );
        } else {
          _editor.execute([
            ChangeTaskCompletionRequest(
              nodeId: node.id,
              isComplete: isComplete,
            ),
          ]);
        }
      },
      text: node.text,
      textDirection: textDirection,
      textAlignment: textDirection == TextDirection.ltr ? TextAlign.left : TextAlign.right,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
      isCollapseSummary: isCollapseSummary,
      isExpandedHeader: isExpandedHeader,
      isHiddenInCollapse: isHiddenInCollapse,
      completedCount: completedCount,
      onToggleCollapse: onToggleCollapse,
      placeholder: placeholder,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! TaskComponentViewModel) {
      return null;
    }

    return QuietTaskComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
    );
  }
}

/// View model configuring the visual appearance and interaction of [QuietTaskComponent].
class QuietTaskComponentViewModel extends TaskComponentViewModel {
  QuietTaskComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    required super.padding,
    super.opacity = 1.0,
    super.indent = 0,
    super.indentCalculator,
    required super.isComplete,
    required super.setComplete,
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
    this.isCollapseSummary = false,
    this.isExpandedHeader = false,
    this.isHiddenInCollapse = false,
    this.completedCount = 0,
    this.onToggleCollapse,
    this.placeholder = 'New task...',
  });

  final bool isCollapseSummary;
  final bool isExpandedHeader;
  final bool isHiddenInCollapse;
  final int completedCount;
  final VoidCallback? onToggleCollapse;
  final String placeholder;

  @override
  QuietTaskComponentViewModel copy() {
    return QuietTaskComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      opacity: opacity,
      indent: indent,
      indentCalculator: indentCalculator,
      isComplete: isComplete,
      setComplete: setComplete,
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
      isCollapseSummary: isCollapseSummary,
      isExpandedHeader: isExpandedHeader,
      isHiddenInCollapse: isHiddenInCollapse,
      completedCount: completedCount,
      onToggleCollapse: onToggleCollapse,
      placeholder: placeholder,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietTaskComponentViewModel &&
          runtimeType == other.runtimeType &&
          isCollapseSummary == other.isCollapseSummary &&
          isExpandedHeader == other.isExpandedHeader &&
          isHiddenInCollapse == other.isHiddenInCollapse &&
          completedCount == other.completedCount &&
          placeholder == other.placeholder;

  @override
  int get hashCode =>
      super.hashCode ^
      isCollapseSummary.hashCode ^
      isExpandedHeader.hashCode ^
      isHiddenInCollapse.hashCode ^
      completedCount.hashCode ^
      placeholder.hashCode;
}

/// A document component displaying an interactive checklist task
/// in Quiet Paper's aesthetic style with smooth completion animations.
class QuietTaskComponent extends StatefulWidget {
  const QuietTaskComponent({
    super.key,
    required this.viewModel,
    this.showDebugPaint = false,
  });

  final TaskComponentViewModel viewModel;
  final bool showDebugPaint;

  @override
  State<QuietTaskComponent> createState() => _QuietTaskComponentState();
}

class _QuietTaskComponentState extends State<QuietTaskComponent>
    with ProxyDocumentComponent<QuietTaskComponent>, ProxyTextComposable {
  final _textKey = GlobalKey();
  bool _isPendingAnimation = false;
  bool? _optimisticComplete;

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  @override
  void didUpdateWidget(QuietTaskComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewModel.isComplete != oldWidget.viewModel.isComplete) {
      _isPendingAnimation = false;
      _optimisticComplete = null;
    }
  }

  /// Never report a caret rectangle for collapsed/hidden tasks.
  /// This prevents SuperEditor from rendering a floating ghost caret in empty space.
  @override
  Rect getRectForPosition(NodePosition nodePosition) {
    final quietVm = widget.viewModel is QuietTaskComponentViewModel
        ? widget.viewModel as QuietTaskComponentViewModel
        : null;
    if (quietVm != null && (quietVm.isHiddenInCollapse || quietVm.isCollapseSummary)) {
      return Rect.zero;
    }
    return super.getRectForPosition(nodePosition);
  }

  /// Never report a text position for collapsed/hidden tasks.
  @override
  NodePosition? getPositionAtOffset(Offset localOffset) {
    final quietVm = widget.viewModel is QuietTaskComponentViewModel
        ? widget.viewModel as QuietTaskComponentViewModel
        : null;
    if (quietVm != null && (quietVm.isHiddenInCollapse || quietVm.isCollapseSummary)) {
      return null;
    }
    return super.getPositionAtOffset(localOffset);
  }

  bool get _isEffectiveComplete =>
      _optimisticComplete ?? widget.viewModel.isComplete;

  TextStyle _computeStyles(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    return _isEffectiveComplete
        ? style.copyWith(
            decoration: style.decoration == null
                ? TextDecoration.lineThrough
                : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
          )
        : style;
  }

  void _onCheckboxTap() {
    if (widget.viewModel.setComplete == null) return;
    final targetComplete = !_isEffectiveComplete;

    setState(() {
      _isPendingAnimation = true;
      _optimisticComplete = targetComplete;
    });

    // 250ms smooth visual dwell & fade transition before executing document move
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      widget.viewModel.setComplete!(targetComplete);
      if (mounted) {
        setState(() {
          _isPendingAnimation = false;
          _optimisticComplete = null;
        });
      }
    });
  }

  Widget _buildHiddenComponent() {
    return SizedBox(
      width: 0,
      height: 0,
      child: OverflowBox(
        minWidth: 0,
        maxWidth: 0,
        minHeight: 0,
        maxHeight: 0,
        child: Offstage(
          offstage: true,
          child: TextComponent(
            key: _textKey,
            text: widget.viewModel.text,
            textDirection: widget.viewModel.textDirection,
            textAlign: widget.viewModel.textAlignment,
            maxLines: widget.viewModel.maxLines,
            overflow: widget.viewModel.overflow,
            textStyleBuilder: _computeStyles,
            inlineWidgetBuilders: widget.viewModel.inlineWidgetBuilders,
            textSelection: widget.viewModel.selection,
            selectionColor: widget.viewModel.selectionColor,
            highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
            underlines: widget.viewModel.createUnderlines(),
            showDebugPaint: widget.showDebugPaint,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader({
    required BuildContext context,
    required AppColors colors,
    required int count,
    required bool isExpanded,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorIconsRegular.checkCircle,
                size: 17.0,
                color: colors.accent,
              ),
              const SizedBox(width: 8.0),
              Text(
                '$count completed items',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(width: 4.0),
              Icon(
                isExpanded
                    ? PhosphorIconsBold.caretDown
                    : PhosphorIconsBold.caretRight,
                size: 13.0,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskRow(BuildContext context, AppColors colors) {
    final quietVm = widget.viewModel is QuietTaskComponentViewModel
        ? widget.viewModel as QuietTaskComponentViewModel
        : null;
    final placeholder = quietVm?.placeholder ?? 'New task...';

    // Calculate optical top padding for checkbox based on typography:
    // (firstLineHeight - iconSize) / 2 centers the icon with the first line of text and caret.
    final style = widget.viewModel.textStyleBuilder({});
    final fontSize = style.fontSize ?? 18.0;
    final lineHeight = style.height ?? 1.6;
    final firstLineHeight = fontSize * lineHeight;
    const checkboxSize = 20.0;
    final topPadding = ((firstLineHeight - checkboxSize) / 2).clamp(0.0, double.infinity);

    return Directionality(
      textDirection: widget.viewModel.textDirection,
      child: AnimatedOpacity(
        opacity: _isPendingAnimation ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: widget.viewModel.indentCalculator(
                  widget.viewModel.textStyleBuilder({}),
                  widget.viewModel.indent,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: topPadding, right: 8.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.viewModel.setComplete != null ? _onCheckboxTap : null,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      width: checkboxSize,
                      height: checkboxSize,
                      alignment: Alignment.center,
                      child: Icon(
                        _isEffectiveComplete
                            ? PhosphorIconsFill.checkSquare
                            : PhosphorIconsRegular.square,
                        size: checkboxSize,
                        color: _isEffectiveComplete
                            ? colors.accent
                            : colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.topLeft,
                  children: [
                    if (widget.viewModel.text.isEmpty)
                      IgnorePointer(
                        child: Text(
                          placeholder,
                          style: _computeStyles({}).copyWith(
                            color: colors.textTertiary.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    TextComponent(
                      key: _textKey,
                      text: widget.viewModel.text,
                      textDirection: widget.viewModel.textDirection,
                      textAlign: widget.viewModel.textAlignment,
                      maxLines: widget.viewModel.maxLines,
                      overflow: widget.viewModel.overflow,
                      textStyleBuilder: _computeStyles,
                      inlineWidgetBuilders: widget.viewModel.inlineWidgetBuilders,
                      textSelection: widget.viewModel.selection,
                      selectionColor: widget.viewModel.selectionColor,
                      highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
                      underlines: widget.viewModel.createUnderlines(),
                      showDebugPaint: widget.showDebugPaint,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final quietVm = widget.viewModel is QuietTaskComponentViewModel
        ? widget.viewModel as QuietTaskComponentViewModel
        : null;

    if (quietVm != null && quietVm.isHiddenInCollapse) {
      return _buildHiddenComponent();
    }

    if (quietVm != null && quietVm.isCollapseSummary) {
      return SizeChangedLayoutNotifier(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryHeader(
                context: context,
                colors: colors,
                count: quietVm.completedCount,
                isExpanded: false,
                onTap: quietVm.onToggleCollapse,
              ),
              _buildHiddenComponent(),
            ],
          ),
        ),
      );
    }

    if (quietVm != null && quietVm.isExpandedHeader) {
      return SizeChangedLayoutNotifier(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: _buildSummaryHeader(
                  context: context,
                  colors: colors,
                  count: quietVm.completedCount,
                  isExpanded: true,
                  onTap: quietVm.onToggleCollapse,
                ),
              ),
              _buildTaskRow(context, colors),
            ],
          ),
        ),
      );
    }

    return _buildTaskRow(context, colors);
  }
}

/// A specialized [DocumentNodeMarkdownSerializer] for [TaskNode]s that ensures
/// a blank line before following non-task nodes (such as [ParagraphNode]s).
///
/// In CommonMark, a list item followed immediately by a line of text without
/// an empty line is parsed as a lazy multiline continuation of the list item.
/// By appending a trailing newline when the following node is not a task or list item,
/// this serializer guarantees a blank line (`\n\n`) is written between the checklist
/// and the following paragraph.
class QuietTaskNodeSerializer extends NodeTypedDocumentNodeMarkdownSerializer<TaskNode> {
  const QuietTaskNodeSerializer();

  @override
  String doSerialization(
    Document document,
    TaskNode node, {
    NodeSelection? selection,
  }) {
    if (selection != null && selection is! TextNodeSelection) {
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      return '';
    }
    final textToConvert = textSelection != null
        ? node.text.copyText(textSelection.start, textSelection.end)
        : node.text;

    final markdownText = textToConvert.toMarkdown();
    final taskMarkdown = '- [${node.isComplete ? 'x' : ' '}] $markdownText';

    final nodeIndex = document.getNodeIndexById(node.id);
    final isFollowedByNonList = nodeIndex < document.nodeCount - 1 &&
        document.getNodeAt(nodeIndex + 1) is! TaskNode &&
        document.getNodeAt(nodeIndex + 1) is! ListItemNode;

    if (isFollowedByNonList) {
      return '$taskMarkdown\n';
    }

    return taskMarkdown;
  }
}
