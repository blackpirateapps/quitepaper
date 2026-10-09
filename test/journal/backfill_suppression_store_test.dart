import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/features/journal/application/backfill_suppression_store.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> container() async {
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('BackfillSuppressionStore', () {
    test('starts empty and suppressDay adds exactly that date', () async {
      final c = await container();
      final notifier = c.read(backfillSuppressionProvider.notifier);

      expect(c.read(backfillSuppressionProvider), isEmpty);
      expect(notifier.isDaySuppressed('2026-09-15'), isFalse);

      notifier.suppressDay('2026-09-15');

      expect(c.read(backfillSuppressionProvider), {'2026-09-15'});
      expect(notifier.isDaySuppressed('2026-09-15'), isTrue);
      // Other days remain un-suppressed.
      expect(notifier.isDaySuppressed('2026-09-16'), isFalse);
    });

    test('suppressDay is idempotent and ignores empty', () async {
      final c = await container();
      final notifier = c.read(backfillSuppressionProvider.notifier);

      notifier.suppressDay('2026-09-15');
      notifier.suppressDay('2026-09-15');
      notifier.suppressDay('');

      expect(c.read(backfillSuppressionProvider), {'2026-09-15'});
    });

    test('persists to SharedPreferences and reloads across instances',
        () async {
      final prefs = await SharedPreferences.getInstance();
      BackfillSuppressionStore(prefs).suppressDay('2026-01-02');

      final raw = prefs.getString(BackfillSuppressionStore.storageKey);
      expect(raw, isNotNull);
      expect(raw, contains('2026-01-02'));

      // A fresh store loads the persisted set.
      final reloaded = BackfillSuppressionStore(prefs);
      expect(reloaded.isDaySuppressed('2026-01-02'), isTrue);
    });

    test('corrupt payload falls back to an empty set', () async {
      SharedPreferences.setMockInitialValues({
        BackfillSuppressionStore.storageKey: 'not-json',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(c.dispose);
      expect(c.read(backfillSuppressionProvider), isEmpty);
    });

    test('in-memory only when no prefs (no crash)', () {
      final store = BackfillSuppressionStore(null);
      store.suppressDay('2026-09-15');
      expect(store.isDaySuppressed('2026-09-15'), isTrue);
    });
  });
}
