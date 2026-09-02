import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/speech/domain/speech_model.dart';

void main() {
  group('SpeechModelDescriptor & SpeechModels Registry', () {
    test('contains all 4 expected models', () {
      expect(SpeechModels.all.length, equals(4));
      expect(SpeechModels.all, containsAll([
        SpeechModels.english39,
        SpeechModels.english74,
        SpeechModels.english244,
        SpeechModels.multilingual244,
      ]));
    });

    test('default model is English 39', () {
      expect(SpeechModels.defaultModel, equals(SpeechModels.english39));
      expect(SpeechModels.defaultModel.id, equals('futo_voice_input_english_39'));
      expect(SpeechModels.defaultModel.languageCode, equals('en'));
      expect(SpeechModels.defaultModel.isMultilingual, isFalse);
    });

    test('English 74 descriptor has correct URL, size, sha256 and lang', () {
      final model = SpeechModels.english74;
      expect(model.id, equals('futo_voice_input_english_74'));
      expect(model.name, equals('English (Balanced)'));
      expect(model.filename, equals('voice-input-english-74.bin'));
      expect(model.downloadUrl, equals('https://dl.keyboard.futo.org/voice-input-english-74.bin'));
      expect(model.sizeBytes, equals(81781811));
      expect(model.expectedSha256, equals('e9b4b7b81b8a28769e8aa9962aa39bb9f21b622cf6a63982e93f065ed5caf1c8'));
      expect(model.languageCode, equals('en'));
      expect(model.isMultilingual, isFalse);
    });

    test('English 244 descriptor has correct URL, size, sha256 and lang', () {
      final model = SpeechModels.english244;
      expect(model.id, equals('futo_voice_input_english_244'));
      expect(model.name, equals('English (High Accuracy)'));
      expect(model.filename, equals('voice-input-english-244.bin'));
      expect(model.downloadUrl, equals('https://dl.keyboard.futo.org/voice-input-english-244.bin'));
      expect(model.sizeBytes, equals(264477561));
      expect(model.expectedSha256, equals('58fbe949992dafed917590d58bc12ca577b08b9957f0b3e0d7ee71b64bed3aa8'));
      expect(model.languageCode, equals('en'));
      expect(model.isMultilingual, isFalse);
    });

    test('Multilingual 244 descriptor has auto languageCode and isMultilingual: true', () {
      final model = SpeechModels.multilingual244;
      expect(model.id, equals('futo_voice_input_multilingual_244'));
      expect(model.name, equals('Multilingual (Auto-Detect)'));
      expect(model.filename, equals('voice-input-multilingual-244.bin'));
      expect(model.downloadUrl, equals('https://dl.keyboard.futo.org/voice-input-multilingual-244.bin'));
      expect(model.sizeBytes, equals(264464624));
      expect(model.expectedSha256, equals('15ef255465a6dc582ecf1ec651a4618c7ee2c18c05570bbe46493d248d465ac4'));
      expect(model.languageCode, equals('auto'));
      expect(model.isMultilingual, isTrue);
    });

    test('fromId returns matching model or falls back to default', () {
      expect(SpeechModels.fromId('futo_voice_input_english_74'), equals(SpeechModels.english74));
      expect(SpeechModels.fromId('futo_voice_input_english_244'), equals(SpeechModels.english244));
      expect(SpeechModels.fromId('futo_voice_input_multilingual_244'), equals(SpeechModels.multilingual244));
      expect(SpeechModels.fromId('unknown_id'), equals(SpeechModels.defaultModel));
      expect(SpeechModels.fromId(null), equals(SpeechModels.defaultModel));
    });
  });
}
