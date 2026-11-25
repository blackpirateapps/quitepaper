import 'dart:convert';
import '../../editor/domain/rich_document.dart';
import 'task_document.dart';

/// Small extension at the existing diff3 boundary. Ambiguity returns null so the
/// existing recoverable conflict path retains both versions.
abstract final class TaskContentMerge {
  static ({bool ok, dynamic value}) _field(
    dynamic base,
    dynamic local,
    dynamic remote,
  ) {
    final b = jsonEncode(base), l = jsonEncode(local), r = jsonEncode(remote);
    if (l == r || b == r) return (ok: true, value: local);
    if (b == l) return (ok: true, value: remote);
    return (ok: false, value: null);
  }

  static String? line(String base, String local, String remote) {
    final b = TaskDocument.extract(base),
        l = TaskDocument.extract(local),
        r = TaskDocument.extract(remote);
    if (b.length != 1 || l.length != 1 || r.length != 1) return null;
    final bm = b.single.metadata,
        lm = l.single.metadata,
        rm = r.single.metadata;
    if (bm == null ||
        lm == null ||
        rm == null ||
        bm.id != lm.id ||
        bm.id != rm.id) {
      return null;
    }
    final bp = TaskMetadata.parseTerminal(base).text;
    final lp = TaskMetadata.parseTerminal(local).text;
    final rp = TaskMetadata.parseTerminal(remote).text;
    final state = _field(
      b.single.completed,
      l.single.completed,
      r.single.completed,
    );
    final date = _field(
      bm.due?.toString(),
      lm.due?.toString(),
      rm.due?.toString(),
    );
    String withoutCheck(String text, TaskOccurrence t) =>
        text.replaceRange(t.checkOffset, t.checkOffset + 1, ' ');
    final text = _field(
      withoutCheck(bp, b.single),
      withoutCheck(lp, l.single),
      withoutCheck(rp, r.single),
    );
    if (!state.ok || !date.ok || !text.ok) return null;
    final source = text.value as String;
    final target = TaskDocument.extract(source).single;
    return '${TaskDocument.setCompleted(source, target, state.value as bool)}${TaskMetadata(id: bm.id, due: TaskDate.tryParse(date.value as String?)).comment}';
  }

  static String? rich(String base, String local, String remote) {
    if (!RichDocument.isJson(base) ||
        !RichDocument.isJson(local) ||
        !RichDocument.isJson(remote)) {
      return null;
    }
    try {
      final b = jsonDecode(base) as Map<String, dynamic>;
      final l = jsonDecode(local) as Map<String, dynamic>;
      final r = jsonDecode(remote) as Map<String, dynamic>;
      final bs = b['blocks'] as List,
          ls = l['blocks'] as List,
          rs = r['blocks'] as List;
      if (bs.length != ls.length || bs.length != rs.length) return null;
      final counts = <Map<String, int>>[];
      for (final content in [base, local, remote]) {
        final map = <String, int>{};
        for (final task in TaskDocument.extract(content)) {
          final id = task.metadata?.id;
          if (id != null) map[id] = (map[id] ?? 0) + 1;
        }
        counts.add(map);
      }
      final merged = <dynamic>[];
      for (var i = 0; i < bs.length; i++) {
        final direct = _field(bs[i], ls[i], rs[i]);
        if (direct.ok) {
          merged.add(direct.value);
          continue;
        }
        final bb = bs[i] as Map<String, dynamic>,
            lb = ls[i] as Map<String, dynamic>,
            rb = rs[i] as Map<String, dynamic>;
        if (bb['type'] != 'checklist_item' ||
            lb['type'] != 'checklist_item' ||
            rb['type'] != 'checklist_item') {
          return null;
        }
        final bm = TaskMetadata.fromJson(bb['task']),
            lm = TaskMetadata.fromJson(lb['task']),
            rm = TaskMetadata.fromJson(rb['task']);
        if (bm == null ||
            lm == null ||
            rm == null ||
            bm.id != lm.id ||
            bm.id != rm.id) {
          return null;
        }
        if (counts.any((map) => map[bm.id] != 1)) return null;
        final out = <String, dynamic>{};
        for (final key in {...bb.keys, ...lb.keys, ...rb.keys}) {
          if (key == 'task') {
            final date = _field(
              bm.due?.toString(),
              lm.due?.toString(),
              rm.due?.toString(),
            );
            if (!date.ok) return null;
            out[key] = TaskMetadata(
              id: bm.id,
              due: TaskDate.tryParse(date.value as String?),
            ).toJson();
          } else {
            final field = _field(bb[key], lb[key], rb[key]);
            if (!field.ok) return null;
            if (field.value != null) out[key] = field.value;
          }
        }
        merged.add(out);
      }
      final result = <String, dynamic>{};
      for (final key in {...b.keys, ...l.keys, ...r.keys}) {
        if (key == 'blocks') {
          result[key] = merged;
          continue;
        }
        final field = _field(b[key], l[key], r[key]);
        if (!field.ok) return null;
        result[key] = field.value;
      }
      return jsonEncode(result);
    } catch (_) {
      return null;
    }
  }
}
