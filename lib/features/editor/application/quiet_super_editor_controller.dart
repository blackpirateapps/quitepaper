import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

import '../../../core/utils/web_url_helper.dart';
import '../presentation/widgets/super_editor/quiet_attachment_component.dart';
import '../presentation/widgets/super_editor/quiet_image_component.dart';
import '../presentation/widgets/super_editor/quiet_link_preview_component.dart';

/// Controller coordinating the [SuperEditor] editing state and bridging Quiet Paper's
/// formatting toolbar, keyboard shortcuts, and document actions.
///
/// Features:
/// - Inline styling toggles (bold, italic, strikethrough, inline code).
/// - Block-level conversions (headings H1-H6, checklists, bullet lists, ordered lists, blockquotes).
/// - Insertion of horizontal rules, links, and arbitrary snippets.
/// - Document undo / redo integration.
/// - Active formatting inspection for toolbar button states and badges.
class QuietSuperEditorController extends ChangeNotifier {
  Editor? _editor;
  MutableDocumentComposer? _composer;

  /// Whether an [Editor] is currently attached.
  bool get isAttached => _editor != null && _composer != null;

  /// The underlying [Editor], exposed for testing and low-level commands.
  @visibleForTesting
  Editor? get editor => _editor;

  /// The underlying [MutableDocumentComposer], exposed for testing and low-level selection control.
  @visibleForTesting
  MutableDocumentComposer? get composer => _composer;

  /// Attaches this controller to an active [Editor] and [MutableDocumentComposer].
  void attach(Editor editor, MutableDocumentComposer composer) {
    if (_editor == editor && _composer == composer) return;
    detach();
    _editor = editor;
    _composer = composer;

    _editor!.document.addListener(_onDocumentChanged);
    _composer!.selectionNotifier.addListener(_onSelectionChanged);
    _composer!.preferences.addListener(_onPreferencesChanged);
    notifyListeners();
  }

  bool _isDisposed = false;

  /// Detaches the controller and cleans up listeners.
  void detach() {
    _editor?.document.removeListener(_onDocumentChanged);
    _composer?.selectionNotifier.removeListener(_onSelectionChanged);
    _composer?.preferences.removeListener(_onPreferencesChanged);
    _editor = null;
    _composer = null;
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _onDocumentChanged(DocumentChangeLog changeLog) {
    if (!_isDisposed) notifyListeners();
  }

  void _onSelectionChanged() {
    if (!_isDisposed) notifyListeners();
  }

  void _onPreferencesChanged() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    detach();
    super.dispose();
  }

  // ===========================================================================
  // History & Undo / Redo
  // ===========================================================================

  /// Whether an undo action is available.
  bool get canUndo => _editor?.history.isNotEmpty ?? false;

  /// Whether a redo action is available.
  bool get canRedo => _editor?.future.isNotEmpty ?? false;

  /// Reverts the most recent transaction in editor history.
  void undo() {
    _editor?.undo();
    notifyListeners();
  }

  /// Replays the most recently undone transaction.
  void redo() {
    _editor?.redo();
    notifyListeners();
  }

  // ===========================================================================
  // Inline Attributions (Bold, Italic, Strikethrough, Code)
  // ===========================================================================

  bool _isAttributionActive(Attribution attribution) {
    if (_composer == null || _editor == null) return false;
    final sel = _composer!.selection;
    if (sel == null) return false;

    if (sel.isCollapsed) {
      if (_composer!.preferences.currentAttributions.contains(attribution)) {
        return true;
      }
      final node = _editor!.document.getNodeById(sel.extent.nodeId);
      if (node is TextNode && sel.extent.nodePosition is TextNodePosition) {
        final offset = (sel.extent.nodePosition as TextNodePosition).offset;
        if (offset > 0 && offset <= node.text.length) {
          return node.text.hasAttributionAt(offset - 1, attribution: attribution);
        }
      }
      return false;
    } else {
      final range = sel.normalize(_editor!.document);
      final nodes = _editor!.document.getNodesInside(range.start, range.end);
      for (final node in nodes) {
        if (node is TextNode) {
          final startOffset =
              (node.id == range.start.nodeId && range.start.nodePosition is TextNodePosition)
                  ? (range.start.nodePosition as TextNodePosition).offset
                  : 0;
          final endOffset =
              (node.id == range.end.nodeId && range.end.nodePosition is TextNodePosition)
                  ? (range.end.nodePosition as TextNodePosition).offset
                  : node.text.length;
          if (endOffset > startOffset) {
            final spans = node.text.getAttributionSpansInRange(
              attributionFilter: (a) => a == attribution,
              range: SpanRange(startOffset, endOffset - 1),
            );
            if (spans.isNotEmpty) return true;
          }
        }
      }
      return false;
    }
  }

  void _toggleAttribution(Attribution attribution) {
    if (_composer == null || _editor == null) return;
    final sel = _composer!.selection;
    if (sel != null && !sel.isCollapsed) {
      final range = _trimRangeWhitespace(_editor!.document, sel);
      if (range == null) return;
      _editor!.execute([
        ToggleTextAttributionsRequest(
          documentRange: range,
          attributions: {attribution},
        ),
      ]);
    } else {
      _composer!.preferences.toggleStyle(attribution);
      notifyListeners();
    }
  }

  /// Trims leading and trailing whitespace from [sel] so inline attributions
  /// do not flank or enclose whitespace, which violates CommonMark flanking rules
  /// and breaks Markdown serialization/deserialization.
  DocumentRange? _trimRangeWhitespace(Document doc, DocumentSelection sel) {
    final normalized = sel.normalize(doc);
    final startNode = doc.getNodeById(normalized.start.nodeId);
    final endNode = doc.getNodeById(normalized.end.nodeId);

    if (startNode is! TextNode || endNode is! TextNode) {
      return normalized;
    }

    if (normalized.start.nodePosition is! TextNodePosition ||
        normalized.end.nodePosition is! TextNodePosition) {
      return normalized;
    }

    var startOffset = (normalized.start.nodePosition as TextNodePosition).offset;
    var endOffset = (normalized.end.nodePosition as TextNodePosition).offset;

    if (startNode.id == endNode.id) {
      final text = startNode.text.toPlainText();
      if (startOffset >= endOffset) return null;

      // Advance startOffset past leading whitespace
      while (startOffset < endOffset && text[startOffset].trim().isEmpty) {
        startOffset++;
      }
      // Retreat endOffset before trailing whitespace
      while (endOffset > startOffset && text[endOffset - 1].trim().isEmpty) {
        endOffset--;
      }

      if (startOffset >= endOffset) return null;

      return DocumentRange(
        start: DocumentPosition(
          nodeId: startNode.id,
          nodePosition: TextNodePosition(offset: startOffset),
        ),
        end: DocumentPosition(
          nodeId: endNode.id,
          nodePosition: TextNodePosition(offset: endOffset),
        ),
      );
    }

    // Cross-node selection: trim outer boundaries
    final startText = startNode.text.toPlainText();
    while (startOffset < startText.length && startText[startOffset].trim().isEmpty) {
      startOffset++;
    }

    final endText = endNode.text.toPlainText();
    while (endOffset > 0 && endText[endOffset - 1].trim().isEmpty) {
      endOffset--;
    }

    return DocumentRange(
      start: DocumentPosition(
        nodeId: startNode.id,
        nodePosition: TextNodePosition(offset: startOffset),
      ),
      end: DocumentPosition(
        nodeId: endNode.id,
        nodePosition: TextNodePosition(offset: endOffset),
      ),
    );
  }

  /// Whether bold styling is currently active.
  bool get isBoldActive => _isAttributionActive(boldAttribution);

  /// Toggles bold styling at the current caret or selection.
  void toggleBold() => _toggleAttribution(boldAttribution);

  /// Whether italic styling is currently active.
  bool get isItalicActive => _isAttributionActive(italicsAttribution);

  /// Toggles italic styling at the current caret or selection.
  void toggleItalic() => _toggleAttribution(italicsAttribution);

  /// Whether strikethrough styling is currently active.
  bool get isStrikeActive => _isAttributionActive(strikethroughAttribution);

  /// Toggles strikethrough styling at the current caret or selection.
  void toggleStrike() => _toggleAttribution(strikethroughAttribution);

  /// Whether inline code styling is currently active.
  bool get isCodeActive => _isAttributionActive(codeAttribution);

  /// Toggles inline code styling at the current caret or selection.
  void toggleCode() => _toggleAttribution(codeAttribution);

  /// Whether text highlight styling is currently active.
  bool get isHighlightActive => false;

  /// Toggles text highlight styling (unsupported by standard SuperEditor Markdown).
  void toggleHighlight() {}

  // ===========================================================================
  // Headings & Block Types
  // ===========================================================================

  /// Returns the current active heading level (1..6) or null if not a heading.
  int? get activeHeadingLevel {
    if (_composer?.selection == null || _editor == null) return null;
    final node = _editor!.document.getNodeById(_composer!.selection!.extent.nodeId);
    if (node is ParagraphNode) {
      final blockType = node.getMetadataValue('blockType');
      if (blockType == header1Attribution) return 1;
      if (blockType == header2Attribution) return 2;
      if (blockType == header3Attribution) return 3;
      if (blockType == header4Attribution) return 4;
      if (blockType == header5Attribution) return 5;
      if (blockType == header6Attribution) return 6;
    }
    return null;
  }

  /// Whether the current block is any heading level.
  bool get isHeadingActive => activeHeadingLevel != null;

  /// Sets the heading level for the currently selected node (1..6), or 0 for normal paragraph.
  void setHeadingLevel(int level) {
    if (_composer?.selection == null || _editor == null) return;
    final nodeId = _composer!.selection!.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);
    final targetAttribution = switch (level) {
      1 => header1Attribution,
      2 => header2Attribution,
      3 => header3Attribution,
      4 => header4Attribution,
      5 => header5Attribution,
      6 => header6Attribution,
      _ => null,
    };

    if (node is ParagraphNode) {
      _editor!.execute([
        ChangeParagraphBlockTypeRequest(
          nodeId: nodeId,
          blockType: targetAttribution,
        ),
      ]);
    } else if (node is ListItemNode) {
      _editor!.execute([
        ConvertListItemToParagraphRequest(
          nodeId: nodeId,
          paragraphMetadata: targetAttribution != null ? {'blockType': targetAttribution} : null,
        ),
      ]);
    } else if (node is TaskNode) {
      _editor!.execute([
        ConvertTaskToParagraphRequest(
          nodeId: nodeId,
          paragraphMetadata: targetAttribution != null ? {'blockType': targetAttribution} : null,
        ),
      ]);
    }
  }

  /// Converts the current node to a standard paragraph.
  void convertHeadingToParagraph() => setHeadingLevel(0);

  /// Cycles heading level: 0 -> 1 -> 2 -> 3 -> 0.
  void cycleHeadingLevel() {
    final current = activeHeadingLevel ?? 0;
    final next = (current >= 3) ? 0 : (current == 0 ? 1 : current + 1);
    if (next == 0) {
      convertHeadingToParagraph();
    } else {
      setHeadingLevel(next);
    }
  }

  // ===========================================================================
  // Lists & Tasks
  // ===========================================================================

  /// Whether the current block is a checklist task item.
  bool get isChecklistActive {
    if (_composer?.selection == null || _editor == null) return false;
    final node = _editor!.document.getNodeById(_composer!.selection!.extent.nodeId);
    return node is TaskNode;
  }

  /// Toggles the current block between a task item and a normal paragraph.
  void toggleChecklist() {
    if (_composer?.selection == null || _editor == null) return;
    final nodeId = _composer!.selection!.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);

    if (node is TaskNode) {
      _editor!.execute([
        ConvertTaskToParagraphRequest(nodeId: nodeId),
      ]);
    } else if (node is ParagraphNode) {
      _editor!.execute([
        ConvertParagraphToTaskRequest(nodeId: nodeId),
      ]);
    } else if (node is ListItemNode) {
      _editor!.execute([
        ConvertListItemToParagraphRequest(nodeId: nodeId),
        ConvertParagraphToTaskRequest(nodeId: nodeId),
      ]);
    }
  }

  /// Whether the current block is an unordered bullet list item.
  bool get isBulletedListActive {
    if (_composer?.selection == null || _editor == null) return false;
    final node = _editor!.document.getNodeById(_composer!.selection!.extent.nodeId);
    return node is ListItemNode && node.type == ListItemType.unordered;
  }

  /// Toggles the current block between an unordered bullet list item and a paragraph.
  void toggleBulletedList() {
    if (_composer?.selection == null || _editor == null) return;
    final nodeId = _composer!.selection!.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);

    if (node is ListItemNode) {
      if (node.type == ListItemType.unordered) {
        _editor!.execute([
          ConvertListItemToParagraphRequest(nodeId: nodeId),
        ]);
      } else {
        _editor!.execute([
          ChangeListItemTypeRequest(nodeId: nodeId, newType: ListItemType.unordered),
        ]);
      }
    } else if (node is ParagraphNode) {
      _editor!.execute([
        ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.unordered),
      ]);
    } else if (node is TaskNode) {
      _editor!.execute([
        ConvertTaskToParagraphRequest(nodeId: nodeId),
        ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.unordered),
      ]);
    }
  }

  /// Whether the current block is an ordered numbered list item.
  bool get isOrderedListActive {
    if (_composer?.selection == null || _editor == null) return false;
    final node = _editor!.document.getNodeById(_composer!.selection!.extent.nodeId);
    return node is ListItemNode && node.type == ListItemType.ordered;
  }

  /// Toggles the current block between an ordered numbered list item and a paragraph.
  void toggleOrderedList() {
    if (_composer?.selection == null || _editor == null) return;
    final nodeId = _composer!.selection!.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);

    if (node is ListItemNode) {
      if (node.type == ListItemType.ordered) {
        _editor!.execute([
          ConvertListItemToParagraphRequest(nodeId: nodeId),
        ]);
      } else {
        _editor!.execute([
          ChangeListItemTypeRequest(nodeId: nodeId, newType: ListItemType.ordered),
        ]);
      }
    } else if (node is ParagraphNode) {
      _editor!.execute([
        ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.ordered),
      ]);
    } else if (node is TaskNode) {
      _editor!.execute([
        ConvertTaskToParagraphRequest(nodeId: nodeId),
        ConvertParagraphToListItemRequest(nodeId: nodeId, type: ListItemType.ordered),
      ]);
    }
  }

  /// Whether the current block is a blockquote.
  bool get isQuoteActive {
    if (_composer?.selection == null || _editor == null) return false;
    final node = _editor!.document.getNodeById(_composer!.selection!.extent.nodeId);
    return node is ParagraphNode && node.getMetadataValue('blockType') == blockquoteAttribution;
  }

  /// Toggles the current block between a blockquote and a paragraph.
  void toggleQuote() {
    if (_composer?.selection == null || _editor == null) return;
    final nodeId = _composer!.selection!.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);

    if (node is ParagraphNode) {
      final isQuote = node.getMetadataValue('blockType') == blockquoteAttribution;
      _editor!.execute([
        ChangeParagraphBlockTypeRequest(
          nodeId: nodeId,
          blockType: isQuote ? null : blockquoteAttribution,
        ),
      ]);
    } else if (node is ListItemNode) {
      _editor!.execute([
        ConvertListItemToParagraphRequest(
          nodeId: nodeId,
          paragraphMetadata: {'blockType': blockquoteAttribution},
        ),
      ]);
    } else if (node is TaskNode) {
      _editor!.execute([
        ConvertTaskToParagraphRequest(
          nodeId: nodeId,
          paragraphMetadata: {'blockType': blockquoteAttribution},
        ),
      ]);
    }
  }

  // ===========================================================================
  // Code Block & Inserts
  // ===========================================================================

  /// Converts the current paragraph to a code block or vice versa.
  void insertCodeBlock() {
    if (_editor == null || _composer == null) return;
    final sel = _composer!.selection;
    if (sel == null) return;
    final nodeId = sel.extent.nodeId;
    final node = _editor!.document.getNodeById(nodeId);

    if (node is ParagraphNode) {
      final isCode = node.getMetadataValue('blockType') == codeAttribution;
      _editor!.execute([
        ChangeParagraphBlockTypeRequest(
          nodeId: nodeId,
          blockType: isCode ? null : codeAttribution,
        ),
      ]);
    }
  }

  /// Inserts a horizontal rule (divider) after the current node.
  void insertHorizontalRule() {
    if (_editor == null || _composer == null) return;
    final sel = _composer!.selection;
    if (sel == null) return;

    final currentNodeId = sel.extent.nodeId;
    final hrId = Editor.createNodeId();
    final newParaId = Editor.createNodeId();

    _editor!.execute([
      InsertNodeAfterNodeRequest(
        existingNodeId: currentNodeId,
        newNode: HorizontalRuleNode(id: hrId),
      ),
      InsertNodeAfterNodeRequest(
        existingNodeId: hrId,
        newNode: ParagraphNode(id: newParaId, text: AttributedText()),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: newParaId,
            nodePosition: const TextNodePosition(offset: 0),
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  /// Applies or inserts a link with the given [url] and optional [title].
  void applyLink({required String url, String? title}) {
    if (_editor == null || _composer == null) return;
    final sel = _composer!.selection;
    final linkUri = Uri.tryParse(url) ?? Uri();
    final linkAttr = LinkAttribution.fromUri(linkUri);

    if (sel != null && !sel.isCollapsed) {
      _editor!.execute([
        AddTextAttributionsRequest(
          documentRange: sel,
          attributions: {linkAttr},
        ),
      ]);
    } else {
      final displayText = (title != null && title.isNotEmpty) ? title : url;
      insertLinkRun(url: url, displayText: displayText);
    }
  }

  /// Whether the current selection is a non-collapsed (expanded) range.
  bool get hasExpandedSelection {
    final sel = _composer?.selection;
    return sel != null && !sel.isCollapsed;
  }

  /// Inserts [displayText] carrying a [url] [LinkAttribution] at the collapsed
  /// caret (or the document end when there is no selection). Used by the
  /// dialog's collapsed-insert path and by the smart-paste auto-link flow so a
  /// real link run is created rather than literal `[text](url)` characters.
  void insertLinkRun({required String url, required String displayText}) {
    if (_editor == null || _composer == null) return;
    if (_composer!.selection == null && _editor!.document.isNotEmpty) {
      final lastNode = _editor!.document.last;
      if (lastNode is TextNode) {
        _composer!.setSelectionWithReason(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: lastNode.id,
              nodePosition: TextNodePosition(offset: lastNode.text.length),
            ),
          ),
        );
      }
    }
    if (_composer!.selection == null) return;

    final text = displayText.isNotEmpty ? displayText : url;
    final attributed = AttributedText(text);
    if (text.isNotEmpty) {
      attributed.addAttribution(
        LinkAttribution.fromUri(Uri.tryParse(url) ?? Uri()),
        SpanRange(0, text.length - 1),
      );
    }
    _editor!.execute([
      InsertStyledTextAtCaretRequest(attributed),
    ]);
    notifyListeners();
  }

  /// Inserts a [LinkPreviewNode] in [status] (default: loading) at the caret.
  /// If the caret sits in an empty paragraph, that paragraph is replaced.
  void insertLinkPreview({
    required String url,
    String? title,
    LinkPreviewStatus status = LinkPreviewStatus.loading,
  }) {
    if (_editor == null) return;
    final previewId = Editor.createNodeId();
    final trailingParaId = Editor.createNodeId();
    final previewNode = LinkPreviewNode(
      id: previewId,
      url: url,
      title: title ?? url,
      fetchedAt: DateTime.now(),
      status: status,
    );

    final sel = _composer?.selection;
    if (sel != null) {
      final currentNode = _editor!.document.getNodeById(sel.extent.nodeId);
      if (currentNode is ParagraphNode && currentNode.text.toPlainText().trim().isEmpty) {
        _editor!.execute([
          ReplaceNodeRequest(
            existingNodeId: currentNode.id,
            newNode: previewNode,
          ),
          InsertNodeAfterNodeRequest(
            existingNodeId: previewId,
            newNode: ParagraphNode(id: trailingParaId, text: AttributedText()),
          ),
          ChangeSelectionRequest(
            DocumentSelection.collapsed(
              position: DocumentPosition(
                nodeId: trailingParaId,
                nodePosition: const TextNodePosition(offset: 0),
              ),
            ),
            SelectionChangeType.placeCaret,
            SelectionReason.userInteraction,
          ),
        ]);
        notifyListeners();
        return;
      }

      _editor!.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: sel.extent.nodeId,
          newNode: previewNode,
        ),
        InsertNodeAfterNodeRequest(
          existingNodeId: previewId,
          newNode: ParagraphNode(id: trailingParaId, text: AttributedText()),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: trailingParaId,
              nodePosition: const TextNodePosition(offset: 0),
            ),
          ),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
      notifyListeners();
      return;
    }

    if (_editor!.document.isNotEmpty) {
      final lastNodeId = _editor!.document.last.id;
      _editor!.execute([
        InsertNodeAfterNodeRequest(
          existingNodeId: lastNodeId,
          newNode: previewNode,
        ),
        InsertNodeAfterNodeRequest(
          existingNodeId: previewId,
          newNode: ParagraphNode(id: trailingParaId, text: AttributedText()),
        ),
      ]);
      notifyListeners();
    }
  }

  /// Returns the hyperlink covering the current caret/selection (within a single
  /// text node), or null. [range] spans the full link run so callers can rewrite
  /// it in place. Used to prefill and apply the Edit Link panel (Feature 2).
  ({String url, String text, DocumentRange range})? linkAtSelection() {
    if (_editor == null || _composer == null) return null;
    final sel = _composer!.selection;
    if (sel == null) return null;
    if (sel.base.nodeId != sel.extent.nodeId) return null;
    final node = _editor!.document.getNodeById(sel.extent.nodeId);
    if (node is! TextNode) return null;
    if (sel.extent.nodePosition is! TextNodePosition) return null;

    final plain = node.text.toPlainText();
    final offset = (sel.extent.nodePosition as TextNodePosition).offset;
    // Favour the character to the left of a boundary caret, matching how most
    // editors treat a caret sitting just after a link.
    final probe = (offset > 0 && offset <= plain.length) ? offset - 1 : offset;

    final spans = node.text.getAttributionSpansByFilter((a) => a is LinkAttribution);
    for (final span in spans) {
      if (probe >= span.start && probe <= span.end) {
        final link = span.attribution as LinkAttribution;
        final text = plain.substring(span.start, span.end + 1);
        return (
          url: link.plainTextUri,
          text: text,
          range: DocumentRange(
            start: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: span.start),
            ),
            end: DocumentPosition(
              nodeId: node.id,
              nodePosition: TextNodePosition(offset: span.end + 1),
            ),
          ),
        );
      }
    }
    return null;
  }

  /// Feature 2: replaces the content in [range] with [displayText] carrying a
  /// fresh [url] [LinkAttribution]. Used when editing an existing link in place.
  void replaceLinkContent(
    DocumentRange range, {
    required String url,
    required String displayText,
  }) {
    if (_editor == null) return;
    final text = displayText.isNotEmpty ? displayText : url;
    final attributed = AttributedText(text);
    if (text.isNotEmpty) {
      attributed.addAttribution(
        LinkAttribution.fromUri(Uri.tryParse(url) ?? Uri()),
        SpanRange(0, text.length - 1),
      );
    }
    _editor!.execute([
      DeleteContentRequest(documentRange: range),
      InsertAttributedTextRequest(range.start, attributed),
    ]);
    notifyListeners();
  }

  /// Feature 5: strips every link attribution overlapping [range] while keeping
  /// the characters, reverting a link back to plain text.
  void removeLinkInRange(DocumentRange range) {
    if (_editor == null) return;
    final node = _editor!.document.getNodeById(range.start.nodeId);
    if (node is! TextNode) return;
    if (range.start.nodePosition is! TextNodePosition ||
        range.end.nodePosition is! TextNodePosition) {
      return;
    }
    final start = (range.start.nodePosition as TextNodePosition).offset;
    final end = (range.end.nodePosition as TextNodePosition).offset;
    final toRemove = <Attribution>{};
    for (final span in node.text.getAttributionSpansByFilter((a) => a is LinkAttribution)) {
      if (span.start < end && span.end >= start) {
        toRemove.add(span.attribution);
      }
    }
    if (toRemove.isEmpty) return;
    _editor!.execute([
      RemoveTextAttributionsRequest(
        documentRange: range,
        attributions: toRemove,
      ),
    ]);
    notifyListeners();
  }

  /// Feature 1 (auto-filled titles): finds the link whose href == [url] and
  /// swaps its display text to [newText]. When [force] is true, swaps regardless
  /// of whether current text equals [url].
  void replaceLinkDisplayText(String url, String newText, {bool force = false}) {
    if (_editor == null || newText.isEmpty) return;
    final normalized = Uri.tryParse(url)?.toString() ?? url;
    for (final node in _editor!.document) {
      if (node is! TextNode) continue;
      final plain = node.text.toPlainText();
      for (final span in node.text.getAttributionSpansByFilter((a) => a is LinkAttribution)) {
        final link = span.attribution as LinkAttribution;
        if (link.plainTextUri != url && link.plainTextUri != normalized) continue;
        if (span.end + 1 > plain.length) continue;
        if (!force && plain.substring(span.start, span.end + 1) != url) continue;

        final attributed = AttributedText(newText)
          ..addAttribution(
            LinkAttribution.fromUri(Uri.tryParse(url) ?? Uri()),
            SpanRange(0, newText.length - 1),
          );
        final range = DocumentRange(
          start: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: span.start),
          ),
          end: DocumentPosition(
            nodeId: node.id,
            nodePosition: TextNodePosition(offset: span.end + 1),
          ),
        );
        _editor!.execute([
          DeleteContentRequest(documentRange: range),
          InsertAttributedTextRequest(range.start, attributed),
        ]);
        notifyListeners();
        return;
      }
    }
  }

  /// Whether the single-node range [sel] already contains a hyperlink.
  bool _rangeHasLink(DocumentSelection sel) {
    if (_editor == null) return false;
    final node = _editor!.document.getNodeById(sel.extent.nodeId);
    if (node is! TextNode) return false;
    if (sel.base.nodePosition is! TextNodePosition ||
        sel.extent.nodePosition is! TextNodePosition) {
      return false;
    }
    final a = (sel.base.nodePosition as TextNodePosition).offset;
    final b = (sel.extent.nodePosition as TextNodePosition).offset;
    final start = a < b ? a : b;
    final end = a < b ? b : a;
    if (end <= start) return false;
    final spans = node.text.getAttributionSpansInRange(
      attributionFilter: (attr) => attr is LinkAttribution,
      range: SpanRange(start, end - 1),
    );
    return spans.isNotEmpty;
  }

  /// Inserts an arbitrary text snippet at the current caret, or at the end of the document.
  /// If the snippet contains block-level markdown (images, tables), it is deserialized
  /// and pasted as structured document content.
  void insertSnippet(String snippet) {
    if (_editor == null) return;

    // Feature 4: pasting a lone web URL onto a non-empty single-block selection
    // wraps the selected text as a link (display = selection, href = URL)
    // instead of replacing it. Skips multi-node ranges and ranges already
    // containing a link, falling through to the default paste in those cases.
    final activeSel = _composer?.selection;
    if (activeSel != null && !activeSel.isCollapsed && isSingleWebUrl(snippet)) {
      final url = normalizeWebUrl(snippet);
      if (url != null &&
          activeSel.base.nodeId == activeSel.extent.nodeId &&
          !_rangeHasLink(activeSel)) {
        applyLink(url: url);
        return;
      }
    }

    if (_composer?.selection == null && _editor!.document.isNotEmpty) {
      final lastNode = _editor!.document.last;
      if (lastNode is TextNode) {
        _composer!.setSelectionWithReason(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: lastNode.id,
              nodePosition: TextNodePosition(offset: lastNode.text.length),
            ),
          ),
        );
      }
    }

    if (_composer?.selection != null) {
      final trimmed = snippet.trim();
      final hasBlockImage = trimmed.contains(RegExp(r'!\[.*?\]\(.*?\)'));
      final hasBlockTable = trimmed.startsWith('|') && trimmed.contains('\n|');
      // Standalone `[name](qp://document|asset/...)` link snippets must embed as
      // attachment cards, not land as inline hyperlink text.
      final hasBlockAttachment =
          trimmed.contains(RegExp(r'\[[^\]]*\]\(\s*qp://(?:document|asset)/'));
      final hasBlockLinkPreview =
          trimmed.contains('<!-- qp-link-preview:') ||
          trimmed.contains(r'\<!-- qp-link-preview:');

      if (hasBlockImage || hasBlockTable || hasBlockAttachment || hasBlockLinkPreview) {
        final normalized = normalizeMarkdownForSuperEditor(trimmed);
        final structuredDoc = deserializeMarkdownToDocument(normalized);
        promoteQuietAttachmentNodes(structuredDoc);
        promoteLinkPreviewNodes(structuredDoc);
        if (structuredDoc.isNotEmpty) {
          _editor!.execute([
            PasteStructuredContentEditorRequest(
              content: structuredDoc,
              pastePosition: _composer!.selection!.extent,
            ),
          ]);
          return;
        }
      }

      _editor!.execute([
        InsertPlainTextAtCaretRequest(snippet),
      ]);
    }
  }
}
