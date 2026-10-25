import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../settings/application/settings_provider.dart';

abstract final class OnboardingKeys {
  static const String completed = 'onboarding_completed_v1';
  static const String tourSeen = 'onboarding_tour_seen_v1';
}

@immutable
class OnboardingStatus {
  const OnboardingStatus({
    required this.completed,
    required this.tourSeen,
  });

  final bool completed;
  final bool tourSeen;

  OnboardingStatus copyWith({bool? completed, bool? tourSeen}) {
    return OnboardingStatus(
      completed: completed ?? this.completed,
      tourSeen: tourSeen ?? this.tourSeen,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OnboardingStatus &&
          runtimeType == other.runtimeType &&
          completed == other.completed &&
          tourSeen == other.tourSeen;

  @override
  int get hashCode => completed.hashCode ^ tourSeen.hashCode;
}

class OnboardingStatusNotifier extends StateNotifier<OnboardingStatus> {
  OnboardingStatusNotifier(this._prefs)
      : super(OnboardingStatus(
          completed: _prefs.getBool(OnboardingKeys.completed) ?? false,
          tourSeen: _prefs.getBool(OnboardingKeys.tourSeen) ?? false,
        ));

  final SharedPreferences _prefs;

  Future<void> complete() async {
    state = state.copyWith(completed: true);
    await _prefs.setBool(OnboardingKeys.completed, true);
  }

  Future<void> markTourSeen() async {
    state = state.copyWith(tourSeen: true);
    await _prefs.setBool(OnboardingKeys.tourSeen, true);
  }

  Future<void> clearTourSeen() async {
    state = state.copyWith(tourSeen: false);
    await _prefs.setBool(OnboardingKeys.tourSeen, false);
  }

  Future<void> finishWithoutTour() async {
    await complete();
    await markTourSeen();
  }

  Future<void> finishWithTour() async {
    await complete();
    await clearTourSeen();
  }
}

final onboardingStatusProvider =
    StateNotifierProvider<OnboardingStatusNotifier, OnboardingStatus>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingStatusNotifier(prefs);
});
