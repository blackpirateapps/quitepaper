import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'annotation_models.dart';
import 'annotation_service.dart';

/// The active editing tool. [navigate] leaves the `InteractiveViewer` fully in
/// control (today's behavior). [eraser] deletes whole objects; [select] copies
/// underlying OCR text. Every other value maps to an [AnnotationType].
enum AnnotationTool {
  navigate,
  ink,
  highlighter,
  rect,
  ellipse,
  line,
  arrow,
  eraser,
  select,
  textHighlight,
  underline,
  strikethrough,
  squiggly,
  comment,
  redaction;

  bool get isMarkup => this != AnnotationTool.navigate;

  bool get isFreeformDraw =>
      this == ink ||
      this == highlighter ||
      this == rect ||
      this == ellipse ||
      this == line ||
      this == arrow;

  bool get isTextAnchored =>
      this == textHighlight ||
      this == underline ||
      this == strikethrough ||
      this == squiggly;

  /// The annotation type this tool creates, or null for non-creating tools.
  AnnotationType? get annotationType {
    switch (this) {
      case ink:
        return AnnotationType.ink;
      case highlighter:
        return AnnotationType.highlighterFree;
      case rect:
        return AnnotationType.rect;
      case ellipse:
        return AnnotationType.ellipse;
      case line:
        return AnnotationType.line;
      case arrow:
        return AnnotationType.arrow;
      case textHighlight:
        return AnnotationType.textHighlight;
      case underline:
        return AnnotationType.underline;
      case strikethrough:
        return AnnotationType.strikethrough;
      case squiggly:
        return AnnotationType.squiggly;
      case comment:
        return AnnotationType.comment;
      case redaction:
        return AnnotationType.redaction;
      case navigate:
      case eraser:
      case select:
        return null;
    }
  }
}

/// Session-scoped editing state for one document's annotation overlay (spec
/// §4.5/§4.7): active tool/color/width, per-page annotation lists (including
/// tombstones so deletes persist and sync), an undo/redo stack, and debounced
/// encrypted autosave on every committed mutation.
class AnnotationEditingController extends ChangeNotifier {
  AnnotationEditingController({
    required this.documentId,
    required this.service,
  });

  final String documentId;
  final DocumentAnnotationService service;
  static const _uuid = Uuid();

  // --- Tool palette state ---
  AnnotationTool _tool = AnnotationTool.navigate;
  int _colorArgb = 0xFFEF5350; // restrained red default for ink
  double _strokeWidth = 0.004; // fraction of page width
  bool _filled = false;
  bool _snapStraight = false; // ruler assist (0/45/90°)

  AnnotationTool get tool => _tool;
  int get colorArgb => _colorArgb;
  double get strokeWidth => _strokeWidth;
  bool get filled => _filled;
  bool get snapStraight => _snapStraight;
  bool get isMarkupMode => _tool.isMarkup;

  // --- Per-page annotation store (full lists, including tombstones) ---
  final Map<int, List<Annotation>> _pages = {};
  final Set<int> _loaded = {};

  // --- Undo / redo (per-page list snapshots) ---
  final List<_PageSnapshot> _undo = [];
  final List<_PageSnapshot> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  final Map<int, Timer> _saveTimers = {};
  static const _autosaveDelay = Duration(milliseconds: 500);

  void setTool(AnnotationTool t) {
    if (_tool == t) return;
    _tool = t;
    notifyListeners();
  }

  void setColor(int argb) {
    _colorArgb = argb;
    notifyListeners();
  }

  void setStrokeWidth(double w) {
    _strokeWidth = w;
    notifyListeners();
  }

  void setFilled(bool f) {
    _filled = f;
    notifyListeners();
  }

  void setSnapStraight(bool s) {
    _snapStraight = s;
    notifyListeners();
  }

  /// Non-deleted annotations for a page, in paint order.
  List<Annotation> annotationsForPage(int pageIndex) {
    final list = _pages[pageIndex];
    if (list == null) return const [];
    final live = list.where((a) => !a.deleted).toList()
      ..sort((a, b) => a.z != b.z
          ? a.z.compareTo(b.z)
          : a.createdAtMs.compareTo(b.createdAtMs));
    return live;
  }

  bool isPageLoaded(int pageIndex) => _loaded.contains(pageIndex);

  /// Lazily decrypt + load a page's annotations once.
  Future<void> ensurePageLoaded(int pageIndex) async {
    if (_loaded.contains(pageIndex)) return;
    final loaded = await service.loadPage(documentId, pageIndex);
    _loaded.add(pageIndex);
    _pages[pageIndex] = List<Annotation>.from(loaded);
    notifyListeners();
  }

  int _nextZ(int pageIndex) {
    final list = _pages[pageIndex];
    if (list == null || list.isEmpty) return 0;
    return list.map((a) => a.z).fold<int>(-1, (m, z) => z > m ? z : m) + 1;
  }

  /// Build (but do not commit) a new annotation of the current tool's type.
  Annotation buildAnnotation({
    required int pageIndex,
    required AnnotationType type,
    required AnnotationGeometry geometry,
    AnnotationStyle? style,
    String? text,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Annotation(
      id: _uuid.v4(),
      documentId: documentId,
      pageIndex: pageIndex,
      type: type,
      geometry: geometry,
      style: style ??
          AnnotationStyle(
            colorArgb: _colorArgb,
            strokeWidth: _strokeWidth,
            opacity: type == AnnotationType.highlighterFree ||
                    type == AnnotationType.textHighlight
                ? 0.35
                : 1.0,
            filled: _filled,
          ),
      text: text,
      createdAtMs: now,
      updatedAtMs: now,
      z: _nextZ(pageIndex),
    );
  }

  void _snapshot(int pageIndex) {
    _undo.add(_PageSnapshot(
      pageIndex,
      List<Annotation>.from(_pages[pageIndex] ?? const []),
    ));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  /// Commit a freshly built annotation.
  void addAnnotation(Annotation annotation) {
    final pageIndex = annotation.pageIndex;
    _snapshot(pageIndex);
    final list = _pages.putIfAbsent(pageIndex, () => <Annotation>[]);
    list.add(annotation);
    _scheduleSave(pageIndex);
    notifyListeners();
  }

  /// Replace an existing annotation (edit comment text, move, restyle).
  void updateAnnotation(Annotation updated) {
    final pageIndex = updated.pageIndex;
    final list = _pages[pageIndex];
    if (list == null) return;
    final idx = list.indexWhere((a) => a.id == updated.id);
    if (idx < 0) return;
    _snapshot(pageIndex);
    list[idx] = updated.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _scheduleSave(pageIndex);
    notifyListeners();
  }

  /// Soft-delete (tombstone) an annotation so the delete persists and syncs.
  void deleteAnnotation(int pageIndex, String id) {
    final list = _pages[pageIndex];
    if (list == null) return;
    final idx = list.indexWhere((a) => a.id == id);
    if (idx < 0) return;
    _snapshot(pageIndex);
    list[idx] = list[idx].copyWith(
      deleted: true,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _scheduleSave(pageIndex);
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    final snap = _undo.removeLast();
    _redo.add(_PageSnapshot(
      snap.pageIndex,
      List<Annotation>.from(_pages[snap.pageIndex] ?? const []),
    ));
    _pages[snap.pageIndex] = List<Annotation>.from(snap.annotations);
    _scheduleSave(snap.pageIndex);
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final snap = _redo.removeLast();
    _undo.add(_PageSnapshot(
      snap.pageIndex,
      List<Annotation>.from(_pages[snap.pageIndex] ?? const []),
    ));
    _pages[snap.pageIndex] = List<Annotation>.from(snap.annotations);
    _scheduleSave(snap.pageIndex);
    notifyListeners();
  }

  void _scheduleSave(int pageIndex) {
    _saveTimers[pageIndex]?.cancel();
    _saveTimers[pageIndex] = Timer(_autosaveDelay, () {
      _saveTimers.remove(pageIndex);
      final list = _pages[pageIndex];
      if (list == null) return;
      // Fire and forget; errors are swallowed inside the service.
      unawaited(service.savePage(
        documentId: documentId,
        pageIndex: pageIndex,
        annotations: List<Annotation>.from(list),
      ));
    });
  }

  /// Flush any pending debounced saves immediately (on screen dispose/export).
  Future<void> flushPendingSaves() async {
    final pending = _saveTimers.keys.toList();
    for (final pageIndex in pending) {
      _saveTimers[pageIndex]?.cancel();
      _saveTimers.remove(pageIndex);
      final list = _pages[pageIndex];
      if (list == null) continue;
      await service.savePage(
        documentId: documentId,
        pageIndex: pageIndex,
        annotations: List<Annotation>.from(list),
      );
    }
  }

  /// Drop all in-memory page state (after an external bulk change such as
  /// "delete all"), forcing a fresh decrypt from storage on next access.
  void invalidateCache() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    _saveTimers.clear();
    _pages.clear();
    _loaded.clear();
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final t in _saveTimers.values) {
      t.cancel();
    }
    _saveTimers.clear();
    super.dispose();
  }
}

class _PageSnapshot {
  _PageSnapshot(this.pageIndex, this.annotations);
  final int pageIndex;
  final List<Annotation> annotations;
}
