import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/features/onboarding/application/onboarding_provider.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingProvider & OnboardingStatusNotifier Tests', () {
    test('1. Defaults are completed: false, tourSeen: false when keys are absent',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final status = container.read(onboardingStatusProvider);
      expect(status.completed, isFalse);
      expect(status.tourSeen, isFalse);

      final notifier = OnboardingStatusNotifier(prefs);
      expect(notifier.state.completed, isFalse);
      expect(notifier.state.tourSeen, isFalse);
    });

    test('2. complete() persists onboarding_completed_v1 = true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      await notifier.complete();

      expect(notifier.state.completed, isTrue);
      expect(prefs.getBool(OnboardingKeys.completed), isTrue);
    });

    test('3. markTourSeen() persists onboarding_tour_seen_v1 = true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      await notifier.markTourSeen();

      expect(notifier.state.tourSeen, isTrue);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isTrue);
    });

    test('4. clearTourSeen() persists false', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingKeys.tourSeen: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      expect(notifier.state.tourSeen, isTrue);
      await notifier.clearTourSeen();

      expect(notifier.state.tourSeen, isFalse);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isFalse);
    });

    test('5. finishWithTour() sets completed true and tourSeen false', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingKeys.completed: false,
        OnboardingKeys.tourSeen: true,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      await notifier.finishWithTour();

      expect(notifier.state.completed, isTrue);
      expect(notifier.state.tourSeen, isFalse);
      expect(prefs.getBool(OnboardingKeys.completed), isTrue);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isFalse);
    });

    test('6. finishWithoutTour() sets both true', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      await notifier.finishWithoutTour();

      expect(notifier.state.completed, isTrue);
      expect(notifier.state.tourSeen, isTrue);
      expect(prefs.getBool(OnboardingKeys.completed), isTrue);
      expect(prefs.getBool(OnboardingKeys.tourSeen), isTrue);
    });

    test('7. A new provider instance reads persisted state back', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingKeys.completed: true,
        OnboardingKeys.tourSeen: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = OnboardingStatusNotifier(prefs);

      expect(notifier.state.completed, isTrue);
      expect(notifier.state.tourSeen, isFalse);
    });
  });
}
