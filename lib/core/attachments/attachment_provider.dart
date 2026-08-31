import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../documents/document_provider.dart';
import '../sync/sync_provider.dart';
import '../uri/local_note_resolver.dart';
import '../uri/resource_resolver.dart';
import '../ocr/ocr_provider.dart';
import 'attachment_crypto.dart';
import 'attachment_open_service.dart';
import 'attachment_processing_service.dart';
import 'attachment_service.dart';
import 'attachment_share_service.dart';
import 'attachment_storage.dart';
import 'attachment_sync_service.dart';
import 'attachment_temp_storage.dart';
import 'cloudinary_client.dart';

final attachmentCryptoProvider = Provider<AttachmentCrypto>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  return AttachmentCrypto(cryptoService: cryptoService);
});

final attachmentLocalStorageProvider = Provider<AttachmentLocalStorage>((ref) {
  return AttachmentLocalStorage();
});

final cloudinaryClientProvider = Provider<CloudinaryClient>((ref) {
  return DefaultCloudinaryClient();
});

final attachmentProcessingServiceProvider =
    Provider<AttachmentProcessingService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final ocrCrypto = ref.watch(ocrCryptoProvider);
  final ocrService = ref.watch(ocrServiceProvider);
  final ocrSearchService = ref.watch(ocrSearchServiceProvider);

  return AttachmentProcessingService(
    database: database,
    keyManager: keyManager,
    ocrCrypto: ocrCrypto,
    ocrService: ocrService,
    ocrSearchService: ocrSearchService,
  );
});

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final crypto = ref.watch(attachmentCryptoProvider);
  final storage = ref.watch(attachmentLocalStorageProvider);
  final cloudinaryClient = ref.watch(cloudinaryClientProvider);
  final apiClient = ref.watch(syncApiClientProvider);
  final processingService = ref.watch(attachmentProcessingServiceProvider);

  return AttachmentService(
    database: database,
    keyManager: keyManager,
    crypto: crypto,
    storage: storage,
    cloudinaryClient: cloudinaryClient,
    apiClient: apiClient,
    processingService: processingService,
  );
});

final attachmentSyncServiceProvider = Provider<AttachmentSyncService>((ref) {
  final database = ref.watch(databaseProvider);
  final storage = ref.watch(attachmentLocalStorageProvider);
  final apiClient = ref.watch(syncApiClientProvider);
  final cloudinaryClient = ref.watch(cloudinaryClientProvider);
  final authService = ref.watch(authServiceProvider);
  final keyManager = ref.watch(keyManagerProvider);

  return AttachmentSyncService(
    database: database,
    storage: storage,
    apiClient: apiClient,
    cloudinaryClient: cloudinaryClient,
    authService: authService,
    keyManager: keyManager,
  );
});

final attachmentTempStorageProvider = Provider<AttachmentTempStorage>((ref) {
  return AttachmentTempStorage();
});

final attachmentOpenServiceProvider = Provider<AttachmentOpenService>((ref) {
  final attachmentService = ref.watch(attachmentServiceProvider);
  final tempStorage = ref.watch(attachmentTempStorageProvider);
  return AttachmentOpenService(
    attachmentService: attachmentService,
    tempStorage: tempStorage,
  );
});

final attachmentShareServiceProvider = Provider<AttachmentShareService>((ref) {
  final attachmentService = ref.watch(attachmentServiceProvider);
  final tempStorage = ref.watch(attachmentTempStorageProvider);
  return AttachmentShareService(
    attachmentService: attachmentService,
    tempStorage: tempStorage,
  );
});

final resourceResolverProvider = Provider<QuietPaperResourceResolver>((ref) {
  final attachmentService = ref.watch(attachmentServiceProvider);
  final documentService = ref.watch(documentServiceProvider);
  final db = ref.watch(databaseProvider);
  return QuietPaperResourceResolver(
    assetResolver: attachmentService,
    documentResolver: documentService,
    noteResolver: LocalNoteResolver(db),
  );
});


