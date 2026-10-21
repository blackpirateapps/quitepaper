import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../features/settings/application/settings_provider.dart';
import '../domain/audio_journal_models.dart';
import '../infrastructure/audio_journal_recording_service.dart';
import '../infrastructure/audio_playback_service.dart';
import '../infrastructure/audio_waveform_cache_service.dart';

/// Provider for the local audio waveform cache.
final audioWaveformCacheServiceProvider = Provider<AudioWaveformCacheService>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // In unit test contexts where sharedPreferencesProvider is uninitialized
  }
  return AudioWaveformCacheService(prefs: prefs);
});

/// Provider for the singleton audio recording service.
final audioJournalRecordingServiceProvider = Provider<AudioJournalRecordingService>((ref) {
  final service = AudioJournalRecordingService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Reactive stream of the current audio recording session.
final audioRecordingSessionStreamProvider = StreamProvider<AudioJournalRecordingSession>((ref) {
  final service = ref.watch(audioJournalRecordingServiceProvider);
  return service.sessionStream;
});

/// Current recording session snapshot.
final audioRecordingSessionProvider = Provider<AudioJournalRecordingSession>((ref) {
  final asyncVal = ref.watch(audioRecordingSessionStreamProvider);
  return asyncVal.value ?? ref.watch(audioJournalRecordingServiceProvider).session;
});

/// Provider for the application-wide playback coordinator.
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Reactive stream of the current playback snapshot.
final audioPlaybackSnapshotStreamProvider = StreamProvider<AudioPlaybackSnapshot>((ref) {
  final service = ref.watch(audioPlaybackServiceProvider);
  return service.snapshotStream;
});

/// Current playback state snapshot.
final audioPlaybackSnapshotProvider = Provider<AudioPlaybackSnapshot>((ref) {
  final asyncVal = ref.watch(audioPlaybackSnapshotStreamProvider);
  return asyncVal.value ?? ref.watch(audioPlaybackServiceProvider).snapshot;
});
