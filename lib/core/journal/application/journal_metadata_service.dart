import '../domain/journal_date_helper.dart';

class JournalMetadata {
  const JournalMetadata({
    required this.isJournal,
    this.journalDate,
  });

  final bool isJournal;
  final String? journalDate;

  static const none = JournalMetadata(isJournal: false, journalDate: null);
}

/// Service for creating, extracting, normalizing, and updating application-managed
/// YAML frontmatter for journal notes.
abstract final class JournalMetadataService {
  static final RegExp _frontmatterRegex = RegExp(
    r'^\s*---\r?\n([\s\S]*?)\r?\n(?:---|\.\.\.)\r?\n?',
  );

  /// Generates the initial canonical Markdown content for a new journal entry.
  static String createInitialJournalContent({
    required String journalDate,
    String body = '',
  }) {
    final cleanDate = JournalDateHelper.isValidDateString(journalDate)
        ? journalDate.trim()
        : JournalDateHelper.todayString();

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.writeln('journal: true');
    buffer.writeln('date: $cleanDate');
    buffer.writeln('---');
    if (body.isNotEmpty) {
      buffer.writeln();
      buffer.write(body);
    }
    return buffer.toString();
  }

  /// Extracts journal metadata (`isJournal` and `journalDate`) from Markdown content.
  static JournalMetadata extractJournalMetadata(String content) {
    if (content.isEmpty) return JournalMetadata.none;

    final match = _frontmatterRegex.firstMatch(content);
    if (match == null) return JournalMetadata.none;

    final block = match.group(1) ?? '';
    final lines = block.split(RegExp(r'\r?\n'));

    bool isJournal = false;
    String? dateStr;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final colonIndex = trimmed.indexOf(':');
      if (colonIndex == -1) continue;

      final key = trimmed.substring(0, colonIndex).trim().toLowerCase().replaceAll('-', '_');
      var val = trimmed.substring(colonIndex + 1).trim();

      // Strip optional quotes
      if ((val.startsWith('"') && val.endsWith('"')) ||
          (val.startsWith("'") && val.endsWith("'"))) {
        if (val.length >= 2) {
          val = val.substring(1, val.length - 1).trim();
        }
      }

      if (key == 'journal') {
        final lower = val.toLowerCase();
        if (lower == 'true' || lower == 'yes' || lower == '1') {
          isJournal = true;
        }
      } else if (key == 'date') {
        if (JournalDateHelper.isValidDateString(val)) {
          dateStr = val;
        } else {
          // Attempt parsing date if formatted differently
          final parsed = JournalDateHelper.tryParseDateString(val);
          if (parsed != null) {
            dateStr = JournalDateHelper.toDateString(parsed);
          }
        }
      }
    }

    if (isJournal && dateStr != null) {
      return JournalMetadata(isJournal: true, journalDate: dateStr);
    } else if (isJournal) {
      return const JournalMetadata(isJournal: true, journalDate: null);
    } else if (dateStr != null) {
      // Only classified as journal entry if `journal: true` is explicitly specified
      return JournalMetadata(isJournal: false, journalDate: dateStr);
    }

    return JournalMetadata.none;
  }

  /// Ensures that [content] contains canonical, application-managed journal frontmatter
  /// with `journal: true` and `date: [journalDate]`.
  ///
  /// This operation is 100% idempotent and preserves any pre-existing frontmatter properties.
  static String ensureJournalFrontmatter({
    required String content,
    required String journalDate,
  }) {
    final cleanDate = JournalDateHelper.isValidDateString(journalDate)
        ? journalDate.trim()
        : JournalDateHelper.todayString();

    if (content.isEmpty) {
      return createInitialJournalContent(journalDate: cleanDate);
    }

    final match = _frontmatterRegex.firstMatch(content);
    if (match == null) {
      // No existing frontmatter: prepend frontmatter block cleanly
      final cleanContent = content.startsWith('\n') ? content : '\n$content';
      return '---\njournal: true\ndate: $cleanDate\n---$cleanContent';
    }

    final block = match.group(1) ?? '';
    final remainder = content.substring(match.end);
    final lines = block.split(RegExp(r'\r?\n'));

    final updatedLines = <String>[];
    bool hasJournalKey = false;
    bool hasDateKey = false;

    for (final line in lines) {
      final trimmed = line.trim();
      final colonIndex = trimmed.indexOf(':');

      if (colonIndex != -1) {
        final key = trimmed.substring(0, colonIndex).trim().toLowerCase().replaceAll('-', '_');
        if (key == 'journal') {
          if (!hasJournalKey) {
            updatedLines.add('journal: true');
            hasJournalKey = true;
          }
          continue;
        } else if (key == 'date') {
          if (!hasDateKey) {
            updatedLines.add('date: $cleanDate');
            hasDateKey = true;
          }
          continue;
        }
      }

      updatedLines.add(line);
    }

    // Insert missing keys at the beginning if they were not present
    final finalLines = <String>[];
    if (!hasJournalKey) {
      finalLines.add('journal: true');
    }
    if (!hasDateKey) {
      finalLines.add('date: $cleanDate');
    }
    finalLines.addAll(updatedLines);

    final newFrontmatter = finalLines.join('\n');
    return '---\n$newFrontmatter\n---\n$remainder';
  }

  /// Removes `journal: ...` and `date: ...` from frontmatter in [content] (e.g. for conflict copies).
  static String removeJournalFrontmatter(String content) {
    if (content.isEmpty) return content;

    final match = _frontmatterRegex.firstMatch(content);
    if (match == null) return content;

    final block = match.group(1) ?? '';
    final remainder = content.substring(match.end);
    final lines = block.split(RegExp(r'\r?\n'));

    final remainingLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      final colonIndex = trimmed.indexOf(':');
      if (colonIndex != -1) {
        final key = trimmed.substring(0, colonIndex).trim().toLowerCase().replaceAll('-', '_');
        if (key == 'journal' || key == 'date') {
          continue;
        }
      }
      if (trimmed.isNotEmpty) {
        remainingLines.add(line);
      }
    }

    if (remainingLines.isEmpty) {
      return remainder.trimLeft();
    }

    return '---\n${remainingLines.join('\n')}\n---\n$remainder';
  }
}
