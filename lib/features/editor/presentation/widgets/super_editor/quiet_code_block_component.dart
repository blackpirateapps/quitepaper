import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quitepaper/app/theme/app_colors.dart';
import 'package:quitepaper/app/theme/app_radii.dart';
import 'package:quitepaper/app/theme/app_spacing.dart';
import 'package:quitepaper/app/theme/app_typography.dart';
import 'package:quitepaper/core/syntax/application/syntax_language_registry.dart';
import 'package:quitepaper/core/syntax/application/syntax_language_resolver.dart';
import 'package:quitepaper/core/syntax/domain/highlight_result.dart';
import 'package:quitepaper/core/syntax/domain/syntax_theme.dart';
import 'package:quitepaper/core/syntax/domain/syntax_token_type.dart';
import 'package:quitepaper/core/syntax/infrastructure/highlight_package_adapter.dart';
import 'package:quitepaper/core/syntax/presentation/language_selector_sheet.dart';
import 'package:quitepaper/core/utils/font_family_helper.dart';
import 'package:quitepaper/core/widgets/quiet_icon_button.dart';
import 'package:quitepaper/features/editor/application/markdown_code_block_parser.dart';
import 'package:quitepaper/features/settings/domain/typography_settings.dart';
import 'package:super_editor/super_editor.dart';

/// Promotion pass that associates raw code fence languages with [ParagraphNode]s
/// representing code blocks in a [MutableDocument].
///
/// Stock `super_editor_markdown` parses fenced code blocks into [ParagraphNode]s
/// with `blockType: codeAttribution`, but discards the language tag. This pass
/// matches each code block paragraph with its parsed [MarkdownCodeBlockInfo]
/// from [MarkdownCodeBlockParser] and records the language in `node.metadata['language']`.
void promoteQuietCodeBlockNodes(Document document, String markdown) {
  if (document is! MutableDocument) return;
  final codeBlockInfos = MarkdownCodeBlockParser.parse(markdown);
  if (codeBlockInfos.isEmpty) return;

  var infoIndex = 0;
  for (int i = 0; i < document.nodeCount; i++) {
    final node = document.getNodeAt(i);
    if (node is ParagraphNode &&
        node.metadata[NodeMetadata.blockType] == codeAttribution) {
      if (infoIndex < codeBlockInfos.length) {
        final info = codeBlockInfos[infoIndex];
        final rawLang = info.rawLanguage.trim();
        if (rawLang.isNotEmpty) {
          final updatedNode = node.copyParagraphWith(
            metadata: {
              ...node.metadata,
              'language': rawLang,
            },
          );
          document.replaceNodeById(node.id, updatedNode);
        }
        infoIndex++;
      }
    }
  }
}

/// Custom [DocumentNodeMarkdownSerializer] for serializing [ParagraphNode] code blocks
/// with their assigned language identifier into fenced Markdown blocks:
///
/// ```dart
/// void main() {}
/// ```
class QuietCodeBlockNodeSerializer implements DocumentNodeMarkdownSerializer {
  const QuietCodeBlockNodeSerializer();

  @override
  String? serialize(
    Document document,
    DocumentNode node, {
    NodeSelection? selection,
  }) {
    if (node is! ParagraphNode) {
      return null;
    }
    if (node.metadata[NodeMetadata.blockType] != codeAttribution) {
      return null;
    }

    if (selection != null && selection is! TextNodeSelection) {
      return '';
    }
    final textSelection = selection as TextNodeSelection?;
    if (textSelection != null && textSelection.isCollapsed) {
      return '';
    }

    final codeText = textSelection != null
        ? node.text.copyText(textSelection.start, textSelection.end).toPlainText()
        : node.text.toPlainText();

    final language = (node.metadata['language'] as String?)?.trim() ?? '';
    final buffer = StringBuffer();
    buffer.writeln('```$language');
    buffer.write(codeText);
    if (!codeText.endsWith('\n')) {
      buffer.writeln();
    }
    buffer.write('```');

    final nodeIndex = document.getNodeIndexById(node.id);
    if (nodeIndex != document.nodeCount - 1) {
      buffer.writeln();
    }

    return buffer.toString();
  }
}

/// Request handler that intercepts [InsertNewlineAtCaretRequest] when the user
/// is at the end of a paragraph consisting solely of a code fence (e.g. ````, ````dart, `~~~`, `~~~python`)
/// and converts it directly into a code block with that language instead of splitting the node.
EditCommand? handleCodeBlockFenceNewlineRequest(
  Editor editor,
  EditRequest request,
) {
  if (request is! InsertNewlineAtCaretRequest) return null;

  final selection = editor.composer.selection;
  if (selection == null || !selection.isCollapsed) return null;

  final base = selection.base;
  final node = editor.document.getNodeById(base.nodeId);
  if (node is! ParagraphNode) return null;
  if (node.metadata[NodeMetadata.blockType] == codeAttribution) return null;

  final text = node.text.toPlainText();
  final fenceRegex = RegExp(r'^\s*(?:```|~~~)([a-zA-Z0-9_\-\+]*)\s*$');
  final match = fenceRegex.firstMatch(text);
  if (match == null) return null;

  final rawLang = match.group(1)?.trim() ?? '';
  return _ConvertParagraphToCodeBlockCommand(
    nodeId: node.id,
    language: rawLang,
  );
}

class _ConvertParagraphToCodeBlockCommand extends EditCommand {
  const _ConvertParagraphToCodeBlockCommand({
    required this.nodeId,
    required this.language,
  });

  final String nodeId;
  final String language;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final node = context.document.getNodeById(nodeId);
    if (node is! ParagraphNode) return;

    executor.executeCommand(
      ReplaceNodeCommand(
        existingNodeId: nodeId,
        newNode: ParagraphNode(
          id: nodeId,
          text: AttributedText(),
          metadata: {
            ...node.metadata,
            NodeMetadata.blockType: codeAttribution,
            if (language.isNotEmpty) 'language': language,
          },
        ),
      ),
    );

    executor.executeCommand(
      ChangeSelectionCommand(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: nodeId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    );
  }
}

/// An [EditReaction] that converts a paragraph to a code block when the user types
/// ```` or ````<lang> followed by a space.
class CodeBlockConversionReaction extends ParagraphPrefixConversionReaction {
  static final _fenceSpacePattern =
      RegExp(r'^(?:```|~~~)([a-zA-Z0-9_\-\+]*)\s$');

  const CodeBlockConversionReaction() : super(requireSpaceInsertion: true);

  @override
  RegExp get pattern => _fenceSpacePattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    if (paragraph.metadata[NodeMetadata.blockType] == codeAttribution) return;

    final langMatch = _fenceSpacePattern.firstMatch(match);
    final rawLang = langMatch?.group(1)?.trim() ?? '';

    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ParagraphNode(
          id: paragraph.id,
          text: AttributedText(),
          metadata: {
            ...paragraph.metadata,
            NodeMetadata.blockType: codeAttribution,
            if (rawLang.isNotEmpty) 'language': rawLang,
          },
        ),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: paragraph.id,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// Custom [ComponentBuilder] for SuperEditor that renders code block paragraphs
/// as an editorial card with language pill, copy button, subtle line numbers,
/// and live syntax highlighting.
class QuietCodeBlockComponentBuilder implements ComponentBuilder {
  QuietCodeBlockComponentBuilder(this._editor);

  final Editor _editor;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! ParagraphNode) return null;
    if (node.metadata[NodeMetadata.blockType] != codeAttribution) return null;

    final textDirection = getParagraphDirection(node.text.toPlainText());
    final rawLanguage = (node.metadata['language'] as String?)?.trim() ?? '';

    return QuietCodeBlockComponentViewModel(
      nodeId: node.id,
      createdAt: node.metadata[NodeMetadata.createdAt],
      padding: EdgeInsets.zero,
      text: node.text,
      language: rawLanguage,
      textDirection: textDirection,
      textAlignment: TextAlign.left,
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! QuietCodeBlockComponentViewModel) return null;

    final node = _editor.document.getNodeById(componentViewModel.nodeId);
    if (node is! ParagraphNode) return null;

    return QuietCodeBlockComponent(
      key: componentContext.componentKey,
      viewModel: componentViewModel,
      editor: _editor,
      node: node,
    );
  }
}

/// View model for [QuietCodeBlockComponent].
class QuietCodeBlockComponentViewModel
    extends SingleColumnLayoutComponentViewModel with TextComponentViewModel {
  QuietCodeBlockComponentViewModel({
    required super.nodeId,
    super.createdAt,
    super.padding = EdgeInsets.zero,
    required this.text,
    required this.language,
    required this.textStyleBuilder,
    this.inlineWidgetBuilders = const [],
    this.textDirection = TextDirection.ltr,
    this.textAlignment = TextAlign.left,
    this.textScaler,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.selection,
    required this.selectionColor,
    this.highlightWhenEmpty = false,
  });

  @override
  AttributedText text;
  String language;

  @override
  AttributionStyleBuilder textStyleBuilder;
  @override
  InlineWidgetBuilderChain inlineWidgetBuilders;
  @override
  TextDirection textDirection;
  @override
  TextAlign textAlignment;
  @override
  int? maxLines;
  @override
  TextOverflow overflow;
  TextScaler? textScaler;
  @override
  TextSelection? selection;
  @override
  Color selectionColor;
  @override
  bool highlightWhenEmpty;

  @override
  QuietCodeBlockComponentViewModel copy() {
    return internalCopy(
      QuietCodeBlockComponentViewModel(
        nodeId: nodeId,
        createdAt: createdAt,
        padding: padding,
        text: text.copyText(0),
        language: language,
        textStyleBuilder: textStyleBuilder,
        inlineWidgetBuilders: inlineWidgetBuilders,
        textDirection: textDirection,
        textAlignment: textAlignment,
        textScaler: textScaler,
        maxLines: maxLines,
        overflow: overflow,
        selection: selection,
        selectionColor: selectionColor,
        highlightWhenEmpty: highlightWhenEmpty,
      ),
    ) as QuietCodeBlockComponentViewModel;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other &&
          other is QuietCodeBlockComponentViewModel &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          language == other.language;

  @override
  int get hashCode => Object.hash(super.hashCode, text, language);
}

/// A document component displaying an editable code block in Quiet Paper's
/// editorial aesthetic with live syntax highlighting, language selector,
/// 1-tap copy button, and subtle line numbers.
class QuietCodeBlockComponent extends StatefulWidget {
  const QuietCodeBlockComponent({
    super.key,
    required this.viewModel,
    required this.editor,
    required this.node,
    this.showDebugPaint = false,
  });

  final QuietCodeBlockComponentViewModel viewModel;
  final Editor editor;
  final ParagraphNode node;
  final bool showDebugPaint;

  @override
  State<QuietCodeBlockComponent> createState() =>
      _QuietCodeBlockComponentState();
}

class _QuietCodeBlockComponentState extends State<QuietCodeBlockComponent>
    with
        ProxyDocumentComponent<QuietCodeBlockComponent>,
        ProxyTextComposable {
  final _textKey = GlobalKey();
  bool _copied = false;
  Timer? _copyResetTimer;

  // Dedicated syntax resolver & highlighter instances (cached)
  static final _resolver =
      SyntaxLanguageResolver(registry: SyntaxLanguageRegistry.instance);
  static final _highlighter = HighlightPackageAdapter();

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  GlobalKey<State<StatefulWidget>> get childDocumentComponentKey => _textKey;

  @override
  TextComposable get childTextComposable =>
      childDocumentComponentKey.currentState as TextComposable;

  DocumentComponent get _childDocComponent =>
      childDocumentComponentKey.currentState as DocumentComponent;

  Offset _getOffsetFromChild(Offset childOffset) {
    final myBox = context.findRenderObject() as RenderBox?;
    final childContext = childDocumentComponentKey.currentContext;
    if (myBox == null || childContext == null) return childOffset;
    final childBox = childContext.findRenderObject() as RenderBox?;
    if (childBox == null) return childOffset;
    return childBox.localToGlobal(childOffset, ancestor: myBox);
  }

  /// Translates caret geometry by the offset of the child [TextComponent] relative
  /// to this component box. This accounts for the header bar, hairline divider,
  /// gutter width, and internal padding.
  @override
  CaretGeometry getCaretForPosition(NodePosition nodePosition) {
    final childCaret = _childDocComponent.getCaretForPosition(nodePosition);
    final childOffset = _getOffsetFromChild(Offset.zero);
    return childCaret.translate(childOffset);
  }

  Future<void> _copyCode() async {
    final plainText = widget.viewModel.text.toPlainText();
    await Clipboard.setData(ClipboardData(text: plainText));
    if (mounted) {
      setState(() => _copied = true);
      _copyResetTimer?.cancel();
      _copyResetTimer = Timer(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  Future<void> _changeLanguage(BuildContext context) async {
    final selected = await LanguageSelectorSheet.show(
      context,
      currentLanguageId: widget.viewModel.language,
      title: 'Select Code Language',
    );
    if (selected != null && mounted) {
      widget.editor.execute([
        ReplaceNodeRequest(
          existingNodeId: widget.node.id,
          newNode: widget.node.copyParagraphWith(
            metadata: {
              ...widget.node.metadata,
              'language': selected.id,
            },
          ),
        ),
      ]);
    }
  }

  /// Builds a decorated [AttributedText] for presentation containing syntax
  /// attributions (`NamedAttribution('syntax_<type>')`) matching the token ranges.
  AttributedText _buildSyntaxAttributedText(
    String rawText,
    String language,
  ) {
    if (rawText.isEmpty) return AttributedText();

    final resolvedLang = _resolver.resolveFromFence(
      language.isNotEmpty ? language : null,
    );

    final HighlightResult hlResult;
    if (resolvedLang != null && resolvedLang.isSupported) {
      hlResult = _highlighter.highlight(source: rawText, language: resolvedLang);
    } else {
      hlResult = HighlightResult.plain(source: rawText);
    }

    final decorated = AttributedText(rawText);
    for (final token in hlResult.tokens) {
      if (token.start >= 0 &&
          token.end <= rawText.length &&
          token.start < token.end) {
        decorated.addAttribution(
          NamedAttribution('syntax_${token.type.name}'),
          SpanRange(token.start, token.end - 1),
        );
      }
    }

    return decorated;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final typography = TypographySettings.defaultSettings;
    final syntaxTheme = SyntaxTheme.fromColors(colors, typography: typography);

    final rawSource = widget.viewModel.text.toPlainText();
    final rawLang = widget.viewModel.language.trim();
    final registeredLang = rawLang.isNotEmpty
        ? SyntaxLanguageRegistry.instance.findByIdOrAlias(rawLang)
        : null;
    final displayName = registeredLang?.name ??
        (rawLang.isNotEmpty ? rawLang : 'Plain text');

    final decoratedText = _buildSyntaxAttributedText(rawSource, rawLang);
    final codeFont = typography.codeFontFamily ?? 'monospace';
    final baseCodeStyle = FontFamilyHelper.getTextStyle(
      fontFamily: codeFont,
      baseStyle: TextStyle(
        fontSize: typography.scaledCodeSize,
        height: 1.5,
        color: colors.codeText,
      ),
    );

    TextStyle codeStyleBuilder(Set<Attribution> attributions) {
      var currentStyle = baseCodeStyle;
      for (final attr in attributions) {
        if (attr is NamedAttribution && attr.name.startsWith('syntax_')) {
          final tokenName = attr.name.substring('syntax_'.length);
          try {
            final tokenType = SyntaxTokenType.values.byName(tokenName);
            final tokenStyle = syntaxTheme.styleFor(tokenType);
            currentStyle = currentStyle.merge(tokenStyle);
          } catch (_) {}
        }
      }
      return currentStyle;
    }

    final lineCount = max(1, '\n'.allMatches(rawSource).length + 1);
    final gutterWidth = max(32.0, ('$lineCount'.length * 8.5) + 16.0);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.borderMd,
        border: Border.all(
          color: colors.divider,
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Editorial Header Bar
          Container(
            height: 36.0,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.35),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Language selector pill
                InkWell(
                  onTap: () => _changeLanguage(context),
                  borderRadius: AppRadii.borderSm,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName.toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            color: rawLang.isNotEmpty
                                ? colors.accent
                                : colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.0,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                // 1-tap Copy button
                QuietIconButton(
                  icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                  tooltip: _copied ? 'Copied!' : 'Copy Code',
                  size: 16,
                  isActive: _copied,
                  padding: const EdgeInsets.all(6.0),
                  onPressed: _copyCode,
                ),
              ],
            ),
          ),

          // 2. Hairline separator
          Divider(
            height: 1.0,
            thickness: 0.8,
            color: colors.divider.withValues(alpha: 0.6),
          ),

          // 3. Line Number Gutter + Code Editing Canvas
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtle Line Number Gutter
              _LineNumberGutter(
                text: rawSource,
                textComponentKey: _textKey,
                width: gutterWidth,
                baseStyle: baseCodeStyle.copyWith(
                  color: colors.textTertiary.withValues(alpha: 0.5),
                  fontSize: 11.5,
                ),
                dividerColor: colors.divider.withValues(alpha: 0.4),
              ),

              // Code Body (TextComponent with soft text wrapping)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    right: AppSpacing.md,
                    top: 10.0,
                    bottom: 10.0,
                  ),
                  child: TextComponent(
                    key: _textKey,
                    text: decoratedText,
                    textDirection: widget.viewModel.textDirection,
                    textAlign: widget.viewModel.textAlignment,
                    maxLines: null,
                    overflow: TextOverflow.clip,
                    textStyleBuilder: codeStyleBuilder,
                    inlineWidgetBuilders:
                        widget.viewModel.inlineWidgetBuilders,
                    textSelection: widget.viewModel.selection,
                    selectionColor: widget.viewModel.selectionColor,
                    highlightWhenEmpty: widget.viewModel.highlightWhenEmpty,
                    showDebugPaint: widget.showDebugPaint,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A lightweight gutter widget that paints aligned line numbers based on the
/// [TextLayout] of the sibling [TextComponent].
class _LineNumberGutter extends StatelessWidget {
  const _LineNumberGutter({
    required this.text,
    required this.textComponentKey,
    required this.width,
    required this.baseStyle,
    required this.dividerColor,
  });

  final String text;
  final GlobalKey textComponentKey;
  final double width;
  final TextStyle baseStyle;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: _LineNumberPainter(
          text: text,
          textComponentKey: textComponentKey,
          style: baseStyle,
          dividerColor: dividerColor,
        ),
      ),
    );
  }
}

class _LineNumberPainter extends CustomPainter {
  _LineNumberPainter({
    required this.text,
    required this.textComponentKey,
    required this.style,
    required this.dividerColor,
  });

  final String text;
  final GlobalKey textComponentKey;
  final TextStyle style;
  final Color dividerColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw vertical hairline divider separating gutter from code area
    final dividerPaint = Paint()
      ..color = dividerColor
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(size.width - 0.4, 0),
      Offset(size.width - 0.4, size.height),
      dividerPaint,
    );

    // 2. Identify start offsets of each logical line
    final lineStartOffsets = <int>[0];
    for (int i = 0; i < text.length; i++) {
      if (text[i] == '\n') {
        lineStartOffsets.add(i + 1);
      }
    }

    final docComponent =
        textComponentKey.currentState as DocumentComponent?;

    const topPadding = 10.0;
    final estimatedLineHeight = style.fontSize != null
        ? style.fontSize! * (style.height ?? 1.5)
        : 18.0;

    for (int i = 0; i < lineStartOffsets.length; i++) {
      final pos = lineStartOffsets[i];
      double yOffset;
      if (docComponent != null && pos <= text.length) {
        try {
          final charOffset =
              docComponent.getOffsetForPosition(TextNodePosition(offset: pos));
          yOffset = charOffset.dy + topPadding;
        } catch (_) {
          yOffset = (i * estimatedLineHeight) + topPadding;
        }
      } else {
        yOffset = (i * estimatedLineHeight) + topPadding;
      }

      final textPainter = TextPainter(
        text: TextSpan(text: '${i + 1}', style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - 8.0 - textPainter.width, yOffset),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineNumberPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.dividerColor != dividerColor;
  }
}
