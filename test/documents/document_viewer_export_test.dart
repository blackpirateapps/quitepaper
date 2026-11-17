import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:syncfusion_pdfviewer_platform_interface/pdfviewer_platform_interface.dart';
import '../pdf/syncfusion_pdf_page_renderer_test.dart'
    show FakePdfViewerPlatform;
import 'document_viewer_save_test.dart' show SaveService, openSaveViewer;

class ExportPicker extends FilePicker {
  String? result;
  bool unavailable = false;
  int calls = 0;
  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    calls++;
    if (unavailable) throw UnimplementedError('Picker unavailable');
    return result;
  }
}

class ExportPaths extends PathProviderPlatform {
  ExportPaths(this.path);
  final String path;
  int downloadsCalls = 0;
  @override
  Future<String?> getDownloadsPath() async {
    downloadsCalls++;
    return path;
  }
}

void main() {
  late Directory directory;
  late ExportPaths paths;
  late ExportPicker picker;
  setUpAll(() => FilePicker.platform = ExportPicker());
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('qp-export-regression-');
    paths = ExportPaths(directory.path);
    picker = ExportPicker();
    final previousPaths = PathProviderPlatform.instance;
    PathProviderPlatform.instance = paths;
    final previousPicker = FilePicker.platform;
    FilePicker.platform = picker;
    final previousPdf = PdfViewerPlatform.instance;
    PdfViewerPlatform.instance = FakePdfViewerPlatform()
      ..pageCountToReturn = 1
      ..heightsToReturn = [842]
      ..widthsToReturn = [595];
    addTearDown(() async {
      FilePicker.platform = previousPicker;
      PathProviderPlatform.instance = previousPaths;
      PdfViewerPlatform.instance = previousPdf;
      await directory.delete(recursive: true);
    });
  });
  for (final cancelled in [null, '']) {
    testWidgets(
      'cancelled picker ($cancelled) writes no file and reports no success',
      (tester) async {
        picker.result = cancelled;
        await openSaveViewer(tester, SaveService());
        await tester.runAsync(() async {
          await tester.tap(find.byTooltip('Save PDF to storage'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();
        expect(picker.calls, 1);
        expect(paths.downloadsCalls, 0);
        expect(await tester.runAsync(() => directory.list().toList()), isEmpty);
        expect(find.textContaining('Document saved:'), findsNothing);
        expect(find.textContaining('Saved to'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  }
  testWidgets('unavailable picker retains Downloads fallback', (tester) async {
    picker.unavailable = true;
    final service = SaveService();
    await openSaveViewer(tester, service);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Save PDF to storage'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();
    expect(paths.downloadsCalls, 1);
    expect(
      await tester.runAsync(
        () => File('${directory.path}/Save Test.pdf').readAsBytes(),
      ),
      service.resolution.data!.pdfBytes,
    );
    expect(find.textContaining('Saved to'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 600));
  });
}
