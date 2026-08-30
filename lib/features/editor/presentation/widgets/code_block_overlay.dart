import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/markdown/markdown_helper.dart';
import '../../../../core/syntax/presentation/language_selector_sheet.dart';
import '../../application/markdown_code_block_parser.dart';
import 'code_block_language_pill.dart';

/// An overlay widget wrapping an editor [TextField] that places interactive
/// [CodeBlockLanguagePill] buttons at the upper-right corner of every code block.
class CodeBlockOverlay extends StatefulWidget {
  const CodeBlockOverlay({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.child,
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Widget child;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  State<CodeBlockOverlay> createState() => CodeBlockOverlayState();
}

class CodeBlockOverlayState extends State<CodeBlockOverlay> {
  List<MarkdownCodeBlockInfo> _codeBlocks = const [];
  Map<int, double> _pillPositions = const {};

  @visibleForTesting
  List<MarkdownCodeBlockInfo> get codeBlocks => _codeBlocks;

  @visibleForTesting
  Map<int, double> get pillPositions => _pillPositions;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _scanCodeBlocks();
  }

  @override
  void didUpdateWidget(CodeBlockOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _scanCodeBlocks();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    _scanCodeBlocks();
  }

  void _scanCodeBlocks() {
    final text = widget.controller.text;
    final parsed = MarkdownCodeBlockParser.parse(text);
    if (!listEquals(parsed, _codeBlocks)) {
      setState(() {
        _codeBlocks = parsed;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updatePillPositions();
      }
    });
  }

  RenderEditable? _findRenderEditable(RenderObject? ro) {
    if (ro is RenderEditable) return ro;
    RenderEditable? found;
    ro?.visitChildren((child) {
      found ??= _findRenderEditable(child);
    });
    return found;
  }

  void _updatePillPositions() {
    if (!mounted || _codeBlocks.isEmpty) {
      if (_pillPositions.isNotEmpty) {
        setState(() {
          _pillPositions = const {};
        });
      }
      return;
    }

    final renderObject = context.findRenderObject();
    final renderEditable = _findRenderEditable(renderObject);
    if (renderEditable == null) return;

    final textLength = widget.controller.text.length;
    final newPositions = <int, double>{};

    for (final block in _codeBlocks) {
      final start = block.openingFenceLineStart;
      final end = block.openingFenceLineEnd;
      if (start <= end && end <= textLength) {
        final boxes = renderEditable.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        if (boxes.isNotEmpty) {
          newPositions[start] = boxes.first.top;
        } else {
          final endpoints = renderEditable.getEndpointsForSelection(
            TextSelection.collapsed(offset: start),
          );
          if (endpoints.isNotEmpty) {
            newPositions[start] = endpoints.first.point.dy;
          }
        }
      }
    }

    if (!mapEquals(newPositions, _pillPositions)) {
      setState(() {
        _pillPositions = newPositions;
      });
    }
  }

  Future<void> _onSelectLanguage(MarkdownCodeBlockInfo block) async {
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: block.rawLanguage.isNotEmpty ? block.rawLanguage : null,
      title: 'Select Code Language',
    );

    if (selected != null) {
      final updated = MarkdownHelper.replaceCodeBlockLanguageAtLine(
        value: widget.controller.value,
        openingFenceLineStart: block.openingFenceLineStart,
        openingFenceLineEnd: block.openingFenceLineEnd,
        newLanguage: selected.id,
      );
      widget.controller.value = updated;
      widget.onChanged?.call(updated.text);
      if (!widget.focusNode.hasFocus) {
        widget.focusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updatePillPositions();
      }
    });

    if (_codeBlocks.isEmpty || widget.readOnly) {
      return widget.child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        for (final block in _codeBlocks)
          if (_pillPositions.containsKey(block.openingFenceLineStart))
            Positioned(
              top: _pillPositions[block.openingFenceLineStart]! + 1.0,
              right: 6.0,
              child: CodeBlockLanguagePill(
                language: block.rawLanguage,
                enabled: !widget.readOnly,
                onTap: () => _onSelectLanguage(block),
              ),
            ),
      ],
    );
  }
}
