import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/document_selection.dart';
import '../domain/markdown_styles.dart';
import '../domain/markdown_table.dart';
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
  static const int maxWysiwygCharacters = 200000;
  static const int largeDocumentThresholdCharacters = 35000;
  static const int largeDocumentThresholdLines = 1200;

  static bool isDocumentTooLargeForWysiwyg(String text) {
    if (RichDocument.isJson(text)) {
      try {
        final doc = RichDocument.fromJson(jsonDecode(text) as Map<String, dynamic>);
        return doc.plainText.length > largeDocumentThresholdCharacters;
      } catch (_) {}
    }
    return text.length > largeDocumentThresholdCharacters ||
        '\n'.allMatches(text).length > largeDocumentThresholdLines;
  }

  bool get exceedsWysiwygThreshold => isDocumentTooLargeForWysiwyg(toMarkdown());

  RichDocumentController({
    String initialMarkdown = '',
    this.styles,
    this.stripFrontmatter = false,
    this.onDocumentChanged,
  })  : _parser = const RichDocumentParser(),
        _serializer = const RichDocumentSerializer() {
    if (RichDocument.isJson(initialMarkdown)) {
      try {
        _document = RichDocument.fromJson(jsonDecode(initialMarkdown) as Map<String, dynamic>);
      } catch (_) {
        _document = _parser.parse(initialMarkdown);
      }
    } else {
      var bodyMarkdown = initialMarkdown;
      if (stripFrontmatter) {
        final fmDoc = FrontmatterEditorHelper.parse(initialMarkdown);
        if (fmDoc.hasFrontmatter) {
          _frontmatterPrefix = initialMarkdown.substring(0, fmDoc.bodyStartOffset);
          bodyMarkdown = initialMarkdown.substring(fmDoc.bodyStartOffset);
        }
      }
      _document = _parser.parse(bodyMarkdown);
    }
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
  bool get hasFrontmatter => _frontmatterPrefix != null && _frontmatterPrefix!.isNotEmpty;

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

  bool _isDirty = false;
  bool get isDirty => _isDirty;
  void markClean() {
    _isDirty = false;
  }

  /// Notifies the controller and observers that content has been mutated in memory
  /// without triggering immediate Markdown serialization.
  void notifyContentMutated() {
    _isDirty = true;
    onDocumentChanged?.call(_document);
  }

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
      _isDirty = true;
      if (newSelection != null) {
        _selection = newSelection;
      }
      _recordSnapshot();
      notifyListeners();
      onDocumentChanged?.call(_document);
    }
  }

  /// Sets the authoritative document directly in-memory from a [RichDocument] model
  /// without parsing or string serialization.
  void setDocument(RichDocument newDoc, {RichDocumentSelection? newSelection}) {
    _commitMutation(newDoc, newSelection: newSelection);
  }

  /// Sets the entire document from a Markdown source string or RichDocument JSON.
  void setContent(String content) {
    if (RichDocument.isJson(content)) {
      try {
        final newDoc = RichDocument.fromJson(jsonDecode(content) as Map<String, dynamic>);
        setDocument(newDoc);
        return;
      } catch (_) {}
    }
    setMarkdown(content);
  }

  /// Sets the entire document from a Markdown source string.
  void setMarkdown(String markdown) {
    if (RichDocument.isJson(markdown)) {
      setContent(markdown);
      return;
    }
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

  /// Exports the current document to canonical RichDocument JSON format.
  String toJsonString() => jsonEncode(_document.toJson());

  /// Returns user plain text across all blocks.
  String toPlainText() => _document.plainText;

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
    final newDoc = RichDocumentMutations.applyLink(_document, _selection, url: url, title: title);
    if (_selection.isCollapsed) {
      final label = (title != null && title.isNotEmpty) ? title : url;
      final newPos = RichDocumentPosition(
        blockIndex: _selection.extent.blockIndex,
        blockId: _selection.extent.blockId,
        offset: _selection.extent.offset + label.length,
      );
      _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
    } else {
      _commitMutation(newDoc);
    }
  }

  void removeLink() {
    _commitMutation(RichDocumentMutations.removeLink(_document, _selection));
  }

  void applyNoteLink({required String target}) {
    final newDoc = RichDocumentMutations.applyNoteLink(_document, _selection, target: target);
    if (_selection.isCollapsed) {
      final newPos = RichDocumentPosition(
        blockIndex: _selection.extent.blockIndex,
        blockId: _selection.extent.blockId,
        offset: _selection.extent.offset + target.length,
      );
      _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
    } else {
      _commitMutation(newDoc);
    }
  }

  void applyTag({required String tag}) {
    final newDoc = RichDocumentMutations.applyTag(_document, _selection, tag: tag);
    if (_selection.isCollapsed) {
      final normalized = tag.startsWith('#') ? tag.substring(1) : tag;
      final newPos = RichDocumentPosition(
        blockIndex: _selection.extent.blockIndex,
        blockId: _selection.extent.blockId,
        offset: _selection.extent.offset + normalized.length + 1,
      );
      _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
    } else {
      _commitMutation(newDoc);
    }
  }

  // ===========================================================================
  // Block Structure Actions
  // ===========================================================================

  int get currentBlockIndex =>
      _selection.extent.blockIndex.clamp(0, max(0, _document.blocks.length - 1));

  RichBlock? get currentBlock =>
      _document.blocks.isNotEmpty ? _document.blocks[currentBlockIndex] : null;

  void setHeadingLevel(int level) {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.setHeadingLevel(doc, i, level);
    }
    _commitMutation(doc);
  }

  void convertHeadingToParagraph() {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.convertToParagraph(doc, i);
    }
    _commitMutation(doc);
  }

  void convertBlockToParagraph(int blockIndex) {
    _commitMutation(RichDocumentMutations.convertToParagraph(_document, blockIndex));
  }

  /// Replaces the table at [blockIndex] with [newTable] in place (inline table
  /// editing). The block id is preserved so the surface does not rebuild it.
  void updateTable(int blockIndex, MarkdownTable newTable) {
    _commitMutation(RichDocumentMutations.updateTable(_document, blockIndex, newTable));
  }

  void cycleHeadingLevel() {
    _commitMutation(RichDocumentMutations.cycleHeading(_document, currentBlockIndex));
  }

  void toggleChecklist() {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.toggleChecklist(doc, i);
    }
    _commitMutation(doc);
  }

  void toggleChecklistItemChecked(int blockIndex) {
    _commitMutation(RichDocumentMutations.toggleChecklistItemChecked(_document, blockIndex));
  }

  void toggleBulletedList() {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.toggleBulletedList(doc, i);
    }
    _commitMutation(doc);
  }

  void toggleOrderedList() {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.toggleOrderedList(doc, i);
    }
    _commitMutation(doc);
  }

  void toggleQuote() {
    final start = min(_selection.base.blockIndex, _selection.extent.blockIndex);
    final end = max(_selection.base.blockIndex, _selection.extent.blockIndex);
    var doc = _document;
    for (var i = start; i <= end; i++) {
      doc = RichDocumentMutations.toggleQuote(doc, i);
    }
    _commitMutation(doc);
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

  void handleEnterAt(RichDocumentPosition position) {
    final (newDoc, newPos) = RichDocumentMutations.handleEnter(_document, position);
    _typingAttributes = TextAttributes.none;
    _commitMutation(newDoc, newSelection: RichDocumentSelection.collapsed(newPos));
  }

  void handleEnter() {
    handleEnterAt(_selection.extent);
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
    _isDirty = true;
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

  bool _isAttributeActiveInSelection(bool Function(TextAttributes) test) {
    if (_selection.isCollapsed) {
      return test(_typingAttributes);
    }
    final startPos = _selection.start;
    final endPos = _selection.end;

    for (var bi = startPos.blockIndex; bi <= endPos.blockIndex && bi < _document.blocks.length; bi++) {
      final block = _document.blocks[bi];
      if (!block.isTextBlock) continue;
      final startOffset = (bi == startPos.blockIndex) ? startPos.offset : 0;
      final endOffset = (bi == endPos.blockIndex) ? endPos.offset : block.plainText.length;

      var running = 0;
      for (final span in block.spans) {
        final spanEnd = running + span.length;
        if (spanEnd > startOffset && running < endOffset) {
          if (test(span.attributes)) return true;
        }
        running = spanEnd;
      }
    }
    return false;
  }

  bool get isBoldActive => _isAttributeActiveInSelection((a) => a.isBold);
  bool get isItalicActive => _isAttributeActiveInSelection((a) => a.isItalic);
  bool get isStrikeActive => _isAttributeActiveInSelection((a) => a.isStrike);
  bool get isHighlightActive => _isAttributeActiveInSelection((a) => a.isHighlight);
  bool get isCodeActive => _isAttributeActiveInSelection((a) => a.isCode);
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
