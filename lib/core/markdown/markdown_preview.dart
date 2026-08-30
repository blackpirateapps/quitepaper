import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../utils/font_family_helper.dart';
import '../utils/link_launcher_helper.dart';
import '../../features/editor/presentation/widgets/tag_editor_bar.dart';
import '../../features/import/application/markdown_frontmatter_parser.dart';
import '../../features/settings/application/typography_provider.dart';
import '../attachments/presentation/quiet_asset_image_view.dart';
import '../documents/document_models.dart';
import '../documents/document_provider.dart';
import '../documents/presentation/document_viewer_screen.dart';
import '../documents/presentation/quiet_document_card.dart';
import '../../features/web_clipper/presentation/web_snapshot_viewer_screen.dart';
import '../uri/quiet_paper_uri.dart';
import '../widgets/intelligent_heading_scrollbar.dart';
import 'markdown_chunker.dart';
import 'markdown_highlight.dart';
import 'quiet_code_block_element_builder.dart';
import '../syntax/application/syntax_provider.dart';

class QuietMarkdownPreview extends ConsumerStatefulWidget {
  const QuietMarkdownPreview({
    super.key,
    required this.markdownData,
    this.title,
    this.tags,
    this.onAddTag,
    this.onRemoveTag,
    this.header,
    this.scrollController,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.padding,
    this.selectable = true,
    this.shrinkWrap = false,
    this.onTapLink,
    this.searchQuery,
    this.onDocumentRenamed,
    this.onAttachmentRenamed,
    this.onAttachmentDeleted,
    this.onInsertText,
    this.softLineBreak = true,
    this.showScrollbar = true,
  });

  final String markdownData;
  final String? title;
  final List<String>? tags;
  final ValueChanged<String>? onAddTag;
  final ValueChanged<String>? onRemoveTag;
  final Widget? header;
  final ScrollController? scrollController;
  final ScrollPhysics physics;
  final EdgeInsetsGeometry? padding;
  final bool selectable;
  final bool shrinkWrap;
  final MarkdownTapLinkCallback? onTapLink;
  final String? searchQuery;
  final void Function(String documentId, String newTitle)? onDocumentRenamed;
  final void Function(String attachmentId, String newTitle)? onAttachmentRenamed;
  final void Function(String attachmentId)? onAttachmentDeleted;
  final void Function(String text)? onInsertText;
  final bool softLineBreak;
  final bool showScrollbar;

  @override
  ConsumerState<QuietMarkdownPreview> createState() => _QuietMarkdownPreviewState();
}

class _QuietMarkdownPreviewState extends ConsumerState<QuietMarkdownPreview> {
  late ParsedMarkdown _parsedMarkdown;
  late List<String> _chunks;

  @override
  void initState() {
    super.initState();
    _processMarkdown();
  }

  @override
  void didUpdateWidget(QuietMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdownData != widget.markdownData) {
      _processMarkdown();
    }
  }

  void _processMarkdown() {
    _parsedMarkdown = MarkdownFrontmatterParser.parse(widget.markdownData);
    _chunks = MarkdownChunker.split(_parsedMarkdown.contentBody);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);

    final headingFont = FontFamilyHelper.resolveHeadingFontFamily(
      typography.headingFontFamily ?? typography.bodyFontFamily,
    );
    final bodyFont = FontFamilyHelper.resolveBodyFontFamily(
      typography.bodyFontFamily,
    );
    final codeFont = typography.codeFontFamily ?? 'monospace';
    final baseFontSize = typography.fontSize;
    final baseHeight = typography.lineHeight;
    final baseLetterSpacing = typography.letterSpacing;

    final customStyleSheet = MarkdownStyleSheet(
      h1: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading1Size,
          fontWeight: FontWeight.w700,
          height: baseHeight,
          letterSpacing: baseLetterSpacing - 0.3,
          color: colors.textPrimary,
        ),
      ),
      h2: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading2Size,
          fontWeight: FontWeight.w700,
          height: baseHeight,
          letterSpacing: baseLetterSpacing - 0.2,
          color: colors.textPrimary,
        ),
      ),
      h3: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading3Size,
          fontWeight: FontWeight.w600,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      h4: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading4Size,
          fontWeight: FontWeight.w700,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      h5: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading5Size,
          fontWeight: FontWeight.w700,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      h6: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledHeading6Size,
          fontWeight: FontWeight.w700,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      p: FontFamilyHelper.getTextStyle(
        fontFamily: bodyFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize,
          fontWeight: FontWeight.w400,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      pPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      blockquote: FontFamilyHelper.getTextStyle(
        fontFamily: bodyFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize,
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w400,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textSecondary,
        ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          left: BorderSide(color: colors.accent, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topRight: AppRadii.rSm,
          bottomRight: AppRadii.rSm,
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
      code: FontFamilyHelper.getTextStyle(
        fontFamily: codeFont,
        baseStyle: TextStyle(
          fontSize: typography.scaledCodeSize,
          height: baseHeight,
          color: colors.accentDark,
          backgroundColor: colors.tagBackground,
        ),
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider),
      ),
      codeblockPadding: EdgeInsets.zero,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      listBullet: FontFamilyHelper.getTextStyle(
        fontFamily: bodyFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize,
          height: baseHeight,
          color: colors.accent,
        ),
      ),
      listBulletPadding: const EdgeInsets.only(right: AppSpacing.sm),
      a: FontFamilyHelper.getTextStyle(
        fontFamily: bodyFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize,
          height: baseHeight,
          color: colors.accent,
          decoration: TextDecoration.underline,
          decorationColor: colors.accent.withValues(alpha: 0.5),
        ),
      ),
      tableHead: FontFamilyHelper.getTextStyle(
        fontFamily: headingFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize * 0.9,
          fontWeight: FontWeight.w600,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      tableBody: FontFamilyHelper.getTextStyle(
        fontFamily: bodyFont,
        baseStyle: TextStyle(
          fontSize: baseFontSize * 0.9,
          fontWeight: FontWeight.w400,
          height: baseHeight,
          letterSpacing: baseLetterSpacing,
          color: colors.textPrimary,
        ),
      ),
      tableBorder: TableBorder.all(color: colors.divider, width: 1),
      tableHeadAlign: TextAlign.left,
      tablePadding: const EdgeInsets.all(AppSpacing.sm),
    );

    final effectiveTitle = (widget.title != null && widget.title!.trim().isNotEmpty)
        ? widget.title!.trim()
        : (_parsedMarkdown.title?.trim() ?? '');

    final hasHeader = widget.header != null ||
        effectiveTitle.isNotEmpty ||
        _parsedMarkdown.hasDisplayableMetadata ||
        (widget.tags != null && widget.tags!.isNotEmpty);

    final effectiveOnTapLink = widget.onTapLink ??
        (text, href, title) async {
          final target = (href != null && href.isNotEmpty) ? href : text;
          final qpUri = QuietPaperUri.tryParse(target);
          if (qpUri != null && qpUri.isDocument) {
            try {
              final doc = await ref.read(documentServiceProvider).database.getDocument(qpUri.resourceId);
              if (doc != null &&
                  (doc.source == DocumentSource.webSnapshot.identifier ||
                      doc.mimeType == 'text/html')) {
                if (context.mounted) {
                  await WebSnapshotViewerScreen.open(
                    context,
                    documentId: qpUri.resourceId,
                    title: text.isNotEmpty ? text : doc.title,
                    sourceUrl: _parsedMarkdown.source,
                  );
                }
                return;
              }
            } catch (_) {}

            if (context.mounted) {
              final renamed = await DocumentViewerScreen.openUri(
                context,
                uri: qpUri,
                title: text.isNotEmpty ? text : 'Scanned Document',
              );
              if (renamed != null && renamed.isNotEmpty && renamed != text && widget.onDocumentRenamed != null) {
                widget.onDocumentRenamed!(qpUri.resourceId, renamed);
              }
            }
            return;
          }
          LinkLauncherHelper.handleLinkTap(context, target);
        };

    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.header != null) widget.header!,
          if (effectiveTitle.isNotEmpty) ...[
            Text(
              effectiveTitle,
              style: FontFamilyHelper.getTextStyle(
                fontFamily: headingFont,
                baseStyle: AppTypography.editorTitle.copyWith(
                  color: colors.textPrimary,
                  fontSize: typography.scaledTitleSize,
                  letterSpacing: baseLetterSpacing - 0.4,
                ),
              ),
            ),
            const SizedBox(height: 20.0),
          ],
          if (_parsedMarkdown.hasDisplayableMetadata) ...[
            QuietFrontmatterCard(
              metadata: _parsedMarkdown,
              onTapLink: effectiveOnTapLink,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (widget.tags != null && widget.tags!.isNotEmpty) ...[
            TagEditorBar(
              tags: widget.tags!,
              onAddTag: widget.onAddTag ?? (_) {},
              onRemoveTag: widget.onRemoveTag ?? (_) {},
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      );
    }

    final effectivePadding = widget.padding ??
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        );

    final inlineSyntaxes = <md.InlineSyntax>[
      HighlightSyntax(),
      QuietDocumentSyntax(),
      QuietAttachmentSyntax(),
    ];
    final highlighter = ref.watch(syntaxHighlighterProvider);
    final resolver = ref.watch(syntaxLanguageResolverProvider);

    final builders = <String, MarkdownElementBuilder>{
      'mark': HighlightElementBuilder(colors),
      'quietdoc': QuietDocumentElementBuilder(
        onDocumentRenamed: widget.onDocumentRenamed,
      ),
      'quietattachment': QuietAttachmentElementBuilder(
        onAttachmentRenamed: widget.onAttachmentRenamed,
        onAttachmentDeleted: widget.onAttachmentDeleted,
      ),
      'pre': QuietCodeBlockElementBuilder(
        colors: colors,
        typography: typography,
        highlighter: highlighter,
        resolver: resolver,
        searchQuery: widget.searchQuery,
      ),
    };

    if (widget.searchQuery != null && widget.searchQuery!.trim().isNotEmpty) {
      inlineSyntaxes.add(SearchMatchSyntax(widget.searchQuery!.trim()));
      builders['searchmark'] = SearchMatchElementBuilder(colors);
    }

    Widget customImageBuilder(Uri uri, String? title, String? alt) {
      final uriString = uri.toString();
      final qpUri = QuietPaperUri.tryParse(uriString);
      if (qpUri != null && qpUri.isAsset) {
        return QuietAssetImageView(
          assetId: qpUri.resourceId,
          altText: alt,
          title: title,
          onInsertText: widget.onInsertText,
        );
      }
      if (qpUri != null && qpUri.isDocument) {
        return QuietDocumentCard(
          documentId: qpUri.resourceId,
          title: (alt != null && alt.isNotEmpty)
              ? alt
              : (title ?? 'Scanned Document'),
          uriString: uriString,
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: ClipRRect(
          borderRadius: AppRadii.borderMd,
          child: Image.network(
            uriString,
            errorBuilder: (context, error, stackTrace) => Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: AppRadii.borderSm,
                border: Border.all(color: colors.divider),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined,
                      size: 16, color: colors.textTertiary),
                  const SizedBox(width: 8),
                  Text(
                    alt?.isNotEmpty == true ? alt! : 'Image unavailable',
                    style: AppTypography.caption
                        .copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget content;
    if (widget.shrinkWrap) {
      if (_chunks.isEmpty) {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) buildHeader(),
            MarkdownBody(
              key: ValueKey('preview_empty_${widget.searchQuery ?? ''}'),
              data: '*No content*',
              selectable: false,
              styleSheet: customStyleSheet,
              inlineSyntaxes: inlineSyntaxes,
              builders: builders,
              // ignore: deprecated_member_use
              imageBuilder: customImageBuilder,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              onTapLink: effectiveOnTapLink,
              softLineBreak: widget.softLineBreak,
            ),
          ],
        );
      } else {
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) buildHeader(),
            ..._chunks.map(
              (chunk) => MarkdownBody(
                key: ValueKey('preview_chunk_${chunk.hashCode}_${widget.searchQuery ?? ''}'),
                data: chunk,
                selectable: false,
                styleSheet: customStyleSheet,
                inlineSyntaxes: inlineSyntaxes,
                builders: builders,
                // ignore: deprecated_member_use
                imageBuilder: customImageBuilder,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                onTapLink: effectiveOnTapLink,
                softLineBreak: widget.softLineBreak,
              ),
            ),
          ],
        );
      }
    } else {
      final headerCount = hasHeader ? 1 : 0;
      final bodyCount = _chunks.isEmpty ? 1 : _chunks.length;
      const footerCount = 1;
      final totalCount = headerCount + bodyCount + footerCount;

      content = ListView.builder(
        controller: widget.scrollController,
        physics: widget.physics,
        padding: effectivePadding,
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (hasHeader && index == 0) {
            return buildHeader();
          }

          final bodyIndex = index - headerCount;
          if (bodyIndex < bodyCount) {
            if (_chunks.isEmpty) {
              return MarkdownBody(
                key: ValueKey('preview_empty_${widget.searchQuery ?? ''}'),
                data: '*No content*',
                selectable: false,
                styleSheet: customStyleSheet,
                inlineSyntaxes: inlineSyntaxes,
                builders: builders,
                // ignore: deprecated_member_use
                imageBuilder: customImageBuilder,
                extensionSet: md.ExtensionSet.gitHubFlavored,
                onTapLink: effectiveOnTapLink,
                softLineBreak: widget.softLineBreak,
              );
            }
            return MarkdownBody(
              key: ValueKey('preview_body_${bodyIndex}_${widget.searchQuery ?? ''}'),
              data: _chunks[bodyIndex],
              selectable: false,
              styleSheet: customStyleSheet,
              inlineSyntaxes: inlineSyntaxes,
              builders: builders,
              // ignore: deprecated_member_use
              imageBuilder: customImageBuilder,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              onTapLink: effectiveOnTapLink,
              softLineBreak: widget.softLineBreak,
            );
          }

          // Generous bottom scroll area for comfortable preview reading
          return const SizedBox(height: 120.0);
        },
      );
    }

    if (widget.selectable) {
      content = SelectionArea(child: content);
    }

    if (widget.scrollController != null && widget.showScrollbar && !widget.shrinkWrap) {
      content = IntelligentHeadingScrollbar(
        scrollController: widget.scrollController!,
        markdownData: widget.markdownData,
        title: effectiveTitle,
        child: content,
      );
    }

    return content;
  }
}

/// A clean editorial card displaying frontmatter properties (author, source, created date, description)
/// with subtle icons inspired by Obsidian properties and styled with Bear Notes warmth.
class QuietFrontmatterCard extends StatelessWidget {
  const QuietFrontmatterCard({
    super.key,
    required this.metadata,
    this.onTapLink,
  });

  final ParsedMarkdown metadata;
  final MarkdownTapLinkCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final rows = <Widget>[];

    // 1. Author
    if (metadata.author != null && metadata.author!.trim().isNotEmpty) {
      rows.add(
        _PropertyRow(
          icon: Icons.person_outline_rounded,
          label: 'Author',
          child: Text(
            metadata.author!.trim(),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
      );
    }

    // 2. Source
    if (metadata.source != null && metadata.source!.trim().isNotEmpty) {
      final source = metadata.source!.trim();
      final isUrl = source.startsWith('http://') ||
          source.startsWith('https://') ||
          source.startsWith('www.');

      rows.add(
        _PropertyRow(
          icon: Icons.link_rounded,
          label: 'Source',
          child: isUrl
              ? InkWell(
                  borderRadius: AppRadii.borderSm,
                  onTap: () {
                    final targetUrl = source.startsWith('www.')
                        ? 'https://$source'
                        : source;
                    onTapLink?.call(targetUrl, targetUrl, targetUrl);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            source,
                            style: AppTypography.bodySmall.copyWith(
                              color: colors.accent,
                              decoration: TextDecoration.underline,
                              decorationColor: colors.accent.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Icon(
                          Icons.open_in_new_rounded,
                          size: 13.0,
                          color: colors.accent,
                        ),
                      ],
                    ),
                  ),
                )
              : Text(
                  source,
                  style: AppTypography.bodySmall.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
        ),
      );
    }

    // 3. Created date
    if (metadata.createdAt != null ||
        (metadata.createdRaw != null && metadata.createdRaw!.trim().isNotEmpty)) {
      String displayDate;
      if (metadata.createdAt != null) {
        displayDate = DateFormat('MMM d, yyyy').format(metadata.createdAt!);
      } else {
        displayDate = metadata.createdRaw!.trim();
      }

      rows.add(
        _PropertyRow(
          icon: Icons.calendar_today_outlined,
          label: 'Created',
          child: Text(
            displayDate,
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
            ),
          ),
        ),
      );
    }

    // 4. Description
    if (metadata.description != null && metadata.description!.trim().isNotEmpty) {
      rows.add(
        _PropertyRow(
          icon: Icons.notes_rounded,
          label: 'Description',
          child: Text(
            metadata.description!.trim(),
            style: AppTypography.bodySmall.copyWith(
              color: colors.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.compact,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Divider(
                  color: colors.divider.withValues(alpha: 0.4),
                  height: 1,
                  thickness: 0.5,
                ),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.5),
            child: Icon(
              icon,
              size: 14.0,
              color: colors.textTertiary,
            ),
          ),
          const SizedBox(width: 8.0),
          SizedBox(
            width: 80.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          Expanded(child: child),
        ],
      ),
    );
  }
}

