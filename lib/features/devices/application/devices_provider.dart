import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/device/device_info_service.dart';
import '../../../core/sync/sync_provider.dart';
import '../domain/device.dart';

final devicesListProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final api = ref.watch(syncApiClientProvider);
  final currentDeviceId = await ref.watch(currentDeviceIdProvider.future);
  return api.getDevices(deviceId: currentDeviceId);
});

final devicesActionNotifierProvider =
    StateNotifierProvider.autoDispose<DevicesActionNotifier, AsyncValue<void>>((ref) {
  return DevicesActionNotifier(ref);
});

class DevicesActionNotifier extends StateNotifier<AsyncValue<void>> {
  DevicesActionNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<Device?> rename(String deviceId, String newName) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(syncApiClientProvider);
      final updated = await api.renameDevice(deviceId, newName);
      ref.invalidate(devicesListProvider);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> revoke(String deviceId) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(syncApiClientProvider);
      await api.revokeDevice(deviceId);
      ref.invalidate(devicesListProvider);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<int> revokeOthers(String currentDeviceId) async {
    state = const AsyncValue.loading();
    try {
      final api = ref.read(syncApiClientProvider);
      final count = await api.revokeOtherDevices(currentDeviceId);
      ref.invalidate(devicesListProvider);
      state = const AsyncValue.data(null);
      return count;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}
