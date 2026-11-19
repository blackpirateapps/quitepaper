import '../../notes/domain/note_model.dart';

/// Active editor sessions flush existing edits before preview and adopt committed
/// appends afterward, preventing a hidden autosave from restoring old content.
class EmailEditorBridge {
  EmailEditorBridge({required this.prepare, required this.accept});
  final Future<Note?> Function() prepare;
  final void Function(Note note) accept;
  static final _sessions = <EmailEditorBridge>[];
  static EmailEditorBridge? get active =>
      _sessions.isEmpty ? null : _sessions.last;
  void attach() {
    _sessions.remove(this);
    _sessions.add(this);
  }

  void detach() => _sessions.remove(this);
}
