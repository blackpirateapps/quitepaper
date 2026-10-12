import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quitepaper/core/attachments/attachment_crypto.dart';
import 'package:quitepaper/core/attachments/attachment_service.dart';
import 'package:quitepaper/core/attachments/attachment_storage.dart';
import 'package:quitepaper/core/crypto/crypto_service.dart';
import 'package:quitepaper/core/crypto/key_manager.dart';
import 'package:quitepaper/core/database/app_database.dart';
import 'package:quitepaper/core/web_clipper/link_preview_baker.dart';
import 'package:quitepaper/features/editor/application/link_preview_metadata.dart';

class MockKeyManager implements KeyManager {
  MockKeyManager({required this.masterKey, this.isUnlocked = true});

  final Uint8List masterKey;
  @override
  bool isUnlocked;

  @override
  bool get hasKeyData => true;

  @override
  Uint8List getMasterKey() {
    if (!isUnlocked) throw StateError('Locked');
    return masterKey;
  }

  @override
  void lock() {
    isUnlocked = false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _pageHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="OG Title" />
  <meta property="og:description" content="OG Description" />
  <meta property="og:site_name" content="OG Site" />
  <meta property="og:image" content="https://cdn.example.com/thumb.png" />
</head>
<body>
  <article><p>Body text that is long enough to be extracted.</p></article>
</body>
</html>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AttachmentService attachmentService;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('link_preview_baker_test_');
    db = AppDatabase.memory();
    final cryptoService = DefaultCryptoService();
    final masterKey = cryptoService.generateRandomBytes(32);
    final keyManager = MockKeyManager(masterKey: masterKey, isUnlocked: true);

    attachmentService = AttachmentService(
      database: db,
      keyManager: keyManager,
      crypto: AttachmentCrypto(cryptoService: cryptoService),
      storage: AttachmentLocalStorage(customBaseDirectory: tempDir),
    );
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  LinkPreviewBaker bakerWith(http.Client client) => LinkPreviewBaker(
        client: client,
        attachmentService: attachmentService,
      );

  group('findUnbakedLoneLineUrls', () {
    test('finds a lone bare URL and ignores inline/baked/non-URL lines', () {
      final baker = bakerWith(MockClient((_) async => http.Response('', 200)));

      const markdown = 'Intro paragraph\n'
          'https://example.com/post\n'
          'See https://inline.com/x in the sentence\n'
          '[Baked Title](https://baked.com/a)\n'
          '<!-- qp-link-preview: {"ts":"2026-01-01T00:00:00.000"} -->\n'
          '[Unbaked Title](https://unbaked.com/b)\n'
          'just some text';

      final urls = baker.findUnbakedLoneLineUrls(markdown);

      expect(urls, ['https://example.com/post', 'https://unbaked.com/b']);
    });
  });

  group('bakeUrl', () {
    test('happy path returns a block with metadata and a thumbnail', () async {
      final client = MockClient((request) async {
        if (request.url.toString().endsWith('.png')) {
          return http.Response.bytes(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response(_pageHtml, 200, headers: {'content-type': 'text/html'});
      });

      final block = await bakerWith(client).bakeUrl(
        'https://example.com/post',
        noteId: 'note-1',
      );

      expect(block, isNotNull);
      expect(block!.url, 'https://example.com/post');
      expect(block.title, 'OG Title');
      expect(block.description, 'OG Description');
      expect(block.siteName, 'OG Site');
      expect(block.thumbnailAssetId, isNotNull);
      expect(block.thumbnailAssetId, startsWith('qp://asset/'));
    });

    test('returns null when the page fetch fails (non-2xx)', () async {
      final client = MockClient((_) async => http.Response('error', 500));

      final block = await bakerWith(client).bakeUrl('https://example.com/post');

      expect(block, isNull);
    });

    test('returns a text-only block when the image fetch fails', () async {
      final client = MockClient((request) async {
        if (request.url.toString().endsWith('.png')) {
          return http.Response('not found', 404);
        }
        return http.Response(_pageHtml, 200, headers: {'content-type': 'text/html'});
      });

      final block = await bakerWith(client).bakeUrl('https://example.com/post');

      expect(block, isNotNull);
      expect(block!.title, 'OG Title');
      expect(block.description, 'OG Description');
      expect(block.thumbnailAssetId, isNull);
    });

    test('follows redirects cleanly across schemes or locations', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == 'http://example.com/redirect') {
          return http.Response('', 301, headers: {
            'location': 'https://example.com/target',
          });
        }
        if (request.url.toString() == 'https://example.com/target') {
          return http.Response(_pageHtml, 200, headers: {'content-type': 'text/html'});
        }
        return http.Response('not found', 404);
      });

      final block = await bakerWith(client).bakeUrl('http://example.com/redirect');
      expect(block, isNotNull);
      expect(block!.title, 'OG Title');
    });

    test('falls back to domain when title is Web Article or empty', () async {
      const htmlWithoutTitle = '<html><body><article><p>Some plain text</p></article></body></html>';
      final client = MockClient((_) async => http.Response(htmlWithoutTitle, 200, headers: {'content-type': 'text/html'}));

      final block = await bakerWith(client).bakeUrl('https://custom-domain.org/article');
      expect(block, isNotNull);
      expect(block!.title, 'custom-domain.org');
    });
  });

  group('bakeMarkdown', () {
    test('rewrites a lone-line URL into link + sentinel, leaving others', () async {
      final client = MockClient((request) async {
        if (request.url.toString().endsWith('.png')) {
          return http.Response.bytes(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }
        return http.Response(_pageHtml, 200, headers: {'content-type': 'text/html'});
      });

      const markdown = 'Before line\n'
          'https://example.com/post\n'
          'After line';

      final result = await bakerWith(client).bakeMarkdown(markdown, noteId: 'note-1');
      final lines = result.split('\n');

      expect(lines.first, 'Before line');
      expect(lines.last, 'After line');

      final linkIndex = lines.indexOf('[OG Title](https://example.com/post)');
      expect(linkIndex, greaterThan(0));
      expect(isLinkPreviewComment(lines[linkIndex + 1]), isTrue);
    });

    test('rewrites an unbaked lone-line Markdown link into link + sentinel', () async {
      final client = MockClient((request) async {
        return http.Response(_pageHtml, 200, headers: {'content-type': 'text/html'});
      });

      const markdown = 'Before\n[Placeholder](https://example.com/post)\nAfter';
      final result = await bakerWith(client).bakeMarkdown(markdown, noteId: 'note-1');
      final lines = result.split('\n');

      final linkIndex = lines.indexOf('[OG Title](https://example.com/post)');
      expect(linkIndex, greaterThan(0));
      expect(isLinkPreviewComment(lines[linkIndex + 1]), isTrue);
    });

    test('returns the input unchanged when every fetch fails (offline)', () async {
      final client = MockClient((_) async => throw http.ClientException('offline'));

      const markdown = 'Before\nhttps://example.com/post\nAfter';

      final result = await bakerWith(client).bakeMarkdown(markdown);

      expect(result, markdown);
    });
  });
}
