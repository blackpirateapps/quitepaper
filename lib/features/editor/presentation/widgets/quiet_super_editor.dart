import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../settings/application/typography_provider.dart';
import '../../../settings/domain/typography_settings.dart';
import '../../application/frontmatter_editor_helper.dart';
import '../../application/quiet_super_editor_controller.dart';

/// Embedded block-based document editor surface powered by SuperEditor.
///
/// Features:
/// - Native [TaskNode] checklists with interactive checkboxes
/// - Standard CommonMark / GFM Markdown persistence via [serializeDocumentToMarkdown]
/// - Dynamic typography inheritance from [TypographySettings]
/// - Theme-aware styling bound to [AppColors]
/// - Frontmatter preservation for note metadata
class QuietSuperEditor extends ConsumerStatefulWidget {
  const QuietSuperEditor({
    super.key,
    required this.initialMarkdown,
    required this.onChanged,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.stripFrontmatter = false,
    this.hintText,
  });

  final String initialMarkdown;
  final ValueChanged<String> onChanged;
  final QuietSuperEditorController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool stripFrontmatter;
  final String? hintText;

  @override
  ConsumerState<QuietSuperEditor> createState() => _QuietSuperEditorState();
}

class _QuietSuperEditorState extends ConsumerState<QuietSuperEditor> {
  late Editor _editor;
  late MutableDocumentComposer _composer;
  String? _frontmatterPrefix;
  String _lastSerializedMarkdown = '';
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _initEditor();
  }

  void _initEditor() {
    String bodyMarkdown = widget.initialMarkdown;
    if (widget.stripFrontmatter) {
      final fmDoc = FrontmatterEditorHelper.parse(widget.initialMarkdown);
      if (fmDoc.hasFrontmatter) {
        _frontmatterPrefix = widget.initialMarkdown.substring(0, fmDoc.bodyStartOffset);
        bodyMarkdown = widget.initialMarkdown.substring(fmDoc.bodyStartOffset);
      } else {
        _frontmatterPrefix = null;
      }
    } else {
      _frontmatterPrefix = null;
    }

    final trimmed = bodyMarkdown.trim();
    final document = trimmed.isEmpty
        ? MutableDocument.empty()
        : deserializeMarkdownToDocument(bodyMarkdown);

    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: document,
      composer: _composer,
      isHistoryEnabled: true,
    );

    _lastSerializedMarkdown = widget.initialMarkdown;
    _editor.document.addListener(_onDocumentChange);
    widget.controller?.attach(_editor, _composer);
  }

  @override
  void didUpdateWidget(QuietSuperEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_editor, _composer);
    }
    if (widget.initialMarkdown != oldWidget.initialMarkdown &&
        widget.initialMarkdown != _lastSerializedMarkdown &&
        !_isInternalUpdate) {
      widget.controller?.detach();
      _editor.document.removeListener(_onDocumentChange);
      _editor.dispose();
      _composer.dispose();
      _initEditor();
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    _editor.document.removeListener(_onDocumentChange);
    _editor.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    if (!mounted || _isInternalUpdate) return;
    _isInternalUpdate = true;
    try {
      final bodyMarkdown = serializeDocumentToMarkdown(
        _editor.document,
        syntax: MarkdownSyntax.normal,
      );
      final fullMarkdown = _frontmatterPrefix != null
          ? '$_frontmatterPrefix$bodyMarkdown'
          : bodyMarkdown;
      _lastSerializedMarkdown = fullMarkdown;
      widget.onChanged(fullMarkdown);
    } finally {
      _isInternalUpdate = false;
    }
  }

  Stylesheet _buildStylesheet(AppColors colors, TypographySettings typography) {
    return Stylesheet(
      rules: [
        StyleRule(
          BlockSelector.all,
          (doc, docNode) => {
            Styles.maxWidth: double.infinity,
            Styles.padding: const CascadingPadding.symmetric(horizontal: 0),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.bodyFontFamily,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
              letterSpacing: typography.letterSpacing,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header1'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 24, bottom: 8),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading1Size,
              fontWeight: FontWeight.bold,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header2'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 20, bottom: 6),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading2Size,
              fontWeight: FontWeight.bold,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header3'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 16, bottom: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading3Size,
              fontWeight: FontWeight.bold,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header4'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 14, bottom: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading4Size,
              fontWeight: FontWeight.w600,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header5'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 12, bottom: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading5Size,
              fontWeight: FontWeight.w600,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('header6'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 12, bottom: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.headingFontFamily ?? typography.bodyFontFamily,
              fontSize: typography.scaledHeading6Size,
              fontWeight: FontWeight.w600,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('paragraph'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 4, bottom: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.bodyFontFamily,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('blockquote'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.only(top: 8, bottom: 8, left: 16),
            Styles.textStyle: TextStyle(
              color: colors.textSecondary,
              fontFamily: typography.bodyFontFamily,
              fontSize: typography.fontSize,
              fontStyle: FontStyle.italic,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('code'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.symmetric(horizontal: 16, vertical: 12),
            Styles.backgroundColor: colors.surfaceSecondary,
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.codeFontFamily ?? 'monospace',
              fontSize: typography.scaledCodeSize,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('task'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.symmetric(vertical: 4),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.bodyFontFamily,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('listItem'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.symmetric(vertical: 2),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.bodyFontFamily,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
            ),
          },
        ),
      ],
      inlineTextStyler: defaultInlineTextStyler,
      inlineWidgetBuilders: defaultInlineWidgetBuilderChain,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final stylesheet = _buildStylesheet(colors, typography);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            child: SuperEditor(
              editor: _editor,
              focusNode: widget.focusNode,
              shrinkWrap: true,
              stylesheet: stylesheet,
              selectionStyle: SelectionStyles(
                selectionColor: colors.selection,
              ),
              androidHandleColor: colors.accent,
              iOSHandleColor: colors.accent,
              documentOverlayBuilders: [
                const SuperEditorIosToolbarFocalPointDocumentLayerBuilder(),
                SuperEditorIosHandlesDocumentLayerBuilder(
                  handleColor: colors.accent,
                ),
                const SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder(),
                SuperEditorAndroidHandlesDocumentLayerBuilder(
                  caretColor: colors.accent,
                ),
                DefaultCaretOverlayBuilder(
                  caretStyle: CaretStyle(
                    width: 2,
                    color: colors.accent,
                  ),
                  displayOnAllPlatforms: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
