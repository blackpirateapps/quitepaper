import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../domain/note_template.dart';

class TemplateRepository {
  TemplateRepository(this.database);
  final AppDatabase database;

  NoteTemplate _map(NoteTemplateEntity row) => NoteTemplate.fromJson({
    'id': row.id,
    'displayName': row.displayName,
    'content': row.content,
    'storageFormat': row.storageFormat,
    'defaultTags': jsonDecode(row.defaultTagsJson),
    'createdAt': row.createdAt.toUtc().toIso8601String(),
    'updatedAt': row.updatedAt.toUtc().toIso8601String(),
    'schemaVersion': row.schemaVersion,
  });

  Future<List<NoteTemplate>> getUserTemplates() async =>
      (await database.select(database.noteTemplatesTable).get())
          .map(_map)
          .toList();
  Stream<List<NoteTemplate>> watchUserTemplates() => database
      .select(database.noteTemplatesTable)
      .watch()
      .map((rows) => rows.map(_map).toList());
  Future<NoteTemplate?> getUserTemplate(String id) async {
    final row = await (database.select(
      database.noteTemplatesTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  }

  void _userId(String id) {
    if (!Uuid.isValidUUID(fromString: id)) {
      throw const TemplateException('Invalid user template identity.');
    }
  }

  Future<void> insertUserTemplate(NoteTemplate template) async {
    _userId(template.id);
    await database
        .into(database.noteTemplatesTable)
        .insert(
          NoteTemplatesTableCompanion.insert(
            id: template.id,
            displayName: validateTemplateName(template.displayName),
            content: template.content,
            storageFormat: template.storageFormat.name,
            defaultTagsJson: jsonEncode(template.defaultTags),
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
            schemaVersion: Value(template.schemaVersion),
          ),
        );
  }

  Future<void> renameUserTemplate(String id, String name) async {
    _userId(id);
    final count =
        await (database.update(
          database.noteTemplatesTable,
        )..where((t) => t.id.equals(id))).write(
          NoteTemplatesTableCompanion(
            displayName: Value(validateTemplateName(name)),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (count == 0) {
      throw const TemplateException('This template is no longer available.');
    }
  }

  Future<void> deleteUserTemplate(String id) async {
    _userId(id);
    await database.transaction(() async {
      await (database.delete(
        database.templateFavoritesTable,
      )..where((t) => t.templateId.equals(id))).go();
      await (database.delete(
        database.noteTemplatesTable,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  Future<Set<String>> getFavoriteTemplateIds() async =>
      (await database.select(database.templateFavoritesTable).get())
          .map((r) => r.templateId)
          .toSet();
  Stream<Set<String>> watchFavoriteTemplateIds() => database
      .select(database.templateFavoritesTable)
      .watch()
      .map((rows) => rows.map((r) => r.templateId).toSet());
  Future<void> setFavorite(String id, bool favorite) async {
    if (favorite) {
      await database
          .into(database.templateFavoritesTable)
          .insert(
            TemplateFavoritesTableCompanion.insert(templateId: id),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (database.delete(
        database.templateFavoritesTable,
      )..where((t) => t.templateId.equals(id))).go();
    }
  }
}
