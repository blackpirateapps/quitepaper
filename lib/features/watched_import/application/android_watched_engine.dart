import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../native/api/engine.dart';
import 'android_folder_access.dart';
import 'native_watched_engine.dart';

/// Foreground SAF reconciliation. No filesystem paths, service, or Rust library.
class AndroidWatchedEngine implements WatchedEngine, WatchedRootNames {
  AndroidWatchedEngine({AndroidFolderAccess? access, DateTime Function()? now})
    : access = access ?? const MethodChannelAndroidFolderAccess(),
      now = now ?? _monotonicClock();
  static DateTime Function() _monotonicClock() {
    final timer = Stopwatch()..start();
    final origin = DateTime.utc(2000);
    return () => origin.add(timer.elapsed);
  }

  final AndroidFolderAccess access;
  final DateTime Function() now;
  final _watches = <int, _AndroidWatch>{};
  final _rootNames = <String, String>{};
  @override
  String? rootName(String root) => _rootNames[root];
  int _nextHandle = 1;
  static const _uuid = Uuid();

  @override
  Future<void> load() => access.available();
  @override
  Future<RootInfo> inspect(String path, List<String> forbidden) async {
    final root = await access.inspect(path);
    _rootNames[root.root] = root.name;
    return RootInfo(canonicalPath: root.root, identity: root.identity);
  }

  @override
  Future<int> start(
    String id,
    String path,
    String identity,
    bool inventory,
  ) async {
    final session = _uuid.v4();
    final rootId = await access.start(session, path, identity);
    final handle = _nextHandle++;
    _watches[handle] = _AndroidWatch(id, session, rootId, inventory);
    return handle;
  }

  _AndroidWatch _watch(int handle) =>
      _watches[handle] ?? (throw StateError('engine_stopped'));
  @override
  Future<void> ready(int handle, bool ready) async {
    final w = _watch(handle);
    if (w.ready == ready) return;
    w.ready = ready;
    if (!ready) w.epoch++;
    await access.ready(w.session, ready && !w.paused);
  }

  @override
  Future<void> pause(int handle) async {
    final w = _watch(handle);
    w.paused = true;
    w.epoch++;
    await access.ready(w.session, false);
  }

  @override
  Future<void> resume(int handle) async {
    final w = _watch(handle);
    w.paused = false;
    w.dirty = true;
    await access.ready(w.session, w.ready);
  }

  @override
  Future<void> reconcile(int handle) async {
    _watch(handle).dirty = true;
  }

  static int? limit(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'eml' => 50 * 1024 * 1024,
        'md' || 'markdown' || 'txt' => 10 * 1024 * 1024,
        'pdf' || 'png' || 'jpg' || 'jpeg' || 'webp' => 10000000,
        _ => null,
      };
  static bool _safeName(String name) =>
      name.isNotEmpty &&
      name.length <= 255 &&
      !name.startsWith('.') &&
      !name.contains(RegExp(r'[/\\\x00-\x1f\x7f]'));

  Stream<_LocatedDocument> _walk(_AndroidWatch w) async* {
    final seen = <String>{w.rootId};
    var visited = 0;
    Stream<_LocatedDocument> directory(
      String parent,
      List<String> path,
    ) async* {
      if (path.length > 64) {
        throw PlatformException(code: 'scan_limit');
      }
      int? offset = 0;
      do {
        if (w.closed) return;
        final page = await access.children(w.session, parent, offset!);
        if (page.documents.length > 64 ||
            (page.nextOffset != null && page.nextOffset! <= offset)) {
          throw PlatformException(code: 'invalid_provider_page');
        }
        for (final d in page.documents) {
          if (++visited > 100000 || d.id.length > 8192 || !seen.add(d.id)) {
            throw PlatformException(code: 'scan_limit_or_cycle');
          }
          if (!_safeName(d.name)) continue;
          if ((d.isDirectory || limit(d.name) != null) &&
              (d.partial || d.virtual)) {
            throw PlatformException(code: 'provider_document_incomplete');
          }
          final relative = [...path, d.name];
          if (d.isDirectory) {
            yield* directory(d.id, relative);
          } else if (limit(d.name) case final int maximum) {
            if (d.size == null || d.size! <= maximum) {
              yield _LocatedDocument(d, relative);
            }
          }
        }
        offset = page.nextOffset;
      } while (offset != null);
    }

    yield* directory(w.rootId, const []);
  }

  EngineEvent _event(EventKind kind, {Candidate? candidate, String? code}) =>
      EngineEvent(
        kind: kind,
        candidate: candidate,
        code: code,
        count: 0,
        generation: 1,
      );

  @override
  Future<List<EngineEvent>> events(int handle) async {
    final w = _watch(handle);
    if (!w.ready ||
        w.paused ||
        w.closed ||
        w.current != null ||
        now().isBefore(w.retryUntil)) {
      return const [];
    }
    final epoch = w.epoch;
    bool valid() => !w.closed && w.ready && !w.paused && w.epoch == epoch;
    final result = <EngineEvent>[];
    try {
      if (w.scan == null) {
        if (!w.dirty && now().isBefore(w.nextScan)) return const [];
        w.dirty = false;
        w.scanError = false;
        w.discoveryDone = false;
        w.scan = StreamIterator(_walk(w));
        result.add(_event(EventKind.scanProgress));
      }
      for (
        var i = 0;
        i < 8 && w.pending.length < 128 && !w.discoveryDone;
        i++
      ) {
        final more = await w.scan!.moveNext();
        if (!more) {
          w.discoveryDone = true;
          break;
        }
        w.pending.add(_Pending(w.scan!.current, now()));
        if (!valid()) return const [];
      }
      if (!valid()) return const [];
      final selected = <_Pending>[];
      for (
        var i = 0, count = w.pending.length;
        i < count && selected.length < 8;
        i++
      ) {
        final p = w.pending.removeFirst();
        if (now().difference(p.lastCheck) >= const Duration(seconds: 1)) {
          selected.add(p);
        } else {
          w.pending.add(p);
        }
      }
      if (selected.isNotEmpty) {
        final docs = await access.stat(
          w.session,
          selected.map((p) => p.located.document.id).toList(),
        );
        if (!valid()) {
          w.pending.addAll(selected);
          return const [];
        }
        final byId = {for (final d in docs) d.id: d};
        for (var index = 0; index < selected.length; index++) {
          final p = selected[index];
          final d = byId[p.located.document.id];
          if (d == null) {
            w.scanError = true;
            result.add(_event(EventKind.error, code: 'source_unreadable'));
            continue;
          }
          if (d.fingerprint != p.located.document.fingerprint) {
            p.located = _LocatedDocument(d, [
              ...p.located.path.take(p.located.path.length - 1),
              d.name,
            ]);
            p.since = now();
            p.observations = 1;
          } else {
            p.observations++;
          }
          p.lastCheck = now();
          if (p.observations < 3 ||
              now().difference(p.since) < const Duration(seconds: 3)) {
            w.pending.add(p);
            continue;
          }
          final maximum = limit(d.name);
          if (!_safeName(d.name) ||
              maximum == null ||
              d.isDirectory ||
              d.partial ||
              d.virtual) {
            w.scanError = true;
            continue;
          }
          final AndroidRead read;
          try {
            read = await access.read(w.session, d.id, maximum, bytes: false);
          } on PlatformException catch (e) {
            if (e.code == 'unsupported_or_oversized') {
              // A renamed binary/oversized stream is outside the supported inventory.
              continue;
            }
            if (e.code == 'source_changed') {
              p.since = now();
              p.observations = 1;
              w.pending.add(p);
              continue;
            }
            rethrow;
          }
          if (!valid()) {
            w.pending.add(p);
            w.pending.addAll(selected.skip(index + 1));
            return const [];
          }
          if (read.fingerprint != d.fingerprint) {
            p.since = now();
            p.observations = 1;
            w.pending.add(p);
            continue;
          }
          final c = Candidate(
            jobId: _uuid.v4(),
            folderId: w.folderId,
            relativePath: Uint8List.fromList(utf8.encode(d.id)),
            displayName: d.name,
            size: read.size,
            revision: read.revision,
            sha256: read.sha256,
            format: d.name.split('.').last.toLowerCase(),
            generation: 1,
            initialInventory: w.inventory,
          );
          w.current = (candidate: c, located: p.located);
          w.pending.addAll(selected.skip(index + 1));
          result.add(_event(EventKind.stableCandidate, candidate: c));
          return result;
        }
      }
      if (w.discoveryDone && w.pending.isEmpty) {
        await w.scan!.cancel();
        w.scan = null;
        w.nextScan = now().add(const Duration(seconds: 30));
        if (!w.scanError) w.inventory = false;
        result.add(
          _event(
            EventKind.scanComplete,
            code: w.scanError ? 'inventory_incomplete' : null,
          ),
        );
      }
    } catch (e) {
      // A cancelled provider enumeration cannot be reused as a complete scan.
      w.scanError = true;
      if (!valid()) {
        await w.scan?.cancel();
        w.scan = null;
        w.pending.clear();
        w.discoveryDone = false;
        w.dirty = true;
        return const [];
      }
      await w.scan?.cancel();
      w.scan = null;
      w.pending.clear();
      w.nextScan = now().add(const Duration(seconds: 30));
      result.add(
        _event(
          EventKind.error,
          code: e is PlatformException ? e.code : 'provider_io',
        ),
      );
      result.add(_event(EventKind.scanComplete, code: 'inventory_incomplete'));
    }
    return valid() ? result : const [];
  }

  @override
  Future<Uint8List> snapshot(int handle, String job) async {
    final w = _watch(handle), epoch = _watch(handle).epoch;
    final current = w.current;
    if (!w.ready ||
        w.paused ||
        current == null ||
        current.candidate.jobId != job) {
      throw StateError('stale_candidate');
    }
    final result = await access.read(
      w.session,
      current.located.document.id,
      limit(current.candidate.displayName)!,
      bytes: true,
    );
    if (w.closed ||
        !w.ready ||
        w.paused ||
        epoch != w.epoch ||
        result.sha256 != current.candidate.sha256 ||
        result.revision != current.candidate.revision ||
        result.size != current.candidate.size ||
        result.bytes?.length != result.size) {
      throw PlatformException(code: 'source_changed');
    }
    return result.bytes!;
  }

  @override
  Future<Uint8List> relatedImage(int handle, String job, String target) async {
    final w = _watch(handle), epoch = _watch(handle).epoch;
    final current = w.current;
    if (!w.ready ||
        w.paused ||
        current == null ||
        current.candidate.jobId != job) {
      throw StateError('stale_candidate');
    }
    final bytes = await access.relatedImage(
      w.session,
      current.located.path,
      target,
    );
    if (w.closed || !w.ready || w.paused || epoch != w.epoch) {
      throw PlatformException(code: 'locked');
    }
    return bytes;
  }

  @override
  Future<int> acknowledge(int handle, String job, Outcome outcome) async {
    final w = _watch(handle);
    if (w.current?.candidate.jobId == job) {
      w.current = null;
      if (outcome == Outcome.retry) {
        w.dirty = true;
        w.retryAttempts = (w.retryAttempts + 1).clamp(1, 5);
        final delay = (1 << w.retryAttempts) * 1000;
        w.retryUntil = now().add(Duration(milliseconds: delay));
        return delay;
      }
      w.retryAttempts = 0;
      w.retryUntil = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return 0;
  }

  @override
  Future<void> stop(int handle) async {
    final w = _watches.remove(handle);
    if (w == null) return;
    w.closed = true;
    w.epoch++;
    await access.stop(w.session);
    await w.scan?.cancel();
    w.pending.clear();
    w.current = null;
  }
}

class _LocatedDocument {
  const _LocatedDocument(this.document, this.path);
  final AndroidDocument document;
  final List<String> path;
}

class _Pending {
  _Pending(this.located, this.since) : lastCheck = since;
  _LocatedDocument located;
  DateTime since, lastCheck;
  int observations = 1;
}

class _AndroidWatch {
  _AndroidWatch(this.folderId, this.session, this.rootId, this.inventory);
  final String folderId, session, rootId;
  bool ready = false,
      paused = false,
      closed = false,
      dirty = true,
      inventory,
      discoveryDone = false,
      scanError = false;
  int epoch = 0, retryAttempts = 0;
  DateTime retryUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime nextScan = DateTime.fromMillisecondsSinceEpoch(0);
  StreamIterator<_LocatedDocument>? scan;
  final pending = Queue<_Pending>();
  ({Candidate candidate, _LocatedDocument located})? current;
}
