import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/ocr/ollama_ocr_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('OllamaOcrSettings and Notifier Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Initializes with platform defaults', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = OllamaOcrSettingsNotifier(prefs);

      expect(notifier.state.endpoint, 'http://127.0.0.1:11434');
      expect(notifier.state.model, 'deepseek-ocr');
      expect(notifier.state.availableModels, isEmpty);
    });

    test('Persists settings updates to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = OllamaOcrSettingsNotifier(prefs);

      await notifier.setEnabled(false);
      expect(notifier.state.enabled, isFalse);
      expect(prefs.getBool('quietpaper_ollama_ocr_enabled'), isFalse);

      await notifier.setEndpoint('http://localhost:11434/');
      expect(notifier.state.endpoint, 'http://localhost:11434');
      expect(prefs.getString('quietpaper_ollama_ocr_endpoint'), 'http://localhost:11434');

      await notifier.setModel('hf.co/ggml-org/DeepSeek-OCR-GGUF:latest');
      expect(notifier.state.model, 'hf.co/ggml-org/DeepSeek-OCR-GGUF:latest');
      expect(prefs.getString('quietpaper_ollama_ocr_model'), 'hf.co/ggml-org/DeepSeek-OCR-GGUF:latest');
    });

    test('checkConnection updates state on successful /api/tags response', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/tags');
        return http.Response(
          json.encode({
            'models': [
              {'name': 'deepseek-ocr:latest'},
              {'name': 'llama3.2:latest'},
            ],
          }),
          200,
        );
      });

      final prefs = await SharedPreferences.getInstance();
      final notifier = OllamaOcrSettingsNotifier(prefs, httpClient: mockClient);

      final success = await notifier.checkConnection();

      expect(success, isTrue);
      expect(notifier.state.status, OllamaConnectionStatus.connected);
      expect(notifier.state.isConnected, isTrue);
      expect(notifier.state.availableModels, ['deepseek-ocr:latest', 'llama3.2:latest']);
      expect(notifier.state.errorMessage, isNull);
    });

    test('checkConnection marks disconnected on network failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final prefs = await SharedPreferences.getInstance();
      final notifier = OllamaOcrSettingsNotifier(prefs, httpClient: mockClient);

      final success = await notifier.checkConnection();

      expect(success, isFalse);
      expect(notifier.state.status, OllamaConnectionStatus.disconnected);
      expect(notifier.state.isConnected, isFalse);
      expect(notifier.state.errorMessage, contains('Connection refused'));
    });
  });
}
