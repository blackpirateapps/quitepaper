import 'package:flutter/material.dart';
import '../domain/task_document.dart';

class TaskDateSelection {
  const TaskDateSelection(this.value);
  final TaskDate? value;
}

String taskDateLabel(BuildContext context, TaskDate date, TaskDate today) {
  if (date == today) return 'Today';
  if (date == today.addDays(1)) return 'Tomorrow';
  return MaterialLocalizations.of(context).formatMediumDate(date.calendar);
}

Future<TaskDateSelection?> showTaskDatePicker(
  BuildContext context, {
  required TaskDate today,
  TaskDate? current,
}) => showDialog<TaskDateSelection>(
  context: context,
  builder: (context) => _DatePicker(today: today, current: current),
);

class _DatePicker extends StatefulWidget {
  const _DatePicker({required this.today, this.current});
  final TaskDate today;
  final TaskDate? current;
  @override
  State<_DatePicker> createState() => _DatePickerState();
}

class _DatePickerState extends State<_DatePicker> {
  TaskDate? pending;
  @override
  void initState() {
    super.initState();
    pending = widget.current;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Due date'),
    content: SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pending != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatFullDate(pending!.calendar),
                ),
              ),
            for (final preset in [
              ('Today', 0),
              ('Tomorrow', 1),
              ('In a week', 7),
            ])
              TextButton(
                onPressed: () =>
                    setState(() => pending = widget.today.addDays(preset.$2)),
                child: Text(preset.$1),
              ),
            TextButton(
              onPressed: () async {
                final initial = pending ?? widget.today;
                final date = await showDatePicker(
                  context: context,
                  initialDate: initial.calendar,
                  firstDate: DateTime(1),
                  lastDate: DateTime(9999, 12, 31),
                );
                if (date != null && mounted) {
                  setState(() => pending = TaskDate.local(date));
                }
              },
              child: const Text('Pick a date'),
            ),
            if (widget.current != null)
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const TaskDateSelection(null)),
                child: const Text('Clear date'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: pending == null
            ? null
            : () => Navigator.pop(context, TaskDateSelection(pending)),
        child: const Text('Save'),
      ),
    ],
  );
}
