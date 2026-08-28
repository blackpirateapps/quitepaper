import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../domain/export_models.dart';
import '../ocr_export_resolver.dart';

/// Exporter for generating canonical Markdown (.md) documents.
class MarkdownExporter {
  const MarkdownExporter();

  Future<ExportResult> exportMarkdown({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final buffer = StringBuffer();

    // 1. Optional YAML Frontmatter metadata
    if (request.includeMetadata) {
      final isoDate = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
      buffer.writeln('---');
      buffer.writeln('title: "${_escapeYamlString(snapshot.title)}"');
      buffer.writeln('created: ${isoDate.format(snapshot.createdAt.toUtc())}');
      buffer.writeln('updated: ${isoDate.format(snapshot.updatedAt.toUtc())}');
      if (snapshot.isPinned) buffer.writeln('pinned: true');
      if (snapshot.isArchived) buffer.writeln('archived: true');
      if (snapshot.isTrashed) {
        buffer.writeln('trashed: true');
        if (snapshot.deletedAt != null) {
          buffer.writeln('deletedAt: ${isoDate.format(snapshot.deletedAt!.toUtc())}');
        }
      }
      if (snapshot.tags.isNotEmpty) {
        buffer.writeln('tags:');
        for (final tag in snapshot.tags) {
          buffer.writeln('  - ${_escapeYamlString(tag)}');
        }
      }
      buffer.writeln('---');
      buffer.writeln();
    }

    // 2. Canonical Markdown Body
    buffer.write(snapshot.markdown);

    // 3. Optional OCR appendix
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument) {
      final appendix = OcrExportResolver.formatOcrAppendix(snapshot.ocrData);
      buffer.write(appendix);
    }

    final content = buffer.toString();
    final bytes = utf8.encode(content);
    await outputFile.writeAsBytes(bytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.markdown,
      filename: filename,
      byteSize: bytes.length,
      mimeType: ExportFormat.markdown.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static String _escapeYamlString(String str) {
    return str.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }
}
