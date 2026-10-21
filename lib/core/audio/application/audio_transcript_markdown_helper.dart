import 'dart:convert';
import '../../uri/quiet_paper_uri.dart';
import '../domain/audio_transcript_models.dart';

/// Helper for serialization, parsing, and normalization of audio transcripts in canonical Markdown.
class AudioTranscriptMarkdownHelper {
  AudioTranscriptMarkdownHelper._();

  static final RegExp _audioLinkRegex = RegExp(
    r'^\[([^\]]*)\]\((qp:\/\/asset\/([0-9a-fA-F\-]{36})(\?[^)\s]*)?)\)$',
  );

  /// Serializes an audio attachment link and companion transcript blockquote to canonical Markdown.
  static String serializeAudioMarkdown({
    required String displayText,
    required String uri,
    String? transcript,
    String? language,
    bool isEdited = false,
  }) {
    final cleanTitle = displayText.replaceAll('[', '').replaceAll(']', '').trim();
    final hasTranscript = transcript != null && transcript.trim().isNotEmpty;

    final qp = QuietPaperUri.tryParse(uri);
    if (!hasTranscript) {
      // Clean transcript params if previously present
      final cleanUri = (qp != null && qp.parameters.containsKey('transcript'))
          ? QuietPaperUri.asset(
              qp.resourceId,
              parameters: Map.from(qp.parameters)
                ..remove('transcript')
                ..remove('lang')
                ..remove('edited'),
            ).toUriString()
          : uri;
      return '[$cleanTitle]($cleanUri)';
    }

    final effectiveLang = (language != null && language.isNotEmpty) ? language : 'en';
    final Map<String, String> params = qp != null ? Map.from(qp.parameters) : {};
    params['transcript'] = '1';
    params['lang'] = effectiveLang;
    params['edited'] = isEdited ? '1' : '0';

    final uriWithParams = (qp != null)
        ? QuietPaperUri.asset(qp.resourceId, parameters: params).toUriString()
        : uri;

    final buffer = StringBuffer('[$cleanTitle]($uriWithParams)');
    final lines = const LineSplitter().convert(transcript.trim());
    for (final line in lines) {
      if (line.trim().isEmpty) {
        buffer.write('\n>');
      } else {
        buffer.write('\n> $line');
      }
    }

    return buffer.toString();
  }

  /// Parses a standalone audio link and extracts its URI, title, asset ID, and transcript parameters.
  static ({
    String title,
    String uri,
    String cleanUri,
    String assetId,
    bool hasTranscriptParam,
    String language,
    bool isEdited,
  })? parseAudioLink(String line) {
    final trimmed = line.trim();
    final match = _audioLinkRegex.firstMatch(trimmed);
    if (match == null) return null;

    final title = match.group(1) ?? '';
    final uri = match.group(2) ?? '';
    final assetId = match.group(3) ?? '';

    final qp = QuietPaperUri.tryParse(uri);
    final cleanUri = (qp != null)
        ? QuietPaperUri(resourceType: qp.resourceType, resourceId: qp.resourceId).toUriString()
        : 'qp://asset/$assetId';
    final hasTranscriptParam =
        qp?.parameters['transcript'] == '1' || qp?.parameters['transcript'] == 'true';
    final language = qp?.parameters['lang'] ?? 'en';
    final isEdited =
        qp?.parameters['edited'] == '1' || qp?.parameters['edited'] == 'true';

    return (
      title: title,
      uri: uri,
      cleanUri: cleanUri,
      assetId: assetId,
      hasTranscriptParam: hasTranscriptParam,
      language: language,
      isEdited: isEdited,
    );
  }

  /// Extracts all audio transcripts present in a full Markdown document, keyed by asset ID.
  static Map<String, AudioTranscriptData> extractAllTranscripts(String markdown) {
    final result = <String, AudioTranscriptData>{};
    if (markdown.isEmpty) return result;

    final lines = const LineSplitter().convert(markdown);
    for (int i = 0; i < lines.length; i++) {
      final parsed = parseAudioLink(lines[i]);
      if (parsed == null || !parsed.hasTranscriptParam) continue;

      final transcriptLines = <String>[];
      int j = i + 1;
      while (j < lines.length) {
        final nextLine = lines[j];
        final trimmed = nextLine.trim();
        if (trimmed.startsWith('>')) {
          var quoteContent = trimmed.substring(1);
          if (quoteContent.startsWith(' ')) {
            quoteContent = quoteContent.substring(1);
          }
          transcriptLines.add(quoteContent);
          j++;
        } else {
          break;
        }
      }

      if (transcriptLines.isNotEmpty) {
        final text = transcriptLines.join('\n').trim();
        result[parsed.assetId] = AudioTranscriptData(
          text: text,
          language: parsed.language,
          isEdited: parsed.isEdited,
        );
      }
    }

    return result;
  }

  /// Normalizes markdown for preview mode by stripping transcript blockquote lines
  /// following audio links so they do not render twice (once in the card and once as a quote).
  static String stripTranscriptBlockquotesForPreview(String markdown) {
    if (markdown.isEmpty) return markdown;

    final lines = const LineSplitter().convert(markdown);
    final output = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      output.add(line);

      final parsed = parseAudioLink(line);
      if (parsed != null && parsed.hasTranscriptParam) {
        // Skip subsequent immediately consecutive blockquote lines belonging to this audio link
        while (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          final trimmed = nextLine.trim();
          if (trimmed.startsWith('>')) {
            i++;
          } else {
            break;
          }
        }
      }
    }

    return output.join('\n');
  }
}
