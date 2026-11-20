import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import '../../../core/security/sensitive_preview_registry.dart';
import '../../email_import/domain/email_message.dart';
import '../data/watched_import_repository.dart';
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
  QueryRow? configuration;
  List<QueryRow> history = const [];
  String health = 'Paused';
  String? error;
  bool busy = false;
  int scanned = 0;
  int bytes = 0;
  int? _handle;
  Timer? _timer;
  bool _disposed = false;
  bool _polling = false;
  bool _degraded = false;
  int _epoch = 0;
  Future<void>? _active;
  Future<void>? _initializing;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _securityChanged() {
    _epoch++;
    health = 'Needs unlock';
    final handle = _handle;
    if (handle != null) {
      unawaited(engine.ready(handle, false).catchError((Object _) {}));
    }
    _notify();
  }

  void accountChanged() {
    _securityChanged();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      configuration = await store.folder();
      if (configuration == null) {
        _notify();
        return;
      }
      await prepareVault?.call();
      await importer.recover();
      await _start();
      await refresh();
    } catch (_) {
      error = 'native_unavailable_or_incompatible';
      health = 'Unavailable';
      _notify();
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    configuration = await store.folder();
    if (configuration != null) {
      final counts = (await store.rows(
        'SELECT COUNT(*) AS count, COALESCE(SUM(size),0) AS bytes FROM watched_import_baseline WHERE folder_id=?',
        [configuration!.read<String>('id')],
      )).single;
      scanned = counts.read<int>('count');
      bytes = counts.read<int>('bytes');
    }
    history = await store.history(await scope());
    _notify();
  }

  Future<void> enroll(String path) async {
    if (busy || _handle != null) return;
    busy = true;
    error = null;
    _notify();
    try {
      await engine.load();
      final root = await engine.inspect(path, await forbiddenPaths());
      await store.enroll(root, await scope());
      configuration = await store.folder();
      await prepareVault?.call();
      await importer.recover();
      scanned = 0;
      bytes = 0;
      await _start();
    } catch (_) {
      error = 'folder_access_or_native_unavailable';
      health = 'Unavailable';
    } finally {
      busy = false;
      await refresh();
    }
  }

  Future<void> _start() async {
    final f = configuration;
    if (f == null) return;
    if (f.read<String>('vault_scope') != await scope()) {
      health = 'Paused';
      error = 'account_changed_select_folder_again';
      return;
    }
    if (f.read<int>('enabled') == 0) {
      health = 'Paused';
      return;
    }
    await engine.load();
    final handle = await engine.start(
      f.read<String>('id'),
      f.read<String>('canonical_root'),
      f.read<String>('root_identity'),
      f.read<String>('review_state') == 'pending' &&
          f.read<int>('inventory_complete') == 0,
    );
    if (_disposed) {
      await engine.stop(handle);
      return;
    }
    _handle = handle;
    health = isUnlocked() ? 'Scanning' : 'Needs unlock';
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      unawaited(_poll());
    });
  }

  Future<void> _poll() async {
    if (_disposed || _polling || _handle == null) return;
    _polling = true;
    final handle = _handle!;
    try {
      final f = await store.folder();
      if (f == null || f.read<String>('vault_scope') != await scope()) {
        await _stop();
        configuration = f;
        health = 'Paused';
        error = 'account_changed_select_folder_again';
        _notify();
        return;
      }
      configuration = f;
      if (f.read<int>('enabled') == 0) {
        return;
      }
      final ready = isUnlocked();
      await engine.ready(handle, ready);
      if (!ready) {
        if (health != 'Needs unlock') {
          health = 'Needs unlock';
          _notify();
        }
        return;
      }
      for (final event in await engine.events(handle)) {
        if (_disposed || handle != _handle) break;
        if (event.kind == EventKind.stableCandidate &&
            event.candidate != null) {
          final candidate = event.candidate!;
          _active = _candidate(handle, candidate);
          await _active;
          _active = null;
        } else if (event.kind == EventKind.scanComplete) {
          await store.inventoryDone(f.read<String>('id'), event.code);
          if (event.code != null) {
            health = 'Needs attention';
            error = event.code;
          } else {
            health = _degraded ? 'Degraded' : 'Watching';
          }
          await refresh();
        } else if (event.kind == EventKind.watchDegraded) {
          _degraded = true;
          health = 'Degraded';
          error = event.code;
          _notify();
        } else if (event.kind == EventKind.rootUnavailable) {
          health = 'Unavailable';
          error = event.code;
          _notify();
        } else if (event.kind == EventKind.error) {
          error = event.code;
          health = 'Needs attention';
          if (f.read<String>('review_state') == 'pending' &&
              event.code != 'unsupported_or_oversized') {
            await store.inventoryDone(
              f.read<String>('id'),
              'inventory_incomplete',
            );
          }
          _notify();
        } else if (event.kind == EventKind.scanProgress) {
          health = 'Scanning';
          _notify();
        }
      }
    } catch (_) {
      health = 'Needs attention';
      error = 'watch_operation_failed';
      _notify();
    } finally {
      _polling = false;
    }
  }

  Future<void> _candidate(int handle, Candidate c) async {
    final epoch = _epoch;
    bool current() =>
        !_disposed &&
        epoch == _epoch &&
        handle == _handle &&
        isUnlocked() &&
        configuration?.read<int>('enabled') == 1 &&
        (isScopeCurrent?.call(configuration!.read<String>('vault_scope')) ??
            true);
    var outcome = Outcome.complete;
    QueryRow? job;
    try {
      final f = await store.folder();
      if (f == null || f.read<String>('id') != c.folderId) return;
      final activeScope = await scope();
      if (f.read<String>('vault_scope') != activeScope || !current()) {
        outcome = Outcome.retry;
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
        if (c.initialInventory) {
          await store.baseline(c, f);
          scanned++;
          bytes += c.size;
        }
        await store.transition(jobId, 'awaiting_review', event: false);
        _notify();
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
      await importer.import(c, job, snapshotBytes, isCurrent: current);
      try {
        await onImported();
      } catch (_) {
        /* Durable note remains dirty for sync. */
      }
      await refresh();
    } catch (e) {
      final code = e is EmailImportException ? e.code : 'import_failed';
      if (job != null) {
        final attempts = job.read<int>('attempt_count');
        final retry =
            const {
              'busy',
              'locked',
              'source_changed',
              'import_failed',
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
      error = code;
      await refresh();
    } finally {
      if (!_disposed && handle == _handle) {
        await engine.acknowledge(handle, c.jobId, outcome);
      }
    }
  }

  Future<void> decide(bool existing) async {
    final f = configuration;
    if (f == null) return;
    busy = true;
    _notify();
    try {
      await store.decide(f.read<String>('id'), existing);
      await rescan();
    } catch (_) {
      error = 'inventory_incomplete';
    } finally {
      busy = false;
      await refresh();
    }
  }

  Future<void> pause() async {
    _epoch++;
    final handle = _handle;
    if (handle != null) await engine.pause(handle);
    await store.write('UPDATE watched_folders SET enabled=0');
    health = 'Paused';
    await refresh();
  }

  Future<void> resume() async {
    await store.write('UPDATE watched_folders SET enabled=1');
    if (_handle == null) {
      configuration = await store.folder();
      await _start();
    } else {
      await engine.resume(_handle!);
    }
    health = 'Scanning';
    await refresh();
  }

  Future<void> rescan() async {
    final h = _handle;
    if (h == null || configuration?.read<int>('enabled') == 0) return;
    await engine.reconcile(h);
    health = 'Scanning';
    _notify();
  }

  Future<void> remove() async {
    _epoch++;
    await _stop();
    await _active;
    await importer.recover();
    await store.removeFolder();
    configuration = null;
    health = 'Paused';
    error = null;
    await refresh();
  }

  Future<void> retry(String id) async {
    await store.retry(id);
    await rescan();
    await refresh();
  }

  Future<void> importAgain(String id) async {
    final row = (await store.rows(
      'SELECT * FROM watched_import_jobs WHERE id=?',
      [id],
    )).single;
    await store.write(
      '''INSERT INTO watched_import_jobs
      (id,folder_id,vault_scope,source_path,display_name,revision,size,sha256,format,status,
      planned_note_id,generation,override_id,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,'ready',?,?,?,?,?)''',
      [
        WatchedImportRepositoryAdapter.uuid.v4(),
        row.read<String>('folder_id'),
        row.read<String>('vault_scope'),
        row.read<Uint8List>('source_path'),
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
    await rescan();
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    final handle = _handle;
    _handle = null;
    if (handle != null) await engine.stop(handle);
  }

  Future<void> close() async {
    _epoch++;
    await _stop();
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
