import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/notes/application/note_security_service.dart';
import 'package:quitepaper/features/notes/domain/note_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NoteSecurityService', () {
    test('encrypts and decrypts note payload accurately with valid password', () async {
      const originalTitle = 'Secret Ideas & Roadmaps';
      const originalContent = '# Classified\n\nThis note contains sensitive roadmap details.';
      final originalTags = ['secret', 'roadmap'];
      const password = 'CorrectHorseBatteryStaple123!';
      const hint = 'battery horse';

      final encryptedPayload = await NoteSecurityService.encryptNote(
        title: originalTitle,
        content: originalContent,
        tags: originalTags,
        password: password,
        hint: hint,
      );

      expect(NoteSecurityService.isEncrypted(encryptedPayload), isTrue);
      expect(NoteSecurityService.getHint(encryptedPayload), equals(hint));
      expect(encryptedPayload.contains(originalTitle), isFalse);
      expect(encryptedPayload.contains(originalContent), isFalse);

      final decrypted = await NoteSecurityService.decryptNote(
        encryptedContent: encryptedPayload,
        password: password,
      );

      expect(decrypted.title, equals(originalTitle));
      expect(decrypted.content, equals(originalContent));
      expect(decrypted.tags, equals(originalTags));
      expect(decrypted.hint, equals(hint));
    });

    test('throws InvalidNotePasswordException when wrong password is used', () async {
      final encryptedPayload = await NoteSecurityService.encryptNote(
        title: 'Secret',
        content: 'Data',
        password: 'ValidPassword123',
      );

      expect(
        () async => await NoteSecurityService.decryptNote(
          encryptedContent: encryptedPayload,
          password: 'WrongPassword999',
        ),
        throwsA(isA<InvalidNotePasswordException>()),
      );
    });

    test('isEncrypted returns false for normal markdown text', () {
      expect(NoteSecurityService.isEncrypted('# Hello World'), isFalse);
      expect(NoteSecurityService.isEncrypted('Just a normal note'), isFalse);
      expect(NoteSecurityService.isEncrypted(''), isFalse);
    });
  });

  group('Note Model Password Protection Helpers', () {
    test('isPasswordProtected, displayTitle, and previewSnippet for encrypted notes', () async {
      final encryptedPayload = await NoteSecurityService.encryptNote(
        title: 'Secret Title',
        content: 'Confidential content',
        password: 'myPassword',
      );

      final encryptedNote = Note(
        id: 'note-1',
        title: '',
        content: encryptedPayload,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(encryptedNote.isPasswordProtected, isTrue);
      expect(encryptedNote.displayTitle, equals('Protected Note'));
      expect(encryptedNote.previewSnippet, equals('🔒 Password protected note'));

      final normalNote = Note(
        id: 'note-2',
        title: 'Normal Title',
        content: 'Normal content body',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(normalNote.isPasswordProtected, isFalse);
      expect(normalNote.displayTitle, equals('Normal Title'));
      expect(normalNote.previewSnippet, equals('Normal content body'));
    });
  });
}
