import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:quitepaper/features/watched_import/native/frb_generated.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';

/// Loads a specific bundled ELF through the real generated FRB interface.
/// Only creates synthetic sources under a private temporary directory.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/smoke_watched_import.dart /absolute/library.so',
    );
    exitCode = 64;
    return;
  }
  await RustLib.init(
    externalLibrary: ExternalLibrary.open(File(args.single).absolute.path),
  );
  if (contractVersion() != 2) throw StateError('native_contract_incompatible');
  final dir = await Directory.systemTemp.createTemp('qp-native-smoke-');
  int? handle;
  try {
    final file = File('${dir.path}/smoke.txt');
    await file.writeAsString('Quiet Paper synthetic smoke');
    final root = await inspectRoot(rootPath: dir.path, forbiddenPaths: []);
    handle = await initializeWatchedImportEngine(
      folderId: 'smoke',
      rootPath: root.canonicalPath,
      expectedIdentity: root.identity,
      initialInventory: true,
      forcePoll: false,
    );
    await setVaultReady(handle: handle, ready: true);
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    var found = false;
    while (DateTime.now().isBefore(deadline) && !found) {
      for (final event in await drainEvents(handle: handle)) {
        final c = event.candidate;
        if (c == null) continue;
        final bytes = await readCandidateSnapshot(
          handle: handle,
          jobId: c.jobId,
        );
        if (String.fromCharCodes(bytes) != 'Quiet Paper synthetic smoke') {
          throw StateError('snapshot_mismatch');
        }
        await submitImportOutcome(
          handle: handle,
          jobId: c.jobId,
          outcome: Outcome.complete,
        );
        found = true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!found) throw StateError('native_candidate_timeout');
    if (await file.readAsString() != 'Quiet Paper synthetic smoke') {
      throw StateError('source_mutated');
    }
    stdout.writeln(
      'PASS: FRB contract 2, recursive engine, verified snapshot, ACK, untouched source',
    );
  } finally {
    if (handle != null) await shutdownWatch(handle: handle);
    await dir.delete(recursive: true);
    RustLib.dispose();
  }
}
