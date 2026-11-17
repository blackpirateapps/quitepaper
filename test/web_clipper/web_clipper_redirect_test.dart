import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:quitepaper/core/web_clipper/web_clipper_scanner.dart';

void main() {
  test(
    'real redirect chain uses final document directory for resources',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = IOClient(HttpClient());
      addTearDown(() async {
        client.close();
        await server.close(force: true);
      });
      final paths = <String>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        if (request.uri.path == '/start') {
          request.response.statusCode = 302;
          request.response.headers.set('location', '/posts/article');
        } else if (request.uri.path == '/posts/article') {
          request.response.write(
            '<article><p>Redirected article content.</p>'
            '<a href="related">Read more</a><img src="photo.png" alt="Photo"></article>',
          );
        } else {
          request.response.headers.set('content-length', '0');
        }
        await request.response.close();
      });
      final origin = 'http://127.0.0.1:${server.port}';
      final result = await WebClipperScanner(
        httpClient: client,
      ).scanUrl('$origin/start');
      expect(result.metadata.sourceUrl, '$origin/posts/article');
      expect(result.images.single.resolvedUrl, '$origin/posts/photo.png');
      expect(result.markdownBody, contains('$origin/posts/related'));
      expect(
        result.preparedSnapshotHtml,
        contains('<base href="$origin/posts/article">'),
      );
      expect(paths, contains('/posts/photo.png'));
      expect(paths, isNot(contains('/photo.png')));
    },
  );
}
