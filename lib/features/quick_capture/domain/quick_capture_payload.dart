import 'package:flutter/foundation.dart';

/// The point of entry for a Quick Capture session.
enum CaptureOrigin {
  /// Launched via the compact Android home-screen widget.
  widget,

  /// Launched via the system Share sheet (ACTION_SEND text/URL).
  share,

  /// Launched internally from within the application.
  inApp,
}

/// Immutable descriptor of an incoming Quick Capture request.
@immutable
class QuickCapturePayload {
  const QuickCapturePayload({
    required this.id,
    required this.targetNoteId,
    required this.origin,
    this.initialContent = '',
    this.sourceUrl,
    this.titleHint,
    this.cursorPosition = 0,
    required this.createdAt,
  });

  /// Unique session identifier (UUID v4).
  final String id;

  /// Stable target note identifier (UUID v4) preserved across retries.
  final String targetNoteId;

  /// Origin that triggered this capture session.
  final CaptureOrigin origin;

  /// Pre-filled initial content (e.g. shared text or URL).
  final String initialContent;

  /// Optional source URL extracted from the share payload.
  final String? sourceUrl;

  /// Optional title hint (e.g. from an email/browser subject).
  final String? titleHint;

  /// Saved or initial cursor position.
  final int cursorPosition;

  /// Timestamp when the capture request was instantiated.
  final DateTime createdAt;

  /// Whether the initial payload contains an identifiable web link.
  bool get hasSourceUrl => sourceUrl != null && sourceUrl!.trim().isNotEmpty;

  QuickCapturePayload copyWith({
    String? id,
    String? targetNoteId,
    CaptureOrigin? origin,
    String? initialContent,
    String? sourceUrl,
    String? titleHint,
    int? cursorPosition,
    DateTime? createdAt,
  }) {
    return QuickCapturePayload(
      id: id ?? this.id,
      targetNoteId: targetNoteId ?? this.targetNoteId,
      origin: origin ?? this.origin,
      initialContent: initialContent ?? this.initialContent,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      titleHint: titleHint ?? this.titleHint,
      cursorPosition: cursorPosition ?? this.cursorPosition,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
