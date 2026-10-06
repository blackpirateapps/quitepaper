import 'package:flutter/foundation.dart';

/// Immutable value object representing inline formatting attributes for a rich text run.
///
/// Supports composable combinations of formatting:
/// bold, italic, strikethrough, highlight, inline code, link, noteLink, and tag.
@immutable
class TextAttributes {
  const TextAttributes({
    this.isBold = false,
    this.isItalic = false,
    this.isStrike = false,
    this.isHighlight = false,
    this.isCode = false,
    this.linkUrl,
    this.linkTitle,
    this.noteLinkTarget,
    this.tag,
  });

  /// An unstyled attributes instance with all formatting disabled.
  static const none = TextAttributes();

  /// Whether bold typography is applied.
  final bool isBold;

  /// Whether italic typography is applied.
  final bool isItalic;

  /// Whether strikethrough (line-through) typography is applied.
  final bool isStrike;

  /// Whether highlight background tint is applied.
  final bool isHighlight;

  /// Whether inline monospace code styling is applied.
  final bool isCode;

  /// Optional hyperlink URL (e.g. `https://example.com`).
  final String? linkUrl;

  /// Optional hyperlink title attribute.
  final String? linkTitle;

  /// Optional target for wiki-style note links (e.g. `[[Note Title]]`).
  final String? noteLinkTarget;

  /// Optional normalized hashtag (e.g. `#work`).
  final String? tag;

  /// Whether this run has an active external hyperlink.
  bool get hasLink => linkUrl != null && linkUrl!.isNotEmpty;

  /// Whether this run has an active internal note link.
  bool get hasNoteLink => noteLinkTarget != null && noteLinkTarget!.isNotEmpty;

  /// Whether this run has an active hashtag.
  bool get hasTag => tag != null && tag!.isNotEmpty;

  /// Whether any formatting attribute is active on this run.
  bool get isEmpty =>
      !isBold &&
      !isItalic &&
      !isStrike &&
      !isHighlight &&
      !isCode &&
      !hasLink &&
      !hasNoteLink &&
      !hasTag;

  /// Returns a new [TextAttributes] with the specified fields replaced.
  TextAttributes copyWith({
    bool? isBold,
    bool? isItalic,
    bool? isStrike,
    bool? isHighlight,
    bool? isCode,
    String? linkUrl,
    bool clearLink = false,
    String? linkTitle,
    String? noteLinkTarget,
    bool clearNoteLink = false,
    String? tag,
    bool clearTag = false,
  }) {
    return TextAttributes(
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isStrike: isStrike ?? this.isStrike,
      isHighlight: isHighlight ?? this.isHighlight,
      isCode: isCode ?? this.isCode,
      linkUrl: clearLink ? null : (linkUrl ?? this.linkUrl),
      linkTitle: clearLink ? null : (linkTitle ?? this.linkTitle),
      noteLinkTarget: clearNoteLink ? null : (noteLinkTarget ?? this.noteLinkTarget),
      tag: clearTag ? null : (tag ?? this.tag),
    );
  }

  /// Combines this set of attributes with [other], with [other]'s enabled values taking precedence.
  TextAttributes merge(TextAttributes other) {
    return TextAttributes(
      isBold: isBold || other.isBold,
      isItalic: isItalic || other.isItalic,
      isStrike: isStrike || other.isStrike,
      isHighlight: isHighlight || other.isHighlight,
      isCode: isCode || other.isCode,
      linkUrl: other.linkUrl ?? linkUrl,
      linkTitle: other.linkTitle ?? linkTitle,
      noteLinkTarget: other.noteLinkTarget ?? noteLinkTarget,
      tag: other.tag ?? tag,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextAttributes &&
          runtimeType == other.runtimeType &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isStrike == other.isStrike &&
          isHighlight == other.isHighlight &&
          isCode == other.isCode &&
          linkUrl == other.linkUrl &&
          linkTitle == other.linkTitle &&
          noteLinkTarget == other.noteLinkTarget &&
          tag == other.tag;

  @override
  int get hashCode => Object.hash(
        isBold,
        isItalic,
        isStrike,
        isHighlight,
        isCode,
        linkUrl,
        linkTitle,
        noteLinkTarget,
        tag,
      );

  @override
  String toString() {
    final active = <String>[];
    if (isBold) active.add('bold');
    if (isItalic) active.add('italic');
    if (isStrike) active.add('strike');
    if (isHighlight) active.add('highlight');
    if (isCode) active.add('code');
    if (hasLink) active.add('link($linkUrl)');
    if (hasNoteLink) active.add('noteLink($noteLinkTarget)');
    if (hasTag) active.add('tag($tag)');
    return 'TextAttributes(${active.join(', ')})';
  }
}
