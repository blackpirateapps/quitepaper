import 'dart:math';
import 'package:flutter/material.dart';
import 'markdown_token.dart';

/// Represents a single styled span in the visual projection mapped to its source slice.
@immutable
class MarkdownVisualRun {
  const MarkdownVisualRun({
    required this.sourceStart,
    required this.sourceEnd,
    required this.visualStart,
    required this.visualEnd,
    required this.type,
    required this.style,
    required this.visualText,
    this.isHiddenSyntax = false,
  });

  /// Inclusive start index in canonical Markdown source.
  final int sourceStart;

  /// Exclusive end index in canonical Markdown source.
  final int sourceEnd;

  /// Inclusive start index in the projected visual document string.
  final int visualStart;

  /// Exclusive end index in the projected visual document string.
  final int visualEnd;

  /// Semantic token type.
  final MarkdownTokenType type;

  /// Typography styling applied to this visual run.
  final TextStyle style;

  /// Text content in the visual document.
  final String visualText;

  /// Whether this slice is hidden structural Markdown syntax (e.g. `**`, `# `, `- `).
  final bool isHiddenSyntax;

  int get sourceLength => sourceEnd - sourceStart;
  int get visualLength => visualEnd - visualStart;

  @override
  String toString() =>
      'MarkdownVisualRun(type: $type, src: [$sourceStart, $sourceEnd], vis: [$visualStart, $visualEnd], text: "$visualText", hidden: $isHiddenSyntax)';
}

/// Bidirectional coordinate mapping and projection between canonical Markdown source
/// and visual WYSIWYG document representations.
class SourceVisualMapping {
  const SourceVisualMapping({
    required this.sourceText,
    required this.visualText,
    required this.runs,
  });

  final String sourceText;
  final String visualText;
  final List<MarkdownVisualRun> runs;

  static const empty = SourceVisualMapping(
    sourceText: '',
    visualText: '',
    runs: [],
  );

  /// Converts a character index in canonical Markdown source into a visual document offset.
  int sourceToVisual(int sourceOffset) {
    if (runs.isEmpty || visualText.isEmpty) return 0;
    final clampedSource = sourceOffset.clamp(0, sourceText.length);

    // Fast-path: start of document
    if (clampedSource == 0) return 0;

    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];

      if (clampedSource < run.sourceStart) {
        return run.visualStart;
      }

      if (clampedSource >= run.sourceStart && clampedSource <= run.sourceEnd) {
        if (run.isHiddenSyntax) {
          // If cursor falls inside hidden delimiter (e.g. between **), snap to visual boundary
          return run.visualStart;
        }

        final delta = clampedSource - run.sourceStart;
        return (run.visualStart + delta).clamp(0, visualText.length);
      }
    }

    return visualText.length;
  }

  /// Converts a character index in the projected visual text into a canonical Markdown source offset.
  /// If [insertInsideRun] is true, visual offsets at the end of a styled run remain inside the run
  /// (before closing hidden syntax markers such as `**`, `*`, `~~`), enabling continuous formatted typing.
  int visualToSource(int visualOffset, {bool insertInsideRun = true}) {
    if (runs.isEmpty || sourceText.isEmpty) return 0;
    final clampedVisual = visualOffset.clamp(0, visualText.length);

    // Fast-path: start of document
    if (clampedVisual == 0) {
      if (runs.isNotEmpty && runs.first.isHiddenSyntax) {
        // If first token is hidden prefix (like "# " or opening "**"), cursor in visual index 0 is at content start
        return runs.first.sourceEnd;
      }
      return 0;
    }

    if (clampedVisual == visualText.length) {
      if (insertInsideRun && runs.isNotEmpty && runs.last.isHiddenSyntax && runs.length >= 2) {
        return runs[runs.length - 2].sourceEnd;
      }
      return sourceText.length;
    }

    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      if (run.isHiddenSyntax) continue;

      if (clampedVisual >= run.visualStart && clampedVisual <= run.visualEnd) {
        final delta = clampedVisual - run.visualStart;
        if (clampedVisual == run.visualEnd && i + 1 < runs.length && runs[i + 1].isHiddenSyntax) {
          return insertInsideRun ? run.sourceEnd : runs[i + 1].sourceEnd;
        }
        return (run.sourceStart + delta).clamp(0, sourceText.length);
      }
    }

    return sourceText.length;
  }

  /// Maps a visual selection to the corresponding canonical Markdown source selection.
  TextSelection mapVisualSelectionToSource(
    TextSelection visualSel, {
    bool insertInsideRun = true,
  }) {
    if (!visualSel.isValid) return const TextSelection.collapsed(offset: -1);

    var sourceBase = visualToSource(visualSel.baseOffset, insertInsideRun: insertInsideRun);
    var sourceExtent = visualToSource(visualSel.extentOffset, insertInsideRun: insertInsideRun);

    // If selection covers the whole visual run, expand to encompass hidden delimiters around it
    if (!visualSel.isCollapsed) {
      for (var i = 0; i < runs.length; i++) {
        final run = runs[i];
        if (run.isHiddenSyntax) continue;

        if (visualSel.start == run.visualStart && i > 0 && runs[i - 1].isHiddenSyntax) {
          if (visualSel.baseOffset <= visualSel.extentOffset) {
            sourceBase = runs[i - 1].sourceStart;
          } else {
            sourceExtent = runs[i - 1].sourceStart;
          }
        }
        if (visualSel.end == run.visualEnd && i + 1 < runs.length && runs[i + 1].isHiddenSyntax) {
          if (visualSel.baseOffset <= visualSel.extentOffset) {
            sourceExtent = runs[i + 1].sourceEnd;
          } else {
            sourceBase = runs[i + 1].sourceEnd;
          }
        }
      }
    }

    return visualSel.copyWith(
      baseOffset: sourceBase,
      extentOffset: sourceExtent,
    );
  }

  /// Maps a canonical Markdown source selection to the corresponding visual selection.
  TextSelection mapSourceSelectionToVisual(TextSelection sourceSel) {
    if (!sourceSel.isValid) return const TextSelection.collapsed(offset: -1);

    final visualBase = sourceToVisual(sourceSel.baseOffset);
    final visualExtent = sourceToVisual(sourceSel.extentOffset);

    return sourceSel.copyWith(
      baseOffset: visualBase,
      extentOffset: visualExtent,
    );
  }

  /// Translates a visual text edit into an exact canonical Markdown source mutation.
  TextEditingValue mapVisualEditToSource({
    required TextEditingValue oldVisualValue,
    required TextEditingValue newVisualValue,
    bool insertInsideRun = true,
  }) {
    final oldVText = oldVisualValue.text;
    final newVText = newVisualValue.text;

    // If text is identical, only selection/composing changed
    if (oldVText == newVText) {
      final newSourceSel = mapVisualSelectionToSource(
        newVisualValue.selection,
        insertInsideRun: insertInsideRun,
      );
      final newSourceComp = newVisualValue.isComposingRangeValid
          ? TextRange(
              start: visualToSource(newVisualValue.composing.start, insertInsideRun: insertInsideRun),
              end: visualToSource(newVisualValue.composing.end, insertInsideRun: insertInsideRun),
            )
          : TextRange.empty;

      return TextEditingValue(
        text: sourceText,
        selection: newSourceSel,
        composing: newSourceComp,
      );
    }

    // Find the edited region in visual coordinates
    var prefixLen = 0;
    final minLen = min(oldVText.length, newVText.length);
    while (prefixLen < minLen && oldVText[prefixLen] == newVText[prefixLen]) {
      prefixLen++;
    }

    var suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        oldVText[oldVText.length - 1 - suffixLen] ==
            newVText[newVText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final oldVisualEditStart = prefixLen;
    final oldVisualEditEnd = oldVText.length - suffixLen;
    final insertedVisualText =
        newVText.substring(prefixLen, newVText.length - suffixLen);

    // Map the edited range from visual coordinates to canonical source coordinates
    final int sourceEditStart;
    final int sourceEditEnd;

    if (!insertInsideRun && oldVisualEditStart == 0 && oldVisualEditEnd == oldVText.length) {
      sourceEditStart = 0;
      sourceEditEnd = sourceText.length;
    } else {
      sourceEditStart = oldVisualEditStart == 0
          ? (runs.isNotEmpty && runs.first.isHiddenSyntax && insertInsideRun ? runs.first.sourceEnd : 0)
          : visualToSource(oldVisualEditStart, insertInsideRun: insertInsideRun);

      sourceEditEnd = oldVisualEditEnd == oldVText.length
          ? (insertInsideRun && runs.isNotEmpty && runs.last.isHiddenSyntax && runs.length >= 2
              ? runs[runs.length - 2].sourceEnd
              : sourceText.length)
          : visualToSource(oldVisualEditEnd, insertInsideRun: insertInsideRun);
    }

    final newSourceText = sourceText.replaceRange(
      sourceEditStart,
      sourceEditEnd,
      insertedVisualText,
    );

    final newSourceSelection = TextSelection.collapsed(
      offset: sourceEditStart + insertedVisualText.length,
    );

    return TextEditingValue(
      text: newSourceText,
      selection: newSourceSelection,
    );
  }
}
