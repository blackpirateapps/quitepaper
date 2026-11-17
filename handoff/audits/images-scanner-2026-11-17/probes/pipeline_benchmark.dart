// Pure Dart VM benchmark of actual production ScanPipelines. Run from repo root:
// dart run handoff/audits/images-scanner-2026-11-17/probes/pipeline_benchmark.dart
import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:quitepaper/core/image_processing/scan_mode.dart';
import 'package:quitepaper/core/image_processing/scan_pipelines.dart';

img.Image paper(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (final p in image) {
    final text = p.y % 37 < 4 && p.x % 100 < 80;
    final value = text ? 35 : 170 + (p.x * 70 ~/ width);
    p.setRgb(value, value - (text ? 0 : 5), value - (text ? 0 : 10));
  }
  return image;
}

double percentile(List<double> values, double quantile) {
  final sorted = [...values]..sort();
  return sorted[((sorted.length - 1) * quantile).ceil()];
}

void main() {
  final results = <Map<String, Object>>[];
  final warm = paper(320, 240);
  for (final mode in ScanMode.values) {
    ScanPipelines.apply(warm, mode);
  }
  for (final maxDim in [600, 1600, 2048]) {
    final source = paper(maxDim, maxDim * 3 ~/ 4);
    for (final mode in ScanMode.values) {
      final samples = <double>[];
      final rssBefore = ProcessInfo.currentRss;
      var encodedBytes = 0;
      for (var i = 0; i < 5; i++) {
        final timer = Stopwatch()..start();
        final output = ScanPipelines.apply(source, mode);
        final encoded = img.encodeJpg(output, quality: 85);
        timer.stop();
        if (output.width != source.width ||
            output.height != source.height ||
            encoded.isEmpty) {
          throw StateError('Invalid pipeline output for $mode');
        }
        encodedBytes = encoded.length;
        samples.add(timer.elapsedMicroseconds / 1000);
      }
      final result = <String, Object>{
        'mode': mode.name,
        'width': source.width,
        'height': source.height,
        'samples_ms': samples,
        'median_ms': percentile(samples, .5),
        'p95_ms': percentile(samples, .95),
        'output_bytes': encodedBytes,
        'rss_before': rssBefore,
        'rss_after': ProcessInfo.currentRss,
      };
      results.add(result);
      stdout.writeln(jsonEncode(result));
    }
  }
  // Sequential multipage finalization lower-level CPU cost, including decode,
  // mode transform and JPEG re-encode. No camera, encryption or PDF layout.
  final source = img.encodeJpg(paper(1600, 1200), quality: 95);
  for (final count in [1, 5, 10]) {
    final timer = Stopwatch()..start();
    var totalOutput = 0;
    for (var i = 0; i < count; i++) {
      final decoded = img.decodeJpg(source)!;
      final output = ScanPipelines.apply(decoded, ScanMode.auto);
      totalOutput += img.encodeJpg(output, quality: 85).length;
    }
    timer.stop();
    final result = <String, Object>{
      'operation': 'sequential-auto-decode-process-encode',
      'pages': count,
      'width': 1600,
      'height': 1200,
      'total_ms': timer.elapsedMicroseconds / 1000,
      'output_bytes': totalOutput,
      'rss_after': ProcessInfo.currentRss,
    };
    results.add(result);
    stdout.writeln(jsonEncode(result));
  }
  final report = {
    'runtime': Platform.version,
    'os': Platform.operatingSystem,
    'processors': Platform.numberOfProcessors,
    'peak_rss_bytes': ProcessInfo.maxRss,
    'note':
        'Dart VM JIT, synthetic fixtures, 5 samples per mode including JPEG encoding. '
        'RSS is process-wide GC-sensitive, not per-image allocation. No device FPS claims.',
    'results': results,
  };
  File(
    'handoff/audits/images-scanner-2026-11-17/evidence/dart-vm-performance.json',
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
}
