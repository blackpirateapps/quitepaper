import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/settings/application/settings_provider.dart';

/// Connection and availability state for local Ollama OCR daemon.
enum OllamaConnectionStatus {
  initial,
  checking,
  connected,
  disconnected,
  error,
}

/// Immutable configuration and state for Ollama Desktop OCR.
@immutable
class OllamaOcrSettings {
  const OllamaOcrSettings({
    required this.enabled,
    this.endpoint = defaultEndpoint,
    this.model = defaultModel,
    this.status = OllamaConnectionStatus.initial,
    this.availableModels = const [],
    this.errorMessage,
    this.lastChecked,
  });

  static const String defaultEndpoint = 'http://127.0.0.1:11434';
  static const String defaultModel = 'deepseek-ocr';

  /// Whether Ollama OCR is enabled as the primary recognition engine on desktop.
  final bool enabled;

  /// HTTP endpoint for the local or remote Ollama server.
  final String endpoint;

  /// Model tag or identifier to invoke (e.g. 'deepseek-ocr', 'hf.co/ggml-org/DeepSeek-OCR-GGUF:latest').
  final String model;

  /// Live connection status.
  final OllamaConnectionStatus status;

  /// List of model names retrieved from Ollama `GET /api/tags`.
  final List<String> availableModels;

  /// Human-readable error message if the connection check failed.
  final String? errorMessage;

  /// Timestamp of the last connection check.
  final DateTime? lastChecked;

  /// Whether Ollama is currently confirmed reachable and running.
  bool get isConnected => status == OllamaConnectionStatus.connected;

  OllamaOcrSettings copyWith({
    bool? enabled,
    String? endpoint,
    String? model,
    OllamaConnectionStatus? status,
    List<String>? availableModels,
    String? errorMessage,
    DateTime? lastChecked,
    bool clearError = false,
  }) {
    return OllamaOcrSettings(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      status: status ?? this.status,
      availableModels: availableModels ?? this.availableModels,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      lastChecked: lastChecked ?? this.lastChecked,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OllamaOcrSettings &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          endpoint == other.endpoint &&
          model == other.model &&
          status == other.status &&
          listEquals(availableModels, other.availableModels) &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(
        enabled,
        endpoint,
        model,
        status,
        Object.hashAll(availableModels),
        errorMessage,
      );
}

/// Notifier managing Ollama OCR preferences and daemon health checks.
class OllamaOcrSettingsNotifier extends StateNotifier<OllamaOcrSettings> {
  OllamaOcrSettingsNotifier(this._prefs, {this.httpClient})
      : super(_loadInitialSettings(_prefs)) {
    if (state.enabled) {
      checkConnection();
    }
  }

  final SharedPreferences? _prefs;
  final http.Client? httpClient;

  static const String _enabledKey = 'quietpaper_ollama_ocr_enabled';
  static const String _endpointKey = 'quietpaper_ollama_ocr_endpoint';
  static const String _modelKey = 'quietpaper_ollama_ocr_model';

  static bool _defaultEnabledForPlatform() {
    if (kIsWeb) return false;
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  static OllamaOcrSettings _loadInitialSettings(SharedPreferences? prefs) {
    final defaultEnabled = _defaultEnabledForPlatform();
    if (prefs == null) {
      return OllamaOcrSettings(enabled: defaultEnabled);
    }

    final enabled = prefs.getBool(_enabledKey) ?? defaultEnabled;
    final endpoint = prefs.getString(_endpointKey) ?? OllamaOcrSettings.defaultEndpoint;
    final model = prefs.getString(_modelKey) ?? OllamaOcrSettings.defaultModel;

    return OllamaOcrSettings(
      enabled: enabled,
      endpoint: endpoint,
      model: model,
    );
  }

  /// Sets whether Ollama OCR is enabled and persists to [SharedPreferences].
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _prefs?.setBool(_enabledKey, enabled);
    if (enabled && state.status != OllamaConnectionStatus.connected) {
      await checkConnection();
    }
  }

  /// Sets custom endpoint and persists to [SharedPreferences].
  Future<void> setEndpoint(String endpoint) async {
    final clean = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    state = state.copyWith(endpoint: clean);
    await _prefs?.setString(_endpointKey, clean);
    await checkConnection();
  }

  /// Sets target model and persists to [SharedPreferences].
  Future<void> setModel(String model) async {
    final clean = model.trim();
    state = state.copyWith(model: clean);
    await _prefs?.setString(_modelKey, clean);
  }

  /// Pings Ollama `/api/tags` to check connectivity and fetch available models.
  Future<bool> checkConnection({http.Client? clientOverride}) async {
    state = state.copyWith(
      status: OllamaConnectionStatus.checking,
      clearError: true,
    );

    final client = clientOverride ?? httpClient ?? http.Client();
    final shouldCloseClient = clientOverride == null && httpClient == null;

    try {
      final uri = Uri.parse('${state.endpoint}/api/tags');
      final response = await client.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final modelsList = (decoded['models'] as List?) ?? [];
        final names = modelsList
            .map((m) => (m is Map) ? (m['name'] as String? ?? m['model'] as String? ?? '') : '')
            .where((n) => n.isNotEmpty)
            .toList();

        state = state.copyWith(
          status: OllamaConnectionStatus.connected,
          availableModels: names,
          lastChecked: DateTime.now(),
          clearError: true,
        );
        return true;
      } else {
        state = state.copyWith(
          status: OllamaConnectionStatus.error,
          errorMessage: 'Server returned HTTP ${response.statusCode}',
          lastChecked: DateTime.now(),
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        status: OllamaConnectionStatus.disconnected,
        errorMessage: e.toString(),
        lastChecked: DateTime.now(),
      );
      return false;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }
}

/// Provider for user-configured Ollama OCR settings on desktop.
final ollamaOcrSettingsProvider =
    StateNotifierProvider<OllamaOcrSettingsNotifier, OllamaOcrSettings>((ref) {
  SharedPreferences? prefs;
  try {
    prefs = ref.watch(sharedPreferencesProvider);
  } catch (_) {
    // Test environment fallback
  }
  return OllamaOcrSettingsNotifier(prefs);
});
