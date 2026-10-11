import 'dart:convert';

import '../domain/rich_block.dart';

/// Opening marker of a baked link-preview sentinel comment.
const String linkPreviewCommentPrefix = '<!-- qp-link-preview:';

/// Closing marker of a baked link-preview sentinel comment.
const String linkPreviewCommentSuffix = '-->';

/// Matches a standalone Markdown link to an `https?://` URL.
/// Group 1 is the link text (title); group 2 is the URL.
final RegExp _linkPreviewLinkPattern =
    RegExp(r'^\[([^\]]*)\]\((https?://[^)\s]+)(?:\s+"[^"]*")?\)$');

/// Encodes [block]'s baked metadata into a one-line HTML-comment sentinel.
///
/// Emits: `<!-- qp-link-preview: {"desc":"…","site":"…","img":"qp://asset/<id>","ts":"ISO"} -->`
///
/// The `desc`, `site`, and `img` keys are omitted when their corresponding
/// block field is null or empty. `ts` is [LinkPreviewBlock.fetchedAt] as an
/// ISO-8601 string and is always present.
String encodeLinkPreviewComment(LinkPreviewBlock block) {
  final payload = <String, dynamic>{};
  if (block.description != null && block.description!.isNotEmpty) {
    payload['desc'] = block.description;
  }
  if (block.siteName != null && block.siteName!.isNotEmpty) {
    payload['site'] = block.siteName;
  }
  if (block.thumbnailAssetId != null && block.thumbnailAssetId!.isNotEmpty) {
    payload['img'] = block.thumbnailAssetId;
  }
  payload['ts'] = block.fetchedAt.toIso8601String();
  return '$linkPreviewCommentPrefix ${jsonEncode(payload)} $linkPreviewCommentSuffix';
}

/// Whether a trimmed [line] is a `qp-link-preview` sentinel comment.
bool isLinkPreviewComment(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith(linkPreviewCommentPrefix) &&
      trimmed.endsWith(linkPreviewCommentSuffix);
}

/// Reconstructs a [LinkPreviewBlock] from a visible Markdown link line
/// (`[Title](url)`) and its adjacent sentinel [commentLine].
///
/// Returns null if either line does not match the expected shape. The JSON
/// slice between [linkPreviewCommentPrefix] and [linkPreviewCommentSuffix] is
/// decoded; all keys (`desc`, `site`, `img`, `ts`) are optional. A missing or
/// unparseable `ts` falls back to [DateTime.now].
LinkPreviewBlock? decodeLinkPreview({
  required String linkLine,
  required String commentLine,
  required String id,
}) {
  final linkMatch = _linkPreviewLinkPattern.firstMatch(linkLine.trim());
  if (linkMatch == null) {
    return null;
  }
  if (!isLinkPreviewComment(commentLine)) {
    return null;
  }

  final trimmedComment = commentLine.trim();
  final jsonSlice = trimmedComment
      .substring(
        linkPreviewCommentPrefix.length,
        trimmedComment.length - linkPreviewCommentSuffix.length,
      )
      .trim();

  Map<String, dynamic> payload;
  try {
    final decoded = jsonDecode(jsonSlice);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    payload = decoded;
  } catch (_) {
    return null;
  }

  final title = linkMatch.group(1) ?? '';
  final url = linkMatch.group(2) ?? '';
  final ts = payload['ts'] as String?;

  return LinkPreviewBlock(
    id: id,
    url: url,
    title: title,
    description: payload['desc'] as String?,
    siteName: payload['site'] as String?,
    thumbnailAssetId: payload['img'] as String?,
    fetchedAt: ts != null ? (DateTime.tryParse(ts) ?? DateTime.now()) : DateTime.now(),
  );
}
