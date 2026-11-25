import 'package:flutter/material.dart';
import '../domain/task_document.dart';
import 'task_date_picker.dart';

TaskOccurrence? taskAtCaret(TextEditingController controller) {
  final offset = controller.selection.extentOffset;
  for (final task in TaskDocument.extract(controller.text)) {
    if (offset >= task.start && offset <= task.end) return task;
  }
  return null;
}

Future<void> editTaskDateAtCaret(
  BuildContext context,
  TextEditingController controller,
  ValueChanged<String>? onChanged,
) async {
  final task = taskAtCaret(controller);
  if (task == null) return;
  final version = TaskDocument.version(controller.text);
  final selected = await showTaskDatePicker(
    context,
    today: TaskDate.local(DateTime.now()),
    current: task.metadata?.due,
  );
  if (selected == null || !context.mounted) return;
  try {
    final live = TaskDocument.resolve(
      controller.text,
      expectedVersion: version,
      ordinal: task.ordinal,
      taskId: task.metadata?.id,
    );
    if (live.metadata?.due != task.metadata?.due) throw const StaleTask();
    final text = TaskDocument.setDate(controller.text, live, selected.value);
    final old = controller.selection;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: old.baseOffset.clamp(0, text.length),
        extentOffset: old.extentOffset.clamp(0, text.length),
      ),
    );
    onChanged?.call(text);
  } on StaleTask catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
