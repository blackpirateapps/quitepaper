import 'package:path/path.dart' as p;
import '../../notes/application/note_security_service.dart';
import '../../notes/domain/note_model.dart';

/// Exception thrown when an export operation fails security validation.
class ExportSecurityException implements Exception {
  const ExportSecurityException(this.message);
  final String message;

  @override
  String toString() => 'ExportSecurityException: $message';
}

/// Security verification guard for note export operations.
class ExportSecurityGuard {
  const ExportSecurityGuard();

  /// Validates and unlocks note content if password protected.
  /// Returns decrypted note payload and tags.
  Future<({String title, String content, List<String> tags})> verifyAndUnlockNote({
    required Note note,
    String? suppliedPassword,
  }) async {
    final isEncrypted = NoteSecurityService.isEncrypted(note.content);

    if (!isEncrypted) {
      return (
        title: note.title,
        content: note.content,
        tags: note.tags,
      );
    }

    if (suppliedPassword == null || suppliedPassword.trim().isEmpty) {
      throw const ExportSecurityException(
        'Note is password-protected. Please provide the password to export this note.',
      );
    }

    try {
      final decrypted = await NoteSecurityService.decryptNote(
        encryptedContent: note.content,
        password: suppliedPassword.trim(),
      );

      final combinedTags = <String>{...note.tags, ...decrypted.tags}.toList();

      return (
        title: decrypted.title.isNotEmpty ? decrypted.title : note.title,
        content: decrypted.content,
        tags: combinedTags,
      );
    } on InvalidNotePasswordException catch (e) {
      throw ExportSecurityException(e.message);
    } catch (e) {
      throw ExportSecurityException('Failed to decrypt protected note: $e');
    }
  }

  /// Verifies that a relative [relativePath] does not perform path traversal (e.g. `../` or `/root`).
  static void validateRelativePathSafety(String relativePath) {
    final normalized = p.normalize(relativePath);
    if (normalized.startsWith('..') ||
        p.isAbsolute(normalized) ||
        normalized.contains('../') ||
        normalized.contains('..\\') ||
        normalized.startsWith('/') ||
        normalized.startsWith('\\') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      throw ExportSecurityException(
        'Unsafe path traversal detected in export resource path: "$relativePath"',
      );
    }
  }

  /// Verifies that a target file path is securely contained inside the expected [rootDir].
  static void validateContainedInDirectory(String filePath, String rootDir) {
    final canonicalFile = p.canonicalize(filePath);
    final canonicalRoot = p.canonicalize(rootDir);

    if (!p.isWithin(canonicalRoot, canonicalFile) && canonicalFile != canonicalRoot) {
      throw ExportSecurityException(
        'Path traversal violation: "$filePath" is outside target directory "$rootDir"',
      );
    }
  }

  /// Sanitizes text to prevent HTML injection and XSS when generating HTML documents.
  static String escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
