import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart' hide SyntaxHighlighter;
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/markdown/markdown_highlight.dart';
import '../../../../core/markdown/quiet_code_block_element_builder.dart';
import '../../../../core/syntax/application/syntax_highlighter.dart';
import '../../../../core/syntax/application/syntax_language_resolver.dart';
import '../../../../features/editor/application/rich_document_serializer.dart';
import '../../../../features/editor/domain/rich_document.dart';
import '../../../../features/notes/domain/note_model.dart';
import '../../../../features/settings/domain/typography_settings.dart';
import '../../../../features/tags/domain/tag_colors.dart';
import '../../domain/export_models.dart';

/// Editorial presentation card designed for rasterizing a whole note into a screenshot image.
/// Preserves Quiet Paper branding, typography hierarchy, and complete colorization.
class NoteScreenshotCard extends StatelessWidget {
  const NoteScreenshotCard({
    super.key,
    required this.snapshot,
    required this.options,
    this.highlighter,
    this.resolver,
    this.typography = const TypographySettings(),
  });

  final NoteExportSnapshot snapshot;
  final ImageExportOptions options;
  final SyntaxHighlighter? highlighter;
  final SyntaxLanguageResolver? resolver;
  final TypographySettings typography;

  AppColors _resolveColors(BuildContext context) {
    switch (options.themeMode) {
      case 'dark':
        return AppColors.classicDark;
      case 'warm':
        return AppColors.warmPaperLight;
      case 'light':
        return AppColors.classicLight;
      case 'current':
      default:
        final theme = Theme.of(context);
        return theme.extension<AppColors>() ?? AppColors.classicLight;
    }
  }

  TagColorDefinition _resolveTagColor(String tag) {
    final byId = TagColors.fromId(tag);
    if (byId != null) return byId;
    final idx = tag.hashCode.abs() % TagColors.all.length;
    return TagColors.all[idx];
  }

  String _cleanMarkdownBody(String rawMarkdown) {
    var content = rawMarkdown;
    if (Note.isRichTextContent(content)) {
      try {
        final doc = RichDocument.fromJson(jsonDecode(content) as Map<String, dynamic>);
        content = const RichDocumentSerializer().serialize(doc);
      } catch (_) {}
    }
    // Strip YAML frontmatter delimiters from preview if present
    if (content.startsWith('---')) {
      final endIndex = content.indexOf('\n---', 3);
      if (endIndex != -1) {
        content = content.substring(endIndex + 4).trimLeft();
      }
    }
    return content;
  }

  MarkdownStyleSheet _buildScreenshotStyleSheet(AppColors colors) {
    return MarkdownStyleSheet(
      p: AppTypography.editorBody.copyWith(
        color: colors.textPrimary,
        fontSize: 16.0,
        height: 1.6,
      ),
      h1: AppTypography.title.copyWith(
        color: colors.textPrimary,
        fontSize: 26.0,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h2: AppTypography.title.copyWith(
        color: colors.textPrimary,
        fontSize: 22.0,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      h3: AppTypography.headline.copyWith(
        color: colors.textPrimary,
        fontSize: 19.0,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      h4: AppTypography.headline.copyWith(
        color: colors.textPrimary,
        fontSize: 17.0,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      h5: AppTypography.body.copyWith(
        color: colors.textPrimary,
        fontSize: 15.0,
        fontWeight: FontWeight.w600,
      ),
      h6: AppTypography.bodySmall.copyWith(
        color: colors.textSecondary,
        fontSize: 14.0,
        fontWeight: FontWeight.w600,
      ),
      strong: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      em: TextStyle(
        color: colors.textPrimary,
        fontStyle: FontStyle.italic,
      ),
      blockquote: AppTypography.editorBody.copyWith(
        color: colors.textSecondary,
        fontSize: 15.5,
        fontStyle: FontStyle.italic,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8.0)),
        border: Border(
          left: BorderSide(
            color: colors.accent,
            width: 3.5,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      code: TextStyle(
        color: colors.textPrimary,
        backgroundColor: colors.codeBackground,
        fontFamily: typography.codeFontFamily ?? 'monospace',
        fontSize: 13.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.codeBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: colors.codeBorder, width: 0.8),
      ),
      codeblockPadding: const EdgeInsets.all(14.0),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1.0),
        ),
      ),
      a: TextStyle(
        color: colors.accent,
        decoration: TextDecoration.underline,
        decorationColor: colors.accent.withValues(alpha: 0.5),
      ),
      listBullet: TextStyle(
        color: colors.accent,
        fontWeight: FontWeight.w600,
      ),
      tableHead: TextStyle(
        color: colors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      tableBody: TextStyle(
        color: colors.textPrimary,
      ),
      tableBorder: TableBorder.all(
        color: colors.divider,
        width: 0.8,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    );
  }

  Widget _buildScreenshotImage(
    Uri uri,
    List<ExportAttachmentItem> attachments,
    AppColors colors,
  ) {
    final uriStr = uri.toString().trim();

    // Check attachments
    for (final att in attachments) {
      if (att.relativePath == uriStr ||
          att.id == uriStr ||
          'qp://asset/${att.id}' == uriStr) {
        if (att.hasBytes) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.memory(
                att.bytes!,
                fit: BoxFit.contain,
              ),
            ),
          );
        } else if (att.cloudUrl != null && att.cloudUrl!.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.network(
                att.cloudUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
          );
        }
      }
    }

    // Network image fallback
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            uriStr,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _resolveColors(context);
    final cleanMarkdown = _cleanMarkdownBody(snapshot.markdown);
    final dateFmt = DateFormat('MMMM d, yyyy');

    return Container(
      width: options.logicalWidth,
      color: colors.background,
      padding: const EdgeInsets.fromLTRB(40.0, 44.0, 40.0, 40.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Document Title
          if (snapshot.effectiveTitle.isNotEmpty) ...[
            Text(
              snapshot.effectiveTitle,
              style: AppTypography.title.copyWith(
                fontSize: 28.0,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
                height: 1.25,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12.0),
          ],

          // 2. Metadata (Created Date)
          if (options.includeMetadata) ...[
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 13.0,
                  color: colors.textTertiary,
                ),
                const SizedBox(width: 6.0),
                Text(
                  dateFmt.format(snapshot.createdAt.toLocal()),
                  style: AppTypography.caption.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
          ],

          // 3. Tag Pills (Colorized with TagColorDefinition)
          if (options.includeTags && snapshot.tags.isNotEmpty) ...[
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: snapshot.tags.map((tag) {
                final colorDef = _resolveTagColor(tag);
                final isDark = colors.isDark;
                final bg = colorDef.background(isDark);
                final fg = colorDef.foreground(isDark);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(
                      color: fg.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    '#$tag',
                    style: TextStyle(
                      color: fg,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18.0),
            Divider(color: colors.divider.withValues(alpha: 0.6), height: 1.0),
            const SizedBox(height: 20.0),
          ] else if (snapshot.effectiveTitle.isNotEmpty || options.includeMetadata) ...[
            const SizedBox(height: 6.0),
          ],

          // 4. Markdown Content (with Syntax Highlighting & Inline Highlights)
          MarkdownBody(
            data: cleanMarkdown,
            selectable: false,
            shrinkWrap: true,
            extensionSet: md.ExtensionSet.gitHubFlavored,
            inlineSyntaxes: [
              HighlightSyntax(),
            ],
            builders: {
              'mark': HighlightElementBuilder(colors),
              if (highlighter != null && resolver != null)
                'pre': QuietCodeBlockElementBuilder(
                  colors: colors,
                  typography: typography,
                  highlighter: highlighter!,
                  resolver: resolver!,
                ),
            },
            checkboxBuilder: (bool checked) {
              return Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18.0,
                color: checked ? colors.accent : colors.textTertiary,
              );
            },
            // ignore: deprecated_member_use
            imageBuilder: (uri, title, alt) {
              return _buildScreenshotImage(uri, snapshot.attachments, colors);
            },
            styleSheet: _buildScreenshotStyleSheet(colors),
          ),

          // 5. Official Quiet Paper Editorial Branding Footer
          if (options.includeBranding) ...[
            const SizedBox(height: 36.0),
            Container(
              padding: const EdgeInsets.only(top: 16.0),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colors.divider.withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Quiet Paper Icon + Name
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24.0,
                        height: 24.0,
                        margin: const EdgeInsets.only(right: 8.0),
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Icon(
                          Icons.article_outlined,
                          size: 14.0,
                          color: colors.accent,
                        ),
                      ),
                      Text(
                        options.brandingTitle,
                        style: AppTypography.caption.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.0,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),

                  // Right: Official Website URL
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(
                        color: colors.divider.withValues(alpha: 0.6),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      options.brandingUrl,
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
