import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/tag_parser.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import 'editor_state.dart';

@immutable
class EditorParams {
  const EditorParams(this.note, {this.initialPreviewMode = false});
  final Note note;
  final bool initialPreviewMode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorParams &&
          runtimeType == other.runtimeType &&
          note.id == other.note.id;

  @override
  int get hashCode => note.id.hashCode;
}

class EditorNotifier extends StateNotifier<EditorState> {
  EditorNotifier({
    required Note initialNote,
    required this.repository,
    bool initialPreviewMode = false,
  })  : _debouncer = Debouncer(duration: const Duration(milliseconds: 700)),
        super(EditorState(note: initialNote, isPreviewMode: initialPreviewMode));

  final NotesRepository repository;
  final Debouncer _debouncer;

  void updateTitle(String newTitle) {
    if (newTitle == state.note.title) return;

    final updated = state.note.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(note: updated, isDirty: true);
    _debouncedSave();
  }

  void updateContent(String newContent) {
    if (newContent == state.note.content) return;

    final updated = state.note.copyWith(
      content: newContent,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(note: updated, isDirty: true);
    _debouncedSave();
  }

  void addTag(String tag) {
    final normalized = TagParser.normalizeTag(tag);
    if (!TagParser.isValidTag(normalized)) return;
    if (state.note.tags.contains(normalized)) return;

    final updatedTags = [...state.note.tags, normalized];
    final updated = state.note.copyWith(
      tags: updatedTags,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void removeTag(String tag) {
    final normalized = TagParser.normalizeTag(tag);
    final updatedTags = state.note.tags.where((t) => t != normalized).toList();
    final updated = state.note.copyWith(
      tags: updatedTags,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void togglePinned() {
    final updated = state.note.copyWith(
      isPinned: !state.note.isPinned,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void togglePreviewMode() {
    state = state.copyWith(isPreviewMode: !state.isPreviewMode);
  }

  void _debouncedSave() {
    _debouncer.run(saveNow);
  }

  Future<void> saveNow() async {
    if (!mounted) return;

    // If completely empty, skip save
    if (state.note.title.trim().isEmpty &&
        state.note.content.trim().isEmpty &&
        state.note.tags.isEmpty) {
      return;
    }

    // If title is empty, derive title from content
    var titleToSave = state.note.title.trim();
    if (titleToSave.isEmpty) {
      titleToSave = Note.deriveTitle(state.note.content);
    }

    // Extract tags during debounced save and merge with explicit tags
    final extractedTags =
        TagParser.extractTags('$titleToSave\n${state.note.content}');
    final combinedTags = {...state.note.tags, ...extractedTags}.toList();
    final noteToSave = state.note.copyWith(
      title: titleToSave,
      tags: combinedTags,
    );

    state = state.copyWith(note: noteToSave, isSaving: true);

    try {
      await repository.saveNote(noteToSave);
      if (mounted) {
        state = state.copyWith(
          isDirty: false,
          isSaving: false,
          lastSavedAt: DateTime.now(),
        );
      }
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isSaving: false);
      }
    }
  }

  /// Cleans up note if empty upon exit
  Future<void> handleExitCleanup() async {
    _debouncer.cancel();
    if (state.note.title.trim().isEmpty &&
        state.note.content.trim().isEmpty &&
        state.note.tags.isEmpty) {
      await repository.deletePermanently(state.note.id);
    } else {
      await saveNow();
    }
  }

  Future<void> archiveNote() async {
    _debouncer.cancel();
    await saveNow();
    await repository.archiveNote(state.note.id);
    if (mounted) {
      state = state.copyWith(
        note: state.note.copyWith(
          isArchived: true,
          isTrashed: false,
          isPinned: false,
          deletedAt: null,
        ),
      );
    }
  }

  Future<void> unarchiveNote() async {
    _debouncer.cancel();
    await saveNow();
    await repository.unarchiveNote(state.note.id);
    if (mounted) {
      state = state.copyWith(
        note: state.note.copyWith(
          isArchived: false,
          isTrashed: false,
          deletedAt: null,
        ),
      );
    }
  }

  Future<void> trashNote() async {
    _debouncer.cancel();
    await saveNow();
    await repository.trashNote(state.note.id);
    if (mounted) {
      state = state.copyWith(
        note: state.note.copyWith(
          isTrashed: true,
          isArchived: false,
          deletedAt: DateTime.now(),
        ),
      );
    }
  }

  Future<void> restoreNote() async {
    _debouncer.cancel();
    await repository.restoreFromTrash(state.note.id);
    if (mounted) {
      state = state.copyWith(
        note: state.note.copyWith(
          isTrashed: false,
          isArchived: false,
          deletedAt: null,
        ),
      );
    }
  }

  Future<void> deletePermanently() async {
    _debouncer.cancel();
    await repository.deletePermanently(state.note.id);
  }

  Future<void> deleteNote() async {
    await trashNote();
  }

  @override
  void dispose() {
    // Flush any pending save before destroying editor notifier
    if (state.isDirty &&
        (state.note.title.trim().isNotEmpty ||
            state.note.content.trim().isNotEmpty)) {
      repository.saveNote(state.note);
    }
    _debouncer.dispose();
    super.dispose();
  }
}

final editorProviderFamily =
    StateNotifierProvider.family.autoDispose<EditorNotifier, EditorState, EditorParams>(
  (ref, params) {
    final repository = ref.watch(notesRepositoryProvider);
    return EditorNotifier(
      initialNote: params.note,
      repository: repository,
      initialPreviewMode: params.initialPreviewMode,
    );
  },
);
