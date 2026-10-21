import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/quick_capture/application/quick_capture_normalizer.dart';
import 'package:quitepaper/features/quick_capture/domain/quick_capture_payload.dart';

void main() {
  group('QuickCaptureNormalizer Tests', () {
    test('handles empty and whitespace-only text gracefully', () {
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.widget,
        rawText: '   \n  \t  ',
      );

      expect(payload.initialContent, isEmpty);
      expect(payload.sourceUrl, isNull);
      expect(payload.titleHint, isNull);
      expect(payload.origin, CaptureOrigin.widget);
      expect(payload.id, isNotEmpty);
      expect(payload.targetNoteId, isNotEmpty);
    });

    test('normalizes plain text and preserves Unicode and line breaks', () {
      const text = 'Hello world!\nLine 2 with Bengali: বাংলা লিপি\nLine 3 with emoji: 📝✨';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: text,
      );

      expect(payload.initialContent, text);
      expect(payload.origin, CaptureOrigin.share);
      expect(payload.sourceUrl, isNull);
      expect(payload.cursorPosition, text.length);
    });

    test('handles URL-only content correctly', () {
      const url = 'https://example.com/article?id=123';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: url,
      );

      expect(payload.initialContent, url);
      expect(payload.sourceUrl, url);
      expect(payload.titleHint, isNull);
    });

    test('extracts title hint from subject when distinct from content', () {
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: 'Here is a note from my email.',
        rawSubject: 'Meeting Notes regarding Project X',
      );

      expect(payload.titleHint, 'Meeting Notes regarding Project X');
      expect(payload.initialContent, 'Here is a note from my email.');
    });

    test('ignores subject if it is identical to URL or content', () {
      const url = 'https://example.com';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: url,
        rawSubject: url,
      );

      expect(payload.titleHint, isNull);
      expect(payload.sourceUrl, url);
    });

    test('avoids duplicating URL when text already contains it', () {
      const url = 'https://quietpaper.org/docs';
      const text = 'Check out the documentation at https://quietpaper.org/docs for details.';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: text,
        rawUri: url,
      );

      expect(payload.initialContent, text);
      expect(payload.sourceUrl, url);
      // Ensure url is not appended a second time
      expect(RegExp(r'https:\/\/quietpaper\.org\/docs').allMatches(payload.initialContent).length, 1);
    });

    test('appends URL when text does not contain it', () {
      const text = 'Quoted interesting paragraph from a blog post.';
      const url = 'https://blog.example.com/post/1';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: text,
        rawUri: url,
      );

      expect(payload.initialContent, '$text\n\n$url');
      expect(payload.sourceUrl, url);
    });

    test('caps oversized payload without crashing', () {
      final hugeText = 'A' * 600000;
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.share,
        rawText: hugeText,
      );

      expect(payload.initialContent.length, lessThan(600000));
      expect(payload.initialContent, contains('[Content capped at 500000 characters]'));
    });

    test('preserves explicitSessionId and targetNoteId across retries', () {
      const sessionId = 'session-1234';
      const noteId = 'note-5678';
      final payload = QuickCaptureNormalizer.normalize(
        origin: CaptureOrigin.widget,
        rawText: 'Thought',
        explicitSessionId: sessionId,
        explicitTargetNoteId: noteId,
      );

      expect(payload.id, sessionId);
      expect(payload.targetNoteId, noteId);
    });
  });
}
