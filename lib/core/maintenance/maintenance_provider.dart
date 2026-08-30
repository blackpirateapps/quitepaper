import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../attachments/attachment_provider.dart';
import '../documents/document_provider.dart';
import '../ocr/ocr_provider.dart';
import '../sync/sync_provider.dart';
import 'attachment_maintenance_service.dart';

final attachmentMaintenanceServiceProvider =
    Provider<AttachmentMaintenanceService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final attachmentStorage = ref.watch(attachmentLocalStorageProvider);
  final documentStorage = ref.watch(documentLocalStorageProvider);
  final cloudinaryClient = ref.watch(cloudinaryClientProvider);
  final attachmentCrypto = ref.watch(attachmentCryptoProvider);
  final documentCrypto = ref.watch(documentCryptoProvider);
  final ocrCrypto = ref.watch(ocrCryptoProvider);
  final ocrService = ref.watch(ocrServiceProvider);
  final pageRenderer = ref.watch(pdfPageRendererProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);

  return AttachmentMaintenanceService(
    database: database,
    keyManager: keyManager,
    attachmentStorage: attachmentStorage,
    documentStorage: documentStorage,
    cloudinaryClient: cloudinaryClient,
    attachmentCrypto: attachmentCrypto,
    documentCrypto: documentCrypto,
    ocrCrypto: ocrCrypto,
    ocrService: ocrService,
    pageRenderer: pageRenderer,
    ocrSearchService: ocrSearchService,
  );
});
