import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/highlight_result.dart';
import '../domain/syntax_theme.dart';

/// Helper utility for compiling syntax tokens into styled Flutter [TextSpan] trees
/// with seamless search match overlays and IME composing decorations.
abstract final class SyntaxTextSpans {
  /// Builds a [TextSpan] representing [text] formatted by [highlightResult] and [theme].
  static TextSpan buildTextSpan({
    required String text,
    required HighlightResult highlightResult,
    required SyntaxTheme theme,
    TextStyle? fallbackStyle,
    String? searchQuery,
    int? activeSearchMatchIndex,
    List<int>? searchMatchOffsets,
    TextStyle? searchHighlightStyle,
    TextStyle? activeSearchHighlightStyle,
    TextRange? composingRange,
  }) {
    if (text.isEmpty) {
      return TextSpan(text: '', style: fallbackStyle ?? theme.plain);
    }

    final tokens = highlightResult.tokens;
    final defaultStyle = fallbackStyle ?? theme.plain;

    // Fast path: no tokens
    if (tokens.isEmpty) {
      return _buildSearchOverlaySpan(
        text: text,
        baseStart: 0,
        baseEnd: text.length,
        style: defaultStyle,
        searchQuery: searchQuery,
        activeSearchMatchIndex: activeSearchMatchIndex,
        searchMatchOffsets: searchMatchOffsets,
        searchHighlightStyle: searchHighlightStyle,
        activeSearchHighlightStyle: activeSearchHighlightStyle,
        composingRange: composingRange,
      );
    }

    final spans = <InlineSpan>[];
    var lastOffset = 0;

    for (final token in tokens) {
      // 1. Fill any gaps before token
      if (token.start > lastOffset && token.start <= text.length) {
        final gapEnd = min(token.start, text.length);
        final gapSpan = _buildSearchOverlaySpan(
          text: text,
          baseStart: lastOffset,
          baseEnd: gapEnd,
          style: defaultStyle,
          searchQuery: searchQuery,
          activeSearchMatchIndex: activeSearchMatchIndex,
          searchMatchOffsets: searchMatchOffsets,
          searchHighlightStyle: searchHighlightStyle,
          activeSearchHighlightStyle: activeSearchHighlightStyle,
          composingRange: composingRange,
        );
        spans.add(gapSpan);
      }

      // 2. Add styled token with search and composing overlays
      if (token.start < text.length) {
        final tokenEnd = min(token.end, text.length);
        final tokenStyle = theme.styleFor(token.type);

        final tokenSpan = _buildSearchOverlaySpan(
          text: text,
          baseStart: token.start,
          baseEnd: tokenEnd,
          style: tokenStyle,
          searchQuery: searchQuery,
          activeSearchMatchIndex: activeSearchMatchIndex,
          searchMatchOffsets: searchMatchOffsets,
          searchHighlightStyle: searchHighlightStyle,
          activeSearchHighlightStyle: activeSearchHighlightStyle,
          composingRange: composingRange,
        );
        spans.add(tokenSpan);
        lastOffset = tokenEnd;
      }
    }

    // 3. Fill any remaining text at the end
    if (lastOffset < text.length) {
      final tailSpan = _buildSearchOverlaySpan(
        text: text,
        baseStart: lastOffset,
        baseEnd: text.length,
        style: defaultStyle,
        searchQuery: searchQuery,
        activeSearchMatchIndex: activeSearchMatchIndex,
        searchMatchOffsets: searchMatchOffsets,
        searchHighlightStyle: searchHighlightStyle,
        activeSearchHighlightStyle: activeSearchHighlightStyle,
        composingRange: composingRange,
      );
      spans.add(tailSpan);
    }

    return TextSpan(children: spans, style: defaultStyle);
  }

  /// Builds a [TextSpan] for a slice `[baseStart, baseEnd]` of [text], applying search highlights
  /// and composing underline decorations where applicable.
  static TextSpan _buildSearchOverlaySpan({
    required String text,
    required int baseStart,
    required int baseEnd,
    required TextStyle style,
    String? searchQuery,
    int? activeSearchMatchIndex,
    List<int>? searchMatchOffsets,
    TextStyle? searchHighlightStyle,
    TextStyle? activeSearchHighlightStyle,
    TextRange? composingRange,
  }) {
    if (baseEnd <= baseStart || baseStart >= text.length) {
      return const TextSpan(text: '');
    }

    final spanText = text.substring(baseStart, baseEnd);
    final hasSearch = searchQuery != null &&
        searchQuery.isNotEmpty &&
        searchMatchOffsets != null &&
        searchMatchOffsets.isNotEmpty;

    final isComposingValid = composingRange != null &&
        composingRange.isValid &&
        !composingRange.isCollapsed &&
        composingRange.start >= 0 &&
        composingRange.end <= text.length;

    if (!hasSearch && !isComposingValid) {
      return TextSpan(text: spanText, style: style);
    }

    // Find overlapping search matches in this slice
    final queryLen = searchQuery?.length ?? 0;
    final overlappingMatches = <_SearchMatchInfo>[];

    if (hasSearch) {
      for (var idx = 0; idx < searchMatchOffsets.length; idx++) {
        final matchStart = searchMatchOffsets[idx];
        final matchEnd = matchStart + queryLen;
        if (matchEnd > baseStart && matchStart < baseEnd) {
          overlappingMatches.add(_SearchMatchInfo(
            start: max(baseStart, matchStart),
            end: min(baseEnd, matchEnd),
            isActive: idx == activeSearchMatchIndex,
          ));
        }
      }
    }

    final children = <InlineSpan>[];
    var current = baseStart;

    void addSegment(int segStart, int segEnd, {TextStyle? styleOverride}) {
      if (segEnd <= segStart) return;
      final segText = text.substring(segStart, segEnd);
      final effective = styleOverride ?? style;

      if (!isComposingValid ||
          segEnd <= composingRange.start ||
          segStart >= composingRange.end) {
        children.add(TextSpan(text: segText, style: effective));
      } else {
        final compStart = composingRange.start;
        final compEnd = composingRange.end;

        if (segStart < compStart) {
          children.add(TextSpan(
            text: text.substring(segStart, compStart),
            style: effective,
          ));
        }

        final inCompStart = max(segStart, compStart);
        final inCompEnd = min(segEnd, compEnd);
        if (inCompEnd > inCompStart) {
          children.add(TextSpan(
            text: text.substring(inCompStart, inCompEnd),
            style: effective.copyWith(decoration: TextDecoration.underline),
          ));
        }

        if (segEnd > compEnd) {
          children.add(TextSpan(
            text: text.substring(compEnd, segEnd),
            style: effective,
          ));
        }
      }
    }

    for (final match in overlappingMatches) {
      if (match.start > current) {
        addSegment(current, match.start);
      }

      final hlStyle = match.isActive
          ? (activeSearchHighlightStyle ?? const TextStyle(fontWeight: FontWeight.bold))
          : (searchHighlightStyle ?? const TextStyle(fontWeight: FontWeight.w600));

      addSegment(
        match.start,
        match.end,
        styleOverride: style.merge(hlStyle),
      );
      current = match.end;
    }

    if (current < baseEnd) {
      addSegment(current, baseEnd);
    }

    return TextSpan(children: children);
  }
}

class _SearchMatchInfo {
  final int start;
  final int end;
  final bool isActive;

  const _SearchMatchInfo({
    required this.start,
    required this.end,
    required this.isActive,
  });
}
