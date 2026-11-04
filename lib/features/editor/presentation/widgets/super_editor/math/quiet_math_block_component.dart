import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_radii.dart';
import 'package:quitepaper/core/widgets/quiet_button.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/settings/application/typography_provider.dart';
import 'package:quitepaper/features/tags/domain/phosphor_icons.dart';
import 'package:super_editor/super_editor.dart';

import 'quiet_math_block_node.dart';

/// Custom [ComponentBuilder] for SuperEditor that renders [QuietMathBlockNode]
/// as an editorial mathematical formula card with tap-to-edit inline toggle.
class QuietMathBlockComponentBuilder implements ComponentBuilder {
  const QuietMathBlockComponentBuilder(this._editor);

  final Editor _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! QuietMathBlockNode) {
      return null;
    }

    return QuietMathBlockComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: const EdgeInsets.symmetric(vertical: 4),
      latex: node.latex,
      delimiterType: node.delimiterType,
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! QuietMathBlockComponentViewModel) {
      return null;
    }

    final node = _editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! QuietMathBlockNode) {
      return null;
    }

    return BoxComponent(
      key: componentContext.componentKey,
      isVisuallySelectable: true,
      child: QuietMathBlockComponent(
        key: ValueKey('quiet_math_${componentViewModel.nodeId}'),
        viewModel: componentViewModel,
        editor: _editor,
        node: node,
      ),
    );
  }
}

/// View model for [QuietMathBlockComponent].
class QuietMathBlockComponentViewModel
    extends SingleColumnLayoutComponentViewModel {
  QuietMathBlockComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.maxWidth,
    super.padding = const EdgeInsets.symmetric(vertical: 4),
    required this.latex,
    required this.delimiterType,
  });

  final String latex;
  final MathDelimiterType delimiterType;

  @override
  QuietMathBlockComponentViewModel copy() {
    return QuietMathBlockComponentViewModel(
      nodeId: nodeId,
      createdAt: createdAt,
      maxWidth: maxWidth,
      padding: padding,
      latex: latex,
      delimiterType: delimiterType,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietMathBlockComponentViewModel &&
          runtimeType == other.runtimeType &&
          latex == other.latex &&
          delimiterType == other.delimiterType;

  @override
  int get hashCode => Object.hash(super.hashCode, latex, delimiterType);
}

/// Document component displaying a LaTeX math formula in Quiet Paper.
///
/// Features:
/// - Default rendered state: beautiful TeX formula card with copy and edit actions.
/// - Tap-to-edit inline state: expands an inline TeX editor with live updating preview.
/// - Graceful fallback on syntax errors.
class QuietMathBlockComponent extends ConsumerStatefulWidget {
  const QuietMathBlockComponent({
    super.key,
    required this.viewModel,
    required this.editor,
    required this.node,
  });

  final QuietMathBlockComponentViewModel viewModel;
  final Editor editor;
  final QuietMathBlockNode node;

  @override
  ConsumerState<QuietMathBlockComponent> createState() =>
      _QuietMathBlockComponentState();
}

class _QuietMathBlockComponentState
    extends ConsumerState<QuietMathBlockComponent> {
  bool _isHovered = false;
  bool _isEditing = false;
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late MathDelimiterType _delimiterType;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void initState() {
    super.initState();
    _delimiterType = widget.node.delimiterType;
    _textController = TextEditingController(text: widget.node.latex);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(QuietMathBlockComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && widget.node.latex != oldWidget.node.latex) {
      _textController.text = widget.node.latex;
    }
    if (!_isEditing && widget.node.delimiterType != oldWidget.node.delimiterType) {
      _delimiterType = widget.node.delimiterType;
    }
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEditing() {
    widget.editor.execute([const ClearSelectionRequest()]);
    setState(() {
      _isHovered = false;
      _isEditing = true;
      _textController.text = widget.node.latex;
      _delimiterType = widget.node.delimiterType;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _cancelEditing() {
    setState(() {
      _isHovered = false;
      _isEditing = false;
      _textController.text = widget.node.latex;
      _delimiterType = widget.node.delimiterType;
    });
  }

  void _commitEditing() {
    final updatedLatex = _textController.text.trim();
    if (updatedLatex.isEmpty) {
      // Empty formula: replace with an empty paragraph node.
      widget.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: widget.node.id,
          newNode: ParagraphNode(
            id: widget.node.id,
            text: AttributedText(),
          ),
        ),
      ]);
      return;
    }

    if (updatedLatex != widget.node.latex ||
        _delimiterType != widget.node.delimiterType) {
      final updatedNode = widget.node.copyWith(
        latex: updatedLatex,
        delimiterType: _delimiterType,
      );
      widget.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: widget.node.id,
          newNode: updatedNode,
        ),
      ]);
    }

    setState(() {
      _isHovered = false;
      _isEditing = false;
    });
  }

  void _deleteNode() {
    widget.editor.execute([
      ReplaceNodeRequest(
        existingNodeId: widget.node.id,
        newNode: ParagraphNode(
          id: widget.node.id,
          text: AttributedText(),
        ),
      ),
    ]);
  }

  Future<void> _copyLatex() async {
    await Clipboard.setData(ClipboardData(text: widget.node.latex));
    if (mounted) {
      setState(() => _copied = true);
      _copyTimer?.cancel();
      _copyTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);

    if (_isEditing) {
      return _buildEditMode(colors, typography.fontSize);
    }

    return _buildRenderedMode(colors, typography.fontSize);
  }

  Widget _buildRenderedMode(AppColors colors, double baseFontSize) {
    final latex = widget.node.latex.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: _startEditing,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? colors.surfaceSecondary.withValues(alpha: 0.45)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: _isHovered
                    ? colors.divider.withValues(alpha: 0.3)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Formula body centered
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 32,
                      ),
                      child: latex.isEmpty
                          ? Text(
                              'Empty formula (tap to edit)',
                              style: TextStyle(
                                fontSize: baseFontSize,
                                fontStyle: FontStyle.italic,
                                color: colors.textSecondary.withValues(alpha: 0.7),
                              ),
                            )
                          : Math.tex(
                              latex,
                              mathStyle: MathStyle.display,
                              textStyle: TextStyle(
                                fontSize: baseFontSize * 1.15,
                                color: colors.textPrimary,
                              ),
                              onErrorFallback: (err) => _buildErrorFallback(
                                latex,
                                colors,
                                baseFontSize,
                              ),
                            ),
                    ),
                  ),
                ),

                // Floating actions pill (Copy & Edit)
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: _isHovered ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: !_isHovered,
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                          border: Border.all(
                            color: colors.divider.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.textPrimary.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MathHoverIconButton(
                              icon: _copied
                                  ? PhosphorIconsRegular.check
                                  : PhosphorIconsRegular.copy,
                              tooltip: _copied ? 'Copied' : 'Copy LaTeX',
                              isActive: _copied,
                              onPressed: _copyLatex,
                            ),
                            const SizedBox(width: 2),
                            _MathHoverIconButton(
                              icon: PhosphorIconsRegular.pencilSimple,
                              tooltip: 'Edit Formula',
                              onPressed: _startEditing,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditMode(AppColors colors, double baseFontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceSecondary,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: colors.accent.withValues(alpha: 0.7),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Delimiter switcher and actions
            Row(
              children: [
                _buildDelimiterPill(
                  label: r'\[ \]',
                  selected: _delimiterType == MathDelimiterType.brackets,
                  onTap: () => setState(() => _delimiterType = MathDelimiterType.brackets),
                  colors: colors,
                ),
                const SizedBox(width: 6),
                _buildDelimiterPill(
                  label: r'$$',
                  selected: _delimiterType == MathDelimiterType.dollars,
                  onTap: () => setState(() => _delimiterType = MathDelimiterType.dollars),
                  colors: colors,
                ),
                const SizedBox(width: 6),
                _buildDelimiterPill(
                  label: '```math',
                  selected: _delimiterType == MathDelimiterType.codeFence,
                  onTap: () => setState(() => _delimiterType = MathDelimiterType.codeFence),
                  colors: colors,
                ),
                const Spacer(),
                QuietIconButton(
                  icon: PhosphorIconsRegular.trash,
                  size: 16,
                  padding: const EdgeInsets.all(6),
                  tooltip: 'Delete Formula',
                  onPressed: _deleteNode,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // TeX Input field
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, control: true): _commitEditing,
                const SingleActivator(LogicalKeyboardKey.enter, meta: true): _commitEditing,
                const SingleActivator(LogicalKeyboardKey.escape): _cancelEditing,
              },
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: baseFontSize,
                  color: colors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: r'Enter LaTeX formula, e.g. S_{17}=\frac{17}{2}(3+99)',
                  hintStyle: TextStyle(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                    fontFamily: 'monospace',
                    fontSize: baseFontSize * 0.9,
                  ),
                  filled: true,
                  fillColor: colors.background,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide(
                      color: colors.divider.withValues(alpha: 0.4),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide(color: colors.accent, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 12),

            // Live preview
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colors.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _textController.text.trim().isEmpty
                          ? Text(
                              'Type LaTeX above to see preview',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: colors.textSecondary.withValues(alpha: 0.6),
                                fontSize: baseFontSize * 0.9,
                              ),
                            )
                          : Math.tex(
                              _textController.text.trim(),
                              mathStyle: MathStyle.display,
                              textStyle: TextStyle(
                                fontSize: baseFontSize * 1.1,
                                color: colors.textPrimary,
                              ),
                              onErrorFallback: (err) => _buildErrorFallback(
                                _textController.text.trim(),
                                colors,
                                baseFontSize,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Footer action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ctrl+Enter to save',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 12),
                QuietButton(
                  label: 'Cancel',
                  variant: QuietButtonVariant.secondary,
                  onPressed: _cancelEditing,
                ),
                const SizedBox(width: 8),
                QuietButton(
                  label: 'Done',
                  variant: QuietButtonVariant.primary,
                  onPressed: _commitEditing,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelimiterPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required AppColors colors,
  }) {
    return GestureDetector(
      onTap: () {
        onTap();
        _focusNode.requestFocus();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? colors.accent.withValues(alpha: 0.15)
              : colors.background,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(
            color: selected ? colors.accent : colors.divider.withValues(alpha: 0.4),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorFallback(
    String raw,
    AppColors colors,
    double baseFontSize,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        raw,
        style: TextStyle(
          color: colors.error,
          fontFamily: 'monospace',
          fontSize: baseFontSize * 0.9,
        ),
      ),
    );
  }
}

/// Content tap delegate that catches taps on a [QuietMathBlockNode]
/// and halts SuperEditor tap processing so the document selection does not jump
/// to the end of the page or steal focus from the math formula editor.
class QuietMathBlockTapHandler extends ContentTapDelegate {
  QuietMathBlockTapHandler({required this.editContext});

  final SuperEditorContext editContext;

  bool _isInsideMathBlock(DocumentTapDetails details) {
    final docLayout = details.documentLayout;
    final document = editContext.document;

    // 1. Direct document position lookup
    final tapPosition = docLayout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    if (tapPosition != null) {
      final node = document.getNodeById(tapPosition.nodeId);
      if (node is QuietMathBlockNode) {
        final component = docLayout.getComponentByNodeId(node.id);
        if (component != null) {
          final box = component.context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final localPos = box.globalToLocal(details.globalOffset);
            if (localPos.dy >= 0 && localPos.dy <= box.size.height) {
              return true;
            }
          }
        }
      }
    }

    // 2. Spatial hit test across any QuietMathBlockNode RenderBox
    for (final node in document) {
      if (node is QuietMathBlockNode) {
        final component = docLayout.getComponentByNodeId(node.id);
        if (component != null) {
          final box = component.context.findRenderObject() as RenderBox?;
          if (box != null && box.hasSize) {
            final localPos = box.globalToLocal(details.globalOffset);
            if (localPos.dx >= 0 &&
                localPos.dx <= box.size.width &&
                localPos.dy >= 0 &&
                localPos.dy <= box.size.height) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    if (_isInsideMathBlock(details)) {
      return TapHandlingInstruction.halt;
    }
    return TapHandlingInstruction.continueHandling;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) {
    if (_isInsideMathBlock(details)) {
      return TapHandlingInstruction.halt;
    }
    return TapHandlingInstruction.continueHandling;
  }

  @override
  TapHandlingInstruction onTripleTap(DocumentTapDetails details) {
    if (_isInsideMathBlock(details)) {
      return TapHandlingInstruction.halt;
    }
    return TapHandlingInstruction.continueHandling;
  }
}

QuietMathBlockTapHandler quietMathBlockTapHandlerFactory(SuperEditorContext editContext) =>
    QuietMathBlockTapHandler(editContext: editContext);

/// [SuperEditorKeyboardAction] that handles navigating past math blocks, pressing
/// Enter on math blocks, and typing immediately after math blocks.
ExecutionInstruction handleMathBlockKeyboardActions({
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
  if (selectedNode is QuietMathBlockNode) {
    final nextNode = document.getNodeAfterById(selectedNode.id);

    // 1. Enter pressed on math block -> insert empty paragraph after and move caret there.
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

    // 2. ArrowDown pressed on terminal math block -> insert empty paragraph after and move caret there.
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
  }

  return ExecutionInstruction.continueExecution;
}

/// [SuperEditorPlugin] that registers keyboard interaction handling for
/// [QuietMathBlockNode]s.
class QuietMathBlockPlugin extends SuperEditorPlugin {
  QuietMathBlockPlugin();

  @override
  List<SuperEditorKeyboardAction> get keyboardActions => [
    handleMathBlockKeyboardActions,
  ];
}

/// Compact action icon button used in the floating hover toolbar of math blocks.
class _MathHoverIconButton extends StatelessWidget {
  const _MathHoverIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isActive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = isActive ? colors.accent : colors.textSecondary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.borderSm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 15,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
