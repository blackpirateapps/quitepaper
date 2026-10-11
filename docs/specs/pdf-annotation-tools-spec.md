# PDF Annotation Tools — Implementation Spec

> Status: **Approved design, not yet built.** Author: product brainstorm, 2026-10-11.
> Audience: a coding agent (or human) picking this up cold in a new session.
> Read §0–§3 before touching any feature section. The locked decisions in §2 were
> made with the maintainer and are **not open for re-litigation** — build to them.
>
> Focus of this effort: **studying / reading imported PDFs.** Every design tension
> was resolved in favour of the reading use case, not document authoring or signing.

---

## 0. Summary

Add annotation tooling to the dedicated PDF viewer (`DocumentViewerScreen`). Users reading
imported PDFs can mark up pages with freehand ink, highlighter, shapes, and text-anchored
marks (highlight / underline / strikethrough / squiggly), attach comments, and redact
content. Annotations are stored as a **non-destructive, client-side-encrypted vector sidecar**
that never mutates the original PDF bytes, sync crypto-blind across devices like notes, and are
**flattened into the raster only on export / share / print**.

The viewer today renders each PDF page as a flat raster PNG (no live text layer); annotations
are therefore a **vector overlay (`CustomPaint`) painted on top of the raster**, which keeps
marks crisp at any zoom and keeps decrypted bytes inside our own code (no third-party PDF-edit
engine). Text-anchored tools snap to per-word geometry produced by the OCR pipeline (which
auto-runs on import). A separate, additive workstream (§10) later lets born-digital PDFs skip
OCR and use their embedded text layer for sharper, cheaper text geometry.

---

## 1. Ground Truth — Existing Architecture (verified in code, 2026-10-11)

### 1.1 The viewer — raster, not an interactive PDF widget
`lib/core/documents/presentation/document_viewer_screen.dart` (`DocumentViewerScreen`):
- Resolves and decrypts the document, then rasterizes every page via
  `Printing.raster(pdfBytes, dpi: 150.0)` → one PNG per page held in `_renderedPages`.
- Displays the selected page as `Image.memory(...)` inside an `InteractiveViewer`
  (`minScale: 0.8, maxScale: 4.0`). Phone layout = single page + bottom page pills;
  tablet layout = 180px left thumbnail rail + main viewer.
- **There is no live text layer and no page-object model on screen** — just flattened images.
  App bar actions: rename, OCR text viewer, run/regenerate OCR, save, share, print, reload.

### 1.2 Storage & encryption (zero-knowledge, QPD1)
- Documents are end-to-end encrypted (`PDF (QPD1)`), decrypted on-device. The backend is
  **crypto-blind** — it stores ciphertext + metadata revisions, never plaintext.
- Document sources (`lib/core/documents/document_models.dart`, `DocumentSource`):
  `scanner`, `importedPdf`, `webSnapshot`. This spec targets `importedPdf` primarily; it
  applies to `scanner` docs too. `webSnapshot` is handled by a different viewer and is OUT of scope.

### 1.3 OCR geometry model (the enabler for text-anchored tools)
`lib/core/ocr/ocr_models.dart` already defines normalized geometry we reuse verbatim:
- `NormalizedRect { x, y, width, height }` — **top-left origin, 0.0–1.0**, with
  `contains(px,py)`, `intersects(other)`, and `NormalizedRect.fromPixels(...)`.
- `OcrWord { text, bounds }` → `OcrLine { text, bounds, words }` →
  `OcrBlock { text, bounds, lines }` → `OcrPage { pageNumber, plainText, blocks }`.
- Stored **per page, encrypted** with the master key; also held in an in-memory search cache.

### 1.4 OCR / text pipeline (image-based today)
`lib/core/ocr/document_processing_service.dart` → `processDocument(...)`:
- **Always** rasterizes pages at 150 DPI and runs on-device recognition
  (`DefaultOcrService.recognizePage`, ML Kit with a pure-Dart CV fallback), per page, on a
  background isolate. Produces `OcrPage` geometry, encrypts each page, stores it, flips
  `ocrState` → `available`, and updates the search cache.
- **Important correction to the HANDOFF:** §51/§54 describe an embedded-text extractor
  (`DefaultPdfTextExtractor` / `_PdfDocumentParser`, lazy xref parsing, 5s budget → OCR
  fallback). **That code is not present in the current `lib/` tree** (grep finds no such
  symbols). Treat the current pipeline as **OCR-on-raster only**. Feature G (§10) is therefore
  **net-new**, not an extension of existing code — the HANDOFF sections are a design reference
  for the parsing approach, nothing more.

### 1.5 Export / share / print
- `_savePdfToStorage` / `_sharePdf` / `_printPdf` all operate on the raw decrypted
  `docInfo.pdfBytes` (via `FilePicker.saveFile`, `Printing.sharePdf`, `Printing.layoutPdf`).
  Annotation flattening (§8) hooks in here.

### 1.6 Relevant dependencies (`pubspec.yaml`)
- `pdf: ^3.13.0` (PDF *generation* — used to build the flattened export), `printing: ^5.15.0`
  (raster/share/print), `image: ^4.9.2` (pixel compositing), `google_mlkit_text_recognition: ^0.17.1`.
  **No interactive PDF-viewer dependency is to be added** (see §2, option 3).

---

## 2. Locked Decisions (do not re-litigate)

1. **Non-destructive encrypted vector sidecar** (necessary). Annotations are stored as typed
   vector objects in normalized coordinates, encrypted client-side, keyed by `documentId`.
   The original PDF bytes are **never** mutated by annotating.
2. **Crypto-blind sync + merge** (necessary). Annotations sync like notes; merge is
   **union-by-id with last-writer-wins** on edits to the same object (see §9) — not the heavier
   note 3-way merge.
3. **Render = overlay `CustomPaint` on the existing raster** (recommended option, chosen).
   Keep `Printing.raster`; do **not** add an interactive/native PDF-editing library. Rationale:
   zero new large deps (OpenCV was already dropped over app size), decrypted bytes never leave
   our code, and vector marks stay crisp at any zoom.
4. **Flatten only on export / share / print** (necessary). The in-app model stays fully
   non-destructive; permanence is produced at export time by compositing onto the raster (§8).
5. **OCR auto-runs on import** (chosen). Text-anchored tools depend on word geometry; it must be
   ready by the time the user opens the doc. This matches the current pipeline (§1.4).
6. **Redaction = "redact-and-export only"** (chosen). In-app, a redaction is an opaque box over
   the raster; the covered content **still exists in the stored PDF**. True removal happens
   **only in the exported/shared/printed artifact** (§7). The maintainer explicitly accepted
   that the in-app stored copy retains the content and that prior synced revisions are not purged.
7. **Embedded text layer, hybrid per-page** (chosen, §10). Born-digital pages use their embedded
   text geometry and skip OCR; image pages fall back to OCR. This is a **separate workstream**
   that the annotation layer does not block on.

---

## 3. Constraints

- **Offline-first, zero-knowledge, no new outbound network calls.** Annotations are encrypted
  with the master key exactly like OCR pages; the backend only ever sees ciphertext.
- **Non-destructive on the original.** The decrypted `pdfBytes` are read-only for the annotation
  feature. Only the export path (§8) produces modified bytes, and it produces a *new* artifact —
  it does not overwrite the stored document.
- **Normalized, resolution-independent geometry.** All annotation geometry is stored in 0.0–1.0
  page coordinates (top-left origin, matching `NormalizedRect`) so it survives re-rasterization at
  any DPI and any on-screen size. Nothing stores pixel coordinates.
- **Heavy work off the UI isolate**, following the existing `compute()` pattern (OCR, raster).
- **Theme-native UI.** Tool palette, colors, and panels use existing theme tokens
  (`context.appColors`, `AppSpacing`, `AppRadii`, `AppTypography`, `QuietButton`). Marks default
  to a restrained palette; no second brand hue is introduced into chrome.
- **Degrade gracefully.** A document with no OCR yet shows freeform tools immediately and disables
  text-anchored tools with a quiet "preparing text…" state rather than an error.

---

## 4. Feature A — Annotation Layer (foundation)

### 4.1 Data model
One annotation = one typed object. Suggested shape (names illustrative, not binding):

```
Annotation {
  String   id;            // uuid v4, stable; the merge key
  String   documentId;    // qp://document/<UUID>
  int      pageIndex;     // 0-based page the mark lives on
  AnnotationType type;    // see enum below
  Geometry geometry;      // normalized; shape depends on type (§4.3)
  AnnotationStyle style;  // color, strokeWidth, opacity, fill, etc.
  String?  text;          // comment body / typed-text payload (nullable)
  int      createdAtMs;   // epoch millis
  int      updatedAtMs;   // epoch millis — the LWW tiebreaker (§9)
  bool     deleted;       // tombstone for sync (soft delete)
  int      z;             // paint order within the page
}

enum AnnotationType {
  ink, highlighterFree,              // freeform (§5)
  rect, ellipse, line, arrow,        // freeform shapes (§5)
  textHighlight, underline,          // text-anchored (§6)
  strikethrough, squiggly,           // text-anchored (§6)
  comment,                           // pinned note (§6)
  redaction,                         // redact-and-export (§7)
}
```

- `AnnotationStyle` carries `colorArgb`, `strokeWidth` (normalized to page width), `opacity`,
  and `filled` (shapes). Redactions ignore color and always flatten to solid black (§7).
- Keep the model a plain serializable value type (JSON) so it reuses the OCR crypto path (§4.2).

### 4.2 Storage
- Store annotations **per document, per page**, mirroring the OCR page storage pattern in
  `document_processing_service.dart` (an encrypted blob keyed by `documentId` + page). This
  gives lazy per-page load for large PDFs and a natural sync granularity.
- Encrypt with the master key via the same crypto helper family used for OCR pages
  (`OcrCrypto`-equivalent). The backend stores only the ciphertext blob.
- A new Drift table (e.g. `DocumentAnnotationsTable`: `documentId`, `pageNumber`,
  `encryptedPayload`, `revision`, `updatedAt`) + a schema-version bump and migration, following
  the precedent of the OCR page table and the sync tables.

### 4.3 Coordinate space (critical — get this exactly right)
- **Everything normalized, top-left origin, 0.0–1.0**, consistent with `NormalizedRect`.
- Ink / freeform: `List<Offset>` where each component is 0..1 of page width/height.
- Shapes & text-anchored spans: one or more `NormalizedRect`.
- Comment pins: a single normalized anchor point (+ optional `NormalizedRect` for the anchored region).
- **Screen ↔ page mapping** must invert *two* transforms: (a) the `InteractiveViewer` matrix
  (pan/zoom), and (b) the `BoxFit.contain` letterboxing of `Image.memory` inside its box. A touch
  → page-normalized helper is the single source of truth; mis-handling the letterbox offset is the
  most likely cause of marks drifting from where the finger was.

### 4.4 Rendering (overlay)
- A `CustomPaint` layered directly over the page `Image.memory`, inside the same transformed
  space so marks pan/zoom with the page. Because marks are vector, they stay crisp at `maxScale`.
- Paint committed annotations from a cached layer; paint only the in-progress stroke live, so
  dragging a long ink stroke never repaints the whole page's annotation set.
- Each page owns its own overlay; the tablet thumbnail rail may show a small annotated badge/count
  but need not render full marks.

### 4.5 Gesture arbitration / tool modes (the one real UX gotcha)
- The viewer has two modes: **Navigate** (default — `InteractiveViewer` owns one- and two-finger
  gestures, exactly as today) and **Mark up** (a tool is selected).
- In Mark-up mode: **one finger / stylus draws**, **two fingers still pan & zoom**. One-finger pan
  is suppressed while a tool is active so a drawing gesture is never stolen by the viewer.
- A floating tool palette (theme-native) selects the active tool, color, and width, and toggles
  back to Navigate. Palette lives above the page, out of the thumbnail rail on tablet.
- Stylus, when present, always draws regardless of mode (palm rejection); finger follows the mode.

### 4.6 Zoom crispness
- The page image is a 150 DPI raster; at high zoom the **page** blurs (annotations do not, being
  vector). On zoom-in past a threshold, **re-rasterize the visible page at a higher DPI** and swap
  the image in place. This is a perf/quality tradeoff local to the viewer, not an architectural one;
  it is independent of the annotation data and can land before or after v1.

### 4.7 Undo / redo & autosave
- A per-session undo/redo stack of annotation mutations (add / edit / delete).
- Autosave the page's encrypted annotation blob on commit of each mutation (debounced), so a crash
  or navigation never loses marks. No explicit "save" button.

---

## 5. Feature B — Freeform markup tools
All freeform tools are pure geometry and need **no OCR**; they are available immediately on any
document, including before OCR completes.

- **Ink pen** — smoothed polyline from sampled points; color + width presets; stylus pressure may
  modulate width where available (optional, not required for v1).
- **Highlighter (freeform)** — translucent stroke, multiply/overlay blend, wider default width,
  typically a warm yellow; distinct from the ink pen.
- **Shapes** — `rect`, `ellipse`, `line`, `arrow`. Drag to size; outline by default, optional fill
  for rect/ellipse. Arrow = line + arrowhead at the end point.
- **Stroke-level eraser** — removes whole vector objects it crosses (hit-test against stored
  geometry). **Not** a pixel eraser — nothing is rasterized, so erasing is just deleting objects.
- **Ruler / straight-line snap** — holding/toggling constrains a line/stroke to straight and snaps
  shapes to clean angles (0/45/90°). Assist only; stored geometry is still normalized points/rects.

---

## 6. Feature C — Text-anchored markup tools
These snap to the OCR word/line geometry from §1.3. Gated on `ocrState == available`; while OCR
is pending they are disabled with a quiet "preparing text…" affordance (never an error).

- **Text highlight** — drag across text; the selection resolves to the set of `OcrWord`/`OcrLine`
  bounds it covers, and the stored highlight is those `NormalizedRect`s (translucent fill). Feels
  like real PDF highlighting because it hugs the words, not the raw drag rectangle.
- **Underline / strikethrough / squiggly** — same word/line resolution; the mark is drawn relative
  to the line box (baseline for underline, mid-line for strikethrough, wavy for squiggly).
- **Select text → copy** — the same selection resolution yields the underlying OCR text (already
  extracted), copied to the clipboard. No new text model needed.
- **Comment (pinned)** — a pin anchored to a word/region (normalized anchor + optional region
  rect); tap to expand/edit the `text` body. Shows as a small marker on the page.

**Selection resolution rules**
- Primary: collect `OcrWord` boxes whose centers fall within the drag; group by `OcrLine` so a
  multi-line selection produces one rect per line (not one giant rect).
- **Fallback:** when word boxes are missing/noisy (dense or multi-column layouts), fall back to
  `OcrLine`-level snapping. Geometry is OCR-derived today, so accuracy equals OCR quality; §10 later
  upgrades born-digital pages to exact embedded geometry transparently (same `OcrPage` structure).

---

## 7. Feature D — Redaction (redact-and-export only)

**Behaviour the maintainer chose and explicitly accepted:**
- **In-app:** a redaction is a `redaction`-type annotation drawn as a **solid opaque box** over the
  raster. The underlying content **still physically exists** in the stored (encrypted) PDF beneath
  the box, and prior synced revisions are **not** purged. "Permanent" does not apply to the in-app
  stored copy.
- **On export / share / print (§8):** permanence is produced. For every `redaction` rect on a page,
  the flatten step **burns a solid fill into the rasterized page pixels** and **drops every OCR word
  whose bounds intersect the rect** from any text carried into the exported artifact. Because the
  export is raster-composited and carries no live text/vector layer beneath the fill (§8), the
  shared file has **no recoverable content** under the mark — it is genuinely gone *in the artifact
  you hand out*.
- Redaction rects should snap to OCR word/line boxes (like §6) so users can redact "this phrase"
  precisely, but a freeform redaction rectangle is also allowed.

**Explicitly OUT of scope:** destroying the in-app stored original or purging history to make
redaction permanent *inside the app*. If ever wanted, that is a separate, deliberate, irreversible
"apply redactions" action — not part of this spec.

---

## 8. Feature E — Export / Flatten pipeline

Hooks into the existing `_savePdfToStorage` / `_sharePdf` / `_printPdf` in the viewer. When a
document has any (non-deleted) annotations, those actions export the **flattened** bytes instead of
the raw `pdfBytes`; a document with no annotations exports the raw bytes unchanged (current behaviour).

Per page:
1. Rasterize the page at an **export DPI** (higher than the 150 DPI screen raster — e.g. ≥200–300
   for print quality), using `Printing.raster` / `PdfPageRenderer`.
2. Composite annotations onto the raster in `z` order using the `image` package (or a Flutter
   `Canvas` → image), mapping each annotation's normalized geometry to export pixels.
3. For `redaction` annotations, paint a **solid opaque fill** (not translucent) so nothing shows
   through, and exclude intersecting OCR words from any text emitted for that page.
4. Re-wrap all composited page images into a new PDF via the `pdf: ^3.13.0` package (one image per
   page), producing the export artifact.

Consequences to document for users where relevant:
- Exported pages become **images** — the original selectable/embedded text is not present in the
  *export* (the stored original keeps it). This is acceptable for the share/print use case and is
  what makes redaction unrecoverable in the artifact.
- The stored encrypted document is **never overwritten** by export; flatten always yields a new
  artifact the user saves/shares/prints.

---

## 9. Feature F — Sync & merge

- Annotations ride the existing crypto-blind sync path as encrypted per-document(-per-page) blobs.
  The backend sees only ciphertext + a revision, exactly like notes and OCR data.
- **Merge is deliberately simple** (annotations are append-friendly, unlike note prose):
  - Union all annotation objects across replicas by `id`.
  - For the same `id` present on both sides, **last-writer-wins by `updatedAtMs`**.
  - `deleted: true` is a tombstone and wins over an older edit; a newer edit after a delete resurrects
    (standard LWW on `updatedAtMs`).
- No interactive conflict UI is required for annotations (contrast the note `ConflictResolutionScreen`).
  Collisions on the same object are rare and resolve automatically.

---

## 10. Feature G — Embedded text-layer extraction (hybrid, per page) — separate workstream

**Goal:** for born-digital PDFs (the common case for study material), use the PDF's embedded text
layer for text geometry instead of OCR — more accurate marks, exact copy, no OCR cost — while
image-only pages still fall back to OCR.

**This is net-new code** (see §1.4 correction): the HANDOFF-described extractor does not exist in
the current tree. The HANDOFF §51/§54 descriptions (lazy `startxref`/xref parsing, content-stream
tokenization, 5 s budget) are a **reference** for how to build it, not existing code to extend.

Design:
1. **Per-page, not per-document.** Mixed PDFs (some text pages, some scanned images, or an invisible
   pre-baked OCR layer) must decide page by page.
2. **Extract geometry, not just text.** Walk the content stream, track the text matrix (`Tm`) and
   CTM, and emit per-word boxes from glyph positions + font metrics, converted to **top-left
   normalized** `NormalizedRect`. Must correctly apply **CropBox vs MediaBox** and page **`/Rotate`**
   — getting these wrong offsets marks from the visible text (a very visible bug).
3. **Quality gate per page.** Use the embedded layer only when the page has enough extractable text,
   a valid `ToUnicode` mapping, and plausible glyph coverage. Otherwise fall back to OCR for that
   page. Watch for **subset fonts without `ToUnicode`** (display fine, extract garbage) and
   **invisible/approximate pre-baked OCR layers**.
4. **Unify output.** Both sources populate the **same** `OcrPage` / `NormalizedRect` structure, so
   the annotation layer, search, and copy are source-agnostic. Record provenance per page
   (`embedded` vs `ocr`).
5. **Run on the background isolate** (existing `compute()` pattern), like OCR.

**Sequencing:** the annotation layer (§4–§9) ships first on OCR geometry. When Feature G lands,
born-digital pages transparently get sharper geometry with no change to the annotation layer.

---

## 11. Annotation index panel — roadmap (not v1)

A side panel listing every annotation (type, page, text/snippet) with tap-to-jump and filter by
type/color. Natural fit for the reading focus; also lets annotation/comment text feed the existing
global search (which already indexes OCR text). Deferred from v1 but designed-for by the per-page
data model (§4.2).

---

## 12. Out of scope / non-goals (decided)

- **No interactive/native PDF-edit library** (pdfrx, Syncfusion, etc.) — §2 option 3.
- **No in-app-permanent redaction / history purge** — §7.
- **No signatures, stamps, typed-text boxes, callouts, measurement tools** — the brainstorm raised
  these; this effort is scoped to freeform + text-anchored + redaction for the reading use case.
- **No annotation of `webSnapshot` documents** (different viewer).
- **No editing of the original PDF content** (text, pages) — annotation is overlay-only.

---

## 13. Phasing / suggested build order

1. **Foundation (§4):** data model, encrypted per-page storage + Drift table/migration,
   coordinate-mapping helper, overlay `CustomPaint`, tool-mode gesture arbitration, undo/redo + autosave.
2. **Freeform tools (§5):** ink, highlighter, shapes, eraser, ruler/snap. Shippable with no OCR
   dependency — proves the whole overlay + storage path end to end.
3. **Text-anchored tools (§6):** highlight/underline/strikethrough/squiggly, select→copy, comment,
   on OCR geometry.
4. **Redaction (§7)** + **export/flatten (§8):** redaction is only meaningfully "permanent" once the
   flatten path exists, so build them together.
5. **Sync & merge (§9):** wire annotation blobs into the crypto-blind sync with union/LWW merge.
6. **Zoom crispness (§4.6)** and **annotation index panel (§11):** polish, any time after v1.
7. **Embedded text extraction (§10):** independent workstream; sharpens §6/§7 when it lands.

---

## 14. Open questions (none blocking; resolve during build)

- Exact **export DPI** and resulting file-size ceiling for large PDFs (§8).
- Whether the **highlighter** blend should be multiply or screen for best legibility on both light
  scans and dark text (§5).
- Default **tool palette placement** on phone vs tablet, and whether it floats or docks (§4.5).
- Zoom-in **DPI re-raster threshold** and memory budget for the swapped high-DPI page image (§4.6).

---

## 15. File touchpoints (anticipated — confirm when implementing)

- `lib/core/documents/presentation/document_viewer_screen.dart` — overlay, tool palette, mode
  arbitration, export hooks.
- `lib/core/documents/` — annotation model, repository/service, encryption (reuse OCR crypto family).
- `lib/core/database/app_database.dart` — new `DocumentAnnotationsTable` + schema bump + migration.
- Sync layer — new annotation blob entity on the crypto-blind push/pull path.
- Export — flatten utility bridging `Printing.raster`/`PdfPageRenderer` + `image` compositing + `pdf`
  re-wrap.
- `lib/core/ocr/` — Feature G extractor (net-new), emitting into the existing `OcrPage` structure.

> When implementing, follow `AGENTS.md`: run `flutter analyze` + `flutter test` (zero warnings),
> update `HANDOFF.md` with the architectural changes, then commit with a conventional message.
