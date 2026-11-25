import '../../../core/search/search_tokenizer.dart';
import '../../notes/domain/note_model.dart';
import 'task_document.dart';

enum TaskGroup { overdue, today, upcoming, undated, completed }

class TaskItem {
  TaskItem({
    required this.note,
    required this.version,
    required this.occurrence,
  });
  final Note note;
  final String version;
  final TaskOccurrence occurrence;
  late final String normalizedSearch = SearchTokenizer.tokenize(
    '${occurrence.text} ${note.displayTitle}',
  ).join(' ');
  late final String titleSortKey = note.displayTitle.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => m[0]!.toLowerCase(),
  );
  String get key =>
      '${note.id}:${occurrence.metadata?.id ?? version}:${occurrence.ordinal}';
  TaskGroup group(TaskDate today) {
    if (occurrence.completed) return TaskGroup.completed;
    final date = occurrence.metadata?.due;
    if (date == null) return TaskGroup.undated;
    final delta = date.compareTo(today);
    return delta < 0
        ? TaskGroup.overdue
        : delta == 0
        ? TaskGroup.today
        : TaskGroup.upcoming;
  }
}
