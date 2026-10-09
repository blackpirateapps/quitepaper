import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/journal/application/place_alias_store.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer withPrefs() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PlaceAliasStore (§2.3, device-local)', () {
    test('merge points every match key at the canonical key + display name', () {
      final c = withPrefs();
      c.read(placeAliasStoreProvider.notifier).merge(
        ['calcutta', 'kolkata'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );

      final state = c.read(placeAliasStoreProvider);
      expect(state['calcutta']!.canonicalKey, 'kolkata');
      expect(state['calcutta']!.displayName, 'Kolkata');
      // Canonical key maps to itself so its own entries adopt the display name.
      expect(state['kolkata']!.canonicalKey, 'kolkata');
      expect(state['kolkata']!.displayName, 'Kolkata');
    });

    test('rename updates display name for all entries under a canonical key', () {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      store.merge(['calcutta', 'kolkata'],
          canonicalKey: 'kolkata', displayName: 'Kolkata');

      store.rename(canonicalKey: 'kolkata', displayName: 'Kolkata, India');

      final state = c.read(placeAliasStoreProvider);
      expect(state['calcutta']!.displayName, 'Kolkata, India');
      expect(state['kolkata']!.displayName, 'Kolkata, India');
      expect(state['calcutta']!.canonicalKey, 'kolkata');
    });

    test('unmerge removes only the given key (reversible)', () {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      store.merge(['calcutta', 'cal'],
          canonicalKey: 'kolkata', displayName: 'Kolkata');

      store.unmerge('calcutta');

      final state = c.read(placeAliasStoreProvider);
      expect(state.containsKey('calcutta'), isFalse);
      expect(state.containsKey('cal'), isTrue);
      expect(state.containsKey('kolkata'), isTrue);
    });

    test('unmerge on an unknown key is a no-op', () {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      store.merge(['calcutta'], canonicalKey: 'kolkata', displayName: 'Kolkata');
      store.unmerge('does-not-exist');
      expect(c.read(placeAliasStoreProvider).length, 2); // calcutta + kolkata
    });

    test('persists to SharedPreferences and reloads in a fresh store', () async {
      final c1 = withPrefs();
      c1.read(placeAliasStoreProvider.notifier).merge(
        ['calcutta'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );
      // Let the fire-and-forget write settle.
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // A brand-new container over the same prefs rehydrates the map.
      final c2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c2.dispose);

      final restored = c2.read(placeAliasStoreProvider);
      expect(restored['calcutta']!.canonicalKey, 'kolkata');
      expect(restored['calcutta']!.displayName, 'Kolkata');
      expect(restored['kolkata']!.displayName, 'Kolkata');
    });

    test('falls back to in-memory when SharedPreferences is absent', () {
      final c = ProviderContainer(); // no override → prefs provider throws
      addTearDown(c.dispose);

      final store = c.read(placeAliasStoreProvider.notifier);
      store.merge(['a'], canonicalKey: 'b', displayName: 'B');

      expect(c.read(placeAliasStoreProvider)['a']!.canonicalKey, 'b');
    });
  });
}
