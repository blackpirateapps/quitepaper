import 'package:flutter/foundation.dart';
import '../../notes/domain/note_model.dart';
import '../domain/editor_editing_style.dart';

@immutable
class EditorState {
  const EditorState({
    required this.note,
    this.isDirty = false,
    this.isSaving = false,
    this.lastSavedAt,
    this.isPreviewMode = false,
    this.isReadOnly = false,
    this.isUnlocked = true,
    this.activePassword,
    this.activePasswordHint,
    this.perNoteEditingStyleOverride,
  });

  final Note note;
  final bool isDirty;
  final bool isSaving;
  final DateTime? lastSavedAt;
  final bool isPreviewMode;
  final bool isReadOnly;
  final bool isUnlocked;
  final String? activePassword;
  final String? activePasswordHint;
  final EditorEditingStyle? perNoteEditingStyleOverride;

  /// Returns the effective editing style considering per-note override and global preference.
  EditorEditingStyle effectiveEditingStyle(EditorEditingStyle globalStyle) =>
      perNoteEditingStyleOverride ?? globalStyle;

  EditorState copyWith({
    Note? note,
    bool? isDirty,
    bool? isSaving,
    DateTime? lastSavedAt,
    bool? isPreviewMode,
    bool? isReadOnly,
    bool? isUnlocked,
    String? activePassword,
    bool clearActivePassword = false,
    String? activePasswordHint,
    bool clearActivePasswordHint = false,
    EditorEditingStyle? perNoteEditingStyleOverride,
    bool clearPerNoteEditingStyleOverride = false,
  }) {
    return EditorState(
      note: note ?? this.note,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      isPreviewMode: isPreviewMode ?? this.isPreviewMode,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      activePassword: clearActivePassword
          ? null
          : (activePassword ?? this.activePassword),
      activePasswordHint: clearActivePasswordHint
          ? null
          : (activePasswordHint ?? this.activePasswordHint),
      perNoteEditingStyleOverride: clearPerNoteEditingStyleOverride
          ? null
          : (perNoteEditingStyleOverride ?? this.perNoteEditingStyleOverride),
    );
  }
}

