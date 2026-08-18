import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../auth/auth_service.dart';
import '../crypto/crypto_service.dart';
import '../crypto/key_manager.dart';
import 'sync_api_client.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return FirebaseAuthService();
});

final authStateProvider = StreamProvider<AuthUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<AuthUser?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authServiceProvider).currentUser;
});

final cryptoServiceProvider = Provider<CryptoService>((ref) {
  return DefaultCryptoService();
});

final keyManagerProvider = Provider<KeyManager>((ref) {
  final crypto = ref.watch(cryptoServiceProvider);
  final km = SecureKeyManager(cryptoService: crypto);
  km.initialize();
  return km;
});

final isKeyManagerUnlockedProvider = StateProvider<bool>((ref) {
  final km = ref.watch(keyManagerProvider);
  return km.isUnlocked;
});

final syncApiClientProvider = Provider<SyncApiClient>((ref) {
  final auth = ref.watch(authServiceProvider);
  return HttpSyncApiClient(authService: auth);
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final db = ref.watch(databaseProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  final keyManager = ref.watch(keyManagerProvider);
  final auth = ref.watch(authServiceProvider);
  final api = ref.watch(syncApiClientProvider);

  final engine = SyncEngine(
    database: db,
    cryptoService: crypto,
    keyManager: keyManager,
    authService: auth,
    apiClient: api,
  );

  ref.onDispose(engine.dispose);
  return engine;
});

final syncStateStreamProvider = StreamProvider<SyncState>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return engine.stateStream;
});

final syncStateProvider = Provider<SyncState>((ref) {
  final asyncState = ref.watch(syncStateStreamProvider);
  return asyncState.value ?? ref.watch(syncEngineProvider).state;
});
