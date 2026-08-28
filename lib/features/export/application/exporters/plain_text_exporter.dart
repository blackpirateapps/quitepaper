import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../domain/export_models.dart';
import '../ocr_export_resolver.dart';

/// Exporter for converting canonical Markdown to human-readable plain text (.txt).
class PlainTextExporter {
  const PlainTextExporter();

  Future<ExportResult> exportPlainText({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final buffer = StringBuffer();

    // 1. Optional text metadata header
    if (request.includeMetadata) {
      final dateFmt = DateFormat('MMMM d, yyyy h:mm a');
      if (snapshot.title.trim().isNotEmpty) {
        buffer.writeln(snapshot.title.trim());
        buffer.writeln('=' * snapshot.title.trim().length);
        buffer.writeln();
      }
      buffer.writeln('Created: ${dateFmt.format(snapshot.createdAt.toLocal())}');
      buffer.writeln('Updated: ${dateFmt.format(snapshot.updatedAt.toLocal())}');
      if (snapshot.tags.isNotEmpty) {
        buffer.writeln('Tags: ${snapshot.tags.map((t) => "#$t").join(" ")}');
      }
      buffer.writeln('-' * 40);
      buffer.writeln();
    }

    // 2. Convert Markdown body to clean plain text
    final cleanBody = convertMarkdownToPlainText(snapshot.markdown);
    buffer.write(cleanBody);

    // 3. Optional OCR transcript
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument) {
      final appendix = OcrExportResolver.formatOcrAppendix(snapshot.ocrData);
      buffer.write('\n\n');
      buffer.write(convertMarkdownToPlainText(appendix));
    }

    final content = buffer.toString().trimRight();
    final bytes = utf8.encode(content);
    await outputFile.writeAsBytes(bytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.plainText,
      filename: filename,
      byteSize: bytes.length,
      mimeType: ExportFormat.plainText.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  /// Converts markdown text to readable plain text.
  static String convertMarkdownToPlainText(String markdown) {
    if (markdown.trim().isEmpty) return '';

    var text = markdown;

    // Strip YAML frontmatter if present in markdown body
    if (text.startsWith('---')) {
      final endIndex = text.indexOf('\n---', 3);
      if (endIndex != -1) {
        text = text.substring(endIndex + 4).trimLeft();
      }
    }

    final lines = text.split('\n');
    final processedLines = <String>[];
    var inCodeBlock = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];

      // Code fences
      if (line.trim().startsWith('```') || line.trim().startsWith('~~~')) {
        inCodeBlock = !inCodeBlock;
        continue;
      }

      if (inCodeBlock) {
        processedLines.add(line);
        continue;
      }

      // Checklists: `- [x] ` or `- [ ] `
      final checkedMatch = RegExp(r'^(\s*)[-*+]\s+\[([xX])\]\s+(.*)$').firstMatch(line);
      if (checkedMatch != null) {
        final indent = checkedMatch.group(1) ?? '';
        final rest = checkedMatch.group(3) ?? '';
        processedLines.add('$indent☑ $rest');
        continue;
      }

      final uncheckedMatch = RegExp(r'^(\s*)[-*+]\s+\[\s*\]\s+(.*)$').firstMatch(line);
      if (uncheckedMatch != null) {
        final indent = uncheckedMatch.group(1) ?? '';
        final rest = uncheckedMatch.group(2) ?? '';
        processedLines.add('$indent☐ $rest');
        continue;
      }

      // Bullet lists
      final bulletMatch = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final indent = bulletMatch.group(1) ?? '';
        final rest = bulletMatch.group(2) ?? '';
        processedLines.add('$indent• $rest');
        continue;
      }

      // Headings: `# Heading` -> `Heading`
      final headingMatch = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(line);
      if (headingMatch != null) {
        final headingText = headingMatch.group(1) ?? '';
        processedLines.add(headingText);
        continue;
      }

      // Blockquotes: `> quote` -> `| quote`
      final quoteMatch = RegExp(r'^>\s*(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        final quoteText = quoteMatch.group(1) ?? '';
        processedLines.add('| $quoteText');
        continue;
      }

      // Horizontal rules: `---`, `***`, `___`
      if (RegExp(r'^[-*_]{3,}\s*$').hasMatch(line)) {
        processedLines.add('----------------------------------------');
        continue;
      }

      // Images: `![Alt](url)` -> `[Image: Alt]`
      line = line.replaceAllMapped(RegExp(r'!\[([^\]]*)\]\([^)]+\)'), (m) {
        final alt = m.group(1)?.trim();
        return alt != null && alt.isNotEmpty ? '[Image: $alt]' : '[Image]';
      });

      // Links: `[Text](url)` -> `Text (url)` or `Text`
      line = line.replaceAllMapped(RegExp(r'(?<!!)\[([^\]]+)\]\(([^)]+)\)'), (m) {
        final linkText = m.group(1)?.trim() ?? '';
        final url = m.group(2)?.trim() ?? '';
        if (url.startsWith('qp://')) {
          return linkText;
        }
        return linkText.isNotEmpty && linkText != url ? '$linkText ($url)' : url;
      });

      // Inline styles: **bold**, *italic*, ~~strikethrough~~, ==highlight==, `code`
      line = line.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'_([^_]+)_'), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'~~([^~]+)~~'), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'==([^=]+)=='), (m) => m.group(1)!);
      line = line.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);

      processedLines.add(line);
    }

    return processedLines.join('\n');
  }
}
