import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:html/parser.dart' as html;
import '../../editor/application/frontmatter_editor_helper.dart';
import '../../editor/application/rich_document_parser.dart';
import '../../editor/application/rich_document_serializer.dart';
import '../../editor/domain/rich_block.dart';
import '../../editor/domain/rich_document.dart';
import '../domain/note_template.dart';

const unsupportedTemplateContent =
    "This note contains attachments or documents that can't be included in templates yet. Make a text-only copy of the note and save that copy as a template.";

TemplateStorageFormat detectTemplateFormat(String content) {
  if (RichDocument.isJson(content)) return TemplateStorageFormat.richAst;
  // A future rich schema must never be mistaken for ordinary Markdown.
  if (content.trimLeft().startsWith('{') && content.contains(r'"$schema"')) {
    throw const TemplateException('Unsupported document serialization.');
  }
  return TemplateStorageFormat.markdown;
}

/// Validates only the selected document, off the UI isolate for large bodies.
Future<void> validateTemplateContentAsync(NoteTemplate template) =>
    compute(validateTemplateContent, template);

void validateTemplateContent(NoteTemplate template) {
  final content = template.content;
  if (content.trimLeft().startsWith('<!-- quiet-paper-encrypted-note-v1:')) {
    throw const TemplateException('Protected notes cannot become templates.');
  }
  if (detectTemplateFormat(content) != template.storageFormat) {
    throw const TemplateException(
      'The document format does not match its content.',
    );
  }
  // Include encoded URIs and metadata, as well as parsed document nodes below.
  final decoded = content.replaceAll(r'\/', '/');
  if (RegExp(
    r'(?:\bqp:(?!/*note(?:/|%2f))|\bfile:/|\bcontent://|\bdata:(?:image|audio|video|application)/)',
    caseSensitive: false,
  ).hasMatch(decoded)) {
    throw const TemplateException(unsupportedTemplateContent);
  }
  try {
    RichDocument document;
    if (template.storageFormat == TemplateStorageFormat.richAst) {
      final raw = jsonDecode(content) as Map<String, dynamic>;
      if (raw[r'$schema'] != RichDocument.schemaId || raw['blocks'] is! List) {
        throw const FormatException('Invalid rich document');
      }
      final blockIds = <String>{};
      for (final block in raw['blocks'] as List) {
        if (block is! Map<String, dynamic> ||
            block['type'] is! String ||
            block['id'] is! String ||
            (block['id'] as String).isEmpty ||
            !blockIds.add(block['id'] as String)) {
          throw const FormatException('Invalid rich block identity');
        }
        if (block['type'] == 'heading' &&
            (block['level'] is! int ||
                (block['level'] as int) < 1 ||
                (block['level'] as int) > 6)) {
          throw const FormatException('Invalid heading level');
        }
      }
      _validateResourceFields(raw);
      document = RichDocument.fromJson(raw);
      // The editor parser is deliberately tolerant. Reject fields/types that it
      // would silently drop, rather than turning a corrupt template into a note.
      if (!_preserves(raw, document.toJson())) {
        throw const FormatException('Unsupported rich document fields');
      }
    } else {
      for (final match in RegExp(
        r'<!--\s*qp-link-preview:\s*(.*?)-->',
        dotAll: true,
      ).allMatches(content)) {
        final metadata =
            jsonDecode(match.group(1)!.trim()) as Map<String, dynamic>;
        if (metadata['img'] != null && metadata['img'] != '') {
          throw const TemplateException(unsupportedTemplateContent);
        }
      }
      document = const RichDocumentParser().parse(content);
      _validateMarkdownResources(content);
    }
    for (final block in document.blocks) {
      if (block is ImageBlock ||
          block is AttachmentBlock ||
          (block is LinkPreviewBlock &&
              (block.thumbnailAssetId?.isNotEmpty ?? false))) {
        throw const TemplateException(unsupportedTemplateContent);
      }
    }
  } on TemplateException {
    rethrow;
  } catch (_) {
    throw const TemplateException(
      'This template contains invalid or unsupported document data.',
    );
  }
}

// Inspect decoded canonical destination fields at every nesting depth, including
// inline attributes, table cells and link-preview metadata. Text/code strings
// are deliberately not treated as resource ownership references.
void _validateResourceFields(dynamic value) {
  if (value is Map) {
    for (final entry in value.entries) {
      if (const {'linkUrl', 'url', 'uri', 'src', 'href'}.contains(entry.key) &&
          entry.value is String &&
          _isPrivateDestination(entry.value as String)) {
        throw const TemplateException(unsupportedTemplateContent);
      }
      if (entry.key == 'markdown' && entry.value is String) {
        _validateMarkdownResources(entry.value as String);
      }
      _validateResourceFields(entry.value);
    }
  } else if (value is List) {
    for (final child in value) {
      _validateResourceFields(child);
    }
  }
}

bool _isPrivateDestination(String destination) {
  var normalized = destination.trim();
  // URI components can themselves contain escaped scheme/path characters.
  for (var i = 0; i < 3; i++) {
    try {
      final decoded = Uri.decodeComponent(normalized);
      if (decoded == normalized) break;
      normalized = decoded;
    } on FormatException {
      break;
    }
  }
  final uri = Uri.tryParse(normalized);
  if (uri == null) return false;
  return switch (uri.scheme.toLowerCase()) {
    'qp' => uri.host.toLowerCase() != 'note',
    'file' || 'content' => true,
    'data' => RegExp(
      r'^data:(image|audio|video|application)/',
      caseSensitive: false,
    ).hasMatch(normalized),
    _ => false,
  };
}

void _validateMarkdownResources(String content) {
  final fragment = html.parseFragment(
    md.markdownToHtml(content, extensionSet: md.ExtensionSet.gitHubFlavored),
  );
  for (final element in fragment.querySelectorAll('*')) {
    if (const {
          'img',
          'audio',
          'video',
          'object',
          'embed',
          'iframe',
        }.contains(element.localName) ||
        element.attributes.entries.any(
          (entry) =>
              const {'href', 'src', 'data', 'poster'}.contains(entry.key) &&
              _isPrivateDestination(entry.value),
        )) {
      throw const TemplateException(unsupportedTemplateContent);
    }
  }
}

bool _preserves(dynamic input, dynamic output) {
  if (input is Map && output is Map) {
    return input.entries.every(
      (e) => output.containsKey(e.key) && _preserves(e.value, output[e.key]),
    );
  }
  if (input is List && output is List) {
    return input.length == output.length &&
        List.generate(
          input.length,
          (i) => i,
        ).every((i) => _preserves(input[i], output[i]));
  }
  return input == output;
}

String templatePreviewMarkdown(NoteTemplate template) =>
    template.storageFormat == TemplateStorageFormat.markdown
    ? template.content
    : const RichDocumentSerializer().serialize(
        RichDocument.fromJson(
          jsonDecode(template.content) as Map<String, dynamic>,
        ),
      );

String instantiateTemplateContent(NoteTemplate template) {
  if (template.storageFormat != TemplateStorageFormat.markdown) {
    return template.content;
  }
  final original = FrontmatterEditorHelper.parse(template.content);
  if (!original.hasFrontmatter || original.getProperty('title') == null) {
    return template.content;
  }
  // JSON's quoted string syntax is valid YAML and safely handles quotes, slashes,
  // boolean-like titles, Unicode and scalar-looking names.
  final updated = FrontmatterEditorHelper.updateTitle(
    documentText: template.content,
    newTitle: template.displayName,
    quoteValue: true,
  );
  final title = FrontmatterEditorHelper.parse(updated).title;
  if (title != template.displayName) {
    throw const TemplateException(
      'The frontmatter title could not be updated safely.',
    );
  }
  return updated;
}

/// Called only for a source with no visible title or organizational metadata.
bool templateHasBodyContent(NoteTemplate template) =>
    template.storageFormat == TemplateStorageFormat.markdown
    ? template.content.trim().isNotEmpty
    : RichDocument.fromJson(
        jsonDecode(template.content) as Map<String, dynamic>,
      ).isNotEmpty;
