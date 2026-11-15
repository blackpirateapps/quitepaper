import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/auth/auth_service.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/sync/sync_engine.dart';
import 'package:quitepaper/core/sync/sync_models.dart';
import 'package:quitepaper/core/sync/conflict/markdown_merge_engine.dart';
import 'package:quitepaper/features/editor/application/markdown_table_parser.dart';
import 'package:quitepaper/features/editor/application/smart_table_edits.dart';
import 'package:quitepaper/features/editor/application/smart_table_markdown.dart';
import 'package:quitepaper/features/editor/domain/smart_tables/formula_engine.dart';
import '../../sync/sync_engine_test.dart' show InMemorySyncApiClient;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const parser = MarkdownTableParser();
  const table =
      '| Item | Qty | Unit price | Total |\n| --- | ---: | ---: | ---: |\n| Paper | 2 | 125 | =B2*C2 |\n| Pens | 3 | 40 | =B3*C3 |';
  String annotated() {
    var source = SmartTableEdits.calculatedColumn(
      table,
      parser.findTables(table).single,
      1,
      3,
    ).text;
    source = SmartTableEdits.summary(
      source,
      parser.findTables(source).single,
      3,
      'SUM',
    ).text;
    return SmartTableEdits.format(source, parser.findTables(source).single, 3, {
      'type': 'currency',
      'currency': 'INR',
      'digits': 2,
    }).text;
  }

  test(
    'two clients sync only ciphertext, retain offline formulas, versions and metadata',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      FlutterSecureStorage.setMockInitialValues({});
      final dbA = AppDatabase.memory(), dbB = AppDatabase.memory();
      final authA = MockAuthService(),
          authB = MockAuthService(),
          crypto = DefaultCryptoService();
      final keysA = SecureKeyManager(cryptoService: crypto),
          keysB = SecureKeyManager(cryptoService: crypto);
      final api = InMemorySyncApiClient();
      final a = SyncEngine(
        database: dbA,
        cryptoService: crypto,
        keyManager: keysA,
        authService: authA,
        apiClient: api,
      );
      final b = SyncEngine(
        database: dbB,
        cryptoService: crypto,
        keyManager: keysB,
        authService: authB,
        apiClient: api,
      );
      addTearDown(() async {
        a.dispose();
        b.dispose();
        await dbA.close();
        await dbB.close();
      });
      await authA.signUpWithEmailAndPassword(
        'tables@test.local',
        'account-password',
      );
      final wrapped = await keysA.setupNewKeys(
        password: 'table-vault-password',
        recoveryKey: crypto.generateRecoveryKey(),
        kdfParameters: const KdfParameters(
          memory: 1024,
          iterations: 1,
          parallelism: 1,
        ),
      );
      await api.putKeys(wrapped);
      final source = annotated(), now = DateTime.now();
      await dbA.saveNote(
        id: 'smart-table',
        isPinned: false,
        title: 'Supplies',
        content: source,
        createdAt: now,
        updatedAt: now,
        isDirty: true,
      );
      await dbA.saveNoteVersion(
        id: 'table-v1',
        noteId: 'smart-table',
        versionNumber: 1,
        content: source,
        createdAt: now,
      );
      await a.syncNow();
      expect(a.state.status, SyncStatus.synced);
      final payload = jsonEncode(api.serverNotes['smart-table']!.toJson());
      expect(payload, isNot(contains('=B2*C2')));
      expect(payload, isNot(contains('quiet-paper-table')));
      await authB.signInWithEmailAndPassword(
        'tables@test.local',
        'account-password',
      );
      await keysB.unlockWithPassword(
        password: 'table-vault-password',
        remoteWrappedKey: wrapped,
      );
      await b.syncNow();
      expect(b.state.status, SyncStatus.synced);
      var received = (await dbB.getNoteWithTags('smart-table'))!.note.content;
      expect(received, source);
      final reopened = deserializeQuietMarkdown(
        received,
      ).where((n) => n.metadata[quietTableSourceKey] != null).single;
      expect(reopened.metadata[quietTableSourceKey], source);
      var snapshot = parser.findTables(received).single;
      expect(FormulaEngine(tableRawCells(snapshot)).value(3, 3).display, '370');
      final offline = SmartTableEdits.updateCell(
        source,
        parser.findTables(source).single,
        1,
        1,
        '4',
      ).text;
      final originalCipher = api.serverNotes['smart-table']!.contentCiphertext;
      await dbA.saveNote(
        id: 'smart-table',
        isPinned: false,
        title: 'Supplies',
        content: offline,
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 1)),
        isDirty: true,
      );
      expect(api.serverNotes['smart-table']!.contentCiphertext, originalCipher);
      await a.syncNow();
      await b.syncNow();
      received = (await dbB.getNoteWithTags('smart-table'))!.note.content;
      expect(received, offline);
      snapshot = parser.findTables(received).single;
      expect(FormulaEngine(tableRawCells(snapshot)).value(3, 3).display, '620');
      final version = (await dbA.getNoteVersions('smart-table')).single;
      expect(version.content, source);
      await dbA.saveNote(
        id: 'smart-table',
        isPinned: false,
        title: 'Supplies',
        content: version.content,
        createdAt: now,
        updatedAt: now.add(const Duration(seconds: 2)),
        isDirty: true,
      );
      await a.syncNow();
      await b.syncNow();
      expect((await dbB.getNoteWithTags('smart-table'))!.note.content, source);
    },
  );
  test(
    'conflicting table-cell edits retain both sources for existing manual resolution',
    () {
      final base = annotated();
      final local = base.replaceFirst('| Paper | 2 |', '| Paper | 4 |');
      final remote = base.replaceFirst('| Paper | 2 |', '| Paper | 9 |');
      final result = const MarkdownMergeEngine().merge(
        base: base,
        local: local,
        remote: remote,
      );
      expect(result.requiresManual, true);
      expect(result.mergedValue, contains('=B2*C2'));
      expect(result.mergedValue, contains('quiet-paper-table:v1'));
      expect(
        result.conflictRegions.any(
          (r) => r.remoteText.contains('| Paper | 9 |'),
        ),
        true,
      );
      expect(
        result.conflictRegions.any(
          (r) => r.localText.contains('| Paper | 4 |'),
        ),
        true,
      );
    },
  );
}
