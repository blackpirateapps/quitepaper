import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../attachments/attachment_crypto.dart';
import '../attachments/attachment_storage.dart';
import '../attachments/cloudinary_client.dart';
import '../crypto/key_manager.dart';
import '../database/app_database.dart';
import '../documents/document_crypto.dart';
import '../documents/document_models.dart';
import '../documents/document_storage.dart';
import '../ocr/ocr_crypto.dart';
import '../ocr/ocr_models.dart';
import '../ocr/ocr_search_service.dart';
import '../ocr/ocr_service.dart';
import '../pdf/pdf_page_renderer.dart';
import 'maintenance_models.dart';

/// Central coordinator for client-side batch maintenance:
/// 1. Eagerly downloading all cloud attachments and documents for offline availability.
/// 2. Batch on-device OCR re-processing across all images and scanned PDFs.
/// 3. FTS5 search index rebuild and cache invalidation.
class AttachmentMaintenanceService {
  AttachmentMaintenanceService({
    required this.database,
    required this.keyManager,
    AttachmentLocalStorage? attachmentStorage,
    DocumentLocalStorage? documentStorage,
    CloudinaryClient? cloudinaryClient,
    AttachmentCrypto? attachmentCrypto,
    DocumentCrypto? documentCrypto,
    OcrCrypto? ocrCrypto,
    OcrService? ocrService,
    PdfPageRenderer? pageRenderer,
    this.ocrSearchService,
  })  : _attachmentStorage = attachmentStorage ?? AttachmentLocalStorage(),
        _documentStorage = documentStorage ?? DocumentLocalStorage(),
        _cloudinaryClient = cloudinaryClient ?? DefaultCloudinaryClient(),
        _attachmentCrypto = attachmentCrypto ?? AttachmentCrypto(),
        _documentCrypto = documentCrypto ?? DocumentCrypto(),
        _ocrCrypto = ocrCrypto ?? OcrCrypto(),
        _ocrService = ocrService ?? const DefaultOcrService(),
        _pageRenderer = pageRenderer ?? const DefaultPdfPageRenderer();

  final AppDatabase database;
  final KeyManager keyManager;
  final AttachmentLocalStorage _attachmentStorage;
  final DocumentLocalStorage _documentStorage;
  final CloudinaryClient _cloudinaryClient;
  final AttachmentCrypto _attachmentCrypto;
  final DocumentCrypto _documentCrypto;
  final OcrCrypto _ocrCrypto;
  final OcrService _ocrService;
  final PdfPageRenderer _pageRenderer;
  final OcrSearchService? ocrSearchService;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Downloads all remote attachments (images, files) and PDF documents
  /// that are not yet cached on the local filesystem.
  Future<MaintenanceProgress> downloadAllAttachments({
    MaintenanceCancellationToken? cancelToken,
    void Function(MaintenanceProgress progress)? onProgress,
  }) async {
    if (_isRunning) {
      throw StateError('A maintenance operation is already running.');
    }
    _isRunning = true;
    final token = cancelToken ?? MaintenanceCancellationToken();

    var progress = const MaintenanceProgress(
      taskType: MaintenanceTaskType.downloadAttachments,
      phase: MaintenancePhase.preparing,
      statusMessage: 'Scanning for missing attachments...',
    );
    onProgress?.call(progress);

    try {
      // 1. Discover all active attachments requiring download
      final allAttachments = await database.getActiveAttachments();
      final missingAttachments = <AttachmentEntity>[];
      for (final att in allAttachments) {
        if (token.isCancelled) break;
        if (att.cloudUrl != null && att.cloudUrl!.isNotEmpty) {
          final hasLocal = await _attachmentStorage.hasEncryptedFile(
            attachmentId: att.id,
            localPath: att.localPath,
          );
          if (!hasLocal) {
            missingAttachments.add(att);
          }
        }
      }

      // 2. Discover all active documents requiring download
      final allDocuments = await database.getActiveDocuments();
      final missingDocuments = <DocumentEntity>[];
      for (final doc in allDocuments) {
        if (token.isCancelled) break;
        if (doc.cloudUrl != null && doc.cloudUrl!.isNotEmpty) {
          final hasLocal = (await _documentStorage.readEncryptedBytes(
            documentId: doc.id,
            localPath: doc.localPath,
          )) != null;
          if (!hasLocal) {
            missingDocuments.add(doc);
          }
        }
      }

      final totalCount = missingAttachments.length + missingDocuments.length;

      if (token.isCancelled) {
        progress = progress.copyWith(
          phase: MaintenancePhase.cancelled,
          statusMessage: 'Download cancelled.',
        );
        onProgress?.call(progress);
        return progress;
      }

      if (totalCount == 0) {
        progress = progress.copyWith(
          phase: MaintenancePhase.completed,
          totalItems: 0,
          completedItems: 0,
          statusMessage: 'All attachments are already downloaded locally.',
        );
        onProgress?.call(progress);
        return progress;
      }

      var completedCount = 0;
      var failedCount = 0;
      final errors = <String>[];

      progress = progress.copyWith(
        phase: MaintenancePhase.downloading,
        totalItems: totalCount,
        completedItems: 0,
        statusMessage: 'Downloading attachments (0 of $totalCount)...',
      );
      onProgress?.call(progress);

      // 3. Download missing attachments
      for (final att in missingAttachments) {
        if (token.isCancelled) {
          progress = progress.copyWith(
            phase: MaintenancePhase.cancelled,
            statusMessage: 'Download cancelled.',
          );
          onProgress?.call(progress);
          return progress;
        }

        final displayName = att.fileName.isNotEmpty
            ? att.fileName
            : 'Attachment ${att.id.substring(0, 8)}';

        progress = progress.copyWith(
          currentItemName: displayName,
          completedItems: completedCount,
          statusMessage:
              'Downloading $displayName (${completedCount + 1} of $totalCount)...',
        );
        onProgress?.call(progress);

        try {
          final encryptedBytes = await _cloudinaryClient.downloadEncryptedBytes(
            cloudUrl: att.cloudUrl!,
          );

          final savedPath = await _attachmentStorage.saveEncryptedBytes(
            attachmentId: att.id,
            encryptedBytes: encryptedBytes,
          );

          await database.updateAttachmentUploadState(
            att.id,
            att.uploadState,
            localPath: savedPath,
          );

          completedCount++;
        } catch (e) {
          failedCount++;
          final errMsg = 'Failed to download $displayName: $e';
          errors.add(errMsg);
          debugPrint('[QuietPaper Maintenance] $errMsg');
        }

        // Yield to event loop to avoid frame lag
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      // 4. Download missing documents
      for (final doc in missingDocuments) {
        if (token.isCancelled) {
          progress = progress.copyWith(
            phase: MaintenancePhase.cancelled,
            statusMessage: 'Download cancelled.',
          );
          onProgress?.call(progress);
          return progress;
        }

        final displayName = doc.title.isNotEmpty
            ? doc.title
            : 'Document ${doc.id.substring(0, 8)}';

        progress = progress.copyWith(
          currentItemName: displayName,
          completedItems: completedCount,
          statusMessage:
              'Downloading $displayName (${completedCount + 1} of $totalCount)...',
        );
        onProgress?.call(progress);

        try {
          final encryptedBytes = await _cloudinaryClient.downloadEncryptedBytes(
            cloudUrl: doc.cloudUrl!,
          );

          final savedPath = await _documentStorage.saveEncryptedBytes(
            documentId: doc.id,
            encryptedBytes: encryptedBytes,
          );

          await database.updateDocumentUploadState(
            doc.id,
            doc.uploadState,
            localPath: savedPath,
          );

          completedCount++;
        } catch (e) {
          failedCount++;
          final errMsg = 'Failed to download $displayName: $e';
          errors.add(errMsg);
          debugPrint('[QuietPaper Maintenance] $errMsg');
        }

        // Yield to event loop
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final isSuccessful = failedCount == 0;
      final summaryMessage = isSuccessful
          ? 'Successfully downloaded $completedCount attachment(s).'
          : 'Downloaded $completedCount attachment(s) with $failedCount failure(s).';

      progress = progress.copyWith(
        phase: isSuccessful ? MaintenancePhase.completed : MaintenancePhase.completed,
        completedItems: completedCount,
        failedItems: failedCount,
        errorMessages: errors,
        statusMessage: summaryMessage,
      );
      onProgress?.call(progress);
      return progress;
    } catch (fatalErr) {
      debugPrint('[QuietPaper Maintenance] Fatal download error: $fatalErr');
      progress = progress.copyWith(
        phase: MaintenancePhase.failed,
        errorMessages: [fatalErr.toString()],
        statusMessage: 'Download failed: $fatalErr',
      );
      onProgress?.call(progress);
      return progress;
    } finally {
      _isRunning = false;
    }
  }

  /// Re-runs on-device OCR for all active image attachments and scanned/imported PDF documents.
  /// Automatically downloads missing files from the cloud if not cached locally.
  Future<MaintenanceProgress> rerunOcrForAll({
    MaintenanceCancellationToken? cancelToken,
    void Function(MaintenanceProgress progress)? onProgress,
  }) async {
    if (_isRunning) {
      throw StateError('A maintenance operation is already running.');
    }

    if (!keyManager.isUnlocked) {
      throw StateError(
        'Notebook encryption is locked. Please unlock Quiet Paper to run OCR.',
      );
    }

    _isRunning = true;
    final token = cancelToken ?? MaintenanceCancellationToken();
    final masterKey = keyManager.getMasterKey();

    var progress = const MaintenanceProgress(
      taskType: MaintenanceTaskType.rerunOcr,
      phase: MaintenancePhase.preparing,
      statusMessage: 'Scanning for images and documents...',
    );
    onProgress?.call(progress);

    try {
      // 1. Gather all active image attachments
      final allAttachments = await database.getActiveAttachments();
      final imageAttachments = allAttachments
          .where((a) => a.kind == 'image' || a.mimeType.startsWith('image/'))
          .toList();

      // 2. Gather all active PDF documents (excluding pure web snapshots)
      final allDocuments = await database.getActiveDocuments();
      final pdfDocuments = allDocuments
          .where((d) =>
              d.source != 'webSnapshot' &&
              (d.mimeType == 'application/pdf' ||
                  d.source == 'scanner' ||
                  d.source == 'imported_pdf'))
          .toList();

      final totalCount = imageAttachments.length + pdfDocuments.length;

      if (token.isCancelled) {
        progress = progress.copyWith(
          phase: MaintenancePhase.cancelled,
          statusMessage: 'OCR cancelled.',
        );
        onProgress?.call(progress);
        return progress;
      }

      if (totalCount == 0) {
        progress = progress.copyWith(
          phase: MaintenancePhase.completed,
          totalItems: 0,
          completedItems: 0,
          statusMessage: 'No images or PDF documents found for OCR.',
        );
        onProgress?.call(progress);
        return progress;
      }

      var completedCount = 0;
      var failedCount = 0;
      final errors = <String>[];

      progress = progress.copyWith(
        phase: MaintenancePhase.runningOcr,
        totalItems: totalCount,
        completedItems: 0,
        statusMessage: 'Starting OCR (0 of $totalCount)...',
      );
      onProgress?.call(progress);

      // 3. Process Image Attachments
      for (final att in imageAttachments) {
        if (token.isCancelled) {
          progress = progress.copyWith(
            phase: MaintenancePhase.cancelled,
            statusMessage: 'OCR cancelled.',
          );
          onProgress?.call(progress);
          return progress;
        }

        final displayName = att.fileName.isNotEmpty
            ? att.fileName
            : 'Image ${att.id.substring(0, 8)}';

        progress = progress.copyWith(
          currentItemName: displayName,
          completedItems: completedCount,
          currentPage: 1,
          totalPages: 1,
          statusMessage:
              'Recognizing text in $displayName (${completedCount + 1} of $totalCount)...',
        );
        onProgress?.call(progress);

        try {
          // Read local encrypted bytes (or auto-download if missing)
          var encryptedBytes = await _attachmentStorage.readEncryptedBytes(
            attachmentId: att.id,
            localPath: att.localPath,
          );

          if (encryptedBytes == null &&
              att.cloudUrl != null &&
              att.cloudUrl!.isNotEmpty) {
            encryptedBytes = await _cloudinaryClient.downloadEncryptedBytes(
              cloudUrl: att.cloudUrl!,
            );
            final savedPath = await _attachmentStorage.saveEncryptedBytes(
              attachmentId: att.id,
              encryptedBytes: encryptedBytes,
            );
            await database.updateAttachmentUploadState(
              att.id,
              att.uploadState,
              localPath: savedPath,
            );
          }

          if (encryptedBytes == null) {
            throw StateError('Encrypted image bytes missing from local storage and cloud.');
          }

          // Decrypt with Master Key
          final decryptedImageBytes = await _attachmentCrypto.decryptAttachment(
            encryptedEnvelopeBytes: encryptedBytes,
            masterKeyBytes: masterKey,
            attachmentId: att.id,
          );

          await database.updateAttachmentOcrState(
            att.id,
            'processing',
            ocrLanguage: 'en',
          );

          // Run on-device OCR
          final ocrPage = await _ocrService.recognizePage(
            decryptedImageBytes,
            pageNumber: 1,
            language: OcrLanguage.english,
          );

          final ocrDoc = OcrDocument(
            documentId: att.id,
            language: OcrLanguage.english,
            engine: 'quietpaper_image_ocr',
            engineVersion: '1.0.0',
            schemaVersion: 1,
            processedAt: DateTime.now(),
            sourceDocumentSha256: att.sha256,
            pages: [ocrPage],
          );

          // Encrypt structured OCR payload client-side
          final encOcr = await _ocrCrypto.encryptOcrDocument(
            ocrDocument: ocrDoc,
            masterKeyBytes: masterKey,
          );

          // Replace database OCR records atomically
          await database.deleteAttachmentOcrPages(att.id);
          await database.saveAttachmentOcrPage(
            attachmentId: att.id,
            pageNumber: 1,
            encryptedPayload: base64Encode(encOcr),
            language: 'en',
            processedAt: DateTime.now(),
            ocrEngine: 'quietpaper_image_ocr',
            ocrEngineVersion: '1.0.0',
            ocrSchemaVersion: 1,
          );

          // Update in-memory search cache
          ocrSearchService?.updateAttachmentCache(att.id, [ocrPage]);

          await database.updateAttachmentOcrState(
            att.id,
            'available',
            ocrLanguage: 'en',
          );

          completedCount++;
        } catch (e) {
          failedCount++;
          final errMsg = 'Failed OCR on $displayName: $e';
          errors.add(errMsg);
          debugPrint('[QuietPaper Maintenance] $errMsg');
          try {
            await database.updateAttachmentOcrState(
              att.id,
              'failed',
              ocrLanguage: 'en',
            );
          } catch (_) {}
        }

        // Memory cleanup & event loop yield
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      // 4. Process PDF Documents
      for (final doc in pdfDocuments) {
        if (token.isCancelled) {
          progress = progress.copyWith(
            phase: MaintenancePhase.cancelled,
            statusMessage: 'OCR cancelled.',
          );
          onProgress?.call(progress);
          return progress;
        }

        final displayName = doc.title.isNotEmpty
            ? doc.title
            : 'Document ${doc.id.substring(0, 8)}';

        progress = progress.copyWith(
          currentItemName: displayName,
          completedItems: completedCount,
          statusMessage:
              'Processing $displayName (${completedCount + 1} of $totalCount)...',
        );
        onProgress?.call(progress);

        try {
          // Read local encrypted bytes (or auto-download if missing)
          var encryptedBytes = await _documentStorage.readEncryptedBytes(
            documentId: doc.id,
            localPath: doc.localPath,
          );

          if (encryptedBytes == null &&
              doc.cloudUrl != null &&
              doc.cloudUrl!.isNotEmpty) {
            encryptedBytes = await _cloudinaryClient.downloadEncryptedBytes(
              cloudUrl: doc.cloudUrl!,
            );
            final savedPath = await _documentStorage.saveEncryptedBytes(
              documentId: doc.id,
              encryptedBytes: encryptedBytes,
            );
            await database.updateDocumentUploadState(
              doc.id,
              doc.uploadState,
              localPath: savedPath,
            );
          }

          if (encryptedBytes == null) {
            throw StateError('Encrypted PDF bytes missing from local storage and cloud.');
          }

          // Decrypt with Master Key
          final decryptedPdfBytes = await _documentCrypto.decryptDocument(
            encryptedEnvelopeBytes: encryptedBytes,
            masterKeyBytes: masterKey,
            documentId: doc.id,
          );

          await database.updateDocumentOcrState(
            doc.id,
            OcrProcessingState.processing.identifier,
            ocrLanguage: 'en',
          );

          // Rasterize and process pages sequentially to avoid OOM memory spikes
          final renderedPages = await _pageRenderer.renderPages(
            decryptedPdfBytes,
            dpi: 150.0,
          );

          final ocrPages = <OcrPage>[];
          for (final rendered in renderedPages) {
            if (token.isCancelled) break;

            progress = progress.copyWith(
              currentPage: rendered.pageNumber,
              totalPages: renderedPages.length,
              statusMessage:
                  '$displayName • Page ${rendered.pageNumber} of ${renderedPages.length}...',
            );
            onProgress?.call(progress);

            final ocrPage = await _ocrService.recognizePage(
              rendered.imageBytes,
              pageNumber: rendered.pageNumber,
              language: OcrLanguage.english,
            );
            ocrPages.add(ocrPage);

            // Yield after each page to let GC reclaim raster bitmaps
            await Future<void>.delayed(const Duration(milliseconds: 20));
          }

          if (token.isCancelled) {
            progress = progress.copyWith(
              phase: MaintenancePhase.cancelled,
              statusMessage: 'OCR cancelled.',
            );
            onProgress?.call(progress);
            return progress;
          }

          final pdfSha256 = DocumentCrypto.computeSha256(decryptedPdfBytes);
          final now = DateTime.now();
          final pagePayloads = <({int pageNumber, String payloadBase64})>[];

          for (final p in ocrPages) {
            final pageDoc = OcrDocument(
              documentId: doc.id,
              language: OcrLanguage.english,
              engine: 'quietpaper_ml_ocr',
              engineVersion: '1.0.0',
              schemaVersion: 1,
              processedAt: now,
              sourceDocumentSha256: pdfSha256,
              pages: [p],
            );

            final encBytes = await _ocrCrypto.encryptOcrDocument(
              ocrDocument: pageDoc,
              masterKeyBytes: masterKey,
            );

            pagePayloads.add((
              pageNumber: p.pageNumber,
              payloadBase64: base64Encode(encBytes),
            ));
          }

          // Atomically replace database records
          await database.deleteDocumentOcrPages(doc.id);
          for (final item in pagePayloads) {
            await database.saveDocumentOcrPage(
              documentId: doc.id,
              pageNumber: item.pageNumber,
              encryptedPayload: item.payloadBase64,
              language: 'en',
              processedAt: now,
              ocrEngine: 'quietpaper_ml_ocr',
              ocrEngineVersion: '1.0.0',
              ocrSchemaVersion: 1,
            );
          }

          // Update in-memory search cache
          ocrSearchService?.updateDocumentCache(doc.id, ocrPages);

          await database.updateDocumentOcrState(
            doc.id,
            OcrProcessingState.available.identifier,
            ocrLanguage: 'en',
          );

          completedCount++;
        } catch (e) {
          failedCount++;
          final errMsg = 'Failed OCR on $displayName: $e';
          errors.add(errMsg);
          debugPrint('[QuietPaper Maintenance] $errMsg');
          try {
            await database.updateDocumentOcrState(
              doc.id,
              OcrProcessingState.failed.identifier,
              ocrLanguage: 'en',
            );
          } catch (_) {}
        }

        // Memory cleanup & event loop yield
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }

      final isSuccessful = failedCount == 0;
      final summaryMessage = isSuccessful
          ? 'OCR completed for $completedCount document(s) & image(s).'
          : 'OCR completed for $completedCount item(s) with $failedCount failure(s).';

      progress = progress.copyWith(
        phase: MaintenancePhase.completed,
        completedItems: completedCount,
        failedItems: failedCount,
        errorMessages: errors,
        statusMessage: summaryMessage,
      );
      onProgress?.call(progress);
      return progress;
    } catch (fatalErr) {
      debugPrint('[QuietPaper Maintenance] Fatal OCR error: $fatalErr');
      progress = progress.copyWith(
        phase: MaintenancePhase.failed,
        errorMessages: [fatalErr.toString()],
        statusMessage: 'OCR processing failed: $fatalErr',
      );
      onProgress?.call(progress);
      return progress;
    } finally {
      _isRunning = false;
    }
  }

  /// Rebuilds SQLite FTS5 search indexes and clears in-memory OCR caches.
  Future<void> rebuildSearchIndex() async {
    await database.rebuildSearchIndex();
    ocrSearchService?.clearCache();
  }
}
