import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../features/export/domain/export_models.dart';
import 'pdf_code_highlighter.dart';
import 'pdf_font_manager.dart';
import 'pdf_markdown_models.dart';

/// Document layout engine converting semantic PDF blocks and note snapshots into vector PDF widgets.
class PdfDocumentBuilder {
  const PdfDocumentBuilder();

  /// Converts a sequence of [PdfBlock] items and note snapshot metadata into a complete PDF widget list.
  List<pw.Widget> buildWidgets({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required List<PdfBlock> blocks,
    required PdfTypographyTheme typography,
    required List<ExportWarning> warnings,
  }) {
    final widgets = <pw.Widget>[];
    final pdfOptions = request.pdfOptions;
    final dateFmt = DateFormat('MMMM d, yyyy');

    // 1. Document Title
    widgets.add(
      pw.Header(
        level: 0,
        margin: const pw.EdgeInsets.only(bottom: 12),
        text: snapshot.effectiveTitle,
        textStyle: pw.TextStyle(
          font: typography.bold,
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('#111827'),
        ),
      ),
    );

    // 2. Metadata Card (if enabled)
    if (request.includeMetadata && pdfOptions.includeMetadata) {
      final metaRows = <pw.Widget>[];

      if (pdfOptions.showDates) {
        metaRows.add(
          pw.Row(
            children: [
              pw.Text(
                'Created: ',
                style: pw.TextStyle(font: typography.bold, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                dateFmt.format(snapshot.createdAt.toLocal()),
                style: pw.TextStyle(font: typography.regular, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(width: 16),
              pw.Text(
                'Updated: ',
                style: pw.TextStyle(font: typography.bold, fontSize: 9, color: PdfColors.grey700),
              ),
              pw.Text(
                dateFmt.format(snapshot.updatedAt.toLocal()),
                style: pw.TextStyle(font: typography.regular, fontSize: 9, color: PdfColors.grey700),
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
                  style: pw.TextStyle(font: typography.bold, fontSize: 9, color: PdfColors.grey700),
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
                          style: pw.TextStyle(
                            font: typography.regular,
                            fontSize: 8.5,
                            color: PdfColor.fromHex('#B45309'),
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
        widgets.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#F9F9F8'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColor.fromHex('#E5E3DC'), width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: metaRows,
            ),
          ),
        );
      }
    }

    // 3. Render Markdown Blocks
    for (final block in blocks) {
      if (block is PdfHeadingBlock) {
        widgets.add(_buildHeading(block, typography));
      } else if (block is PdfParagraphBlock) {
        widgets.add(_buildParagraph(block, typography));
      } else if (block is PdfListBlock) {
        widgets.add(_buildList(block, typography));
      } else if (block is PdfChecklistBlock) {
        widgets.add(_buildChecklist(block, typography));
      } else if (block is PdfBlockquoteBlock) {
        widgets.add(_buildBlockquote(block, typography));
      } else if (block is PdfCodeBlock) {
        widgets.add(_buildCodeBlock(block, typography));
      } else if (block is PdfTableBlock) {
        widgets.add(_buildTable(block, typography));
      } else if (block is PdfImageBlock) {
        widgets.add(_buildImage(block, typography, warnings));
      } else if (block is PdfHorizontalRuleBlock) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 10),
            child: pw.Divider(color: PdfColor.fromHex('#E5E3DC'), thickness: 0.8),
          ),
        );
      }
    }

    // 4. Optional OCR Appendix
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument && snapshot.ocrData.isNotEmpty) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 24, bottom: 8),
          child: pw.Divider(color: PdfColors.grey400, thickness: 1),
        ),
      );
      widgets.add(
        pw.Text(
          'Document OCR Transcripts',
          style: pw.TextStyle(
            font: typography.bold,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
      );

      for (final item in snapshot.ocrData) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
            child: pw.Text(
              '${item.resourceType == "document" ? "Document" : "Image"} OCR (${item.document.language.displayName})',
              style: pw.TextStyle(font: typography.bold, fontSize: 11, color: PdfColors.grey700),
            ),
          ),
        );

        for (final page in item.document.pages) {
          if (item.document.pages.length > 1) {
            widgets.add(
              pw.Text(
                'Page ${page.pageNumber}',
                style: pw.TextStyle(font: typography.italic, fontSize: 9.5, color: PdfColors.grey600),
              ),
            );
          }
          widgets.add(
            pw.Container(
              width: double.infinity,
              margin: const pw.EdgeInsets.only(top: 4, bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8F8F6'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColor.fromHex('#E5E3DC'), width: 0.5),
              ),
              child: pw.Text(
                page.plainText.trim(),
                style: pw.TextStyle(font: typography.mono, fontSize: 8.5, color: PdfColors.grey900),
              ),
            ),
          );
        }
      }
    }

    return widgets;
  }

  pw.Widget _buildHeading(PdfHeadingBlock heading, PdfTypographyTheme typography) {
    double fontSize;
    double topPadding;
    double bottomPadding;

    switch (heading.level) {
      case 1:
        fontSize = 18;
        topPadding = 14;
        bottomPadding = 6;
        break;
      case 2:
        fontSize = 15;
        topPadding = 12;
        bottomPadding = 5;
        break;
      case 3:
        fontSize = 13;
        topPadding = 10;
        bottomPadding = 4;
        break;
      case 4:
        fontSize = 11.5;
        topPadding = 8;
        bottomPadding = 3;
        break;
      case 5:
        fontSize = 10.5;
        topPadding = 6;
        bottomPadding = 2;
        break;
      case 6:
      default:
        fontSize = 9.5;
        topPadding = 5;
        bottomPadding = 2;
        break;
    }

    return pw.Header(
      level: heading.level,
      margin: pw.EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      textStyle: pw.TextStyle(
        font: typography.bold,
        fontSize: fontSize,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#111827'),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: _buildInlineSpans(
            inlines: heading.inlines,
            typography: typography,
            baseFontSize: fontSize,
            isHeading: true,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildParagraph(PdfParagraphBlock paragraph, PdfTypographyTheme typography) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.RichText(
        text: pw.TextSpan(
          children: _buildInlineSpans(
            inlines: paragraph.inlines,
            typography: typography,
            baseFontSize: 10.5,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildList(PdfListBlock list, PdfTypographyTheme typography) {
    final rows = <pw.Widget>[];

    for (var i = 0; i < list.items.length; i++) {
      final item = list.items[i];
      final indentLeft = item.indentLevel * 14.0;

      pw.Widget bulletWidget;
      if (list.isOrdered) {
        final numLabel = '${item.number ?? (i + 1)}.';
        bulletWidget = pw.Container(
          width: 18,
          alignment: pw.Alignment.topRight,
          margin: const pw.EdgeInsets.only(right: 6),
          child: pw.Text(
            numLabel,
            style: pw.TextStyle(
              font: typography.bold,
              fontSize: 10,
              color: PdfColors.grey800,
            ),
          ),
        );
      } else {
        // Unordered bullet glyph based on nesting level
        bulletWidget = pw.Padding(
          padding: const pw.EdgeInsets.only(top: 3.5, right: 6, left: 2),
          child: pw.Container(
            width: item.indentLevel == 0 ? 3.5 : 3.0,
            height: item.indentLevel == 0 ? 3.5 : 3.0,
            decoration: pw.BoxDecoration(
              color: item.indentLevel == 1 ? null : PdfColors.grey800,
              shape: pw.BoxShape.circle,
              border: item.indentLevel == 1 ? pw.Border.all(color: PdfColors.grey800, width: 0.8) : null,
            ),
          ),
        );
      }

      rows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: indentLeft, top: 1.5, bottom: 1.5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              bulletWidget,
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: _buildInlineSpans(
                      inlines: item.inlines,
                      typography: typography,
                      baseFontSize: 10.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  pw.Widget _buildChecklist(PdfChecklistBlock checklist, PdfTypographyTheme typography) {
    final rows = <pw.Widget>[];

    for (final item in checklist.items) {
      final indentLeft = item.indentLevel * 14.0;

      final checkboxWidget = item.isChecked
          ? pw.Container(
              width: 11,
              height: 11,
              margin: const pw.EdgeInsets.only(top: 1.5, right: 7),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#D97706'), // Warm accent
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
              child: pw.Center(
                child: pw.Text(
                  'X',
                  style: pw.TextStyle(
                    font: typography.bold,
                    color: PdfColors.white,
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            )
          : pw.Container(
              width: 11,
              height: 11,
              margin: const pw.EdgeInsets.only(top: 1.5, right: 7),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: 0.9),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
              ),
            );

      rows.add(
        pw.Padding(
          padding: pw.EdgeInsets.only(left: indentLeft, top: 2, bottom: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              checkboxWidget,
              pw.Expanded(
                child: pw.RichText(
                  text: pw.TextSpan(
                    children: _buildInlineSpans(
                      inlines: item.inlines,
                      typography: typography,
                      baseFontSize: 10.5,
                      forceStrike: item.isChecked,
                      forceMuted: item.isChecked,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  pw.Widget _buildBlockquote(PdfBlockquoteBlock blockquote, PdfTypographyTheme typography) {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 4),
      padding: const pw.EdgeInsets.only(left: 10, top: 4, bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColor.fromInt(0xFFD97706), width: 2.8)),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: _buildInlineSpans(
            inlines: blockquote.inlines,
            typography: typography,
            baseFontSize: 10.5,
            isItalicDefault: true,
            baseColor: PdfColor.fromHex('#4B5563'),
          ),
        ),
      ),
    );
  }

  pw.Widget _buildCodeBlock(PdfCodeBlock codeBlock, PdfTypographyTheme typography) {
    final highlightedLines = PdfCodeHighlighter.highlightLines(codeBlock.code, codeBlock.language);

    final lineSpans = <pw.TextSpan>[];
    for (var i = 0; i < highlightedLines.length; i++) {
      final lineTokens = highlightedLines[i];
      final lineSpan = PdfCodeHighlighter.buildLineSpan(lineTokens, typography, 9.0);
      lineSpans.add(lineSpan);
      if (i < highlightedLines.length - 1) {
        lineSpans.add(const pw.TextSpan(text: '\n'));
      }
    }

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F8F8F6'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
        border: pw.Border.all(color: PdfColor.fromHex('#E5E3DC'), width: 0.6),
      ),
      child: pw.RichText(
        text: pw.TextSpan(
          children: lineSpans,
        ),
      ),
    );
  }

  pw.Widget _buildTable(PdfTableBlock table, PdfTypographyTheme typography) {
    final tableRows = <pw.TableRow>[];

    // Header Row
    if (table.headers.isNotEmpty) {
      final headerCells = <pw.Widget>[];
      for (var col = 0; col < table.headers.length; col++) {
        final align = col < table.alignments.length ? table.alignments[col] : PdfTableCellAlignment.left;
        final cellAlign = _mapAlignment(align);

        headerCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            alignment: cellAlign,
            child: pw.RichText(
              textAlign: _mapTextAlign(align),
              text: pw.TextSpan(
                children: _buildInlineSpans(
                  inlines: table.headers[col],
                  typography: typography,
                  baseFontSize: 9.5,
                  isHeading: true,
                ),
              ),
            ),
          ),
        );
      }

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F3F2EE')),
          children: headerCells,
        ),
      );
    }

    // Body Rows
    for (final row in table.rows) {
      final bodyCells = <pw.Widget>[];
      for (var col = 0; col < row.length; col++) {
        final align = col < table.alignments.length ? table.alignments[col] : PdfTableCellAlignment.left;
        final cellAlign = _mapAlignment(align);

        bodyCells.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            alignment: cellAlign,
            child: pw.RichText(
              textAlign: _mapTextAlign(align),
              text: pw.TextSpan(
                children: _buildInlineSpans(
                  inlines: row[col],
                  typography: typography,
                  baseFontSize: 9.0,
                ),
              ),
            ),
          ),
        );
      }

      tableRows.add(
        pw.TableRow(
          children: bodyCells,
        ),
      );
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColor.fromHex('#D1D5DB'), width: 0.6),
        children: tableRows,
      ),
    );
  }

  pw.Alignment _mapAlignment(PdfTableCellAlignment align) {
    switch (align) {
      case PdfTableCellAlignment.center:
        return pw.Alignment.center;
      case PdfTableCellAlignment.right:
        return pw.Alignment.centerRight;
      case PdfTableCellAlignment.left:
        return pw.Alignment.centerLeft;
    }
  }

  pw.TextAlign _mapTextAlign(PdfTableCellAlignment align) {
    switch (align) {
      case PdfTableCellAlignment.center:
        return pw.TextAlign.center;
      case PdfTableCellAlignment.right:
        return pw.TextAlign.right;
      case PdfTableCellAlignment.left:
        return pw.TextAlign.left;
    }
  }

  pw.Widget _buildImage(
    PdfImageBlock imageBlock,
    PdfTypographyTheme typography,
    List<ExportWarning> warnings,
  ) {
    if (imageBlock.hasBytes) {
      try {
        final pdfImage = pw.MemoryImage(imageBlock.bytes!);
        return pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(maxHeight: 280, maxWidth: 460),
                child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
              ),
              if (imageBlock.alt.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 4),
                  child: pw.Text(
                    imageBlock.alt,
                    style: pw.TextStyle(
                      font: typography.italic,
                      fontSize: 8.5,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
            ],
          ),
        );
      } catch (e) {
        warnings.add(
          ExportWarning(
            type: ExportWarningType.attachmentUnavailable,
            message: 'Failed to embed image: ${imageBlock.uri}',
            details: e.toString(),
          ),
        );
      }
    }

    // Placeholder if image is missing or invalid
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F9FAFB'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColor.fromHex('#E5E7EB'), width: 0.8),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '[Image unavailable: ${imageBlock.alt.isNotEmpty ? imageBlock.alt : imageBlock.uri}]',
            style: pw.TextStyle(
              font: typography.italic,
              fontSize: 9,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  List<pw.InlineSpan> _buildInlineSpans({
    required List<PdfInlineRun> inlines,
    required PdfTypographyTheme typography,
    required double baseFontSize,
    bool isHeading = false,
    bool isItalicDefault = false,
    bool forceStrike = false,
    bool forceMuted = false,
    PdfColor? baseColor,
  }) {
    final spans = <pw.InlineSpan>[];
    final defaultColor = baseColor ?? (forceMuted ? PdfColors.grey600 : PdfColor.fromHex('#1F2937'));

    for (final run in inlines) {
      if (run.text.isEmpty) continue;

      pw.Font font;
      final isBold = run.isBold || isHeading;
      final isItalic = run.isItalic || isItalicDefault;

      if (run.isCode) {
        font = isBold ? typography.monoBold : typography.mono;
      } else if (isBold && isItalic) {
        font = typography.boldItalic;
      } else if (isBold) {
        font = typography.bold;
      } else if (isItalic) {
        font = typography.italic;
      } else {
        font = typography.regular;
      }

      PdfColor color = defaultColor;
      pw.BoxDecoration? background;
      pw.TextDecoration? decoration;

      if (forceStrike || run.isStrike) {
        decoration = pw.TextDecoration.lineThrough;
      }

      if (run.isHighlight) {
        background = const pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFDE68A), // Warm yellow highlight
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
        );
        color = PdfColor.fromHex('#78350F'); // Dark amber text
      } else if (run.isCode) {
        background = pw.BoxDecoration(
          color: PdfColor.fromHex('#F3F2EE'),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        );
        color = PdfColor.fromHex('#B45309');
      } else if (run.isTag) {
        color = PdfColor.fromHex('#B45309');
      } else if (run.isLink) {
        color = PdfColor.fromHex('#B45309');
        decoration = pw.TextDecoration.underline;
      }

      final textStyle = pw.TextStyle(
        font: font,
        fontSize: run.isCode ? baseFontSize * 0.92 : baseFontSize,
        color: color,
        fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontStyle: isItalic ? pw.FontStyle.italic : pw.FontStyle.normal,
        background: background,
        decoration: decoration,
        lineSpacing: 2.5,
      );

      if (run.isLink) {
        spans.add(
          pw.TextSpan(
            text: run.text,
            style: textStyle,
            annotation: pw.AnnotationUrl(run.linkUrl!),
          ),
        );
      } else {
        spans.add(
          pw.TextSpan(
            text: run.text,
            style: textStyle,
          ),
        );
      }
    }

    return spans;
  }
}
