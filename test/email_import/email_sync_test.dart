import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/features/email_import/application/email_import_service.dart';
import 'package:quitepaper/features/email_import/application/email_parser.dart';
import 'package:quitepaper/features/email_import/domain/email_message.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import '../sync/sync_engine_test.dart' show InMemorySyncApiClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'real encrypted sync carries email provenance and rebuilds fresh-device duplicates/search',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      FlutterSecureStorage.setMockInitialValues({});
      final a = AppDatabase.memory(), b = AppDatabase.memory();
      final crypto = DefaultCryptoService();
      final ka = SecureKeyManager(cryptoService: crypto),
          kb = SecureKeyManager(cryptoService: crypto);
      final authA = MockAuthService(), authB = MockAuthService();
      final api = InMemorySyncApiClient();
      final engineA = SyncEngine(
        database: a,
        cryptoService: crypto,
        keyManager: ka,
        authService: authA,
        apiClient: api,
      );
      final engineB = SyncEngine(
        database: b,
        cryptoService: crypto,
        keyManager: kb,
        authService: authB,
        apiClient: api,
      );
      final dir = await Directory.systemTemp.createTemp('email-sync-');
      try {
        await authA.signUpWithEmailAndPassword(
          'sync@example.test',
          'account-password',
        );
        final wrapped = await ka.setupNewKeys(
          password: 'vault-password',
          recoveryKey: crypto.generateRecoveryKey(),
          kdfParameters: const KdfParameters(
            memory: 1024,
            iterations: 1,
            parallelism: 1,
          ),
        );
        await api.putKeys(wrapped);
        final source = const EmailParser().parseSync(
          File('test/email_import/fixtures/plain.eml').readAsBytesSync(),
        );
        final repoA = DriftNotesRepository(a);
        final service = EmailImportService(
          database: a,
          repository: repoA,
          attachments: AttachmentService(
            database: a,
            keyManager: ka,
            storage: AttachmentLocalStorage(customBaseDirectory: dir),
          ),
        );
        final note = await service.save(
          email: source,
          mode: EmailImportMode.editable,
          title: source.subject,
        );
        await engineA.syncNow();
        final cloud = api.serverNotes[note.id]!;
        expect(cloud.contentCiphertext, isNot(contains(source.sender)));
        expect(cloud.contentCiphertext, isNot(contains(source.subject)));
        await authB.signInWithEmailAndPassword(
          'sync@example.test',
          'account-password',
        );
        await kb.unlockWithPassword(
          password: 'vault-password',
          remoteWrappedKey: wrapped,
        );
        await engineB.syncNow();
        final repoB = DriftNotesRepository(b);
        final pulled = (await repoB.getNoteById(note.id))!;
        expect(pulled.importSources, note.importSources);
        expect(pulled.content, note.content);
        expect(pulled.tags, ['email']);
        expect(
          await b.findEmailDuplicates(
            rawHash: source.rawHash,
            fingerprint: source.fingerprint,
          ),
          [(noteId: note.id, exact: true)],
        );
        expect(
          await repoB.watchNotes(searchQuery: 'Alice').first,
          hasLength(1),
        );
      } finally {
        engineA.dispose();
        engineB.dispose();
        await a.close();
        await b.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
