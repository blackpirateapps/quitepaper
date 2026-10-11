import '../../ocr/ocr_models.dart';

/// Result of resolving a selection against OCR geometry.
///
/// [lineRects] holds one tight union rectangle per covered OCR line (never one
/// giant rect across lines, never one-per-word). [text] is the underlying OCR
/// text in natural reading order: words within a line joined with a single
/// space, lines joined with a newline.
class TextSelectionResult {
  const TextSelectionResult({required this.lineRects, required this.text});

  /// One tight union rect per covered line, ordered top-to-bottom.
  final List<NormalizedRect> lineRects;

  /// Underlying OCR text in reading order (`' '` between words, `'\n'` between
  /// lines).
  final String text;
}

/// Internal per-line accumulation while resolving a drag.
class _LineHit {
  _LineHit(this.sortY, this.rect, this.text);

  /// Top edge of the source line, used for top-to-bottom ordering.
  final double sortY;
  final NormalizedRect rect;
  final String text;
}

/// Pure (no Flutter widgets) resolver that turns a normalized drag rectangle or
/// a tap point into per-line highlight rects plus the underlying OCR text.
///
/// All geometry is normalized `0.0–1.0`, top-left origin, matching
/// [NormalizedRect]. The resolver iterates `page.blocks → lines → words`.
class AnnotationTextSelector {
  const AnnotationTextSelector();

  /// Resolve a normalized drag [dragRect] against [page] OCR geometry.
  ///
  /// Primary strategy: collect [OcrWord]s whose geometric centre falls within
  /// [dragRect], grouped by their [OcrLine], emitting ONE union rect per line.
  ///
  /// Fallback (per line): when a line has no words with usable bounds (empty
  /// words list, or every word has a zero-size box), snap at [OcrLine] level —
  /// include the whole line when its bounds intersect [dragRect].
  ///
  /// Line rects and text are ordered top-to-bottom (by line `bounds.y`); within
  /// a line, words are ordered left-to-right (by word `bounds.x`).
  TextSelectionResult resolve(OcrPage page, NormalizedRect dragRect) {
    final hits = <_LineHit>[];

    for (final block in page.blocks) {
      for (final line in block.lines) {
        final usableWords = <OcrWord>[
          for (final w in line.words)
            if (w.bounds.width > 0 && w.bounds.height > 0) w,
        ];

        if (usableWords.isEmpty) {
          // Fallback: snap at line level when word geometry is unusable.
          if (_hasArea(line.bounds) && line.bounds.intersects(dragRect)) {
            hits.add(_LineHit(line.bounds.y, line.bounds, line.text));
          }
          continue;
        }

        // Primary: words whose centre falls inside the drag rectangle.
        final selected = <OcrWord>[
          for (final w in usableWords)
            if (dragRect.contains(w.bounds.centerX, w.bounds.centerY)) w,
        ]..sort((a, b) => a.bounds.x.compareTo(b.bounds.x));

        if (selected.isEmpty) continue;

        final rect = _unionRect(selected.map((w) => w.bounds));
        final text = selected.map((w) => w.text).join(' ');
        hits.add(_LineHit(line.bounds.y, rect, text));
      }
    }

    hits.sort((a, b) => a.sortY.compareTo(b.sortY));

    return TextSelectionResult(
      lineRects: [for (final h in hits) h.rect],
      text: hits.map((h) => h.text).join('\n'),
    );
  }

  /// Hit-test a tap at normalized point ([nx], [ny]) to the single word (or, if
  /// no usable word is hit, the line) under the point. Returns `null` when
  /// nothing is hit.
  ///
  /// Used for tap-to-select-word and comment anchoring. The most specific match
  /// wins: a word containing the point is preferred over its enclosing line.
  TextSelectionResult? resolvePoint(OcrPage page, double nx, double ny) {
    // First pass: most specific — a word that contains the point.
    for (final block in page.blocks) {
      for (final line in block.lines) {
        for (final word in line.words) {
          if (_hasArea(word.bounds) && word.bounds.contains(nx, ny)) {
            return TextSelectionResult(
              lineRects: [word.bounds],
              text: word.text,
            );
          }
        }
      }
    }

    // Second pass: fall back to a line that contains the point.
    for (final block in page.blocks) {
      for (final line in block.lines) {
        if (_hasArea(line.bounds) && line.bounds.contains(nx, ny)) {
          return TextSelectionResult(
            lineRects: [line.bounds],
            text: line.text,
          );
        }
      }
    }

    return null;
  }

  static bool _hasArea(NormalizedRect r) => r.width > 0 && r.height > 0;

  /// Union = min x / min y / max right / max bottom over [rects].
  static NormalizedRect _unionRect(Iterable<NormalizedRect> rects) {
    var minX = double.infinity;
    var minY = double.infinity;
    var maxRight = double.negativeInfinity;
    var maxBottom = double.negativeInfinity;

    for (final r in rects) {
      if (r.x < minX) minX = r.x;
      if (r.y < minY) minY = r.y;
      if (r.right > maxRight) maxRight = r.right;
      if (r.bottom > maxBottom) maxBottom = r.bottom;
    }

    return NormalizedRect(
      x: minX,
      y: minY,
      width: maxRight - minX,
      height: maxBottom - minY,
    );
  }
}
