import 'package:flutter/foundation.dart';
import '../uri/quiet_paper_uri.dart';
import '../../features/notes/domain/note_model.dart';

/// Represents a parsed `[displayText](qp://note/<UUID>)` link found within a Markdown string.
@immutable
class ParsedNoteLink {
  const ParsedNoteLink({
    required this.targetNoteId,
    required this.displayText,
    required this.sourceOffset,
    required this.rawText,
    required this.uri,
  });

  /// The UUID of the referenced target note.
  final String targetNoteId;

  /// The display text within the markdown brackets.
  final String displayText;

  /// The 0-indexed UTF-16 character offset in the source Markdown where the link begins (`[`).
  final int sourceOffset;

  /// The full raw markdown string match (e.g. `[Calculus](qp://note/...)`).
  final String rawText;

  /// The parsed internal Quiet Paper URI.
  final QuietPaperUri uri;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedNoteLink &&
          runtimeType == other.runtimeType &&
          targetNoteId == other.targetNoteId &&
          displayText == other.displayText &&
          sourceOffset == other.sourceOffset &&
          rawText == other.rawText;

  @override
  int get hashCode =>
      targetNoteId.hashCode ^
      displayText.hashCode ^
      sourceOffset.hashCode ^
      rawText.hashCode;

  @override
  String toString() =>
      'ParsedNoteLink(target: $targetNoteId, text: "$displayText", offset: $sourceOffset)';
}

/// Represents a backlink relationship pointing to the currently viewed note from a source note.
@immutable
class BacklinkItem {
  const BacklinkItem({
    required this.sourceNote,
    required this.occurrencesCount,
    this.snippet = '',
  });

  /// The source note containing the link(s).
  final Note sourceNote;

  /// The number of outgoing links inside [sourceNote] pointing to the target note.
  final int occurrencesCount;

  /// Optional preview snippet from the source note (if permitted / not password protected).
  final String snippet;

  String get sourceNoteId => sourceNote.id;
  String get displayTitle => sourceNote.displayTitle;
  DateTime get updatedAt => sourceNote.updatedAt;
  List<String> get tags => sourceNote.tags;
  bool get isPasswordProtected => sourceNote.isPasswordProtected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BacklinkItem &&
          runtimeType == other.runtimeType &&
          sourceNote.id == other.sourceNote.id &&
          occurrencesCount == other.occurrencesCount;

  @override
  int get hashCode => sourceNote.id.hashCode ^ occurrencesCount.hashCode;
}
