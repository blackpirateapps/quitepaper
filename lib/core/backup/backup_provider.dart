import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/notes/application/notes_provider.dart';
import '../../features/settings/application/settings_provider.dart';
import '../sync/sync_provider.dart';
import 'backup_models.dart';
import 'backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final crypto = ref.watch(cryptoServiceProvider);
  final prefs = ref.watch(sharedPreferencesProvider);

  return BackupService(
    database: db,
    cryptoService: crypto,
    sharedPreferences: prefs,
    appVersion: '1.3.0',
  );
});

class AutoBackupConfigNotifier extends StateNotifier<AutoBackupConfig> {
  AutoBackupConfigNotifier(this._service) : super(_service.getAutoBackupConfig());

  final BackupService _service;

  void refresh() {
    state = _service.getAutoBackupConfig();
  }

  Future<void> setEnabled(bool enabled) async {
    final updated = state.copyWith(enabled: enabled);
    await _service.updateAutoBackupConfig(updated);
    state = updated;
  }

  Future<void> setFolderPath(String? path) async {
    final updated = state.copyWith(folderPath: path);
    await _service.updateAutoBackupConfig(updated);
    state = updated;
  }

  Future<void> setRetentionCount(int count) async {
    final updated = state.copyWith(retentionCount: count);
    await _service.updateAutoBackupConfig(updated);
    state = updated;
  }

  Future<void> setPassword(String password) async {
    await _service.setAutoBackupPassword(password);
    state = state.copyWith(hasPassword: true);
  }

  Future<void> clearPassword() async {
    await _service.clearAutoBackupPassword();
    state = state.copyWith(hasPassword: false);
  }
}

final autoBackupConfigProvider =
    StateNotifierProvider<AutoBackupConfigNotifier, AutoBackupConfig>((ref) {
  final service = ref.watch(backupServiceProvider);
  return AutoBackupConfigNotifier(service);
});
