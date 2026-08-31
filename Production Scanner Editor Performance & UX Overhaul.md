# Quiet Paper — Production Scanner Editor Performance & UX Overhaul

## Context

You are working inside the existing **Quiet Paper** Flutter application.

Before making any changes, read the repository's `HANDOFF.md` in full and inspect the current scanner/document implementation, especially:

- `DocumentScannerScreen`
- `ScannedPage`
- `ImageAdjustments`
- `DocumentNormalizer`
- `PdfBuilder`
- `PageAdjustmentSheet`
- scanner-related providers/controllers/services
- `DocumentProcessingService`
- `DocumentViewerScreen`
- `QuietDocumentCard`
- scanner/document tests

Do not invent a parallel architecture if the existing architecture can be improved cleanly.

The existing product already has:

- camera-based document scanning
- multi-page scanning
- page thumbnails
- retake/delete/reorder/add-page
- non-destructive crop/rotation/brightness/contrast/saturation/grayscale adjustments
- a reduced-resolution preview pipeline
- local PDF generation
- encrypted document persistence
- asynchronous OCR/document processing
- document embedding into Markdown notes
- on-device OCR
- encrypted cloud synchronization

The current scanner editor, however, feels slow and unreliable during editing. In particular:

1. Image adjustments can feel laggy.
2. Slider interaction does not feel immediate.
3. The displayed image sometimes does not update when an adjustment changes.
4. Older asynchronous processing can potentially overwrite newer visual state.
5. Multi-page editing should feel instantaneous even when several pages exist.
6. Expensive image/PDF/OCR work must never block the interactive editing loop.

This task is a **scanner editor quality and architecture overhaul**.

The goal is:

> Make the scanner editor feel like a polished native document-scanning application: immediate, deterministic, smooth, touch-friendly, visually calm, and resilient under multi-page editing.

Do not add unnecessary “AI” features or gimmicks.

---

# 1. Non-Negotiable Product Principles

## 1.1 The document image is the primary UI

The scanner editor should feel like the user is editing a physical document, not filling out a settings form.

The page preview occupies most of the screen.

Controls remain secondary.

Do not make the interface visually heavy.

Maintain Quiet Paper's warm editorial aesthetic.

Do not introduce generic Material-card-heavy scanner UI.

Prefer:

- restrained controls
- soft surfaces
- subtle dividers
- minimal elevation
- large touch targets
- clear hierarchy
- calm animations

---

# 2. Critical Performance Requirement

The scanner editor must maintain a highly responsive interactive loop.

During:

- brightness slider movement
- contrast slider movement
- saturation slider movement
- crop dragging
- rotation
- page switching

the UI must NOT:

- decode the original camera image repeatedly
- encode JPEG/PNG repeatedly
- rebuild full-resolution image bytes
- rebuild the entire PDF
- run OCR
- encrypt the final document
- upload to cloud storage
- sync
- perform expensive database writes
- run expensive synchronous image processing on the UI isolate

The interactive editing path must operate against a **small preview representation**.

The existing handoff specifies a downscaled preview around 600px specifically for responsive real-time adjustment while preserving the high-resolution source for final compilation. Preserve and enforce that architectural intent.

---

# 3. Establish a Single Source of Truth for Page Editing State

Introduce or refactor toward a clearly defined immutable editing state.

Conceptually:

```text
ScannedPage
 ├── original/high-resolution source
 ├── preview representation
 ├── dimensions
 ├── page identity
 └── ordering metadata

PageEditorState
 ├── crop
 ├── rotationQuarterTurns
 ├── brightness
 ├── contrast
 ├── saturation
 └── grayscale
```

The adjustment state is the source of truth.

Do not maintain several independently mutable copies of:

- crop
- transformed image
- displayed image
- thumbnail image
- adjusted bytes
- normalized bytes

unless there is a compelling performance reason and clear invalidation semantics.

Every visible preview must derive from the same `PageEditorState`.

When the state changes, the preview must immediately reflect the new state.

---

# 4. Preview Image Lifecycle

## 4.1 Decode once

When a page is captured/imported:

1. Acquire the source image.
2. Preserve the original/high-resolution source for final document generation.
3. Decode/create a preview representation once.
4. Downscale the preview to a bounded working size.
5. Cache that preview in memory for the scanner editing session.

Target approximately 600px on the longest side, matching the existing design intent.

Do not recreate the 600px preview for every slider event.

Bad:

```text
slider event
→ decode original
→ resize
→ process
→ encode
→ display
```

Good:

```text
page loaded
→ decode original once
→ create preview once
→ cache preview

slider event
→ update adjustment state
→ render from cached preview
```

---

# 5. Preview Rendering Architecture

Implement a lightweight preview renderer whose job is:

```text
cached preview bitmap
+
PageEditorState
→
visual preview
```

The renderer should avoid unnecessary byte serialization.

For the interactive preview:

- favor display-time transforms when possible
- apply clipping for crop
- apply transforms for rotation
- use efficient color/filter operations for brightness/contrast/saturation/grayscale
- avoid repeatedly writing encoded image bytes

If Flutter's rendering APIs permit the transformation to remain at the rendering layer, use that rather than repeatedly producing new image files.

The preview renderer must be deterministic.

Given:

```text
PreviewImage X
Adjustments Y
```

the displayed result must always represent `X + Y`.

---

# 6. Crop Interaction

Replace any “settings-style” crop behavior with a directly manipulable crop surface.

The user should see the page and a crop rectangle simultaneously.

Outside the crop rectangle, show a restrained dimming overlay.

Provide draggable handles/corners/edges.

Crop manipulation must update continuously while dragging.

Do not require:

```text
drag
→ Apply
→ wait
→ image changes
```

Instead:

```text
drag
→ crop state updates
→ crop viewport updates immediately
```

The actual image bytes do not need to be regenerated during dragging.

Use normalized crop coordinates so crop state remains resolution-independent, consistent with the existing model. The existing scanner architecture already uses normalized crop geometry.

Requirements:

- pinch-to-zoom support where appropriate
- pan support when zoomed
- crop handles remain touch-friendly
- clamped crop bounds
- sensible minimum crop dimensions
- smooth drag behavior
- no jumping when the gesture begins
- correct behavior after rotation
- correct behavior after page switching
- correct behavior after restoring previous adjustments

---

# 7. Rotation

Keep the existing quarter-turn model:

```text
0
90°
180°
270°
```

Do not replace it with a continuous free-rotation editor.

A tap on Rotate Left/Right must:

1. update the adjustment state immediately
2. animate the displayed preview
3. preserve crop state correctly
4. avoid expensive image encoding
5. update the selected page's thumbnail appropriately

Animation target:

- approximately 180–220 ms
- ease-out
- subtle
- no excessive spring/bounce

The canonical adjustment remains the stored rotation parameter rather than a mutated bitmap.

---

# 8. Tone Controls

Existing supported adjustment parameters remain:

- brightness: `-1.0 → 1.0`
- contrast: `-1.0 → 1.0`
- saturation: `-1.0 → 1.0`
- grayscale: boolean

Do not remove these capabilities.

However, redesign the UI so the user is not confronted with a wall of technical controls.

Recommended organization:

```text
Crop

Transform
  Rotate Left
  Rotate Right

Appearance
  Original
  Auto
  B&W

Fine Tune
  Brightness
  Contrast
  Saturation
```

Saturation may live under an expandable “Fine Tune” section.

The UI should prioritize common document-scanning workflows over exposing every technical adjustment immediately.

---

# 9. Add Preset Modes

Introduce lightweight scanner presets:

### Original
No tone adjustment.

### Auto
Use the existing normalization pipeline where possible.

### B&W
Document-oriented monochrome presentation.

Do not build a complicated “filter marketplace.”

Presets should merely write/update the existing adjustment state.

They must remain non-destructive.

For example:

```text
Auto
→ adjustment values

B&W
→ grayscale = true
```

rather than creating permanently transformed image files.

---

# 10. Before/After Interaction

Add a touch-friendly before/after comparison.

Long-press / press-and-hold on the preview should temporarily display the original, unadjusted preview.

Release should restore the edited state.

Interaction:

```text
press
→ Original

release
→ Edited
```

This should be entirely display-state based.

Do not regenerate the image just to perform comparison.

The user should immediately understand what their adjustments changed.

---

# 11. Document Detection Feedback

The scanner already has page-boundary confidence/normalization concepts.

Make detection visually understandable without clutter.

During capture:

```text
page detected
```

can be represented by a subtle document outline.

When confidence is high:

- outline becomes visually confident
- corners gently snap toward the detected page boundary

When confidence is poor:

- use a neutral outline
- do not pretend detection is certain

Do not add exaggerated glowing effects.

The scanner should feel calm and trustworthy.

---

# 12. Page Strip

The scanner already supports multi-page workflows and page management.

Retain:

- page count
- thumbnails
- add page
- delete
- retake
- move left
- move right

But make the thumbnail strip lightweight.

Each thumbnail should be:

- compact
- visually quiet
- easy to touch
- obviously selectable

Selected page gets a subtle accent outline.

Do not rebuild every preview when one page is changed.

Each page must own its editing state independently.

For example:

```text
Page 1
  preview
  adjustments

Page 2
  preview
  adjustments

Page 3
  preview
  adjustments
```

Changing Page 2 must not mutate Page 1 or Page 3.

---

# 13. Per-Page State Isolation

Give each scanned page a stable identity.

Do not rely exclusively on array index.

Example conceptual model:

```text
ScannedPage
  id
  originalSource
  previewSource
  adjustments
  dimensions
  order
```

When pages are reordered:

- page identity remains stable
- adjustment state stays attached to the correct page
- cached preview stays associated with the correct page
- OCR/document metadata never accidentally follows the wrong array index

This is especially important after:

```text
Page 5 → Move Left
Page 4 → Move Right
Delete Page 2
```

---

# 14. Async Preview Race Protection

This is mandatory.

Any asynchronous preview processing operation must use a generation/version token.

Conceptually:

```text
render request 41
render request 42
render request 43
```

Only request 43 can commit the visual result.

If request 41 finishes after request 43:

```text
discard request 41
```

It must never overwrite the current state.

Use an explicit generation counter/token per page or editor session.

Example:

```dart
final generation = ++_previewGeneration;
final result = await render(...);

if (generation != _previewGeneration) {
  return;
}
```

Do not rely on timing assumptions.

This directly addresses the class of bug where an older render completes after a newer adjustment and the preview appears to “jump backwards.”

---

# 15. Cancellation

Where the underlying APIs permit it, preview jobs should be cancellable.

If:

```text
brightness = 0.1
brightness = 0.2
brightness = 0.3
brightness = 0.4
```

the system should not spend resources completing obsolete expensive work.

At minimum:

- stale jobs must be ignored
- new work supersedes old work
- resources associated with obsolete work should be released as soon as safely possible

---

# 16. Immediate UI Feedback vs Expensive Processing

Do not debounce visual feedback.

Dragging a slider must visibly move the preview immediately.

Instead, separate:

### Interactive visual state

Immediate.

### Expensive committed processing

Debounced / deferred.

Architecture:

```text
gesture
  ↓
PageEditorState update
  ↓
immediate preview update

        ↓
interaction settles
        ↓
optional expensive normalization/preparation
```

Do not make the user wait for a timer before seeing what they did.

---

# 17. Keep Final Processing Completely Separate

The editing screen must never:

- generate the final PDF on every adjustment
- OCR every adjustment
- encrypt the document every adjustment
- upload every adjustment
- trigger sync every adjustment

The scanner editor is responsible for editing page state.

The final pipeline begins only after the user presses **Done**.

Conceptually:

```text
EDITING

page states
↓
Done

FINALIZATION

high-resolution source
↓
apply final adjustments
↓
normalize
↓
build PDF
↓
encrypt
↓
persist
↓
enqueue OCR
↓
return to note
```

The existing architecture already separates document processing into an asynchronous lifecycle (`queued → processing → available/failed`). Preserve that separation.

---

# 18. Final PDF Must Use High-Resolution Source

Never use the 600px editor preview as the final document source.

The preview exists only to make editing responsive.

Final PDF compilation must use:

- original/high-resolution capture
- original dimensions
- final crop
- final rotation
- final tone settings
- final normalization

This preserves document quality.

The existing `ScannedPage`/`DocumentNormalizer`/`PdfBuilder` architecture should be retained unless a concrete defect requires refactoring. The handoff specifies that the original high-resolution capture is preserved and the final PDF is generated from high-resolution data. 
---

# 19. OCR Isolation

OCR must remain completely outside the interactive editing loop.

After final document creation:

```text
PDF created
↓
document persisted
↓
OCR queued asynchronously
```

Do not:

```text
change contrast
↓
OCR
↓
update UI
```

The user should be able to return to the note while OCR continues in the background.

The existing OCR architecture is explicitly on-device and asynchronous. Preserve that security and lifecycle model.

---

# 20. Scanner Screen UX

Redesign the scanner editor around this hierarchy:

```text
                    Quiet Paper

                     2 / 5

              ┌─────────────────┐
              │                 │
              │                 │
              │      PAGE       │
              │                 │
              │                 │
              └─────────────────┘

          page thumbnails / strip

           Crop   Transform   Adjust

              contextual controls

      Cancel                         Done
```

The page should dominate the screen.

Avoid:

- huge top app bars
- giant cards
- dense form rows
- unnecessary descriptive paragraphs
- multiple nested modals

---

# 21. Adjustment Sheet

Retain the concept of a `PageAdjustmentSheet`, but make it a lightweight interactive tool rather than a settings dialog.

It should contain the live preview and controls together.

Recommended modes:

### Crop & Rotate

- crop rectangle
- rotate left
- rotate right
- reset

### Tone & Exposure

- Auto
- Original
- B&W
- brightness
- contrast
- saturation

The existing handoff describes these tabs and live preview behavior; preserve the conceptual organization while improving implementation and responsiveness.

---

# 22. Gestures

Support the following interactions where they do not conflict with the platform:

### Preview

- pinch to zoom
- pan when zoomed
- double tap → reset zoom
- press-and-hold → original comparison

### Crop

- drag edges/corners
- pinch/zoom while positioning the document where useful

### Pages

- swipe left → next page
- swipe right → previous page

### Navigation

Do not make horizontal page swipes interfere with crop dragging or image panning.

Gesture arbitration must be deliberate.

Do not stack multiple competing gesture recognizers that produce accidental page changes.

---

# 23. Zoom State

Maintain zoom separately from image-editing parameters.

Zoom is a presentation state, not a document adjustment.

Example:

```text
PageEditorState
  crop
  rotation
  brightness
  contrast
  saturation
  grayscale

PreviewViewportState
  zoom
  panOffset
```

Do not serialize zoom as part of the document.

When switching pages:

- reset or restore zoom predictably
- never inherit the previous page's zoom accidentally

Recommended default:

```text
page switch → fit to page
```

---

# 24. Thumbnail Rendering Strategy

Do not use the full-size original for thumbnails.

Every page should have a lightweight thumbnail/preview representation.

Recommended hierarchy:

```text
thumbnail
≤ 200px class representation

editor preview
≈ 600px longest side

final source
original/high-resolution
```

Avoid unnecessary duplicate decoding.

Cache these representations during the scanner session.

Release them when the scanner is disposed or when memory pressure requires it.

---

# 25. Memory Management

The scanner must handle multi-page sessions responsibly.

A user should be able to scan multiple pages without the app accumulating unbounded decoded bitmaps.

Use:

- bounded preview sizes
- cached decoded previews
- appropriate eviction
- lazy thumbnail decoding
- original bytes retained only as necessary
- disposal of image/codec resources
- no duplicate copies unless justified

The design must balance:

```text
performance
vs
memory
vs
final image quality
```

Do not solve performance by retaining every full-resolution decoded bitmap forever.

---

# 26. Page Editing Does Not Persist Every Gesture

Do not continuously perform expensive SQLite updates for every slider tick.

During an adjustment session:

```text
UI state in memory
```

At appropriate commit boundaries:

- adjustment session settled
- page switched
- editor closed
- scanner completed

persist only the necessary document/page state.

Do not flood Drift/SQLite with dozens of writes per second.

---

# 27. Preserve Existing Security Guarantees

Do not weaken the scanner's existing zero-knowledge architecture.

The current architecture requires:

- document data encrypted client-side
- encrypted OCR
- encrypted document storage
- cloud payloads remaining inaccessible to the backend
- no plaintext OCR sent to third-party services

Do not introduce a remote image-processing API.

Do not upload source images just to perform crop/filter operations.

Do not store plaintext scanned documents in persistent cloud storage.

The scanner's canonical document resource remains:

```text
qp://document/<UUID>
```

and the final document remains a standard PDF payload internally wrapped by the existing encryption architecture.

---

# 28. Preserve Existing Note Integration

Do not change how scanned documents are embedded in Markdown.

The scanner must continue to insert:

```text
[Scanned Document](qp://document/<UUID>)
```

or the existing equivalent canonical resource reference.

The existing Markdown-as-source-of-truth architecture must remain untouched.

Scanner improvements must not introduce a custom rich-text or document JSON representation.

---

# 29. Preserve Existing Document Lifecycle

Do not break:

- local persistence
- backup
- restore
- sync
- encrypted cloud storage
- deletion/tombstones
- OCR
- document cards
- document viewer
- Markdown preview embedding

Scanner improvements should be isolated to the editing/capture path unless a supporting change is required.

---

# 30. “Auto” Normalization

Use the existing `DocumentNormalizer` rather than inventing a separate normalization engine.

Existing normalization concepts include:

- contrast adjustment
- maximum dimension bounding
- boundary confidence scoring

Preserve those semantics.

If the current implementation is expensive:

- move expensive work off the UI isolate
- cache results
- avoid repeated normalization
- make it an explicit finalized-document operation

---

# 31. State Transitions

Make the scanner editor state explicit.

Recommended conceptual states:

```text
idle
capturing
editing
finalizing
completed
error
```

Per-page preview state may additionally have:

```text
ready
rendering
stale
```

Do not let arbitrary async callbacks mutate the UI after the editor has been disposed.

Every async operation must verify:

- current editor/session identity
- current page identity
- current generation token

before committing results.

---

# 32. Error Handling

Errors must never produce a blank image without explanation.

If preview rendering fails:

show:

> Unable to preview this adjustment.

with:

> Retry

and preserve the underlying page/source state.

If finalization fails:

- do not destroy the scan
- keep the in-memory pages
- allow retry
- do not lose the user's adjustments

If OCR fails:

- the PDF must remain usable
- OCR failure must be independent of document creation
- existing OCR retry behavior should remain supported

The handoff already provides OCR failure/retry semantics. Preserve them.

---

# 33. Loading UI

Avoid fake or blocking loading screens during normal adjustments.

Do NOT show:

```text
Loading...
```

every time the slider moves.

The editor should feel immediate.

Reserve progress indicators for genuinely long operations:

### Finalization

```text
Preparing document…
Optimizing pages…
Building PDF…
```

### OCR

```text
Processing text…
```

These operations occur after editing and remain independent.

---

# 34. Accessibility

All interactive controls must have:

- semantic labels
- sufficient contrast
- touch targets of at least the existing app's accessible minimum
- meaningful tooltips where appropriate
- support for screen readers
- support for reduced motion

Do not sacrifice usability for the minimalist visual design.

---

# 35. Responsive Layout

Scanner behavior must work correctly on:

- small Android phones
- large Android phones
- tablets
- landscape orientation
- desktop/simulator fallback where camera hardware is unavailable

The existing application supports fallback document import for environments without camera hardware. Preserve it.

Do not design only for one phone aspect ratio.

---

# 36. Tablet UX

On tablets, use the additional width intelligently.

Potential arrangement:

```text
┌───────────────────────────────┬───────────────┐
│                               │ page controls  │
│                               │               │
│          PAGE                 │ thumbnails     │
│                               │               │
│                               │ adjustment     │
│                               │ controls       │
└───────────────────────────────┴───────────────┘
```

Do not merely scale the phone UI to enormous dimensions.

Keep the document centered at a comfortable reading/editing size.

---

# 37. Avoid Rebuilding the Whole Scanner Screen

Changing:

```text
brightness
```

must not rebuild:

- camera preview
- every thumbnail
- every page model
- OCR state
- document metadata
- unrelated controls

Use localized state updates.

Similarly, selecting a page should only change the necessary page/editor regions.

Structure widgets so rebuild boundaries are intentional.

Use appropriate:

- selectors
- `ValueNotifier`
- Riverpod selectors
- `AnimatedBuilder`
- immutable state
- const widgets
- memoized representations

according to the existing architecture.

Do not introduce state-management patterns that conflict with the app's current architecture without justification.

---

# 38. Measure Performance

Add development instrumentation sufficient to prove the editor is fast.

Measure at minimum:

- preview creation time
- preview render time
- full-resolution decode time
- final image processing time
- PDF compilation time
- page switch time
- thumbnail generation time
- number of stale preview jobs discarded
- number of preview renders triggered per slider gesture

The goal is not merely “it seems faster.”

We should be able to identify regressions.

---

# 39. Performance Targets

Set practical targets:

### Page switching

Target perceived response:

```text
< 100ms
```

for already-cached pages.

### Slider interaction

Preview should visually respond continuously and should not exhibit obvious input lag.

Target:

```text
~60fps where device capability permits
```

The existing handoff explicitly targets responsive 60fps real-time adjustment behavior.

### Crop dragging

No noticeable hitching during normal manipulation.

### Rotation

Immediate response with subtle animation.

### Opening adjustment UI

Should not re-decode the entire original source every time.

---

# 40. Testing Requirements

Do not consider this work complete without extensive tests.

## Unit tests

Add/expand tests for:

### Adjustment state

- default values
- crop changes
- rotation changes
- brightness
- contrast
- saturation
- grayscale
- reset

### Crop

- bounds clamping
- minimum dimensions
- normalized coordinates
- rotated-page crop behavior

### Page identity

- reorder preserves page identity
- delete does not shift state to another page
- page adjustments remain attached to the correct page

### Generation tokens

Verify:

```text
job A starts
job B starts
job B completes
job A completes
```

and job A is ignored.

### Preview derivation

Given identical source + adjustments:

- result is deterministic

### Reset

Reset must restore the original editing state without modifying the source.

---

# 41. Widget Tests

Test the complete user-facing flows:

### Crop

1. Open page.
2. Enter crop.
3. Drag crop handle.
4. Verify visual state changes.
5. Exit crop.
6. Re-enter.
7. Verify adjustment persisted.

### Brightness

1. Open adjustments.
2. Move brightness.
3. Verify preview changes.
4. Verify no unrelated page rebuild behavior.
5. Reset.
6. Verify original preview restored.

### Rotation

1. Rotate clockwise.
2. Verify page preview rotates.
3. Rotate again.
4. Verify 180°.
5. Switch pages.
6. Return.
7. Verify page's rotation remains correct.

### Multi-page

1. Capture/import 5 pages.
2. Modify page 1.
3. Modify page 3.
4. Reorder pages.
5. Verify modifications remain attached to their original page identities.
6. Delete a page.
7. Verify remaining states remain correct.

### Async race

Simulate out-of-order completion and verify stale results cannot overwrite the current preview.

### Done

1. Edit several pages.
2. Press Done.
3. Verify final PDF uses high-resolution source.
4. Verify document is persisted.
5. Verify Markdown document reference is inserted.
6. Verify OCR is queued independently.

---

# 42. Integration Tests

Verify the complete scanner lifecycle:

```text
capture
→ edit
→ reorder
→ finalize
→ PDF
→ encrypt
→ persist
→ OCR queue
→ note integration
```

Verify that the scanner remains compatible with:

- backup
- restore
- sync
- document viewer
- document card
- global search/OCR
- trash/deletion lifecycle

---

# 43. Regression Tests for Existing Behavior

Do not regress:

- camera capture
- simulator/desktop fallback
- multi-page scanning
- retake
- delete
- add page
- reorder
- PDF creation
- encryption
- OCR
- document embedding
- note autosave
- document thumbnails
- sync
- backup/restore

Run the complete Flutter test suite after implementation.

Also run:

```bash
flutter analyze
flutter test
```

Fix all issues introduced by this work.

---

# 44. Repository Inspection Requirement

Before coding:

1. Locate all scanner-related files.
2. Trace the current data flow from:
   - camera capture
   - page creation
   - preview generation
   - adjustment changes
   - thumbnail creation
   - final PDF
3. Determine exactly why the current image preview sometimes fails to update.
4. Determine whether expensive work is happening on the UI isolate.
5. Determine whether image bytes are re-decoded or re-encoded during slider interaction.
6. Determine whether asynchronous callbacks can race and overwrite state.
7. Determine whether page state is indexed by array position rather than stable identity.
8. Determine whether the existing 600px preview architecture is actually being used as intended.

Do not assume the handoff's intended architecture is perfectly implemented.

The task is to reconcile the implementation with the intended architecture.

---

# 45. Root-Cause-First Requirement

Before performing a broad refactor, document the actual problems you find.

At minimum identify:

```text
Problem
Root cause
Current behavior
Desired behavior
Fix
Tests covering the fix
```

Do not simply rewrite the scanner because it “looks cleaner.”

Preserve working behavior and change only what is necessary to achieve the desired quality.

---

# 46. Do Not Introduce Unnecessary Dependencies

Prefer the project's existing Flutter packages and architecture.

Do not add a large image-processing dependency merely to solve a UI architecture problem.

Do not add a remote service.

Do not replace the existing scanner/PDF/OCR architecture unless a concrete incompatibility requires it.

Any newly introduced package must have a clear justification.

---

# 47. Do Not Break Canonical Data Semantics

The scanned document remains:

```text
camera/import
→ ScannedPage(s)
→ PDF
→ encrypted document
→ qp://document/<UUID>
```

The Markdown note remains the source of truth for the document reference.

Do not create:

- scanner-specific rich JSON documents
- HTML as canonical storage
- proprietary page formats
- alternate note representations

The scanner's editing model is presentation/editing state, not a second document source of truth.

---

# 48. Final UX Goal

When this work is finished, the experience should feel like this:

### Capture

The camera sees a page.

The page boundary is clear.

The user captures it.

### Immediately

The captured page appears.

No blank intermediate image.

No unexplained delay.

### Edit

The user drags crop handles.

The preview follows their finger.

The user adjusts contrast.

The preview responds immediately.

They tap Rotate.

The page smoothly rotates.

They press and hold.

Original image appears.

They release.

Edited image returns.

### Multi-page

They swipe to page 2.

Page 2 appears immediately.

They edit it.

They return to page 1.

Page 1 is exactly as they left it.

### Done

They press Done.

Only now does expensive final processing begin.

The document is generated from high-resolution source.

The PDF is encrypted.

The document is saved.

The note receives the document reference.

The user returns to writing.

OCR continues independently.

Nothing about OCR, encryption, cloud upload, or PDF generation interferes with the editing experience.

---

# 49. Acceptance Criteria

This task is complete only when all of the following are true:

- [ ] Existing scanner functionality remains intact.
- [ ] Preview image updates immediately when adjustments change.
- [ ] Slider dragging does not require full-resolution image processing.
- [ ] Original/high-resolution source is not repeatedly decoded.
- [ ] 600px-class preview representation is cached and reused.
- [ ] Crop manipulation is directly interactive.
- [ ] Crop preview responds continuously.
- [ ] Rotation feels immediate.
- [ ] Before/after press-and-hold comparison works.
- [ ] Presets exist for Original, Auto, and B&W.
- [ ] Fine adjustment controls remain available.
- [ ] Multi-page pages have stable identities.
- [ ] Page reorder preserves page-specific adjustments.
- [ ] Page deletion cannot attach adjustments to the wrong page.
- [ ] Thumbnail rendering does not unnecessarily decode full-resolution sources.
- [ ] Preview render generation tokens prevent stale async results from overwriting current state.
- [ ] Obsolete asynchronous preview work is cancelled or safely ignored.
- [ ] No OCR occurs during interactive editing.
- [ ] No PDF compilation occurs during interactive editing.
- [ ] No cloud upload occurs during interactive editing.
- [ ] No expensive synchronous work blocks the UI isolate during normal editing.
- [ ] Final PDF still uses high-resolution sources.
- [ ] Encryption remains client-side.
- [ ] OCR remains on-device.
- [ ] Existing `qp://document/<UUID>` integration remains intact.
- [ ] Scanner works correctly on phones.
- [ ] Scanner works correctly on tablets.
- [ ] Simulator/desktop fallback remains functional.
- [ ] Accessibility is preserved.
- [ ] Reduced-motion behavior is respected.
- [ ] Unit tests cover adjustment state and race protection.
- [ ] Widget tests cover editing interactions.
- [ ] Integration tests cover capture → edit → finalize → document insertion.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.
- [ ] No unrelated Quiet Paper features are regressed.

---

# 50. Implementation Quality Bar

Do not stop at “the feature works.”

The implementation should be:

- production-ready
- deterministic
- testable
- memory-conscious
- responsive
- maintainable
- localized in scope
- consistent with Quiet Paper's existing architecture
- consistent with Quiet Paper's visual language

Avoid:

- temporary hacks
- arbitrary delays
- `Future.delayed()` used to mask race conditions
- rebuilding the whole screen to force image refreshes
- duplicate state sources
- unbounded image caches
- synchronous full-resolution processing during gestures
- swallowing exceptions
- silently dropping failed processing
- placeholder implementations

When complete, provide a concise implementation summary identifying:

1. the root cause of the existing slowness/update bug
2. the architecture used to fix it
3. the preview lifecycle
4. async race protection
5. page state model
6. finalization pipeline
7. tests added
8. any remaining limitations or device-specific considerations

Do not claim performance improvements without measuring the relevant path.