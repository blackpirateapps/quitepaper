import 'package:flutter/foundation.dart';
import '../../notes/domain/note_model.dart';
import '../../notes/domain/note_version_model.dart';

/// Tracks a note editing session from open to close and determines whether
/// edits are substantive enough to commit a version to Version History
/// or if they should be discarded as micro-edits (accidental taps / minor whitespace tweaks).
class VersionSessionTracker {
  VersionSessionTracker(Note initialNote)
      : _initialTitle = initialNote.title,
        _initialContent = initialNote.content,
        _initialTags = List<String>.unmodifiable(initialNote.tags),
        _startTime = DateTime.now();

  final String _initialTitle;
  final String _initialContent;
  final List<String> _initialTags;
  final DateTime _startTime;

  String get initialTitle => _initialTitle;
  String get initialContent => _initialContent;
  List<String> get initialTags => _initialTags;
  DateTime get startTime => _startTime;

  /// Evaluates whether the changes made during this session constitute
  /// a meaningful version rather than a trivial micro-edit.
  bool isMeaningfulSession({
    required String finalTitle,
    required String finalContent,
    required List<String> finalTags,
  }) {
    // 1. Title change
    if (finalTitle.trim() != _initialTitle.trim()) {
      return true;
    }

    // 2. Tag change
    final initialTagSet = _initialTags.toSet();
    final finalTagSet = finalTags.toSet();
    if (!setEquals(initialTagSet, finalTagSet)) {
      return true;
    }

    // Exact content match -> no edit occurred
    if (finalContent == _initialContent) {
      return false;
    }

    // 3. Significant Character Length Delta (>= 10 characters net difference)
    final charDelta = (finalContent.length - _initialContent.length).abs();
    if (charDelta >= 10) {
      return true;
    }

    // 4. Word Count Delta (>= 3 words net difference)
    final initialWords = NoteVersion.countWords(_initialContent);
    final finalWords = NoteVersion.countWords(finalContent);
    final wordDelta = (finalWords - initialWords).abs();
    if (wordDelta >= 3) {
      return true;
    }

    // 5. Structural Markdown Syntax Alterations
    if (_hasStructuralChange(_initialContent, finalContent)) {
      return true;
    }

    // 6. Token Replacement (e.g. replacing a phrase or word even if character delta is small)
    final initialTokens = _extractWords(_initialContent);
    final finalTokens = _extractWords(finalContent);
    final tokenDiff = initialTokens.difference(finalTokens).length +
        finalTokens.difference(initialTokens).length;
    if (tokenDiff >= 3) {
      return true;
    }

    // Otherwise, this is a micro-edit (e.g. 1-2 character typo tweak or trailing space)
    return false;
  }

  /// Generates a concise human-readable summary of what changed.
  String generateSummary({
    required String finalTitle,
    required String finalContent,
    required List<String> finalTags,
  }) {
    return NoteVersion.computeDeltaSummary(
      oldContent: _initialContent,
      newContent: finalContent,
      oldTitle: _initialTitle,
      newTitle: finalTitle,
      oldTags: _initialTags,
      newTags: finalTags,
    );
  }

  static bool _hasStructuralChange(String oldText, String newText) {
    final headingReg = RegExp(r'^#{1,6}\s', multiLine: true);
    final listReg = RegExp(r'^[-*+]\s', multiLine: true);
    final checkReg = RegExp(r'^[-*+]\s+\[[ xX]\]', multiLine: true);
    final codeBlockReg = RegExp(r'```');
    final imageReg = RegExp(r'!\[.*?\]\(.*?\)');

    if (headingReg.allMatches(oldText).length !=
        headingReg.allMatches(newText).length) {
      return true;
    }
    if (checkReg.allMatches(oldText).length !=
        checkReg.allMatches(newText).length) {
      return true;
    }
    if (listReg.allMatches(oldText).length !=
        listReg.allMatches(newText).length) {
      return true;
    }
    if (codeBlockReg.allMatches(oldText).length !=
        codeBlockReg.allMatches(newText).length) {
      return true;
    }
    if (imageReg.allMatches(oldText).length !=
        imageReg.allMatches(newText).length) {
      return true;
    }

    return false;
  }

  static Set<String> _extractWords(String text) {
    if (text.isEmpty) return const {};
    return text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toSet();
  }
}
