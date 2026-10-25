import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/onboarding/application/onboarding_provider.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';

class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onboardingStatusProvider);

    if (!status.completed) {
      return const OnboardingScreen();
    }

    return NotesScreen(showOnboardingTour: !status.tourSeen);
  }
}
