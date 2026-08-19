import 'package:flutter/services.dart';
import '../../../core/markdown/markdown_helper.dart';
import 'markdown_formatter.dart';

/// Helper utilities for Markdown editing operations and keyboard shortcuts.
abstract final class MarkdownEditingHelpers {
  /// Toggles bold formatting context-aware.
  static TextEditingValue toggleBold(TextEditingValue value) =>
      MarkdownFormatter.toggleBold(value: value);

  /// Toggles italic formatting context-aware.
  static TextEditingValue toggleItalic(TextEditingValue value) =>
      MarkdownFormatter.toggleItalic(value: value);

  /// Toggles strikethrough formatting context-aware.
  static TextEditingValue toggleStrikethrough(TextEditingValue value) =>
      MarkdownFormatter.toggleStrikethrough(value: value);

  /// Toggles inline code formatting context-aware.
  static TextEditingValue toggleInlineCode(TextEditingValue value) =>
      MarkdownFormatter.toggleInlineCode(value: value);

  /// Toggles checklist items across selected lines.
  static TextEditingValue toggleChecklist(TextEditingValue value) =>
      MarkdownFormatter.toggleChecklist(value: value);

  /// Toggles unordered bullet list across selected lines.
  static TextEditingValue toggleBulletList(TextEditingValue value) =>
      MarkdownFormatter.toggleBulletList(value: value);

  /// Toggles ordered numbered list across selected lines.
  static TextEditingValue toggleOrderedList(TextEditingValue value) =>
      MarkdownFormatter.toggleOrderedList(value: value);

  /// Creates a Markdown link `[title](url)`.
  static TextEditingValue createLink({
    required TextEditingValue value,
    required String url,
    String? title,
  }) =>
      MarkdownFormatter.createLink(
        value: value,
        url: url,
        title: title,
      );

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
