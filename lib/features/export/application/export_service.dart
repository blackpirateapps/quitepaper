import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../core/attachments/attachment_service.dart';
import '../../../core/crypto/key_manager.dart';
import '../../../core/database/app_database.dart';
import '../../../core/documents/document_service.dart';
import '../../../core/ocr/document_processing_service.dart';
import '../../notes/application/note_security_service.dart';
import '../../notes/domain/note_model.dart';
import '../domain/export_models.dart';
import 'attachment_export_resolver.dart';
import 'export_security_guard.dart';
import 'exporters/docx_exporter.dart';
import 'exporters/html_exporter.dart';
import 'exporters/markdown_exporter.dart';
import 'exporters/pdf_exporter.dart';
import 'exporters/plain_text_exporter.dart';
import 'exporters/qpnote_exporter.dart';
import 'filename_generator.dart';
import 'note_link_resolver.dart';
import 'ocr_export_resolver.dart';
import 'qpnote_validator.dart';

/// Central coordinator for note export orchestration, format generation,
/// temporary workspace management, and native save/share workflows.
class ExportService {
  ExportService({
    required this.database,
    required this.keyManager,
    required this.attachmentService,
    required this.documentService,
    this.docProcessingService,
    ExportSecurityGuard? securityGuard,
    AttachmentExportResolver? attachmentResolver,
    OcrExportResolver? ocrResolver,
    NoteLinkResolver? noteLinkResolver,
    MarkdownExporter? markdownExporter,
    PdfExporter? pdfExporter,
    HtmlExporter? htmlExporter,
    PlainTextExporter? plainTextExporter,
    DocxExporter? docxExporter,
    QpNotePackageExporter? qpNoteExporter,
    QpNoteValidator? qpNoteValidator,
    this.tempDirectoryProvider,
  })  : _securityGuard = securityGuard ?? const ExportSecurityGuard(),
        _attachmentResolver = attachmentResolver ??
            AttachmentExportResolver(
              database: database,
              attachmentService: attachmentService,
              documentService: documentService,
            ),
        _ocrResolver = ocrResolver ??
            OcrExportResolver(
              database: database,
              keyManager: keyManager,
              docProcessingService: docProcessingService,
            ),
        _noteLinkResolver = noteLinkResolver ?? NoteLinkResolver(database: database),
        _markdownExporter = markdownExporter ?? const MarkdownExporter(),
        _pdfExporter = pdfExporter ?? const PdfExporter(),
        _htmlExporter = htmlExporter ?? const HtmlExporter(),
        _plainTextExporter = plainTextExporter ?? const PlainTextExporter(),
        _docxExporter = docxExporter ?? const DocxExporter(),
        _qpNoteExporter = qpNoteExporter ?? QpNotePackageExporter(),
        _qpNoteValidator = qpNoteValidator ?? QpNoteValidator();

  final AppDatabase database;
  final KeyManager keyManager;
  final AttachmentService attachmentService;
  final DocumentService documentService;
  final DocumentProcessingService? docProcessingService;

  final ExportSecurityGuard _securityGuard;
  final Future<Directory> Function()? tempDirectoryProvider;
  final AttachmentExportResolver _attachmentResolver;
  final OcrExportResolver _ocrResolver;
  final NoteLinkResolver _noteLinkResolver;

  final MarkdownExporter _markdownExporter;
  final PdfExporter _pdfExporter;
  final HtmlExporter _htmlExporter;
  final PlainTextExporter _plainTextExporter;
  final DocxExporter _docxExporter;
  final QpNotePackageExporter _qpNoteExporter;
  final QpNoteValidator _qpNoteValidator;

  static const _uuid = Uuid();

  /// Executes an export request and writes the output to a managed export file.
  Future<ExportResult> exportNote(
    ExportRequest request, {
    void Function(ExportProgressState)? onProgress,
  }) async {
    Directory? tempWorkspace;
    final warnings = <ExportWarning>[];

    try {
      // 1. Preparing note phase
      onProgress?.call(const ExportProgressState(
        phase: ExportPhase.preparingNote,
        progress: 0.1,
      ));

      final noteWithTags = await database.getNoteWithTags(request.noteId);
      if (noteWithTags == null) {
        throw ArgumentError('Note not found: ${request.noteId}');
      }

      final note = Note(
        id: noteWithTags.note.id,
        title: noteWithTags.note.title,
        content: noteWithTags.note.content,
        createdAt: noteWithTags.note.createdAt,
        updatedAt: noteWithTags.note.updatedAt,
        isPinned: noteWithTags.note.isPinned,
        isArchived: noteWithTags.note.isArchived,
        isTrashed: noteWithTags.note.isTrashed,
        deletedAt: noteWithTags.note.deletedAt,
        tags: noteWithTags.tagNames,
      );
      final rawTags = noteWithTags.tagNames;

      // Security check & password unlock
      final unlocked = await _securityGuard.verifyAndUnlockNote(
        note: note,
        suppliedPassword: request.notePassword,
      );

      final cleanTitle = unlocked.title.isNotEmpty
          ? unlocked.title
          : Note.deriveTitle(unlocked.content);

      // Create isolated temporary workspace
      final systemTemp = await (tempDirectoryProvider?.call() ?? getTemporaryDirectory());
      final workspacePath = p.join(
        systemTemp.path,
        'quietpaper_export_${_uuid.v4()}',
      );
      tempWorkspace = Directory(workspacePath);
      await tempWorkspace.create(recursive: true);

      // 2. Resolving attachments phase
      onProgress?.call(const ExportProgressState(
        phase: ExportPhase.resolvingAttachments,
        progress: 0.3,
      ));

      final attachmentResult = await _attachmentResolver.resolveResourcesForNote(
        noteId: request.noteId,
        canonicalMarkdown: unlocked.content,
        strategy: request.attachmentStrategy,
      );
      warnings.addAll(attachmentResult.warnings);

      // 3. Resolving OCR phase
      onProgress?.call(const ExportProgressState(
        phase: ExportPhase.resolvingOcr,
        progress: 0.5,
      ));

      final ocrResult = await _ocrResolver.resolveOcrData(
        documents: attachmentResult.documents,
        attachments: attachmentResult.attachments,
        strategy: request.ocrStrategy,
      );
      warnings.addAll(ocrResult.warnings);

      // 4. Transforming note links
      final transformedMarkdown = await _noteLinkResolver.transformNoteLinks(
        attachmentResult.transformedMarkdown,
        strategy: request.noteLinkStrategy,
        targetFormat: request.format,
      );

      // Build immutable snapshot
      final snapshot = NoteExportSnapshot(
        noteId: note.id,
        title: cleanTitle,
        markdown: transformedMarkdown,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        isPinned: note.isPinned,
        isArchived: note.isArchived,
        isTrashed: note.isTrashed,
        deletedAt: note.deletedAt,
        tags: unlocked.tags.isNotEmpty ? unlocked.tags : rawTags,
        isPasswordProtected: note.isPasswordProtected,
        passwordHint: NoteSecurityService.getHint(note.content),
        attachments: attachmentResult.attachments,
        documents: attachmentResult.documents,
        ocrData: ocrResult.ocrItems,
      );

      // 5. Rendering document phase
      onProgress?.call(const ExportProgressState(
        phase: ExportPhase.renderingDocument,
        progress: 0.7,
      ));

      final outputFilename = FilenameGenerator.generateFilename(
        title: snapshot.effectiveTitle,
        format: request.format,
      );

      final outputFile = File(p.join(tempWorkspace.path, outputFilename));

      ExportResult result;
      switch (request.format) {
        case ExportFormat.markdown:
          result = await _markdownExporter.exportMarkdown(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
        case ExportFormat.pdf:
          result = await _pdfExporter.exportPdf(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
        case ExportFormat.html:
          result = await _htmlExporter.exportHtml(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
        case ExportFormat.plainText:
          result = await _plainTextExporter.exportPlainText(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
        case ExportFormat.docx:
          result = await _docxExporter.exportDocx(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
        case ExportFormat.qpnote:
          onProgress?.call(const ExportProgressState(
            phase: ExportPhase.compressingPackage,
            progress: 0.8,
          ));
          result = await _qpNoteExporter.exportQpNote(
            snapshot: snapshot,
            request: request,
            outputFile: outputFile,
          );
          break;
      }

      // Combine warnings
      final allWarnings = [...warnings, ...result.warnings];
      result = result.copyWith(warnings: allWarnings);

      // 6. Optional Native Share
      if (request.shareAfterExport) {
        onProgress?.call(const ExportProgressState(
          phase: ExportPhase.sharing,
          progress: 0.9,
        ));
        await shareExportResult(result);
        result = result.copyWith(isShared: true);
      }

      onProgress?.call(const ExportProgressState(
        phase: ExportPhase.complete,
        progress: 1.0,
      ));

      return result;
    } catch (e) {
      onProgress?.call(ExportProgressState(
        phase: ExportPhase.failed,
        message: e.toString(),
      ));
      rethrow;
    }
  }

  /// Exports the note and prompts user with native file saver dialog.
  Future<ExportResult?> exportAndSave(
    ExportRequest request, {
    void Function(ExportProgressState)? onProgress,
  }) async {
    final result = await exportNote(request, onProgress: onProgress);

    onProgress?.call(const ExportProgressState(
      phase: ExportPhase.saving,
      progress: 0.95,
    ));

    final bytes = await result.file.readAsBytes();

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save ${result.format.displayName}',
      fileName: result.filename,
      type: FileType.custom,
      allowedExtensions: [result.format.extension],
      bytes: bytes,
    );

    if (savedPath == null) {
      // User cancelled
      return null;
    }

    // On desktop / platforms where saveFile returns path without auto-writing bytes
    if (savedPath.isNotEmpty) {
      final f = File(savedPath);
      if (!await f.exists() || (await f.length()) == 0) {
        try {
          await f.writeAsBytes(bytes, flush: true);
        } catch (_) {}
      }
    }

    return result.copyWith(isSaved: true);
  }

  /// Shares an exported file via native system share sheet.
  Future<void> shareExportResult(ExportResult result) async {
    final xFile = XFile(
      result.file.path,
      name: result.filename,
      mimeType: result.mimeType,
    );

    await Share.shareXFiles(
      [xFile],
      subject: result.filename,
    );
  }

  /// Validates a `.qpnote` package file or bytes.
  Future<QpNoteValidationResult> validateQpNote(
    File file, {
    String? packagePassword,
  }) {
    return _qpNoteValidator.validatePackageFile(
      file,
      packagePassword: packagePassword,
    );
  }
}
