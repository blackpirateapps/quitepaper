import 'dart:ui';

import '../../ocr/ocr_models.dart';

/// Type of a single annotation mark.
///
/// Freeform types ([ink]..[arrow]) are pure geometry and need no OCR.
/// Text-anchored types ([textHighlight]..[squiggly]) and [comment] snap to OCR
/// word/line geometry. [redaction] is an opaque box in-app that becomes a
/// permanent burn-in only on export (see annotation_flattener).
enum AnnotationType {
  ink('ink'),
  highlighterFree('highlighter_free'),
  rect('rect'),
  ellipse('ellipse'),
  line('line'),
  arrow('arrow'),
  textHighlight('text_highlight'),
  underline('underline'),
  strikethrough('strikethrough'),
  squiggly('squiggly'),
  comment('comment'),
  redaction('redaction');

  const AnnotationType(this.identifier);

  final String identifier;

  /// Freeform tools are available immediately, before OCR completes.
  bool get isFreeform =>
      this == ink ||
      this == highlighterFree ||
      this == rect ||
      this == ellipse ||
      this == line ||
      this == arrow;

  /// Text-anchored tools require `ocrState == available`.
  bool get isTextAnchored =>
      this == textHighlight ||
      this == underline ||
      this == strikethrough ||
      this == squiggly;

  static AnnotationType fromIdentifier(String? id) {
    if (id == null) return AnnotationType.ink;
    for (final t in AnnotationType.values) {
      if (t.identifier == id || t.name == id) return t;
    }
    return AnnotationType.ink;
  }
}

/// Visual style for an annotation. [strokeWidth] is normalized to page width
/// (0.0–1.0) so marks keep a consistent apparent thickness at any raster DPI.
class AnnotationStyle {
  const AnnotationStyle({
    this.colorArgb = 0xFF000000,
    this.strokeWidth = 0.004,
    this.opacity = 1.0,
    this.filled = false,
  });

  /// 32-bit ARGB color value.
  final int colorArgb;

  /// Stroke width as a fraction of page width.
  final double strokeWidth;

  /// 0.0 (transparent) – 1.0 (opaque).
  final double opacity;

  /// Whether a shape (rect/ellipse) is filled rather than outlined.
  final bool filled;

  AnnotationStyle copyWith({
    int? colorArgb,
    double? strokeWidth,
    double? opacity,
    bool? filled,
  }) {
    return AnnotationStyle(
      colorArgb: colorArgb ?? this.colorArgb,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      opacity: opacity ?? this.opacity,
      filled: filled ?? this.filled,
    );
  }

  Map<String, dynamic> toJson() => {
        'colorArgb': colorArgb,
        'strokeWidth': strokeWidth,
        'opacity': opacity,
        'filled': filled,
      };

  factory AnnotationStyle.fromJson(Map<String, dynamic> json) {
    return AnnotationStyle(
      colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFF000000,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0.004,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      filled: json['filled'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnnotationStyle &&
          colorArgb == other.colorArgb &&
          (strokeWidth - other.strokeWidth).abs() < 0.00001 &&
          (opacity - other.opacity).abs() < 0.00001 &&
          filled == other.filled;

  @override
  int get hashCode => Object.hash(colorArgb, strokeWidth, opacity, filled);
}
/// Normalized geometry for an annotation. All coordinates are 0.0–1.0 in page
/// space (top-left origin), matching [NormalizedRect].
///
/// - [points]: polyline for `ink`/`highlighterFree`; a 2-point `[start, end]`
///   for `line`/`arrow`.
/// - [rects]: one rect for `rect`/`ellipse`; one-per-line for text-anchored
///   spans; one-or-more boxes for a snapped `redaction`.
/// - [anchor]: pin location for a `comment`.
class AnnotationGeometry {
  const AnnotationGeometry({
    this.points = const [],
    this.rects = const [],
    this.anchor,
  });

  final List<Offset> points;
  final List<NormalizedRect> rects;
  final Offset? anchor;

  AnnotationGeometry copyWith({
    List<Offset>? points,
    List<NormalizedRect>? rects,
    Offset? anchor,
  }) {
    return AnnotationGeometry(
      points: points ?? this.points,
      rects: rects ?? this.rects,
      anchor: anchor ?? this.anchor,
    );
  }

  Map<String, dynamic> toJson() => {
        if (points.isNotEmpty)
          'points': points.map((o) => [_r(o.dx), _r(o.dy)]).toList(),
        if (rects.isNotEmpty) 'rects': rects.map((r) => r.toJson()).toList(),
        if (anchor != null) 'anchor': [_r(anchor!.dx), _r(anchor!.dy)],
      };

  factory AnnotationGeometry.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List? ?? const [];
    final rawRects = json['rects'] as List? ?? const [];
    final rawAnchor = json['anchor'] as List?;
    return AnnotationGeometry(
      points: rawPoints
          .whereType<List>()
          .map((p) => Offset(
                (p.isNotEmpty ? p[0] as num : 0).toDouble(),
                (p.length > 1 ? p[1] as num : 0).toDouble(),
              ))
          .toList(),
      rects: rawRects
          .whereType<Map>()
          .map((r) => NormalizedRect.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
      anchor: rawAnchor != null && rawAnchor.length >= 2
          ? Offset((rawAnchor[0] as num).toDouble(), (rawAnchor[1] as num).toDouble())
          : null,
    );
  }

  static double _r(double v) => (v * 100000).round() / 100000;
}

/// One annotation = one typed vector object stored in the encrypted sidecar.
/// [id] is the stable merge key; [updatedAtMs] is the last-writer-wins tiebreak.
class Annotation {
  const Annotation({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.type,
    required this.geometry,
    this.style = const AnnotationStyle(),
    this.text,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.deleted = false,
    this.z = 0,
  });

  /// uuid v4, stable across edits and devices — the merge key.
  final String id;

  /// `qp://document/<UUID>` owner (bare UUID also accepted).
  final String documentId;

  /// 0-based page the mark lives on.
  final int pageIndex;

  final AnnotationType type;
  final AnnotationGeometry geometry;
  final AnnotationStyle style;

  /// Comment body / typed-text payload (nullable).
  final String? text;

  final int createdAtMs;

  /// Last mutation time; LWW tiebreaker for sync merge.
  final int updatedAtMs;

  /// Soft-delete tombstone for sync.
  final bool deleted;

  /// Paint order within the page (ascending = painted first / underneath).
  final int z;

  Annotation copyWith({
    String? id,
    String? documentId,
    int? pageIndex,
    AnnotationType? type,
    AnnotationGeometry? geometry,
    AnnotationStyle? style,
    String? text,
    bool clearText = false,
    int? createdAtMs,
    int? updatedAtMs,
    bool? deleted,
    int? z,
  }) {
    return Annotation(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      geometry: geometry ?? this.geometry,
      style: style ?? this.style,
      text: clearText ? null : (text ?? this.text),
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      deleted: deleted ?? this.deleted,
      z: z ?? this.z,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'documentId': documentId,
        'pageIndex': pageIndex,
        'type': type.identifier,
        'geometry': geometry.toJson(),
        'style': style.toJson(),
        if (text != null) 'text': text,
        'createdAtMs': createdAtMs,
        'updatedAtMs': updatedAtMs,
        'deleted': deleted,
        'z': z,
      };

  factory Annotation.fromJson(Map<String, dynamic> json) {
    return Annotation(
      id: json['id'] as String? ?? '',
      documentId: json['documentId'] as String? ?? '',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      type: AnnotationType.fromIdentifier(json['type'] as String?),
      geometry: json['geometry'] is Map
          ? AnnotationGeometry.fromJson(
              Map<String, dynamic>.from(json['geometry'] as Map))
          : const AnnotationGeometry(),
      style: json['style'] is Map
          ? AnnotationStyle.fromJson(Map<String, dynamic>.from(json['style'] as Map))
          : const AnnotationStyle(),
      text: json['text'] as String?,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
      deleted: json['deleted'] as bool? ?? false,
      z: (json['z'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Annotation && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Union-by-id + last-writer-wins merge (spec §9). For each [id] present on
/// either side, keeps the copy with the greater [Annotation.updatedAtMs]; a
/// `deleted` tombstone follows the same LWW rule (newer edit resurrects).
List<Annotation> mergeAnnotations(
  Iterable<Annotation> local,
  Iterable<Annotation> remote,
) {
  final byId = <String, Annotation>{};
  for (final a in local) {
    byId[a.id] = a;
  }
  for (final a in remote) {
    final existing = byId[a.id];
    if (existing == null || a.updatedAtMs >= existing.updatedAtMs) {
      byId[a.id] = a;
    }
  }
  final merged = byId.values.toList()
    ..sort((a, b) => a.z != b.z
        ? a.z.compareTo(b.z)
        : a.createdAtMs.compareTo(b.createdAtMs));
  return merged;
}

