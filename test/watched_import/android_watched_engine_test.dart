import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/watched_import/application/android_folder_access.dart';
import 'package:quitepaper/features/watched_import/application/android_watched_engine.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';

class FakeAndroidAccess implements AndroidFolderAccess {
  final documents = <String, AndroidDocument>{};
  final folders = <String, List<String>>{'root': []};
  final content = <String, Uint8List>{};
  final sessions = <String, String>{};
  final readySessions = <String>{};
  final stopped = <String>{};
  final statBatchSizes = <int>[];
  int reads = 0, listings = 0;
  String? failure;
  final readFailures = <String, String>{};
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeChildren;
  AndroidDocumentPage Function()? pageOverride;
  ({List<String> source, String target})? related;
  void file(
    String id,
    String name,
    String value, {
    String parent = 'root',
    bool unknown = false,
    bool partial = false,
    bool virtual = false,
  }) {
    final data = Uint8List.fromList(utf8.encode(value));
    documents[id] = AndroidDocument(
      id: id,
      name: name,
      mime: 'text/plain',
      fingerprint: '$id:$name:${unknown ? "?" : value}',
      size: unknown ? null : data.length,
      partial: partial,
      virtual: virtual,
    );
    content[id] = data;
    if (!folders.putIfAbsent(parent, () => []).contains(id)) {
      folders[parent]!.add(id);
    }
  }

  void directory(String id, {String parent = 'root'}) {
    documents[id] = AndroidDocument(
      id: id,
      name: id,
      mime: 'vnd.android.document/directory',
      fingerprint: id,
    );
    folders.putIfAbsent(parent, () => []).add(id);
    folders[id] = [];
  }

  @override
  Future<void> available() async {}
  @override
  Future<String?> chooseFolder() async => 'content://provider/tree/root';
  @override
  Future<({String root, String identity, String name})> inspect(
    String root,
  ) async => (root: root, identity: 'saf:$root', name: 'Test folder');
  @override
  Future<String> start(String session, String root, String identity) async {
    sessions[session] = root;
    return root.endsWith('/other') ? 'other' : 'root';
  }

  @override
  Future<void> ready(String session, bool ready) async {
    ready ? readySessions.add(session) : readySessions.remove(session);
  }

  @override
  Future<AndroidDocumentPage> children(
    String session,
    String parent,
    int offset,
  ) async {
    listings++;
    await beforeChildren?.call();
    if (failure != null) throw PlatformException(code: failure!);
    if (pageOverride != null) return pageOverride!();
    final ids = folders[parent] ?? [];
    return AndroidDocumentPage(
      ids.skip(offset).take(64).map((id) => documents[id]!).toList(),
      offset + 64 < ids.length ? offset + 64 : null,
    );
  }

  @override
  Future<List<AndroidDocument>> stat(String session, List<String> ids) async {
    statBatchSizes.add(ids.length);
    return ids.map((id) => documents[id]).whereType<AndroidDocument>().toList();
  }

  @override
  Future<AndroidRead> read(
    String session,
    String id,
    int limit, {
    required bool bytes,
  }) async {
    reads++;
    if (readFailures[id] case final String code) {
      throw PlatformException(code: code);
    }
    await beforeRead?.call();
    final data = content[id]!;
    if (data.length > limit) {
      throw PlatformException(code: 'unsupported_or_oversized');
    }
    final hash = sha256.convert(data).toString();
    return AndroidRead(
      sha256: hash,
      revision: '${documents[id]!.fingerprint}:$hash',
      fingerprint: documents[id]!.fingerprint,
      size: data.length,
      bytes: bytes ? data : null,
    );
  }

  @override
  Future<Uint8List> relatedImage(
    String session,
    List<String> source,
    String target,
  ) async {
    related = (source: source, target: target);
    return Uint8List.fromList([1]);
  }

  @override
  Future<void> stop(String session) async {
    stopped.add(session);
    readySessions.remove(session);
  }

  @override
  Future<void> open(String root, [String? documentId]) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAndroidAccess access;
  late AndroidWatchedEngine engine;
  late DateTime clock;
  late int handle;
  setUp(() async {
    access = FakeAndroidAccess();
    clock = DateTime(2026);
    engine = AndroidWatchedEngine(access: access, now: () => clock);
    handle = await engine.start(
      'first',
      'content://provider/tree/root',
      'identity',
      true,
    );
    await engine.ready(handle, true);
  });
  tearDown(() async {
    await engine.stop(handle);
  });
  Future<List<EngineEvent>> tick([int milliseconds = 500]) async {
    clock = clock.add(Duration(milliseconds: milliseconds));
    return engine.events(handle);
  }

  Future<Candidate> nextCandidate() async {
    for (var i = 0; i < 100; i++) {
      for (final event in await tick()) {
        if (event.candidate != null) return event.candidate!;
      }
    }
    fail('No stable candidate');
  }

  Future<List<EngineEvent>> complete() async {
    final all = <EngineEvent>[];
    for (var i = 0; i < 100; i++) {
      final events = await tick();
      all.addAll(events);
      for (final e in events) {
        if (e.candidate != null) {
          await engine.acknowledge(
            handle,
            e.candidate!.jobId,
            Outcome.complete,
          );
        }
      }
      if (events.any((e) => e.kind == EventKind.scanComplete)) return all;
    }
    fail('Scan did not finish');
  }

  test(
    'stabilizes before hashing; snapshots verify bytes; originals remain unchanged',
    () async {
      access.file('opaque:1', 'note.TXT', 'hello');
      expect((await tick()).where((e) => e.candidate != null), isEmpty);
      expect(access.reads, 0);
      final c = await nextCandidate();
      expect(c.folderId, 'first');
      expect(c.initialInventory, isTrue);
      expect(c.format, 'txt');
      expect(utf8.decode(c.relativePath), 'opaque:1');
      expect(utf8.decode(await engine.snapshot(handle, c.jobId)), 'hello');
      expect(utf8.decode(access.content['opaque:1']!), 'hello');
      await engine.acknowledge(handle, c.jobId, Outcome.complete);
      expect((await complete()).last.code, isNull);
    },
  );
  test(
    'null metadata with same-size rewrites yields a new content revision',
    () async {
      access.file('id', 'x.txt', 'first', unknown: true);
      final first = await nextCandidate();
      await engine.acknowledge(handle, first.jobId, Outcome.complete);
      await complete();
      access.file('id', 'x.txt', 'later', unknown: true);
      await engine.reconcile(handle);
      final second = await nextCandidate();
      expect(first.revision, isNot(second.revision));
      expect(first.sha256, isNot(second.sha256));
      expect(second.initialInventory, isFalse);
    },
  );
  test(
    'metadata changes restart quiet period; mutated snapshots are rejected',
    () async {
      access.file('id', 'a.txt', 'before');
      await tick();
      await tick(1500);
      access.file('id', 'a.txt', 'changed');
      expect((await tick()).where((e) => e.candidate != null), isEmpty);
      final c = await nextCandidate();
      access.file('id', 'a.txt', 'changed again');
      await expectLater(
        engine.snapshot(handle, c.jobId),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'source_changed',
          ),
        ),
      );
    },
  );
  test('two roots pause, resume, lock and stop independently', () async {
    access.file('a', 'a.txt', 'first');
    access.folders['other'] = [];
    access.file('b', 'b.txt', 'second', parent: 'other');
    final second = await engine.start(
      'second',
      'content://provider/tree/other',
      'id',
      false,
    );
    await engine.ready(second, true);
    await engine.pause(handle);
    for (var i = 0; i < 10; i++) {
      clock = clock.add(const Duration(seconds: 1));
      final events = await engine.events(second);
      if (events.any((e) => e.candidate != null)) break;
    }
    expect(access.reads, 1);
    expect(await engine.events(handle), isEmpty);
    await engine.stop(handle);
    await engine.resume(second);
    await engine.stop(second);
    expect(access.stopped, hasLength(2));
  });
  test('lock during a snapshot rejects returned bytes', () async {
    access.file('id', 'a.txt', 'body');
    final c = await nextCandidate();
    access.beforeRead = () => engine.ready(handle, false);
    await expectLater(
      engine.snapshot(handle, c.jobId),
      throwsA(isA<PlatformException>()),
    );
    final reads = access.reads;
    expect(await tick(10000), isEmpty);
    expect(access.reads, reads);
  });
  test('stopping during discovery cannot deliver a late candidate', () async {
    access.file('id', 'a.txt', 'body');
    access.beforeChildren = () => engine.stop(handle);
    expect(await tick(), isEmpty);
    expect(access.reads, 0);
  });
  test(
    'pagination and nested traversal are bounded and preserve Markdown image context',
    () async {
      access.directory('nested');
      for (var i = 0; i < 140; i++) {
        access.file('f$i', '$i.md', 'body $i', parent: 'nested');
      }
      final c = await nextCandidate();
      expect(access.statBatchSizes.every((n) => n <= 8), isTrue);
      await engine.relatedImage(handle, c.jobId, '../images/a.png');
      expect(access.related!.source, ['nested', c.displayName]);
      expect(access.related!.target, '../images/a.png');
    },
  );
  test(
    'hidden, temporary, oversized and unsafe display names are excluded',
    () async {
      for (final name in [
        '.hidden.txt',
        'file.part',
        '../escape.txt',
        'slash/name.txt',
        'bad\\name.txt',
        'bad\u0000name.txt',
      ]) {
        access.file(name, name, 'body');
      }
      access.documents['huge'] = const AndroidDocument(
        id: 'huge',
        name: 'huge.eml',
        mime: 'message/rfc822',
        fingerprint: 'big',
        size: 999999999,
      );
      access.folders['root']!.add('huge');
      final events = await complete();
      expect(events.where((e) => e.candidate != null), isEmpty);
      expect(access.reads, 0);
    },
  );
  for (final failure in [
    'permission_needed',
    'provider_loading',
    'provider_io',
  ]) {
    test(
      '$failure fails inventory closed and can recover after rescan',
      () async {
        access.failure = failure;
        final failed = await complete();
        expect(failed.last.code, 'inventory_incomplete');
        expect(failed.any((e) => e.code == failure), isTrue);
        access.failure = null;
        access.file('id', 'a.txt', 'recovered');
        await engine.reconcile(handle);
        expect((await nextCandidate()).initialInventory, isTrue);
      },
    );
  }
  for (final virtual in [false, true]) {
    test(
      'partial/virtual documents block initial acceptance, virtual=$virtual',
      () async {
        access.file(
          'id',
          'a.txt',
          'incomplete',
          partial: !virtual,
          virtual: virtual,
        );
        expect((await complete()).last.code, 'inventory_incomplete');
        expect(access.reads, 0);
      },
    );
  }
  test(
    'provider cycles and non-advancing pages cannot loop or accept inventory',
    () async {
      access.directory('nested');
      access.folders['nested']!.add('nested');
      expect((await complete()).last.code, 'inventory_incomplete');
      access.pageOverride = () => const AndroidDocumentPage([], 0);
      await engine.reconcile(handle);
      expect((await complete()).last.code, 'inventory_incomplete');
    },
  );
  test(
    'unsupported binary and partial temporary downloads do not block valid inventory',
    () async {
      access.file('bad', 'not-a-real.png', 'invalid binary');
      access.readFailures['bad'] = 'unsupported_or_oversized';
      access.file('temporary', 'download.crdownload', 'partial', partial: true);
      access.file('good', 'good.txt', 'valid text');
      final events = await complete();
      expect(
        events
            .where((e) => e.candidate != null)
            .map((e) => e.candidate!.displayName),
        ['good.txt'],
      );
      expect(events.last.code, isNull);
    },
  );

  test(
    'background cancellation of directory loading cannot accept a partial inventory',
    () async {
      access.file('id', 'a.txt', 'retained initial file');
      access.beforeChildren = () async {
        await engine.ready(handle, false);
        throw PlatformException(code: 'locked');
      };
      expect(await tick(), isEmpty);
      access.beforeChildren = null;
      await engine.ready(handle, true);
      await engine.reconcile(handle);
      expect((await nextCandidate()).initialInventory, isTrue);
    },
  );

  test('retry outcome enforces returned backoff before another read', () async {
    access.file('id', 'a.txt', 'retry');
    final c = await nextCandidate();
    expect(await engine.acknowledge(handle, c.jobId, Outcome.retry), 2000);
    final reads = access.reads;
    expect(await tick(100), isEmpty);
    expect(access.reads, reads);
  });
}
