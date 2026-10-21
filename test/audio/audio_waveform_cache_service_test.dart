import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/audio/infrastructure/audio_waveform_cache_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioWaveformCacheService Tests', () {
    late AudioWaveformCacheService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      service = AudioWaveformCacheService(prefs: prefs);
    });

    test('returns null when waveform is not cached', () {
      expect(service.getWaveform('non-existent-id'), isNull);
    });

    test('caches and retrieves waveform from memory and preferences', () async {
      final bars = List.generate(32, (i) => 0.2 + (i * 0.02));
      await service.cacheWaveform('att-1', bars);

      final retrieved = service.getWaveform('att-1');
      expect(retrieved, isNotNull);
      expect(retrieved!.length, equals(32));
      expect(retrieved[0], closeTo(0.2, 0.001));
      expect(retrieved[31], closeTo(0.82, 0.001));

      // Test recovery from persistent SharedPreferences after clearing memory cache
      service.clearMemoryCache();
      final fromDisk = service.getWaveform('att-1');
      expect(fromDisk, isNotNull);
      expect(fromDisk!.length, equals(32));
      expect(fromDisk[0], closeTo(0.2, 0.001));
    });

    test('removeWaveform purges from memory and persistent store', () async {
      final bars = [0.25, 0.5, 0.75];
      await service.cacheWaveform('att-2', bars);
      expect(service.getWaveform('att-2'), isNotNull);

      await service.removeWaveform('att-2');
      expect(service.getWaveform('att-2'), isNull);

      service.clearMemoryCache();
      expect(service.getWaveform('att-2'), isNull);
    });

    test('clamps values to safe visual range [0.15, 0.95]', () async {
      final extremeBars = [0.0, 0.1, 0.5, 1.0, 2.5];
      await service.cacheWaveform('att-3', extremeBars);

      final retrieved = service.getWaveform('att-3')!;
      expect(retrieved[0], equals(0.15));
      expect(retrieved[1], equals(0.15));
      expect(retrieved[2], equals(0.5));
      expect(retrieved[3], equals(0.95));
      expect(retrieved[4], equals(0.95));
    });
  });
}
