import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../../features/editor/presentation/widgets/tag_editor_bar.dart';
import 'markdown_chunker.dart';

class QuietMarkdownPreview extends StatefulWidget {
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

  @override
  State<QuietMarkdownPreview> createState() => _QuietMarkdownPreviewState();
}

class _QuietMarkdownPreviewState extends State<QuietMarkdownPreview> {
  late List<String> _chunks;

  @override
  void initState() {
    super.initState();
    _chunks = MarkdownChunker.split(widget.markdownData);
  }

  @override
  void didUpdateWidget(QuietMarkdownPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdownData != widget.markdownData) {
      _chunks = MarkdownChunker.split(widget.markdownData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final customStyleSheet = MarkdownStyleSheet(
      h1: AppTypography.editorH1.copyWith(color: colors.textPrimary),
      h2: AppTypography.editorH2.copyWith(color: colors.textPrimary),
      h3: AppTypography.editorH3.copyWith(color: colors.textPrimary),
      p: AppTypography.editorBody.copyWith(color: colors.textPrimary),
      pPadding: const EdgeInsets.only(bottom: AppSpacing.md),
      blockquote: AppTypography.editorQuote.copyWith(
        color: colors.textSecondary,
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
      code: AppTypography.editorCode.copyWith(
        color: colors.accentDark,
        backgroundColor: colors.tagBackground,
      ),
      codeblockDecoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderSm,
        border: Border.all(color: colors.divider),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.divider, width: 1),
        ),
      ),
      listBullet: AppTypography.editorBody.copyWith(color: colors.accent),
      listBulletPadding: const EdgeInsets.only(right: AppSpacing.sm),
      a: AppTypography.editorBody.copyWith(
        color: colors.accent,
        decoration: TextDecoration.underline,
        decorationColor: colors.accent.withValues(alpha: 0.5),
      ),
      tableHead: AppTypography.bodySmallMedium.copyWith(color: colors.textPrimary),
      tableBody: AppTypography.bodySmall.copyWith(color: colors.textSecondary),
      tableBorder: TableBorder.all(color: colors.divider, width: 1),
      tableHeadAlign: TextAlign.left,
      tablePadding: const EdgeInsets.all(AppSpacing.sm),
    );

    final hasHeader = widget.header != null ||
        (widget.title != null && widget.title!.trim().isNotEmpty) ||
        (widget.tags != null && widget.tags!.isNotEmpty);

    Widget buildHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.header != null) widget.header!,
          if (widget.title != null && widget.title!.trim().isNotEmpty) ...[
            Text(
              widget.title!,
              style: AppTypography.editorTitle.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 24.0),
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

    if (widget.shrinkWrap) {
      if (_chunks.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeader) buildHeader(),
            MarkdownBody(
              data: '*No content*',
              selectable: widget.selectable,
              styleSheet: customStyleSheet,
              onTapLink: widget.onTapLink,
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) buildHeader(),
          ..._chunks.map(
            (chunk) => MarkdownBody(
              data: chunk,
              selectable: widget.selectable,
              styleSheet: customStyleSheet,
              onTapLink: widget.onTapLink,
            ),
          ),
        ],
      );
    }

    final headerCount = hasHeader ? 1 : 0;
    final bodyCount = _chunks.isEmpty ? 1 : _chunks.length;
    const footerCount = 1;
    final totalCount = headerCount + bodyCount + footerCount;

    return ListView.builder(
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
              data: '*No content*',
              selectable: widget.selectable,
              styleSheet: customStyleSheet,
              onTapLink: widget.onTapLink,
            );
          }
          return MarkdownBody(
            data: _chunks[bodyIndex],
            selectable: widget.selectable,
            styleSheet: customStyleSheet,
            onTapLink: widget.onTapLink,
          );
        }

        // Generous bottom scroll area for comfortable preview reading
        return const SizedBox(height: 120.0);
      },
    );
  }
}
