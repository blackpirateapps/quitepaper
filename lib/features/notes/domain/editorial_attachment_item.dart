import 'package:flutter/foundation.dart';

/// Kind of attachment for inline editorial previews.
enum EditorialAttachmentKind {
  image,
  pdf,
  textFile,
  generic,
}

/// Rich metadata for an inline attachment in the Editorial notes list.
@immutable
class EditorialAttachmentItem {
  const EditorialAttachmentItem({
    required this.kind,
    required this.uri,
    this.title,
    this.label,
  });

  const EditorialAttachmentItem.image({
    required this.uri,
    this.title,
  })  : kind = EditorialAttachmentKind.image,
        label = null;

  const EditorialAttachmentItem.pdf({
    required this.uri,
    this.title,
    this.label = 'PDF',
  }) : kind = EditorialAttachmentKind.pdf;

  const EditorialAttachmentItem.textFile({
    required this.uri,
    this.title,
    this.label = 'TXT',
  }) : kind = EditorialAttachmentKind.textFile;

  const EditorialAttachmentItem.generic({
    required this.uri,
    this.title,
    this.label = 'FILE',
  }) : kind = EditorialAttachmentKind.generic;

  final EditorialAttachmentKind kind;
  final String uri;
  final String? title;
  final String? label;

  bool get isImage => kind == EditorialAttachmentKind.image;
  bool get isPdf => kind == EditorialAttachmentKind.pdf;
  bool get isTextFile => kind == EditorialAttachmentKind.textFile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorialAttachmentItem &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          uri == other.uri &&
          title == other.title &&
          label == other.label;

  @override
  int get hashCode => Object.hash(kind, uri, title, label);
}
