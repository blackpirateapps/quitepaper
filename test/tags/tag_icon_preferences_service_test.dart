import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/tags/application/tag_icon_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TagIconPreferencesService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state has empty recents and empty favorites', () async {
      final service = TagIconPreferencesService();
      final recents = await service.getRecentIconIds();
      final favorites = await service.getFavoriteIconIds();

      expect(recents, isEmpty);
      expect(favorites, isEmpty);
    });

    test('recordRecentIcon maintains MRU order and deduplicates', () async {
      final service = TagIconPreferencesService();

      await service.recordRecentIcon('heart');
      await service.recordRecentIcon('star');
      await service.recordRecentIcon('camera');

      var recents = await service.getRecentIconIds();
      expect(recents, ['camera', 'star', 'heart']);

      // Re-recording 'star' moves it to front
      await service.recordRecentIcon('star');
      recents = await service.getRecentIconIds();
      expect(recents, ['star', 'camera', 'heart']);
    });

    test('recordRecentIcon respects maxRecents capacity of 12', () async {
      final service = TagIconPreferencesService();

      for (var i = 0; i < 20; i++) {
        await service.recordRecentIcon('icon-$i');
      }

      final recents = await service.getRecentIconIds();
      expect(recents.length, 12);
      expect(recents.first, 'icon-19');
      expect(recents.last, 'icon-8');
    });

    test('toggleFavorite adds and removes items', () async {
      final service = TagIconPreferencesService();

      expect(await service.isFavorite('heart'), isFalse);

      final added = await service.toggleFavorite('heart');
      expect(added, isTrue);
      expect(await service.isFavorite('heart'), isTrue);

      final removed = await service.toggleFavorite('heart');
      expect(removed, isFalse);
      expect(await service.isFavorite('heart'), isFalse);
    });

    test('clearRecentIcons resets recents', () async {
      final service = TagIconPreferencesService();

      await service.recordRecentIcon('heart');
      await service.recordRecentIcon('star');
      expect((await service.getRecentIconIds()).length, 2);

      await service.clearRecentIcons();
      expect(await service.getRecentIconIds(), isEmpty);
    });
  });
}
