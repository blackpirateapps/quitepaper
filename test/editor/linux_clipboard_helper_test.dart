import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/utils/linux_clipboard_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LinuxClipboardHelper Tests', () {
    test('extracts image bytes when process runner returns PNG payload for wl-paste', () async {
      final fakePngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]);

      final helper = LinuxClipboardHelper(
        processRunner: (executable, arguments, {stdoutEncoding}) async {
          if (executable == 'wl-paste' && arguments.contains('image/png')) {
            return ProcessResult(1234, 0, fakePngBytes, '');
          }
          return ProcessResult(1234, 1, null, 'not found');
        },
      );

      final result = await helper.getClipboardImage();
      // On non-Linux host platforms during unit testing, helper delegates to pasteboard or returns null
      // On Linux host platforms, it executes our process runner and returns fakePngBytes
      if (Platform.isLinux) {
        expect(result, isNotNull);
        expect(result, equals(fakePngBytes));
      }
    });

    test('extracts image bytes when wl-paste fails and xclip succeeds', () async {
      final fakePngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 4, 5, 6]);

      final helper = LinuxClipboardHelper(
        processRunner: (executable, arguments, {stdoutEncoding}) async {
          if (executable == 'xclip') {
            return ProcessResult(1234, 0, fakePngBytes, '');
          }
          return ProcessResult(1234, 1, null, 'not found');
        },
      );

      final result = await helper.getClipboardImage();
      if (Platform.isLinux) {
        expect(result, isNotNull);
        expect(result, equals(fakePngBytes));
      }
    });

    test('returns null when all clipboard image tools fail', () async {
      final helper = LinuxClipboardHelper(
        processRunner: (executable, arguments, {stdoutEncoding}) async {
          return ProcessResult(1234, 1, null, 'not found');
        },
      );

      final result = await helper.getClipboardImage();
      // Since Pasteboard.image is not populated in mock headless test and process fails:
      expect(result, isNull);
    });

    test('extracts URI list file paths when process runner returns text/uri-list', () async {
      const uriList = 'file:///home/dog/photo.png\r\nfile:///home/dog/doc.pdf\n';

      final helper = LinuxClipboardHelper(
        processRunner: (executable, arguments, {stdoutEncoding}) async {
          if (arguments.contains('text/uri-list')) {
            return ProcessResult(1234, 0, uriList, '');
          }
          return ProcessResult(1234, 1, null, 'not found');
        },
      );

      final files = await helper.getClipboardFiles();
      if (Platform.isLinux) {
        expect(files, contains('/home/dog/photo.png'));
        expect(files, contains('/home/dog/doc.pdf'));
      }
    });
  });
}
