import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../../../core/widgets/quiet_icon_button.dart';
import '../../domain/rich_block.dart';
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
    this.readOnly = false,
  });

  final CodeBlock block;
  final int blockIndex;
  final RichDocumentController controller;
  final bool readOnly;

  @override
  State<RichCodeBlock> createState() => _RichCodeBlockState();
}

class _RichCodeBlockState extends State<RichCodeBlock> {
  late final TextEditingController _codeTextController;
  late final FocusNode _codeFocusNode;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _codeTextController = TextEditingController(text: widget.block.code);
    _codeFocusNode = FocusNode();
    _codeTextController.addListener(_onCodeChanged);
  }

  @override
  void didUpdateWidget(RichCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.code != widget.block.code &&
        _codeTextController.text != widget.block.code) {
      _codeTextController.text = widget.block.code;
    }
  }

  @override
  void dispose() {
    _codeTextController.removeListener(_onCodeChanged);
    _codeTextController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_codeTextController.text != widget.block.code) {
      final updated = widget.block.copyWith(code: _codeTextController.text);
      final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
      if (widget.blockIndex < newBlocks.length) {
        newBlocks[widget.blockIndex] = updated;
        widget.controller.setMarkdown(
          widget.controller.toMarkdown(),
        );
      }
    }
  }

  Future<void> _changeLanguage(BuildContext context) async {
    if (widget.readOnly) return;
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: widget.block.language,
      title: 'Select Code Language',
    );
    if (selected != null) {
      final updated = widget.block.copyWith(language: selected.id);
      final newBlocks = List<RichBlock>.from(widget.controller.document.blocks);
      if (widget.blockIndex < newBlocks.length) {
        newBlocks[widget.blockIndex] = updated;
        widget.controller.setMarkdown(widget.controller.toMarkdown());
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
    final lang = widget.block.language.isEmpty ? 'Plain Text' : widget.block.language;

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
                  onTap: widget.readOnly ? null : () => _changeLanguage(context),
                  borderRadius: AppRadii.borderSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          Icon(Icons.arrow_drop_down, size: 14, color: colors.textTertiary),
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
              focusNode: _codeFocusNode,
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
