import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/sync/sync_provider.dart';
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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        isKeyManagerUnlockedProvider.overrideWith((ref) => false),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('PlaceAliasStore (§2.3, device-local)', () {
    test(
      'merge points every match key at the canonical key + display name',
      () async {
        final c = withPrefs();
        await c
            .read(placeAliasStoreProvider.notifier)
            .merge(
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
      },
    );

    test(
      'repeated merges flatten all constituents and remain reversible',
      () async {
        final store = withPrefs().read(placeAliasStoreProvider.notifier);
        await store.merge(
          ['alpha', 'beta'],
          canonicalKey: 'trip',
          displayName: 'Trip',
        );
        await store.merge(
          ['trip', 'gamma'],
          canonicalKey: 'journey',
          displayName: 'Journey',
        );
        await store.merge(
          ['journey', 'delta'],
          canonicalKey: 'adventure',
          displayName: 'Adventure',
        );
        await store.merge(
          ['other'],
          canonicalKey: 'unrelated',
          displayName: 'Unrelated',
        );
        for (final key in [
          'alpha',
          'beta',
          'trip',
          'gamma',
          'journey',
          'delta',
          'adventure',
        ]) {
          expect(store.state[key]!.canonicalKey, 'adventure');
          expect(store.state[key]!.displayName, 'Adventure');
        }
        await pumpEventQueue();
        final reopened = withPrefs().read(placeAliasStoreProvider.notifier);
        expect(reopened.state['alpha']!.canonicalKey, 'adventure');
        await reopened.rename(canonicalKey: 'adventure', displayName: 'Home');
        expect(reopened.state['beta']!.displayName, 'Home');
        await reopened.unmergeCanonical('adventure');
        expect(reopened.state.keys.toSet(), {'other', 'unrelated'});
      },
    );

    test(
      'rename updates display name for all entries under a canonical key',
      () async {
        final c = withPrefs();
        final store = c.read(placeAliasStoreProvider.notifier);
        await store.merge(
          ['calcutta', 'kolkata'],
          canonicalKey: 'kolkata',
          displayName: 'Kolkata',
        );

        await store.rename(
          canonicalKey: 'kolkata',
          displayName: 'Kolkata, India',
        );

        final state = c.read(placeAliasStoreProvider);
        expect(state['calcutta']!.displayName, 'Kolkata, India');
        expect(state['kolkata']!.displayName, 'Kolkata, India');
        expect(state['calcutta']!.canonicalKey, 'kolkata');
      },
    );

    test('unmerge removes only the given key (reversible)', () async {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      await store.merge(
        ['calcutta', 'cal'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );

      await store.unmerge('calcutta');

      final state = c.read(placeAliasStoreProvider);
      expect(state.containsKey('calcutta'), isFalse);
      expect(state.containsKey('cal'), isTrue);
      expect(state.containsKey('kolkata'), isTrue);
    });

    test('unmerge on an unknown key is a no-op', () async {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      await store.merge(
        ['calcutta'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );
      await store.unmerge('does-not-exist');
      expect(c.read(placeAliasStoreProvider).length, 2); // calcutta + kolkata
    });

    test(
      'unmergeCanonical removes every entry pointing at the canonical key',
      () async {
        final c = withPrefs();
        final store = c.read(placeAliasStoreProvider.notifier);
        await store.merge(
          ['calcutta', 'cal', 'kolkata'],
          canonicalKey: 'kolkata',
          displayName: 'Kolkata',
        );
        // Also keep an unrelated merge to prove it is left intact.
        await store.merge(
          ['bombay'],
          canonicalKey: 'mumbai',
          displayName: 'Mumbai',
        );

        await store.unmergeCanonical('kolkata');

        final state = c.read(placeAliasStoreProvider);
        // Every kolkata-pointing entry (including the self-map) is gone.
        expect(state.containsKey('calcutta'), isFalse);
        expect(state.containsKey('cal'), isFalse);
        expect(state.containsKey('kolkata'), isFalse);
        // The unrelated mumbai merge is untouched.
        expect(state['bombay']!.canonicalKey, 'mumbai');
        expect(state['mumbai']!.canonicalKey, 'mumbai');
      },
    );

    test('unmergeCanonical on an unknown canonical key is a no-op', () async {
      final c = withPrefs();
      final store = c.read(placeAliasStoreProvider.notifier);
      await store.merge(
        ['calcutta'],
        canonicalKey: 'kolkata',
        displayName: 'Kolkata',
      );
      await store.unmergeCanonical('nowhere');
      expect(c.read(placeAliasStoreProvider).length, 2); // unchanged
    });

    test(
      'unmergeCanonical persists and stays unmerged in a fresh store',
      () async {
        final c1 = withPrefs();
        final store = c1.read(placeAliasStoreProvider.notifier);
        await store.merge(
          ['calcutta', 'kolkata'],
          canonicalKey: 'kolkata',
          displayName: 'Kolkata',
        );
        await store.unmergeCanonical('kolkata');

        final c2 = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isKeyManagerUnlockedProvider.overrideWith((ref) => false),
          ],
        );
        addTearDown(c2.dispose);
        expect(c2.read(placeAliasStoreProvider).isEmpty, isTrue);
      },
    );

    test(
      'persists to SharedPreferences and reloads in a fresh store',
      () async {
        final c1 = withPrefs();
        await c1
            .read(placeAliasStoreProvider.notifier)
            .merge(
              ['calcutta'],
              canonicalKey: 'kolkata',
              displayName: 'Kolkata',
            );

        // A brand-new container over the same prefs rehydrates the map.
        final c2 = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            isKeyManagerUnlockedProvider.overrideWith((ref) => false),
          ],
        );
        addTearDown(c2.dispose);

        final restored = c2.read(placeAliasStoreProvider);
        expect(restored['calcutta']!.canonicalKey, 'kolkata');
        expect(restored['calcutta']!.displayName, 'Kolkata');
        expect(restored['kolkata']!.displayName, 'Kolkata');
      },
    );

    test('falls back to in-memory when SharedPreferences is absent', () async {
      final c = ProviderContainer(
        overrides: [isKeyManagerUnlockedProvider.overrideWith((ref) => false)],
      ); // no prefs override → prefs provider throws
      addTearDown(c.dispose);

      final store = c.read(placeAliasStoreProvider.notifier);
      await store.merge(['a'], canonicalKey: 'b', displayName: 'B');

      expect(c.read(placeAliasStoreProvider)['a']!.canonicalKey, 'b');
    });
  });
}
