import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../ocr/ocr_crypto.dart';
import '../ocr/ocr_models.dart';
import '../ocr/ocr_search_service.dart';
import '../ocr/ocr_service.dart';
import 'attachment_crypto.dart';

/// Asynchronous coordinator for image on-device OCR,
/// client-side encryption of OCR payloads, and recovery across app restarts.
class AttachmentProcessingService {
  AttachmentProcessingService({
    required this.database,
    required this.keyManager,
    OcrCrypto? ocrCrypto,
    OcrService? ocrService,
    this.ocrSearchService,
  })  : _ocrCrypto = ocrCrypto ?? OcrCrypto(),
        _ocrService = ocrService ?? const DefaultOcrService();

  final AppDatabase database;
  final KeyManager keyManager;
  final OcrCrypto _ocrCrypto;
  final OcrService _ocrService;
  final OcrSearchService? ocrSearchService;

  final Set<String> _inFlightJobIds = <String>{};

  /// Asynchronously processes an image attachment with on-device OCR in the background.
  Future<void> processAttachment({
    required String attachmentId,
    required Uint8List imageBytes,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    if (_inFlightJobIds.contains(attachmentId)) {
      debugPrint(
        '[QuietPaper Image OCR] Attachment $attachmentId is already being processed. Skipping duplicate.',
      );
      return;
    }

    _inFlightJobIds.add(attachmentId);
    debugPrint(
      '[QuietPaper Image OCR] Started OCR processing for attachment $attachmentId (size: ${imageBytes.length} bytes, lang: ${language.code})',
    );

    try {
      await database.updateAttachmentOcrState(
        attachmentId,
        'processing',
        ocrLanguage: language.code,
      );

      final imageSha256 = AttachmentCrypto.computeSha256(imageBytes);

      // Run on-device OCR recognition on the image bitmap
      final ocrPage = await _ocrService.recognizePage(
        imageBytes,
        pageNumber: 1,
        language: language,
      );

      final ocrResult = OcrDocument(
        documentId: attachmentId,
        language: language,
        engine: 'quietpaper_image_ocr',
        engineVersion: '1.0.0',
        schemaVersion: 1,
        processedAt: DateTime.now(),
        sourceDocumentSha256: imageSha256,
        pages: [ocrPage],
      );

      // Encrypt structured OCR payload client-side using Master Key and atomically save
      if (keyManager.isUnlocked) {
        debugPrint(
          '[QuietPaper Image OCR] Encrypting image OCR dataset with Master Key...',
        );
        final masterKey = keyManager.getMasterKey();
        final now = DateTime.now();

        final encryptedBytes = await _ocrCrypto.encryptOcrDocument(
          ocrDocument: ocrResult,
          masterKeyBytes: masterKey,
        );

        final payloadBase64 = base64Encode(encryptedBytes);

        // Atomically replace: delete existing records before writing new payload
        await database.deleteAttachmentOcrPages(attachmentId);

        await database.saveAttachmentOcrPage(
          attachmentId: attachmentId,
          pageNumber: 1,
          encryptedPayload: payloadBase64,
          ocrSchemaVersion: 1,
          ocrEngine: 'quietpaper_image_ocr',
          ocrEngineVersion: '1.0.0',
          language: language.code,
          processedAt: now,
        );

        // Update in-memory decrypted OCR search cache
        ocrSearchService?.updateAttachmentCache(attachmentId, [ocrPage]);
      }

      await database.updateAttachmentOcrState(
        attachmentId,
        'available',
        ocrLanguage: language.code,
      );

      debugPrint(
        '[QuietPaper Image OCR] Attachment $attachmentId OCR completed successfully (${ocrPage.blocks.length} blocks, ${ocrPage.plainText.length} chars).',
      );
    } catch (e, stack) {
      debugPrint(
        '[QuietPaper Image OCR] Failed OCR processing for attachment $attachmentId: $e\n$stack',
      );
      try {
        await database.updateAttachmentOcrState(
          attachmentId,
          'failed',
          ocrLanguage: language.code,
        );
      } catch (_) {}
    } finally {
      _inFlightJobIds.remove(attachmentId);
    }
  }

  /// Manually re-runs OCR for an attachment.
  Future<void> regenerateOcr({
    required String attachmentId,
    required Uint8List imageBytes,
    OcrLanguage language = OcrLanguage.english,
  }) async {
    _inFlightJobIds.remove(attachmentId);
    ocrSearchService?.invalidateAttachmentCache(attachmentId);
    await processAttachment(
      attachmentId: attachmentId,
      imageBytes: imageBytes,
      language: language,
    );
  }
}
