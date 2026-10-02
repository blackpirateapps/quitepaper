import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/application/settings_provider.dart';
import '../flavor/app_flavor.dart';
import '../version/app_version_provider.dart';
import 'update_models.dart';
import 'update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final flavor = ref.watch(appFlavorProvider);
  final versionInfo = ref.watch(appVersionInfoProvider);
  return UpdateService(
    sharedPreferences: prefs,
    currentVersion: versionInfo.version,
    flavor: flavor,
    githubRepo: 'blackpirateapps/quitepaper',
  );
});

final updateCheckProvider = FutureProvider.autoDispose<UpdateCheckResult>((ref) async {
  final service = ref.watch(updateServiceProvider);
  return service.checkForUpdate();
});
