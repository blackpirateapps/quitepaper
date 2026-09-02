import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quitepaper/core/speech/application/speech_provider.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';
import 'package:quitepaper/features/settings/application/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechModelPreferenceNotifier', () {
    test('loads default model when no preference is saved', () {
      final notifier = SpeechModelPreferenceNotifier(null);
      expect(notifier.state, equals(SpeechModels.defaultModel));
    });

    test('persists and updates selected model in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = SpeechModelPreferenceNotifier(prefs);
      expect(notifier.state, equals(SpeechModels.defaultModel));

      await notifier.setModel(SpeechModels.multilingual244);
      expect(notifier.state, equals(SpeechModels.multilingual244));
      expect(prefs.getString('quietpaper_speech_model_pref'), equals('futo_voice_input_multilingual_244'));

      // Re-instantiate from persisted prefs
      final reloaded = SpeechModelPreferenceNotifier(prefs);
      expect(reloaded.state, equals(SpeechModels.multilingual244));
      expect(reloaded.state.isMultilingual, isTrue);
      expect(reloaded.state.languageCode, equals('auto'));
    });

    test('setModelById correctly switches models', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final notifier = SpeechModelPreferenceNotifier(prefs);
      await notifier.setModelById('futo_voice_input_english_74');
      expect(notifier.state, equals(SpeechModels.english74));
      expect(prefs.getString('quietpaper_speech_model_pref'), equals('futo_voice_input_english_74'));
    });

    test('selectedSpeechModelProvider provides active descriptor to speechModelDescriptorProvider', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(speechModelDescriptorProvider), equals(SpeechModels.defaultModel));

      await container.read(selectedSpeechModelProvider.notifier).setModel(SpeechModels.english244);
      expect(container.read(speechModelDescriptorProvider), equals(SpeechModels.english244));
    });
  });
}
