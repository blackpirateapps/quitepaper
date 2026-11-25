import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../../notes/data/notes_repository.dart';
import '../../notes/domain/note_model.dart';
import '../data/built_in_templates.dart';
import '../data/template_repository.dart';
import '../domain/note_template.dart';
import 'template_content.dart';

class TemplateService {
  TemplateService({
    required this.repository,
    required this.notes,
    this.onNoteCreated,
  });
  final TemplateRepository repository;
  final NotesRepository notes;
  final FutureOr<void> Function()? onNoteCreated;

  static bool eligible(
    Note note, {
    bool readOnly = false,
    bool locked = false,
  }) =>
      !readOnly &&
      !locked &&
      !note.isTrashed &&
      !note.isPasswordProtected &&
      !note.isJournal;

  Future<NoteTemplate> resolve(String id) async {
    for (final template in builtInTemplates) {
      if (template.id == id) return template;
    }
    final template = await repository.getUserTemplate(id);
    if (template == null) {
      throw const TemplateException('This template is no longer available.');
    }
    return template;
  }

  Future<NoteTemplate> saveNoteAsTemplate({
    required String noteId,
    required String name,
    required Future<void> Function() flush,
    bool readOnly = false,
    bool locked = false,
  }) async {
    final displayName = validateTemplateName(name);
    if (readOnly || locked) {
      throw const TemplateException('This note cannot become a template.');
    }
    await flush();
    final note = await notes.getNoteById(noteId);
    if (note == null ||
        !eligible(note, readOnly: readOnly, locked: locked) ||
        (note.content.trim().isEmpty &&
            note.title.trim().isEmpty &&
            note.tags.isEmpty)) {
      throw const TemplateException('This note cannot become a template.');
    }
    final now = DateTime.now().toUtc();
    final template = NoteTemplate(
      id: const Uuid().v4(),
      displayName: displayName,
      content: note.content,
      storageFormat: detectTemplateFormat(note.content),
      defaultTags: note.tags,
      createdAt: now,
      updatedAt: now,
    );
    await validateTemplateContentAsync(template);
    if (note.title.trim().isEmpty &&
        note.tags.isEmpty &&
        !await compute(templateHasBodyContent, template)) {
      throw const TemplateException(
        'Add a title or content before saving this note as a template.',
      );
    }
    await repository.insertUserTemplate(template);
    return template;
  }

  // UI mutation guards prevent double submission; distinct calls are explicit
  // independent creations, including calls made by different picker sessions.
  Future<Note> instantiate(String id, {String? activeTag}) async {
    final template = await resolve(id);
    await validateTemplateContentAsync(template);
    final content = await compute(instantiateTemplateContent, template);
    final now = DateTime.now().toUtc();
    final note = Note(
      id: const Uuid().v4(),
      title: template.displayName,
      content: content,
      tags: normalizeTemplateTags([...template.defaultTags, ?activeTag]),
      createdAt: now,
      updatedAt: now,
    );
    await notes.saveNote(note, preserveEmptyTags: true);
    unawaited(_notifyNoteCreated());
    return note;
  }

  // A note is already committed. Retry only this ancillary notification, never
  // note creation, and keep refresh/sync failure outside the persistence result.
  Future<void> _notifyNoteCreated() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await onNoteCreated?.call();
        return;
      } catch (error) {
        debugPrint(
          '[Templates] Creation notification failed (${error.runtimeType})',
        );
      }
    }
  }

  Future<void> favorite(String id, bool value) async {
    // Serialize existence check + write with delete, avoiding orphan user favorites.
    await repository.database.transaction(() async {
      await resolve(id);
      await repository.setFavorite(id, value);
    });
  }

  Future<void> rename(String id, String name) =>
      repository.renameUserTemplate(id, name);
  Future<void> delete(String id) => repository.deleteUserTemplate(id);

  Future<String> preview(String id) async {
    final template = await resolve(id);
    await validateTemplateContentAsync(template);
    return compute(templatePreviewMarkdown, template);
  }
}

class TemplateSection {
  const TemplateSection(this.title, this.templates);
  final String title;
  final List<NoteTemplate> templates;
}

List<TemplateSection> templateSections(
  List<NoteTemplate> templates,
  String query,
) {
  final filtered = templates
      .where(
        (t) => t.displayName.toLowerCase().contains(query.trim().toLowerCase()),
      )
      .toList();
  final favorites = filtered.where((t) => t.isFavorite).toList()
    ..sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
  final users = filtered.where((t) => !t.isFavorite && !t.isBuiltIn).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return [
    if (favorites.isNotEmpty) TemplateSection('Favorites', favorites),
    if (users.isNotEmpty) TemplateSection('My Templates', users),
    if (filtered.any((t) => t.isBuiltIn && !t.isFavorite))
      TemplateSection(
        'Built-in Templates',
        filtered.where((t) => t.isBuiltIn && !t.isFavorite).toList(),
      ),
  ];
}

/// A bounded row excerpt, never a full rich-document decode. Previews of the
/// selected document still use the authoritative serializer after validation.
String templateListSnippet(NoteTemplate template) {
  final prefix = template.content.length > 512
      ? template.content.substring(0, 512)
      : template.content;
  var text = prefix;
  if (template.storageFormat == TemplateStorageFormat.richAst) {
    final match = RegExp(
      r'"(?:text|code|markdown)"\s*:\s*"((?:\\.|[^"\\]){1,120})',
    ).firstMatch(prefix);
    if (match == null) return 'Formatted document';
    try {
      text = jsonDecode('"${match.group(1)}"') as String;
    } on FormatException {
      return 'Formatted document';
    }
  }
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
