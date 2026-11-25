import 'task_editor_bridge.dart';
import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/search/search_tokenizer.dart';
import '../../../core/sync/sync_provider.dart';
import '../../../core/database/app_database.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../domain/task_document.dart';
import '../domain/task_item.dart';
import 'task_service.dart';

final taskExcludedNotesProvider = Provider<Set<String>>((ref) {
  void changed() => ref.invalidateSelf();
  TaskEditorBridge.eligibilityChanges.addListener(changed);
  ref.onDispose(
    () => TaskEditorBridge.eligibilityChanges.removeListener(changed),
  );
  return TaskEditorBridge.readOnlyNotes;
});
final taskClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final taskSearchProvider = StateProvider<String>((ref) => '');
final taskTagsProvider = StateProvider<Set<String>>((ref) => const {});
final taskCompletedProvider = StateProvider<bool>((ref) => false);
final taskScrollProvider = StateProvider<double>((ref) => 0);
final taskIndexFailuresProvider = StreamProvider.autoDispose<int>((ref) {
  if (!ref.watch(taskSessionProvider)) return Stream.value(0);
  return ref.watch(databaseProvider).watchTaskIndexFailures();
});
final taskSessionProvider = Provider<bool>((ref) {
  final key = ref.watch(keyManagerProvider);
  ref.watch(isKeyManagerUnlockedProvider);
  ref.watch(currentUserProvider);
  return !key.hasKeyData || key.isUnlocked;
});
final taskServiceProvider = Provider<TaskService>((ref) {
  final key = ref.watch(keyManagerProvider);
  final accountId = ref.watch(currentUserProvider)?.id;
  return TaskService(
    ref.watch(databaseProvider),
    ref.watch(notesRepositoryProvider),
    isAvailable: () =>
        ref.read(taskSessionProvider) &&
        ref.read(currentUserProvider)?.id == accountId,
    inboxNamespace: () async {
      if (!key.hasKeyData) await key.ensureLocalKey();
      return sha256.convert(key.getMasterKey()).toString();
    },
  );
});

/// Incremental canonical writes are indexed in their transaction. Repair here
/// covers migrations and direct writes, yielding between bounded batches.
final taskItemsProvider = StreamProvider.autoDispose<List<TaskItem>>((
  ref,
) async* {
  if (!ref.watch(taskSessionProvider)) {
    yield [];
    return;
  }
  final excluded = ref.watch(taskExcludedNotesProvider);
  final db = ref.watch(databaseProvider);
  var disposed = false;
  ref.onDispose(() => disposed = true);
  Future<void> repair() async {
    while (!disposed) {
      final count = await db.repairTaskIndex();
      if (count == 0) break;
      await Future<void>.delayed(Duration.zero);
    }
  }

  await repair();
  if (disposed) return;
  await for (final rows in db.watchTaskRows()) {
    if (disposed) return;
    await repair();
    if (disposed) return;
    final tags = await db.getTagsForNoteIds(
      rows.map((r) => r.read<String>('note_id')).toSet().toList(),
    );
    if (disposed) return;
    yield rows
        .where((row) => !excluded.contains(row.read<String>('note_id')))
        .map((row) {
          final id = row.read<String>('note_id');
          final taskId = row.readNullable<String>('task_id');
          return TaskItem(
            note: Note(
              id: id,
              title: row.read<String>('title'),
              content: '',
              tags: (tags[id] ?? []).map((t) => t.name).toList(),
              createdAt: DateTime(1970),
              updatedAt: DateTime(1970),
            ),
            version: row.read<String>('version'),
            occurrence: TaskOccurrence(
              ordinal: row.read<int>('ordinal'),
              start: 0,
              end: 0,
              checkOffset: 0,
              text: row.read<String>('text'),
              completed: row.read<bool>('completed'),
              heading: row.readNullable<String>('heading'),
              metadata: taskId == null
                  ? null
                  : TaskMetadata(
                      id: taskId,
                      due: TaskDate.tryParse(row.readNullable<String>('due')),
                    ),
            ),
          );
        })
        .toList();
  }
});

List<TaskItem> filterTasks(
  List<TaskItem> tasks,
  String search,
  Iterable<String> tags,
) {
  final tokens = SearchTokenizer.tokenize(search);
  return tasks.where((t) {
    if (tags.isNotEmpty &&
        !tags.any(
          (tag) => t.note.tags.any(
            (name) => name == tag || name.startsWith('$tag/'),
          ),
        )) {
      return false;
    }
    return tokens.every(t.normalizedSearch.contains);
  }).toList();
}

int compareTasks(TaskItem a, TaskItem b, TaskDate today) {
  final group = a.group(today).index.compareTo(b.group(today).index);
  if (group != 0) return group;
  if (!a.occurrence.completed &&
      a.occurrence.metadata?.due != null &&
      b.occurrence.metadata?.due != null) {
    final date = a.occurrence.metadata!.due!.compareTo(
      b.occurrence.metadata!.due!,
    );
    if (date != 0) return date;
  }
  final title = a.titleSortKey.compareTo(b.titleSortKey);
  if (title != 0) return title;
  final id = a.note.id.compareTo(b.note.id);
  return id != 0 ? id : a.occurrence.ordinal.compareTo(b.occurrence.ordinal);
}
