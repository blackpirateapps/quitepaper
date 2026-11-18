import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../domain/email_message.dart';
import 'email_parser.dart';

/// File-system paths and file URIs supplied by picker/drop/Android staging.
/// content:// is resolved natively while its temporary permission is valid.
class EmailInput {
  const EmailInput({required this.path, this.name, this.mimeType});
  final String path;
  final String? name, mimeType;
  static const emailMimeTypes = {
    'message/rfc822',
    'message/global',
    'application/eml',
    'application/x-eml',
  };
  String get displayName => name ?? p.basename(localPath);
  String get localPath {
    if (path.startsWith('file:')) {
      try {
        return Uri.parse(path).toFilePath();
      } catch (_) {
        throw const EmailImportException(
          'path',
          'The email file location is invalid.',
        );
      }
    }
    if (path.startsWith('content:')) {
      throw const EmailImportException(
        'permission',
        'The shared file permission expired. Share the file again.',
      );
    }
    return path;
  }

  bool get isDeclaredEmail =>
      p.extension(displayName).toLowerCase() == '.eml' ||
      emailMimeTypes.contains(mimeType?.split(';').first.toLowerCase());
  Future<bool> isEmailCandidate() async {
    if (isDeclaredEmail) return true;
    if ({
      '.msg',
      '.mbox',
      '.pst',
      '.ost',
    }.contains(p.extension(displayName).toLowerCase())) {
      return false;
    }
    try {
      final file = await File(localPath).open();
      try {
        return EmailParser.looksLikeEmail(await file.read(65536));
      } finally {
        await file.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> read({EmailLimits limits = const EmailLimits()}) async {
    try {
      final file = await File(localPath).open();
      try {
        final size = await file.length();
        if (size == 0 || size > limits.rawBytes) {
          throw const EmailImportException(
            'raw_size',
            'Email is empty or exceeds the 50 MiB import limit.',
          );
        }
        final bytes = await file.read(size + 1);
        if (bytes.length > limits.rawBytes) {
          throw const EmailImportException(
            'raw_size',
            'Email exceeds the 50 MiB import limit.',
          );
        }
        return bytes;
      } finally {
        await file.close();
      }
    } on EmailImportException {
      rethrow;
    } catch (_) {
      throw const EmailImportException(
        'file_access',
        'Could not read the email. Check file access or select it again.',
      );
    }
  }
}
