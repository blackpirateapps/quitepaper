import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/font_family_helper.dart';
import '../../../settings/application/typography_provider.dart';
import '../../../settings/domain/typography_settings.dart';
import '../../application/frontmatter_editor_helper.dart';
import '../../application/quiet_super_editor_controller.dart';
import 'super_editor/link_enhance_overlay.dart';
import 'super_editor/math/quiet_inline_math.dart';
import 'super_editor/math/quiet_math_block_component.dart';
import 'super_editor/math/quiet_math_block_node.dart';
import 'super_editor/math/quiet_math_parser.dart';
import 'super_editor/quiet_attachment_component.dart';
import 'super_editor/quiet_blockquote_component.dart';
import 'super_editor/quiet_code_block_component.dart';
import 'super_editor/quiet_horizontal_rule_component.dart';
import 'super_editor/quiet_image_component.dart';
import 'super_editor/quiet_link_preview_component.dart';
import 'super_editor/quiet_table_component.dart';
import 'super_editor/quiet_task_component.dart';
import 'super_editor/smart_task_controller.dart';
import 'super_editor/typewriter_document_layer.dart';

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
    this.noteId,
    this.onCaretPositionChanged,
    this.onPaste,
    this.onKeyEvent,
  });

  final String initialMarkdown;
  final ValueChanged<String> onChanged;
  final QuietSuperEditorController? controller;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool stripFrontmatter;
  final String? hintText;
  final String? noteId;
  final ValueChanged<Offset>? onCaretPositionChanged;
  final VoidCallback? onPaste;
  final FocusOnKeyEventCallback? onKeyEvent;

  @override
  ConsumerState<QuietSuperEditor> createState() => _QuietSuperEditorState();
}

class _QuietSuperEditorState extends ConsumerState<QuietSuperEditor> {
  late Editor _editor;
  late MutableDocumentComposer _composer;
  late SmartTaskController _smartTaskController;
  late final QuietDividerPlugin _dividerPlugin;
  late final QuietMathBlockPlugin _mathBlockPlugin;
  late final QuietPastePlugin _pastePlugin;
  final _linuxHomePlugin = QuietLinuxHomePlugin();
  late final QuietBlockquotePlugin _blockquotePlugin;
  String? _frontmatterPrefix;
  String _lastSerializedMarkdown = '';
  bool _isInternalUpdate = false;

  @override
  void initState() {
    super.initState();
    _dividerPlugin = QuietDividerPlugin();
    _mathBlockPlugin = QuietMathBlockPlugin();
    _pastePlugin = QuietPastePlugin(onPaste: widget.onPaste);
    _blockquotePlugin = QuietBlockquotePlugin();
    _smartTaskController = SmartTaskController()..addListener(_onSmartTaskChanged);
    _initEditor();
  }

  void _onSmartTaskChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _initEditor() {
    final split = _splitFrontmatter(widget.initialMarkdown);
    _frontmatterPrefix = split.prefix;
    _smartTaskController.reset();

    final normalized = normalizeMarkdownForSuperEditor(split.body);
    final trimmed = normalized.trim();
    final document = trimmed.isEmpty
        ? MutableDocument.empty()
        : deserializeQuietMathDocument(normalized);

    // Promote standalone `[name](qp://document|asset/...)` link paragraphs into
    // embedded attachment card nodes before the editor takes ownership.
    promoteQuietAttachmentNodes(document);

    // Promote baked two-line `[title](url)` + sentinel-comment pairs into
    // embedded web-link preview nodes, and promote lone unbaked web links into
    // loading preview nodes with animated skeleton loaders.
    promoteLinkPreviewNodes(document, promoteUnbaked: true);

    // Promote code block paragraphs with raw languages parsed from fences.
    promoteQuietCodeBlockNodes(document, split.body);

    // Promote math block paragraphs (\[ ... \], $$ ... $$, ```math) into QuietMathBlockNodes.
    promoteQuietMathBlockNodes(document);

    // Folded terminal tasks need a visible writing position below the summary.
    final lastTaskBlock = document.isNotEmpty
        ? SmartTaskController.findBlockForNode(document, document.last.id)
        : null;
    if (document.isNotEmpty &&
        (document.last is HorizontalRuleNode || lastTaskBlock?.hasCollapsibleCompleted == true)) {
      document.insertNodeAfter(
        existingNodeId: document.last.id,
        newNode: ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
        ),
      );
    }

    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: document,
      composer: _composer,
      isHistoryEnabled: true,
    );

    _editor.reactionPipeline.insert(0, const CodeBlockConversionReaction());
    _editor.requestHandlers.insert(0, handleCodeBlockFenceNewlineRequest);
    _editor.requestHandlers.insert(0, handleMathBlockFenceNewlineRequest);
    _editor.requestHandlers.insert(0, _handleMathPasteRequest);
    _editor.requestHandlers.insert(0, _smartTaskController.handleBoundaryDeletion);

    _lastSerializedMarkdown = widget.initialMarkdown;
    _editor.document.addListener(_onDocumentChange);
    _composer.selectionNotifier.addListener(_onSelectionChange);
    widget.controller?.attach(_editor, _composer);
  }

  void _onSelectionChange() {
    _smartTaskController.revealSelection(_editor.document, _composer.selection);
    if (mounted) {
      setState(() {});
    }
  }

  // Native selection-toolbar paste uses PasteEditorRequest instead of the app's
  // keyboard paste callback. Give it the same math parsing as controller paste.
  EditCommand? _handleMathPasteRequest(Editor editor, EditRequest request) {
    if (request is! PasteEditorRequest ||
        !QuietMathParser.containsMathSyntax(request.content)) {
      return null;
    }
    final target = editor.document.getNodeById(request.pastePosition.nodeId);
    if (target is ParagraphNode &&
        target.metadata[NodeMetadata.blockType] == codeAttribution) {
      return null;
    }
    final content = deserializeQuietMathDocument(
      normalizeMarkdownForSuperEditor(request.content),
    );
    promoteQuietAttachmentNodes(content);
    promoteLinkPreviewNodes(content);
    promoteQuietCodeBlockNodes(content, request.content);
    promoteQuietMathBlockNodes(content);
    return PasteStructuredContentEditorCommand(
      content: content,
      pastePosition: request.pastePosition,
    );
  }

  /// Splits [markdown] into its preserved frontmatter prefix and the editable
  /// body. When [QuietSuperEditor.stripFrontmatter] is false, the whole string
  /// is treated as body and there is no prefix.
  ({String? prefix, String body}) _splitFrontmatter(String markdown) {
    if (!widget.stripFrontmatter) {
      return (prefix: null, body: markdown);
    }
    final fmDoc = FrontmatterEditorHelper.parse(markdown);
    if (fmDoc.hasFrontmatter) {
      return (
        prefix: markdown.substring(0, fmDoc.bodyStartOffset),
        body: markdown.substring(fmDoc.bodyStartOffset),
      );
    }
    return (prefix: null, body: markdown);
  }

  @override
  void didUpdateWidget(QuietSuperEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPaste != oldWidget.onPaste) {
      _pastePlugin.onPaste = widget.onPaste;
    }
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(_editor, _composer);
    }
    if (widget.initialMarkdown != oldWidget.initialMarkdown &&
        widget.initialMarkdown != _lastSerializedMarkdown &&
        !_isInternalUpdate) {
      // Detect a frontmatter-only change (e.g. the Properties card edited note
      // metadata). The body is byte-identical in that case, so refresh the
      // preserved prefix in place instead of rebuilding the whole SuperEditor
      // document. This keeps the caret and selection, avoids flicker, and
      // prevents a stale prefix from clobbering the metadata edit on the next
      // body change.
      final structuralChange = widget.stripFrontmatter != oldWidget.stripFrontmatter;
      final oldSplit = _splitFrontmatter(oldWidget.initialMarkdown);
      final newSplit = _splitFrontmatter(widget.initialMarkdown);
      if (!structuralChange && widget.stripFrontmatter && newSplit.body == oldSplit.body) {
        _frontmatterPrefix = newSplit.prefix;
        _lastSerializedMarkdown = widget.initialMarkdown;
      } else {
        widget.controller?.detach();
        _editor.document.removeListener(_onDocumentChange);
        _editor.dispose();
        _composer.dispose();
        _initEditor();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _smartTaskController.removeListener(_onSmartTaskChanged);
    _smartTaskController.dispose();
    widget.controller?.detach();
    _composer.selectionNotifier.removeListener(_onSelectionChange);
    _editor.document.removeListener(_onDocumentChange);
    _editor.dispose();
    _composer.dispose();
    super.dispose();
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    if (!mounted || _isInternalUpdate) return;
    _isInternalUpdate = true;
    try {
      _smartTaskController.reconcile(_editor.document);
      _smartTaskController.revealSelection(_editor.document, _composer.selection);
      final bodyMarkdown = serializeDocumentToMarkdown(
        _editor.document,
        syntax: MarkdownSyntax.normal,
        customNodeSerializers: const [
          QuietTaskNodeSerializer(),
          QuietImageNodeSerializer(),
          QuietAttachmentNodeSerializer(),
          LinkPreviewNodeSerializer(),
          QuietTableBlockNodeSerializer(),
          QuietCodeBlockNodeSerializer(),
          QuietMathBlockNodeSerializer(),
        ],
      );
      final normalizedBody = normalizeInlineMarkdownSpacing(bodyMarkdown);
      final fullMarkdown = _frontmatterPrefix != null
          ? '$_frontmatterPrefix$normalizedBody'
          : normalizedBody;
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('blockquote'),
          (doc, docNode) => {
            Styles.padding: const CascadingPadding.symmetric(horizontal: 0, vertical: 0),
            Styles.textStyle: TextStyle(
              color: colors.textSecondary,
              fontFamily: typography.bodyFontFamily,
              fontFamilyFallback: kContentFontFallback,
              fontSize: typography.fontSize,
              fontStyle: FontStyle.italic,
              height: typography.lineHeight,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('code'),
          (doc, docNode) => {
            Styles.maxWidth: double.infinity,
            Styles.padding: const CascadingPadding.symmetric(horizontal: 0, vertical: 0),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.codeFontFamily ?? 'monospace',
              fontFamilyFallback: kContentFontFallback,
              fontSize: typography.scaledCodeSize,
            ),
          },
        ),
        StyleRule(
          const BlockSelector('task'),
          (doc, docNode) => {
            // Visible rows own their spacing; folded rows consume no padding.
            Styles.padding: const CascadingPadding.symmetric(vertical: 0),
            Styles.textStyle: TextStyle(
              color: colors.textPrimary,
              fontFamily: typography.bodyFontFamily,
              fontFamilyFallback: kContentFontFallback,
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
              fontFamilyFallback: kContentFontFallback,
              fontSize: typography.fontSize,
              height: typography.lineHeight,
            ),
          },
        ),
      ],
      inlineTextStyler: defaultInlineTextStyler,
      inlineWidgetBuilders: [
        inlineMathWidgetBuilder,
        ...defaultInlineWidgetBuilderChain,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = ref.watch(typographySettingsProvider);
    final stylesheet = _buildStylesheet(colors, typography);

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget editorWidget = SuperEditor(
          editor: _editor,
          focusNode: widget.focusNode,
          shrinkWrap: true,
          stylesheet: stylesheet,
          selectionPolicies: const SuperEditorSelectionPolicies(
            placeCaretAtEndOfDocumentOnGainFocus: false,
          ),
          plugins: {
            _dividerPlugin,
            _mathBlockPlugin,
            _pastePlugin,
            _linuxHomePlugin,
            _blockquotePlugin,
          },
          contentTapDelegateFactories: const [
            superEditorLaunchLinkTapHandlerFactory,
            quietMathBlockTapHandlerFactory,
            quietDividerTapHandlerFactory,
            superEditorAddEmptyParagraphTapHandlerFactory,
          ],
          componentBuilders: [
            QuietMathBlockComponentBuilder(_editor),
            QuietMathParagraphComponentBuilder(_editor),
            QuietMathListItemComponentBuilder(_editor),
            QuietCodeBlockComponentBuilder(_editor),
            const QuietBlockquoteComponentBuilder(),
            QuietTaskComponentBuilder(
              _editor,
              smartTaskController: _smartTaskController,
            ),
            QuietImageComponentBuilder(noteId: widget.noteId),
            QuietAttachmentComponentBuilder(
              editor: _editor,
              noteId: widget.noteId,
              showRemove: !widget.readOnly,
            ),
            LinkPreviewComponentBuilder(
              editor: _editor,
              noteId: widget.noteId,
              showRemove: !widget.readOnly,
            ),
            QuietTableComponentBuilder(editor: _editor),
            QuietHorizontalRuleComponentBuilder(_editor),
            if (widget.hintText?.isNotEmpty == true && !widget.readOnly)
              _EmptyBodyHintComponentBuilder(
                widget.hintText!,
                (_) => TextStyle(
                  color: colors.textTertiary,
                  fontFamily: typography.bodyFontFamily,
                  fontFamilyFallback: kContentFontFallback,
                  fontSize: typography.fontSize,
                  height: typography.lineHeight,
                ),
              ),
            ...defaultComponentBuilders,
          ],
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
            LinkEnhanceDocumentLayerBuilder(
              controller: widget.controller,
              readOnly: widget.readOnly,
            ),
            if (widget.onCaretPositionChanged != null)
              TypewriterDocumentLayerBuilder(
                onCaretGlobalPosition: widget.onCaretPositionChanged!,
              ),
          ],
        );

        if (widget.onKeyEvent != null) {
          editorWidget = Focus(
            onKeyEvent: widget.onKeyEvent,
            child: editorWidget,
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
            child: editorWidget,
          ),
        );
      },
    );
  }
}

/// Keep the body hint out of headings and other formatted empty blocks.
class _EmptyBodyHintComponentBuilder extends HintComponentBuilder {
  const _EmptyBodyHintComponentBuilder(super.hint, super.hintStyleBuilder);

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode || node.text.isNotEmpty) return null;
    final blockType = node.getMetadataValue(NodeMetadata.blockType);
    if (blockType != null && blockType != paragraphAttribution) return null;
    return super.createViewModel(document, node);
  }
}

/// Plugin that intercepts Ctrl+V / Cmd+V paste events in SuperEditor and routes
/// them to [onPaste], preventing SuperEditor from silently swallowing image/file pastes.
class QuietPastePlugin extends SuperEditorPlugin {
  QuietPastePlugin({this.onPaste});
  VoidCallback? onPaste;

  @override
  List<SuperEditorKeyboardAction> get keyboardActions => [
        _pasteKeyboardAction,
      ];

  ExecutionInstruction _pasteKeyboardAction({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    if (onPaste == null) return ExecutionInstruction.continueExecution;
    if (keyEvent is! KeyDownEvent) {
      return ExecutionInstruction.continueExecution;
    }
    if (!HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed) {
      return ExecutionInstruction.continueExecution;
    }
    if (HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.isAltPressed) {
      return ExecutionInstruction.continueExecution;
    }
    if (keyEvent.logicalKey != LogicalKeyboardKey.keyV) {
      return ExecutionInstruction.continueExecution;
    }

    onPaste!();
    return ExecutionInstruction.haltExecution;
  }
}

/// Consume Linux Home even when the caret is already at the line boundary.
/// Falling through sends the key to the native IME, whose placeholder-backed
/// buffer can be echoed into the document as inserted text (e.g. `. TailTail`).
class QuietLinuxHomePlugin extends SuperEditorPlugin {
  @override
  List<SuperEditorKeyboardAction> get keyboardActions => [_handleHome];

  ExecutionInstruction _handleHome({
    required SuperEditorContext editContext,
    required KeyEvent keyEvent,
  }) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux ||
        (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) ||
        keyEvent.logicalKey != LogicalKeyboardKey.home ||
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed ||
        editContext.composer.selection == null) {
      return ExecutionInstruction.continueExecution;
    }
    editContext.commonOps.moveCaretUpstream(
      expand: HardwareKeyboard.instance.isShiftPressed,
      movementModifier: MovementModifier.line,
    );
    return ExecutionInstruction.haltExecution;
  }
}
