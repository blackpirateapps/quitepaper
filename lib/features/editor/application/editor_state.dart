import 'package:flutter/foundation.dart';
import '../../notes/domain/note_model.dart';

@immutable
class EditorState {
  const EditorState({
    required this.note,
    this.isDirty = false,
    this.isSaving = false,
    this.lastSavedAt,
    this.isPreviewMode = false,
  });

  final Note note;
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSavedAt;
  final bool isPreviewMode;

  EditorState copyWith({
    Note? note,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSavedAt,
    bool? isPreviewMode,
  }) {
    return EditorState(
      note: note ?? this.note,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      isPreviewMode: isPreviewMode ?? this.isPreviewMode,
    );
  }
}
