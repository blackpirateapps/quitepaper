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
  List<TaskNode> get completedTasks => tasks.where((t) => t.isComplete).toList();
  int get completedCount => completedTasks.length;
  bool get hasCollapsibleCompleted => completedCount > 3;

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
    while (endIndex < document.nodeCount - 1 && document.getNodeAt(endIndex + 1) is TaskNode) {
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
    if (block == null || block.length <= 1) return null;

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

  /// Toggles the expansion state of the task block containing [block].
  /// If collapsing and the editor has an active selection in one of the completed tasks,
  /// clears the selection to avoid ghost carets.
  void toggleBlockExpansion(TaskBlockRange block, {Editor? editor}) {
    final isExpanded = isBlockExpanded(block);
    if (isExpanded) {
      // Collapse: remove all node IDs in this block from expanded set
      for (final task in block.tasks) {
        _expandedBlockNodeIds.remove(task.id);
      }
      // Clear selection if it sat within any completed task in this block
      final composer = editor?.maybeComposer;
      if (composer != null && composer.selection != null) {
        final selectionNodeId = composer.selection!.extent.nodeId;
        if (block.completedTasks.any((t) => t.id == selectionNodeId)) {
          composer.clearSelection();
        }
      }
    } else {
      // Expand: add all node IDs in this block to expanded set
      for (final task in block.tasks) {
        _expandedBlockNodeIds.add(task.id);
      }
    }
    notifyListeners();
  }

  /// Executes smart task completion change on [editor]:
  /// 1. Clears selection if caret was inside the task being completed/moved.
  /// 2. Toggles completion state via [ChangeTaskCompletionRequest].
  /// 3. If destination index differs, moves node via [MoveNodeRequest].
  /// 4. If resulting block is collapsed, ensures caret cannot remain on a collapsed node.
  /// 5. Preserves undo/redo history.
  void toggleTaskCompletion({
    required Editor editor,
    required String nodeId,
    required bool isComplete,
  }) {
    final doc = editor.document;
    final destinationIndex = calculateDestinationIndex(
      document: doc,
      nodeId: nodeId,
      isComplete: isComplete,
    );

    // Hygiene: Clear composer selection if the user was focused on the task being completed/moved.
    // This prevents the caret overlay from painting a floating caret on a collapsed/moved node,
    // and clears the active checklist highlight in the formatting toolbar.
    final composer = editor.maybeComposer;
    if (composer != null && composer.selection != null) {
      final selectedNodeId = composer.selection!.extent.nodeId;
      if (selectedNodeId == nodeId || (destinationIndex != null && isComplete)) {
        composer.clearSelection();
      }
    }

    final requests = <EditRequest>[
      ChangeTaskCompletionRequest(
        nodeId: nodeId,
        isComplete: isComplete,
      ),
    ];

    if (destinationIndex != null) {
      requests.add(
        MoveNodeRequest(
          nodeId: nodeId,
          newIndex: destinationIndex,
        ),
      );
    }

    editor.execute(requests);

    // After updating, check if any block's completed count dropped <= 3 and prune expanded set
    final updatedBlock = findBlockForNode(editor.document, nodeId);
    if (updatedBlock != null) {
      if (!updatedBlock.hasCollapsibleCompleted) {
        for (final task in updatedBlock.tasks) {
          _expandedBlockNodeIds.remove(task.id);
        }
      } else if (!isBlockExpanded(updatedBlock) && composer != null && composer.selection != null) {
        // Double check: if block is now collapsed, clear selection if it's on any completed item
        final selectionNodeId = composer.selection!.extent.nodeId;
        if (updatedBlock.completedTasks.any((t) => t.id == selectionNodeId)) {
          composer.clearSelection();
        }
      }
    }

    notifyListeners();
  }
}
