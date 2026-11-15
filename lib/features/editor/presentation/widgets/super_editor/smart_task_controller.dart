import 'package:flutter/foundation.dart';
import 'package:super_editor/super_editor.dart';

/// Range representing a contiguous block of [TaskNode]s in a [Document].
class TaskBlockRange {
  const TaskBlockRange({
    required this.startIndex,
    required this.endIndex,
    required this.tasks,
  });

  final int startIndex;
  final int endIndex;
  final List<TaskNode> tasks;

  int get length => tasks.length;
  List<TaskNode> get activeTasks => tasks.where((t) => !t.isComplete).toList();
  List<TaskNode> get completedTasks =>
      tasks.where((t) => t.isComplete).toList();
  int get completedCount => completedTasks.length;
  // Moving/folding individual rows in a nested list would detach children.
  bool get isFlat => tasks.every((task) => task.indent == 0);
  bool get hasCollapsibleCompleted => isFlat && completedCount > 3;

  /// Returns true if this block contains the node with [nodeId].
  bool containsNode(String nodeId) => tasks.any((t) => t.id == nodeId);
}

/// Controller managing smart task list behaviors in SuperEditor:
/// - Contiguous task block detection
/// - Sorting on check (moves to bottom of block)
/// - Sorting on uncheck (moves to bottom of active items)
/// - Collapsing completed items when completed count > 3
/// - Interactive expansion state tracking
/// - Caret & selection hygiene to avoid ghost carets on collapsed tasks
class SmartTaskController extends ChangeNotifier {
  SmartTaskController();

  /// Set of node IDs belonging to task blocks that the user has explicitly expanded.
  final Set<String> _expandedBlockNodeIds = <String>{};

  /// Discovers all contiguous [TaskNode] blocks in the [document].
  static List<TaskBlockRange> findTaskBlocks(Document document) {
    final blocks = <TaskBlockRange>[];
    int? currentStart;
    final currentTasks = <TaskNode>[];

    for (int i = 0; i < document.nodeCount; i++) {
      final node = document.getNodeAt(i);
      if (node is TaskNode) {
        currentStart ??= i;
        currentTasks.add(node);
      } else {
        if (currentStart != null && currentTasks.isNotEmpty) {
          blocks.add(
            TaskBlockRange(
              startIndex: currentStart,
              endIndex: i - 1,
              tasks: List.unmodifiable(currentTasks),
            ),
          );
          currentStart = null;
          currentTasks.clear();
        }
      }
    }

    if (currentStart != null && currentTasks.isNotEmpty) {
      blocks.add(
        TaskBlockRange(
          startIndex: currentStart,
          endIndex: document.nodeCount - 1,
          tasks: List.unmodifiable(currentTasks),
        ),
      );
    }

    return blocks;
  }

  /// Finds the contiguous task block containing the node with [nodeId], if any.
  static TaskBlockRange? findBlockForNode(Document document, String nodeId) {
    final nodeIndex = document.getNodeIndexById(nodeId);
    if (nodeIndex < 0) return null;
    if (document.getNodeAt(nodeIndex) is! TaskNode) return null;

    int startIndex = nodeIndex;
    while (startIndex > 0 && document.getNodeAt(startIndex - 1) is TaskNode) {
      startIndex--;
    }

    int endIndex = nodeIndex;
    while (endIndex < document.nodeCount - 1 &&
        document.getNodeAt(endIndex + 1) is TaskNode) {
      endIndex++;
    }

    final tasks = <TaskNode>[];
    for (int i = startIndex; i <= endIndex; i++) {
      tasks.add(document.getNodeAt(i) as TaskNode);
    }

    return TaskBlockRange(
      startIndex: startIndex,
      endIndex: endIndex,
      tasks: List.unmodifiable(tasks),
    );
  }

  /// Calculates the target document index for a task when its completion state changes.
  ///
  /// - When [isComplete] is true: moves to the bottom of the contiguous block ([endIndex]).
  /// - When [isComplete] is false: moves to the bottom of active (uncompleted) items.
  /// Returns null if no movement is needed or possible.
  static int? calculateDestinationIndex({
    required Document document,
    required String nodeId,
    required bool isComplete,
  }) {
    final block = findBlockForNode(document, nodeId);
    if (block == null || !block.isFlat || block.length <= 1) return null;

    final currentIndex = document.getNodeIndexById(nodeId);
    if (currentIndex < 0) return null;

    if (isComplete) {
      // Move to the bottom of this contiguous task block
      if (currentIndex == block.endIndex) return null;
      return block.endIndex;
    } else {
      // Move to the bottom of active items in this block
      final otherActiveCount = block.tasks
          .where((t) => t.id != nodeId && !t.isComplete)
          .length;
      final targetIndex = block.startIndex + otherActiveCount;

      if (currentIndex == targetIndex) return null;
      return targetIndex;
    }
  }

  /// Whether the task block containing [block] is currently expanded.
  bool isBlockExpanded(TaskBlockRange block) {
    if (!block.hasCollapsibleCompleted) {
      return true;
    }
    return block.tasks.any((t) => _expandedBlockNodeIds.contains(t.id));
  }

  /// Forget presentation state when a different document is loaded.
  void reset() => _expandedBlockNodeIds.clear();

  /// Discard expansion flags for deleted rows and lists below the threshold.
  /// Deleting a completed row must behave the same as unchecking it.
  void reconcile(Document document) {
    final expandableIds = <String>{};
    for (final block in findTaskBlocks(document)) {
      if (block.hasCollapsibleCompleted) {
        expandableIds.addAll(block.tasks.map((task) => task.id));
      }
    }
    _expandedBlockNodeIds.retainAll(expandableIds);
  }

  /// Reveal content reached by keyboard, IME selection, or undo. A selection
  /// must never point into a folded text layout.
  void revealSelection(Document document, DocumentSelection? selection) {
    if (selection == null) return;
    bool changed = false;
    for (final position in [selection.base, selection.extent]) {
      final node = document.getNodeById(position.nodeId);
      if (node is! TaskNode || !node.isComplete) continue;
      final block = findBlockForNode(document, node.id)!;
      if (!isBlockExpanded(block)) {
        _expandedBlockNodeIds.addAll(block.tasks.map((task) => task.id));
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// The first deletion at a folded-list boundary reveals the target instead
  /// of merging a paragraph into invisible completed text (desktop and IME).
  EditCommand? handleBoundaryDeletion(Editor editor, EditRequest request) {
    DocumentNode? first;
    DocumentNode? second;
    if (request is CombineParagraphsRequest) {
      first = editor.document.getNodeById(request.firstNodeId);
      second = editor.document.getNodeById(request.secondNodeId);
    } else if (request is DeleteUpstreamAtBeginningOfNodeRequest &&
        request.node is ParagraphNode &&
        (request.node.getMetadataValue(NodeMetadata.blockType) == null ||
            request.node.getMetadataValue(NodeMetadata.blockType) ==
                paragraphAttribution)) {
      first = editor.document.getNodeBeforeById(request.node.id);
      second = request.node;
    } else {
      return null;
    }
    for (final candidate in [first, second]) {
      if (candidate is! TaskNode || !candidate.isComplete) continue;
      final block = findBlockForNode(editor.document, candidate.id)!;
      if (isBlockExpanded(block)) continue;
      return _RevealTaskCommand(
        this,
        DocumentPosition(
          nodeId: candidate.id,
          nodePosition: candidate == first
              ? candidate.endPosition
              : candidate.beginningPosition,
        ),
      );
    }
    return null;
  }

  /// Move a selection that is about to be hidden to a visible writing position.
  /// Requests are included with completion/movement in one undo transaction.
  static void _relocateSelection({
    required Editor editor,
    required TaskBlockRange block,
    required Set<String> hiddenIds,
    required List<EditRequest> requests,
  }) {
    final selection = editor.maybeComposer?.selection;
    if (selection == null ||
        (!hiddenIds.contains(selection.base.nodeId) &&
            !hiddenIds.contains(selection.extent.nodeId))) {
      return;
    }

    final active = block.tasks
        .where((task) => !task.isComplete && !hiddenIds.contains(task.id))
        .toList();
    DocumentNode target;
    if (active.isNotEmpty) {
      final selectedIndex = block.tasks.indexWhere(
        (task) => task.id == selection.extent.nodeId,
      );
      target = active.firstWhere(
        (task) => block.tasks.indexOf(task) > selectedIndex,
        orElse: () => active.last,
      );
    } else {
      final next = editor.document.getNodeAt(block.endIndex + 1);
      if (next is ParagraphNode &&
          (next.getMetadataValue(NodeMetadata.blockType) ==
                  paragraphAttribution ||
              next.getMetadataValue(NodeMetadata.blockType) == null)) {
        target = next;
      } else {
        target = ParagraphNode(
          id: Editor.createNodeId(),
          text: AttributedText(),
        );
        requests.add(
          InsertNodeAtIndexRequest(
            nodeIndex: block.endIndex + 1,
            newNode: target,
          ),
        );
      }
    }
    requests.addAll([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: target.id,
            nodePosition: target.beginningPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
      const ClearComposingRegionRequest(),
    ]);
  }

  /// Collapse only after moving both selection endpoints out of completed rows.
  void toggleBlockExpansion(TaskBlockRange block, {Editor? editor}) {
    if (editor != null) {
      final current = findBlockForNode(editor.document, block.tasks.first.id);
      if (current == null) return;
      block = current;
    }
    if (!block.hasCollapsibleCompleted) return;
    if (isBlockExpanded(block)) {
      if (editor != null) {
        final requests = <EditRequest>[];
        _relocateSelection(
          editor: editor,
          block: block,
          hiddenIds: block.completedTasks.map((task) => task.id).toSet(),
          requests: requests,
        );
        if (requests.isNotEmpty) editor.execute(requests);
      }
      _expandedBlockNodeIds.removeAll(block.tasks.map((task) => task.id));
    } else {
      _expandedBlockNodeIds.addAll(block.tasks.map((task) => task.id));
    }
    notifyListeners();
  }

  /// Complete and reorder atomically without clearing selection or closing IME.
  void toggleTaskCompletion({
    required Editor editor,
    required String nodeId,
    required bool isComplete,
  }) {
    final node = editor.document.getNodeById(nodeId);
    if (node is! TaskNode || node.isComplete == isComplete) return;
    final block = findBlockForNode(editor.document, nodeId)!;
    final requests = <EditRequest>[];
    if (isComplete) {
      final willCollapse =
          block.isFlat &&
          block.completedCount + 1 > 3 &&
          !_expandedBlockNodeIds.any((id) => block.containsNode(id));
      _relocateSelection(
        editor: editor,
        block: block,
        hiddenIds: {
          nodeId,
          if (willCollapse) ...block.completedTasks.map((task) => task.id),
        },
        requests: requests,
      );
      if (willCollapse &&
          block.endIndex == editor.document.nodeCount - 1 &&
          !requests.any((request) => request is InsertNodeAtIndexRequest)) {
        requests.add(
          InsertNodeAtIndexRequest(
            nodeIndex: block.endIndex + 1,
            newNode: ParagraphNode(
              id: Editor.createNodeId(),
              text: AttributedText(),
            ),
          ),
        );
      }
    }
    requests.add(
      ChangeTaskCompletionRequest(nodeId: nodeId, isComplete: isComplete),
    );
    if (block.isFlat) {
      // Imported Markdown and preview toggles can leave completed/active rows
      // interleaved. Stable-partition the whole block, placing the toggled row
      // last within its new group, without disturbing surrounding paragraphs.
      final others = block.tasks.where((task) => task.id != nodeId);
      final orderedIds = [
        ...others.where((task) => !task.isComplete).map((task) => task.id),
        if (!isComplete) nodeId,
        ...others.where((task) => task.isComplete).map((task) => task.id),
        if (isComplete) nodeId,
      ];
      final currentIds = block.tasks.map((task) => task.id).toList();
      for (var index = 0; index < orderedIds.length; index++) {
        final id = orderedIds[index];
        final currentIndex = currentIds.indexOf(id);
        if (currentIndex == index) continue;
        requests.add(
          MoveNodeRequest(nodeId: id, newIndex: block.startIndex + index),
        );
        currentIds.insert(index, currentIds.removeAt(currentIndex));
      }
    }
    editor.execute(requests);

    final updatedBlock = findBlockForNode(editor.document, nodeId);
    if (updatedBlock != null && !updatedBlock.hasCollapsibleCompleted) {
      _expandedBlockNodeIds.removeAll(
        updatedBlock.tasks.map((task) => task.id),
      );
    }
    notifyListeners();
  }
}

/// Selection-only command: revealing a folded boundary must not consume text.
class _RevealTaskCommand extends EditCommand {
  _RevealTaskCommand(this.controller, this.position);

  final SmartTaskController controller;
  final DocumentPosition position;

  @override
  void execute(EditContext context, CommandExecutor executor) {
    final selection = DocumentSelection.collapsed(position: position);
    controller.revealSelection(context.document, selection);
    executor.executeCommand(
      ChangeSelectionCommand(
        selection,
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    );
    executor.executeCommand(ChangeComposingRegionCommand(null));
  }
}
