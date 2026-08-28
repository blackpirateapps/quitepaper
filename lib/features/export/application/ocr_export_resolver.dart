import 'dart:convert';
import '../../../core/database/app_database.dart';
import '../../../core/ocr/document_processing_service.dart';
import '../../../core/ocr/ocr_crypto.dart';
import '../../../core/ocr/ocr_models.dart';
import '../../../core/crypto/key_manager.dart';
import '../domain/export_models.dart';

/// Coordinator for extracting, decrypting, and structuring OCR data for export.
class OcrExportResolver {
  OcrExportResolver({
    required this.database,
    required this.keyManager,
    this.docProcessingService,
    OcrCrypto? ocrCrypto,
  }) : _ocrCrypto = ocrCrypto ?? OcrCrypto();

  final AppDatabase database;
  final KeyManager keyManager;
  final DocumentProcessingService? docProcessingService;
  final OcrCrypto _ocrCrypto;

  /// Resolves all OCR datasets associated with the note's documents and attachments.
  Future<({List<ExportOcrItem> ocrItems, List<ExportWarning> warnings})> resolveOcrData({
    required List<ExportDocumentItem> documents,
    required List<ExportAttachmentItem> attachments,
    required OcrExportStrategy strategy,
  }) async {
    final ocrItems = <ExportOcrItem>[];
    final warnings = <ExportWarning>[];

    if (strategy == OcrExportStrategy.none) {
      return (ocrItems: <ExportOcrItem>[], warnings: <ExportWarning>[]);
    }

    if (!keyManager.isUnlocked) {
      warnings.add(const ExportWarning(
        type: ExportWarningType.ocrUnavailable,
        message: 'Notebook encryption is locked; cannot decrypt OCR data for export.',
      ));
      return (ocrItems: <ExportOcrItem>[], warnings: warnings);
    }

    final masterKey = keyManager.getMasterKey();

    // 1. Resolve OCR for documents
    for (final doc in documents) {
      try {
        final rows = await database.getDocumentOcrPages(doc.id);
        if (rows.isNotEmpty) {
          final pages = <OcrPage>[];
          String engine = 'quietpaper_ocr_v1';
          String engineVersion = '1.0.0';
          int schemaVersion = 1;
          OcrLanguage language = OcrLanguage.english;
          DateTime processedAt = DateTime.now();

          for (final row in rows) {
            try {
              final encryptedBytes = base64Decode(row.encryptedPayload);
              final decryptedDoc = await _ocrCrypto.decryptOcrDocument(
                encryptedEnvelopeBytes: encryptedBytes,
                masterKeyBytes: masterKey,
                documentId: doc.id,
                shallow: false,
              );
              engine = decryptedDoc.engine;
              engineVersion = decryptedDoc.engineVersion;
              schemaVersion = decryptedDoc.schemaVersion;
              language = decryptedDoc.language;
              processedAt = decryptedDoc.processedAt;
              pages.addAll(decryptedDoc.pages);
            } catch (pageErr) {
              warnings.add(ExportWarning(
                type: ExportWarningType.ocrUnavailable,
                message: 'Failed to decrypt OCR page ${row.pageNumber} for document ${doc.title}: $pageErr',
              ));
            }
          }

          if (pages.isNotEmpty) {
            pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
            final ocrDoc = OcrDocument(
              documentId: doc.id,
              language: language,
              engine: engine,
              engineVersion: engineVersion,
              schemaVersion: schemaVersion,
              processedAt: processedAt,
              sourceDocumentSha256: doc.sha256,
              pages: pages,
            );

            ocrItems.add(ExportOcrItem(
              resourceId: doc.id,
              resourceType: 'document',
              document: ocrDoc,
              relativePath: 'ocr/doc_${doc.id}',
            ));
          }
        }
      } catch (e) {
        warnings.add(ExportWarning(
          type: ExportWarningType.ocrUnavailable,
          message: 'Error resolving OCR for document ${doc.title}: $e',
        ));
      }
    }

    // 2. Resolve OCR for image attachments
    for (final att in attachments) {
      try {
        final rows = await database.getAttachmentOcrPages(att.id);
        if (rows.isNotEmpty) {
          final pages = <OcrPage>[];
          String engine = 'quietpaper_image_ocr';
          String engineVersion = '1.0.0';
          int schemaVersion = 1;
          OcrLanguage language = OcrLanguage.english;
          DateTime processedAt = DateTime.now();

          for (final row in rows) {
            try {
              final encryptedBytes = base64Decode(row.encryptedPayload);
              final decryptedDoc = await _ocrCrypto.decryptOcrDocument(
                encryptedEnvelopeBytes: encryptedBytes,
                masterKeyBytes: masterKey,
                documentId: att.id,
                shallow: false,
              );
              engine = decryptedDoc.engine;
              engineVersion = decryptedDoc.engineVersion;
              schemaVersion = decryptedDoc.schemaVersion;
              language = decryptedDoc.language;
              processedAt = decryptedDoc.processedAt;
              pages.addAll(decryptedDoc.pages);
            } catch (pageErr) {
              warnings.add(ExportWarning(
                type: ExportWarningType.ocrUnavailable,
                message: 'Failed to decrypt OCR for attachment ${att.originalFilename}: $pageErr',
              ));
            }
          }

          if (pages.isNotEmpty) {
            final ocrDoc = OcrDocument(
              documentId: att.id,
              language: language,
              engine: engine,
              engineVersion: engineVersion,
              schemaVersion: schemaVersion,
              processedAt: processedAt,
              sourceDocumentSha256: att.sha256,
              pages: pages,
            );

            ocrItems.add(ExportOcrItem(
              resourceId: att.id,
              resourceType: 'asset',
              document: ocrDoc,
              relativePath: 'ocr/asset_${att.id}',
            ));
          }
        }
      } catch (e) {
        warnings.add(ExportWarning(
          type: ExportWarningType.ocrUnavailable,
          message: 'Error resolving OCR for attachment ${att.originalFilename}: $e',
        ));
      }
    }

    return (ocrItems: ocrItems, warnings: warnings);
  }

  /// Formats all OCR documents into a structured markdown/text appendix if [strategy] is appendToDocument.
  static String formatOcrAppendix(List<ExportOcrItem> ocrItems) {
    if (ocrItems.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.writeln('\n\n---\n\n## Document OCR Transcripts\n');

    for (final item in ocrItems) {
      buffer.writeln('### ${item.resourceType == "document" ? "Document" : "Image"} OCR (${item.document.language.displayName})\n');
      for (final page in item.document.pages) {
        if (item.document.pages.length > 1) {
          buffer.writeln('#### Page ${page.pageNumber}\n');
        }
        buffer.writeln('```text');
        buffer.writeln(page.plainText.trim());
        buffer.writeln('```\n');
      }
    }

    return buffer.toString();
  }
}
