import '../../../core/attachments/attachment_crypto.dart';
import '../../../core/attachments/attachment_service.dart';
import '../../../core/database/app_database.dart';
import '../../../core/documents/document_service.dart';
import '../../../core/uri/quiet_paper_uri.dart';
import '../domain/export_models.dart';
import 'export_security_guard.dart';
import 'filename_generator.dart';

/// Coordinator for scanning, resolving, and transforming image and document attachments for export.
class AttachmentExportResolver {
  AttachmentExportResolver({
    required this.database,
    required this.attachmentService,
    required this.documentService,
  });

  final AppDatabase database;
  final AttachmentService attachmentService;
  final DocumentService documentService;

  static final RegExp _imageRegex = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
  static final RegExp _linkRegex = RegExp(r'(?<!!)\[([^\]]+)\]\(([^)]+)\)');

  /// Resolves all attachments and documents referenced by the note or attached in database.
  Future<({
    String transformedMarkdown,
    List<ExportAttachmentItem> attachments,
    List<ExportDocumentItem> documents,
    List<ExportWarning> warnings,
  })> resolveResourcesForNote({
    required String noteId,
    required String canonicalMarkdown,
    required AttachmentExportStrategy strategy,
  }) async {
    final warnings = <ExportWarning>[];
    final resolvedAttachments = <ExportAttachmentItem>[];
    final resolvedDocuments = <ExportDocumentItem>[];
    final usedAttachmentNames = <String>{};

    if (strategy == AttachmentExportStrategy.none) {
      return (
        transformedMarkdown: canonicalMarkdown,
        attachments: <ExportAttachmentItem>[],
        documents: <ExportDocumentItem>[],
        warnings: <ExportWarning>[],
      );
    }

    // 1. Find all referenced URIs in markdown
    final assetMatches = <({String fullMatch, String alt, String uriStr})>[];
    for (final match in _imageRegex.allMatches(canonicalMarkdown)) {
      assetMatches.add((
        fullMatch: match.group(0)!,
        alt: match.group(1) ?? '',
        uriStr: match.group(2)!.trim(),
      ));
    }

    final docMatches = <({String fullMatch, String text, String uriStr})>[];
    for (final match in _linkRegex.allMatches(canonicalMarkdown)) {
      final target = match.group(2)!.trim();
      if (target.startsWith('qp://document/') || target.startsWith('qp://asset/')) {
        docMatches.add((
          fullMatch: match.group(0)!,
          text: match.group(1) ?? '',
          uriStr: target,
        ));
      }
    }

    var transformedMarkdown = canonicalMarkdown;

    // 2. Process image/asset references
    var imageCounter = 1;
    for (final match in assetMatches) {
      final qpUri = QuietPaperUri.tryParse(match.uriStr);
      if (qpUri != null && qpUri.isAsset) {
        final assetId = qpUri.resourceId;
        try {
          final res = await attachmentService.resolveAsset(assetId);
          final entity = await database.getAttachment(assetId);

          if (res.isAvailable && res.data != null) {
            final ext = _inferExtensionFromMime(entity?.mimeType ?? 'image/png');
            final baseName = match.alt.trim().isNotEmpty
                ? match.alt.trim()
                : 'image-${imageCounter.toString().padLeft(3, "0")}';
            final sanitizedName = FilenameGenerator.generateUniqueFilename(
              title: baseName,
              format: ExportFormat.fromExtension(ext),
              existingFilenames: usedAttachmentNames,
            );
            usedAttachmentNames.add(sanitizedName.toLowerCase());

            final relPath = 'attachments/$sanitizedName';
            ExportSecurityGuard.validateRelativePathSafety(relPath);

            final sha = entity?.sha256.isNotEmpty == true
                ? entity!.sha256
                : AttachmentCrypto.computeSha256(res.data!);

            resolvedAttachments.add(ExportAttachmentItem(
              id: assetId,
              noteId: entity?.noteId ?? noteId,
              originalFilename: sanitizedName,
              mimeType: entity?.mimeType ?? 'image/png',
              relativePath: relPath,
              byteSize: res.data!.length,
              createdAt: entity?.createdAt ?? DateTime.now(),
              sha256: sha,
              width: entity?.width,
              height: entity?.height,
              bytes: res.data!,
              cloudUrl: entity?.cloudUrl,
            ));

            if (strategy == AttachmentExportStrategy.embedLocally) {
              transformedMarkdown = transformedMarkdown.replaceAll(
                match.fullMatch,
                '![${match.alt}]($relPath)',
              );
            } else if (strategy == AttachmentExportStrategy.preserveRemoteUrls &&
                entity?.cloudUrl != null &&
                entity!.cloudUrl!.isNotEmpty) {
              transformedMarkdown = transformedMarkdown.replaceAll(
                match.fullMatch,
                '![${match.alt}](${entity.cloudUrl})',
              );
            }
            imageCounter++;
          } else {
            warnings.add(ExportWarning(
              type: ExportWarningType.attachmentUnavailable,
              message: 'Attachment image could not be resolved: $assetId (${res.status.name})',
              details: res.errorMessage,
            ));
          }
        } catch (e) {
          warnings.add(ExportWarning(
            type: ExportWarningType.attachmentUnavailable,
            message: 'Error resolving attachment $assetId: $e',
          ));
        }
      }
    }

    // 3. Process document references
    var docCounter = 1;
    for (final match in docMatches) {
      final qpUri = QuietPaperUri.tryParse(match.uriStr);
      if (qpUri != null && qpUri.isDocument) {
        final docId = qpUri.resourceId;
        try {
          final res = await documentService.resolveDocument(docId);
          final entity = await database.getDocument(docId);

          if (res.isAvailable && res.data != null) {
            final ext = entity?.mimeType == 'text/html' ? 'html' : 'pdf';
            final baseName = match.text.trim().isNotEmpty
                ? match.text.trim()
                : (entity?.title.trim().isNotEmpty == true
                    ? entity!.title.trim()
                    : 'document-${docCounter.toString().padLeft(3, "0")}');

            final sanitizedName = FilenameGenerator.generateUniqueFilename(
              title: baseName,
              format: ExportFormat.fromExtension(ext),
              existingFilenames: usedAttachmentNames,
            );
            usedAttachmentNames.add(sanitizedName.toLowerCase());

            final relPath = 'attachments/$sanitizedName';
            ExportSecurityGuard.validateRelativePathSafety(relPath);

            final docBytes = res.data!.pdfBytes;
            final sha = entity?.sha256.isNotEmpty == true
                ? entity!.sha256
                : res.data!.sha256;

            resolvedDocuments.add(ExportDocumentItem(
              id: docId,
              noteId: entity?.noteId ?? noteId,
              title: entity?.title ?? baseName,
              mimeType: entity?.mimeType ?? 'application/pdf',
              relativePath: relPath,
              byteSize: docBytes.length,
              pageCount: entity?.pageCount ?? 1,
              createdAt: entity?.createdAt ?? DateTime.now(),
              sha256: sha,
              source: entity?.source ?? 'scanner',
              bytes: docBytes,
              cloudUrl: entity?.cloudUrl,
            ));

            if (strategy == AttachmentExportStrategy.embedLocally) {
              transformedMarkdown = transformedMarkdown.replaceAll(
                match.fullMatch,
                '[${match.text}]($relPath)',
              );
            } else if (strategy == AttachmentExportStrategy.preserveRemoteUrls &&
                entity?.cloudUrl != null &&
                entity!.cloudUrl!.isNotEmpty) {
              transformedMarkdown = transformedMarkdown.replaceAll(
                match.fullMatch,
                '[${match.text}](${entity.cloudUrl})',
              );
            }
            docCounter++;
          } else {
            warnings.add(ExportWarning(
              type: ExportWarningType.attachmentUnavailable,
              message: 'Document attachment could not be resolved: $docId (${res.status.name})',
              details: res.errorMessage,
            ));
          }
        } catch (e) {
          warnings.add(ExportWarning(
            type: ExportWarningType.attachmentUnavailable,
            message: 'Error resolving document $docId: $e',
          ));
        }
      }
    }

    // 4. Query any note-attached assets in database not explicitly referenced in markdown text
    try {
      final dbAttachments = await database.getAttachmentsForNote(noteId);
      for (final att in dbAttachments) {
        if (!resolvedAttachments.any((r) => r.id == att.id)) {
          final res = await attachmentService.resolveAsset(att.id);
          if (res.isAvailable && res.data != null) {
            final ext = _inferExtensionFromMime(att.mimeType);
            final sanitizedName = FilenameGenerator.generateUniqueFilename(
              title: 'attachment-${att.id.substring(0, 8)}',
              format: ExportFormat.fromExtension(ext),
              existingFilenames: usedAttachmentNames,
            );
            usedAttachmentNames.add(sanitizedName.toLowerCase());

            final relPath = 'attachments/$sanitizedName';
            ExportSecurityGuard.validateRelativePathSafety(relPath);

            resolvedAttachments.add(ExportAttachmentItem(
              id: att.id,
              noteId: noteId,
              originalFilename: sanitizedName,
              mimeType: att.mimeType,
              relativePath: relPath,
              byteSize: res.data!.length,
              createdAt: att.createdAt,
              sha256: att.sha256,
              width: att.width,
              height: att.height,
              bytes: res.data!,
              cloudUrl: att.cloudUrl,
            ));
          }
        }
      }

      final dbDocs = await database.getDocumentsForNote(noteId);
      for (final doc in dbDocs) {
        if (!resolvedDocuments.any((r) => r.id == doc.id)) {
          final res = await documentService.resolveDocument(doc.id);
          if (res.isAvailable && res.data != null) {
            final ext = doc.mimeType == 'text/html' ? 'html' : 'pdf';
            final sanitizedName = FilenameGenerator.generateUniqueFilename(
              title: doc.title.isNotEmpty ? doc.title : 'document-${doc.id.substring(0, 8)}',
              format: ExportFormat.fromExtension(ext),
              existingFilenames: usedAttachmentNames,
            );
            usedAttachmentNames.add(sanitizedName.toLowerCase());

            final relPath = 'attachments/$sanitizedName';
            ExportSecurityGuard.validateRelativePathSafety(relPath);

            resolvedDocuments.add(ExportDocumentItem(
              id: doc.id,
              noteId: noteId,
              title: doc.title,
              mimeType: doc.mimeType,
              relativePath: relPath,
              byteSize: res.data!.pdfBytes.length,
              pageCount: doc.pageCount,
              createdAt: doc.createdAt,
              sha256: doc.sha256,
              source: doc.source,
              bytes: res.data!.pdfBytes,
              cloudUrl: doc.cloudUrl,
            ));
          }
        }
      }
    } catch (_) {}

    return (
      transformedMarkdown: transformedMarkdown,
      attachments: resolvedAttachments,
      documents: resolvedDocuments,
      warnings: warnings,
    );
  }

  static String _inferExtensionFromMime(String mimeType) {
    switch (mimeType.toLowerCase().trim()) {
      case 'image/jpeg':
      case 'image/jpg':
        return 'jpg';
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'application/pdf':
        return 'pdf';
      case 'text/html':
        return 'html';
      default:
        return 'png';
    }
  }
}
