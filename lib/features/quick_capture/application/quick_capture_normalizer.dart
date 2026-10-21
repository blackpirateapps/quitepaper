import 'package:uuid/uuid.dart';
import '../domain/quick_capture_payload.dart';

/// Testable content normalization layer that transforms incoming untrusted
/// Android intents, shares, and widget launch data into validated [QuickCapturePayload]s.
class QuickCaptureNormalizer {
  /// Maximum sensible character size for an incoming quick capture payload (500 KB of text).
  static const int maxPayloadLength = 500000;

  static const _uuid = Uuid();

  /// Regular expression to match standard HTTP/HTTPS URLs.
  static final RegExp urlRegex = RegExp(r'https?://[^\s]+');

  /// Normalizes incoming raw text, optional URI, and optional subject.
  static QuickCapturePayload normalize({
    required CaptureOrigin origin,
    String? rawText,
    String? rawUri,
    String? rawSubject,
    String? explicitSessionId,
    String? explicitTargetNoteId,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final sessionId = explicitSessionId ?? _uuid.v4();
    final targetNoteId = explicitTargetNoteId ?? _uuid.v4();

    // 1. Clean input strings
    final text = rawText ?? '';
    final uri = (rawUri ?? '').trim();
    final subject = (rawSubject ?? '').trim();

    // 2. Extract potential URL from text or URI parameter
    String? detectedUrl;
    if (uri.isNotEmpty && (uri.startsWith('http://') || uri.startsWith('https://'))) {
      detectedUrl = uri;
    } else {
      final match = urlRegex.firstMatch(text);
      if (match != null) {
        detectedUrl = match.group(0);
      }
    }

    // 3. Assemble content adhering to duplication and whitespace rules
    String normalizedContent;
    if (text.trim().isEmpty) {
      normalizedContent = detectedUrl ?? '';
    } else {
      var workingText = text;
      // Handle oversized content explicitly
      if (workingText.length > maxPayloadLength) {
        workingText =
            '${workingText.substring(0, maxPayloadLength)}\n\n[Content capped at $maxPayloadLength characters]';
      }

      // If a separate URI was supplied and not already in text, append it
      if (detectedUrl != null && !workingText.contains(detectedUrl)) {
        normalizedContent = '$workingText\n\n$detectedUrl';
      } else {
        normalizedContent = workingText;
      }
    }

    // 4. Derive title hint from subject if meaningful
    String? titleHint;
    if (subject.isNotEmpty) {
      // Don't treat a bare URL or duplicate text as a title hint
      if (!subject.startsWith('http://') &&
          !subject.startsWith('https://') &&
          subject != normalizedContent.trim()) {
        titleHint = subject.length > 120 ? '${subject.substring(0, 117)}...' : subject;
      }
    }

    return QuickCapturePayload(
      id: sessionId,
      targetNoteId: targetNoteId,
      origin: origin,
      initialContent: normalizedContent,
      sourceUrl: detectedUrl,
      titleHint: titleHint,
      cursorPosition: normalizedContent.length,
      createdAt: timestamp,
    );
  }

  /// Extracts the first URL from a string if present.
  static String? extractUrl(String text) {
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text.split(RegExp(r'\s+')).first;
    }
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
  }
}
