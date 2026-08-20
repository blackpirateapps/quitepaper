import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../documents/document_crypto.dart';
import '../documents/document_models.dart';
import '../pdf/pdf_page_renderer.dart';
import '../pdf/pdf_text_extractor.dart';
import 'ocr_crypto.dart';
import 'ocr_models.dart';
import 'ocr_service.dart';

/// Asynchronous coordinator for document text extraction, on-device OCR,
/// client-side encryption of OCR data, and recovery across app restarts.
class DocumentProcessingService {
  DocumentProcessingService({
    required this.database,
    required this.keyManager,
    OcrCrypto? ocrCrypto,
    PdfTextExtractor? textExtractor,
    PdfPageRenderer? pageRenderer,
    OcrService? ocrService,
  })  : _ocrCrypto = ocrCrypto ?? OcrCrypto(),
        _textExtractor = textExtractor ?? const DefaultPdfTextExtractor(),
        _pageRenderer = pageRenderer ?? const DefaultPdfPageRenderer(),
        _ocrService = ocrService ?? const DefaultOcrService();

  final AppDatabase database;
  final KeyManager keyManager;
  final OcrCrypto _ocrCrypto;
  final PdfTextExtractor _textExtractor;
  final PdfPageRenderer _pageRenderer;
  final OcrService _ocrService;

  final Set<String> _inFlightJobIds = <String>{};

  /// Asynchronously processes a document (text extraction or ML OCR) in the background.
  Future<void> processDocument({
    required String documentId,
    required Uint8List pdfBytes,
    DocumentSource source = DocumentSource.scanner,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    if (_inFlightJobIds.contains(documentId)) {
      debugPrint('[QuietPaper OCR] Document $documentId is already being processed. Skipping duplicate.');
      return;
    }

    _inFlightJobIds.add(documentId);
    debugPrint('[QuietPaper OCR] Started OCR processing for doc $documentId (size: ${pdfBytes.length} bytes, source: $source, lang: ${language.code})');

    try {
      await database.updateDocumentOcrState(
        documentId,
        OcrProcessingState.processing.identifier,
        ocrLanguage: language.code,
      );

      final pdfSha256 = DocumentCrypto.computeSha256(pdfBytes);
      OcrDocument? ocrResult;

      // 1. If imported PDF, inspect for existing usable text layer first
      if (source == DocumentSource.importedPdf) {
        try {
          debugPrint('[QuietPaper OCR] Checking for embedded PDF text layer...');
          final extraction = await _textExtractor.extractText(pdfBytes);
          if (extraction.hasUsableText && extraction.pages.isNotEmpty) {
            debugPrint('[QuietPaper OCR] Found embedded text layer with ${extraction.pages.length} pages.');
            ocrResult = OcrDocument(
              documentId: documentId,
              language: language,
              engine: 'quietpaper_pdf_extractor',
              engineVersion: '1.0.0',
              schemaVersion: 1,
              processedAt: DateTime.now(),
              sourceDocumentSha256: pdfSha256,
              pages: extraction.pages,
            );
          }
        } catch (extractErr) {
          debugPrint('[QuietPaper OCR] Text extraction fallback to OCR: $extractErr');
        }
      }

      // 2. If no text layer found or scanned document, run on-device OCR
      if (ocrResult == null) {
        debugPrint('[QuietPaper OCR] Rasterizing PDF pages at 150 DPI for OCR...');
        final renderedPages = await _pageRenderer.renderPages(pdfBytes, dpi: 150.0);
        debugPrint('[QuietPaper OCR] Rasterized ${renderedPages.length} pages. Starting text recognition...');
        final ocrPages = <OcrPage>[];

        for (final rendered in renderedPages) {
          final ocrPage = await _ocrService.recognizePage(
            rendered.imageBytes,
            pageNumber: rendered.pageNumber,
            language: language,
          );
          ocrPages.add(ocrPage);
          debugPrint('[QuietPaper OCR] Page ${rendered.pageNumber} recognized (${ocrPage.blocks.length} blocks, ${ocrPage.plainText.length} chars).');
        }

        ocrResult = OcrDocument(
          documentId: documentId,
          language: language,
          engine: 'quietpaper_ml_ocr',
          engineVersion: '1.0.0',
          schemaVersion: 1,
          processedAt: DateTime.now(),
          sourceDocumentSha256: pdfSha256,
          pages: ocrPages,
        );
      }

      // 3. Encrypt structured OCR pages client-side using Master Key and atomically save
      if (keyManager.isUnlocked) {
        debugPrint('[QuietPaper OCR] Encrypting OCR datasets with Master Key...');
        final masterKey = keyManager.getMasterKey();
        final now = DateTime.now();

        final pagePayloads = <({int pageNumber, String payloadBase64})>[];

        for (final page in ocrResult.pages) {
          final pageDoc = OcrDocument(
            documentId: documentId,
            language: language,
            engine: ocrResult.engine,
            engineVersion: ocrResult.engineVersion,
            schemaVersion: ocrResult.schemaVersion,
            processedAt: now,
            sourceDocumentSha256: pdfSha256,
            pages: [page],
          );

          final encryptedBytes = await _ocrCrypto.encryptOcrDocument(
            ocrDocument: pageDoc,
            masterKeyBytes: masterKey,
          );

          final payloadBase64 = base64Encode(encryptedBytes);
          pagePayloads.add((pageNumber: page.pageNumber, payloadBase64: payloadBase64));
        }

        // Atomically replace: delete existing records only once all new pages are encrypted
        await database.deleteDocumentOcrPages(documentId);

        for (final item in pagePayloads) {
          await database.saveDocumentOcrPage(
            documentId: documentId,
            pageNumber: item.pageNumber,
            encryptedPayload: item.payloadBase64,
            ocrSchemaVersion: ocrResult.schemaVersion,
            ocrEngine: ocrResult.engine,
            ocrEngineVersion: ocrResult.engineVersion,
            language: language.code,
            processedAt: now,
          );
        }
      }

      await database.updateDocumentOcrState(
        documentId,
        OcrProcessingState.available.identifier,
        ocrLanguage: language.code,
      );
      debugPrint('[QuietPaper OCR] Successfully finished processing for $documentId (state: available)');
    } catch (e, st) {
      debugPrint('[QuietPaper OCR] Processing error for document $documentId: $e\n$st');
      await database.updateDocumentOcrState(
        documentId,
        OcrProcessingState.failed.identifier,
        ocrLanguage: language.code,
      );
    } finally {
      _inFlightJobIds.remove(documentId);
    }
  }

  /// Retries OCR processing for a document with given [pdfBytes] and [language].
  Future<void> retryOcr({
    required String documentId,
    required Uint8List pdfBytes,
    DocumentSource source = DocumentSource.scanner,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    _inFlightJobIds.remove(documentId);
    await processDocument(
      documentId: documentId,
      pdfBytes: pdfBytes,
      source: source,
      language: language,
    );
  }

  /// Regenerates OCR for a document with given [pdfBytes] and [language].
  Future<void> regenerateOcr({
    required String documentId,
    required Uint8List pdfBytes,
    DocumentSource source = DocumentSource.scanner,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    _inFlightJobIds.remove(documentId);
    await processDocument(
      documentId: documentId,
      pdfBytes: pdfBytes,
      source: source,
      language: language,
    );
  }

  /// Decrypts and returns the full structured [OcrDocument] for [documentId].
  Future<OcrDocument?> getDecryptedOcrDocument(String documentId) async {
    if (!keyManager.isUnlocked) return null;

    final rows = await database.getDocumentOcrPages(documentId);
    if (rows.isEmpty) return null;

    final masterKey = keyManager.getMasterKey();
    final pages = <OcrPage>[];
    String engine = 'quietpaper_ocr_v1';
    String engineVersion = '1.0.0';
    int schemaVersion = 1;
    OcrLanguage language = OcrLanguage.english;
    DateTime processedAt = DateTime.now();
    String? sourceSha;

    for (final row in rows) {
      try {
        final encryptedBytes = base64Decode(row.encryptedPayload);
        final decryptedDoc = await _ocrCrypto.decryptOcrDocument(
          encryptedEnvelopeBytes: encryptedBytes,
          masterKeyBytes: masterKey,
          documentId: documentId,
        );

        engine = decryptedDoc.engine;
        engineVersion = decryptedDoc.engineVersion;
        schemaVersion = decryptedDoc.schemaVersion;
        language = decryptedDoc.language;
        processedAt = decryptedDoc.processedAt;
        if (decryptedDoc.sourceDocumentSha256 != null) {
          sourceSha = decryptedDoc.sourceDocumentSha256;
        }

        pages.addAll(decryptedDoc.pages);
      } catch (e) {
        debugPrint('Failed to decrypt OCR page ${row.pageNumber}: $e');
      }
    }

    if (pages.isEmpty) return null;

    pages.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));

    return OcrDocument(
      documentId: documentId,
      language: language,
      engine: engine,
      engineVersion: engineVersion,
      schemaVersion: schemaVersion,
      processedAt: processedAt,
      sourceDocumentSha256: sourceSha,
      pages: pages,
    );
  }
}
