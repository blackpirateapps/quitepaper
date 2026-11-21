import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/security/sensitive_preview_registry.dart';
import '../../email_import/domain/email_message.dart';
import '../data/watched_import_repository.dart';
import '../domain/watched_file_type.dart';
import '../native/api/engine.dart';
import 'canonical_import_adapter.dart';
import 'native_watched_engine.dart';

class WatchedImportController extends ChangeNotifier {
  WatchedImportController({
    required this.store,
    required this.engine,
    required this.importer,
    required this.scope,
    required this.isUnlocked,
    required this.forbiddenPaths,
    required this.onImported,
    this.isScopeCurrent,
    this.prepareVault,
  }) {
    SensitivePreviewRegistry.revision.addListener(_securityChanged);
  }
  final WatchedImportRepositoryAdapter store;
  final WatchedEngine engine;
  final CanonicalImportAdapter importer;
  final Future<String> Function() scope;
  final bool Function() isUnlocked;
  final Future<List<String>> Function() forbiddenPaths;
  final Future<void> Function() onImported;
  final bool Function(String scope)? isScopeCurrent;
  final Future<void> Function()? prepareVault;
  List<QueryRow> folders = const [];
  // Single-folder defaults keep diagnostic tools compatible.
  QueryRow? get configuration => folders.firstOrNull;
  List<QueryRow> history = const [];
  String health = 'Paused';
  String? error;
  bool busy = false;
  int get scanned =>
      configuration == null ? 0 : countFor(configuration!.read<String>('id'));
  int get bytes =>
      configuration == null ? 0 : bytesFor(configuration!.read<String>('id'));
  final _handles = <String, int>{};
  final _starting = <String, Future<void>>{};
  final _health = <String, String>{};
  final _errors = <String, String?>{};
  final _counts = <String, int>{};
  final _bytes = <String, int>{};
  final _epochs = <String, int>{};
  final _changing = <String>{};
  final _degraded = <String>{};
  Timer? _timer;
  bool _disposed = false;
  bool _closed = false;
  bool _foreground = true;
  Future<void>? _pollTask;
  bool _polling = false;
  int _epoch = 0;
  Future<void>? _active;
  Future<void>? _initializing;

  QueryRow? folderFor(String id) =>
      folders.where((f) => f.read<String>('id') == id).firstOrNull;
  String healthFor(String id) => _health[id] ?? 'Paused';
  String? errorFor(String id) => _errors[id];
  int countFor(String id) => _counts[id] ?? 0;
  int bytesFor(String id) => _bytes[id] ?? 0;
  bool changing(String id) => _changing.contains(id);
  void _invalidate(String id) => _epochs[id] = (_epochs[id] ?? 0) + 1;
  void _status(String id, String value, [String? code]) {
    _health[id] = value;
    _errors[id] = code;
    health = value;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _securityChanged() {
    _epoch++;
    history = const [];
    health = 'Needs unlock';
    for (final entry in _handles.entries) {
      _health[entry.key] = folderFor(entry.key)?.read<int>('enabled') == 0
          ? 'Paused'
          : 'Needs unlock';
      unawaited(engine.ready(entry.value, false).catchError((Object _) {}));
    }
    _notify();
  }

  void accountChanged() {
    _securityChanged();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      folders = await store.folders();
      if (folders.isNotEmpty) {
        await prepareVault?.call();
        await importer.recover();
      }
      for (final prior in folders) {
        final id = prior.read<String>('id');
        if (prior.read<String>('review_state') == 'pending' &&
            prior.read<int>('inventory_complete') == 0) {
          final seen = await store.rows(
            'SELECT 1 FROM watched_import_baseline WHERE folder_id=? LIMIT 1',
            [id],
          );
          if (seen.isNotEmpty) {
            await store.write(
              "UPDATE watched_folders SET inventory_error='review_interrupted' WHERE id=?",
              [id],
            );
            _errors[id] = 'review_interrupted';
          }
        }
        await _start(prior);
      }
      await refresh();
    } catch (e) {
      error = e is PlatformException
          ? e.code
          : engine is NativeWatchedEngine
          ? 'native_unavailable_or_incompatible'
          : 'folder_access_or_native_unavailable';
      health = 'Unavailable';
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    final epoch = _epoch;
    final loaded = await store.folders();
    final activeScope = await scope();
    final events = await store.history(activeScope);
    if (_disposed) return;
    folders = loaded;
    // Do not repopulate sensitive history after a lock/account change.
    history =
        epoch == _epoch &&
            isUnlocked() &&
            (isScopeCurrent?.call(activeScope) ?? true)
        ? events
        : const [];
    for (final f in loaded) {
      final id = f.read<String>('id');
      final extensions = WatchedFileType.decode(
        f.read<String>('file_types'),
      ).expand((type) => type.extensions).toList();
      if (extensions.isEmpty) {
        _counts[id] = 0;
        _bytes[id] = 0;
        continue;
      }
      final counts = (await store.rows(
        """SELECT COUNT(*) AS count, COALESCE(SUM(b.size),0) AS bytes
        FROM watched_import_baseline b JOIN watched_import_jobs j
        ON j.folder_id=b.folder_id AND j.source_path=b.source_path AND j.revision=b.revision
        WHERE b.folder_id=? AND j.override_id='' AND j.format IN (${List.filled(extensions.length, '?').join(',')})""",
        [id, ...extensions],
      )).single;
      _counts[id] = counts.read<int>('count');
      _bytes[id] = counts.read<int>('bytes');
    }
    _notify();
  }

  Future<void> enroll(String path) async {
    if (busy) return;
    busy = true;
    error = null;
    _notify();
    try {
      await initialize();
      await engine.load();
      final root = await engine.inspect(path, await forbiddenPaths());
      final id = await store.enroll(
        root,
        await scope(),
        displayName: engine is WatchedRootNames
            ? (engine as WatchedRootNames).rootName(root.canonicalPath)
            : null,
      );
      await prepareVault?.call();
      // Recovery must never run alongside a canonical import.
      if (_handles.isEmpty) {
        await _active;
        await importer.recover();
      }
      await refresh();
      await _start((await store.folder(id))!);
    } catch (e) {
      error = e is StateError && e.message == 'folder_already_watched'
          ? 'folder_already_watched'
          : e is PlatformException
          ? e.code
          : 'folder_access_or_native_unavailable';
    } finally {
      busy = false;
      await refresh();
    }
  }

  Future<void> _start(QueryRow f) {
    final id = f.read<String>('id');
    return _starting[id] ??= _startFolder(f).whenComplete(() {
      _starting.remove(id);
    });
  }

  Future<void> _startFolder(QueryRow f) async {
    if (_disposed || _closed) return;
    final epoch = _epochs[f.read<String>('id')] ?? 0;
    final id = f.read<String>('id');
    if (_handles.containsKey(id)) return;
    if (f.read<String>('vault_scope') != await scope()) {
      _status(id, 'Paused', 'account_changed_select_folder_again');
      return;
    }
    if (f.read<int>('enabled') == 0) {
      _status(id, 'Paused');
      return;
    }
    try {
      await engine.load();
      final handle = await engine.start(
        id,
        f.read<String>('canonical_root'),
        f.read<String>('root_identity'),
        f.read<String>('review_state') == 'pending' &&
            f.read<int>('inventory_complete') == 0,
      );
      if (_disposed || _closed || epoch != (_epochs[id] ?? 0)) {
        await engine.stop(handle);
        return;
      }
      _handles[id] = handle;
      _status(id, isUnlocked() ? 'Scanning' : 'Needs unlock', _errors[id]);
      _timer ??= Timer.periodic(const Duration(milliseconds: 150), (_) {
        if (!_polling) {
          _pollTask = _poll();
          unawaited(_pollTask);
        }
      });
    } catch (e) {
      _status(
        id,
        'Unavailable',
        e is PlatformException ? e.code : 'folder_access_or_native_unavailable',
      );
    }
  }

  Future<void> _poll() async {
    if (_disposed || _closed || !_foreground || _polling || _handles.isEmpty) {
      return;
    }
    _polling = true;
    try {
      for (final entry in _handles.entries.toList()) {
        if (_disposed || _closed) break;
        final id = entry.key;
        final handle = entry.value;
        try {
          final f = await store.folder(id);
          if (f == null || f.read<String>('vault_scope') != await scope()) {
            await _stopFolder(id);
            _status(id, 'Paused', 'account_changed_select_folder_again');
            error = 'account_changed_select_folder_again';
            continue;
          }
          if (f.read<int>('enabled') == 0 || changing(id)) continue;
          final ready = isUnlocked();
          await engine.ready(handle, ready);
          if (!ready) {
            if (healthFor(id) != 'Needs unlock') _status(id, 'Needs unlock');
            continue;
          }
          for (final event in await engine.events(handle)) {
            if (_disposed || _closed || _handles[id] != handle) break;
            if (event.kind == EventKind.stableCandidate &&
                event.candidate != null) {
              _active = _candidate(handle, event.candidate!);
              await _active;
              _active = null;
            } else if (event.kind == EventKind.scanComplete) {
              await store.inventoryDone(id, event.code);
              final updated = await store.folder(id);
              final code =
                  updated?.readNullable<String>('inventory_error') ??
                  event.code;
              _status(
                id,
                code != null
                    ? 'Needs attention'
                    : _degraded.contains(id)
                    ? 'Degraded'
                    : 'Watching',
                code,
              );
              await refresh();
            } else if (event.kind == EventKind.watchDegraded) {
              _degraded.add(id);
              _status(id, 'Degraded', event.code);
            } else if (event.kind == EventKind.rootUnavailable) {
              _status(id, 'Unavailable', event.code);
            } else if (event.kind == EventKind.error) {
              _status(id, 'Needs attention', event.code);
              if (f.read<String>('review_state') == 'pending' &&
                  event.code != 'unsupported_or_oversized') {
                await store.inventoryDone(id, 'inventory_incomplete');
              }
            } else if (event.kind == EventKind.scanProgress) {
              _status(id, 'Scanning');
            }
          }
        } catch (_) {
          _status(id, 'Needs attention', 'watch_operation_failed');
        }
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> _candidate(int handle, Candidate c) async {
    final epoch = _epoch;
    final folderEpoch = _epochs[c.folderId] ?? 0;
    bool current() =>
        !_disposed &&
        !_closed &&
        _foreground &&
        epoch == _epoch &&
        handle == _handles[c.folderId] &&
        folderEpoch == (_epochs[c.folderId] ?? 0) &&
        !changing(c.folderId) &&
        isUnlocked() &&
        folderFor(c.folderId)?.read<int>('enabled') == 1 &&
        (isScopeCurrent?.call(
              folderFor(c.folderId)!.read<String>('vault_scope'),
            ) ??
            true);
    var outcome = Outcome.complete;
    QueryRow? job;
    try {
      final f = await store.folder(c.folderId);
      if (f == null || f.read<String>('id') != c.folderId) return;
      final activeScope = await scope();
      if (f.read<String>('vault_scope') != activeScope || !current()) {
        outcome = Outcome.retry;
        return;
      }
      // Baseline all supported types, so Only New remains valid if types change later.
      if (f.read<String>('review_state') == 'pending' && c.initialInventory) {
        await store.baseline(c, f);
      }
      if (f.read<String>('review_state') != 'pending' &&
          !WatchedFileType.allows(f.read<String>('file_types'), c.format)) {
        return;
      }
      final overrides = await store.rows(
        "SELECT * FROM watched_import_jobs WHERE folder_id=? AND source_path=? AND sha256=? AND override_id<>'' AND status='ready' ORDER BY created_at LIMIT 1",
        [c.folderId, c.relativePath, c.sha256],
      );
      job = overrides.firstOrNull ?? await store.reserve(c, activeScope);
      final jobId = job.read<String>('id');
      final override = job.read<String>('override_id').isNotEmpty;
      if (watchedTerminalStatuses.contains(job.read<String>('status'))) return;
      if (f.read<String>('review_state') == 'pending') {
        await store.transition(jobId, 'awaiting_review', event: false);
        await refresh();
        return;
      }
      if (!override && await store.receipt(activeScope, c) != null) {
        await store.transition(jobId, 'duplicate_skipped');
        await refresh();
        return;
      }
      if (!override &&
          f.read<String>('existing_policy') == 'only_new' &&
          await store.isBaseline(c)) {
        await store.transition(jobId, 'baseline_skipped', event: false);
        return;
      }
      if (!current()) {
        outcome = Outcome.retry;
        return;
      }
      await store.transition(jobId, 'importing', event: false);
      final snapshotBytes = await engine.snapshot(handle, c.jobId);
      await importer.import(
        c,
        job,
        snapshotBytes,
        isCurrent: current,
        readRelatedImage: (target) =>
            engine.relatedImage(handle, c.jobId, target),
      );
      try {
        await onImported();
      } catch (_) {
        /* Durable note remains dirty for sync. */
      }
      await refresh();
    } catch (e) {
      final code = e is EmailImportException
          ? e.code
          : e is PlatformException
          ? e.code
          : 'import_failed';
      if (job != null) {
        final attempts = job.read<int>('attempt_count');
        final retry =
            const {
              'busy',
              'locked',
              'source_changed',
              'import_failed',
              'provider_io',
            }.contains(code) &&
            attempts < 5;
        final status = code == 'message_id_changed'
            ? 'needs_attention'
            : code == 'locked'
            ? 'waiting_for_unlock'
            : retry
            ? 'retry_scheduled'
            : 'failed';
        await store.transition(job.read<String>('id'), status, code: code);
        outcome = retry ? Outcome.retry : Outcome.needsAttention;
      } else {
        outcome = Outcome.retry;
      }
      if (epoch == _epoch && folderEpoch == (_epochs[c.folderId] ?? 0)) {
        _errors[c.folderId] = code;
      }
      await refresh();
    } finally {
      if (!_disposed && handle == _handles[c.folderId]) {
        final delay = await engine.acknowledge(handle, c.jobId, outcome);
        if (job != null && delay > 0) {
          await store.write(
            "UPDATE watched_import_jobs SET next_retry=? WHERE id=? AND status IN ('retry_scheduled','waiting_for_unlock')",
            [store.now + delay, job.read<String>('id')],
          );
        }
      }
    }
  }

  Future<void> decide(bool existing, [String? folderId]) async {
    final id = folderId ?? configuration?.read<String>('id');
    if (id == null || busy) return;
    busy = true;
    _notify();
    try {
      await store.decide(id, existing);
      await rescan(id);
    } catch (_) {
      _status(id, 'Needs attention', 'inventory_incomplete');
    } finally {
      busy = false;
      await refresh();
    }
  }

  Future<void> _change(String id, Future<void> Function() action) async {
    if (!_changing.add(id)) return;
    _invalidate(id);
    _notify();
    try {
      await action();
    } catch (_) {
      _status(id, 'Needs attention', 'watch_operation_failed');
    } finally {
      await refresh();
      _changing.remove(id);
      _notify();
    }
  }

  Future<void> pause([String? folderId]) async {
    final id = folderId ?? configuration?.read<String>('id');
    if (id == null) return;
    await _change(id, () async {
      await store.write(
        'UPDATE watched_folders SET enabled=0,updated_at=? WHERE id=?',
        [store.now, id],
      );
      final handle = _handles[id];
      if (handle != null) await engine.pause(handle);
      _status(id, 'Paused');
    });
  }

  Future<void> resume([String? folderId]) async {
    final id = folderId ?? configuration?.read<String>('id');
    if (id == null) return;
    await _change(id, () async {
      final f = await store.folder(id);
      if (f == null) return;
      if (f.read<String>('vault_scope') != await scope()) {
        _status(id, 'Paused', 'account_changed_select_folder_again');
        return;
      }
      await store.write(
        'UPDATE watched_folders SET enabled=1,updated_at=? WHERE id=?',
        [store.now, id],
      );
      if (_handles[id] == null) {
        await _start((await store.folder(id))!);
      } else {
        await engine.resume(_handles[id]!);
        _status(id, 'Scanning');
      }
    });
  }

  Future<void> setFileTypes(String id, Set<WatchedFileType> types) =>
      _change(id, () async {
        await store.setFileTypes(id, types);
        final f = await store.folder(id);
        if (f?.read<String>('review_state') == 'accepted') await rescan(id);
      });

  Future<void> rescan([String? folderId]) async {
    final id = folderId ?? configuration?.read<String>('id');
    if (id == null) return;
    try {
      final f = await store.folder(id);
      if (f == null || f.read<int>('enabled') == 0) return;
      if (_handles[id] == null) {
        await _start(f);
      } else {
        await engine.reconcile(_handles[id]!);
        _status(id, 'Scanning');
      }
    } catch (_) {
      _status(id, 'Needs attention', 'watch_operation_failed');
    }
  }

  /// Mobile suspends provider work and late commits when it leaves the foreground.
  Future<void> setForeground(bool value) async {
    if (_foreground == value || _closed || _disposed) return;
    _foreground = value;
    if (!value) {
      _epoch++;
      for (final entry in _handles.entries.toList()) {
        try {
          await engine.ready(entry.value, false);
        } catch (_) {
          // A folder may have been removed while the lifecycle event was pending.
        }
      }
    } else {
      await rescanAll();
    }
  }

  Future<void> rescanAll() async {
    for (final f in folders.toList()) {
      await rescan(f.read<String>('id'));
    }
  }

  Future<void> remove([String? folderId]) async {
    final id = folderId ?? configuration?.read<String>('id');
    if (id == null) return;
    await _change(id, () async {
      // Cancel this folder's in-flight commit before touching its jobs.
      await _active;
      await _stopFolder(id);
      await store.removeFolder(id);
      _health.remove(id);
      _errors.remove(id);
      _counts.remove(id);
      _bytes.remove(id);
      _degraded.remove(id);
    });
  }

  Future<void> retry(String id) async {
    await store.retry(id);
    final job = (await store.rows(
      'SELECT folder_id FROM watched_import_jobs WHERE id=?',
      [id],
    )).single;
    await rescan(job.read<String>('folder_id'));
    await refresh();
  }

  Future<void> importAgain(String id) async {
    final row = (await store.rows(
      'SELECT * FROM watched_import_jobs WHERE id=?',
      [id],
    )).single;
    await store.write(
      '''INSERT INTO watched_import_jobs
      (id,folder_id,vault_scope,source_path,source_root,display_name,revision,size,sha256,format,status,
      planned_note_id,generation,override_id,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,'ready',?,?,?,?,?)''',
      [
        WatchedImportRepositoryAdapter.uuid.v4(),
        row.read<String>('folder_id'),
        row.read<String>('vault_scope'),
        row.read<Uint8List>('source_path'),
        row.read<String>('source_root'),
        row.read<String>('display_name'),
        row.read<String>('revision'),
        row.read<int>('size'),
        row.read<String>('sha256'),
        row.read<String>('format'),
        WatchedImportRepositoryAdapter.uuid.v4(),
        0,
        WatchedImportRepositoryAdapter.uuid.v4(),
        store.now,
        store.now,
      ],
    );
    await rescan(row.read<String>('folder_id'));
    await refresh();
  }

  Future<void> _stopFolder(String id) async {
    final handle = _handles.remove(id);
    if (handle != null) await engine.stop(handle);
    if (_handles.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    for (final id in _handles.keys.toList()) {
      await _stopFolder(id);
    }
  }

  Future<void> close() async {
    _closed = true;
    _epoch++;
    await Future.wait(_starting.values.toList());
    await _stop();
    await _pollTask;
    await _active;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    SensitivePreviewRegistry.revision.removeListener(_securityChanged);
    unawaited(_stop());
    super.dispose();
  }
}
