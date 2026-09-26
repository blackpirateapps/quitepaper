/// Shared helper for detecting whether a caret offset falls inside a fenced
/// code block (```` ``` ```` or `~~~`).
///
/// A single correct implementation used by every autocomplete/command trigger
/// (note-link, tag, slash) so a fix never has to be applied in three places
/// (P3-4). A caret is inside a fenced code block iff the number of *fence
/// lines* strictly before the caret's own line is odd. A fence line is a line
/// whose first non-whitespace characters are ```` ``` ```` or `~~~`; an inline
/// span like `` `code` `` on the caret's line is never counted as a block
/// fence.
bool isInsideFencedCodeBlock(String text, int offset) {
  if (offset <= 0 || text.isEmpty) return false;
  if (!text.contains('```') && !text.contains('~~~')) return false;

  final clampedOffset = offset > text.length ? text.length : offset;

  // Start of the caret's own line — fences on this line or after do not count.
  final caretLineStart = text.lastIndexOf('\n', clampedOffset - 1) + 1;

  var fenceCount = 0;
  var lineStart = 0;
  while (lineStart < caretLineStart) {
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = text.length;
    final trimmed = text.substring(lineStart, lineEnd).trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      fenceCount++;
    }
    lineStart = lineEnd + 1;
  }

  return fenceCount.isOdd;
}
