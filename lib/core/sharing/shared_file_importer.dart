import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/editor/presentation/editor_screen.dart';
import '../../features/import/application/markdown_frontmatter_parser.dart';
import '../../features/notes/application/notes_provider.dart';
import '../../features/notes/application/notes_query_provider.dart';
import '../../features/notes/domain/note_model.dart';
import '../attachments/attachment_provider.dart';
import '../documents/document_provider.dart';
import '../documents/presentation/document_viewer_screen.dart';

/// How a plain-text file should be brought into Quiet Paper.
enum _TextImportChoice { note, attachment }

/// Classification of a file handed to the app through an Android intent.
enum _IncomingKind { pdf, markdown, text, unsupported }

/// Imports files handed to Quiet Paper through Android "Open with"
/// (`ACTION_VIEW`) or share (`ACTION_SEND`) intents, always creating a brand
/// new note and then opening the most relevant screen automatically.
///
///  * **PDF** – stored as an encrypted document embedded in a new note; the
///    PDF document viewer opens automatically.
///  * **.md / .markdown** – imported as the note body (never an attachment);
///    opens in Markdown preview.
///  * **.txt (and other text/*)** – prompts whether to import the content as
///    the note body or to keep the file as an attachment only.
class SharedFileImporter {
  const SharedFileImporter._();

  static const _uuid = Uuid();

  /// Classifies [path] / [mimeType] and performs the matching import.
  ///
  /// Fire-and-forget: any failure surfaces to the user as a SnackBar and is
  /// never rethrown, so a malformed share can never crash the host activity.
  static Future<void> importFile({
    required String path,
    String? mimeType,
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final file = File(path);
    if (!file.existsSync()) return;

    final kind = _classify(path, mimeType);
    if (kind == _IncomingKind.unsupported) return;

    final container = ProviderScope.containerOf(context, listen: false);

    try {
      switch (kind) {
        case _IncomingKind.pdf:
          await _importPdf(navigatorKey, container, file);
          break;
        case _IncomingKind.markdown:
          await _importMarkdownNote(navigatorKey, container, file);
          break;
        case _IncomingKind.text:
          await _importTextWithPrompt(navigatorKey, container, file);
          break;
        case _IncomingKind.unsupported:
          break;
      }
    } catch (e) {
      _showSnack(navigatorKey, 'Could not import file: $e');
    }
  }

  static _IncomingKind _classify(String path, String? mimeType) {
    final ext = p.extension(path).toLowerCase();
    final mime = (mimeType ?? '').toLowerCase();
    if (ext == '.pdf' || mime == 'application/pdf') {
      return _IncomingKind.pdf;
    }
    if (ext == '.md' ||
        ext == '.markdown' ||
        mime == 'text/markdown' ||
        mime == 'text/x-markdown') {
      return _IncomingKind.markdown;
    }
    if (ext == '.txt' || ext == '.text' || mime.startsWith('text/')) {
      return _IncomingKind.text;
    }
    return _IncomingKind.unsupported;
  }

  // --- PDF -------------------------------------------------------------------

  static Future<void> _importPdf(
    GlobalKey<NavigatorState> navigatorKey,
    ProviderContainer container,
    File file,
  ) async {
    final docService = container.read(documentServiceProvider);
    final rawTitle = p.basenameWithoutExtension(file.path).trim();
    final title = rawTitle.isNotEmpty ? rawTitle : 'Imported PDF';
    final noteId = _uuid.v4();
    final now = DateTime.now();

    final res = await docService.importPdfFile(
      file: file,
      noteId: noteId,
      title: title,
    );

    await _persist(
      container,
      Note(
        id: noteId,
        title: title,
        content: '${res.markdownSnippet}\n',
        createdAt: now,
        updatedAt: now,
      ),
    );

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          documentId: res.document.id,
          title: title,
        ),
      ),
    );
  }

  // --- Markdown --------------------------------------------------------------

  static Future<void> _importMarkdownNote(
    GlobalKey<NavigatorState> navigatorKey,
    ProviderContainer container,
    File file,
  ) async {
    final content = await file.readAsString();
    final filename = p.basenameWithoutExtension(file.path);
    final parsed = MarkdownFrontmatterParser.parse(content);
    final title = (parsed.title != null && parsed.title!.isNotEmpty)
        ? parsed.title!
        : filename;
    final now = DateTime.now();

    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: parsed.tags,
      createdAt: parsed.createdAt ?? now,
      updatedAt: parsed.updatedAt ?? now,
    );
    await _persist(container, note);
    _openEditor(navigatorKey, note, previewMode: true);
  }

  // --- Plain text ------------------------------------------------------------

  static Future<void> _importTextWithPrompt(
    GlobalKey<NavigatorState> navigatorKey,
    ProviderContainer container,
    File file,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final choice = await showDialog<_TextImportChoice>(
      context: context,
      builder: (_) => _TextImportChoiceDialog(fileName: p.basename(file.path)),
    );
    if (choice == null) return; // Dismissed without choosing.

    if (choice == _TextImportChoice.note) {
      await _importTextAsNote(navigatorKey, container, file);
    } else {
      await _importTextAsAttachment(navigatorKey, container, file);
    }
  }

  static Future<void> _importTextAsNote(
    GlobalKey<NavigatorState> navigatorKey,
    ProviderContainer container,
    File file,
  ) async {
    final content = await file.readAsString();
    final title = p.basenameWithoutExtension(file.path);
    final now = DateTime.now();
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _persist(container, note);
    _openEditor(navigatorKey, note, previewMode: false);
  }

  static Future<void> _importTextAsAttachment(
    GlobalKey<NavigatorState> navigatorKey,
    ProviderContainer container,
    File file,
  ) async {
    final attachmentService = container.read(attachmentServiceProvider);
    final filename = p.basenameWithoutExtension(file.path);
    final noteId = _uuid.v4();
    final now = DateTime.now();

    final res = await attachmentService.importGenericFileFromFile(
      file,
      noteId: noteId,
      preferredFileName: p.basename(file.path),
    );

    final note = Note(
      id: noteId,
      title: filename,
      content: '${res.markdownSnippet}\n',
      createdAt: now,
      updatedAt: now,
    );
    await _persist(container, note);
    _openEditor(navigatorKey, note, previewMode: false);
  }

  // --- Shared helpers --------------------------------------------------------

  static Future<void> _persist(ProviderContainer container, Note note) async {
    await container.read(notesRepositoryProvider).saveNote(note);
    container.read(notesCollectionProvider.notifier).refresh();
  }

  static void _openEditor(
    GlobalKey<NavigatorState> navigatorKey,
    Note note, {
    required bool previewMode,
  }) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(note: note, initialPreviewMode: previewMode),
      ),
    );
  }

  static void _showSnack(
    GlobalKey<NavigatorState> navigatorKey,
    String message,
  ) {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 4)),
      );
  }
}

/// Modal asking whether a shared plain-text file becomes the note body or is
/// kept only as an attachment.
class _TextImportChoiceDialog extends StatelessWidget {
  const _TextImportChoiceDialog({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import text file'),
      content: Text('How would you like to import "$fileName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(_TextImportChoice.attachment),
          child: const Text('As attachment'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_TextImportChoice.note),
          child: const Text('As note'),
        ),
      ],
    );
  }
}

