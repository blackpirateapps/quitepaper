class HeadingItem {
  const HeadingItem({
    required this.id,
    required this.rawTitle,
    required this.title,
    required this.level,
    required this.charOffset,
    required this.lineIndex,
    this.normalizedOffset = 0.0,
  });

  /// Unique stable identifier within the document (e.g. "h_0_0", "h_142_12").
  final String id;

  /// Raw markdown title string including formatting tokens (e.g. "**Bold** _italic_ `code`").
  final String rawTitle;

  /// Clean plain-text title string stripped of markdown formatting (e.g. "Bold italic code").
  final String title;

  /// Heading level (1 for H1, 2 for H2, ..., 6 for H6).
  final int level;

  /// Starting character offset of the heading line in the markdown source.
  final int charOffset;

  /// 0-indexed line number in the markdown source.
  final int lineIndex;

  /// Approximate or computed normalized position in the document (0.0 at top, 1.0 at bottom).
  final double normalizedOffset;

  HeadingItem copyWith({
    String? id,
    String? rawTitle,
    String? title,
    int? level,
    int? charOffset,
    int? lineIndex,
    double? normalizedOffset,
  }) {
    return HeadingItem(
      id: id ?? this.id,
      rawTitle: rawTitle ?? this.rawTitle,
      title: title ?? this.title,
      level: level ?? this.level,
      charOffset: charOffset ?? this.charOffset,
      lineIndex: lineIndex ?? this.lineIndex,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeadingItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          level == other.level &&
          charOffset == other.charOffset &&
          lineIndex == other.lineIndex &&
          (normalizedOffset - other.normalizedOffset).abs() < 1e-6;

  @override
  int get hashCode => Object.hash(id, title, level, charOffset, lineIndex);

  @override
  String toString() =>
      'HeadingItem(id: $id, level: $level, title: "$title", line: $lineIndex, norm: ${normalizedOffset.toStringAsFixed(2)})';
}
