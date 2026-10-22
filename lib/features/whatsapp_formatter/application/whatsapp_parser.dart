import 'dart:math';
import '../domain/whatsapp_message.dart';
import '../domain/whatsapp_parse_result.dart';

/// Fast, deterministic, locally executed parser and detector for WhatsApp exported chats.
abstract final class WhatsAppParser {
  /// iOS bracketed pattern: e.g. `[21/10, 11:04 pm] Sam 3: Yeshh`
  static final RegExp _bracketedRegex = RegExp(
    r'^\[([0-9]{1,4}[/\.-][0-9]{1,2}(?:[/\.-][0-9]{2,4})?),?\s+([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:[\s\u202F\u00A0]*(?:[aApP]\.?[mM]\.?))?)\]\s*(?:([^:\n\r]+?):\s*)?(.*)$',
  );

  /// Android / Web standard dash pattern: e.g. `21/10/2024, 11:04 pm - Sam 3: Yeshh`
  static final RegExp _standardDashRegex = RegExp(
    r'^([0-9]{1,4}[/\.-][0-9]{1,2}(?:[/\.-][0-9]{2,4})?),?\s+([0-9]{1,2}:[0-9]{2}(?::[0-9]{2})?(?:[\s\u202F\u00A0]*(?:[aApP]\.?[mM]\.?))?)\s*[-–—]\s*(?:([^:\n\r]+?):\s*)?(.*)$',
  );

  /// Known common WhatsApp system notices that lack a colon separator or are system actions.
  static final RegExp _systemNoticeRegex = RegExp(
    r'(?:Messages and calls are end-to-end encrypted|created group|added you|changed the subject|changed this group|left|joined using this group|security code changed|You deleted this message|This message was deleted|<Media omitted>|\b\w+\s+omitted\b)',
    caseSensitive: false,
  );

  /// Quick, non-blocking check to determine if [content] contains a formatted WhatsApp conversation.
  /// Designed for high performance in list item extractors.
  static bool isWhatsAppChat(String content) {
    if (content.length < 25) return false;
    if (!content.contains(':') && !content.contains(']')) return false;

    // Scan lines up to first 30 lines to find at least 2 chat headers
    final lines = content.split('\n');
    var matchCount = 0;
    final maxLinesToCheck = min(lines.length, 30);

    for (var i = 0; i < maxLinesToCheck; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (_bracketedRegex.hasMatch(line) || _standardDashRegex.hasMatch(line)) {
        matchCount++;
        if (matchCount >= 2) return true;
      }
    }
    return false;
  }

  /// Parses arbitrary raw text into a structured [WhatsAppParseResult].
  static WhatsAppParseResult parse(
    String rawText, {
    int? sourceStartIndex,
    int? sourceEndIndex,
  }) {
    if (rawText.trim().isEmpty) {
      return WhatsAppParseResult.empty;
    }

    // Normalize CRLF / CR to LF
    final normalized = rawText.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');

    final messages = <WhatsAppMessage>[];
    final unrecognizedLines = <String>[];

    var totalNonEmptyLines = 0;
    var recognizedLinesCount = 0;

    WhatsAppMessage? currentMessage;
    final currentRawLines = <String>[];

    void commitCurrentMessage() {
      if (currentMessage != null) {
        messages.add(currentMessage!.copyWith(
          body: currentMessage!.body.trimRight(),
          rawText: currentRawLines.join('\n'),
        ));
        currentMessage = null;
        currentRawLines.clear();
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (currentMessage != null) {
          // Empty line within a multi-line message
          currentMessage = currentMessage!.copyWith(
            body: '${currentMessage!.body}\n',
          );
          currentRawLines.add(line);
        }
        continue;
      }

      totalNonEmptyLines++;

      // Try Pattern A: Bracketed
      final bracketMatch = _bracketedRegex.firstMatch(trimmed);
      if (bracketMatch != null) {
        commitCurrentMessage();
        recognizedLinesCount++;

        final dateStr = bracketMatch.group(1)?.trim() ?? '';
        final timeStr = bracketMatch.group(2)?.trim() ?? '';
        final senderStr = bracketMatch.group(3)?.trim();
        final bodyStr = bracketMatch.group(4) ?? '';

        final isSystem = senderStr == null ||
            senderStr.isEmpty ||
            _systemNoticeRegex.hasMatch(senderStr) ||
            _systemNoticeRegex.hasMatch(bodyStr);

        currentMessage = WhatsAppMessage(
          date: dateStr,
          time: _cleanTimestamp(timeStr),
          sender: isSystem ? null : senderStr,
          body: isSystem && (senderStr != null && senderStr.isNotEmpty && bodyStr.isEmpty)
              ? senderStr
              : bodyStr,
          isSystemMessage: isSystem,
          parsedDate: _tryParseDate(dateStr),
        );
        currentRawLines.add(line);
        continue;
      }

      // Try Pattern B: Standard Dash
      final dashMatch = _standardDashRegex.firstMatch(trimmed);
      if (dashMatch != null) {
        commitCurrentMessage();
        recognizedLinesCount++;

        final dateStr = dashMatch.group(1)?.trim() ?? '';
        final timeStr = dashMatch.group(2)?.trim() ?? '';
        final senderStr = dashMatch.group(3)?.trim();
        final bodyStr = dashMatch.group(4) ?? '';

        final isSystem = senderStr == null ||
            senderStr.isEmpty ||
            _systemNoticeRegex.hasMatch(senderStr) ||
            _systemNoticeRegex.hasMatch(bodyStr);

        currentMessage = WhatsAppMessage(
          date: dateStr,
          time: _cleanTimestamp(timeStr),
          sender: isSystem ? null : senderStr,
          body: isSystem && (senderStr != null && senderStr.isNotEmpty && bodyStr.isEmpty)
              ? senderStr
              : bodyStr,
          isSystemMessage: isSystem,
          parsedDate: _tryParseDate(dateStr),
        );
        currentRawLines.add(line);
        continue;
      }

      // Line is not a new message header.
      if (currentMessage != null) {
        // Multi-line message continuation
        recognizedLinesCount++;
        currentMessage = currentMessage!.copyWith(
          body: '${currentMessage!.body}\n$line',
        );
        currentRawLines.add(line);
      } else {
        // Standalone unrecognized line before any chat messages
        unrecognizedLines.add(line);
        messages.add(WhatsAppMessage(
          date: '',
          time: '',
          body: line,
          isUnrecognized: true,
          rawText: line,
        ));
      }
    }

    commitCurrentMessage();

    final confidence = totalNonEmptyLines > 0
        ? (recognizedLinesCount / totalNonEmptyLines).clamp(0.0, 1.0)
        : 0.0;

    return WhatsAppParseResult(
      messages: messages,
      originalText: rawText,
      confidence: confidence,
      unrecognizedLines: unrecognizedLines,
      sourceStartIndex: sourceStartIndex,
      sourceEndIndex: sourceEndIndex,
    );
  }

  /// Normalizes narrow non-breaking spaces (\u202F) and regular non-breaking spaces (\u00A0) in timestamps.
  static String _cleanTimestamp(String raw) {
    return raw
        .replaceAll('\u202F', ' ')
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static DateTime? _tryParseDate(String dateStr) {
    try {
      final parts = dateStr.split(RegExp(r'[/\.-]'));
      if (parts.length >= 2) {
        final p1 = int.parse(parts[0]);
        final p2 = int.parse(parts[1]);
        int year = DateTime.now().year;
        if (parts.length >= 3) {
          final p3 = int.parse(parts[2]);
          year = p3 < 100 ? 2000 + p3 : p3;
        }

        // Check if DD/MM or MM/DD
        int day = p1;
        int month = p2;
        if (p1 <= 12 && p2 > 12) {
          month = p1;
          day = p2;
        }
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return null;
  }
}
