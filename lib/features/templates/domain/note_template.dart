import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import '../../../core/utils/tag_parser.dart';

/// Matches the two canonical representations accepted by Note persistence.
enum TemplateStorageFormat { markdown, richAst }

class TemplateException implements Exception {
  const TemplateException(this.message);
  final String message;
  @override
  String toString() => message;
}

String? templateNameError(String name) {
  if (RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]').hasMatch(name)) {
    return 'Use a single line without control characters.';
  }
  if (name.trim().isEmpty) return 'Enter a template name.';
  if (name.trim().characters.length > 80) return 'Use 80 characters or fewer.';
  return null;
}

String validateTemplateName(String name) {
  final error = templateNameError(name);
  if (error != null) throw TemplateException(error);
  return name.trim();
}

List<String> normalizeTemplateTags(Iterable<String> tags) => List.unmodifiable(
  tags.map(TagParser.normalizeTag).where(TagParser.isValidTag).toSet(),
);

@immutable
class NoteTemplate {
  NoteTemplate({
    required this.id,
    required String displayName,
    required this.content,
    required this.storageFormat,
    required DateTime createdAt,
    required DateTime updatedAt,
    List<String> defaultTags = const [],
    this.schemaVersion = 1,
    this.isFavorite = false,
  }) : displayName = validateTemplateName(displayName),
       defaultTags = normalizeTemplateTags(defaultTags),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    if (schemaVersion != 1 || id.isEmpty) {
      throw const TemplateException('Unsupported template metadata.');
    }
  }

  final String id;
  final String displayName;
  final String content;
  final TemplateStorageFormat storageFormat;
  final List<String> defaultTags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final bool isFavorite;
  bool get isBuiltIn => id.startsWith('builtin.');

  NoteTemplate withFavorite(bool favorite) => NoteTemplate(
    id: id,
    displayName: displayName,
    content: content,
    storageFormat: storageFormat,
    defaultTags: defaultTags,
    createdAt: createdAt,
    updatedAt: updatedAt,
    schemaVersion: schemaVersion,
    isFavorite: favorite,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'content': content,
    'storageFormat': storageFormat.name,
    'defaultTags': defaultTags,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'schemaVersion': schemaVersion,
  };

  factory NoteTemplate.fromJson(Map<String, dynamic> json) {
    final tags = json['defaultTags'];
    if (tags is! List || tags.any((t) => t is! String)) {
      throw const TemplateException('Invalid template tags.');
    }
    final format = TemplateStorageFormat.values
        .where((v) => v.name == json['storageFormat'])
        .firstOrNull;
    if (format == null) {
      throw const TemplateException('Unsupported template format.');
    }
    return NoteTemplate(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      content: json['content'] as String,
      storageFormat: format,
      defaultTags: tags.cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      schemaVersion: json['schemaVersion'] as int,
    );
  }
}
