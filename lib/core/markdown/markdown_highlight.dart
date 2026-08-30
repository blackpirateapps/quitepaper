import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import '../../app/theme/app_colors.dart';
import '../attachments/presentation/quiet_attachment_card.dart';
import '../documents/presentation/quiet_document_card.dart';

/// Markdown syntax rule to match `==highlighted text==` and parse into `<mark>` AST nodes.
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==([^=\n\r]+)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[1]!;
    final el = md.Element.text('mark', text);
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<mark>` tags produced by [HighlightSyntax].
/// Renders a soft warm highlight background container matching Quiet Paper's aesthetic.
class HighlightElementBuilder extends MarkdownElementBuilder {
  HighlightElementBuilder(this.colors);

  final AppColors colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final effectiveStyle = (preferredStyle ?? parentStyle ?? const TextStyle())
        .copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(element.textContent, style: effectiveStyle),
    );
  }
}

/// Markdown syntax rule to match a search query and parse into `<searchmark>` AST nodes.
class SearchMatchSyntax extends md.InlineSyntax {
  SearchMatchSyntax(String query)
    : super(RegExp.escape(query), caseSensitive: false);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = match[0]!;
    final el = md.Element.text('searchmark', text);
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<searchmark>` tags.
class SearchMatchElementBuilder extends MarkdownElementBuilder {
  SearchMatchElementBuilder(this.colors);

  final AppColors colors;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final effectiveStyle = (preferredStyle ?? parentStyle ?? const TextStyle())
        .copyWith(
          color: colors.searchHighlightText,
          fontWeight: FontWeight.w600,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 1.0),
      margin: const EdgeInsets.symmetric(horizontal: 1.0),
      decoration: BoxDecoration(
        color: colors.searchHighlight,
        borderRadius: BorderRadius.circular(3.0),
      ),
      child: Text(element.textContent, style: effectiveStyle),
    );
  }
}

/// Markdown syntax rule to match `[Title](qp://document/<UUID>)` and parse into `<quietdoc>` AST nodes.
class QuietDocumentSyntax extends md.InlineSyntax {
  QuietDocumentSyntax()
    : super(r'\[([^\]\n]+)\]\((qp:\/\/document\/([0-9a-fA-F\-]{36}))\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match[1]!;
    final url = match[2]!;
    final docId = match[3]!;
    final el = md.Element('quietdoc', [md.Text(title)])
      ..attributes['url'] = url
      ..attributes['title'] = title
      ..attributes['docId'] = docId;
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<quietdoc>` tags produced by [QuietDocumentSyntax].
class QuietDocumentElementBuilder extends MarkdownElementBuilder {
  QuietDocumentElementBuilder({this.onDocumentRenamed});

  final void Function(String documentId, String newTitle)? onDocumentRenamed;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final docId = element.attributes['docId'] ?? '';
    final title = element.attributes['title'] ?? element.textContent;
    final url = element.attributes['url'] ?? 'qp://document/$docId';

    return QuietDocumentCard(
      documentId: docId,
      title: title.isNotEmpty ? title : 'Scanned Document',
      uriString: url,
      onDocumentRenamed: onDocumentRenamed,
    );
  }
}

/// Markdown syntax rule to match `[Title](qp://asset/<UUID>)` and parse into `<quietattachment>` AST nodes.
class QuietAttachmentSyntax extends md.InlineSyntax {
  QuietAttachmentSyntax()
    : super(r'(?<!!)\[([^\]\n]+)\]\((qp:\/\/asset\/([0-9a-fA-F\-]{36}))\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final title = match[1]!;
    final url = match[2]!;
    final assetId = match[3]!;
    final el = md.Element('quietattachment', [md.Text(title)])
      ..attributes['url'] = url
      ..attributes['title'] = title
      ..attributes['assetId'] = assetId;
    parser.addNode(el);
    return true;
  }
}

/// Custom element builder for `<quietattachment>` tags produced by [QuietAttachmentSyntax].
class QuietAttachmentElementBuilder extends MarkdownElementBuilder {
  QuietAttachmentElementBuilder({
    this.onAttachmentRenamed,
    this.onAttachmentDeleted,
  });

  final void Function(String attachmentId, String newTitle)?
  onAttachmentRenamed;
  final void Function(String attachmentId)? onAttachmentDeleted;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final assetId = element.attributes['assetId'] ?? '';
    final title = element.attributes['title'] ?? element.textContent;
    final url = element.attributes['url'] ?? 'qp://asset/$assetId';

    return QuietAttachmentCard(
      attachmentId: assetId,
      title: title.isNotEmpty ? title : 'Attachment',
      uriString: url,
      onAttachmentRenamed: onAttachmentRenamed,
      onAttachmentDeleted: onAttachmentDeleted,
    );
  }
}
