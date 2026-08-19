import 'package:flutter/services.dart';
import '../../../core/markdown/markdown_helper.dart';

/// Helper utilities for Markdown editing operations and keyboard shortcuts.
abstract final class MarkdownEditingHelpers {
  /// Wraps current selection or inserts formatted pair.
  static TextEditingValue wrapSelection({
    required TextEditingValue value,
    required String prefix,
    required String suffix,
    String defaultText = '',
  }) =>
      MarkdownHelper.wrapSelection(
        value: value,
        prefix: prefix,
        suffix: suffix,
        defaultText: defaultText,
      );

  /// Cycles heading level (# -> ## -> ### -> none).
  static TextEditingValue cycleHeading(TextEditingValue value) =>
      MarkdownHelper.cycleHeading(value);

  /// Toggles line prefix for lists or quotes.
  static TextEditingValue toggleLinePrefix({
    required TextEditingValue value,
    required String prefix,
  }) =>
      MarkdownHelper.toggleLinePrefix(value: value, prefix: prefix);

  /// Inserts a link template `[title](url)`.
  static TextEditingValue insertLink(TextEditingValue value) =>
      MarkdownHelper.insertLink(value);

  /// Inserts a fenced code block.
  static TextEditingValue insertCodeBlock(TextEditingValue value) =>
      MarkdownHelper.insertCodeBlock(value);
}
