import 'package:flutter/foundation.dart';
import '../domain/document_position.dart';
import '../domain/markdown_styles.dart';
import '../domain/semantic_document.dart';
import '../domain/semantic_nodes.dart';
import 'semantic_markdown_parser.dart';
import 'semantic_mutation_service.dart';

/// Coordinator for an active visual document editing session.
/// Keeps canonical Markdown synchronized with ephemeral [SemanticDocument] representations.
class SemanticEditorController extends ChangeNotifier {
  SemanticEditorController({
    required String initialMarkdown,
    this.styles,
    this.stripFrontmatter = false,
    this.onMarkdownChanged,
  }) {
    _markdown = initialMarkdown;
    _document = SemanticMarkdownParser.parse(initialMarkdown, stripFrontmatter: stripFrontmatter);
    _selection = _initialSelection();
  }

  String _markdown = '';
  late SemanticDocument _document;
  late DocumentSelection _selection;
  final bool stripFrontmatter;
  final ValueChanged<String>? onMarkdownChanged;

  MarkdownStyles? styles;
  String? searchQuery;

  /// The current canonical Markdown source string.
  String get markdown => _markdown;

  /// The parsed ephemeral [SemanticDocument].
  SemanticDocument get document => _document;

  /// The active document selection in semantic coordinates.
  DocumentSelection get selection => _selection;

  /// Sets the document selection in semantic coordinates.
  set selection(DocumentSelection newSelection) {
    if (_selection != newSelection) {
      _selection = newSelection;
      notifyListeners();
    }
  }

  DocumentSelection _initialSelection() {
    if (_document.blocks.isNotEmpty) {
      final firstBlock = _document.blocks.first;
      final pos = DocumentPosition(blockId: firstBlock.id, offset: 0);
      return DocumentSelection.collapsed(pos);
    }
    const pos = DocumentPosition(blockId: 'block_0_p', offset: 0);
    return const DocumentSelection.collapsed(pos);
  }

  /// Sets the canonical Markdown text directly.
  set markdown(String newMarkdown) {
    if (_markdown != newMarkdown) {
      _markdown = newMarkdown;
      _document = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
      notifyListeners();
      onMarkdownChanged?.call(newMarkdown);
    }
  }

  /// Applies a [MutationResult] from [SemanticMutationService].
  void applyMutation(MutationResult result) {
    _markdown = result.markdown;
    _document = result.document;
    if (result.selection != null) {
      _selection = result.selection!;
    } else {
      _selection = DocumentSelection.collapsed(result.position);
    }
    notifyListeners();
    onMarkdownChanged?.call(_markdown);
  }

  void updateMarkdownAndRetainSelection(String newMarkdown, int sourceOffset) {
    _markdown = newMarkdown;
    _document = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);
    final newPos = _document.findPositionAtSourceOffset(sourceOffset);
    if (newPos != null) {
      _selection = DocumentSelection.collapsed(newPos);
    }
    notifyListeners();
    onMarkdownChanged?.call(_markdown);
  }

  void splitBlock(String blockId, int offset) {
    final position = DocumentPosition(blockId: blockId, offset: offset);
    applyMutation(SemanticMutationService.splitBlock(_markdown, position));
  }

  void mergeWithPreviousBlock(String blockId) {
    final position = DocumentPosition(blockId: blockId, offset: 0);
    applyMutation(SemanticMutationService.mergeWithPreviousBlock(_markdown, position));
  }

  /// Active block at the current selection.
  SemanticBlock? get activeBlock {
    return _document.findBlockById(_selection.base.blockId);
  }

  // ---------------------------------------------------------------------------
  // Formatting and Command Actions
  // ---------------------------------------------------------------------------

  void toggleBold() {
    applyMutation(SemanticMutationService.toggleBold(_markdown, _selection));
  }

  void toggleItalic() {
    applyMutation(SemanticMutationService.toggleItalic(_markdown, _selection));
  }

  void toggleStrike() {
    applyMutation(SemanticMutationService.toggleStrike(_markdown, _selection));
  }

  void toggleHighlight() {
    applyMutation(SemanticMutationService.toggleHighlight(_markdown, _selection));
  }

  void toggleInlineCode() {
    applyMutation(SemanticMutationService.toggleInlineCode(_markdown, _selection));
  }

  void toggleLink({required String url, String? title}) {
    applyMutation(SemanticMutationService.toggleLink(_markdown, _selection, url: url, title: title));
  }

  void toggleNoteLink({required String noteTitle}) {
    applyMutation(SemanticMutationService.toggleNoteLink(_markdown, _selection, noteTitle: noteTitle));
  }

  void setHeadingLevel(int level) {
    applyMutation(SemanticMutationService.setHeadingLevel(_markdown, _selection.base, level));
  }

  void setHeadingLevelForBlock(String blockId, int level) {
    applyMutation(SemanticMutationService.setHeadingLevelByBlockId(_markdown, blockId, level));
  }

  void cycleHeadingLevel({String? blockId}) {
    final targetId = blockId ?? _selection.base.blockId;
    final block = _document.findBlockById(targetId);
    if (block is HeadingBlock) {
      final next = block.level < 3 ? block.level + 1 : 1;
      setHeadingLevelForBlock(targetId, next);
    } else {
      setHeadingLevelForBlock(targetId, 1);
    }
  }

  void convertHeadingToParagraph({String? blockId}) {
    final targetId = blockId ?? _selection.base.blockId;
    setHeadingLevelForBlock(targetId, 0);
  }

  void toggleList() {
    applyMutation(SemanticMutationService.toggleList(_markdown, _selection.base));
  }

  void toggleOrderedList() {
    applyMutation(SemanticMutationService.toggleOrderedList(_markdown, _selection.base));
  }

  void toggleChecklist() {
    applyMutation(SemanticMutationService.toggleChecklist(_markdown, _selection.base));
  }

  void toggleChecklistState(String blockId, {bool? targetState}) {
    applyMutation(SemanticMutationService.toggleChecklistState(_markdown, blockId, targetState: targetState));
  }

  void toggleQuote() {
    applyMutation(SemanticMutationService.toggleQuote(_markdown, _selection.base));
  }

  void insertCodeBlock({String? language}) {
    applyMutation(SemanticMutationService.createCodeBlock(_markdown, _selection.base, language: language));
  }

  void changeCodeBlockLanguage(String blockId, String? language) {
    applyMutation(SemanticMutationService.changeCodeBlockLanguage(_markdown, blockId, language));
  }

  void insertImage({required String alt, required String url}) {
    applyMutation(SemanticMutationService.insertImage(_markdown, _selection.base, alt: alt, url: url));
  }

  void insertHorizontalRule() {
    applyMutation(SemanticMutationService.insertHorizontalRule(_markdown, _selection.base));
  }

  void deleteBlock(String blockId) {
    applyMutation(SemanticMutationService.deleteBlock(_markdown, blockId));
  }

  // ---------------------------------------------------------------------------
  // Toolbar State Inspection Queries
  // ---------------------------------------------------------------------------

  bool get isBoldActive {
    final range = _document.sourceRangeAtSelection(_selection);
    final slice = range.slice(_markdown);
    return slice.startsWith('**') || slice.startsWith('__');
  }

  bool get isItalicActive {
    final range = _document.sourceRangeAtSelection(_selection);
    final slice = range.slice(_markdown);
    return (slice.startsWith('*') && !slice.startsWith('**')) ||
        (slice.startsWith('_') && !slice.startsWith('__'));
  }

  bool get isStrikeActive {
    final range = _document.sourceRangeAtSelection(_selection);
    final slice = range.slice(_markdown);
    return slice.startsWith('~~');
  }

  bool get isCodeActive {
    final range = _document.sourceRangeAtSelection(_selection);
    final slice = range.slice(_markdown);
    return slice.startsWith('`') && !slice.startsWith('```');
  }

  int? get activeHeadingLevel {
    final block = activeBlock;
    if (block is HeadingBlock) return block.level;
    return null;
  }

  bool get isListActive => activeBlock is ListItemBlock;
  bool get isOrderedListActive => activeBlock is OrderedListItemBlock;
  bool get isChecklistActive => activeBlock is ChecklistItemBlock;
  bool get isQuoteActive => activeBlock is QuoteBlock;
  bool get isCodeBlockActive => activeBlock is CodeBlock;

  String? get activeCodeBlockLanguage {
    final block = activeBlock;
    if (block is CodeBlock) return block.language;
    return null;
  }
}
