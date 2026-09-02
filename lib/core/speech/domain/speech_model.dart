/// Abstract descriptor for speech models.
abstract class SpeechModelDescriptor {
  String get id;
  String get name;
  String get language;
  String get languageCode;
  int get sizeBytes;
  String get version;
  String get filename;
  String get downloadUrl;
  String get expectedSha256;
}

/// Supported FUTO English Voice Input Model (Version 39).
class FutoEnglishSpeechModel implements SpeechModelDescriptor {
  const FutoEnglishSpeechModel();

  @override
  String get id => 'futo_voice_input_english_39';

  @override
  String get name => 'English Voice Model';

  @override
  String get language => 'English';

  @override
  String get languageCode => 'en';

  @override
  int get sizeBytes => 43550795; // 43.55 MB

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
