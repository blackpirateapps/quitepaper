import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';
import '../../../core/markdown/markdown_checklist_helper.dart';
import '../../editor/domain/rich_document.dart';
import '../../editor/domain/task_metadata.dart';
import 'package:markdown/markdown.dart' as md;

export '../../editor/domain/task_metadata.dart';

class TaskOccurrence {
  const TaskOccurrence({
    required this.ordinal,
    required this.start,
    required this.end,
    required this.checkOffset,
    required this.text,
    required this.completed,
    this.heading,
    this.metadata,
    this.blockId,
  });
  final int ordinal;
  final int start;
  final int end;
  final int checkOffset;
  final String text;
  final bool completed;
  final String? heading;
  final TaskMetadata? metadata;
  final String? blockId;
}

class StaleTask implements Exception {
  const StaleTask([
    this.message = 'This task changed. Refresh Tasks and try again.',
  ]);
  final String message;
  @override
  String toString() => message;
}

/// Format-preserving task commands. Reads never write canonical content.
abstract final class TaskDocument {
  static String version(String content) =>
      sha256.convert(utf8.encode(content)).toString();

  static List<TaskOccurrence> extract(String content) {
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final blocks = data['blocks'] as List;
      final result = <TaskOccurrence>[];
      String? heading;
      for (var i = 0; i < blocks.length; i++) {
        final b = blocks[i] as Map<String, dynamic>;
        final text = (b['spans'] as List? ?? [])
            .map((s) => (s as Map)['text'] ?? '')
            .join();
        if (b['type'] == 'heading') heading = text;
        if (b['type'] != 'checklist_item') continue;
        result.add(
          TaskOccurrence(
            ordinal: result.length,
            start: i,
            end: i + 1,
            checkOffset: 0,
            text: text,
            completed: b['isChecked'] == true,
            heading: heading,
            metadata: TaskMetadata.fromJson(b['task']),
            blockId: b['id'] as String?,
          ),
        );
      }
      return result;
    }
    return MarkdownChecklistHelper.occurrences(content).map((item) {
      final parsed = TaskMetadata.parseTerminal(item.text);
      return TaskOccurrence(
        ordinal: item.ordinal,
        start: item.start,
        end: item.end,
        checkOffset: item.checkOffset,
        text: md.Document(extensionSet: md.ExtensionSet.gitHubWeb)
            .parseInline([parsed.text, ...item.continuation].join('\n'))
            .map((n) => n.textContent)
            .join(),
        completed: item.completed,
        heading: item.heading,
        metadata: parsed.metadata,
      );
    }).toList();
  }

  static TaskOccurrence resolve(
    String content, {
    required String expectedVersion,
    required int ordinal,
    String? taskId,
  }) {
    final tasks = extract(content);
    if (taskId != null) {
      final found = tasks.where((t) => t.metadata?.id == taskId).toList();
      if (found.length != 1) throw const StaleTask();
      return found.single;
    }
    if (version(content) != expectedVersion ||
        ordinal < 0 ||
        ordinal >= tasks.length) {
      throw const StaleTask();
    }
    final found = tasks[ordinal];
    if (found.metadata != null &&
        tasks.where((t) => t.metadata?.id == found.metadata!.id).length != 1) {
      throw const StaleTask(
        'Task identity is duplicated. Edit the source to repair it before changing its date.',
      );
    }
    return found;
  }

  static String setCompleted(String content, TaskOccurrence task, bool value) {
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      (data['blocks'] as List)[task.start]['isChecked'] = value;
      return jsonEncode(data);
    }
    return content.replaceRange(
      task.checkOffset,
      task.checkOffset + 1,
      value ? 'x' : ' ',
    );
  }

  static String setDate(
    String content,
    TaskOccurrence task,
    TaskDate? date, {
    String? newId,
  }) {
    final metadata = TaskMetadata(
      id: task.metadata?.id ?? newId ?? const Uuid().v4(),
      due: date,
    );
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final block = (data['blocks'] as List)[task.start] as Map;
      if (block['task'] != null &&
          TaskMetadata.fromJson(block['task']) == null) {
        throw const StaleTask(
          'Unsupported task metadata. Edit in Source mode to repair it.',
        );
      }
      block['task'] = metadata.toJson();
      return jsonEncode(data);
    }
    final line = content.substring(task.start, task.end);
    final parsed = TaskMetadata.parseTerminal(line);
    if (parsed.metadata == null && line.contains('qp-task:')) {
      throw const StaleTask(
        'Unrecognized task metadata. Repair it in Source mode before adding a date.',
      );
    }
    return content.replaceRange(
      task.start,
      task.end,
      '${parsed.text}${metadata.comment}',
    );
  }

  static String append(
    String content,
    String text,
    String captureId,
    TaskDate? date,
  ) {
    if (!TaskMetadata.uuidPattern.hasMatch(captureId)) {
      throw const StaleTask(
        'Invalid capture identity. Reopen New task and try again.',
      );
    }
    if (text.trim().isEmpty || text.contains(RegExp(r'[\r\n\u2028\u2029]'))) {
      throw const StaleTask('Enter one task on a single line.');
    }
    final existing = extract(
      content,
    ).where((t) => t.metadata?.id == captureId).toList();
    if (existing.isNotEmpty) {
      if (existing.length != 1 ||
          existing.single.text != text.trim() ||
          existing.single.completed ||
          existing.single.metadata?.due != date) {
        throw const StaleTask(
          'This capture was already saved and has since changed. Open its destination to inspect it.',
        );
      }
      return content;
    }
    final metadata = TaskMetadata(id: captureId, due: date);
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      (data['blocks'] as List).add({
        'type': 'checklist_item',
        'id': const Uuid().v4(),
        'indent': 0,
        'isChecked': false,
        'spans': [
          {'text': text.trim()},
        ],
        'task': metadata.toJson(),
      });
      return jsonEncode(data);
    }
    // Escape inline syntax, keeping capture a single literal checklist node.
    final literal = text.trim().replaceAllMapped(
      RegExp(r'[\\`*_{}\[\]()<>#+.!|~$=-]'),
      (m) => '\\${m[0]}',
    );
    final nl = content.contains('\r\n') ? '\r\n' : '\n';
    return '$content${content.isEmpty || content.endsWith('\n') ? '' : nl}- [ ] $literal${metadata.comment}';
  }

  static String fingerprint(String content, TaskOccurrence task) {
    if (RichDocument.isJson(content)) {
      final block = (jsonDecode(content)['blocks'] as List)[task.start] as Map;
      return jsonEncode({...block}..remove('id'));
    }
    return content.substring(task.start, task.end);
  }

  static String remove(String content, TaskOccurrence task) {
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      final blocks = data['blocks'] as List;
      if (task.start + 1 < blocks.length &&
          blocks[task.start + 1]['type'] == 'checklist_item' &&
          (blocks[task.start + 1]['indent'] as int? ?? 0) >
              (blocks[task.start]['indent'] as int? ?? 0)) {
        throw const StaleTask(
          'Undo is unavailable because the task has new children.',
        );
      }
      blocks.removeAt(task.start);
      return jsonEncode(data);
    }
    // Refuse to remove a task which acquired continuation content or children.
    final after = content.substring(task.end);
    final next = after.replaceFirst(RegExp(r'^\r?\n'), '').split('\n').first;
    if (next.isNotEmpty && RegExp(r'^[ \t]+\S').hasMatch(next)) {
      throw const StaleTask(
        'Undo is unavailable because the task has new content.',
      );
    }
    final suffix = after.startsWith('\r\n')
        ? 2
        : after.startsWith('\n')
        ? 1
        : 0;
    return content.replaceRange(task.start, task.end + suffix, '');
  }

  static String visibleMarkdown(String content) =>
      MarkdownChecklistHelper.withoutTaskMetadata(content);

  static String rekey(String content, {bool clearDates = false}) {
    if (RichDocument.isJson(content)) {
      final data = jsonDecode(content) as Map<String, dynamic>;
      var changed = false;
      for (final block in data['blocks'] as List) {
        if (block['type'] != 'checklist_item') continue;
        final old = TaskMetadata.fromJson(block['task']);
        if (old == null) continue;
        block['task'] = TaskMetadata(
          id: const Uuid().v4(),
          due: clearDates ? null : old.due,
        ).toJson();
        changed = true;
      }
      return changed ? jsonEncode(data) : content;
    }
    final tasks = extract(content);
    var result = content;
    for (final task in tasks.reversed) {
      if (task.metadata == null) continue;
      final fresh = TaskMetadata(
        id: const Uuid().v4(),
        due: clearDates ? null : task.metadata!.due,
      );
      final line = result.substring(task.start, task.end);
      result = result.replaceRange(
        task.start,
        task.end,
        '${TaskMetadata.parseTerminal(line).text}${fresh.comment}',
      );
    }
    return result;
  }
}
