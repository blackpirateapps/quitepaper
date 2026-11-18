import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../core/attachments/attachment_service.dart';
import '../../../core/database/app_database.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../../editor/application/rich_document_parser.dart';
import '../../editor/domain/rich_document.dart';
import '../domain/email_message.dart';
import '../domain/note_import_source.dart';
import 'email_html_converter.dart';

class EmailImportService {
  EmailImportService({
    required this.database,
    required this.repository,
    required this.attachments,
  });
  final AppDatabase database;
  final NotesRepository repository;
  final AttachmentService attachments;
  static const _uuid = Uuid();
  bool _saving = false;

  /// Run once before accepting requests, never concurrently with a live import.
  /// A committed transaction removes its journal rows atomically with the note.
  Future<void> recoverInterruptedImports() async {
    if (_saving) return;
    final rows = await database
        .customSelect('SELECT asset_id FROM email_import_preparations')
        .get();
    for (final row in rows) {
      final id = row.read<String>('asset_id');
      await attachments.purgeLocalAttachment(id);
      await database.customStatement(
        'DELETE FROM email_import_preparations WHERE asset_id=?',
        [id],
      );
    }
  }

  Future<Note> save({
    required EmailMessage email,
    required EmailImportMode mode,
    required String title,
    List<String> tags = const ['email'],
    Note? destination,
    bool allowDuplicate = false,
    bool Function()? isCancelled,
  }) async {
    if (_saving) {
      throw const EmailImportException(
        'busy',
        'An email is already being saved.',
      );
    }
    if (!attachments.keyManager.isUnlocked) {
      throw const EmailImportException(
        'locked',
        'Unlock your notebook to import email.',
      );
    }
    if (mode == EmailImportMode.archive && email.rawBytes == null) {
      throw const EmailImportException(
        'no_original',
        'Shared content has no original email to archive.',
      );
    }
    if (mode == EmailImportMode.append && destination == null) {
      throw const EmailImportException(
        'destination',
        'Choose a destination note.',
      );
    }
    _saving = true;
    final ids = <String>[];
    var committed = false;
    try {
      final duplicates = await database.findEmailDuplicates(
        rawHash: email.rawHash,
        fingerprint: email.fingerprint,
        messageId: email.messageId,
      );
      if (!allowDuplicate && duplicates.any((d) => d.exact)) {
        throw const EmailImportException(
          'duplicate',
          'This email is already saved. Review the duplicate warning to import another copy.',
        );
      }
      final noteId = mode == EmailImportMode.append
          ? destination!.id
          : _uuid.v4();
      final originalId = email.rawBytes == null ? null : _uuid.v4();
      if (originalId != null) ids.add(originalId);
      // Stable representation + decoded hash reuses duplicate MIME leaves.
      final assetByKey = <String, String>{};
      String key(EmailAttachment a) =>
          '${a.isInlineImage}:${a.mimeType}:${sha256.convert(a.bytes)}';
      if (mode != EmailImportMode.archive) {
        for (final asset in email.attachments) {
          assetByKey.putIfAbsent(key(asset), () {
            final id = _uuid.v4();
            ids.add(id);
            return id;
          });
        }
      }
      // Durable journal is committed before touching ciphertext files.
      await database.transaction(() async {
        for (final id in ids) {
          await database.customStatement(
            'INSERT INTO email_import_preparations(asset_id) VALUES (?)',
            [id],
          );
        }
      });
      void checkCancelled() {
        if (isCancelled?.call() == true) {
          throw const EmailImportException(
            'cancelled',
            'Email import canceled.',
          );
        }
        if (!attachments.keyManager.isUnlocked) {
          throw const EmailImportException(
            'locked',
            'Unlock your notebook to continue.',
          );
        }
      }

      final saved = await database.transaction(() async {
        checkCancelled();
        if (originalId != null) {
          await attachments.importEmailAsset(
            email.rawBytes!,
            assetId: originalId,
            fileName: 'original-email.eml',
            mimeType: 'message/rfc822',
            noteId: noteId,
            original: true,
          );
        }
        final snippets = <String>[];
        final cidAssets = <String, String>{};
        final prepared = <String>{};
        if (mode != EmailImportMode.archive) {
          for (final asset in email.attachments) {
            checkCancelled();
            final id = assetByKey[key(asset)]!;
            if (prepared.add(id)) {
              final result = await attachments.importEmailAsset(
                asset.bytes,
                assetId: id,
                fileName: asset.fileName,
                mimeType: asset.mimeType,
                noteId: noteId,
                inlineImage: asset.isInlineImage,
              );
              snippets.add('- ${result.markdownSnippet}');
            }
            if (asset.contentId != null) {
              cidAssets.putIfAbsent(asset.contentId!, () => id);
            }
          }
        }
        var body = (mode == EmailImportMode.archive ? '' : email.markdown)
            .replaceAllMapped(RegExp(r'email-cid:([^\s)]+)'), (match) {
              final cid = Uri.decodeComponent(match[1]!);
              final id = cidAssets[cid];
              if (id == null) {
                throw const EmailImportException(
                  'cid',
                  'An inline email image could not be prepared.',
                );
              }
              return 'qp://asset/$id';
            });
        if (mode == EmailImportMode.archive) body = '';
        final metadata = <String>[
          '## Email Details',
          if (email.isSharedContent)
            'Shared content — original email unavailable.',
          'From: ${EmailHtmlConverter.escape(email.sender)}',
          if (email.to.isNotEmpty) 'To: ${EmailHtmlConverter.escape(email.to)}',
          if (email.cc.isNotEmpty) 'Cc: ${EmailHtmlConverter.escape(email.cc)}',
          if (email.bcc.isNotEmpty)
            'Bcc: ${EmailHtmlConverter.escape(email.bcc)}',
          if (email.replyTo.isNotEmpty)
            'Reply-To: ${EmailHtmlConverter.escape(email.replyTo)}',
          'Date: ${email.sentAt == null ? 'Date unavailable' : EmailHtmlConverter.escape(email.originalDate)}',
        ];
        final section =
            '${metadata.join('\n\n')}\n\n---\n\n${body.isEmpty ? (mode == EmailImportMode.archive ? '' : 'No readable email body was provided.') : body}${snippets.isEmpty ? '' : '\n\n### Attachments\n\n${snippets.join('\n')}'}${originalId == null ? '' : '\n\n[Original email (.eml)](qp://asset/$originalId)'}';
        checkCancelled();
        // Re-read within the same transaction after asynchronous preparation.
        // Reject any content or revision drift rather than overwrite it.
        final current = mode == EmailImportMode.append
            ? await repository.getNoteById(noteId)
            : null;
        if (mode == EmailImportMode.append &&
            (current == null ||
                current.isTrashed ||
                current.isPasswordProtected)) {
          throw const EmailImportException(
            'destination_missing',
            'The destination is unavailable. Choose another note.',
          );
        }
        if (current != null &&
            (current.content != destination!.content ||
                current.title != destination.title ||
                current.updatedAt.millisecondsSinceEpoch ~/ 1000 !=
                    destination.updatedAt.millisecondsSinceEpoch ~/ 1000)) {
          throw const EmailImportException(
            'destination_changed',
            'The destination changed during preview. Select it again to retry.',
          );
        }
        final now = DateTime.now().toUtc();
        final provenance = NoteImportSource(
          fingerprint: email.fingerprint,
          importedAt: now,
          subject: email.subject,
          sender: email.sender,
          inputType: email.isSharedContent ? 'shared_text' : 'eml',
          rawHash: email.rawHash,
          messageId: email.messageId,
          originalDate: email.originalDate.isEmpty ? null : email.originalDate,
          sourceAssetId: originalId,
          attachmentAssetIds: assetByKey.values.toList(),
          inReplyTo: email.inReplyTo,
          references: email.references,
        );
        String content = section;
        if (current != null) {
          final addition =
              '\n\n---\n\n# ${EmailHtmlConverter.escape(title)}\n\n$section';
          if (current.isRichText) {
            final doc = RichDocument.fromJson(
              jsonDecode(current.content) as Map<String, dynamic>,
            );
            content = jsonEncode(
              doc
                  .copyWith(
                    blocks: [
                      ...doc.blocks,
                      ...const RichDocumentParser().parse(addition).blocks,
                    ],
                  )
                  .toJson(),
            );
          } else {
            content = '${current.content}$addition';
          }
        }
        final note =
            current?.copyWith(
              content: content,
              tags: {...current.tags, ...tags}.toList(),
              updatedAt: now,
              importSources: [...current.importSources, provenance],
            ) ??
            Note(
              id: noteId,
              title: title.trim().isEmpty ? 'Untitled Email' : title.trim(),
              content: content,
              tags: tags,
              createdAt: now,
              updatedAt: now,
              importSources: [provenance],
            );
        await repository.saveNote(note, preserveEmptyTags: true);
        for (final id in ids) {
          await database.customStatement(
            'DELETE FROM email_import_preparations WHERE asset_id=?',
            [id],
          );
        }
        return note;
      });
      committed = true;
      return saved;
    } on EmailImportException {
      rethrow;
    } catch (_) {
      throw const EmailImportException(
        'save_failed',
        'Could not save email. Check available storage and unlock your notebook, then retry.',
      );
    } finally {
      if (!committed) {
        for (final id in ids) {
          try {
            await attachments.purgeLocalAttachment(id);
            await database.customStatement(
              'DELETE FROM email_import_preparations WHERE asset_id=?',
              [id],
            );
          } catch (_) {
            /* Durable journal retries cleanup on next session. */
          }
        }
      }
      _saving = false;
    }
  }
}
