import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final phase in ['mid_stage', 'before_commit', 'after_commit']) {
    test(
      'process death at $phase recovers one canonical note and no orphan stages',
      () async {
        final root = await Directory.systemTemp.createTemp('qp-watched-crash-');
        try {
          final bytes = await File(
            'test/email_import/fixtures/mixed.eml',
          ).readAsBytes();
          final source = File('${root.path}/source.eml');
          await source.writeAsBytes(bytes, flush: true);
          Future<ProcessResult> run(String action) => Process.run(
            'flutter',
            [
              'test',
              '--no-pub',
              '--concurrency=1',
              '--reporter=expanded',
              'test/watched_import/watched_import_crash_child_test.dart',
              '--plain-name',
              'watched crash child',
            ],
            environment: {
              'QP_WATCHED_CRASH_ROOT': root.path,
              'QP_WATCHED_CRASH_PHASE': action,
            },
          );
          final crashed = await run(phase);
          expect(
            crashed.exitCode,
            isNot(0),
            reason: 'child must actually terminate',
          );
          final recovered = await run('recover');
          expect(
            recovered.exitCode,
            0,
            reason: '${recovered.stdout}\n${recovered.stderr}',
          );
          expect(recovered.stdout, contains('QP_WATCHED_CRASH_RECOVERY_OK'));
          final replay = await run('recover');
          expect(
            replay.exitCode,
            0,
            reason: '${replay.stdout}\n${replay.stderr}',
          );
          expect(await source.readAsBytes(), orderedEquals(bytes));
        } finally {
          await root.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 6)),
    );
  }
}
