import 'package:flutter/foundation.dart';

/// Represents a single parsed message or event from a WhatsApp chat export.
@immutable
class WhatsAppMessage {
  const WhatsAppMessage({
    required this.date,
    required this.time,
    required this.body,
    this.sender,
    this.parsedDate,
    this.isSystemMessage = false,
    this.isUnrecognized = false,
    this.rawText = '',
    this.sourceStartIndex,
    this.sourceEndIndex,
  });

  /// The original date string as extracted from the chat header (e.g., '21/10', '21/10/2024').
  final String date;

  /// Optional parsed [DateTime] if the date and time format could be resolved.
  final DateTime? parsedDate;

  /// The original timestamp string (e.g., '11:04 pm', '23:15:30').
  final String time;

  /// The sender name, or `null` if this is a system event/notice.
  final String? sender;

  /// The exact message content, including emojis, URLs, and any continuation lines.
  final String body;

  /// Whether this is an automated WhatsApp system message (e.g., encryption notice, group changes).
  final bool isSystemMessage;

  /// Whether this line could not be confidently identified as a message or system notice.
  final bool isUnrecognized;

  /// The complete raw string from the source chat corresponding to this message.
  final String rawText;

  /// Optional starting character offset in the source string.
  final int? sourceStartIndex;

  /// Optional ending character offset in the source string.
  final int? sourceEndIndex;

  WhatsAppMessage copyWith({
    String? date,
    DateTime? parsedDate,
    String? time,
    String? sender,
    String? body,
    bool? isSystemMessage,
    bool? isUnrecognized,
    String? rawText,
    int? sourceStartIndex,
    int? sourceEndIndex,
  }) {
    return WhatsAppMessage(
      date: date ?? this.date,
      parsedDate: parsedDate ?? this.parsedDate,
      time: time ?? this.time,
      sender: sender ?? this.sender,
      body: body ?? this.body,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
      isUnrecognized: isUnrecognized ?? this.isUnrecognized,
      rawText: rawText ?? this.rawText,
      sourceStartIndex: sourceStartIndex ?? this.sourceStartIndex,
      sourceEndIndex: sourceEndIndex ?? this.sourceEndIndex,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppMessage &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          time == other.time &&
          sender == other.sender &&
          body == other.body &&
          isSystemMessage == other.isSystemMessage &&
          isUnrecognized == other.isUnrecognized;

  @override
  int get hashCode => Object.hash(
        date,
        time,
        sender,
        body,
        isSystemMessage,
        isUnrecognized,
      );

  @override
  String toString() =>
      'WhatsAppMessage(date: $date, time: $time, sender: $sender, body: ${body.length > 30 ? "${body.substring(0, 30)}..." : body})';
}
