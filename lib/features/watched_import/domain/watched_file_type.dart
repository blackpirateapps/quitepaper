import 'dart:convert';

/// User-facing groups include all aliases accepted by the native scanner.
enum WatchedFileType {
  email('Email (.eml)', {'eml'}),
  pdf('PDF (.pdf)', {'pdf'}),
  markdown('Markdown (.md, .markdown)', {'md', 'markdown'}),
  text('Text (.txt)', {'txt'}),
  png('PNG (.png)', {'png'}),
  jpeg('JPEG (.jpg, .jpeg)', {'jpg', 'jpeg'}),
  webp('WebP (.webp)', {'webp'});

  const WatchedFileType(this.label, this.extensions);
  final String label;
  final Set<String> extensions;

  static Set<WatchedFileType> decode(String value) {
    final names = (jsonDecode(value) as List).cast<String>().toSet();
    return values.where((type) => names.contains(type.name)).toSet();
  }

  static String encode(Set<WatchedFileType> types) => jsonEncode(
    values.where(types.contains).map((type) => type.name).toList(),
  );

  static bool allows(String value, String format) => decode(
    value,
  ).any((type) => type.extensions.contains(format.toLowerCase()));
}
