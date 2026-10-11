import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quitepaper/features/export/application/exporters/pdf_exporter.dart';
import 'package:quitepaper/features/export/domain/export_models.dart';

/// A valid tall white PNG, standing in for a rendered note screenshot.
Uint8List _fakeRenderedPng({int width = 800, int height = 2400}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  return Uint8List.fromList(img.encodePng(image));
}

NoteExportSnapshot _snapshot(String markdown, {String title = 'Note'}) {
  final now = DateTime.utc(2026, 1, 1);
  return NoteExportSnapshot(
    noteId: 'n1',
    title: title,
    markdown: markdown,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('qp_pdf_bengali_test');
  });
  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  const exporter = PdfExporter();

  test('Bengali note with a rasterizer produces an image-based PDF + warning', () async {
    var rasterizerCalls = 0;
    final out = File('${tempDir.path}/bengali.pdf');

    final result = await exporter.exportPdf(
      snapshot: _snapshot('# শিরোনাম\n\nআমি বাংলায় গান গাই।'),
      request: ExportRequest.forFormat('n1', ExportFormat.pdf),
      outputFile: out,
      imageRasterizer: ({required snapshot, required request}) async {
        rasterizerCalls++;
        return _fakeRenderedPng();
      },
    );

    expect(rasterizerCalls, 1, reason: 'Bengali content should be rasterized');
    expect(await out.exists(), isTrue);
    final bytes = await out.readAsBytes();
    expect(bytes.length, greaterThan(0));
    // PDF magic header.
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(
      result.warnings.any((w) => w.type == ExportWarningType.partialContent),
      isTrue,
      reason: 'should warn that the PDF is rendered as non-selectable images',
    );
  });

  test('Latin-only note keeps the vector path (rasterizer not invoked)', () async {
    var rasterizerCalls = 0;
    final out = File('${tempDir.path}/latin.pdf');

    await exporter.exportPdf(
      snapshot: _snapshot('# Title\n\nThe quick brown fox.'),
      request: ExportRequest.forFormat('n1', ExportFormat.pdf),
      outputFile: out,
      imageRasterizer: ({required snapshot, required request}) async {
        rasterizerCalls++;
        return _fakeRenderedPng();
      },
    );

    expect(rasterizerCalls, 0, reason: 'Latin-only content stays vector text');
    expect(await out.exists(), isTrue);
    final bytes = await out.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('Bengali note without a rasterizer falls back to the vector path', () async {
    final out = File('${tempDir.path}/bengali_novector.pdf');

    final result = await exporter.exportPdf(
      snapshot: _snapshot('আমি বাংলায় গান গাই।'),
      request: ExportRequest.forFormat('n1', ExportFormat.pdf),
      outputFile: out,
    );

    expect(await out.exists(), isTrue);
    final bytes = await out.readAsBytes();
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    // No rasterizer available → no rasterization warning.
    expect(
      result.warnings.any((w) => w.type == ExportWarningType.partialContent),
      isFalse,
    );
  });
}
