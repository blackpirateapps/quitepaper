import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/quiet_button.dart';
import '../application/task_service.dart';
import '../domain/task_document.dart';
import 'task_modal.dart';

Future<TaskCommit?> showTaskRename(
  BuildContext context, {
  required String text,
  required Future<TaskCommit> Function(String) onSave,
}) => showTaskModal<TaskCommit>(
  context,
  (_) => _Rename(text: text, onSave: onSave),
);

Future<bool?> showTaskDelete(
  BuildContext context,
  String text,
) => showTaskModal<bool>(
  context,
  (context) => TaskModal(
    title: 'Delete task?',
    subtitle: text,
    actions: Row(
      children: [
        Expanded(
          child: QuietButton(
            label: 'Cancel',
            variant: QuietButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: QuietButton(
            label: 'Delete task',
            variant: QuietButtonVariant.destructive,
            onPressed: () => Navigator.pop(context, true),
          ),
        ),
      ],
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Text(
        'This removes the task and any nested items from the note. You can undo this change.',
        style: context.appTypography.body.copyWith(
          color: context.appColors.textSecondary,
        ),
      ),
    ),
  ),
);

class _Rename extends StatefulWidget {
  const _Rename({required this.text, required this.onSave});
  final String text;
  final Future<TaskCommit> Function(String) onSave;
  @override
  State<_Rename> createState() => _RenameState();
}

class _RenameState extends State<_Rename> {
  late final text = TextEditingController(text: widget.text.split('\n').first);
  bool busy = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !text.value.composing.isCollapsed) return;
    if (text.text.trim().isEmpty ||
        text.text.contains(RegExp(r'[\r\n\u2028\u2029]'))) {
      setState(() => error = 'Enter a task name on a single line.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.onSave(text.text.trim());
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = e is StaleTask
              ? e.message
              : 'Could not rename the task. Your draft is retained; try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => TaskModal(
    title: 'Rename task',
    busy: busy,
    actions: Row(
      children: [
        Expanded(
          child: QuietButton(
            label: 'Cancel',
            variant: QuietButtonVariant.ghost,
            onPressed: busy ? null : () => Navigator.pop(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: QuietButton(
            label: busy ? 'Saving…' : 'Save',
            isLoading: busy,
            variant: QuietButtonVariant.primary,
            onPressed: busy ? null : save,
          ),
        ),
      ],
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: TextField(
        controller: text,
        autofocus: true,
        enabled: !busy,
        maxLines: null,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => save(),
        decoration: InputDecoration(labelText: 'Task name', errorText: error),
      ),
    ),
  );
}
