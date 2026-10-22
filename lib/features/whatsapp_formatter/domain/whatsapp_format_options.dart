import 'package:flutter/foundation.dart';

/// Formatting preferences for converting parsed WhatsApp chats into Markdown.
@immutable
class WhatsAppFormatOptions {
  const WhatsAppFormatOptions({
    this.showSenderNames = true,
    this.preserveTimestamps = true,
    this.groupConsecutiveMessages = true,
  });

  /// Whether to render sender names (e.g. `**Sam 3**`).
  final bool showSenderNames;

  /// Whether to preserve individual message timestamps (e.g. `_11:04 pm_ · `).
  final bool preserveTimestamps;

  /// Whether consecutive messages from the same sender on the same date are grouped together.
  final bool groupConsecutiveMessages;

  WhatsAppFormatOptions copyWith({
    bool? showSenderNames,
    bool? preserveTimestamps,
    bool? groupConsecutiveMessages,
  }) {
    return WhatsAppFormatOptions(
      showSenderNames: showSenderNames ?? this.showSenderNames,
      preserveTimestamps: preserveTimestamps ?? this.preserveTimestamps,
      groupConsecutiveMessages:
          groupConsecutiveMessages ?? this.groupConsecutiveMessages,
    );
  }

  Map<String, dynamic> toJson() => {
        'showSenderNames': showSenderNames,
        'preserveTimestamps': preserveTimestamps,
        'groupConsecutiveMessages': groupConsecutiveMessages,
      };

  factory WhatsAppFormatOptions.fromJson(Map<String, dynamic> json) {
    return WhatsAppFormatOptions(
      showSenderNames: json['showSenderNames'] as bool? ?? true,
      preserveTimestamps: json['preserveTimestamps'] as bool? ?? true,
      groupConsecutiveMessages:
          json['groupConsecutiveMessages'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppFormatOptions &&
          runtimeType == other.runtimeType &&
          showSenderNames == other.showSenderNames &&
          preserveTimestamps == other.preserveTimestamps &&
          groupConsecutiveMessages == other.groupConsecutiveMessages;

  @override
  int get hashCode => Object.hash(
        showSenderNames,
        preserveTimestamps,
        groupConsecutiveMessages,
      );
}
