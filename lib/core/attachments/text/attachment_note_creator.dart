import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../../../features/import/application/markdown_frontmatter_parser.dart';
import '../../../features/notes/data/notes_repository.dart';
import '../../../features/notes/domain/note_model.dart';
import '../../database/app_database.dart';
import '../attachment_type_resolver.dart';
import 'attachment_csv_parser.dart';
import 'attachment_text_decoder.dart';
import 'attachment_text_detector.dart';

/// Service for creating independent, canonical Quiet Paper notes from text attachments.
///
/// Ensures strict immutability of the source attachment, enforces document size limits,
/// extracts YAML frontmatter/tags where present, and safely formats tables/codeblocks.
class AttachmentNoteCreator {
  const AttachmentNoteCreator._();

  static const _uuid = Uuid();

  /// Maximum permitted content size for creating a note (5 MB).
  static const int maxNoteContentBytes = 5 * 1024 * 1024;

  /// Creates a new Quiet Paper note from an attachment's decrypted bytes.
  static Future<Note> createNoteFromAttachment({
    required NotesRepository notesRepository,
    required AttachmentEntity attachment,
    required Uint8List rawBytes,
    String? preferredTitle,
  }) async {
    if (rawBytes.length > maxNoteContentBytes) {
      throw ArgumentError(
        'This file is too large to import as a note (maximum 5 MB).',
      );
    }

    final decoded = AttachmentTextDecoder.decode(rawBytes);
    if (!decoded.isSuccess) {
      throw StateError(
        decoded.errorMessage ?? "This file's text encoding isn't supported.",
      );
    }

    final format = AttachmentTextDetector.detectFormat(
      fileName: attachment.fileName,
      bytes: rawBytes,
      mimeType: attachment.mimeType,
    );

    String noteTitle;
    String noteContent;
    List<String> tags = [];

    final cleanFileName = AttachmentTypeResolver.sanitizeFileName(attachment.fileName);
    final ext = AttachmentTypeResolver.inferExtension(cleanFileName);
    final baseTitle = (preferredTitle != null && preferredTitle.trim().isNotEmpty)
        ? preferredTitle.trim()
        : (cleanFileName.contains('.')
            ? cleanFileName.substring(0, cleanFileName.lastIndexOf('.'))
            : cleanFileName);

    final titleFallback = baseTitle.isNotEmpty ? baseTitle : 'New Note';

    switch (format) {
      case TextAttachmentFormat.markdown:
        final parsed = MarkdownFrontmatterParser.parse(decoded.text);
        noteTitle = (parsed.title != null && parsed.title!.trim().isNotEmpty)
            ? parsed.title!.trim()
            : titleFallback;
        noteContent = decoded.text;
        tags = List<String>.from(parsed.tags);
        break;

      case TextAttachmentFormat.csv:
      case TextAttachmentFormat.tsv:
        final table = AttachmentCsvParser.parse(
          decoded.text,
          delimiter: format == TextAttachmentFormat.tsv ? '\t' : ',',
        );
        noteTitle = titleFallback;
        noteContent = AttachmentCsvParser.convertToMarkdownTable(table);
        break;

      case TextAttachmentFormat.plainText:
      case TextAttachmentFormat.log:
      case TextAttachmentFormat.config:
      case TextAttachmentFormat.unknownText:
        noteTitle = titleFallback;
        noteContent = decoded.text;
        break;

      case TextAttachmentFormat.sourceCode:
      case TextAttachmentFormat.json:
      case TextAttachmentFormat.yaml:
      case TextAttachmentFormat.xml:
      case TextAttachmentFormat.toml:
        noteTitle = titleFallback;
        final lang = ext.isNotEmpty ? ext : '';
        noteContent = '```$lang\n${decoded.text}\n```';
        break;

      case TextAttachmentFormat.binary:
        throw UnsupportedError('Binary files cannot be imported as notes.');
    }

    final now = DateTime.now();
    final noteId = _uuid.v4();
    final note = Note(
      id: noteId,
      title: noteTitle,
      content: noteContent,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );

    await notesRepository.saveNote(note);
    return note;
  }
}
