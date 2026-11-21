import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:path/path.dart' as p;
import '../native/api/engine.dart' as native;
import '../native/frb_generated.dart';

abstract class WatchedEngine {
  Future<void> load();
  Future<native.RootInfo> inspect(String path, List<String> forbidden);
  Future<int> start(String id, String path, String identity, bool inventory);
  Future<void> ready(int handle, bool ready);
  Future<List<native.EngineEvent>> events(int handle);
  Future<Uint8List> snapshot(int handle, String job);
  Future<Uint8List> relatedImage(int handle, String job, String target);
  Future<int> acknowledge(int handle, String job, native.Outcome outcome);
  Future<void> pause(int handle);
  Future<void> resume(int handle);
  Future<void> reconcile(int handle);
  Future<void> stop(int handle);
}

class NativeWatchedEngine implements WatchedEngine {
  static Future<void>? _loading;
  @override
  Future<void> load() async {
    try {
      await (_loading ??= RustLib.init(
        externalLibrary: ExternalLibrary.open(
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'lib',
            'libquietpaper_watched_import.so',
          ),
        ),
      ));
      if (native.contractVersion() != 2) {
        throw StateError('native_contract_incompatible');
      }
    } catch (_) {
      _loading = null;
      rethrow;
    }
  }

  @override
  Future<native.RootInfo> inspect(String path, List<String> forbidden) =>
      native.inspectRoot(rootPath: path, forbiddenPaths: forbidden);
  @override
  Future<int> start(String id, String path, String identity, bool inventory) =>
      native.initializeWatchedImportEngine(
        folderId: id,
        rootPath: path,
        expectedIdentity: identity,
        initialInventory: inventory,
        forcePoll: false,
      );
  @override
  Future<void> ready(int handle, bool ready) =>
      native.setVaultReady(handle: handle, ready: ready);
  @override
  Future<List<native.EngineEvent>> events(int handle) =>
      native.drainEvents(handle: handle);
  @override
  Future<Uint8List> snapshot(int handle, String job) =>
      native.readCandidateSnapshot(handle: handle, jobId: job);
  @override
  Future<Uint8List> relatedImage(int handle, String job, String target) =>
      native.readRelatedImageSnapshot(
        handle: handle,
        jobId: job,
        target: target,
      );
  @override
  Future<int> acknowledge(int handle, String job, native.Outcome outcome) =>
      native.submitImportOutcome(handle: handle, jobId: job, outcome: outcome);
  @override
  Future<void> pause(int handle) => native.pauseWatch(handle: handle);
  @override
  Future<void> resume(int handle) => native.resumeWatch(handle: handle);
  @override
  Future<void> reconcile(int handle) => native.reconcileNow(handle: handle);
  @override
  Future<void> stop(int handle) => native.shutdownWatch(handle: handle);
}
