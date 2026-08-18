import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/application/settings_provider.dart';
import 'update_models.dart';
import 'update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UpdateService(
    sharedPreferences: prefs,
    currentVersion: '1.3.0',
    githubRepo: 'blackpirateapps/quitepaper',
  );
});

final updateCheckProvider = FutureProvider.autoDispose<UpdateCheckResult>((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.checkForUpdate();
});
