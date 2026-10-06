import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/document_selection.dart';
import '../domain/markdown_styles.dart';
import '../domain/rich_block.dart';
import '../domain/rich_document.dart';
import '../domain/rich_inline.dart';
import '../domain/text_attributes.dart';
import 'frontmatter_editor_helper.dart';
import 'rich_document_mutations.dart';
import 'rich_document_parser.dart';
import 'rich_document_serializer.dart';

/// Controller coordinating the authoritative [RichDocument] editing state in Visual mode.
///
/// Features:
/// - Authoritative in-memory [RichDocument] model.
/// - Direct rich-text mutations (no Markdown string-rewriting or regex reparsing on keystrokes).
/// - Comprehensive editor-level undo/redo snapshot history.
/// - Coherent selection state and typing attribute persistence.
/// - Clean serialization boundary for debounced autosave and mode switching.
class RichDocumentController extends ChangeNotifier {
  RichDocumentController({
    String initialMarkdown = '',
    this.styles,
    this.stripFrontmatter = false,
    this.onDocumentChanged,
  })  : _parser = const RichDocumentParser(),
        _serializer = const RichDocumentSerializer() {
    var bodyMarkdown = initialMarkdown;
    if (stripFrontmatter) {
      final fmDoc = FrontmatterEditorHelper.parse(initialMarkdown);
      if (fmDoc.hasFrontmatter) {
        _frontmatterPrefix = initialMarkdown.substring(0, fmDoc.bodyStartOffset);
        bodyMarkdown = initialMarkdown.substring(fmDoc.bodyStartOffset);
      }
    }
    _document = _parser.parse(bodyMarkdown);
    final firstBlockId = _document.blocks.isNotEmpty ? _document.blocks.first.id : '';
    _selection = RichDocumentSelection.collapsed(
      RichDocumentPosition(blockIndex: 0, blockId: firstBlockId, offset: 0),
    );
    _recordSnapshot();
  }

  final RichDocumentParser _parser;
  final RichDocumentSerializer _serializer;

  /// Whether YAML frontmatter is stripped for visual editing.
  final bool stripFrontmatter;

  String? _frontmatterPrefix;

  /// Optional notification callback invoked whenever the rich document mutates.
  final ValueChanged<RichDocument>? onDocumentChanged;

  MarkdownStyles? styles;

  String? searchQuery;

  late RichDocument _document;
  RichDocument get document => _document;

  late RichDocumentSelection _selection;
  RichDocumentSelection get selection => _selection;

  TextAttributes _typingAttributes = TextAttributes.none;
  TextAttributes get typingAttributes => _typingAttributes;

  // ===========================================================================
  // Undo / Redo Management
  // ===========================================================================

  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];
  static const int _maxUndoStack = 100;

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  void _recordSnapshot() {
    _redoStack.clear();
    if (_undoStack.isNotEmpty && _undoStack.last.document == _document) {
      // Avoid duplicate document snapshots
      return;
    }
    _undoStack.add(_EditorSnapshot(document: _document, selection: _selection));
    if (_undoStack.length > _maxUndoStack) {
      _undoStack.removeAt(0);
    }
  }

  void undo() {
    if (!canUndo) return;
    final current = _undoStack.removeLast();
    _redoStack.add(current);
    final target = _undoStack.last;
    _document = target.document;
    _selection = target.selection;
    notifyListeners();
    onDocumentChanged?.call(_document);
  }

  void redo() {
    if (!canRedo) return;
    final target = _redoStack.removeLast();
    _undoStack.add(target);
    _document = target.document;
    _selection = target.selection;
    notifyListeners();
    onDocumentChanged?.call(_document);
  }

  // ===========================================================================
  // Selection & Position Management
  // ===========================================================================

  void updateSelection(RichDocumentSelection newSelection) {
    if (_selection != newSelection) {
      _selection = newSelection;
      _updateTypingAttributesFromSelection();
      notifyListeners();
    }
  }

  void setSelectionFromGlobalOffset(int globalOffset) {
    final pos = _document.documentPositionAtGlobalOffset(globalOffset);
    updateSelection(RichDocumentSelection.collapsed(pos));
  }

  int get globalCaretOffset =>
      _document.globalOffsetAtDocumentPosition(_selection.extent);

  void _updateTypingAttributesFromSelection() {
    if (_document.blocks.isEmpty) {
      _typingAttributes = TextAttributes.none;
      return;
    }
    final pos = _selection.extent;
    final blockIdx = pos.blockIndex.clamp(0, _document.blocks.length - 1);
    final block = _document.blocks[blockIdx];
    if (!block.isTextBlock || block.spans.isEmpty) {
      _typingAttributes = TextAttributes.none;
      return;
    }

    // Inspect attributes of the span at or immediately preceding the caret
    var currentOffset = 0;
    for (final span in block.spans) {
      final spanEnd = currentOffset + span.length;
      if (pos.offset >= currentOffset && pos.offset <= spanEnd) {
        _typingAttributes = span.attributes;
        return;
      }
      currentOffset = spanEnd;
    }
    _typingAttributes = block.spans.last.attributes;
  }

  // ===========================================================================
  // Document Mutations
  // ===========================================================================

  void _commitMutation(RichDocument newDoc, {RichDocumentSelection? newSelection}) {
    if (_document != newDoc) {
      _document = newDoc;
      if (newSelection != null) {
        _selection = newSelection;
      }
      _recordSnapshot();
      notifyListeners();
      onDocumentChanged?.call(_document);
    }
  }

  /// Sets the entire document from a Markdown source string.
  void setMarkdown(String markdown) {
    var bodyMarkdown = markdown;
    if (stripFrontmatter) {
      final fmDoc = FrontmatterEditorHelper.parse(markdown);
      if (fmDoc.hasFrontmatter) {
        _frontmatterPrefix = markdown.substring(0, fmDoc.bodyStartOffset);
        bodyMarkdown = markdown.substring(fmDoc.bodyStartOffset);
      } else {
        _frontmatterPrefix = null;
      }
    }
    final newDoc = _parser.parse(bodyMarkdown);
    if (_document != newDoc) {
      _document = newDoc;
      final firstId = newDoc.blocks.isNotEmpty ? newDoc.blocks.first.id : '';
      _selection = RichDocumentSelection.collapsed(
        RichDocumentPosition(blockIndex: 0, blockId: firstId, offset: 0),
      );
      _recordSnapshot();
      notifyListeners();
      onDocumentChanged?.call(_document);
    }
  }

  /// Exports the current document to canonical Markdown including any frontmatter.
  String toMarkdown() {
    final body = _serializer.serialize(_document);
    if (stripFrontmatter && _frontmatterPrefix != null) {
      return _frontmatterPrefix! + body;
    }
    return body;
  }

  /// Exports only the visual body content without frontmatter.
  String toBodyMarkdown() => _serializer.serialize(_document);

  // ===========================================================================
  // Inline Formatting Actions
  // ===========================================================================

  void toggleBold() {
    if (_selection.isCollapsed) {
      _typingAttributes = _typingAttributes.copyWith(isBold: !_typingAttributes.isBold);
      notifyListeners();
      return;
    }
    _commitMutation(RichDocumentMutations.toggleBold(_document, _selection));
  }

  void toggleItalic() {
    if (_selection.isCollapsed) {
      _typingAttributes = _typingAttributes.copyWith(isItalic: !_typingAttributes.isItalic);
      notifyListeners();
      return;
    }
    _commitMutation(RichDocumentMutations.toggleItalic(_document, _selection));
  }

  void toggleStrike() {
    if (_selection.isCollapsed) {
      _typingAttributes = _typingAttributes.copyWith(isStrike: !_typingAttributes.isStrike);
      notifyListeners();
      return;
    }
    _commitMutation(RichDocumentMutations.toggleStrike(_document, _selection));
  }

  void toggleHighlight() {
    if (_selection.isCollapsed) {
      _typingAttributes = _typingAttributes.copyWith(isHighlight: !_typingAttributes.isHighlight);
      notifyListeners();
      return;
    }
    _commitMutation(RichDocumentMutations.toggleHighlight(_document, _selection));
  }

  void toggleCode() {
    if (_selection.isCollapsed) {
      _typingAttributes = _typingAttributes.copyWith(isCode: !_typingAttributes.isCode);
      notifyListeners();
      return;
    }
    _commitMutation(RichDocumentMutations.toggleCode(_document, _selection));
  }

  void applyLink({required String url, String? title}) {
    _commitMutation(
      RichDocumentMutations.applyLink(_document, _selection, url: url, title: title),
    );
  }

  void removeLink() {
    _commitMutation(RichDocumentMutations.removeLink(_document, _selection));
  }

  void applyNoteLink({required String target}) {
    _commitMutation(
      RichDocumentMutations.applyNoteLink(_document, _selection, target: target),
    );
  }

  void applyTag({required String tag}) {
    _commitMutation(
      RichDocumentMutations.applyTag(_document, _selection, tag: tag),
    );
  }

  // ===========================================================================
  // Block Structure Actions
  // ===========================================================================

  int get currentBlockIndex =>
      _selection.extent.blockIndex.clamp(0, max(0, _document.blocks.length - 1));

  RichBlock? get currentBlock =>
      _document.blocks.isNotEmpty ? _document.blocks[currentBlockIndex] : null;

  void setHeadingLevel(int level) {
    _commitMutation(RichDocumentMutations.setHeadingLevel(_document, currentBlockIndex, level));
  }

  void convertHeadingToParagraph() {
    _commitMutation(RichDocumentMutations.convertToParagraph(_document, currentBlockIndex));
  }

  void convertBlockToParagraph(int blockIndex) {
    _commitMutation(RichDocumentMutations.convertToParagraph(_document, blockIndex));
  }

  void cycleHeadingLevel() {
    _commitMutation(RichDocumentMutations.cycleHeading(_document, currentBlockIndex));
  }

  void toggleChecklist() {
    _commitMutation(RichDocumentMutations.toggleChecklist(_document, currentBlockIndex));
  }

  void toggleChecklistItemChecked(int blockIndex) {
    _commitMutation(RichDocumentMutations.toggleChecklistItemChecked(_document, blockIndex));
  }

  void toggleBulletedList() {
    _commitMutation(RichDocumentMutations.toggleBulletedList(_document, currentBlockIndex));
  }

  void toggleOrderedList() {
    _commitMutation(RichDocumentMutations.toggleOrderedList(_document, currentBlockIndex));
  }

  void toggleQuote() {
    _commitMutation(RichDocumentMutations.toggleQuote(_document, currentBlockIndex));
  }

  void insertHorizontalRule() {
    _commitMutation(RichDocumentMutations.insertHorizontalRule(_document, currentBlockIndex));
  }

  void insertDivider() => insertHorizontalRule();

  void toggleList() => toggleBulletedList();

  void toggleInlineCode() => toggleCode();

  void insertTable({int rows = 3, int cols = 3}) {
    _commitMutation(
      RichDocumentMutations.insertTable(_document, currentBlockIndex, rows: rows, cols: cols),
    );
  }

  void insertCodeBlock({String language = '', String code = ''}) {
    _commitMutation(
      RichDocumentMutations.insertCodeBlock(
        _document,
        currentBlockIndex,
        language: language,
        code: code,
      ),
    );
  }

  void insertImage({required String path, String alt = ''}) {
    _commitMutation(
      RichDocumentMutations.insertImage(
        _document,
        currentBlockIndex,
        path: path,
        alt: alt,
      ),
    );
  }

  void handleEnter() {
    final (newDoc, newPos) = RichDocumentMutations.handleEnter(_document, _selection.extent);
    _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
  }

  void handleBackspaceAtStart() {
    final (newDoc, newPos) = RichDocumentMutations.handleBackspaceAtStart(_document, _selection.extent);
    _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
  }

  void updateBlockSpans(int blockIndex, List<RichInlineSpan> newSpans) {
    if (blockIndex < 0 || blockIndex >= _document.blocks.length) return;
    final block = _document.blocks[blockIndex];
    if (!block.isTextBlock) return;

    RichBlock updated;
    if (block is ParagraphBlock) {
      updated = block.copyWith(spans: newSpans);
    } else if (block is HeadingBlock) {
      updated = block.copyWith(spans: newSpans);
    } else if (block is ChecklistItemBlock) {
      updated = block.copyWith(spans: newSpans);
    } else if (block is BulletedListItemBlock) {
      updated = block.copyWith(spans: newSpans);
    } else if (block is OrderedListItemBlock) {
      updated = block.copyWith(spans: newSpans);
    } else if (block is QuoteBlock) {
      updated = block.copyWith(spans: newSpans);
    } else {
      return;
    }

    final newBlocks = List<RichBlock>.from(_document.blocks);
    newBlocks[blockIndex] = updated;
    _document = _document.copyWith(blocks: newBlocks);
    notifyListeners();
    onDocumentChanged?.call(_document);
  }

  // ===========================================================================
  // Toolbar State Queries
  // ===========================================================================

  int? get activeHeadingLevel {
    final block = currentBlock;
    if (block is HeadingBlock) return block.level;
    return null;
  }

  bool get isBoldActive => _typingAttributes.isBold;
  bool get isItalicActive => _typingAttributes.isItalic;
  bool get isStrikeActive => _typingAttributes.isStrike;
  bool get isHighlightActive => _typingAttributes.isHighlight;
  bool get isCodeActive => _typingAttributes.isCode;
  bool get isChecklistActive => currentBlock is ChecklistItemBlock;
  bool get isBulletedListActive => currentBlock is BulletedListItemBlock;
  bool get isOrderedListActive => currentBlock is OrderedListItemBlock;
  bool get isQuoteActive => currentBlock is QuoteBlock;
  bool get isCodeBlockActive => currentBlock is CodeBlock;

  String? get activeCodeBlockLanguage {
    final block = currentBlock;
    if (block is CodeBlock) return block.language;
    return null;
  }
}

class _EditorSnapshot {
  final RichDocument document;
  final RichDocumentSelection selection;

  const _EditorSnapshot({
    required this.document,
    required this.selection,
  });
}
