import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:quitepaper/features/email_import/application/email_parser.dart';

// Synthetic messages only. Run: dart run tool/email_import_benchmark.dart
// RSS values belong to the whole Dart VM; this is a Linux/JIT observation,
// not a mobile benchmark or a per-isolate heap profiler.
Future<void> main() async {
  const parser = EmailParser();
  const headers =
      'From: Synthetic <benchmark@example.test>\nTo: test@example.test\nSubject: Synthetic benchmark\nDate: Wed, 18 Nov 2026 10:30:00 +0530\n';
  Uint8List plain(int size) => Uint8List.fromList(
    utf8.encode('$headers\n${'Readable email text. ' * (size ~/ 21)}'),
  );
  Uint8List htmlEmail() => Uint8List.fromList(
    utf8.encode(
      '${headers}Content-Type: text/html; charset=utf-8\n\n${'<p>${'Readable email text. ' * 40}</p>' * 1250}',
    ),
  );
  Uint8List multipart(int decodedSize) {
    final body = base64Encode(Uint8List(decodedSize));
    return Uint8List.fromList(
      utf8.encode(
        '${headers}Content-Type: multipart/mixed; boundary=bench\n\n--bench\nContent-Type: text/plain\n\nBenchmark attachment\n--bench\nContent-Type: application/octet-stream\nContent-Disposition: attachment; filename=synthetic.bin\nContent-Transfer-Encoding: base64\n\n$body\n--bench--\n',
      ),
    );
  }

  Uint8List large() {
    final part = base64Encode(Uint8List(15 * 1024 * 1024));
    final body = StringBuffer(
      '${headers}Content-Type: multipart/mixed; boundary=large\n\n--large\nContent-Type: text/plain\n\nTwo synthetic parts\n',
    );
    for (var i = 0; i < 2; i++) {
      body.write(
        '--large\nContent-Type: application/octet-stream\nContent-Disposition: attachment; filename=synthetic-$i.bin\nContent-Transfer-Encoding: base64\n\n$part\n',
      );
    }
    body.write('--large--\n');
    return Uint8List.fromList(utf8.encode(body.toString()));
  }

  final results = <Map<String, Object>>[];
  Future<void> measure(
    String label,
    Uint8List Function() make, {
    int count = 1,
  }) async {
    final source = make();
    var ticks = 0;
    final timer = Timer.periodic(
      const Duration(milliseconds: 10),
      (_) => ticks++,
    );
    final rssBefore = ProcessInfo.currentRss;
    final watch = Stopwatch()..start();
    var attachmentBytes = 0;
    for (var i = 0; i < count; i++) {
      final email = await parser.parse(source);
      attachmentBytes = email.attachmentSize;
      if (email.subject != 'Synthetic benchmark') {
        throw StateError('Benchmark parse failed');
      }
    }
    watch.stop();
    timer.cancel();
    results.add({
      'case': label,
      'raw_bytes': source.length,
      'count': count,
      'elapsed_ms': watch.elapsedMilliseconds,
      'decoded_attachment_bytes_per_message': attachmentBytes,
      'main_isolate_timer_ticks': ticks,
      'rss_before_bytes': rssBefore,
      'rss_after_bytes': ProcessInfo.currentRss,
      'process_peak_rss_bytes': ProcessInfo.maxRss,
    });
  }

  await measure('10 KB plaintext', () => plain(10000));
  await measure('1 MB HTML', htmlEmail);
  await measure('10 MB multipart', () => multipart(7500000));
  await measure('40 MiB multipart', large);
  await measure('50 small emails', () => plain(10000), count: 50);
  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'runtime': Platform.version,
      'os': Platform.operatingSystem,
      'measurements': results,
      'limits':
          'Synthetic warm/cold JIT single runs; process RSS includes source construction, isolate copying and previous cases. No mobile, native UI or package performance claim.',
    }),
  );
}
