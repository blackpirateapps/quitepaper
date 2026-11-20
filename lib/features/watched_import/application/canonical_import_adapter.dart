import 'dart:convert';
import 'dart:isolate';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import '../../../core/attachments/attachment_service.dart';
import '../../../core/documents/document_service.dart';
import '../../../core/documents/document_models.dart';
import '../../../core/security/sensitive_preview_registry.dart';
import '../../../core/utils/tag_parser.dart';
import '../../email_import/application/email_import_service.dart';
import '../../email_import/application/email_parser.dart';
import '../../email_import/domain/email_message.dart';
import '../../import/application/markdown_frontmatter_parser.dart';
import '../../import/application/markdown_import_service.dart';
import '../../import/domain/markdown_import_item.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../data/watched_import_repository.dart';
import '../native/api/engine.dart';

/// Headless integration only. MIME/HTML conversion, asset encryption, Markdown
/// policy, note storage, indexing and sync dirtiness remain in canonical services.
class CanonicalImportAdapter {
  CanonicalImportAdapter({
    required this.store,
    required this.email,
    required this.notes,
    required this.attachments,
    required this.documents,
  });
  final WatchedImportRepositoryAdapter store;
  final EmailImportService email;
  final NotesRepository notes;
  final AttachmentService attachments;
  final DocumentService documents;

  Future<void> recover() async {
    // EmailImportService serializes manual + watched saves. Its existing recovery
    // guard will not purge an active manual preparation.
    await email.recoverInterruptedImports();
    final stages = await store.rows('SELECT * FROM watched_import_stages');
    for (final stage in stages) {
      final id = stage.read<String>('asset_id');
      if (stage.read<String>('kind') == 'document') {
        await documents.purgeLocalDocument(id);
      } else {
        await attachments.purgeLocalAttachment(id);
      }
      await store.write('DELETE FROM watched_import_stages WHERE asset_id=?', [
        id,
      ]);
    }
    await store.write(
      "UPDATE watched_import_jobs SET status='ready' WHERE status='importing'",
    );
  }

  Future<Note> import(
    Candidate c,
    QueryRow job,
    Uint8List bytes, {
    required bool Function() isCurrent,
  }) async {
    final securityRevision = SensitivePreviewRegistry.revision.value;
    void check() {
      if (!isCurrent() ||
          !attachments.keyManager.isUnlocked ||
          securityRevision != SensitivePreviewRegistry.revision.value) {
        throw const EmailImportException(
          'locked',
          'Unlock your notebook to continue.',
        );
      }
    }

    check();
    if (bytes.length != c.size) {
      throw const EmailImportException(
        'source_changed',
        'Source changed. Rescan to retry.',
      );
    }
    await store.transition(job.read<String>('id'), 'importing', event: false);
    final id = job.read<String>('planned_note_id');
    final override = job.read<String>('override_id').isNotEmpty;
    if (c.format == 'eml') {
      final message = await const EmailParser().parse(bytes);
      check();
      if (message.rawHash != c.sha256) {
        throw const EmailImportException(
          'source_changed',
          'Source changed. Rescan to retry.',
        );
      }
      if (!override &&
          await store.hasMessageId(
            job.read<String>('vault_scope'),
            message.messageId,
          )) {
        throw const EmailImportException(
          'message_id_changed',
          'A different version of this message was imported. Review before importing again.',
        );
      }
      return email.save(
        email: message,
        mode: EmailImportMode.editable,
        title: message.subject,
        allowDuplicate: true,
        plannedNoteId: id,
        isCancelled: () => !isCurrent(),
        commitInTransaction: (note) async {
          check();
          await store.commitReceipt(job, c, messageId: message.messageId);
          check();
        },
      );
    }

    final format = c.format;
    final binary = const {'pdf', 'png', 'jpg', 'jpeg', 'webp'}.contains(format);
    final stageId = binary ? WatchedImportRepositoryAdapter.uuid.v4() : null;
    if (stageId != null) {
      await store.write(
        'INSERT INTO watched_import_stages(asset_id,kind,job_id) VALUES(?,?,?)',
        [
          stageId,
          format == 'pdf' ? 'document' : 'attachment',
          job.read<String>('id'),
        ],
      );
    }
    try {
      return await store.database.transaction(() async {
        check();
        var title = p.basenameWithoutExtension(c.displayName);
        var content = '';
        if (format == 'pdf') {
          if (bytes.length < 5 ||
              ascii.decode(bytes.sublist(0, 5), allowInvalid: true) !=
                  '%PDF-') {
            throw const EmailImportException(
              'invalid_pdf',
              'This file is not a PDF.',
            );
          }
          final pages = await _pdfPages(bytes);
          final result = await documents.createDocumentFromPdfBytes(
            pdfBytes: bytes,
            pageCount: pages,
            noteId: id,
            title: title,
            source: DocumentSource.importedPdf,
            autoRunOcr: false,
            preparedId: stageId,
            cachePlaintext: false,
          );
          content = result.markdownSnippet;
        } else if (binary) {
          final mime = switch (format) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            _ => 'image/jpeg',
          };
          final result = await attachments.importImageFromBytes(
            bytes,
            mimeType: mime,
            fileName: c.displayName,
            noteId: id,
            preferredAltText: title,
            skipOcr: true,
            preparedId: stageId,
            cachePlaintext: false,
          );
          content = result.markdownSnippet;
        } else if (const {'md', 'markdown', 'txt'}.contains(format)) {
          content = await _text(bytes);
          if (content.contains('\u0000')) {
            throw const EmailImportException(
              'invalid_text',
              'Binary text is unsupported.',
            );
          }
          if (format != 'txt') {
            final parsed = await _frontmatter(content);
            title = parsed.title ?? title;
            final now = DateTime.now();
            final item = MarkdownImportItem(
              id: id,
              filePath: '',
              relativePath: c.displayName,
              title: title,
              content: content,
              tags: {
                ...parsed.tags,
                ...TagParser.extractTags(content),
              }.toList(),
              createdAt: parsed.createdAt ?? now,
              updatedAt: parsed.updatedAt ?? now,
              fileSizeBytes: bytes.length,
            );
            // No filesystem scanner runs on the UI isolate. Local image references
            // remain verbatim; arbitrary sibling paths are never opened by Dart.
            await MarkdownImportService(notes).importNotes([item]);
            check();
            await store.commitReceipt(job, c);
            check();
            return (await notes.getNoteById(id))!;
          }
        } else {
          throw const EmailImportException(
            'unsupported',
            'This file type is unsupported.',
          );
        }
        check();
        final now = DateTime.now();
        final note = Note(
          id: id,
          title: title,
          content: content,
          tags: const [],
          createdAt: now,
          updatedAt: now,
        );
        await notes.saveNote(note);
        check();
        await store.commitReceipt(job, c);
        check();
        return note;
      });
    } catch (_) {
      // The journal survives rollback. Recovery also handles process death during
      // ciphertext creation, including before the asset metadata row exists.
      if (stageId != null) {
        try {
          if (format == 'pdf') {
            await documents.purgeLocalDocument(stageId);
          } else {
            await attachments.purgeLocalAttachment(stageId);
          }
          await store.write(
            'DELETE FROM watched_import_stages WHERE asset_id=?',
            [stageId],
          );
        } catch (_) {
          /* Retain durable cleanup journal for next startup. */
        }
      }
      rethrow;
    }
  }
}

Future<int> _pdfPages(Uint8List bytes) => Isolate.run(
  () => RegExp(r'/Type\s*/Page\b').allMatches(latin1.decode(bytes)).length,
);
Future<String> _text(Uint8List bytes) => Isolate.run(() => utf8.decode(bytes));
Future<ParsedMarkdown> _frontmatter(String content) =>
    Isolate.run(() => MarkdownFrontmatterParser.parse(content));
