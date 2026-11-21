import 'dart:convert';
import 'dart:io';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:quitepaper/features/watched_import/native/frb_generated.dart';
import 'package:quitepaper/features/watched_import/native/api/engine.dart';

/// Synthetic native-engine acceptance benchmark; never reads a real user vault.
Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError('Pass an absolute native library path.');
  }
  await RustLib.init(
    externalLibrary: ExternalLibrary.open(File(args.single).absolute.path),
  );
  final root = await Directory.systemTemp.createTemp('qp-watched-benchmark-');
  int? handle;
  int fdCount() => Directory('/proc/self/fd').listSync().length;
  int rss() {
    final line = File(
      '/proc/self/status',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('VmRSS:'));
    return int.parse(RegExp(r'\d+').firstMatch(line)![0]!);
  }

  try {
    final info = await inspectRoot(rootPath: root.path, forbiddenPaths: []);
    await File('${root.path}/.warmup.part').writeAsString('warmup');
    final baselineFds = fdCount();
    final baselineRss = rss();
    var maxRss = baselineRss;
    handle = await initializeWatchedImportEngine(
      folderId: 'benchmark',
      rootPath: info.canonicalPath,
      expectedIdentity: info.identity,
      initialInventory: false,
      forcePoll: false,
    );
    final burst = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await File(
        '${root.path}/file-$i.txt',
      ).writeAsString('Synthetic watched-import fixture $i');
    }
    burst.stop();
    await setVaultReady(handle: handle, ready: true);
    final timer = Stopwatch()..start();
    var count = 0;
    var maxBatch = 0;
    final hashes = <String>{};
    while (count < 1000) {
      if (timer.elapsed > const Duration(minutes: 5)) {
        throw StateError('benchmark deadline');
      }
      final events = await drainEvents(handle: handle);
      if (events.length > maxBatch) maxBatch = events.length;
      for (final event in events) {
        final c = event.candidate;
        if (c == null) continue;
        if (!hashes.add(c.sha256)) {
          throw StateError('unexpected same-scan replay');
        }
        await readCandidateSnapshot(handle: handle, jobId: c.jobId);
        await submitImportOutcome(
          handle: handle,
          jobId: c.jobId,
          outcome: Outcome.complete,
        );
        count++;
      }
      final resident = rss();
      if (resident > maxRss) maxRss = resident;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    timer.stop();
    await shutdownWatch(handle: handle);
    handle = null;
    final startupMs = <int>[];
    final restartFds = <int>[];
    for (var cycle = 0; cycle < 5; cycle++) {
      final time = Stopwatch()..start();
      handle = await initializeWatchedImportEngine(
        folderId: 'benchmark',
        rootPath: info.canonicalPath,
        expectedIdentity: info.identity,
        initialInventory: false,
        forcePoll: false,
      );
      await setVaultReady(handle: handle, ready: true);
      var seen = false;
      while (!seen) {
        if (time.elapsed > const Duration(seconds: 20)) {
          throw StateError('startup deadline');
        }
        for (final event in await drainEvents(handle: handle)) {
          if (event.candidate != null) {
            seen = true;
            break;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      await shutdownWatch(handle: handle);
      handle = null;
      time.stop();
      startupMs.add(time.elapsedMilliseconds);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      restartFds.add(fdCount());
    }
    final afterFds = fdCount();
    if (afterFds > baselineFds + 2) throw StateError('native descriptor leak');
    stdout.writeln(
      jsonEncode({
        'measurement':
            'actual native engine and FRB; synthetic files; no canonical note conversion',
        'files': count,
        'create_1000_event_burst_ms': burst.elapsedMilliseconds,
        'stabilize_hash_snapshot_ack_ms': timer.elapsedMilliseconds,
        'max_event_batch': maxBatch,
        'baseline_rss_kib': baselineRss,
        'peak_sampled_rss_kib': maxRss,
        'fds_before': baselineFds,
        'fds_after': afterFds,
        'fds_after_each_restart': restartFds,
        'five_restart_to_first_candidate_ms': startupMs,
      }),
    );
  } finally {
    if (handle != null) await shutdownWatch(handle: handle);
    await root.delete(recursive: true);
    RustLib.dispose();
  }
}
