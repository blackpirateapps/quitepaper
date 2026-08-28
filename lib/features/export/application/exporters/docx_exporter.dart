import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import '../../domain/export_models.dart';
import '../export_security_guard.dart';

/// Exporter for compiling notes into standards-compliant Microsoft Word OpenXML (.docx) packages.
class DocxExporter {
  const DocxExporter();

  Future<ExportResult> exportDocx({
    required NoteExportSnapshot snapshot,
    required ExportRequest request,
    required File outputFile,
  }) async {
    final stopwatch = Stopwatch()..start();
    final warnings = <ExportWarning>[];

    final dateFmt = DateFormat('MMMM d, yyyy');

    // 1. Build document.xml body content
    final docBodyBuffer = StringBuffer();

    // Document Title
    docBodyBuffer.writeln(_buildHeadingXml(snapshot.effectiveTitle, level: 0));

    // Metadata Card
    if (request.includeMetadata && request.docxOptions.includeMetadata) {
      final metaLines = <String>[
        'Created: ${dateFmt.format(snapshot.createdAt.toLocal())}',
        'Updated: ${dateFmt.format(snapshot.updatedAt.toLocal())}',
        if (snapshot.tags.isNotEmpty)
          'Tags: ${snapshot.tags.map((t) => "#$t").join(" ")}',
      ];

      docBodyBuffer.writeln(_buildMetadataBoxXml(metaLines));
    }

    // Markdown Body
    var markdownBody = snapshot.markdown;
    if (markdownBody.startsWith('---')) {
      final endIndex = markdownBody.indexOf('\n---', 3);
      if (endIndex != -1) {
        markdownBody = markdownBody.substring(endIndex + 4).trimLeft();
      }
    }

    final bodyXml = _parseMarkdownToDocxXml(markdownBody);
    docBodyBuffer.writeln(bodyXml);

    // Optional OCR Appendix
    if (request.includeOcr && request.ocrStrategy == OcrExportStrategy.appendToDocument && snapshot.ocrData.isNotEmpty) {
      docBodyBuffer.writeln(_buildHorizontalRuleXml());
      docBodyBuffer.writeln(_buildHeadingXml('Document OCR Transcripts', level: 1));

      for (final item in snapshot.ocrData) {
        docBodyBuffer.writeln(
          _buildHeadingXml(
            '${item.resourceType == "document" ? "Document" : "Image"} OCR (${item.document.language.displayName})',
            level: 2,
          ),
        );

        for (final page in item.document.pages) {
          if (item.document.pages.length > 1) {
            docBodyBuffer.writeln(_buildParagraphXml('Page ${page.pageNumber}', isItalic: true));
          }
          docBodyBuffer.writeln(_buildCodeBlockXml(page.plainText.trim()));
        }
      }
    }

    // 2. Assemble OpenXML Package Files
    final archive = Archive();

    // [Content_Types].xml
    archive.addFile(
      ArchiveFile(
        '[Content_Types].xml',
        utf8.encode(_contentTypesXml).length,
        utf8.encode(_contentTypesXml),
      ),
    );

    // _rels/.rels
    archive.addFile(
      ArchiveFile(
        '_rels/.rels',
        utf8.encode(_rootRelsXml).length,
        utf8.encode(_rootRelsXml),
      ),
    );

    // word/_rels/document.xml.rels
    archive.addFile(
      ArchiveFile(
        'word/_rels/document.xml.rels',
        utf8.encode(_documentRelsXml).length,
        utf8.encode(_documentRelsXml),
      ),
    );

    // word/styles.xml
    archive.addFile(
      ArchiveFile(
        'word/styles.xml',
        utf8.encode(_stylesXml).length,
        utf8.encode(_stylesXml),
      ),
    );

    // word/document.xml
    final fullDocumentXml = _buildFullDocumentXml(docBodyBuffer.toString());
    archive.addFile(
      ArchiveFile(
        'word/document.xml',
        utf8.encode(fullDocumentXml).length,
        utf8.encode(fullDocumentXml),
      ),
    );

    // 3. Compress ZIP archive and write to outputFile
    final zipEncoder = ZipEncoder();
    final docxBytes = zipEncoder.encode(archive);
    await outputFile.writeAsBytes(docxBytes, flush: true);

    stopwatch.stop();
    final filename = outputFile.uri.pathSegments.last;

    return ExportResult(
      file: outputFile,
      format: ExportFormat.docx,
      filename: filename,
      byteSize: docxBytes.length,
      mimeType: ExportFormat.docx.mimeType,
      duration: stopwatch.elapsed,
      warnings: warnings,
    );
  }

  static String _buildFullDocumentXml(String bodyContent) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <w:body>
$bodyContent
    <w:sectPr>
      <w:pgSz w:w="11906" w:h="16838"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/>
    </w:sectPr>
  </w:body>
</w:document>''';
  }

  static String _parseMarkdownToDocxXml(String markdown) {
    final buffer = StringBuffer();
    final lines = markdown.split('\n');

    var inCodeBlock = false;
    final codeLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Code blocks ```
      if (line.trim().startsWith('```') || line.trim().startsWith('~~~')) {
        if (inCodeBlock) {
          buffer.writeln(_buildCodeBlockXml(codeLines.join('\n')));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          codeLines.clear();
        }
        continue;
      }

      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        buffer.writeln('<w:p/>');
        continue;
      }

      // Headings
      final h1Match = RegExp(r'^#\s+(.*)$').firstMatch(line);
      if (h1Match != null) {
        buffer.writeln(_buildHeadingXml(h1Match.group(1)!, level: 1));
        continue;
      }

      final h2Match = RegExp(r'^##\s+(.*)$').firstMatch(line);
      if (h2Match != null) {
        buffer.writeln(_buildHeadingXml(h2Match.group(1)!, level: 2));
        continue;
      }

      final h3Match = RegExp(r'^###\s+(.*)$').firstMatch(line);
      if (h3Match != null) {
        buffer.writeln(_buildHeadingXml(h3Match.group(1)!, level: 3));
        continue;
      }

      final hOtherMatch = RegExp(r'^#{4,6}\s+(.*)$').firstMatch(line);
      if (hOtherMatch != null) {
        buffer.writeln(_buildHeadingXml(hOtherMatch.group(1)!, level: 4));
        continue;
      }

      // Checklists: `- [x] ` or `- [ ] `
      final checkedMatch = RegExp(r'^(\s*)[-*+]\s+\[([xX])\]\s+(.*)$').firstMatch(line);
      if (checkedMatch != null) {
        final text = checkedMatch.group(3)!;
        buffer.writeln(_buildTaskItemXml(text, isChecked: true));
        continue;
      }

      final uncheckedMatch = RegExp(r'^(\s*)[-*+]\s+\[\s*\]\s+(.*)$').firstMatch(line);
      if (uncheckedMatch != null) {
        final text = uncheckedMatch.group(2)!;
        buffer.writeln(_buildTaskItemXml(text, isChecked: false));
        continue;
      }

      // Bullet lists
      final bulletMatch = RegExp(r'^(\s*)[-*+]\s+(.*)$').firstMatch(line);
      if (bulletMatch != null) {
        final text = bulletMatch.group(2)!;
        buffer.writeln(_buildBulletItemXml(text));
        continue;
      }

      // Blockquotes
      final quoteMatch = RegExp(r'^>\s*(.*)$').firstMatch(line);
      if (quoteMatch != null) {
        buffer.writeln(_buildBlockquoteXml(quoteMatch.group(1)!));
        continue;
      }

      // Horizontal rules
      if (RegExp(r'^[-*_]{3,}\s*$').hasMatch(trimmed)) {
        buffer.writeln(_buildHorizontalRuleXml());
        continue;
      }

      // Standard paragraph
      buffer.writeln(_buildParagraphXml(line));
    }

    return buffer.toString();
  }

  static String _buildHeadingXml(String text, {required int level}) {
    final styleVal = level == 0 ? 'Title' : 'Heading$level';
    final fontSize = level == 0 ? '48' : (level == 1 ? '36' : (level == 2 ? '28' : '24'));
    final escaped = ExportSecurityGuard.escapeHtml(text);

    return '''
    <w:p>
      <w:pPr>
        <w:pStyle w:val="$styleVal"/>
        <w:spacing w:before="240" w:after="120"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="$fontSize"/>
        </w:rPr>
        <w:t>$escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _buildParagraphXml(String text, {bool isItalic = false}) {
    final escaped = ExportSecurityGuard.escapeHtml(text);
    return '''
    <w:p>
      <w:pPr>
        <w:spacing w:after="120" w:line="276" w:lineRule="auto"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          ${isItalic ? '<w:i/>' : ''}
          <w:sz w:val="22"/>
        </w:rPr>
        <w:t>$escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _buildBulletItemXml(String text) {
    final escaped = ExportSecurityGuard.escapeHtml(text);
    return '''
    <w:p>
      <w:pPr>
        <w:pStyle w:val="ListBullet"/>
        <w:spacing w:after="60"/>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:sz w:val="22"/>
        </w:rPr>
        <w:t>•  $escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _buildTaskItemXml(String text, {required bool isChecked}) {
    final escaped = ExportSecurityGuard.escapeHtml(text);
    final icon = isChecked ? '☑' : '☐';
    return '''
    <w:p>
      <w:pPr>
        <w:spacing w:after="60"/>
        <w:ind w:left="720" w:hanging="360"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:b/>
          <w:sz w:val="22"/>
        </w:rPr>
        <w:t>$icon  </w:t>
      </w:r>
      <w:r>
        <w:rPr>
          ${isChecked ? '<w:strike/><w:color w:val="73706A"/>' : ''}
          <w:sz w:val="22"/>
        </w:rPr>
        <w:t>$escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _buildBlockquoteXml(String text) {
    final escaped = ExportSecurityGuard.escapeHtml(text);
    return '''
    <w:p>
      <w:pPr>
        <w:pBdr>
          <w:left w:val="single" w:sz="24" w:space="12" w:color="D97706"/>
        </w:pBdr>
        <w:ind w:left="360"/>
        <w:spacing w:before="120" w:after="120"/>
      </w:pPr>
      <w:r>
        <w:rPr>
          <w:i/>
          <w:color w:val="73706A"/>
          <w:sz w:val="22"/>
        </w:rPr>
        <w:t>$escaped</w:t>
      </w:r>
    </w:p>''';
  }

  static String _buildCodeBlockXml(String text) {
    final lines = text.split('\n');
    final pBuffer = StringBuffer();
    for (final line in lines) {
      final escaped = ExportSecurityGuard.escapeHtml(line);
      pBuffer.writeln('''
      <w:p>
        <w:pPr>
          <w:pStyle w:val="HTMLPreformatted"/>
          <w:shd w:val="clear" w:color="auto" w:fill="F3F2EE"/>
          <w:spacing w:after="0" w:line="240" w:lineRule="auto"/>
        </w:pPr>
        <w:r>
          <w:rPr>
            <w:rFonts w:ascii="Courier New" w:hAnsi="Courier New"/>
            <w:sz w:val="19"/>
          </w:rPr>
          <w:t xml:space="preserve">$escaped</w:t>
        </w:r>
      </w:p>''');
    }
    return pBuffer.toString();
  }

  static String _buildMetadataBoxXml(List<String> lines) {
    final pBuffer = StringBuffer();
    for (final line in lines) {
      final escaped = ExportSecurityGuard.escapeHtml(line);
      pBuffer.writeln('''
      <w:p>
        <w:pPr>
          <w:spacing w:after="40"/>
        </w:pPr>
        <w:r>
          <w:rPr>
            <w:color w:val="73706A"/>
            <w:sz w:val="18"/>
          </w:rPr>
          <w:t>$escaped</w:t>
        </w:r>
      </w:p>''');
    }
    return pBuffer.toString();
  }

  static String _buildHorizontalRuleXml() {
    return '''
    <w:p>
      <w:pPr>
        <w:pBdr>
          <w:bottom w:val="single" w:sz="12" w:space="8" w:color="E6E4DD"/>
        </w:pBdr>
        <w:spacing w:before="240" w:after="240"/>
      </w:pPr>
    </w:p>''';
  }

  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const String _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:color w:val="2D2B28"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:styleId="Normal" w:default="1">
    <w:name w:val="Normal"/>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="36"/>
      <w:color w:val="1D1C1A"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="28"/>
      <w:color w:val="1D1C1A"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="24"/>
      <w:color w:val="1D1C1A"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Title">
    <w:name w:val="Title"/>
    <w:basedOn w:val="Normal"/>
    <w:rPr>
      <w:b/>
      <w:sz w:val="48"/>
      <w:color w:val="1D1C1A"/>
    </w:rPr>
  </w:style>
</w:styles>''';
}
