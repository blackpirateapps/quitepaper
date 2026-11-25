import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../notes/application/notes_provider.dart';
import '../../../core/database/app_database.dart';
import '../../notes/domain/note_model.dart';
import '../../editor/presentation/editor_screen.dart';
import '../../email_import/application/email_editor_bridge.dart';
import '../application/task_editor_bridge.dart';
import '../application/task_providers.dart';
import '../application/task_service.dart';
import '../domain/task_document.dart';
import '../domain/task_item.dart';
import 'task_capture_dialog.dart';
import 'task_date_picker.dart';

class TasksView extends ConsumerStatefulWidget {
  const TasksView({super.key, this.onNoteSelected, this.onMenu});
  final void Function(Note note, TaskItem task)? onNoteSelected;
  final VoidCallback? onMenu;
  @override
  ConsumerState<TasksView> createState() => _TasksState();
}

class _TasksState extends ConsumerState<TasksView> with WidgetsBindingObserver {
  late final ScrollController scroll;
  late final TextEditingController search;
  late TaskDate today;
  Timer? timer;
  Timer? midnight;
  final Set<String> pending = {};
  final listFocus = FocusNode(debugLabel: 'Tasks results');
  @override
  void initState() {
    super.initState();
    today = TaskDate.local(ref.read(taskClockProvider)());
    scroll = ScrollController(
      initialScrollOffset: ref.read(taskScrollProvider),
    );
    search = TextEditingController(text: ref.read(taskSearchProvider));
    WidgetsBinding.instance.addObserver(this);
    // Also detects manual clock/timezone changes while the view is visible.
    scheduleMidnight();
    timer = Timer.periodic(const Duration(seconds: 15), (_) => checkDate());
  }

  void scheduleMidnight() {
    midnight?.cancel();
    final now = ref.read(taskClockProvider)();
    final next = DateTime(now.year, now.month, now.day + 1);
    midnight = Timer(next.difference(now), checkDate);
  }

  void checkDate() {
    scheduleMidnight();
    final next = TaskDate.local(ref.read(taskClockProvider)());
    if (mounted && next != today) setState(() => today = next);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkDate();
  }

  @override
  void dispose() {
    timer?.cancel();
    midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    scroll.dispose();
    search.dispose();
    listFocus.dispose();
    super.dispose();
  }

  void failure(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e is StaleTask
              ? e.message
              : 'Tasks could not be updated. Please try again.',
        ),
      ),
    );
    ref.invalidate(taskItemsProvider);
  }

  Future<void> open(TaskItem item) async {
    try {
      await EmailEditorBridge.active?.prepare();
      final note = await ref
          .read(notesRepositoryProvider)
          .getNoteById(item.note.id);
      if (note == null || !note.isActive || note.isPasswordProtected) {
        throw const StaleTask();
      }
      TaskDocument.resolve(
        note.content,
        expectedVersion: item.version,
        ordinal: item.occurrence.ordinal,
        taskId: item.occurrence.metadata?.id,
      );
      if (!mounted) return;
      if (widget.onNoteSelected != null) {
        widget.onNoteSelected!(note, item);
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => EditorScreen(note: note, initialTask: item),
          ),
        );
      }
      TaskEditorBridge.forNote(note.id)?.reveal(item);
    } catch (e) {
      failure(e);
    }
  }

  void committed(
    TaskCommit result,
    String message, {
    bool showDestination = false,
  }) {
    if (!mounted || !ref.read(taskSessionProvider)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Expanded(child: Text(message)),
            if (showDestination && result.task != null)
              TextButton(
                onPressed: () => open(result.task!),
                child: const Text('Open'),
              ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await result.undo.run();
            } catch (e) {
              failure(e);
            }
          },
        ),
      ),
    );
  }

  Future<void> mutate(
    TaskItem item,
    Future<TaskCommit> Function() action,
  ) async {
    if (!pending.add(item.key)) return;
    setState(() {});
    try {
      final result = await action();
      if (mounted) {
        listFocus.requestFocus();
        committed(result, 'Task updated');
      }
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => pending.remove(item.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final data = ref.watch(taskItemsProvider);
    final completed = ref.watch(taskCompletedProvider);
    final tag = ref.watch(taskTagProvider);
    final excluded = ref.watch(taskExcludedNotesProvider);
    final all = ref.watch(taskSessionProvider)
        ? (data.valueOrNull ?? <TaskItem>[])
              .where((t) => !excluded.contains(t.note.id))
              .toList()
        : <TaskItem>[];
    final filtered = filterTasks(all, ref.watch(taskSearchProvider), tag)
      ..sort((a, b) => compareTasks(a, b, today));
    final openCount = filtered.where((t) => !t.occurrence.completed).length;
    final doneCount = filtered.length - openCount;
    final items = filtered
        .where((t) => t.occurrence.completed == completed)
        .toList();
    final tags =
        all
            .expand((t) => t.note.tags)
            .expand((tag) {
              final parts = tag.split('/');
              return List.generate(
                parts.length,
                (i) => parts.take(i + 1).join('/'),
              );
            })
            .toSet()
            .toList()
          ..sort();
    if (tag != null && !tags.contains(tag)) tags.add(tag);
    final display = <Object>[];
    TaskGroup? prior;
    for (final item in items) {
      final group = item.group(today);
      if (group != prior) {
        display.add(group);
        prior = group;
      }
      display.add(item);
    }
    return Material(
      color: colors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Row(
              children: [
                if (widget.onMenu != null)
                  IconButton(
                    onPressed: widget.onMenu,
                    icon: const Icon(Icons.menu),
                    tooltip: 'Workspace navigation',
                  ),
                Expanded(
                  child: Text(
                    'Tasks',
                    style: AppTypography.title.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final result = await showTaskCapture(context);
                    if (result != null && mounted) {
                      committed(
                        result,
                        'Added to ${result.note.displayTitle}',
                        showDestination: true,
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'New task',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: search,
              onChanged: (q) => ref.read(taskSearchProvider.notifier).state = q,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search tasks and notes',
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: DropdownButton<String>(
              value: tag ?? '',
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: '', child: Text('All note tags')),
                for (final name in tags)
                  DropdownMenuItem(
                    value: name,
                    child: Text('#$name', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => ref.read(taskTagProvider.notifier).state =
                  value == '' ? null : value,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      ref.read(taskCompletedProvider.notifier).state = false,
                  child: Text(
                    'Open ($openCount)',
                    style: TextStyle(
                      fontWeight: !completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () =>
                      ref.read(taskCompletedProvider.notifier).state = true,
                  child: Text(
                    'Completed ($doneCount)',
                    style: TextStyle(
                      fontWeight: completed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (data.isLoading) const LinearProgressIndicator(),
          if ((ref.watch(taskIndexFailuresProvider).valueOrNull ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'Some notes could not be indexed. Open their source to repair invalid content, then retry.',
                  ),
                  TextButton(
                    onPressed: () async {
                      await ref.read(databaseProvider).retryTaskIndexFailures();
                      ref.invalidate(taskItemsProvider);
                    },
                    child: const Text('Retry indexing'),
                  ),
                ],
              ),
            ),
          if (data.hasError)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'Tasks could not be refreshed. Your notes are safe.',
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(taskItemsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: colors.divider),
          Expanded(
            child: Focus(
              focusNode: listFocus,
              child: display.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          data.isLoading
                              ? 'Building Tasks…'
                              : !ref.watch(taskSessionProvider)
                              ? 'Unlock your vault to see tasks.'
                              : all.isEmpty
                              ? 'Your note checkboxes will appear here.'
                              : filtered.isEmpty
                              ? 'No tasks match your search and tag.'
                              : completed
                              ? 'No completed tasks.'
                              : 'No open tasks.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.depth == 0) {
                          ref.read(taskScrollProvider.notifier).state =
                              n.metrics.pixels;
                        }
                        return false;
                      },
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: display.length,
                        itemBuilder: (context, index) {
                          final entry = display[index];
                          if (entry is TaskGroup) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                              child: Text(
                                switch (entry) {
                                  TaskGroup.overdue => 'Overdue',
                                  TaskGroup.today => 'Due today',
                                  TaskGroup.upcoming => 'Upcoming',
                                  TaskGroup.undated => 'No date',
                                  TaskGroup.completed => 'Completed',
                                },
                                style: AppTypography.bodySmall.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                            );
                          }
                          final item = entry as TaskItem;
                          final task = item.occurrence;
                          final due = task.metadata?.due;
                          final overdue =
                              !task.completed &&
                              due != null &&
                              due.compareTo(today) < 0;
                          final disabled = pending.contains(item.key);
                          return Padding(
                            key: ValueKey(item.key),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Checkbox(
                                    value: task.completed,
                                    onChanged: disabled
                                        ? null
                                        : (value) => mutate(
                                            item,
                                            () => ref
                                                .read(taskServiceProvider)
                                                .setCompleted(item, value!),
                                          ),
                                    semanticLabel:
                                        '${task.completed ? 'Reopen' : 'Complete'} ${task.text}',
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => open(item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.text.isEmpty
                                                ? 'Untitled task'
                                                : task.text,
                                            style: AppTypography.body.copyWith(
                                              color: colors.textPrimary,
                                              decoration: task.completed
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.note.displayTitle}${task.heading == null ? '' : ' · ${task.heading}'}',
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                ),
                                          ),
                                          if (due != null)
                                            TextButton(
                                              onPressed: disabled
                                                  ? null
                                                  : () => editDate(item),
                                              child: Text(
                                                '${overdue ? 'Overdue · ' : ''}${taskDateLabel(context, due, today)}',
                                                style: TextStyle(
                                                  color: overdue
                                                      ? colors.accent
                                                      : colors.textSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (due == null)
                                  IconButton(
                                    onPressed: disabled
                                        ? null
                                        : () => editDate(item),
                                    icon: const Icon(
                                      Icons.event_outlined,
                                      size: 20,
                                    ),
                                    tooltip: 'Add due date to ${task.text}',
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> editDate(TaskItem item) async {
    final selection = await showTaskDatePicker(
      context,
      today: today,
      current: item.occurrence.metadata?.due,
    );
    if (selection != null && mounted) {
      await mutate(
        item,
        () => ref.read(taskServiceProvider).setDate(item, selection.value),
      );
    }
  }
}
