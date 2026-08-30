import 'heading_item.dart';

/// Lightweight, deterministic Markdown heading extractor and dynamic window computer.
/// Designed for high-frequency scrolling lookups with zero frame drop overhead.
abstract final class HeadingParser {
  /// Cleans raw heading markdown by stripping inline markdown tokens:
  /// bold, italic, strikethrough, highlight, code spans, links, images, HTML tags.
  static String cleanTitle(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';

    // Strip image syntax ![alt](url) -> alt
    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );

    // Strip link syntax [text](url) -> text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );

    // Strip bold & italic ***text***, ___text___, **text**, __text__, *text*, _text_
    text = text.replaceAllMapped(
      RegExp(r'\*{1,3}([^*\n]+)\*{1,3}'),
      (m) => m.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'_{1,3}([^_\n]+)_{1,3}'),
      (m) => m.group(1) ?? '',
    );

    // Strip strikethrough ~~text~~
    text = text.replaceAllMapped(
      RegExp(r'~~([^~\n]+)~~'),
      (m) => m.group(1) ?? '',
    );

    // Strip highlight ==text==
    text = text.replaceAllMapped(
      RegExp(r'==([^=\n]+)=='),
      (m) => m.group(1) ?? '',
    );

    // Strip inline code `text`
    text = text.replaceAllMapped(
      RegExp(r'`([^`\n]+)`'),
      (m) => m.group(1) ?? '',
    );

    // Strip HTML tags <tag>
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');

    // Collapse multiple whitespaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    return text;
  }

  /// Parses markdown document text and extracts all headings (H1 to H6).
  /// Accurately skips YAML frontmatter and fenced code blocks (` ``` ` or `~~~`).
  static List<HeadingItem> extractHeadings(String markdown) {
    if (markdown.trim().isEmpty) return const [];

    final headings = <HeadingItem>[];
    final lines = markdown.split('\n');

    var inFrontmatter = false;
    var inCodeBlock = false;
    var currentCodeFence = '';
    var currentCharOffset = 0;

    final docLength = markdown.length;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmedLine = line.trim();

      // 1. YAML frontmatter check (only at start of document)
      if (i == 0 && trimmedLine == '---') {
        inFrontmatter = true;
        currentCharOffset += line.length + 1;
        continue;
      }

      if (inFrontmatter) {
        if (trimmedLine == '---') {
          inFrontmatter = false;
        }
        currentCharOffset += line.length + 1;
        continue;
      }

      // 2. Fenced code block check (``` or ~~~)
      if (trimmedLine.startsWith('```') || trimmedLine.startsWith('~~~')) {
        final fence = trimmedLine.substring(0, 3);
        if (!inCodeBlock) {
          inCodeBlock = true;
          currentCodeFence = fence;
          currentCharOffset += line.length + 1;
          continue;
        } else if (fence == currentCodeFence) {
          inCodeBlock = false;
          currentCodeFence = '';
          currentCharOffset += line.length + 1;
          continue;
        }
      }

      if (inCodeBlock) {
        currentCharOffset += line.length + 1;
        continue;
      }

      // 3. Heading check: allows up to 3 leading spaces, 1-6 '#' characters, followed by whitespace or end of line
      final headingMatch = RegExp(r'^(\s{0,3})(#{1,6})(?:[ \t]+(.*)|$)').firstMatch(line);
      if (headingMatch != null) {
        final hashes = headingMatch.group(2) ?? '#';
        final rawTitle = headingMatch.group(3) ?? '';
        final level = hashes.length.clamp(1, 6);
        final clean = cleanTitle(rawTitle);
        final displayTitle = clean.isNotEmpty ? clean : 'Heading $level';

        final normalized = docLength > 0
            ? (currentCharOffset / docLength).clamp(0.0, 1.0)
            : 0.0;

        headings.add(
          HeadingItem(
            id: 'h_${currentCharOffset}_$i',
            rawTitle: rawTitle,
            title: displayTitle,
            level: level,
            charOffset: currentCharOffset,
            lineIndex: i,
            normalizedOffset: normalized,
          ),
        );
      }

      currentCharOffset += line.length + 1;
    }

    return headings;
  }

  /// Computes the dynamic visible window of headings around the active heading:
  /// - [headings]: full list of headings
  /// - [activeIndex]: currently active heading index (or nearest index)
  /// - [availableHeight]: available vertical height for heading labels (in dp)
  /// - [itemHeight]: average height per item including padding (default ~30.0)
  /// - [maxItems]: hard maximum of headings to display simultaneously
  static List<HeadingItem> computeVisibleWindow({
    required List<HeadingItem> headings,
    required int activeIndex,
    double availableHeight = 600.0,
    double itemHeight = 30.0,
    int maxItems = 8,
  }) {
    if (headings.isEmpty) return const [];
    if (headings.length == 1) return headings;

    final maxFitting = (availableHeight / itemHeight).floor().clamp(1, maxItems);
    if (headings.length <= maxFitting) {
      return headings;
    }

    final windowSize = maxFitting.clamp(1, headings.length);
    final clampedActive = activeIndex.clamp(0, headings.length - 1);

    var start = clampedActive - (windowSize ~/ 2);
    if (start < 0) {
      start = 0;
    } else if (start + windowSize > headings.length) {
      start = headings.length - windowSize;
    }

    return headings.sublist(start, start + windowSize);
  }

  /// Binary searches for the active heading index for a given scroll position [scrollOffset]
  /// against a list of target scroll offsets [headingOffsets].
  static int findActiveHeadingIndex({
    required double scrollOffset,
    required List<double> headingOffsets,
    double topThreshold = 40.0,
  }) {
    if (headingOffsets.isEmpty) return -1;
    if (headingOffsets.length == 1) return 0;

    if (scrollOffset <= headingOffsets.first - topThreshold) {
      return 0;
    }
    if (scrollOffset >= headingOffsets.last - topThreshold) {
      return headingOffsets.length - 1;
    }

    // Binary search for the last heading where headingOffset - topThreshold <= scrollOffset
    var low = 0;
    var high = headingOffsets.length - 1;
    var result = 0;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final offset = headingOffsets[mid];

      if (offset - topThreshold <= scrollOffset) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }
}
