import 'package:flutter/foundation.dart';

/// Supported resource types for internal Quiet Paper URIs (`qp://<resourceType>/<resourceId>`).
enum QuietPaperResourceType {
  /// Binary image or media attachment (`qp://asset/<UUID>`).
  asset('asset'),

  /// Note entity reference for future note-to-note linking (`qp://note/<UUID>`).
  note('note'),

  /// Fallback / unsupported resource type.
  unknown('unknown');

  const QuietPaperResourceType(this.identifier);
  final String identifier;

  static QuietPaperResourceType fromIdentifier(String identifier) {
    final lower = identifier.toLowerCase().trim();
    for (final type in QuietPaperResourceType.values) {
      if (type.identifier == lower) {
        return type;
      }
    }
    return QuietPaperResourceType.unknown;
  }
}

/// A first-class, immutable representation of an internal Quiet Paper URI.
///
/// Canonical format:
/// ```text
/// qp://asset/550e8400-e29b-41d4-a716-446655440000
/// qp://note/3f4a2100-e29b-41d4-a716-446655440000
/// ```
@immutable
class QuietPaperUri {
  const QuietPaperUri({
    required this.resourceType,
    required this.resourceId,
    this.parameters = const <String, String>{},
  });

  /// Scheme identifier for all Quiet Paper internal resource URIs.
  static const String scheme = 'qp';

  /// Standard UUID v4 / UUID format validation regex (case-insensitive).
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );

  /// The parsed resource type (e.g. `asset` or `note`).
  final QuietPaperResourceType resourceType;

  /// The unique logical identity of the resource (e.g. attachment UUID or note UUID).
  final String resourceId;

  /// Optional query parameters attached to the URI (e.g. variant type).
  final Map<String, String> parameters;

  /// Whether this URI points to an asset/attachment.
  bool get isAsset => resourceType == QuietPaperResourceType.asset;

  /// Whether this URI points to a note.
  bool get isNote => resourceType == QuietPaperResourceType.note;

  /// Whether this URI has a valid known resource type and well-formed resource ID.
  bool get isValid {
    if (resourceType == QuietPaperResourceType.unknown) return false;
    if (resourceId.trim().isEmpty) return false;
    return isValidUuid(resourceId) || resourceId.length >= 8;
  }

  /// Statically checks if a URI string is valid.
  static bool isValidUri(String? uriString) {
    final parsed = tryParse(uriString);
    return parsed != null && parsed.isValid;
  }

  /// Validates whether [id] matches standard UUID formatting.
  static bool isValidUuid(String id) {
    return _uuidRegex.hasMatch(id.trim());
  }

  /// Creates a canonical asset URI (`qp://asset/<assetId>`).
  factory QuietPaperUri.asset(String assetId, {Map<String, String>? parameters}) {
    final cleanId = assetId.trim();
    if (cleanId.isEmpty) {
      throw const FormatException('Asset ID cannot be empty');
    }
    return QuietPaperUri(
      resourceType: QuietPaperResourceType.asset,
      resourceId: cleanId,
      parameters: parameters ?? const <String, String>{},
    );
  }

  /// Creates a canonical note URI (`qp://note/<noteId>`).
  factory QuietPaperUri.note(String noteId, {Map<String, String>? parameters}) {
    final cleanId = noteId.trim();
    if (cleanId.isEmpty) {
      throw const FormatException('Note ID cannot be empty');
    }
    return QuietPaperUri(
      resourceType: QuietPaperResourceType.note,
      resourceId: cleanId,
      parameters: parameters ?? const <String, String>{},
    );
  }

  /// Parses a string into a [QuietPaperUri], throwing a [FormatException] if invalid.
  factory QuietPaperUri.parse(String uriString) {
    final result = tryParse(uriString);
    if (result == null) {
      throw FormatException('Invalid Quiet Paper URI: "$uriString"');
    }
    return result;
  }

  /// Safely attempts to parse a string into a [QuietPaperUri]. Returns `null` if malformed.
  static QuietPaperUri? tryParse(String? uriString) {
    if (uriString == null) return null;
    final trimmed = uriString.trim();
    if (trimmed.isEmpty) return null;

    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('qp://')) {
      return null;
    }

    final withoutScheme = trimmed.substring(5); // Strips "qp://"
    if (withoutScheme.isEmpty) return null;

    final questionMarkIndex = withoutScheme.indexOf('?');
    final pathPart = questionMarkIndex != -1
        ? withoutScheme.substring(0, questionMarkIndex)
        : withoutScheme;
    final queryPart = questionMarkIndex != -1
        ? withoutScheme.substring(questionMarkIndex + 1)
        : '';

    final slashIndex = pathPart.indexOf('/');
    if (slashIndex == -1) {
      return null;
    }

    final typePart = pathPart.substring(0, slashIndex).trim();
    final idPart = pathPart.substring(slashIndex + 1).trim();

    if (typePart.isEmpty || idPart.isEmpty) {
      return null;
    }

    // Disallow extra slashes in resourceId (e.g. qp://asset/123/extra)
    if (idPart.contains('/')) {
      return null;
    }

    if (!isValidUuid(idPart)) {
      return null;
    }

    final resourceType = QuietPaperResourceType.fromIdentifier(typePart);
    if (resourceType == QuietPaperResourceType.unknown) {
      return null;
    }

    final params = <String, String>{};
    if (queryPart.isNotEmpty) {
      final pairs = queryPart.split('&');
      for (final pair in pairs) {
        final equalIndex = pair.indexOf('=');
        if (equalIndex != -1) {
          final key = Uri.decodeQueryComponent(pair.substring(0, equalIndex));
          final value = Uri.decodeQueryComponent(pair.substring(equalIndex + 1));
          params[key] = value;
        } else if (pair.isNotEmpty) {
          params[Uri.decodeQueryComponent(pair)] = '';
        }
      }
    }

    return QuietPaperUri(
      resourceType: resourceType,
      resourceId: idPart,
      parameters: params,
    );
  }

  /// Returns canonical string representation `qp://<resourceType>/<resourceId>`.
  String toUriString() {
    final buffer = StringBuffer('qp://${resourceType.identifier}/$resourceId');
    if (parameters.isNotEmpty) {
      buffer.write('?');
      final entries = parameters.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        if (i > 0) buffer.write('&');
        buffer.write(Uri.encodeQueryComponent(entries[i].key));
        if (entries[i].value.isNotEmpty) {
          buffer.write('=');
          buffer.write(Uri.encodeQueryComponent(entries[i].value));
        }
      }
    }
    return buffer.toString();
  }

  @override
  String toString() => toUriString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuietPaperUri &&
          runtimeType == other.runtimeType &&
          resourceType == other.resourceType &&
          resourceId == other.resourceId &&
          mapEquals(parameters, other.parameters);

  @override
  int get hashCode =>
      resourceType.hashCode ^ resourceId.hashCode ^ parameters.hashCode;
}
