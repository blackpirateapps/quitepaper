import 'package:flutter/foundation.dart';

/// Representation of a programming, markup, or configuration language.
@immutable
class SyntaxLanguage {
  const SyntaxLanguage({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.extensions = const [],
    this.mimeTypes = const [],
    this.isSupported = true,
    this.category,
  });

  /// Canonical identifier used by the syntax highlighter engine (e.g. 'dart', 'python').
  final String id;

  /// Human-readable display name (e.g. 'Dart', 'Python').
  final String name;

  /// Recognized alias identifiers (e.g. ['py', 'python3']).
  final List<String> aliases;

  /// File extensions associated with this language (e.g. ['dart']).
  final List<String> extensions;

  /// MIME types associated with this language (e.g. ['text/x-dart']).
  final List<String> mimeTypes;

  /// Whether tokenization is supported for this language.
  final bool isSupported;

  /// High-level category grouping (e.g. 'Programming', 'Data', 'Web', 'Scripting', 'Database').
  final String? category;

  /// Plain text fallback representation.
  static const plainText = SyntaxLanguage(
    id: 'text',
    name: 'Plain Text',
    aliases: ['plaintext', 'txt'],
    extensions: ['txt', 'text'],
    mimeTypes: ['text/plain'],
    isSupported: false,
    category: 'General',
  );

  @override
  String toString() => 'SyntaxLanguage($id, name: "$name", isSupported: $isSupported)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyntaxLanguage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
