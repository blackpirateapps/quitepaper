import 'dart:math' as math;
import 'dart:typed_data';
import 'package:intl/intl.dart';

/// Formatter and parsing helper for audio durations, timestamps, and waveform amplitudes.
class AudioDurationHelper {
  AudioDurationHelper._();

  /// Formats duration into digital clock format:
  /// - Under an hour: `MM:SS` (e.g. `00:08`, `03:18`, `04:36`)
  /// - One hour or more: `H:MM:SS` (e.g. `1:04:32`)
  static String formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      return '$hours:$minStr:$secStr';
    }
    return '$minStr:$secStr';
  }

  /// Formats total duration for note summary footers:
  /// e.g. `7 min 54 sec` or `3 min 18 sec` or `45 sec` or `1 hr 14 min`.
  static String formatDurationHuman(Duration duration) {
    if (duration.isNegative || duration == Duration.zero) return '0 sec';
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours hr $minutes min';
      }
      return '$hours hr';
    }

    if (minutes > 0) {
      if (seconds > 0) {
        return '$minutes min $seconds sec';
      }
      return '$minutes min';
    }

    return '$seconds sec';
  }

  /// Formats creation timestamp for audio card headers / subtitles:
  /// e.g. `21 Oct 2026 · 4:12 PM`.
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final datePart = DateFormat('d MMM yyyy').format(local);
    final timePart = DateFormat('h:mm a').format(local);
    return '$datePart · $timePart';
  }

  /// Formats compact time for voice memo subheadings:
  /// e.g. `4:12 PM`.
  static String formatTimeOnly(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  /// Generates a standard default title for a new voice memo based on start time:
  /// e.g. `Voice memo · 4:12 PM`.
  static String generateDefaultTitle(DateTime dateTime) {
    return 'Voice memo · ${formatTimeOnly(dateTime)}';
  }

  /// Derives [count] normalized amplitude bars (values between 0.15 and 0.95)
  /// from raw audio bytes or a fallback sample distribution.
  static List<double> extractAmplitudesFromBytes(
    Uint8List bytes, {
    int count = 32,
    List<double>? liveAmplitudes,
  }) {
    if (count <= 0) return const [];

    // 1. If we captured live amplitudes during recording, downsample them
    if (liveAmplitudes != null && liveAmplitudes.length >= 8) {
      return _downsampleAmplitudes(liveAmplitudes, count);
    }

    // 2. Derive RMS amplitude buckets from raw audio bytes
    if (bytes.length >= 64) {
      final samples = <double>[];
      final bucketSize = (bytes.length / count).floor();
      for (var i = 0; i < count; i++) {
        final start = i * bucketSize;
        final end = math.min(start + bucketSize, bytes.length);
        if (start >= end) {
          samples.add(0.2);
          continue;
        }

        // Compute RMS energy of byte values in bucket
        double sumSquares = 0.0;
        int sampleCount = 0;
        for (var j = start; j < end; j += 2) {
          // Interpret as unsigned or centered delta
          final val = (bytes[j] - 128).abs();
          sumSquares += val * val;
          sampleCount++;
        }
        final rms = sampleCount > 0 ? math.sqrt(sumSquares / sampleCount) : 0.0;
        // Normalize between 0.15 and 0.95
        final normalized = (0.15 + (rms / 128.0) * 0.8).clamp(0.15, 0.95);
        samples.add(normalized);
      }
      return samples;
    }

    // 3. Fallback subtle organic waveform profile
    return _generateOrganicProfile(count);
  }

  static List<double> _downsampleAmplitudes(List<double> source, int targetCount) {
    final result = <double>[];
    final step = source.length / targetCount;
    for (var i = 0; i < targetCount; i++) {
      final startIndex = (i * step).floor();
      final endIndex = math.min(((i + 1) * step).ceil(), source.length);
      double maxVal = 0.15;
      for (var j = startIndex; j < endIndex; j++) {
        if (source[j] > maxVal) maxVal = source[j];
      }
      result.add(maxVal.clamp(0.15, 0.95));
    }
    return result;
  }

  static List<double> _generateOrganicProfile(int count) {
    final list = <double>[];
    for (var i = 0; i < count; i++) {
      // Gentle bell / conversational wave curve
      final x = i / (count - 1);
      final curve = math.sin(x * math.pi);
      final jitter = (math.sin(i * 1.7) * 0.15).abs();
      final val = (0.2 + curve * 0.55 + jitter).clamp(0.15, 0.95);
      list.add(val);
    }
    return list;
  }
}
