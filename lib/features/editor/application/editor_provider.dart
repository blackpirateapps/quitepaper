import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/tag_parser.dart';
import '../../notes/application/note_security_service.dart';
import '../../notes/application/notes_provider.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../domain/editor_editing_style.dart';
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
  }) : _debouncer = Debouncer(duration: const Duration(milliseconds: 700)),
       super(
         EditorState(
           note: initialNote,
           isPreviewMode: initialPreviewMode,
           isUnlocked: !initialNote.isPasswordProtected,
           activePasswordHint: NoteSecurityService.getHint(initialNote.content),
         ),
       );

  final NotesRepository repository;
  final Debouncer _debouncer;
  int _saveRevision = 0;

  void toggleReadOnly() {
    state = state.copyWith(isReadOnly: !state.isReadOnly);
  }

  void setReadOnly(bool readOnly) {
    state = state.copyWith(isReadOnly: readOnly);
  }

  void setPerNoteEditingStyle(EditorEditingStyle? style) {
    state = state.copyWith(
      perNoteEditingStyleOverride: style,
      clearPerNoteEditingStyleOverride: style == null,
    );
  }

  void togglePerNoteEditingStyle(EditorEditingStyle currentGlobalStyle) {
    final effective = state.effectiveEditingStyle(currentGlobalStyle);
    final next = switch (effective) {
      EditorEditingStyle.superEditor => EditorEditingStyle.markdown,
      EditorEditingStyle.markdown => EditorEditingStyle.wysiwyg,
      EditorEditingStyle.wysiwyg => EditorEditingStyle.superEditor,
    };
    setPerNoteEditingStyle(next);
  }

  Future<bool> unlockWithPassword(String password) async {
    try {
      final decrypted = await NoteSecurityService.decryptNote(
        encryptedContent: state.note.content,
        password: password,
      );
      final finalTitle = state.note.title.isNotEmpty
          ? state.note.title
          : decrypted.title;
      state = state.copyWith(
        note: state.note.copyWith(
          title: finalTitle,
          content: decrypted.content,
          tags: decrypted.tags,
        ),
        isUnlocked: true,
        activePassword: password,
        activePasswordHint: decrypted.hint,
        isDirty: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPasswordProtection({
    required String password,
    String? hint,
  }) async {
    _saveRevision++;
    state = state.copyWith(
      activePassword: password,
      activePasswordHint: hint,
      clearActivePasswordHint: hint == null,
      isUnlocked: true,
      isDirty: true,
    );
    await flushForTemplate();
  }

  Future<void> removePasswordProtection() async {
    _saveRevision++;
    state = state.copyWith(
      clearActivePassword: true,
      clearActivePasswordHint: true,
      isUnlocked: true,
      isDirty: true,
    );
    await flushForTemplate();
  }

  Future<void> lockNow() async {
    if (state.activePassword != null || state.note.isPasswordProtected) {
      await flushForTemplate();
      state = state.copyWith(isUnlocked: false, clearActivePassword: true);
    }
  }

  void updateTitle(String newTitle) {
    if (newTitle == state.note.title) return;

    final updated = state.note.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    _saveRevision++;
    state = state.copyWith(note: updated, isDirty: true);
    _debouncedSave();
  }

  void updateContent(String newContent) {
    if (newContent == state.note.content) return;

    final updated = state.note.copyWith(
      content: newContent,
      updatedAt: DateTime.now(),
    );
    _saveRevision++;
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
    _saveRevision++;
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void removeTag(String tag) {
    final normalized = TagParser.normalizeTag(tag);
    final updatedTags = state.note.tags.where((t) => t != normalized).toList();
    final newTitle = TagParser.removeTagFromText(state.note.title, normalized);
    final newContent = TagParser.removeTagFromText(
      state.note.content,
      normalized,
    );
    final updated = state.note.copyWith(
      title: newTitle,
      content: newContent,
      tags: updatedTags,
      updatedAt: DateTime.now(),
    );
    _saveRevision++;
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void setTags(List<String> tags) {
    final normalized = tags
        .map(TagParser.normalizeTag)
        .where(TagParser.isValidTag)
        .toSet()
        .toList();
    final updated = state.note.copyWith(
      tags: normalized,
      updatedAt: DateTime.now(),
    );
    _saveRevision++;
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void togglePinned() {
    final updated = state.note.copyWith(
      isPinned: !state.note.isPinned,
      updatedAt: DateTime.now(),
    );
    _saveRevision++;
    state = state.copyWith(note: updated, isDirty: true);
    saveNow();
  }

  void togglePreviewMode() {
    state = state.copyWith(isPreviewMode: !state.isPreviewMode);
  }

  void _debouncedSave() {
    _debouncer.run(saveNow);
  }

  Future<void>? _pendingSave;

  Future<void> saveNow() {
    return _pendingSave ??= _drainSaves().whenComplete(() {
      _pendingSave = null;
    });
  }

  /// Await local persistence, including edits made while an earlier save ran.
  /// Existing autosave presents failures through dirty state; snapshots must
  /// fail explicitly rather than read a stale persisted body.
  Future<void> flushForTemplate() async {
    _debouncer.cancel();
    await saveNow();
    if (mounted && state.isDirty) await saveNow();
    if (!mounted || state.isDirty || state.isSaving) {
      throw StateError('The note could not be saved before taking a snapshot.');
    }
  }

  Future<void> _drainSaves() async {
    while (mounted && state.isDirty) {
      if (!await _saveNow()) break;
    }
  }

  Future<bool> _saveNow() async {
    if (!mounted || !state.isDirty) return false;

    // If note is currently locked, do not overwrite ciphertext with empty/unlocked buffer
    if (!state.isUnlocked && state.note.isPasswordProtected) {
      return false;
    }

    // If completely empty and not password protected, skip save
    if (state.activePassword == null &&
        state.note.title.trim().isEmpty &&
        state.note.content.trim().isEmpty &&
        state.note.tags.isEmpty) {
      return false;
    }

    // If title is empty, derive title from content
    var titleToSave = state.note.title.trim();
    if (titleToSave.isEmpty) {
      titleToSave = Note.deriveTitle(state.note.content);
    }

    // Extract tags during debounced save and merge with explicit tags
    final textForTags = state.note.isRichText
        ? state.note.plainText
        : state.note.content;
    final extractedTags = TagParser.extractTags(
      '$titleToSave\n$textForTags',
      requireTerminator: true,
    );
    final combinedTags = {...state.note.tags, ...extractedTags}.toList();
    final noteToSave = state.note.copyWith(
      title: titleToSave,
      tags: combinedTags,
    );

    final revision = _saveRevision;
    final password = state.activePassword;
    final hint = state.activePasswordHint;
    state = state.copyWith(note: noteToSave, isSaving: true);

    try {
      if (password != null) {
        final encryptedPayload = await NoteSecurityService.encryptNote(
          title: titleToSave,
          content: noteToSave.content,
          tags: combinedTags,
          password: password,
          hint: hint,
        );

        final encryptedNoteInDb = noteToSave.copyWith(
          title: titleToSave,
          content: encryptedPayload,
        );
        await repository.saveNote(encryptedNoteInDb, preserveEmptyTags: true);
      } else {
        await repository.saveNote(noteToSave, preserveEmptyTags: true);
      }

      if (mounted) {
        state = state.copyWith(
          isDirty: _saveRevision != revision,
          isSaving: false,
          lastSavedAt: DateTime.now(),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        state = state.copyWith(isSaving: false);
      }
      return false;
    }
  }

  /// Cleans up note if empty upon exit
  Future<void> handleExitCleanup() async {
    _debouncer.cancel();
    if (state.activePassword == null &&
        state.note.title.trim().isEmpty &&
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
        note: state.note.copyWith(isTrashed: false, deletedAt: null),
      );
    }
  }

  Future<void> deletePermanently() async {
    _debouncer.cancel();
    await repository.deletePermanently(state.note.id);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    super.dispose();
  }
}

final editorProviderFamily = StateNotifierProvider.autoDispose
    .family<EditorNotifier, EditorState, EditorParams>((ref, params) {
      final repository = ref.watch(notesRepositoryProvider);
      return EditorNotifier(
        initialNote: params.note,
        repository: repository,
        initialPreviewMode: params.initialPreviewMode,
      );
    });
