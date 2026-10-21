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
    String? mimeType,
    String? fileName,
  }) {
    if (count <= 0) return const [];

    // 1. If we captured live amplitudes during recording, downsample them
    if (liveAmplitudes != null && liveAmplitudes.length >= 8) {
      return downsampleAmplitudes(liveAmplitudes, count);
    }

    if (bytes.length < 64) {
      return _generateOrganicProfile(count);
    }

    // 2. Try parsing genuine WAV PCM audio
    final isWav = (mimeType != null && mimeType.contains('wav')) ||
        (fileName != null && fileName.toLowerCase().endsWith('.wav')) ||
        _isWavHeader(bytes);
    if (isWav) {
      final wavWaveform = _extractWavPcmWaveform(bytes, count);
      if (wavWaveform != null && wavWaveform.isNotEmpty) {
        return wavWaveform;
      }
    }

    // 3. Try parsing genuine M4A / MP4 AAC audio frame sizes (stsz)
    final isMp4 = (mimeType != null &&
            (mimeType.contains('mp4') ||
                mimeType.contains('aac') ||
                mimeType.contains('m4a'))) ||
        (fileName != null &&
            (fileName.toLowerCase().endsWith('.m4a') ||
                fileName.toLowerCase().endsWith('.aac') ||
                fileName.toLowerCase().endsWith('.mp4'))) ||
        _isMp4Header(bytes);
    if (isMp4) {
      final mp4Waveform = _extractMp4Waveform(bytes, count);
      if (mp4Waveform != null && mp4Waveform.isNotEmpty) {
        return mp4Waveform;
      }
    }

    // 4. Derive RMS amplitude buckets from raw audio bytes
    return _extractByteRmsWaveform(bytes, count);
  }

  static bool _isWavHeader(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  static List<double>? _extractWavPcmWaveform(Uint8List bytes, int count) {
    try {
      final byteData = ByteData.sublistView(bytes);
      var offset = 12; // after RIFF...WAVE
      int channels = 1;
      int bitsPerSample = 16;
      int? dataOffset;
      int? dataLength;

      while (offset + 8 <= bytes.length) {
        final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final chunkSize = byteData.getUint32(offset + 4, Endian.little);
        offset += 8;

        if (chunkId == 'fmt ' && offset + 14 <= bytes.length) {
          channels = byteData.getUint16(offset + 2, Endian.little);
          bitsPerSample = byteData.getUint16(offset + 14, Endian.little);
        } else if (chunkId == 'data') {
          dataOffset = offset;
          dataLength = math.min(chunkSize, bytes.length - offset);
          break;
        }

        offset += chunkSize;
      }

      if (dataOffset == null || dataLength == null || dataLength < 16) {
        return null;
      }

      final bytesPerSample = bitsPerSample ~/ 8;
      if (bytesPerSample != 1 && bytesPerSample != 2) return null;
      final totalSamples = dataLength ~/ (bytesPerSample * channels);
      if (totalSamples < count) return null;

      final samples = <double>[];
      final samplesPerBucket = (totalSamples / count).floor();
      for (var b = 0; b < count; b++) {
        final startSample = b * samplesPerBucket;
        final endSample = (b == count - 1)
            ? totalSamples
            : math.min((b + 1) * samplesPerBucket, totalSamples);

        double sumSquares = 0.0;
        int countInBucket = 0;

        for (var s = startSample; s < endSample; s++) {
          final sampleByteOffset = dataOffset + s * bytesPerSample * channels;
          if (sampleByteOffset + bytesPerSample > bytes.length) break;

          double val;
          if (bytesPerSample == 2) {
            val = byteData.getInt16(sampleByteOffset, Endian.little) / 32768.0;
          } else {
            val = (bytes[sampleByteOffset] - 128) / 128.0;
          }
          sumSquares += val * val;
          countInBucket++;
        }

        final rms = countInBucket > 0 ? math.sqrt(sumSquares / countInBucket) : 0.0;
        final normalized = (0.15 + (rms * 2.5)).clamp(0.15, 0.95);
        samples.add(normalized);
      }

      return samples;
    } catch (_) {
      return null;
    }
  }

  static bool _isMp4Header(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70;
  }

  static List<double>? _extractMp4Waveform(Uint8List bytes, int count) {
    try {
      final byteData = ByteData.sublistView(bytes);

      // Find 'stsz' (Sample Size Box)
      int stszOffset = -1;
      for (var i = 0; i < bytes.length - 16; i++) {
        if (bytes[i] == 0x73 &&
            bytes[i + 1] == 0x74 &&
            bytes[i + 2] == 0x73 &&
            bytes[i + 3] == 0x7A) {
          stszOffset = i;
          break;
        }
      }

      if (stszOffset < 4) return null;

      final defaultSampleSize = byteData.getUint32(stszOffset + 4 + 4, Endian.big);
      final sampleCount = byteData.getUint32(stszOffset + 4 + 8, Endian.big);

      if (sampleCount == 0 || sampleCount > 500000) return null;
      if (defaultSampleSize != 0) return null;

      final tableOffset = stszOffset + 4 + 12;
      if (tableOffset + (sampleCount * 4) > bytes.length) return null;

      final frameSizes = <double>[];
      double maxFrameSize = 1.0;
      double minFrameSize = 999999.0;
      for (var i = 0; i < sampleCount; i++) {
        final sz = byteData.getUint32(tableOffset + (i * 4), Endian.big).toDouble();
        frameSizes.add(sz);
        if (sz > maxFrameSize) maxFrameSize = sz;
        if (sz < minFrameSize) minFrameSize = sz;
      }

      if (frameSizes.isEmpty) return null;

      final range = maxFrameSize - minFrameSize;
      final effectiveRange = range > 10.0 ? range : 100.0;

      final normalizedFrames = frameSizes.map((sz) {
        final norm = ((sz - minFrameSize) / effectiveRange).clamp(0.0, 1.0);
        return (0.15 + (norm * 0.8)).clamp(0.15, 0.95);
      }).toList();

      return downsampleAmplitudes(normalizedFrames, count);
    } catch (_) {
      return null;
    }
  }

  static List<double> _extractByteRmsWaveform(Uint8List bytes, int count) {
    final samples = <double>[];
    final bucketSize = (bytes.length / count).floor();
    for (var i = 0; i < count; i++) {
      final start = i * bucketSize;
      final end = math.min(start + bucketSize, bytes.length);
      if (start >= end) {
        samples.add(0.2);
        continue;
      }

      double sumSquares = 0.0;
      int sampleCount = 0;
      for (var j = start; j < end; j += 2) {
        final val = (bytes[j] - 128).abs();
        sumSquares += val * val;
        sampleCount++;
      }
      final rms = sampleCount > 0 ? math.sqrt(sumSquares / sampleCount) : 0.0;
      final normalized = (0.15 + (rms / 128.0) * 0.8).clamp(0.15, 0.95);
      samples.add(normalized);
    }
    return samples;
  }

  /// Downsamples a list of [source] amplitudes to [targetCount] normalized values.
  static List<double> downsampleAmplitudes(List<double> source, int targetCount) {
    if (source.isEmpty || targetCount <= 0) return const [];
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
