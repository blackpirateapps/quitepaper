import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/export_models.dart';

/// Exporter for compiling notes into searchable, vector text PDF documents (.pdf).
class PdfExporter {
  const PdfExporter();

  Future<ExportResult> exportPdf({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final pdfDoc = pw.Document(
      title: snapshot.effectiveTitle,
      author: 'Quiet Paper',
      creator: 'Quiet Paper Export Subsystem',
    );

    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontItalic = pw.Font.helveticaOblique();
    final fontMono = pw.Font.courier();

    final theme = pw.ThemeData.withFont(
      base: fontRegular,
      bold: fontBold,
      italic: fontItalic,
      fontFallback: [fontRegular],
    );

    final pdfOptions = request.pdfOptions;
    final dateFmt = DateFormat('MMMM d, yyyy');

    // Build attachment byte map by path / uri
    final imageMap = <String, Uint8List>{};
    for (final att in snapshot.attachments) {
      if (att.hasBytes) {
        imageMap[att.relativePath] = att.bytes!;
        imageMap['qp://asset/${att.id}'] = att.bytes!;
      }
    }

    // Parse Markdown into PDF widget blocks
    var markdownBody = snapshot.markdown;
    if (markdownBody.startsWith('---')) {
      final endIndex = markdownBody.indexOf('\n---', 3);
      if (endIndex != -1) {
        markdownBody = markdownBody.substring(endIndex + 4).trimLeft();
      }
    }

    final contentWidgets = <pw.Widget>[];

    // Document Title
    contentWidgets.add(
      pw.Header(
        level: 0,
        margin: const pw.EdgeInsets.only(bottom: 12),
        text: snapshot.effectiveTitle,
        textStyle: pw.TextStyle(
          font: fontBold,
          fontSize: 24,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey900,
        ),
      ),
    );

    // Metadata Card
    if (request.includeMetadata && pdfOptions.includeMetadata) {
      final metaRows = <pw.Widget>[];

      if (pdfOptions.showDates) {
        metaRows.add(
          pw.Row(
            children: [
              pw.Text(
                'Created: ',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                dateFmt.format(snapshot.createdAt.toLocal()),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                'Updated: ',
                style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                dateFmt.format(snapshot.updatedAt.toLocal()),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ],
          ),
        );
      }

      if (pdfOptions.showTags && snapshot.tags.isNotEmpty) {
        metaRows.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Tags: ',
                  style: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: snapshot.tags.map((t) {
                      return pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey200,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        ),
                        child: pw.Text(
                          '#$t',
                          style: const pw.TextStyle(
                            fontSize: 8.5,
                            color: PdfColors.amber900,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (metaRows.isNotEmpty) {
        contentWidgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 18),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: metaRows,
            ),
          ),
        );
      }
    }

    // Parse Body Lines into PDF components
    final parsedBodyWidgets = _parseMarkdownToPdfWidgets(
      markdown: markdownBody,
      fontRegular: fontRegular,
      fontBold: fontBold,
      fontItalic: fontItalic,
      fontMono: fontMono,
      imageMap: imageMap,
      includeAttachments: pdfOptions.includeAttachments,
    );
    contentWidgets.addAll(parsedBodyWidgets);

    // Optional OCR Appendix
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument && snapshot.ocrData.isNotEmpty) {
      contentWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 24, bottom: 8),
          child: pw.Divider(color: PdfColors.grey400, thickness: 1),
        ),
      );
      contentWidgets.add(
        pw.Text(
          'Document OCR Transcripts',
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      );

      for (final item in snapshot.ocrData) {
        contentWidgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              '${item.resourceType == "document" ? "Document" : "Image"} OCR (${item.document.language.displayName})',
              style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700),
            ),
          ),
        );

        for (final page in item.document.pages) {
          if (item.document.pages.length > 1) {
            contentWidgets.add(
              pw.Text(
                'Page ${page.pageNumber}',
                style: pw.TextStyle(font: fontItalic, fontSize: 9.5, color: PdfColors.grey600),
              ),
            );
          }
          contentWidgets.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Text(
                page.plainText.trim(),
                style: pw.TextStyle(font: fontMono, fontSize: 8.5, color: PdfColors.grey900),
              ),
            ),
          );
        }
      }
    }

    // Add multi-page document layout
    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Text(
                snapshot.effectiveTitle,
                style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey500),
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey500),
            ),
          );
        },
        build: (pw.Context context) => contentWidgets,
      ),
    );

    final bytes = await pdfDoc.save();
    await outputFile.writeAsBytes(bytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.pdf,
      filename: filename,
      byteSize: bytes.length,
      mimeType: ExportFormat.pdf.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static List<pw.Widget> _parseMarkdownToPdfWidgets({
    required String markdown,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Font fontItalic,
    required pw.Font fontMono,
    required Map<String, Uint8List> imageMap,
    required bool includeAttachments,
  }) {
    final widgets = <pw.Widget>[];
    final lines = markdown.split('\n');

    var inCodeBlock = false;
    final codeBlockLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Code blocks ```
      if (line.trim().startsWith('```') || line.trim().startsWith('~~~')) {
        if (inCodeBlock) {
          // Finish code block
          final codeText = codeBlockLines.join('\n');
          widgets.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.symmetric(vertical: 8),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
              ),
              child: pw.Text(
                codeText,
                style: pw.TextStyle(font: fontMono, fontSize: 9.5, color: PdfColors.grey900),
              ),
            ),
          );
          codeBlockLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          codeBlockLines.clear();
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(pw.SizedBox(height: 6));
        continue;
      }

      // Check if image `![alt](url)`
      final imgMatch = RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(trimmed);
      if (imgMatch != null) {
        if (includeAttachments) {
          final uri = imgMatch.group(2)!.trim();
          final bytes = imageMap[uri];
          if (bytes != null && bytes.isNotEmpty) {
            try {
              final pdfImage = pw.MemoryImage(bytes);
              widgets.add(
                pw.Container(
                  alignment: pw.Alignment.center,
                  margin: const pw.EdgeInsets.symmetric(vertical: 8),
                  child: pw.ConstrainedBox(
                    constraints: const pw.BoxConstraints(maxHeight: 280, maxWidth: 460),
                    child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
                  ),
                ),
              );
              continue;
            } catch (_) {}
          }
        }
      }

      // Headings # .. ######
      final h1Match = RegExp(r'^#\s+(.*)$').firstMatch(line);
      if (h1Match != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
            child: pw.Text(
              h1Match.group(1)!,
              style: pw.TextStyle(font: fontBold, fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        continue;
      }

      final h2Match = RegExp(r'^##\s+(.*)$').firstMatch(line);
      if (h2Match != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 12, bottom: 5),
            child: pw.Text(
              h2Match.group(1)!,
              style: pw.TextStyle(font: fontBold, fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        continue;
      }

      final h3Match = RegExp(r'^###\s+(.*)$').firstMatch(line);
      if (h3Match != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(
              h3Match.group(1)!,
              style: pw.TextStyle(font: fontBold, fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        continue;
      }

      final hOtherMatch = RegExp(r'^#{4,6}\s+(.*)$').firstMatch(line);
      if (hOtherMatch != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              hOtherMatch.group(1)!,
              style: pw.TextStyle(font: fontBold, fontSize: 11.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
        continue;
      }

      // Blockquote `> quote`
      final quoteMatch = RegExp(r'^>\s*(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 4),
            padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(left: pw.BorderSide(color: PdfColors.amber800, width: 2.5)),
            ),
            child: pw.Text(
              quoteMatch.group(1)!,
              style: pw.TextStyle(font: fontItalic, fontSize: 10.5, color: PdfColors.grey800),
            ),
          ),
        );
        continue;
      }

      // Checkboxes `- [x] ` or `- [ ] `
      final checkedMatch = RegExp(r'^(\s*)[-*+]\s+\[([xX])\]\s+(.*)$').firstMatch(line);
      if (checkedMatch != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 11,
                  height: 11,
                  margin: const pw.EdgeInsets.only(top: 1.5, right: 6),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.amber700,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'X',
                      style: pw.TextStyle(
                        font: fontBold,
                        color: PdfColors.white,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    checkedMatch.group(3)!,
                    style: pw.TextStyle(
                      fontSize: 10.5,
                      color: PdfColors.grey700,
                      decoration: pw.TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final uncheckedMatch = RegExp(r'^(\s*)[-*+]\s+\[\s*\]\s+(.*)$').firstMatch(line);
      if (uncheckedMatch != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: 11,
                  height: 11,
                  margin: const pw.EdgeInsets.only(top: 1.5, right: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey500, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    uncheckedMatch.group(2)!,
                    style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet lists
      final bulletMatch = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 4),
                  child: pw.Container(
                    width: 3.5,
                    height: 3.5,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey800,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    bulletMatch.group(2)!,
                    style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Horizontal rules
      if (RegExp(r'^[-*_]{3,}\s*$').hasMatch(trimmed)) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Divider(color: PdfColors.grey300, thickness: 0.8),
          ),
        );
        continue;
      }

      // Standard paragraph
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
          child: pw.Text(
            line,
            style: const pw.TextStyle(fontSize: 10.5, color: PdfColors.grey900, lineSpacing: 2.5),
          ),
        ),
      );
    }

    return widgets;
  }
}
