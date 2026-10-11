import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/notes/application/notes_provider.dart';
import '../../sync/sync_provider.dart';
import 'annotation_crypto.dart';
import 'annotation_service.dart';

/// Client-side authenticated annotation payload encryption.
final annotationCryptoProvider = Provider<AnnotationCrypto>((ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  return AnnotationCrypto(cryptoService: cryptoService);
});

/// Loads and persists the encrypted per-page annotation sidecar.
final documentAnnotationServiceProvider =
    Provider<DocumentAnnotationService>((ref) {
  final database = ref.watch(databaseProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final crypto = ref.watch(annotationCryptoProvider);
  return DocumentAnnotationService(
    database: database,
    keyManager: keyManager,
    crypto: crypto,
  );
});
