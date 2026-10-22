import 'package:flutter/foundation.dart';
import 'whatsapp_message.dart';

/// The result of analyzing and parsing text as a WhatsApp conversation.
@immutable
class WhatsAppParseResult {
  const WhatsAppParseResult({
    required this.messages,
    required this.originalText,
    required this.confidence,
    required this.unrecognizedLines,
    this.sourceStartIndex,
    this.sourceEndIndex,
  });

  /// The sequence of parsed messages, system events, and preserved unrecognized lines.
  final List<WhatsAppMessage> messages;

  /// The raw input text that was evaluated.
  final String originalText;

  /// Confidence score between 0.0 and 1.0 that this text is an authentic WhatsApp chat.
  final double confidence;

  /// Lines that could not be parsed as chat messages or system notices.
  final List<String> unrecognizedLines;

  /// Optional start offset of the chat in the parent note body.
  final int? sourceStartIndex;

  /// Optional end offset of the chat in the parent note body.
  final int? sourceEndIndex;

  /// Whether this result passes the confidence threshold and qualifies as a WhatsApp conversation.
  bool get isWhatsAppChat =>
      confidence >= 0.5 && messageCount >= 2;

  /// Count of genuine chat messages (excluding system events and unrecognized fragments).
  int get messageCount =>
      messages.where((m) => !m.isSystemMessage && !m.isUnrecognized).length;

  /// Distinct list of participant/sender names identified in the conversation.
  List<String> get participants {
    final set = <String>{};
    for (final m in messages) {
      if (m.sender != null && m.sender!.trim().isNotEmpty && !m.isSystemMessage) {
        set.add(m.sender!.trim());
      }
    }
    return set.toList();
  }

  /// Whether any lines had ambiguous or unrecognized formatting.
  bool get hasUnrecognizedLines => unrecognizedLines.isNotEmpty;

  /// Formatted date range label matching Quiet Paper mockup (e.g., 'OCTOBER 21–22' or '21/10 – 22/10').
  String get dateRangeLabel {
    final dates = <String>{};
    for (final m in messages) {
      if (m.date.isNotEmpty) {
        dates.add(m.date);
      }
    }
    if (dates.isEmpty) return 'CONVERSATION';
    if (dates.length == 1) {
      return _formatSingleDateLabel(dates.first);
    }

    final d1 = _parseDateParts(dates.first);
    final d2 = _parseDateParts(dates.last);
    if (d1 != null && d2 != null) {
      if (d1.month == d2.month) {
        final monthName = _monthName(d1.month);
        return '$monthName ${d1.day}–${d2.day}';
      } else {
        return '${_monthName(d1.month)} ${d1.day}–${_monthName(d2.month)} ${d2.day}';
      }
    }

    final first = _formatSingleDateLabel(dates.first);
    final last = _formatSingleDateLabel(dates.last);
    if (first == last) return first;
    return '$first–$last';
  }

  /// Proposes a descriptive, respectful note title based on the conversation participants.
  String get suggestedTitle {
    final parts = participants;
    if (parts.isEmpty) return 'WhatsApp conversation';
    if (parts.length == 1) return 'Conversation with ${parts.first}';
    if (parts.length == 2) {
      return 'Conversation with ${parts.first} & ${parts.last}';
    }
    return 'Conversation with friends';
  }

  static ({int day, int month})? _parseDateParts(String rawDate) {
    final parts = rawDate.split(RegExp(r'[/\.-]'));
    if (parts.length >= 2) {
      final p1 = int.tryParse(parts[0]);
      final p2 = int.tryParse(parts[1]);
      if (p1 != null && p2 != null) {
        int day = p1;
        int month = p2;
        if (p1 <= 12 && p2 > 12) {
          month = p1;
          day = p2;
        }
        if (month >= 1 && month <= 12) {
          return (day: day, month: month);
        }
      }
    }
    return null;
  }

  static String _monthName(int month) {
    const monthNames = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    if (month >= 1 && month <= 12) {
      return monthNames[month - 1];
    }
    return '';
  }

  static String _formatSingleDateLabel(String rawDate) {
    final parsed = _parseDateParts(rawDate);
    if (parsed != null) {
      return '${_monthName(parsed.month)} ${parsed.day}';
    }
    return rawDate.toUpperCase();
  }

  static const empty = WhatsAppParseResult(
    messages: [],
    originalText: '',
    confidence: 0.0,
    unrecognizedLines: [],
  );
}
