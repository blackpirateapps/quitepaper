import '../../../core/journal/domain/journal_date_helper.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/task_document.dart';
import '../domain/task_item.dart';
import 'task_editor_bridge.dart';

class TaskUndo {
  TaskUndo(this.run);
  final Future<void> Function() run;
}

class TaskInboxInTrash extends StaleTask {
  const TaskInboxInTrash(this.noteId)
    : super('Task Inbox is in Trash. Restore it, then retry.');
  final String noteId;
}

class TaskCommit {
  const TaskCommit(this.note, this.undo, {this.task});
  final TaskItem? task;
  final Note note;
  final TaskUndo undo;
}

class TaskService {
  TaskService(
    this.database,
    this.repository, {
    required this.inboxNamespace,
    this.isAvailable,
  });
  final AppDatabase database;
  final NotesRepository repository;
  final Future<String> Function() inboxNamespace;
  final bool Function()? isAvailable;
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) async {
      _checkSession();
      return action();
    });
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  void _checkSession() {
    if (isAvailable?.call() == false) {
      throw const StaleTask('Unlock your current vault to use Tasks.');
    }
  }

  void _eligible(Note? note) {
    _checkSession();
    if (note == null ||
        !note.isActive ||
        note.deletedAt != null ||
        note.isPasswordProtected) {
      throw const StaleTask('The source note is no longer available in Tasks.');
    }
  }

  Future<Note> _write(String id, String Function(Note) transform) async {
    final bridge = TaskEditorBridge.forNote(id);
    if (bridge != null) {
      return bridge.mutate((note) {
        _eligible(note);
        return transform(note);
      });
    }
    return database.transaction(() async {
      final note = await repository.getNoteById(id);
      _eligible(note);
      final content = transform(note!);
      _checkSession();
      if (content == note.content) return note;
      final updated = note.copyWith(
        content: content,
        updatedAt: DateTime.now(),
      );
      // Transaction holds SQLite's write serialization across latest read/save.
      await repository.saveNote(updated, preserveEmptyTags: true);
      return updated;
    });
  }

  TaskOccurrence _resolve(Note note, TaskItem item) => TaskDocument.resolve(
    note.content,
    expectedVersion: item.version,
    ordinal: item.occurrence.ordinal,
    taskId: item.occurrence.metadata?.id,
  );

  Future<TaskCommit> setCompleted(TaskItem item, bool value) =>
      _serial(() async {
        final before = item.occurrence.completed;
        final note = await _write(item.note.id, (note) {
          final target = _resolve(note, item);
          if (target.completed != before) throw const StaleTask();
          return TaskDocument.setCompleted(note.content, target, value);
        });
        final after = _currentItem(
          note,
          item.occurrence.ordinal,
          item.occurrence.metadata?.id,
        );
        return TaskCommit(
          note,
          TaskUndo(() async {
            await setCompleted(after, before);
          }),
        );
      });

  Future<TaskCommit> setDate(TaskItem item, TaskDate? date) =>
      _serial(() async {
        final before = item.occurrence.metadata?.due;
        final id = item.occurrence.metadata?.id ?? const Uuid().v4();
        final note = await _write(item.note.id, (note) {
          final target = _resolve(note, item);
          if (target.metadata?.due != before) throw const StaleTask();
          return TaskDocument.setDate(note.content, target, date, newId: id);
        });
        final after = _currentItem(note, item.occurrence.ordinal, id);
        return TaskCommit(
          note,
          TaskUndo(() async {
            await setDate(after, before);
          }),
        );
      });

  TaskItem _currentItem(Note note, int ordinal, String? id) {
    final version = TaskDocument.version(note.content);
    return TaskItem(
      note: note,
      version: version,
      occurrence: TaskDocument.resolve(
        note.content,
        expectedVersion: version,
        ordinal: ordinal,
        taskId: id,
      ),
    );
  }

  Future<TaskCommit> capture({
    required String text,
    required String captureId,
    TaskDate? due,
    String? noteId,
    bool todayJournal = false,
    DateTime? today,
  }) => _serial(() async {
    // Validate before destination creation. Retry always reuses captureId.
    TaskDocument.append('', text, captureId, due);
    final namespace = await inboxNamespace();
    _checkSession();
    final inboxId = const Uuid().v5(
      Namespace.url.value,
      'quietpaper:task-inbox:v1:$namespace',
    );
    final journalNote = todayJournal
        ? await repository.getJournalEntry(
            JournalDateHelper.toDateString(today ?? DateTime.now()),
          )
        : null;
    final id = noteId ?? (todayJournal ? journalNote?.id : inboxId);
    TaskCommit makeCommit(Note note) {
      final captured = _currentItem(note, 0, captureId);
      final original = captured.occurrence;
      final fingerprint = TaskDocument.fingerprint(note.content, original);
      return TaskCommit(
        note,
        TaskUndo(
          () => _serial(() async {
            await _write(note.id, (live) {
              final task = _resolve(live, captured);
              if (TaskDocument.fingerprint(live.content, task) != fingerprint ||
                  task.text != original.text ||
                  task.completed != original.completed ||
                  task.metadata != original.metadata) {
                throw const StaleTask(
                  'Undo is unavailable because the task has been edited.',
                );
              }
              return TaskDocument.remove(live.content, task);
            });
          }),
        ),
        task: captured,
      );
    }

    if (id != null && TaskEditorBridge.forNote(id) != null) {
      return makeCommit(
        await _write(
          id,
          (note) => TaskDocument.append(note.content, text, captureId, due),
        ),
      );
    }
    return database.transaction(() async {
      Note? note;
      if (todayJournal) {
        note = await repository.getOrCreateJournalEntry(
          today ?? DateTime.now(),
        );
      } else {
        note = await repository.getNoteById(id!);
        if (note == null && noteId == null) {
          final now = DateTime.now();
          note = Note(
            id: inboxId,
            title: 'Task Inbox',
            content: '',
            createdAt: now,
            updatedAt: now,
          );
        }
      }
      if (note?.isTrashed == true && noteId == null && !todayJournal) {
        throw TaskInboxInTrash(note!.id);
      }
      _eligible(note);
      // A journal resolved by the service can also be open in the editor.
      if (TaskEditorBridge.forNote(note!.id) != null) {
        throw const StaleTask(
          'Choose the open journal explicitly to capture while editing it.',
        );
      }
      final updated = note.copyWith(
        content: TaskDocument.append(note.content, text, captureId, due),
        updatedAt: DateTime.now(),
      );
      _checkSession();
      await repository.saveNote(updated, preserveEmptyTags: true);
      return makeCommit(updated);
    });
  });
}
