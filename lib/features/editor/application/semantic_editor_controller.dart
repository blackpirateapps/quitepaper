import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/document_position.dart';
import '../domain/markdown_styles.dart';
import '../domain/semantic_document.dart';
import '../domain/semantic_nodes.dart';
import '../domain/source_range.dart';
import 'semantic_markdown_parser.dart';
import 'semantic_mutation_service.dart';

/// Immutable record of active formatting styles for text typed at a collapsed cursor.
@immutable
class ActiveTypingFormats {
  const ActiveTypingFormats({
    this.isBold = false,
    this.isItalic = false,
    this.isStrike = false,
    this.isHighlight = false,
  });

  final bool isBold;
  final bool isItalic;
  final bool isStrike;
  final bool isHighlight;

  ActiveTypingFormats copyWith({
    bool? isBold,
    bool? isItalic,
    bool? isStrike,
    bool? isHighlight,
  }) {
    return ActiveTypingFormats(
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isStrike: isStrike ?? this.isStrike,
      isHighlight: isHighlight ?? this.isHighlight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveTypingFormats &&
          runtimeType == other.runtimeType &&
          isBold == other.isBold &&
          isItalic == other.isItalic &&
          isStrike == other.isStrike &&
          isHighlight == other.isHighlight;

  @override
  int get hashCode => Object.hash(isBold, isItalic, isStrike, isHighlight);

  @override
  String toString() => 'ActiveTypingFormats(b: $isBold, i: $isItalic, s: $isStrike, h: $isHighlight)';
}

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
  ActiveTypingFormats? _activeTypingFormats;
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

  /// Active explicit typing formats for newly inserted characters at a collapsed cursor.
  ActiveTypingFormats? get activeTypingFormats => _activeTypingFormats;

  /// Sets the document selection in semantic coordinates.
  set selection(DocumentSelection newSelection) {
    if (_selection != newSelection) {
      final oldPos = _selection.base;
      _selection = newSelection;
      if (oldPos.blockId != newSelection.base.blockId || oldPos.offset != newSelection.base.offset) {
        _activeTypingFormats = null;
      }
      notifyListeners();
    }
  }

  DocumentSelection _initialSelection() {
    if (_document.blocks.isNotEmpty) {
      final firstBlock = _document.blocks.first;
      final pos = DocumentPosition(blockId: firstBlock.id, offset: 0);
      return DocumentSelection.collapsed(pos);
    }
    const pos = DocumentPosition(blockId: 'block_0', offset: 0);
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
    if (_selection.isCollapsed) {
      final current = isBoldActive;
      _activeTypingFormats = (_activeTypingFormats ?? _currentFormatsAtCursor).copyWith(isBold: !current);
      notifyListeners();
      return;
    }
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleBold(_markdown, _selection));
  }

  void toggleItalic() {
    if (_selection.isCollapsed) {
      final current = isItalicActive;
      _activeTypingFormats = (_activeTypingFormats ?? _currentFormatsAtCursor).copyWith(isItalic: !current);
      notifyListeners();
      return;
    }
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleItalic(_markdown, _selection));
  }

  void toggleStrike() {
    if (_selection.isCollapsed) {
      final current = isStrikeActive;
      _activeTypingFormats = (_activeTypingFormats ?? _currentFormatsAtCursor).copyWith(isStrike: !current);
      notifyListeners();
      return;
    }
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleStrike(_markdown, _selection));
  }

  void toggleHighlight() {
    if (_selection.isCollapsed) {
      final current = isHighlightActive;
      _activeTypingFormats = (_activeTypingFormats ?? _currentFormatsAtCursor).copyWith(isHighlight: !current);
      notifyListeners();
      return;
    }
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleHighlight(_markdown, _selection));
  }

  void toggleInlineCode() {
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleInlineCode(_markdown, _selection));
  }

  void toggleLink({required String url, String? title}) {
    _activeTypingFormats = null;
    applyMutation(SemanticMutationService.toggleLink(_markdown, _selection, url: url, title: title));
  }

  void toggleNoteLink({required String noteTitle}) {
    _activeTypingFormats = null;
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
      final next = block.level < 6 ? block.level + 1 : 0;
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
  // Visual Block Text & Selection Handling
  // ---------------------------------------------------------------------------

  /// Updates selection from a visual block TextField.
  void updateSelectionFromBlock(String blockId, TextSelection blockSelection) {
    final pos = DocumentPosition(blockId: blockId, offset: blockSelection.baseOffset);
    final extent = DocumentPosition(blockId: blockId, offset: blockSelection.extentOffset);
    final docSel = DocumentSelection(base: pos, extent: extent);

    if (_selection != docSel) {
      final oldPos = _selection.base;
      _selection = docSel;
      if (oldPos.blockId != pos.blockId || oldPos.offset != pos.offset) {
        _activeTypingFormats = null;
      }
      notifyListeners();
    }
  }

  /// Handles visual block text edits while keeping Markdown formatting intact.
  void handleVisualBlockTextChange(String blockId, String newText, TextSelection newSelection) {
    final block = _document.findBlockById(blockId);
    if (block == null) return;

    if (block is CodeBlock) {
      final newMarkdown = _markdown.replaceRange(block.codeRange.start, block.codeRange.end, newText);
      markdown = newMarkdown;
      return;
    }

    if (newText.contains('\n') ||
        (block is ParagraphBlock && RegExp(r'^(#{1,6}\s|- \[[ x]\]\s|[-*+]\s|\d+\.\s|>\s)').hasMatch(newText))) {
      final contentStart = (block is HeadingBlock)
          ? block.contentRange.start
          : (block is ListItemBlock)
              ? block.contentRange.start
              : (block is OrderedListItemBlock)
                  ? block.contentRange.start
                  : (block is ChecklistItemBlock)
                      ? block.contentRange.start
                      : (block is QuoteBlock)
                          ? block.contentRange.start
                          : (block is ParagraphBlock)
                              ? (block.contentRange?.start ?? block.sourceRange.start)
                              : block.sourceRange.start;

      final contentEnd = (block is HeadingBlock)
          ? block.contentRange.end
          : (block is ListItemBlock)
              ? block.contentRange.end
              : (block is OrderedListItemBlock)
                  ? block.contentRange.end
                  : (block is ChecklistItemBlock)
                      ? block.contentRange.end
                      : (block is QuoteBlock)
                          ? block.contentRange.end
                          : (block is ParagraphBlock)
                              ? (block.contentRange?.end ?? block.sourceRange.end)
                              : block.sourceRange.end;

      final newMarkdown = _markdown.replaceRange(contentStart, contentEnd, newText);
      final newSourceOffset = contentStart + newSelection.baseOffset;
      updateMarkdownAndRetainSelection(newMarkdown, newSourceOffset);
      return;
    }

    final runs = _getRunsForBlock(block);
    final oldPlainText = block.plainText;

    if (oldPlainText == newText) return;

    // Diff oldPlainText and newText
    var prefixLen = 0;
    final minLen = min(oldPlainText.length, newText.length);
    while (prefixLen < minLen && oldPlainText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    var suffixLen = 0;
    while (suffixLen < (minLen - prefixLen) &&
        oldPlainText[oldPlainText.length - 1 - suffixLen] == newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final editStart = prefixLen;
    final editEnd = oldPlainText.length - suffixLen;
    final insertedText = newText.substring(prefixLen, newText.length - suffixLen);

    // Split runs around editStart and editEnd
    var split = SemanticMutationService.splitRunsAt(runs, editStart);
    split = SemanticMutationService.splitRunsAt(split, editEnd);

    // Determine formatting for insertedText
    final activeFormats = _activeTypingFormats ?? _currentFormatsAtCursor;

    final updatedRuns = <SemanticInline>[];
    var currentOffset = 0;
    var inserted = false;

    for (final r in split) {
      final rLen = r.text.length;
      final rStart = currentOffset;
      final rEnd = currentOffset + rLen;

      if (rEnd <= editStart || rStart >= editEnd) {
        if (!inserted && rStart >= editStart && insertedText.isNotEmpty) {
          updatedRuns.add(_createRun(insertedText, activeFormats));
          inserted = true;
        }
        updatedRuns.add(r);
      } else {
        // Within replaced range -> skip (deleted)
        if (!inserted && insertedText.isNotEmpty) {
          updatedRuns.add(_createRun(insertedText, activeFormats));
          inserted = true;
        }
      }
      currentOffset += rLen;
    }

    if (!inserted && insertedText.isNotEmpty) {
      updatedRuns.add(_createRun(insertedText, activeFormats));
    }

    final merged = SemanticMutationService.mergeAdjacentRuns(updatedRuns);
    final blockMarkdown = SemanticMutationService.serializeBlockMarkdown(block, merged);

    final lineEnd = block.sourceRange.end;
    final hasTrailingNewline = lineEnd <= _markdown.length && lineEnd > 0 && _markdown[lineEnd - 1] == '\n';
    final replacement = hasTrailingNewline ? '$blockMarkdown\n' : blockMarkdown;

    final newMarkdown = _markdown.replaceRange(block.sourceRange.start, block.sourceRange.end, replacement);
    _markdown = newMarkdown;
    _document = SemanticMarkdownParser.parse(newMarkdown, stripFrontmatter: stripFrontmatter);

    final targetOffset = newSelection.baseOffset.clamp(0, newText.length);
    _selection = DocumentSelection.collapsed(DocumentPosition(blockId: blockId, offset: targetOffset));

    notifyListeners();
    onMarkdownChanged?.call(newMarkdown);
  }

  static SemanticInline _createRun(String text, ActiveTypingFormats formats) {
    const emptyRange = SourceRange(0, 0);
    if (!formats.isBold && !formats.isItalic && !formats.isStrike && !formats.isHighlight) {
      return PlainRun(text, emptyRange);
    }
    if (formats.isBold) {
      return BoldRun(
        text,
        emptyRange,
        emptyRange,
        isItalic: formats.isItalic,
        isStrike: formats.isStrike,
        isHighlight: formats.isHighlight,
      );
    }
    if (formats.isItalic) {
      return ItalicRun(
        text,
        emptyRange,
        emptyRange,
        isBold: formats.isBold,
        isStrike: formats.isStrike,
        isHighlight: formats.isHighlight,
      );
    }
    if (formats.isStrike) {
      return StrikeRun(
        text,
        emptyRange,
        emptyRange,
        isBold: formats.isBold,
        isItalic: formats.isItalic,
        isHighlight: formats.isHighlight,
      );
    }
    return HighlightRun(
      text,
      emptyRange,
      emptyRange,
      isBold: formats.isBold,
      isItalic: formats.isItalic,
      isStrike: formats.isStrike,
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar State Inspection Queries
  // ---------------------------------------------------------------------------

  ActiveTypingFormats get _currentFormatsAtCursor {
    final block = activeBlock;
    if (block == null) return const ActiveTypingFormats();

    final runs = _getRunsForBlock(block);
    if (runs.isEmpty) return const ActiveTypingFormats();

    final offset = _selection.base.offset;
    var currentOffset = 0;
    SemanticInline? targetRun;
    for (final r in runs) {
      final rLen = r.text.length;
      if (offset >= currentOffset && offset <= currentOffset + rLen) {
        if (offset > currentOffset || targetRun == null) {
          targetRun = r;
        }
      }
      currentOffset += rLen;
    }
    targetRun ??= runs.last;
    return ActiveTypingFormats(
      isBold: targetRun.isBold,
      isItalic: targetRun.isItalic,
      isStrike: targetRun.isStrike,
      isHighlight: targetRun.isHighlight,
    );
  }

  bool get isBoldActive {
    if (_selection.isCollapsed) {
      if (_activeTypingFormats != null) {
        return _activeTypingFormats!.isBold;
      }
      return _currentFormatsAtCursor.isBold;
    }
    final block = activeBlock;
    if (block == null) return false;
    final runs = _getRunsForBlock(block);
    if (runs.isEmpty) return false;
    final start = min(_selection.base.offset, _selection.extent.offset);
    final end = max(_selection.base.offset, _selection.extent.offset);
    final selectedRuns = _getRunsInRange(runs, start, end);
    return selectedRuns.isNotEmpty && selectedRuns.every((r) => r.isBold);
  }

  bool get isItalicActive {
    if (_selection.isCollapsed) {
      if (_activeTypingFormats != null) {
        return _activeTypingFormats!.isItalic;
      }
      return _currentFormatsAtCursor.isItalic;
    }
    final block = activeBlock;
    if (block == null) return false;
    final runs = _getRunsForBlock(block);
    if (runs.isEmpty) return false;
    final start = min(_selection.base.offset, _selection.extent.offset);
    final end = max(_selection.base.offset, _selection.extent.offset);
    final selectedRuns = _getRunsInRange(runs, start, end);
    return selectedRuns.isNotEmpty && selectedRuns.every((r) => r.isItalic);
  }

  bool get isStrikeActive {
    if (_selection.isCollapsed) {
      if (_activeTypingFormats != null) {
        return _activeTypingFormats!.isStrike;
      }
      return _currentFormatsAtCursor.isStrike;
    }
    final block = activeBlock;
    if (block == null) return false;
    final runs = _getRunsForBlock(block);
    if (runs.isEmpty) return false;
    final start = min(_selection.base.offset, _selection.extent.offset);
    final end = max(_selection.base.offset, _selection.extent.offset);
    final selectedRuns = _getRunsInRange(runs, start, end);
    return selectedRuns.isNotEmpty && selectedRuns.every((r) => r.isStrike);
  }

  bool get isHighlightActive {
    if (_selection.isCollapsed) {
      if (_activeTypingFormats != null) {
        return _activeTypingFormats!.isHighlight;
      }
      return _currentFormatsAtCursor.isHighlight;
    }
    final block = activeBlock;
    if (block == null) return false;
    final runs = _getRunsForBlock(block);
    if (runs.isEmpty) return false;
    final start = min(_selection.base.offset, _selection.extent.offset);
    final end = max(_selection.base.offset, _selection.extent.offset);
    final selectedRuns = _getRunsInRange(runs, start, end);
    return selectedRuns.isNotEmpty && selectedRuns.every((r) => r.isHighlight);
  }

  bool get isCodeActive {
    if (_selection.isCollapsed) {
      final block = activeBlock;
      if (block == null) return false;
      final runs = _getRunsForBlock(block);
      final offset = _selection.base.offset;
      var cur = 0;
      for (final r in runs) {
        if (offset >= cur && offset <= cur + r.text.length) {
          return r.isCode;
        }
        cur += r.text.length;
      }
      return false;
    }
    final block = activeBlock;
    if (block == null) return false;
    final runs = _getRunsForBlock(block);
    final start = min(_selection.base.offset, _selection.extent.offset);
    final end = max(_selection.base.offset, _selection.extent.offset);
    final selectedRuns = _getRunsInRange(runs, start, end);
    return selectedRuns.isNotEmpty && selectedRuns.every((r) => r.isCode);
  }

  static List<SemanticInline> _getRunsForBlock(SemanticBlock block) {
    if (block is ParagraphBlock) return block.runs;
    if (block is HeadingBlock) return block.runs;
    if (block is ListItemBlock) return block.runs;
    if (block is OrderedListItemBlock) return block.runs;
    if (block is ChecklistItemBlock) return block.runs;
    if (block is QuoteBlock) return block.runs;
    return const [];
  }

  static List<SemanticInline> _getRunsInRange(List<SemanticInline> runs, int start, int end) {
    var currentOffset = 0;
    final result = <SemanticInline>[];
    for (final r in runs) {
      final rStart = currentOffset;
      final rEnd = currentOffset + r.text.length;
      if (rEnd > start && rStart < end) {
        result.add(r);
      }
      currentOffset += r.text.length;
    }
    return result;
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
