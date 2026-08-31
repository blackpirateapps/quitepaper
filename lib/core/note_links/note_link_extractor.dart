import '../uri/quiet_paper_uri.dart';
import 'note_link_models.dart';

/// High-performance extractor for canonical internal note links `[displayText](qp://note/<UUID>)`.
abstract final class NoteLinkExtractor {
  /// Regular expression to match markdown links where URL starts with `qp://note/`.
  /// Negative lookbehind `(?<!!)` prevents matching image tags `![alt](...)`.
  static final RegExp _linkRegex = RegExp(
    r'(?<!!)\[([^\]\r\n]+)\]\((qp:\/\/note\/[^\)\r\n]+)\)',
  );

  /// Extracts all valid canonical note links from [markdown].
  ///
  /// Returns a list of [ParsedNoteLink] items with accurate UTF-16 source offsets.
  static List<ParsedNoteLink> extractLinks(String markdown) {
    if (markdown.isEmpty || !markdown.contains('qp://note/')) {
      return const [];
    }

    final results = <ParsedNoteLink>[];
    final matches = _linkRegex.allMatches(markdown);

    for (final match in matches) {
      final fullMatch = match.group(0);
      final displayText = match.group(1);
      final uriString = match.group(2);

      if (fullMatch == null || displayText == null || uriString == null) {
        continue;
      }

      // Check if bracket was escaped with a backslash `\[`
      final matchStart = match.start;
      if (matchStart > 0 && markdown[matchStart - 1] == '\\') {
        // Check if backslash itself was escaped `\\`
        var backslashCount = 0;
        var idx = matchStart - 1;
        while (idx >= 0 && markdown[idx] == '\\') {
          backslashCount++;
          idx--;
        }
        if (backslashCount % 2 == 1) {
          // Escaped bracket, skip
          continue;
        }
      }

      final uri = QuietPaperUri.tryParse(uriString.trim());
      if (uri == null || !uri.isNote || !uri.isValid) {
        continue;
      }

      results.add(
        ParsedNoteLink(
          targetNoteId: uri.resourceId,
          displayText: displayText.trim(),
          sourceOffset: matchStart,
          rawText: fullMatch,
          uri: uri,
        ),
      );
    }

    return results;
  }

  /// Extracts the unique set of target note IDs referenced in [markdown].
  static Set<String> extractTargetNoteIds(String markdown) {
    final links = extractLinks(markdown);
    return links.map((l) => l.targetNoteId).toSet();
  }

  /// Checks if [markdown] contains a link to [targetNoteId].
  static bool containsNoteLink(String markdown, String targetNoteId) {
    if (markdown.isEmpty || !markdown.contains(targetNoteId)) {
      return false;
    }
    final links = extractLinks(markdown);
    return links.any((l) => l.targetNoteId == targetNoteId);
  }
}
