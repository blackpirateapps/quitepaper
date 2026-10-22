import 'dart:convert';
import '../domain/whatsapp_format_options.dart';
import '../domain/whatsapp_message.dart';
import '../domain/whatsapp_parse_result.dart';
import 'whatsapp_parser.dart';

/// Helper to parse WhatsApp chat text (whether raw export, formatted markdown,
/// or option-prefixed) into a structured [WhatsAppParseResult] and [WhatsAppFormatOptions].
class WhatsAppChatHelper {
  const WhatsAppChatHelper._();

  /// Parses [content] which can be:
  /// 1. Optional JSON/comment options line followed by raw chat.
  /// 2. Raw exported WhatsApp chat.
  /// 3. Markdown-formatted chat (e.g. `### Date`, `**Sender**`, `_time_ · body`).
  static ({WhatsAppParseResult result, WhatsAppFormatOptions options}) parseContent(
    String content, {
    WhatsAppFormatOptions defaultOptions = const WhatsAppFormatOptions(),
  }) {
    var text = content.trim();
    var options = defaultOptions;

    // 1. Check for option header line: e.g. `{"showSenderNames":...}` or `<!-- qp-options: {...} -->`
    if (text.startsWith('{') && text.contains('\n')) {
      final firstLineEnd = text.indexOf('\n');
      final firstLine = text.substring(0, firstLineEnd).trim();
      try {
        final decoded = jsonDecode(firstLine) as Map<String, dynamic>;
        options = WhatsAppFormatOptions.fromJson(decoded);
        text = text.substring(firstLineEnd + 1).trim();
      } catch (_) {}
    } else if (text.startsWith('<!-- qp-options:') && text.contains('-->')) {
      final endIdx = text.indexOf('-->');
      final optStr = text.substring('<!-- qp-options:'.length, endIdx).trim();
      try {
        final decoded = jsonDecode(optStr) as Map<String, dynamic>;
        options = WhatsAppFormatOptions.fromJson(decoded);
        text = text.substring(endIdx + 3).trim();
      } catch (_) {}
    }

    // 2. Check if content is raw WhatsApp chat
    if (WhatsAppParser.isWhatsAppChat(text)) {
      final result = WhatsAppParser.parse(text);
      return (result: result, options: options);
    }

    // 3. Try parsing as Markdown-formatted chat (e.g. `### Date\n\n**Sender**\n_time_ · msg`)
    final mdResult = _parseMarkdownChat(text);
    if (mdResult.messages.isNotEmpty) {
      return (result: mdResult, options: options);
    }

    // 4. Fallback to normal parser
    final fallback = WhatsAppParser.parse(text);
    return (result: fallback, options: options);
  }

  static WhatsAppParseResult _parseMarkdownChat(String md) {
    final lines = const LineSplitter().convert(md);
    final messages = <WhatsAppMessage>[];
    final participants = <String>{};
    final unrecognized = <String>[];

    String currentDate = '';
    String currentSender = '';
    final dateHeadingRegex = RegExp(r'^#{1,3}\s+(.+)$');
    final senderRegex = RegExp(r'^\*\*([^*]+)\*\*$');
    final timeBodyRegex1 = RegExp(r'^_([^_]+)_[ ·]*(.*)$');
    final timeBodyRegex2 = RegExp(r'^\*\(([^\)]+)\)\*[ ]*(.*)$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final dateMatch = dateHeadingRegex.firstMatch(trimmed);
      if (dateMatch != null) {
        currentDate = dateMatch.group(1)?.trim() ?? '';
        currentSender = '';
        continue;
      }

      final senderMatch = senderRegex.firstMatch(trimmed);
      if (senderMatch != null) {
        currentSender = senderMatch.group(1)?.trim() ?? '';
        if (currentSender.isNotEmpty) {
          participants.add(currentSender);
        }
        continue;
      }

      final timeMatch1 = timeBodyRegex1.firstMatch(trimmed);
      final timeMatch2 = timeBodyRegex2.firstMatch(trimmed);
      final timeMatch = timeMatch1 ?? timeMatch2;

      if (timeMatch != null) {
        final time = timeMatch.group(1)?.trim() ?? '';
        final body = timeMatch.group(2)?.trim() ?? '';
        messages.add(
          WhatsAppMessage(
            date: currentDate,
            time: time,
            sender: currentSender.isNotEmpty ? currentSender : null,
            body: body,
            rawText: trimmed,
          ),
        );
        continue;
      }

      if (currentSender.isNotEmpty) {
        // Plain message line under current sender
        messages.add(
          WhatsAppMessage(
            date: currentDate,
            time: '',
            sender: currentSender,
            body: trimmed,
            rawText: trimmed,
          ),
        );
      } else {
        unrecognized.add(trimmed);
      }
    }

    return WhatsAppParseResult(
      messages: messages,
      unrecognizedLines: unrecognized,
      originalText: md,
      confidence: messages.isNotEmpty ? 0.9 : 0.0,
    );
  }
}
