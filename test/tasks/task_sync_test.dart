import 'dart:convert';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/features/editor/application/rich_document_parser.dart';
import 'package:quitepaper/features/notes/data/notes_repository.dart';
import 'package:quitepaper/features/tasks/application/task_service.dart';
import 'package:quitepaper/features/tasks/domain/task_document.dart';
import 'package:quitepaper/features/tasks/domain/task_item.dart';
import '../sync/sync_engine_conflict_test.dart'
    show ConflictSimulatingSyncApiClient;

const captureId = '03fe77cf-8000-4d05-ba80-d365fd69b17c';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final rich in [false, true]) {
    test(
      'two encrypted offline clients merge completion and date ${rich ? 'rich' : 'Markdown'}',
      () async {
        driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
        FlutterSecureStorage.setMockInitialValues({});
        final a = AppDatabase.memory(), b = AppDatabase.memory();
        final crypto = DefaultCryptoService();
        final ka = SecureKeyManager(cryptoService: crypto),
            kb = SecureKeyManager(cryptoService: crypto);
        final authA = MockAuthService(), authB = MockAuthService();
        final api = ConflictSimulatingSyncApiClient();
        final ea = SyncEngine(
          database: a,
          cryptoService: crypto,
          keyManager: ka,
          authService: authA,
          apiClient: api,
        );
        final eb = SyncEngine(
          database: b,
          cryptoService: crypto,
          keyManager: kb,
          authService: authB,
          apiClient: api,
        );
        try {
          await authA.signUpWithEmailAndPassword(
            'tasks@example.test',
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
          await authB.signInWithEmailAndPassword(
            'tasks@example.test',
            'account-password',
          );
          await kb.unlockWithPassword(
            password: 'vault-password',
            remoteWrappedKey: wrapped,
          );
          final ra = DriftNotesRepository(a), rb = DriftNotesRepository(b);
          final sa = TaskService(
            a,
            ra,
            inboxNamespace: () async => 'shared-synthetic-vault',
          );
          final sb = TaskService(
            b,
            rb,
            inboxNamespace: () async => 'shared-synthetic-vault',
          );
          final captured = await sa.capture(
            text: 'Private task বাংলা',
            captureId: captureId,
            due: TaskDate.tryParse('2026-11-27'),
          );
          if (rich) {
            await ra.saveNote(
              captured.note.copyWith(
                content: jsonEncode(
                  const RichDocumentParser()
                      .parse(captured.note.content)
                      .toJson(),
                ),
              ),
            );
          }
          await ea.syncNow();
          await eb.syncNow();
          final na = (await ra.getNoteById(captured.note.id))!,
              nb = (await rb.getNoteById(captured.note.id))!;
          expect(nb.content, na.content);
          expect(await b.watchTaskRows().first, hasLength(1));
          TaskItem item(n) => TaskItem(
            note: n,
            version: TaskDocument.version(n.content),
            occurrence: TaskDocument.extract(n.content).single,
          );
          await sa.setCompleted(item(na), true);
          await sb.setDate(item(nb), TaskDate.tryParse('2026-11-28'));
          await ea.syncNow();
          await eb.syncNow();
          await eb.syncNow();
          await ea.syncNow();
          for (final repo in [ra, rb]) {
            final current = (await repo.getNoteById(captured.note.id))!;
            final task = TaskDocument.extract(current.content).single;
            expect(task.completed, isTrue);
            expect(task.metadata!.id, captureId);
            expect(task.metadata!.due.toString(), '2026-11-28');
          }
          final cloud = api.serverNotes[captured.note.id]!;
          for (final plaintext in ['Private task', '2026-11-28', captureId]) {
            expect(cloud.contentCiphertext, isNot(contains(plaintext)));
          }
          expect(await a.getPendingConflictsCount(), 0);
          expect(await b.getPendingConflictsCount(), 0);
        } finally {
          ea.dispose();
          eb.dispose();
          await a.close();
          await b.close();
        }
      },
    );
  }
}
