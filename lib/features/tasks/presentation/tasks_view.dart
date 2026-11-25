import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../tags/domain/phosphor_icons.dart';
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
import 'task_tag_filter.dart';
import 'task_edit_sheet.dart';

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
  String? expandedTask;
  bool searchVisible = false;
  final listFocus = FocusNode(debugLabel: 'Tasks results');
  @override
  void initState() {
    super.initState();
    today = TaskDate.local(ref.read(taskClockProvider)());
    scroll = ScrollController(
      initialScrollOffset: ref.read(taskScrollProvider),
    );
    search = TextEditingController(text: ref.read(taskSearchProvider));
    searchVisible = search.text.isNotEmpty;
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
    Future<TaskCommit> Function() action, {
    String message = 'Task updated',
  }) async {
    if (!pending.add(item.key)) return;
    setState(() {});
    try {
      final result = await action();
      if (mounted) {
        listFocus.requestFocus();
        committed(result, message);
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
    final selectedTags = ref.watch(taskTagsProvider);
    final excluded = ref.watch(taskExcludedNotesProvider);
    final all = ref.watch(taskSessionProvider)
        ? (data.valueOrNull ?? <TaskItem>[])
              .where((t) => !excluded.contains(t.note.id))
              .toList()
        : <TaskItem>[];
    final filtered = filterTasks(
      all,
      ref.watch(taskSearchProvider),
      selectedTags,
    )..sort((a, b) => compareTasks(a, b, today));
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
    tags.addAll(selectedTags.difference(tags.toSet()));
    final firstLoad = data.isLoading && data.valueOrNull == null;
    final display = <Object>[];
    final groupedKeys = <String>{};
    TaskGroup? prior;
    for (var i = 0; i < items.length;) {
      final item = items[i];
      final group = item.group(today);
      if (group != prior) {
        display.add(group);
        prior = group;
      }
      // Keep date ordering intact; share a source heading for adjacent tasks
      // belonging to the same note in the same date group.
      var end = i + 1;
      while (end < items.length &&
          items[end].group(today) == group &&
          items[end].note.id == item.note.id) {
        end++;
      }
      if (end - i > 1) {
        display.add(_TaskSourceHeading(item));
        groupedKeys.addAll(items.sublist(i, end).map((item) => item.key));
      }
      display.addAll(items.sublist(i, end));
      i = end;
    }
    return Material(
      color: colors.background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
            child: Row(
              children: [
                if (widget.onMenu != null) ...[
                  IconButton(
                    onPressed: widget.onMenu,
                    icon: const Icon(PhosphorIconsRegular.list, size: 26),
                    color: colors.iconSecondary,
                    tooltip: 'Workspace navigation',
                  ),
                  const SizedBox(width: 12),
                ] else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tasks',
                    style: context.appTypography.title.copyWith(
                      fontFamily: 'serif',
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (searchVisible) {
                      FocusScope.of(context).unfocus();
                    }
                    setState(() => searchVisible = !searchVisible);
                  },
                  icon: Icon(
                    searchVisible
                        ? PhosphorIconsRegular.x
                        : PhosphorIconsRegular.magnifyingGlass,
                    size: 26,
                  ),
                  color: search.text.isEmpty
                      ? colors.iconSecondary
                      : colors.accent,
                  tooltip: searchVisible ? 'Hide search' : 'Search tasks',
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
                  icon: const Icon(PhosphorIconsRegular.plus, size: 28),
                  color: colors.accent,
                  tooltip: 'New task',
                ),
              ],
            ),
          ),
          if (searchVisible)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: TextField(
                controller: search,
                autofocus: searchVisible,
                onChanged: (q) =>
                    ref.read(taskSearchProvider.notifier).state = q,
                decoration: InputDecoration(
                  prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(PhosphorIconsRegular.x),
                          onPressed: () {
                            search.clear();
                            ref.read(taskSearchProvider.notifier).state = '';
                          },
                        ),
                  hintText: 'Search tasks and notes',
                  isDense: true,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabs = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    tab(
                      'Open',
                      firstLoad ? null : openCount,
                      !completed,
                      () => ref.read(taskCompletedProvider.notifier).state =
                          false,
                    ),
                    const SizedBox(width: 24),
                    tab(
                      'Completed',
                      firstLoad ? null : doneCount,
                      completed,
                      () =>
                          ref.read(taskCompletedProvider.notifier).state = true,
                    ),
                  ],
                );
                final tagPicker = SizedBox(
                  width: 104,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: selectedTags.isEmpty
                          ? colors.textSecondary
                          : colors.accent,
                      textStyle: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.merge(context.appTypography.body),
                    ),
                    onPressed: () async {
                      final selection = await showTaskTagFilter(
                        context,
                        available: tags,
                        selected: selectedTags,
                      );
                      if (selection != null && mounted) {
                        ref.read(taskTagsProvider.notifier).state = selection;
                      }
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedTags.isEmpty
                                ? 'All tags'
                                : selectedTags.length == 1
                                ? '#${selectedTags.single}'
                                : '${selectedTags.length} tags',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(PhosphorIconsRegular.caretDown, size: 12),
                      ],
                    ),
                  ),
                );
                double labelWidth(String label, bool selected) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: label,
                      style: DefaultTextStyle.of(context).style
                          .merge(context.appTypography.body)
                          .copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                    ),
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout();
                  final width = painter.width;
                  painter.dispose();
                  return width;
                }

                final tabsWidth =
                    labelWidth(
                      firstLoad ? 'Open' : 'Open $openCount',
                      !completed,
                    ) +
                    labelWidth(
                      firstLoad ? 'Completed' : 'Completed $doneCount',
                      completed,
                    ) +
                    24;
                if (constraints.maxWidth < tabsWidth + 104 + 16) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: tabs,
                      ),
                      Align(alignment: Alignment.centerRight, child: tagPicker),
                    ],
                  );
                }
                return Row(children: [tabs, const Spacer(), tagPicker]);
              },
            ),
          ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 1, color: colors.divider),
          ),
          Expanded(
            child: Focus(
              focusNode: listFocus,
              child: firstLoad && ref.watch(taskSessionProvider)
                  ? const _TaskListLoading()
                  : display.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          !ref.watch(taskSessionProvider)
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
                          if (entry is TaskGroup ||
                              entry is _TaskSourceHeading) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                index == 0 ? 28 : 24,
                                24,
                                10,
                              ),
                              child: entry is _TaskSourceHeading
                                  ? sourceLink(entry.item, heading: true)
                                  : Text(
                                      switch (entry as TaskGroup) {
                                        TaskGroup.overdue => 'Overdue',
                                        TaskGroup.today => 'Due today',
                                        TaskGroup.upcoming => 'Upcoming',
                                        TaskGroup.undated => 'No date',
                                        TaskGroup.completed => 'Completed',
                                      },
                                      style: context.appTypography.body
                                          .copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.textSecondary,
                                          ),
                                    ),
                            );
                          }
                          final item = entry as TaskItem;
                          return taskRow(
                            item,
                            showSource: !groupedKeys.contains(item.key),
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

  Widget tab(String label, int? count, bool selected, VoidCallback onTap) {
    final colors = context.appColors;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            count == null ? label : '$label $count',
            style: context.appTypography.body.copyWith(
              color: selected ? colors.textPrimary : colors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget taskRow(TaskItem item, {required bool showSource}) {
    final colors = context.appColors;
    final task = item.occurrence;
    final due = task.metadata?.due;
    final overdue = !task.completed && due != null && due.compareTo(today) < 0;
    final disabled = pending.contains(item.key);
    final expanded = expandedTask == item.key;
    final dateLabel = due == null
        ? 'Add due date'
        : '${overdue ? 'Overdue · ' : ''}${taskDateLabel(context, due, today)}';
    return Material(
      key: ValueKey(item.key),
      color: expanded ? colors.surfaceSecondary : colors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: 12),
              SizedBox(
                width: 48,
                height: 48,
                child: Checkbox(
                  value: task.completed,
                  shape: const CircleBorder(),
                  side: BorderSide(color: colors.iconSecondary, width: 1.5),
                  activeColor: colors.accent,
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
                child: Semantics(
                  expanded: expanded,
                  child: InkWell(
                    onTap: () => setState(
                      () => expandedTask = expanded ? null : item.key,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 9, 24, 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.text.isEmpty
                                      ? 'Untitled task'
                                      : task.text,
                                  style: context.appTypography.bodyLarge
                                      .copyWith(
                                        color: colors.textPrimary,
                                        height: 1.4,
                                        decoration: task.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                ),
                                if (showSource) ...[
                                  const SizedBox(height: 2),
                                  sourceLink(item),
                                  if (task.heading != null)
                                    Text(
                                      task.heading!,
                                      style: context.appTypography.bodySmall
                                          .copyWith(
                                            color: colors.textSecondary,
                                          ),
                                    ),
                                ] else if (task.heading != null)
                                  Text(
                                    task.heading!,
                                    style: context.appTypography.bodySmall
                                        .copyWith(color: colors.textSecondary),
                                  ),
                                if (due != null && !expanded)
                                  Text(
                                    dateLabel,
                                    style: context.appTypography.bodySmall
                                        .copyWith(
                                          color: overdue
                                              ? colors.accent
                                              : colors.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 8),
                              child: Icon(
                                PhosphorIconsRegular.caretUp,
                                size: 18,
                                color: colors.iconSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 0, 16, 4),
              child: Wrap(
                spacing: 16,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      foregroundColor: colors.accent,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: disabled ? null : () => editDate(item),
                    icon: const Icon(
                      PhosphorIconsRegular.calendarBlank,
                      size: 16,
                    ),
                    label: Text(dateLabel),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: disabled ? null : () => renameTask(item),
                    icon: const Icon(
                      PhosphorIconsRegular.pencilSimple,
                      size: 16,
                    ),
                    label: const Text('Rename'),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.error,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 28),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: disabled ? null : () => deleteTask(item),
                    icon: const Icon(PhosphorIconsRegular.trash, size: 16),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget sourceLink(TaskItem item, {bool heading = false}) {
    final colors = context.appColors;
    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Open note: ${item.note.displayTitle}',
        child: Semantics(
          link: true,
          child: InkWell(
            onTap: () => open(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      item.note.displayTitle,
                      style:
                          (heading
                                  ? context.appTypography.body
                                  : context.appTypography.bodySmall)
                              .copyWith(
                                fontWeight: heading
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: colors.textSecondary,
                              ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    PhosphorIconsRegular.arrowUpRight,
                    size: heading ? 16 : 14,
                    color: colors.iconSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> renameTask(TaskItem item) async {
    final result = await showTaskRename(
      context,
      text: item.occurrence.text,
      onSave: (text) => ref.read(taskServiceProvider).rename(item, text),
    );
    if (result != null && mounted) {
      setState(() => expandedTask = null);
      listFocus.requestFocus();
      committed(result, 'Task renamed');
    }
  }

  Future<void> deleteTask(TaskItem item) async {
    final confirmed = await showTaskDelete(context, item.occurrence.text);
    if (confirmed == true && mounted) {
      await mutate(
        item,
        () => ref.read(taskServiceProvider).delete(item),
        message: 'Task deleted',
      );
    }
  }

  Future<void> editDate(TaskItem item) async {
    final selection = await showTaskDatePicker(
      context,
      today: today,
      current: item.occurrence.metadata?.due,
      taskTitle: item.occurrence.text,
    );
    if (selection != null && mounted) {
      await mutate(
        item,
        () => ref.read(taskServiceProvider).setDate(item, selection.value),
      );
    }
  }
}

class _TaskListLoading extends StatelessWidget {
  const _TaskListLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Finding tasks in your notes…',
                  style: context.appTypography.body.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ExcludeSemantics(
            child: Column(
              children: [
                for (final width in [0.78, 0.66, 0.74])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIconsRegular.circle,
                          size: 20,
                          color: colors.textTertiary,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: width,
                              child: Container(
                                height: 11,
                                decoration: BoxDecoration(
                                  color: colors.divider,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSourceHeading {
  const _TaskSourceHeading(this.item);
  final TaskItem item;
}
