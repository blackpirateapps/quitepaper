import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/export/application/export_security_guard.dart';
import 'package:quitepaper/features/notes/application/note_security_service.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  group('ExportSecurityGuard', () {
    const securityGuard = ExportSecurityGuard();

    test('returns plaintext note directly if not password protected', () async {
      final note = Note(
        id: 'note-1',
        title: 'Public Note',
        content: '# Heading\nThis is clear text.',
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        tags: const ['work', 'public'],
      );

      final result = await securityGuard.verifyAndUnlockNote(note: note);
      expect(result.title, equals('Public Note'));
      expect(result.content, equals('# Heading\nThis is clear text.'));
      expect(result.tags, equals(['work', 'public']));
    });

    test('throws ExportSecurityException when exporting password protected note without password', () async {
      final encryptedContent = await NoteSecurityService.encryptNote(
        title: 'Secret Note',
        content: 'Top secret data',
        password: 'correct_password',
        hint: 'secret hint',
        tags: const ['confidential'],
      );

      final note = Note(
        id: 'note-2',
        title: 'Secret Note',
        content: encryptedContent,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      expect(
        () => securityGuard.verifyAndUnlockNote(note: note),
        throwsA(isA<ExportSecurityException>()),
      );
    });

    test('decrypts password protected note when valid password supplied', () async {
      final encryptedContent = await NoteSecurityService.encryptNote(
        title: 'Secret Note',
        content: 'Decrypted markdown body',
        password: 'secure_password_123',
        hint: 'mypassword',
        tags: const ['private'],
      );

      final note = Note(
        id: 'note-3',
        title: 'Secret Note',
        content: encryptedContent,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
        tags: const ['secure'],
      );

      final result = await securityGuard.verifyAndUnlockNote(
        note: note,
        suppliedPassword: 'secure_password_123',
      );

      expect(result.title, equals('Secret Note'));
      expect(result.content, equals('Decrypted markdown body'));
      expect(result.tags, containsAll(['secure', 'private']));
    });

    test('throws ExportSecurityException on invalid password', () async {
      final encryptedContent = await NoteSecurityService.encryptNote(
        title: 'Secret Note',
        content: 'Sensitive body',
        password: 'real_password',
      );

      final note = Note(
        id: 'note-4',
        title: 'Secret Note',
        content: encryptedContent,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      expect(
        () => securityGuard.verifyAndUnlockNote(
          note: note,
          suppliedPassword: 'wrong_password',
        ),
        throwsA(isA<ExportSecurityException>()),
      );
    });

    test('validates relative path safety against path traversal', () {
      expect(
        () => ExportSecurityGuard.validateRelativePathSafety('../secret.txt'),
        throwsA(isA<ExportSecurityException>()),
      );
      expect(
        () => ExportSecurityGuard.validateRelativePathSafety('/etc/shadow'),
        throwsA(isA<ExportSecurityException>()),
      );
      expect(
        () => ExportSecurityGuard.validateRelativePathSafety('attachments/../../escape.bin'),
        throwsA(isA<ExportSecurityException>()),
      );

      expect(
        () => ExportSecurityGuard.validateRelativePathSafety('attachments/image-001.png'),
        returnsNormally,
      );
    });

    test('escapes HTML strings safely for XSS prevention', () {
      final input = '<script>alert("xss")</script> & "quotes"';
      final escaped = ExportSecurityGuard.escapeHtml(input);
      expect(escaped, equals('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt; &amp; &quot;quotes&quot;'));
    });
  });
}
