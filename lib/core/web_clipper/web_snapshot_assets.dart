import 'dart:convert';
import 'dart:typed_data';
import 'package:html/parser.dart' as html_parser;
import 'package:mime/mime.dart';

/// Hydrates vault URLs only in memory, after decrypting the snapshot.
Future<String> hydrateSnapshotImages(
  String html,
  Future<Uint8List?> Function(String assetId) resolveAsset,
) async {
  final document = html_parser.parse(html);
  final sources = <String, String>{};
  for (final image in document.querySelectorAll('img')) {
    final source = image.attributes['src'] ?? '';
    final uri = Uri.tryParse(source);
    if (uri == null ||
        uri.scheme != 'qp' ||
        uri.host != 'asset' ||
        uri.pathSegments.length != 1) {
      continue;
    }
    final id = uri.pathSegments.single;
    if (!sources.containsKey(source)) {
      final bytes = await resolveAsset(id);
      if (bytes == null) continue;
      final mime =
          lookupMimeType(id, headerBytes: bytes) ?? 'application/octet-stream';
      sources[source] = 'data:$mime;base64,${base64Encode(bytes)}';
    }
    image.attributes['src'] = sources[source]!;
    image.attributes.remove('srcset');
  }
  return document.outerHtml;
}
