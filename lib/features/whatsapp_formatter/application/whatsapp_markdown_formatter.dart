import '../domain/whatsapp_format_options.dart';
import '../domain/whatsapp_parse_result.dart';

/// Converts parsed WhatsApp chat structures into clean, safe, valid Markdown.
abstract final class WhatsAppMarkdownFormatter {
  /// Converts a [WhatsAppParseResult] into Markdown based on [WhatsAppFormatOptions].
  static String format(
    WhatsAppParseResult parseResult, {
    WhatsAppFormatOptions options = const WhatsAppFormatOptions(),
    bool asBlock = true,
  }) {
    if (parseResult.messages.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    String? currentDate;
    String? currentSender;

    for (var i = 0; i < parseResult.messages.length; i++) {
      final msg = parseResult.messages[i];

      // Handle unrecognized lines before/between messages
      if (msg.isUnrecognized) {
        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
          buffer.writeln();
        }
        buffer.writeln(msg.body);
        buffer.writeln();
        currentSender = null;
        continue;
      }

      // Handle date transitions
      if (msg.date.isNotEmpty && msg.date != currentDate) {
        currentDate = msg.date;
        currentSender = null;

        if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
          buffer.writeln();
        }
        buffer.writeln('### $currentDate');
        buffer.writeln();
      }

      // Handle system notices
      if (msg.isSystemMessage) {
        currentSender = null;
        final cleanNotice = msg.body.trim();
        if (cleanNotice.isNotEmpty) {
          buffer.writeln('_${escapeMessageContent(cleanNotice)}_');
          buffer.writeln();
        }
        continue;
      }

      // Handle Sender grouping
      final sender = msg.sender ?? 'Unknown';
      final isNewSenderGroup = !options.groupConsecutiveMessages ||
          currentSender == null ||
          currentSender != sender;

      if (isNewSenderGroup) {
        currentSender = sender;
        if (options.showSenderNames) {
          // If previous content was written, ensure spacing
          if (buffer.isNotEmpty && !buffer.toString().endsWith('\n\n')) {
            buffer.writeln();
          }
          buffer.writeln('**$sender**');
        }
      }

      // Format individual message line
      final bodyLines = msg.body.split('\n');
      final firstLine = bodyLines.first;
      final escapedFirst = escapeMessageContent(firstLine);

      if (options.preserveTimestamps && msg.time.isNotEmpty) {
        buffer.write('_${msg.time}_ · $escapedFirst');
      } else {
        buffer.write(escapedFirst);
      }
      buffer.writeln();

      // Subsequent lines of a multi-line message
      for (var l = 1; l < bodyLines.length; l++) {
        final line = bodyLines[l];
        buffer.writeln(escapeMessageContent(line));
      }
    }

    final formatted = buffer.toString().trim();
    if (asBlock) {
      return '```whatsapp\n$formatted\n```';
    }
    return formatted;
  }

  /// Escapes Markdown-sensitive leading characters to prevent chat text
  /// from inadvertently becoming headings, checklists, blockquotes, or lists.
  static String escapeMessageContent(String text) {
    if (text.isEmpty) return '';

    var result = text;

    // Headings: #, ##, etc.
    if (RegExp(r'^\s*#{1,6}\s+').hasMatch(result)) {
      result = result.replaceFirst(RegExp(r'^\s*#'), r'\#');
    }

    // Checklists: - [ ] or - [x]
    if (RegExp(r'^\s*[-*+]\s*\[[ xX]\]\s+').hasMatch(result)) {
      result = result.replaceFirst(RegExp(r'^\s*[-*+]'), r'\-');
    }

    // Unordered lists: - item, * item, + item
    if (RegExp(r'^\s*[-*+]\s+').hasMatch(result)) {
      result = result.replaceFirst(RegExp(r'^\s*[-*+]'), r'\-');
    }

    // Ordered lists: 1. item, 2. item
    if (RegExp(r'^\s*\d+[\.\)]\s+').hasMatch(result)) {
      result = result.replaceFirstMapped(
        RegExp(r'^(\s*\d+)([\.\)])(\s+)'),
        (m) => '${m[1]}\\${m[2]}${m[3]}',
      );
    }

    // Blockquotes: > quote
    if (RegExp(r'^\s*>\s*').hasMatch(result)) {
      result = result.replaceFirst(RegExp(r'^\s*>'), r'\>');
    }

    // Code fences: ```
    if (result.startsWith('```')) {
      result = '\\```${result.substring(3)}';
    }

    return result;
  }
}
