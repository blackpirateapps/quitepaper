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
      padding: const EdgeInsets.symmetric(vertical: 8),
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

    return QuietMathBlockComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
      editor: _editor,
      node: node,
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
    super.padding = const EdgeInsets.symmetric(vertical: 8),
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
    setState(() {
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _startEditing,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: colors.divider.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header bar with delimiter label and action buttons
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        widget.node.delimiterType.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    QuietIconButton(
                      icon: _copied ? PhosphorIconsRegular.check : PhosphorIconsRegular.copy,
                      size: 16,
                      isActive: _copied,
                      padding: const EdgeInsets.all(6),
                      tooltip: _copied ? 'Copied' : 'Copy LaTeX',
                      onPressed: _copyLatex,
                    ),
                    const SizedBox(width: 4),
                    QuietIconButton(
                      icon: PhosphorIconsRegular.pencilSimple,
                      size: 16,
                      padding: const EdgeInsets.all(6),
                      tooltip: 'Edit Formula',
                      onPressed: _startEditing,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Formula body
                Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: latex.isEmpty
                          ? Text(
                              'Empty formula (tap to edit)',
                              style: TextStyle(
                                fontSize: baseFontSize,
                                fontStyle: FontStyle.italic,
                                color: colors.textSecondary,
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
            KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.enter &&
                    (HardwareKeyboard.instance.isControlPressed ||
                        HardwareKeyboard.instance.isMetaPressed)) {
                  _commitEditing();
                } else if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  _cancelEditing();
                }
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
      onTap: onTap,
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
