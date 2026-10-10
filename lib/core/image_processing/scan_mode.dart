/// Document scanner capture modes.
///
/// A [ScanMode] selects a whole image *pipeline* (illumination flatten,
/// adaptive threshold, white balance, …). It is deliberately **orthogonal** to
/// the continuous [ImageAdjustments] knobs (brightness/contrast/…): a mode sets
/// the base look, the knobs fine-tune on top. Do not try to express a mode as
/// knob values — that is the mistake the old "fake presets" made.
///
/// Modes are ephemeral scan-session state (per page). They are baked into the
/// final PDF at compile time and are **not** persisted anywhere today (raw
/// photos are discarded after compile; no scan-draft serialization exists).
enum ScanMode {
  /// Escape hatch: geometry only (crop/rotate/resize), no tone transform.
  original,

  /// The default. Any document under imperfect lighting: shadows flattened,
  /// white-balanced, crisp, lightly punchy. "It just looks scanned."
  auto,

  /// Forms, receipts, colored docs where color must stay true: flattened
  /// lighting + gentle contrast, colors faithful.
  document,

  /// Photos of whiteboards / flip charts: background driven to white, marker
  /// colors boosted, glare tamed.
  whiteboard,

  /// Mixed text/images where pure B&W is too harsh: neutral gray, mild local
  /// contrast.
  grayscale,

  /// Pure text pages; smallest files; best OCR input: adaptive-thresholded
  /// black ink on white, despeckled.
  blackAndWhite;

  /// Default mode applied to a freshly captured page.
  static const ScanMode defaultMode = ScanMode.auto;

  /// Short human-readable label for pickers / carousels.
  String get label => switch (this) {
        ScanMode.original => 'Original',
        ScanMode.auto => 'Auto',
        ScanMode.document => 'Document',
        ScanMode.whiteboard => 'Whiteboard',
        ScanMode.grayscale => 'Grayscale',
        ScanMode.blackAndWhite => 'B&W Text',
      };

  /// One-line description of when to use the mode.
  String get description => switch (this) {
        ScanMode.original => 'No tone changes — keep the photo as captured.',
        ScanMode.auto => 'Flatten shadows, balance color, sharpen.',
        ScanMode.document => 'Even lighting, true colors.',
        ScanMode.whiteboard => 'Whiten background, boost markers.',
        ScanMode.grayscale => 'Neutral gray with mild contrast.',
        ScanMode.blackAndWhite => 'Crisp black text on white.',
      };

  /// Whether this mode produces a binarized (1-bit-looking) result, under which
  /// the `grayscale` and `saturation` knobs are meaningless no-ops.
  bool get isBinary => this == ScanMode.blackAndWhite;

  /// Whether this mode forces a monochrome result (B&W or grayscale), under
  /// which the `saturation` knob and `grayscale` toggle are redundant.
  bool get isMonochrome =>
      this == ScanMode.blackAndWhite || this == ScanMode.grayscale;

  /// Parses a persisted name (forward-compatible); unknown/missing → [defaultMode].
  static ScanMode fromName(String? name, {ScanMode fallback = defaultMode}) {
    if (name == null) return fallback;
    for (final mode in ScanMode.values) {
      if (mode.name == name) return mode;
    }
    return fallback;
  }
}
