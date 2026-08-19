import 'package:flutter/material.dart';

/// Represents a discrete snapshot of the editor text state and cursor position.
@immutable
class TextEditSnapshot {
  const TextEditSnapshot({
    required this.text,
    required this.selection,
    required this.timestamp,
  });

  final String text;
  final TextSelection selection;
  final DateTime timestamp;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextEditSnapshot &&
          text == other.text &&
          selection.start == other.selection.start &&
          selection.end == other.selection.end;

  @override
  int get hashCode =>
      text.hashCode ^ selection.start.hashCode ^ selection.end.hashCode;
}

/// Manages undo and redo stacks for a note editing session.
/// Batches continuous typing within a small debounce window while creating
/// immediate atomic snapshots for programmatic formatting or whitespace breaks.
class UndoRedoManager extends ChangeNotifier {
  UndoRedoManager({
    this.maxHistory = 100,
    this.typingDebounceDuration = const Duration(milliseconds: 600),
  });

  final int maxHistory;
  final Duration typingDebounceDuration;

  final List<TextEditSnapshot> _undoStack = [];
  final List<TextEditSnapshot> _redoStack = [];

  bool _isApplying = false;

  bool get canUndo => _undoStack.length > 1;
  bool get canRedo => _redoStack.isNotEmpty;

  /// Initializes the undo stack with the starting text and selection.
  void initialize(TextEditingValue initialValue) {
    _undoStack.clear();
    _redoStack.clear();
    _undoStack.add(TextEditSnapshot(
      text: initialValue.text,
      selection: initialValue.selection,
      timestamp: DateTime.now(),
    ));
    notifyListeners();
  }

  /// Registers an edit from the text editing controller.
  void registerEdit(TextEditingValue value) {
    if (_isApplying) return;

    final now = DateTime.now();

    if (_undoStack.isEmpty) {
      _undoStack.add(TextEditSnapshot(
        text: value.text,
        selection: value.selection,
        timestamp: now,
      ));
      _redoStack.clear();
      notifyListeners();
      return;
    }

    final top = _undoStack.last;

    // If text is identical, only update the cursor selection on the current snapshot
    if (top.text == value.text) {
      if (top.selection != value.selection) {
        _undoStack[_undoStack.length - 1] = TextEditSnapshot(
          text: value.text,
          selection: value.selection,
          timestamp: top.timestamp,
        );
      }
      return;
    }

    final timeDiff = now.difference(top.timestamp);

    // Check if continuous typing should replace the top snapshot (debounce batching)
    final isContinuousTyping = timeDiff < typingDebounceDuration &&
        !value.text.endsWith('\n');

    if (isContinuousTyping && _undoStack.length > 1) {
      _undoStack[_undoStack.length - 1] = TextEditSnapshot(
        text: value.text,
        selection: value.selection,
        timestamp: now,
      );
    } else {
      _undoStack.add(TextEditSnapshot(
        text: value.text,
        selection: value.selection,
        timestamp: now,
      ));
      if (_undoStack.length > maxHistory + 1) {
        _undoStack.removeAt(0);
      }
    }

    _redoStack.clear();
    notifyListeners();
  }

  /// Pushes an immediate atomic snapshot (e.g. after a formatting toolbar action).
  void pushAtomicEdit(TextEditingValue value) {
    if (_isApplying) return;

    final now = DateTime.now();
    if (_undoStack.isNotEmpty && _undoStack.last.text == value.text) {
      _undoStack[_undoStack.length - 1] = TextEditSnapshot(
        text: value.text,
        selection: value.selection,
        timestamp: now,
      );
    } else {
      _undoStack.add(TextEditSnapshot(
        text: value.text,
        selection: value.selection,
        timestamp: now,
      ));
      if (_undoStack.length > maxHistory + 1) {
        _undoStack.removeAt(0);
      }
    }
    _redoStack.clear();
    notifyListeners();
  }

  /// Undoes the last edit and returns the previous TextEditingValue.
  TextEditingValue? undo(TextEditingValue currentValue) {
    if (!canUndo) return null;

    _isApplying = true;
    try {
      final currentTop = _undoStack.removeLast();
      _redoStack.add(TextEditSnapshot(
        text: currentValue.text,
        selection: currentValue.selection,
        timestamp: currentTop.timestamp,
      ));

      final target = _undoStack.last;
      return TextEditingValue(
        text: target.text,
        selection: target.selection,
      );
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// Redoes the undone edit and returns the next TextEditingValue.
  TextEditingValue? redo(TextEditingValue currentValue) {
    if (!canRedo) return null;

    _isApplying = true;
    try {
      final target = _redoStack.removeLast();
      _undoStack.add(target);

      return TextEditingValue(
        text: target.text,
        selection: target.selection,
      );
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  /// Clears the undo and redo history for session reset.
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    _isApplying = false;
    notifyListeners();
  }
}
