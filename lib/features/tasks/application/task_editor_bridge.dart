import 'package:flutter/foundation.dart';
import '../../notes/domain/note_model.dart';
import '../domain/task_item.dart';

/// An attached editor owns its mutation and undo history. Never overwrite its
/// live buffer with a repository snapshot.
class TaskEditorBridge {
  TaskEditorBridge({
    required this.noteId,
    required this.prepare,
    required this.apply,
    required this.reveal,
  });
  final String noteId;
  final Future<Note> Function() prepare;
  final Future<Note> Function(String Function(Note) transform) apply;
  Future<void> _tail = Future.value();
  Future<Note> mutate(String Function(Note) transform) {
    final result = _tail.then((_) => apply(transform));
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
  }

  final void Function(TaskItem task) reveal;
  bool _readOnly = false;
  static final eligibilityChanges = ValueNotifier<int>(0);
  static Set<String> get readOnlyNotes =>
      _sessions.where((s) => s._readOnly).map((s) => s.noteId).toSet();
  void setReadOnly(bool value) {
    if (value == _readOnly) return;
    _readOnly = value;
    eligibilityChanges.value++;
  }

  static final _sessions = <TaskEditorBridge>[];
  static TaskEditorBridge? forNote(String id) {
    for (final session in _sessions.reversed) {
      if (session.noteId == id) return session;
    }
    return null;
  }

  void attach() {
    _sessions.remove(this);
    _sessions.add(this);
  }

  void detach() {
    _sessions.remove(this);
    if (_readOnly) eligibilityChanges.value++;
  }
}
