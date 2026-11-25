import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/domain/note_model.dart';
import '../application/task_providers.dart';
import '../application/task_service.dart';
import '../domain/task_document.dart';
import 'task_date_picker.dart';

final taskDestinationsProvider = StreamProvider.autoDispose<List<Note>>((ref) {
  final excluded = ref.watch(taskExcludedNotesProvider);
  return ref
      .watch(notesRepositoryProvider)
      .watchNotes()
      .map(
        (notes) => notes
            .where(
              (n) =>
                  n.isActive &&
                  !n.isPasswordProtected &&
                  n.deletedAt == null &&
                  !excluded.contains(n.id),
            )
            .toList(),
      );
});

Future<TaskCommit?> showTaskCapture(BuildContext context) =>
    showDialog<TaskCommit>(
      context: context,
      builder: (_) => const _CaptureDialog(),
    );

class _CaptureDialog extends ConsumerStatefulWidget {
  const _CaptureDialog();
  @override
  ConsumerState<_CaptureDialog> createState() => _CaptureState();
}

class _CaptureState extends ConsumerState<_CaptureDialog> {
  final text = TextEditingController();
  final captureId = const Uuid().v4();
  String destination = 'inbox';
  TaskDate? due;
  bool busy = false;
  String? error;
  String? trashedInbox;
  late final FocusNode inputFocus;
  @override
  void initState() {
    super.initState();
    inputFocus = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
            text.value.composing.isCollapsed) {
          submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    inputFocus.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !text.value.composing.isCollapsed) return;
    if (text.text.trim().isEmpty ||
        text.text.contains(RegExp(r'[\r\n\u2028\u2029]'))) {
      setState(() => error = 'Enter one task on a single line.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final commit = await ref
          .read(taskServiceProvider)
          .capture(
            text: text.text,
            captureId: captureId,
            due: due,
            noteId: destination.startsWith('note:')
                ? destination.substring(5)
                : null,
            todayJournal: destination == 'journal',
            today: ref.read(taskClockProvider)(),
          );
      if (mounted) Navigator.pop(context, commit);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          trashedInbox = e is TaskInboxInTrash ? e.noteId : null;
          error = e is StaleTask
              ? e.message
              : 'Task could not be saved. Your draft is retained; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(taskDestinationsProvider).valueOrNull ?? [];
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: const Text('New task'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  focusNode: inputFocus,
                  autofocus: true,
                  enabled: !busy,
                  maxLines: null,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () {},
                  onSubmitted: (_) => submit(),
                  decoration: InputDecoration(
                    labelText: 'Task',
                    errorText: error,
                  ),
                ),
                if (trashedInbox != null)
                  TextButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() => busy = true);
                            try {
                              await ref
                                  .read(notesRepositoryProvider)
                                  .restoreFromTrash(trashedInbox!);
                              if (mounted) {
                                setState(() {
                                  trashedInbox = null;
                                  error = null;
                                });
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(
                                  () => error =
                                      'Task Inbox could not be restored. Please retry.',
                                );
                              }
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          },
                    child: const Text('Restore Task Inbox'),
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: destination,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Destination'),
                  items: [
                    const DropdownMenuItem(
                      value: 'inbox',
                      child: Text('Task Inbox'),
                    ),
                    const DropdownMenuItem(
                      value: 'journal',
                      child: Text('Today’s Journal'),
                    ),
                    for (final note in notes)
                      DropdownMenuItem(
                        value: 'note:${note.id}',
                        child: Text(
                          note.displayTitle,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => destination = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: busy
                      ? null
                      : () async {
                          final selected = await showTaskDatePicker(
                            context,
                            today: TaskDate.local(
                              ref.read(taskClockProvider)(),
                            ),
                            current: due,
                          );
                          if (selected != null && mounted) {
                            setState(() => due = selected.value);
                          }
                        },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    due == null
                        ? 'Add due date'
                        : taskDateLabel(
                            context,
                            due!,
                            TaskDate.local(ref.read(taskClockProvider)()),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Saving…' : 'Add task'),
          ),
        ],
      ),
    );
  }
}
