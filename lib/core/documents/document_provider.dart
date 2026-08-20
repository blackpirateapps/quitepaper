import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../attachments/attachment_provider.dart';
import '../sync/sync_provider.dart';
import 'document_crypto.dart';
import 'document_service.dart';
import 'document_storage.dart';
import 'document_sync_service.dart';

import '../ocr/ocr_provider.dart';

final documentCryptoProvider = Provider<DocumentCrypto>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  return DocumentCrypto(cryptoService: cryptoService);
});

final documentLocalStorageProvider = Provider<DocumentLocalStorage>((ref) {
  return DocumentLocalStorage();
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final crypto = ref.watch(documentCryptoProvider);
  final storage = ref.watch(documentLocalStorageProvider);
  final cloudinaryClient = ref.watch(cloudinaryClientProvider);
  final processingService = ref.watch(documentProcessingServiceProvider);
  final apiClient = ref.watch(syncApiClientProvider);

  return DocumentService(
    database: database,
    keyManager: keyManager,
    crypto: crypto,
    storage: storage,
    cloudinaryClient: cloudinaryClient,
    processingService: processingService,
    apiClient: apiClient,
  );
});

final documentSyncServiceProvider = Provider<DocumentSyncService>((ref) {
  final database = ref.watch(databaseProvider);
  final storage = ref.watch(documentLocalStorageProvider);
  final apiClient = ref.watch(syncApiClientProvider);
  final cloudinaryClient = ref.watch(cloudinaryClientProvider);
  final authService = ref.watch(authServiceProvider);
  final keyManager = ref.watch(keyManagerProvider);

  return DocumentSyncService(
    database: database,
    storage: storage,
    apiClient: apiClient,
    cloudinaryClient: cloudinaryClient,
    authService: authService,
    keyManager: keyManager,
  );
});
