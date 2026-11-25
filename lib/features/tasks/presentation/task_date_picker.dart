import 'package:flutter/material.dart';
import '../domain/task_document.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../tags/domain/phosphor_icons.dart';

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
  String? taskTitle,
}) {
  if (MediaQuery.sizeOf(context).width < 600) {
    return showModalBottomSheet<TaskDateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _DateSheet(today: today, current: current, taskTitle: taskTitle),
    );
  }
  return showDialog<TaskDateSelection>(
    context: context,
    builder: (context) => _DatePicker(today: today, current: current),
  );
}

class _DateSheet extends StatelessWidget {
  const _DateSheet({required this.today, this.current, this.taskTitle});
  final TaskDate today;
  final TaskDate? current;
  final String? taskTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    void select(TaskDate? date) =>
        Navigator.pop(context, TaskDateSelection(date));
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textTertiary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Due date',
              style: context.appTypography.title.copyWith(
                fontFamily: 'serif',
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            if (taskTitle != null)
              Text(
                taskTitle!,
                style: context.appTypography.bodySmall.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            const SizedBox(height: 8),
            for (final preset in [
              ('Today', 0),
              ('Tomorrow', 1),
              ('In a week', 7),
            ])
              TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.textPrimary,
                  textStyle: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.merge(context.appTypography.body),
                  minimumSize: const Size(48, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => select(today.addDays(preset.$2)),
                child: Text(preset.$1),
              ),
            Divider(height: 1, color: colors.divider),
            TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: colors.textSecondary,
                minimumSize: const Size(48, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: (current ?? today).calendar,
                  firstDate: DateTime(1),
                  lastDate: DateTime(9999, 12, 31),
                );
                if (date != null && context.mounted) {
                  select(TaskDate.local(date));
                }
              },
              child: Row(
                children: [
                  const Icon(PhosphorIconsRegular.calendarBlank, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Pick a date',
                      style: context.appTypography.body.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(PhosphorIconsRegular.arrowRight, size: 20),
                ],
              ),
            ),
            if (current != null)
              TextButton(
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  foregroundColor: colors.accent,
                ),
                onPressed: () => select(null),
                child: const Text('Clear date'),
              ),
          ],
        ),
      ),
    );
  }
}

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
