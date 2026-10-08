import 'package:flutter/material.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

/// Custom [ComponentBuilder] for SuperEditor that renders checklists
/// using Quiet Paper's calm editorial style with Phosphor icons,
/// tight spacing, and baseline-aligned checkboxes.
class QuietTaskComponentBuilder implements ComponentBuilder {
  QuietTaskComponentBuilder(this._editor);

  final Editor _editor;

  @override
  TaskComponentViewModel? createViewModel(Document document, DocumentNode node) {
    if (node is! TaskNode) {
      return null;
    }

    final textDirection = getParagraphDirection(node.text.toPlainText());

    return TaskComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      indent: node.indent,
      isComplete: node.isComplete,
      setComplete: (bool isComplete) {
        _editor.execute([
          ChangeTaskCompletionRequest(
            nodeId: node.id,
            isComplete: isComplete,
          ),
        ]);
      },
      text: node.text,
      textDirection: textDirection,
      textAlignment: textDirection == TextDirection.ltr ? TextAlign.left : TextAlign.right,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
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

/// A document component displaying an interactive checklist task
/// in Quiet Paper's aesthetic style.
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

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  TextStyle _computeStyles(Set<Attribution> attributions) {
    final style = widget.viewModel.textStyleBuilder(attributions);
    return widget.viewModel.isComplete
        ? style.copyWith(
            decoration: style.decoration == null
                ? TextDecoration.lineThrough
                : TextDecoration.combine([TextDecoration.lineThrough, style.decoration!]),
          )
        : style;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Directionality(
      textDirection: widget.viewModel.textDirection,
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
              padding: const EdgeInsets.only(top: 2.0, right: 8.0),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.viewModel.setComplete != null
                    ? () {
                        widget.viewModel.setComplete!(!widget.viewModel.isComplete);
                      }
                    : null,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 22.0,
                    height: 22.0,
                    alignment: Alignment.center,
                    child: Icon(
                      widget.viewModel.isComplete
                          ? PhosphorIconsFill.checkSquare
                          : PhosphorIconsRegular.square,
                      size: 20.0,
                      color: widget.viewModel.isComplete
                          ? colors.accent
                          : colors.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
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
          ],
        ),
      ),
    );
  }
}
