import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local on-device persistent cache for audio waveform amplitude bars.
///
/// Keeps audio files encrypted on disk while caching normalized waveform
/// representations (32 amplitude bars between 0.15 and 0.95) locally so that
/// note rendering never shows a static fallback curve and does not require
/// decrypting the vault file on every note view.
class AudioWaveformCacheService {
  AudioWaveformCacheService({this.prefs});

  final SharedPreferences? prefs;
  final Map<String, List<double>> _memoryCache = {};

  static const String _keyPrefix = 'quietpaper_audio_waveform_';

  /// Returns cached normalized amplitude bars for [attachmentId] if available,
  /// or `null` if not yet computed.
  List<double>? getWaveform(String attachmentId) {
    if (attachmentId.isEmpty) return null;

    if (_memoryCache.containsKey(attachmentId)) {
      return _memoryCache[attachmentId];
    }

    final p = prefs;
    if (p == null) return null;

    final jsonStr = p.getString('$_keyPrefix$attachmentId');
    if (jsonStr == null || jsonStr.isEmpty) return null;

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final list = decoded.map((e) => (e as num).toDouble()).toList();
        if (list.isNotEmpty) {
          _memoryCache[attachmentId] = List.unmodifiable(list);
          return list;
        }
      }
    } catch (e) {
      debugPrint('[AudioWaveformCache] Deserialization error for $attachmentId: $e');
    }
    return null;
  }

  /// Caches the normalized amplitude [bars] for [attachmentId].
  Future<void> cacheWaveform(String attachmentId, List<double> bars) async {
    if (attachmentId.isEmpty || bars.isEmpty) return;

    final cleanBars = bars.map((b) => b.clamp(0.15, 0.95)).toList();
    _memoryCache[attachmentId] = List.unmodifiable(cleanBars);

    final p = prefs;
    if (p != null) {
      try {
        await p.setString('$_keyPrefix$attachmentId', jsonEncode(cleanBars));
      } catch (e) {
        debugPrint('[AudioWaveformCache] Serialization error for $attachmentId: $e');
      }
    }
  }

  /// Removes cached waveform data when an attachment is deleted.
  Future<void> removeWaveform(String attachmentId) async {
    if (attachmentId.isEmpty) return;
    _memoryCache.remove(attachmentId);
    final p = prefs;
    if (p != null) {
      try {
        await p.remove('$_keyPrefix$attachmentId');
      } catch (_) {}
    }
  }

  /// Clears in-memory cache (for testing or memory pressure).
  void clearMemoryCache() {
    _memoryCache.clear();
  }
}
