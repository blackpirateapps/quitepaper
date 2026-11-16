import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/rich_block.dart';
import '../../domain/document_selection.dart';
import '../../application/rich_document_controller.dart';

/// Specialized code block widget in Quiet Paper's Visual editor surface.
///
/// Features:
/// - Distinct monospace typography with subtle editorial container styling.
/// - Language indicator pill allowing quick language switching via [LanguageSelectorSheet].
/// - 1-tap Copy code action with non-intrusive feedback.
/// - Direct synchronization with [CodeBlock] in the authoritative [RichDocument].
class RichCodeBlock extends StatefulWidget {
  const RichCodeBlock({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.controller,
    required this.focusNode,
    this.onActiveTargetChanged,
    this.readOnly = false,
  });

  final CodeBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final FocusNode focusNode;
  final void Function(TextEditingController controller, FocusNode focusNode)?
  onActiveTargetChanged;
  final bool readOnly;

  @override
  State<RichCodeBlock> createState() => _RichCodeBlockState();
}

class _RichCodeBlockState extends State<RichCodeBlock> {
  late final TextEditingController _codeTextController;
  bool _isSyncing = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _codeTextController = TextEditingController.fromValue(
      TextEditingValue(
        text: widget.block.code,
        selection: const TextSelection.collapsed(offset: 0),
      ),
    );
    _codeTextController.addListener(_onCodeChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _scheduleSync();
  }

  @override
  void didUpdateWidget(RichCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final selection = widget.controller.selection;
      final current = _codeTextController.value;
      final text = widget.block.code;
      final selected =
          selection.base.blockId == widget.block.id &&
          selection.extent.blockId == widget.block.id;
      final updated = current.copyWith(
        text: text,
        selection: TextSelection(
          baseOffset:
              (selected ? selection.base.offset : current.selection.baseOffset)
                  .clamp(0, text.length),
          extentOffset:
              (selected
                      ? selection.extent.offset
                      : current.selection.extentOffset)
                  .clamp(0, text.length),
        ),
        composing: current.text == text ? current.composing : TextRange.empty,
      );
      _isSyncing = true;
      try {
        if (updated != current) _codeTextController.value = updated;
      } finally {
        _isSyncing = false;
      }
    });
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      widget.onActiveTargetChanged?.call(_codeTextController, widget.focusNode);
      _onCodeChanged();
    }
  }

  @override
  void dispose() {
    _codeTextController.removeListener(_onCodeChanged);
    _codeTextController.dispose();
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onCodeChanged() {
    if (_isSyncing || widget.readOnly || !widget.focusNode.hasFocus) return;
    final document = widget.controller.document;
    final index = document.findBlockIndexById(widget.block.id);
    if (index < 0 || document.blocks[index] is! CodeBlock) return;
    final block = document.blocks[index] as CodeBlock;
    final value = _codeTextController.value;
    if (!value.selection.isValid) return;
    final selection = RichDocumentSelection(
      base: RichDocumentPosition(
        blockIndex: index,
        blockId: block.id,
        offset: value.selection.baseOffset,
      ),
      extent: RichDocumentPosition(
        blockIndex: index,
        blockId: block.id,
        offset: value.selection.extentOffset,
      ),
    );
    if (value.text != block.code) {
      final blocks = List<RichBlock>.from(document.blocks);
      blocks[index] = block.copyWith(code: value.text);
      widget.controller.setDocument(
        document.copyWith(blocks: blocks),
        newSelection: selection,
      );
    } else {
      widget.controller.updateSelection(selection);
    }
  }

  Future<void> _changeLanguage(BuildContext context) async {
    if (widget.readOnly) return;
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: widget.block.language,
      title: 'Select Code Language',
    );
    if (mounted && selected != null) {
      final document = widget.controller.document;
      final index = document.findBlockIndexById(widget.block.id);
      if (index >= 0 && document.blocks[index] is CodeBlock) {
        final blocks = List<RichBlock>.from(document.blocks);
        blocks[index] = (blocks[index] as CodeBlock).copyWith(
          language: selected.id,
        );
        widget.controller.setDocument(document.copyWith(blocks: blocks));
      }
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.block.code));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lang = widget.block.language.isEmpty
        ? 'Plain Text'
        : widget.block.language;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Language pill & Copy button
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: widget.readOnly
                      ? null
                      : () => _changeLanguage(context),
                  borderRadius: AppRadii.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang,
                          style: AppTypography.caption.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!widget.readOnly) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: colors.textTertiary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                QuietIconButton(
                  icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                  tooltip: _copied ? 'Copied!' : 'Copy Code',
                  size: 16,
                  onPressed: _copyCode,
                ),
              ],
            ),
          ),

          // Code text input / viewer
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _codeTextController,
              focusNode: widget.focusNode,
              readOnly: widget.readOnly,
              maxLines: null,
              style: AppTypography.editorCode.copyWith(
                fontSize: 13.5,
                height: 1.5,
                color: colors.textPrimary,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
