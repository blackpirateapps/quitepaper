import 'package:flutter/foundation.dart';
import 'syntax_token_type.dart';

/// A token span mapping a slice of source text to a semantic [SyntaxTokenType].
/// Offsets use Flutter/Dart canonical UTF-16 string indices.
@immutable
class SyntaxToken {
  const SyntaxToken({
    required this.start,
    required this.end,
    required this.type,
    this.text,
  }) : assert(start >= 0 && end >= start, 'Invalid token range: [$start, $end]');

  final int start;
  final int end;
  final SyntaxTokenType type;
  final String? text;

  int get length => end - start;

  @override
  String toString() => 'SyntaxToken($type, [$start, $end]${text != null ? ', text: "$text"' : ''})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SyntaxToken &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end &&
          type == other.type &&
          text == other.text;

  @override
  int get hashCode => Object.hash(start, end, type, text);
}
