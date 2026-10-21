import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/audio/application/audio_duration_helper.dart';

void main() {
  group('AudioDurationHelper Tests', () {
    test('formatDuration formats zero, seconds, minutes and hours', () {
      expect(AudioDurationHelper.formatDuration(Duration.zero), equals('00:00'));
      expect(AudioDurationHelper.formatDuration(const Duration(seconds: 8)), equals('00:08'));
      expect(AudioDurationHelper.formatDuration(const Duration(minutes: 3, seconds: 18)), equals('03:18'));
      expect(AudioDurationHelper.formatDuration(const Duration(minutes: 4, seconds: 36)), equals('04:36'));
      expect(AudioDurationHelper.formatDuration(const Duration(hours: 1, minutes: 4, seconds: 32)), equals('1:04:32'));
      expect(AudioDurationHelper.formatDuration(const Duration(seconds: -5)), equals('00:00'));
    });

    test('formatDurationHuman formats human readable totals for footers', () {
      expect(AudioDurationHelper.formatDurationHuman(Duration.zero), equals('0 sec'));
      expect(AudioDurationHelper.formatDurationHuman(const Duration(seconds: 45)), equals('45 sec'));
      expect(AudioDurationHelper.formatDurationHuman(const Duration(minutes: 3, seconds: 18)), equals('3 min 18 sec'));
      expect(AudioDurationHelper.formatDurationHuman(const Duration(minutes: 7, seconds: 54)), equals('7 min 54 sec'));
      expect(AudioDurationHelper.formatDurationHuman(const Duration(hours: 1, minutes: 14)), equals('1 hr 14 min'));
      expect(AudioDurationHelper.formatDurationHuman(const Duration(hours: 2)), equals('2 hr'));
    });

    test('formatDateTime and formatTimeOnly format timestamps properly', () {
      final dt = DateTime(2026, 10, 21, 16, 12);
      final formattedTime = AudioDurationHelper.formatTimeOnly(dt);
      expect(formattedTime.toLowerCase(), contains('4:12'));

      final fullDate = AudioDurationHelper.formatDateTime(dt);
      expect(fullDate, contains('21 Oct 2026'));
      expect(fullDate.toLowerCase(), contains('4:12'));

      final defaultTitle = AudioDurationHelper.generateDefaultTitle(dt);
      expect(defaultTitle, startsWith('Voice memo · '));
      expect(defaultTitle.toLowerCase(), contains('4:12'));
    });

    test('extractAmplitudesFromBytes generates bounded amplitude values', () {
      // 1. Organic fallback on empty bytes
      final emptyBars = AudioDurationHelper.extractAmplitudesFromBytes(Uint8List(0), count: 32);
      expect(emptyBars.length, equals(32));
      for (final bar in emptyBars) {
        expect(bar, greaterThanOrEqualTo(0.15));
        expect(bar, lessThanOrEqualTo(0.95));
      }

      // 2. Real audio bytes RMS computation
      final audioBytes = Uint8List(512);
      for (var i = 0; i < audioBytes.length; i++) {
        audioBytes[i] = (i % 256);
      }
      final calculatedBars = AudioDurationHelper.extractAmplitudesFromBytes(audioBytes, count: 16);
      expect(calculatedBars.length, equals(16));
      for (final bar in calculatedBars) {
        expect(bar, greaterThanOrEqualTo(0.15));
        expect(bar, lessThanOrEqualTo(0.95));
      }

      // 3. Downsampling captured live amplitudes
      final live = List.generate(64, (i) => (i / 64.0).clamp(0.15, 0.95));
      final downsampled = AudioDurationHelper.extractAmplitudesFromBytes(
        audioBytes,
        count: 32,
        liveAmplitudes: live,
      );
      expect(downsampled.length, equals(32));
      for (final bar in downsampled) {
        expect(bar, greaterThanOrEqualTo(0.15));
        expect(bar, lessThanOrEqualTo(0.95));
      }
    });
  });
}
