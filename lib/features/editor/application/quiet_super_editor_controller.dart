import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

import '../presentation/widgets/super_editor/quiet_attachment_component.dart';
import '../presentation/widgets/super_editor/quiet_image_component.dart';

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
      _editor!.execute([
        ToggleTextAttributionsRequest(
          documentRange: sel,
          attributions: {attribution},
        ),
      ]);
    } else {
      _composer!.preferences.toggleStyle(attribution);
      notifyListeners();
    }
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
      insertSnippet('[$displayText]($url)');
    }
  }

  /// Inserts an arbitrary text snippet at the current caret, or at the end of the document.
  /// If the snippet contains block-level markdown (images, tables), it is deserialized
  /// and pasted as structured document content.
  void insertSnippet(String snippet) {
    if (_editor == null) return;
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

      if (hasBlockImage || hasBlockTable || hasBlockAttachment) {
        final normalized = normalizeMarkdownForSuperEditor(trimmed);
        final structuredDoc = deserializeMarkdownToDocument(normalized);
        promoteQuietAttachmentNodes(structuredDoc);
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
