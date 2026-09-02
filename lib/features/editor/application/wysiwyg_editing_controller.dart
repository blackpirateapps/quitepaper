import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/markdown_styles.dart';
import '../domain/source_visual_mapping.dart';
import 'wysiwyg_projection_builder.dart';

/// A [TextEditingController] that manages visual WYSIWYG editing while maintaining
/// the canonical Markdown string as the single authoritative source of truth.
class WysiwygEditingController extends TextEditingController {
  WysiwygEditingController({
    String sourceText = '',
    this.styles,
    this.stripFrontmatter = false,
    this.onSourceChanged,
  }) : _sourceText = sourceText {
    _rebuildProjection(sourceText, initial: true);
  }

  MarkdownStyles? styles;
  final bool stripFrontmatter;
  final ValueChanged<String>? onSourceChanged;

  String _sourceText;
  String get sourceText => _sourceText;
  set sourceText(String newSource) {
    if (_sourceText != newSource) {
      _sourceText = newSource;
      _rebuildProjection(newSource);
    }
  }

  SourceVisualMapping _mapping = SourceVisualMapping.empty;
  SourceVisualMapping get mapping => _mapping;

  TextEditingValue _lastVisualValue = TextEditingValue.empty;
  bool _isInternalUpdate = false;

  String? _searchQuery;
  String? get searchQuery => _searchQuery;
  set searchQuery(String? value) {
    if (_searchQuery != value) {
      _searchQuery = value;
      notifyListeners();
    }
  }

  TextRange? _activeSearchRange;
  TextRange? get activeSearchRange => _activeSearchRange;
  set activeSearchRange(TextRange? value) {
    if (_activeSearchRange != value) {
      _activeSearchRange = value;
      notifyListeners();
    }
  }

  void setSearchHighlight({
    required String? query,
    required TextRange? activeRange,
  }) {
    if (_searchQuery != query || _activeSearchRange != activeRange) {
      _searchQuery = query;
      _activeSearchRange = activeRange;
      notifyListeners();
    }
  }

  void _rebuildProjection(String source, {bool initial = false}) {
    final effectiveStyles = styles ?? MarkdownStyles.fromColors(AppColors.light);
    final oldSourceSelection = initial
        ? const TextSelection.collapsed(offset: 0)
        : _mapping.mapVisualSelectionToSource(_lastVisualValue.selection);

    _mapping = WysiwygProjectionBuilder.build(
      sourceText: source,
      styles: effectiveStyles,
      stripFrontmatter: stripFrontmatter,
    );

    final newVisualSelection = _mapping.mapSourceSelectionToVisual(oldSourceSelection);

    _isInternalUpdate = true;
    super.value = TextEditingValue(
      text: _mapping.visualText,
      selection: newVisualSelection.isValid
          ? newVisualSelection
          : TextSelection.collapsed(offset: _mapping.visualText.length),
    );
    _lastVisualValue = value;
    _isInternalUpdate = false;
  }

  /// Sets source value directly with specific source selection (e.g. from formatting toolbar).
  void setSourceValue(TextEditingValue sourceValue) {
    _sourceText = sourceValue.text;
    final effectiveStyles = styles ?? MarkdownStyles.fromColors(AppColors.light);
    _mapping = WysiwygProjectionBuilder.build(
      sourceText: _sourceText,
      styles: effectiveStyles,
      stripFrontmatter: stripFrontmatter,
    );

    final mappedVisualSelection = _mapping.mapSourceSelectionToVisual(sourceValue.selection);

    _isInternalUpdate = true;
    super.value = TextEditingValue(
      text: _mapping.visualText,
      selection: mappedVisualSelection.isValid
          ? mappedVisualSelection
          : TextSelection.collapsed(offset: _mapping.visualText.length),
    );
    _lastVisualValue = value;
    _isInternalUpdate = false;
    notifyListeners();
  }

  /// Returns the current canonical Markdown source value with mapped selection.
  TextEditingValue get sourceValue {
    return TextEditingValue(
      text: _sourceText,
      selection: _mapping.mapVisualSelectionToSource(value.selection),
      composing: value.isComposingRangeValid
          ? TextRange(
              start: _mapping.visualToSource(value.composing.start),
              end: _mapping.visualToSource(value.composing.end),
            )
          : TextRange.empty,
    );
  }

  @override
  set value(TextEditingValue newValue) {
    if (_isInternalUpdate) {
      super.value = newValue;
      return;
    }

    if (newValue.text != _lastVisualValue.text) {
      // Visual text was edited -> mutate source
      final newSourceVal = _mapping.mapVisualEditToSource(
        oldVisualValue: _lastVisualValue,
        newVisualValue: newValue,
      );

      _sourceText = newSourceVal.text;
      final effectiveStyles = styles ?? MarkdownStyles.fromColors(AppColors.light);
      _mapping = WysiwygProjectionBuilder.build(
        sourceText: _sourceText,
        styles: effectiveStyles,
        stripFrontmatter: stripFrontmatter,
      );

      _lastVisualValue = newValue;
      super.value = newValue;

      onSourceChanged?.call(_sourceText);
    } else {
      // Only selection or composing changed
      _lastVisualValue = newValue;
      super.value = newValue;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyles = styles ??
        MarkdownStyles.fromColors(
          context.appColors,
          baseStyle: style,
        );

    final composingRange =
        (withComposing && value.isComposingRangeValid) ? value.composing : null;

    final visibleRuns = _mapping.runs.where((r) => !r.isHiddenSyntax).toList();
    if (visibleRuns.isEmpty) {
      return TextSpan(text: text, style: effectiveStyles.body);
    }

    final searchMatches = <TextRange>[];
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final lowerText = text.toLowerCase();
      final lowerQuery = _searchQuery!.toLowerCase();
      var searchIdx = 0;
      const maxMatches = 1000;
      while (searchIdx < lowerText.length && searchMatches.length < maxMatches) {
        final found = lowerText.indexOf(lowerQuery, searchIdx);
        if (found == -1) break;
        searchMatches.add(TextRange(start: found, end: found + _searchQuery!.length));
        searchIdx = found + _searchQuery!.length;
      }
    }

    final spans = <TextSpan>[];
    final isComposingValid = composingRange != null &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.start >= 0 &&
        composingRange.end <= text.length;

    for (final run in visibleRuns) {
      if (run.visualText.isEmpty) continue;

      final runStart = run.visualStart;
      final runEnd = run.visualEnd;

      // Check search overlap
      final overlappingSearch = searchMatches
          .where((m) => m.end > runStart && m.start < runEnd)
          .toList();

      if (overlappingSearch.isEmpty) {
        _appendSegmentWithComposing(
          spans: spans,
          segStart: runStart,
          segEnd: runEnd,
          segText: run.visualText,
          style: run.style,
          composingRange: isComposingValid ? composingRange : null,
        );
      } else {
        var currOffset = runStart;
        for (final match in overlappingSearch) {
          final matchStart = max(currOffset, match.start);
          final matchEnd = min(runEnd, match.end);

          if (matchStart > currOffset) {
            final beforeText = run.visualText.substring(
              currOffset - runStart,
              matchStart - runStart,
            );
            _appendSegmentWithComposing(
              spans: spans,
              segStart: currOffset,
              segEnd: matchStart,
              segText: beforeText,
              style: run.style,
              composingRange: isComposingValid ? composingRange : null,
            );
          }

          if (matchEnd > matchStart) {
            final matchText = run.visualText.substring(
              matchStart - runStart,
              matchEnd - runStart,
            );
            final isActive = _activeSearchRange != null &&
                _activeSearchRange!.start == match.start &&
                _activeSearchRange!.end == match.end;

            final highlightStyle = isActive
                ? effectiveStyles.activeSearchHighlight
                : effectiveStyles.searchHighlight;

            _appendSegmentWithComposing(
              spans: spans,
              segStart: matchStart,
              segEnd: matchEnd,
              segText: matchText,
              style: run.style.merge(highlightStyle),
              composingRange: isComposingValid ? composingRange : null,
            );
            currOffset = matchEnd;
          }
        }

        if (currOffset < runEnd) {
          final afterText = run.visualText.substring(currOffset - runStart);
          _appendSegmentWithComposing(
            spans: spans,
            segStart: currOffset,
            segEnd: runEnd,
            segText: afterText,
            style: run.style,
            composingRange: isComposingValid ? composingRange : null,
          );
        }
      }
    }

    return TextSpan(style: effectiveStyles.body, children: spans);
  }

  void _appendSegmentWithComposing({
    required List<TextSpan> spans,
    required int segStart,
    required int segEnd,
    required String segText,
    required TextStyle style,
    required TextRange? composingRange,
  }) {
    if (segText.isEmpty) return;

    if (composingRange == null ||
        segEnd <= composingRange.start ||
        segStart >= composingRange.end) {
      spans.add(TextSpan(text: segText, style: style));
      return;
    }

    final compStart = composingRange.start;
    final compEnd = composingRange.end;

    // 1. Before composing
    if (segStart < compStart) {
      final beforeText = segText.substring(0, compStart - segStart);
      spans.add(TextSpan(text: beforeText, style: style));
    }

    // 2. Composing range
    final inCompStart = max(segStart, compStart) - segStart;
    final inCompEnd = min(segEnd, compEnd) - segStart;
    if (inCompEnd > inCompStart) {
      final compText = segText.substring(inCompStart, inCompEnd);
      spans.add(TextSpan(
        text: compText,
        style: style.copyWith(decoration: TextDecoration.underline),
      ));
    }

    // 3. After composing
    if (segEnd > compEnd) {
      final afterText = segText.substring(compEnd - segStart);
      spans.add(TextSpan(text: afterText, style: style));
    }
  }
}
