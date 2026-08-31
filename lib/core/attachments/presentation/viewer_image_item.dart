import 'package:flutter/foundation.dart';

/// Represents a single image item within a note for rendering and gallery navigation.
@immutable
class ViewerImageItem {
  const ViewerImageItem({
    this.assetId,
    this.url,
    this.altText,
    this.title,
    this.caption,
    this.initialBytes,
  });

  /// Internal encrypted attachment ID (for `qp://asset/<UUID>`).
  final String? assetId;

  /// Direct network/file URL or raw source string.
  final String? url;

  /// Markdown alt text (e.g. `![alt text](...)`).
  final String? altText;

  /// Optional Markdown image title (e.g. `![alt](url "title")`).
  final String? title;

  /// Optional caption extracted from Markdown semantics (e.g. adjacent `*caption*`).
  final String? caption;

  /// Ephemeral pre-resolved image byte buffer in RAM.
  final Uint8List? initialBytes;

  /// Whether this item represents a Quiet Paper encrypted asset.
  bool get isAsset => assetId != null && assetId!.isNotEmpty;

  /// Whether this item represents an external network URL.
  bool get isNetwork => url != null && (url!.startsWith('http://') || url!.startsWith('https://'));

  /// Canonical identifier for deduplication and routing.
  String get id => assetId ?? url ?? '';

  /// Clean display title for fullscreen viewer header and accessibility.
  String get displayTitle {
    if (caption != null && caption!.trim().isNotEmpty) {
      return caption!.trim();
    }
    if (title != null && title!.trim().isNotEmpty) {
      return title!.trim();
    }
    if (altText != null && altText!.trim().isNotEmpty && altText!.trim().toLowerCase() != 'image') {
      return altText!.trim();
    }
    return 'Image';
  }

  /// Clean accessibility announcement label.
  String get semanticLabel {
    final name = displayTitle;
    return '$name, image. Double tap to open.';
  }

  ViewerImageItem copyWith({
    String? assetId,
    String? url,
    String? altText,
    String? title,
    String? caption,
    Uint8List? initialBytes,
  }) {
    return ViewerImageItem(
      assetId: assetId ?? this.assetId,
      url: url ?? this.url,
      altText: altText ?? this.altText,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      initialBytes: initialBytes ?? this.initialBytes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ViewerImageItem &&
          runtimeType == other.runtimeType &&
          assetId == other.assetId &&
          url == other.url &&
          altText == other.altText &&
          title == other.title &&
          caption == other.caption;

  @override
  int get hashCode => Object.hash(assetId, url, altText, title, caption);
}
