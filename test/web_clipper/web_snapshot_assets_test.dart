import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quitepaper/core/web_clipper/web_snapshot_assets.dart';

void main() {
  test(
    'hydrates encrypted image references for offline WebView rendering',
    () async {
      final ids = <String>[];
      final html = await hydrateSnapshotImages(
        '<img src="qp://asset/photo" srcset="https://example.com/photo 2x">'
        '<img src="qp://asset/photo"><img src="https://example.com/remote">',
        (id) async {
          ids.add(id);
          return Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
        },
      );
      expect(ids, ['photo']);
      expect('data:image/png;base64,'.allMatches(html).length, 2);
      expect(html, isNot(contains('srcset')));
      expect(html, contains('src="https://example.com/remote"'));
    },
  );
}
