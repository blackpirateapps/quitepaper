/// A calendar value, never an instant. Arithmetic uses calendar constructors.
class TaskDate implements Comparable<TaskDate> {
  const TaskDate._(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;

  static TaskDate? tryParse(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final y = int.parse(value.substring(0, 4));
    final m = int.parse(value.substring(5, 7));
    final d = int.parse(value.substring(8, 10));
    final date = DateTime(y, m, d);
    if (y < 1 || date.year != y || date.month != m || date.day != d) {
      return null;
    }
    return TaskDate._(y, m, d);
  }

  factory TaskDate.local(DateTime value) =>
      TaskDate._(value.year, value.month, value.day);
  DateTime get calendar => DateTime(year, month, day);
  TaskDate addDays(int days) =>
      TaskDate.local(DateTime(year, month, day + days));
  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  @override
  int compareTo(TaskDate other) {
    final y=year.compareTo(other.year);
    if(y!=0) return y;
    final m=month.compareTo(other.month);
    return m!=0 ? m : day.compareTo(other.day);
  }
  @override
  bool operator ==(Object other) =>
      other is TaskDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;
  @override
  int get hashCode => Object.hash(year, month, day);
}

/// Versioned metadata on the actual checklist item, independent of editor IDs.
class TaskMetadata {
  const TaskMetadata({required this.id, this.due});
  final String id;
  final TaskDate? due;
  static final uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  static final _comment = RegExp(
    r' <!-- qp-task:v1 id=([0-9a-fA-F-]+)(?: due=(\d{4}-\d{2}-\d{2}))? -->$',
  );

  static TaskMetadata? fromJson(dynamic value) {
    if (value is! Map ||
        value['v'] != 1 ||
        value['id'] is! String ||
        !uuidPattern.hasMatch(value['id'] as String) ||
        value.keys.any((k) => !['v', 'id', 'due'].contains(k))) {
      return null;
    }
    final due = value['due'];
    if (due != null && (due is! String || TaskDate.tryParse(due) == null)) {
      return null;
    }
    return TaskMetadata(
      id: (value['id'] as String).toLowerCase(),
      due: TaskDate.tryParse(due as String?),
    );
  }

  /// Call only on the first physical line of a structurally recognized task.
  /// Inline code, escaped '<', and other comments cannot bind metadata.
  static ({String text, TaskMetadata? metadata}) parseTerminal(String text) {
    final match = _comment.firstMatch(text);
    if (match == null) return (text: text, metadata: null);
    final prefix = text.substring(0, match.start);
    if (!uuidPattern.hasMatch(match[1]!) ||
        (match[2] != null && TaskDate.tryParse(match[2]) == null)) {
      return (text: text, metadata: null);
    }
    // Conservative inline-code recognition: a terminal marker inside any open
    // backtick run is literal. Runs must close at their original width.
    int? open;
    for (final run in RegExp(r'(?<!\\)`+').allMatches(prefix)) {
      if (open == null) {
        open = run[0]!.length;
      } else if (open == run[0]!.length) {
        open = null;
      }
    }
    if (open != null || prefix.contains('<!--') || prefix.endsWith('\\')) {
      return (text: text, metadata: null);
    }
    return (
      text: prefix,
      metadata: TaskMetadata(
        id: match[1]!.toLowerCase(),
        due: TaskDate.tryParse(match[2]),
      ),
    );
  }

  Map<String, Object> toJson() => {
    'v': 1,
    'id': id,
    if (due != null) 'due': due.toString(),
  };
  String get comment =>
      ' <!-- qp-task:v1 id=$id${due == null ? '' : ' due=$due'} -->';
  @override
  bool operator ==(Object other) =>
      other is TaskMetadata && id == other.id && due == other.due;
  @override
  int get hashCode => Object.hash(id, due);
}
