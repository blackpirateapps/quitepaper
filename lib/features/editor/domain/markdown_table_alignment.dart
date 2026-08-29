import 'package:flutter/material.dart';

/// Column alignment supported by GitHub-Flavored Markdown tables.
enum MarkdownTableAlignment {
  none,
  left,
  center,
  right;

  /// Returns the corresponding Flutter [TextAlign].
  TextAlign get textAlign {
    switch (this) {
      case MarkdownTableAlignment.center:
        return TextAlign.center;
      case MarkdownTableAlignment.right:
        return TextAlign.right;
      case MarkdownTableAlignment.left:
      case MarkdownTableAlignment.none:
        return TextAlign.left;
    }
  }

  /// Returns the corresponding Flutter [Alignment].
  Alignment get alignment {
    switch (this) {
      case MarkdownTableAlignment.center:
        return Alignment.center;
      case MarkdownTableAlignment.right:
        return Alignment.centerRight;
      case MarkdownTableAlignment.left:
      case MarkdownTableAlignment.none:
        return Alignment.centerLeft;
    }
  }

  /// Returns the GFM delimiter token representation (e.g. `:---:`, `:---`, `---:`, `---`).
  String toDelimiterString({int minWidth = 3}) {
    final dashes = '-' * (minWidth > 3 ? minWidth - 2 : 3);
    switch (this) {
      case MarkdownTableAlignment.left:
        return ':$dashes';
      case MarkdownTableAlignment.center:
        return ':$dashes:';
      case MarkdownTableAlignment.right:
        return '$dashes:';
      case MarkdownTableAlignment.none:
        return dashes;
    }
  }
}
