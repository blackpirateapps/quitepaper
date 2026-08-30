import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:quitepaper/core/fonts/font_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('font_cache_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('FontCacheManager', () {
    test('defaultHostedFonts contains 8 curated font families', () {
      final fonts = FontCacheManager.defaultHostedFonts;
      expect(fonts.length, equals(8));

      final families = fonts.map((f) => f.family).toSet();
      expect(families, containsAll([
        'Inter',
        'Roboto',
        'Lora',
        'Merriweather',
        'Open Sans',
        'Lato',
        'JetBrains Mono',
        'Fira Code',
      ]));
    });

    test('HostedFontEntry calculates totalSize and formats readable size', () {
      const entry = HostedFontEntry(
        family: 'TestFont',
        category: 'Sans-serif',
        variants: [
          HostedFontVariant(
            variant: 'regular',
            weight: 400,
            style: 'normal',
            file: 'TestFont/Test-Regular.ttf',
            size: 512 * 1024,
          ),
          HostedFontVariant(
            variant: 'bold',
            weight: 700,
            style: 'normal',
            file: 'TestFont/Test-Bold.ttf',
            size: 512 * 1024,
          ),
        ],
      );

      expect(entry.totalSize, equals(1024 * 1024));
      expect(entry.formattedSize, equals('1.0 MB'));
    });

    test('HostedFontEntry and HostedFontVariant serialization round-trips', () {
      const entry = HostedFontEntry(
        family: 'CustomSans',
        category: 'Sans-serif',
        variants: [
          HostedFontVariant(
            variant: 'regular',
            weight: 400,
            style: 'normal',
            file: 'CustomSans/Custom-Regular.ttf',
            size: 12345,
          ),
        ],
      );

      final json = entry.toJson();
      final restored = HostedFontEntry.fromJson(json);

      expect(restored.family, equals('CustomSans'));
      expect(restored.category, equals('Sans-serif'));
      expect(restored.variants.length, equals(1));
      expect(restored.variants.first.variant, equals('regular'));
      expect(restored.variants.first.size, equals(12345));
    });

    test('isFontCached returns false when font file does not exist', () {
      final manager = FontCacheManager(
        customStorageDir: tempDir,
      );

      expect(manager.isFontCached('Inter'), isFalse);
      expect(manager.getStatus('Inter'), equals(FontDownloadStatus.notDownloaded));
    });

    test('isFontCached returns true when regular variant file exists', () async {
      final manager = FontCacheManager(
        customStorageDir: tempDir,
      );

      final file = File('${tempDir.path}/Inter-Regular.ttf');
      await file.writeAsString('dummy ttf content');

      expect(manager.isFontCached('Inter'), isTrue);
      expect(manager.getStatus('Inter'), equals(FontDownloadStatus.cached));
    });

    test('getCachedFontFile returns existing file or null', () async {
      final manager = FontCacheManager(
        customStorageDir: tempDir,
      );
      await manager.getFontsDirectory();

      expect(manager.getCachedFontFile('Lora'), isNull);

      final file = File('${tempDir.path}/Lora-Regular.ttf');
      await file.writeAsString('lora binary');

      final cached = manager.getCachedFontFile('Lora');
      expect(cached, isNotNull);
      expect(cached!.existsSync(), isTrue);
    });

    test('downloadAndRegisterFont downloads variants and registers in manager', () async {
      // Mock HTTP client returning dummy bytes
      final mockClient = http_testing.MockClient((request) async {
        return http.Response.bytes(
          utf8.encode('mock font data'),
          200,
          headers: {'content-type': 'font/ttf'},
        );
      });

      final manager = FontCacheManager(
        baseUrl: 'https://test-server.example',
        customStorageDir: tempDir,
        httpClient: mockClient,
      );

      double reportedProgress = 0.0;
      final success = await manager.downloadAndRegisterFont(
        'Fira Code',
        onProgress: (p) => reportedProgress = p,
      );

      expect(success, isTrue);
      expect(reportedProgress, equals(1.0));
      expect(manager.isFontCached('Fira Code'), isTrue);
      expect(manager.getStatus('Fira Code'), equals(FontDownloadStatus.cached));

      final regularFile = File('${tempDir.path}/FiraCode-Regular.ttf');
      expect(await regularFile.exists(), isTrue);
    });

    test('downloadAndRegisterFont handles network failures gracefully', () async {
      final mockClient = http_testing.MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final manager = FontCacheManager(
        baseUrl: 'https://test-server.example',
        customStorageDir: tempDir,
        httpClient: mockClient,
      );

      final success = await manager.downloadAndRegisterFont('Lora');
      expect(success, isFalse);
      expect(manager.getStatus('Lora'), equals(FontDownloadStatus.error));
    });

    test('loadCustomFontFromFile copies local file to font cache', () async {
      final manager = FontCacheManager(
        customStorageDir: tempDir,
      );

      final localFile = File('${tempDir.path}/MyCustomFont.ttf');
      await localFile.writeAsString('custom font bytes');

      final loadedFamily = await manager.loadCustomFontFromFile(localFile.path);
      expect(loadedFamily, equals('MyCustomFont'));
      expect(manager.isFontCached('MyCustomFont'), isTrue);
    });
  });
}
