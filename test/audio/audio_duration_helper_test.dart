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

    test('extracts genuine PCM waveform from WAV audio container', () {
      final header = ByteData(44);
      // 'RIFF'
      header.setUint8(0, 0x52);
      header.setUint8(1, 0x49);
      header.setUint8(2, 0x46);
      header.setUint8(3, 0x46);
      header.setUint32(4, 36 + 200 * 2, Endian.little);
      // 'WAVE'
      header.setUint8(8, 0x57);
      header.setUint8(9, 0x41);
      header.setUint8(10, 0x56);
      header.setUint8(11, 0x45);
      // 'fmt '
      header.setUint8(12, 0x66);
      header.setUint8(13, 0x6D);
      header.setUint8(14, 0x74);
      header.setUint8(15, 0x20);
      header.setUint32(16, 16, Endian.little);
      header.setUint16(20, 1, Endian.little); // PCM
      header.setUint16(22, 1, Endian.little); // 1 channel
      header.setUint32(24, 16000, Endian.little); // 16kHz
      header.setUint32(28, 32000, Endian.little); // byte rate
      header.setUint16(32, 2, Endian.little); // block align
      header.setUint16(34, 16, Endian.little); // 16-bit
      // 'data'
      header.setUint8(36, 0x64);
      header.setUint8(37, 0x61);
      header.setUint8(38, 0x74);
      header.setUint8(39, 0x61);
      header.setUint32(40, 200 * 2, Endian.little);

      final pcmBytes = ByteData(200 * 2);
      // First 100 samples silence (0)
      for (var i = 0; i < 100; i++) {
        pcmBytes.setInt16(i * 2, 0, Endian.little);
      }
      // Next 100 samples loud voice/signal (+25000)
      for (var i = 100; i < 200; i++) {
        pcmBytes.setInt16(i * 2, 25000, Endian.little);
      }

      final completeWav = Uint8List(44 + 400);
      completeWav.setRange(0, 44, header.buffer.asUint8List());
      completeWav.setRange(44, 444, pcmBytes.buffer.asUint8List());

      final waveform = AudioDurationHelper.extractAmplitudesFromBytes(
        completeWav,
        count: 16,
        fileName: 'test.wav',
      );

      expect(waveform.length, equals(16));
      // First half (silence) must be quiet (~0.15)
      expect(waveform[0], closeTo(0.15, 0.01));
      // Second half (loud signal) must be high (> 0.5)
      expect(waveform[15], greaterThan(0.5));
    });

    test('extracts genuine frame-size amplitude envelope from MP4/M4A stsz box', () {
      final buffer = ByteData(100);
      // 'ftyp' at offset 4
      buffer.setUint32(0, 20, Endian.big);
      buffer.setUint8(4, 0x66);
      buffer.setUint8(5, 0x74);
      buffer.setUint8(6, 0x79);
      buffer.setUint8(7, 0x70);

      // 'stsz' at offset 20
      buffer.setUint32(20, 60, Endian.big); // size
      buffer.setUint8(24, 0x73); // s
      buffer.setUint8(25, 0x74); // t
      buffer.setUint8(26, 0x73); // s
      buffer.setUint8(27, 0x7A); // z
      buffer.setUint32(28, 0, Endian.big); // version + flags
      buffer.setUint32(32, 0, Endian.big); // default sample size = 0 (variable)
      buffer.setUint32(36, 8, Endian.big); // sample count = 8

      // Frame sizes: 4 quiet frames (15 bytes), 4 loud speech frames (300 bytes)
      buffer.setUint32(40, 15, Endian.big);
      buffer.setUint32(44, 15, Endian.big);
      buffer.setUint32(48, 15, Endian.big);
      buffer.setUint32(52, 15, Endian.big);
      buffer.setUint32(56, 300, Endian.big);
      buffer.setUint32(60, 300, Endian.big);
      buffer.setUint32(64, 300, Endian.big);
      buffer.setUint32(68, 300, Endian.big);

      final waveform = AudioDurationHelper.extractAmplitudesFromBytes(
        buffer.buffer.asUint8List(),
        count: 8,
        fileName: 'memo.m4a',
      );

      expect(waveform.length, equals(8));
      // Quiet frames mapped to low value, loud frames mapped to high value
      expect(waveform[0], lessThan(waveform[7]));
      expect(waveform[7], closeTo(0.95, 0.05));
    });
  });
}
