/// Abstract descriptor for speech models.
abstract class SpeechModelDescriptor {
  String get id;
  String get name;
  String get subtitle;
  String get language;
  String get languageCode;
  int get sizeBytes;
  String get version;
  String get filename;
  String get downloadUrl;
  String get expectedSha256;
  bool get isMultilingual;
}

/// FUTO English Voice Input Model (Version 39 - Fast & Lightweight).
class FutoEnglishSpeechModel39 implements SpeechModelDescriptor {
  const FutoEnglishSpeechModel39();

  @override
  String get id => 'futo_voice_input_english_39';

  @override
  String get name => 'English (Fast)';

  @override
  String get subtitle => 'Lightweight model for quick English dictation (~41.5 MB)';

  @override
  String get language => 'English';

  @override
  String get languageCode => 'en';

  @override
  int get sizeBytes => 43550795; // ~41.53 MB

  @override
  String get version => '39';

  @override
  String get filename => 'voice-input-english-39.bin';

  @override
  String get downloadUrl =>
      'https://dl.keyboard.futo.org/voice-input-english-39.bin';

  @override
  String get expectedSha256 =>
      '4b5480aa1b14a7efc5b578ef176510970a898049671c3cd237285b3e3f6bfbfc';

  @override
  bool get isMultilingual => false;
}

/// FUTO English Voice Input Model (Version 74 - Balanced).
class FutoEnglishSpeechModel74 implements SpeechModelDescriptor {
  const FutoEnglishSpeechModel74();

  @override
  String get id => 'futo_voice_input_english_74';

  @override
  String get name => 'English (Balanced)';

  @override
  String get subtitle => 'Enhanced accuracy for English dictation (~78.0 MB)';

  @override
  String get language => 'English';

  @override
  String get languageCode => 'en';

  @override
  int get sizeBytes => 81781811; // ~77.99 MB

  @override
  String get version => '74';

  @override
  String get filename => 'voice-input-english-74.bin';

  @override
  String get downloadUrl =>
      'https://dl.keyboard.futo.org/voice-input-english-74.bin';

  @override
  String get expectedSha256 =>
      'e9b4b7b81b8a28769e8aa9962aa39bb9f21b622cf6a63982e93f065ed5caf1c8';

  @override
  bool get isMultilingual => false;
}

/// FUTO English Voice Input Model (Version 244 - High Accuracy).
class FutoEnglishSpeechModel244 implements SpeechModelDescriptor {
  const FutoEnglishSpeechModel244();

  @override
  String get id => 'futo_voice_input_english_244';

  @override
  String get name => 'English (High Accuracy)';

  @override
  String get subtitle => 'Highest precision for English dictation (~252.2 MB)';

  @override
  String get language => 'English';

  @override
  String get languageCode => 'en';

  @override
  int get sizeBytes => 264477561; // ~252.22 MB

  @override
  String get version => '244';

  @override
  String get filename => 'voice-input-english-244.bin';

  @override
  String get downloadUrl =>
      'https://dl.keyboard.futo.org/voice-input-english-244.bin';

  @override
  String get expectedSha256 =>
      '58fbe949992dafed917590d58bc12ca577b08b9957f0b3e0d7ee71b64bed3aa8';

  @override
  bool get isMultilingual => false;
}

/// FUTO Multilingual Voice Input Model (Version 244 - Auto Language Detection).
class FutoMultilingualSpeechModel244 implements SpeechModelDescriptor {
  const FutoMultilingualSpeechModel244();

  @override
  String get id => 'futo_voice_input_multilingual_244';

  @override
  String get name => 'Multilingual (Auto-Detect)';

  @override
  String get subtitle => 'Auto-detects spoken language and writes in that language (~252.2 MB)';

  @override
  String get language => 'Multilingual';

  @override
  String get languageCode => 'auto';

  @override
  int get sizeBytes => 264464624; // ~252.21 MB

  @override
  String get version => '244';

  @override
  String get filename => 'voice-input-multilingual-244.bin';

  @override
  String get downloadUrl =>
      'https://dl.keyboard.futo.org/voice-input-multilingual-244.bin';

  @override
  String get expectedSha256 =>
      '15ef255465a6dc582ecf1ec651a4618c7ee2c18c05570bbe46493d248d465ac4';

  @override
  bool get isMultilingual => true;
}

/// Backward compatibility alias for the default English model.
typedef FutoEnglishSpeechModel = FutoEnglishSpeechModel39;

/// Global registry and lookup utilities for speech models.
class SpeechModels {
  const SpeechModels._();

  static const SpeechModelDescriptor english39 = FutoEnglishSpeechModel39();
  static const SpeechModelDescriptor english74 = FutoEnglishSpeechModel74();
  static const SpeechModelDescriptor english244 = FutoEnglishSpeechModel244();
  static const SpeechModelDescriptor multilingual244 = FutoMultilingualSpeechModel244();

  static const List<SpeechModelDescriptor> all = [
    english39,
    english74,
    english244,
    multilingual244,
  ];

  static const SpeechModelDescriptor defaultModel = english39;

  static SpeechModelDescriptor fromId(String? id) {
    if (id == null) return defaultModel;
    return all.firstWhere(
      (m) => m.id == id,
      orElse: () => defaultModel,
    );
  }
}

/// Metadata stored on disk after model verification.
class SpeechModelMetadata {
  const SpeechModelMetadata({
    required this.modelId,
    required this.version,
    required this.filename,
    required this.sizeBytes,
    required this.sha256,
    required this.installedAt,
  });

  final String modelId;
  final String version;
  final String filename;
  final int sizeBytes;
  final String sha256;
  final DateTime installedAt;

  Map<String, dynamic> toJson() => {
        'modelId': modelId,
        'version': version,
        'filename': filename,
        'sizeBytes': sizeBytes,
        'sha256': sha256,
        'installedAt': installedAt.toIso8601String(),
      };

  factory SpeechModelMetadata.fromJson(Map<String, dynamic> json) {
    return SpeechModelMetadata(
      modelId: json['modelId'] as String? ?? 'futo_voice_input_english_39',
      version: json['version'] as String? ?? '39',
      filename: json['filename'] as String? ?? 'voice-input-english-39.bin',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? '',
      installedAt: DateTime.tryParse(json['installedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
