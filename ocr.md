# Quiet Paper — Flagship AI Coding-Agent Implementation Prompt

You are implementing the next major document subsystem for **Quiet Paper**, an offline-first Flutter notes application with a Bear-inspired editorial UI, Drift/SQLite local persistence, client-side zero-knowledge encryption, Firebase authentication, a Vercel/TypeScript backend, Turso/libSQL metadata storage, direct Cloudinary object storage, Markdown as the canonical note representation, and an existing image attachment system.

This is a **production implementation task**, not a conceptual prototype and not a greenfield rewrite.

You MUST inspect the actual repository before making architectural changes. Preserve existing project conventions, abstractions, database patterns, sync mechanisms, encryption architecture, UI language, editor architecture, authentication lifecycle, backup behavior, and testing style.

The existing handoff establishes several non-negotiable principles:

* Quiet Paper is offline-first.
* Note content is canonical.
* Markdown remains the canonical representation.
* Note title/body/tags are encrypted client-side.
* The backend and cloud storage are crypto-blind.
* The editor preserves a 1:1 mapping between Markdown source and editable text rather than introducing a rich-text document model.
* The sync system already has revision tracking, push/pull, cursor synchronization, idempotency, conflict handling, and offline queues.
  Preserve these foundations.

---

# 1. Feature Scope

Implement all of the following as one coherent document subsystem:

## Scanner

A dedicated **Scan Document** button immediately beside the existing image attachment button.

The scanner must support:

* camera preview
* automatic document boundary detection
* automatic page capture
* automatic perspective correction/document normalization
* manual crop correction after capture
* rotate
* brightness
* contrast
* saturation
* grayscale
* non-destructive adjustments
* retake
* page deletion
* page reordering
* multi-page scanning
* local PDF generation
* local encryption
* asynchronous local OCR
* direct encrypted Cloudinary upload
* offline operation

## PDF Import

Add the ability to manually attach an existing PDF to a note.

Imported PDFs must:

* become the same `document` resource type as scanned documents
* retain the original PDF as the canonical document payload
* be stored locally first
* be encrypted locally
* upload directly from Flutter to Cloudinary
* be referenced from Markdown via `qp://document/<UUID>`
* participate in the same sync/lifecycle architecture as scanned PDFs
* undergo text-layer extraction and/or OCR processing as described below

## OCR

Implement on-device OCR.

The user MUST be able to select the OCR language.

For the initial release, provide exactly one OCR language:

```text
English
```

Do not expose additional languages until they are intentionally implemented and tested.

The language-selection architecture MUST be extensible so additional languages can be added later without redesigning the OCR subsystem.

OCR must:

* run locally/on-device
* never upload plaintext document contents to a cloud OCR provider
* run asynchronously
* produce searchable text
* preserve page boundaries
* preserve positional/geometry data
* store OCR separately from the canonical PDF
* be encrypted before synchronization
* work for scanned documents and imported PDFs without an embedded text layer
* use existing PDF text extraction instead of OCR whenever a usable text layer already exists

---

# 2. Canonical Resource URI Architecture

Quiet Paper must now recognize three internal resource types:

```text
qp://asset/<UUID>
qp://document/<UUID>
qp://note/<UUID>
```

Semantics:

```text
qp://asset/<UUID>
    Existing ordinary image/file attachment.

qp://document/<UUID>
    Scanned or imported PDF document.

qp://note/<UUID>
    Future internal note-to-note link.
```

The `qp://` URI system MUST be implemented as a centralized, reusable abstraction.

Do not scatter raw string checks throughout the application.

Conceptually:

```text
QuietPaperUri
 ├── scheme
 ├── resourceType
 └── resourceId
```

The parser must:

* validate scheme
* validate resource type
* validate UUID/resource ID
* reject malformed URIs
* reject unsupported resource types
* serialize back to canonical form
* provide equality/hash semantics
* be independently unit tested

The exact class names may follow repository conventions.

---

# 3. Resource Resolution

Separate URI parsing from actual resource resolution.

Architecture:

```text
Markdown
   ↓
QuietPaperUri
   ↓
ResourceResolver
   ├── AssetResolver
   ├── DocumentResolver
   └── NoteResolver
```

The current implementation MUST fully support `asset` and `document`.

The `note` resource type MUST be recognized structurally and be ready for future linking, but the full note-linking feature is explicitly out of scope.

Markdown parsing must not directly:

* query Drift
* call Cloudinary
* decrypt resources
* navigate between screens

The parser identifies resources. Higher application/presentation layers resolve them.

---

# 4. Markdown Representation

A scanned or imported PDF is referenced by:

```markdown
[Scanned Document](qp://document/<UUID>)
```

or an appropriate user-facing title:

```markdown
[Quarterly Report](qp://document/<UUID>)
```

The UUID is the stable identity.

The title/display text is not the identity.

Changing the title must never change the URI.

Never store:

```markdown
[Document](https://res.cloudinary.com/...)
```

Never store local filesystem paths.

Never embed PDF bytes or Base64 in Markdown.

Never introduce a second canonical rich-text document representation.

The existing editor architecture must remain source-preserving and selection/caret-safe.

---

# 5. Document Domain Model

Introduce a first-class `Document` domain model.

Conceptually:

```text
Document
────────────────────────────────
id
noteId
source

mimeType
byteSize
pageCount
sha256

createdAt
updatedAt

encryptionKeyVersion

uploadState
isDirty
isDeleted
serverRevision
syncedAt

cloudObjectId
cloudVersion / cloud metadata
```

`source` MUST distinguish at minimum:

```text
scanner
importedPdf
```

Do not create separate resource types for scanner PDFs and imported PDFs.

They are both:

```text
qp://document/<UUID>
```

The source is metadata.

The canonical payload is always a PDF.

---

# 6. Document Identity and Immutability

The document UUID is its stable logical identity.

The SHA-256 hash is content identity/integrity metadata.

Do NOT use SHA-256 as the primary resource ID.

Do NOT mutate the canonical PDF associated with a document ID.

If a document is replaced, create a new document ID:

```text
old → qp://document/A
new → qp://document/B
```

and retire the old document through the normal tombstone/cleanup lifecycle.

This preserves stable resource identity.

---

# 7. Document Is the Canonical Resource for Both Scanner and PDF Import

Scanner:

```text
Camera
 ↓
Pages
 ↓
PDF
 ↓
Document
```

PDF import:

```text
PDF picker
 ↓
PDF
 ↓
Document
```

Both produce:

```text
qp://document/<UUID>
```

Both use:

* same encryption infrastructure
* same local storage infrastructure
* same Cloudinary upload architecture
* same sync infrastructure
* same viewer
* same OCR processing
* same deletion behavior
* same backup behavior

Do not duplicate these subsystems.

---

# 8. Scanner Button Placement

The current editor already contains an image attachment button.

Add the new **Scan Document** button directly adjacent to it.

Conceptually:

```text
...   link   image   scan   #
```

The scanner icon must clearly communicate document scanning.

The existing image attachment button must remain unchanged in purpose:

```text
image button = attach image
scanner button = scan document
```

Do not hide scanning behind the image button unless platform/layout constraints make a dedicated button genuinely impossible.

On narrow screens, an adaptive layout may move secondary insertion actions into an overflow, but the scanner should remain discoverable.

Follow the existing Quiet Paper visual language.

---

# 9. PDF Import UI

Also provide a **Add PDF** action.

The implementation may present:

### Phone

```text
Image
Scan Document
Add PDF
```

through an insertion sheet/menu if toolbar width requires it.

### Tablet/Desktop

The UI may expose dedicated actions if there is sufficient toolbar space.

Do not create a large media-management interface.

The scanner should remain the most prominent document-creation action.

---

# 10. Scanner Camera Workflow

Scanner flow:

```text
Editor
  ↓
Scan Document
  ↓
Full-screen scanner
  ↓
Camera preview
  ↓
Document detection
  ↓
Capture
  ↓
Page preview/edit
  ↓
Add another page OR Done
  ↓
Generate PDF
  ↓
Persist local document
  ↓
Insert Markdown reference
  ↓
Background OCR
  ↓
Background cloud sync
```

The note must never wait for network operations.

---

# 11. Automatic Document Detection

The scanner should automatically detect a rectangular document/page where possible.

When a confident boundary is detected:

* visually indicate the detected page
* automatically capture when the page is stable where practical
* provide a manual capture fallback

The detection system must gracefully handle:

* no page detected
* poor lighting
* skew
* partial page
* cluttered background
* low contrast
* camera permission failure

Do not crash or trap the user.

If advanced detection is unavailable on a target platform, provide a fallback camera capture path.

---

# 12. Automatic Perspective Correction

After capture, automatically correct document perspective.

The scanner may correct:

* trapezoidal distortion
* orientation
* obvious skew
* page geometry

This is automatic scanner normalization, not a user-facing image editor.

---

# 13. User-Visible Scanner Adjustments

After page capture, the user MUST have access to:

```text
Crop
Rotate
Brightness
Contrast
Saturation
Grayscale
```

These features are explicitly in scope.

Do NOT add:

* filters
* annotations
* drawing
* markup
* OCR editing
* AI cleanup
* background removal
* retouching
* arbitrary image effects

The image adjustment system must remain intentionally small and document-focused.

---

# 14. Non-Destructive Editing Architecture

Do not repeatedly encode/save the image for every adjustment.

Represent page edits as parameters.

Conceptually:

```dart
ImageAdjustments(
  crop: ...,
  rotationQuarterTurns: ...,
  brightness: ...,
  contrast: ...,
  saturation: ...,
  grayscale: ...,
)
```

The captured original remains the source for rendering.

The UI previews the adjustments.

Only when the page is finalized should the implementation render the final page bitmap used for:

* PDF generation
* OCR

This avoids cumulative JPEG/encoding loss.

---

# 15. Crop

Provide a simple manual crop UI.

Requirements:

* user can move crop boundaries
* preserve sensible minimum crop size
* page remains visually understandable
* support portrait/landscape documents
* use existing design language

Automatic document detection should suggest the initial crop.

The user can correct it manually.

Do not build an advanced photo editor.

---

# 16. Rotate

Initially support 90-degree increments:

```text
↶ Rotate left
↷ Rotate right
```

Do not implement arbitrary-angle free rotation unless the repository already contains infrastructure that makes it essentially free and robust.

Keep the first implementation predictable.

---

# 17. Brightness / Contrast / Saturation

Provide simple sliders.

Use normalized application-level values rather than exposing the image-processing library's raw numeric parameters directly.

Conceptually:

```text
brightness = 0.0 → neutral
contrast   = 0.0 → neutral
saturation = 0.0 → neutral
```

The UI maps these to suitable processing ranges.

Defaults MUST be neutral.

Changing an adjustment should update the preview without destructively rewriting the source.

---

# 18. Grayscale

Make grayscale a dedicated toggle.

Do not represent it merely as "saturation = zero."

Conceptually:

```text
Grayscale   ○ / ●
```

It should be composable with the other adjustments.

---

# 19. Multi-Page Scanning

The scanner must support:

* page 1
* page 2
* page 3
* ...
* additional pages

The user must be able to:

* add a page
* retake a page
* delete a page
* reorder pages

Page management is document organization, not image editing.

The scanner should retain temporary page data until the scan is completed or cancelled.

---

# 20. Canonical PDF Generation

After the scan session is complete:

```text
Final page 1
Final page 2
Final page 3
...
        ↓
PDF
```

The PDF is the canonical document payload.

The PDF must:

* preserve page order
* contain every final page
* use appropriate page dimensions
* preserve useful visual quality
* be standards-compliant
* be generated locally
* use MIME type `application/pdf`

Do not generate the canonical PDF on Vercel.

Do not upload raw page images to Vercel for PDF generation.

---

# 21. Original Capture Handling

During the scanner editing session, retain the unmodified captured page representation so adjustments can be recalculated non-destructively.

After successful PDF creation/persistence, temporary original page files may be cleaned up.

Do not permanently upload the raw camera pages as the document's cloud representation unless explicitly required by a future feature.

The canonical cloud representation is the encrypted final PDF.

---

# 22. Imported PDF

When the user chooses Add PDF:

```text
System/file picker
 ↓
Select PDF
 ↓
Validate
 ↓
Inspect metadata
 ↓
Persist locally
 ↓
Encrypt locally
 ↓
Create Document
 ↓
Insert Markdown reference
 ↓
Background text extraction/OCR
 ↓
Direct Cloudinary upload
```

Do not rewrite the original PDF merely to make it searchable.

Do not rasterize an imported text PDF unnecessarily.

Do not convert it into a scan.

---

# 23. PDF Canonical Integrity

For imported PDFs, preserve the original PDF bytes.

The imported PDF is the canonical document.

Do not regenerate it from rendered pages.

Do not strip metadata unnecessarily.

Do not modify user content.

If a thumbnail/preview is required, it is a derived presentation artifact.

---

# 24. PDF Text Layer Detection

Before OCRing an imported PDF:

```text
PDF
 ↓
inspect for usable embedded text
```

If it has a usable text layer:

```text
extract text
 ↓
normalize into Quiet Paper OCR representation
```

Do NOT render every page and OCR it unnecessarily.

If there is no usable text layer:

```text
render page
 ↓
OCR page
```

If the PDF has some text but not enough to be considered usable, document the heuristic and fall back to OCR appropriately.

---

# 25. OCR Architecture

Implement OCR behind an application-level interface.

Conceptually:

```dart
abstract class OcrService {
  Future<OcrDocumentResult> recognizeDocument(
    PdfSource document,
    OcrOptions options,
  );
}
```

Do not make the document domain directly depend on a specific OCR vendor/library.

Create a platform implementation behind it.

The initial implementation should use an on-device OCR engine compatible with Android/iOS and the current Flutter project.

A strong initial candidate is:

```yaml
google_mlkit_text_recognition
```

but verify current package/platform compatibility before adding it to `pubspec.yaml`.

The architecture MUST allow the OCR engine to be replaced later.

---

# 26. OCR Language Selection

The user MUST be able to select OCR language.

For this release, provide only:

```text
English
```

Do not expose other languages yet.

The UI should still use a model/enumeration designed for future extension:

```text
OcrLanguage
  english
```

or repository-appropriate naming.

Do not hard-code `"en"` throughout business logic.

Use an OCR-language configuration abstraction.

Later languages can be added without redesigning:

* database
* OCR service
* processing queue
* document viewer
* settings

The selected language MUST be stored per processing request/document as appropriate so OCR can be reproduced consistently.

---

# 27. OCR Language UI

Provide a simple document/OCR setting:

```text
OCR Language
English
```

The user can open a picker.

For the first release there is exactly one available option:

```text
English
```

Even with one option, implement the picker through the actual language model so the feature can expand later.

Do not show unsupported languages as disabled fake choices.

---

# 28. OCR Must Be Local

Plaintext documents MUST NOT be sent to an external OCR API.

The intended pipeline is:

```text
PDF/image
 ↓
Flutter/device
 ↓
on-device OCR
 ↓
OCR result
```

Never:

```text
PDF
 ↓
Vercel
 ↓
Cloud OCR
```

Never:

```text
PDF
 ↓
third-party OCR SaaS
```

unless the user explicitly authorizes a future cloud feature that is not part of this implementation.

---

# 29. OCR Processing Is Asynchronous

When a document is created:

```text
Document saved
 ↓
Markdown updated
 ↓
OCR job queued
 ↓
UI returns immediately
```

Do not block the user waiting for OCR.

The document should be usable while OCR runs.

The document can show a subtle state:

```text
4 pages · Processing text…
```

then:

```text
4 pages · Searchable
```

Do not display technical progress logs in the note.

---

# 30. OCR Processing Queue

Introduce a local document-processing queue or equivalent background-processing mechanism.

Conceptual jobs:

```text
generatePreview
generateThumbnail
extractPdfText
runOcr
```

The actual implementation may combine some jobs.

The architecture must support:

* queueing
* retry
* failure state
* cancellation where practical
* process restart recovery
* duplicate-job avoidance

Do not make OCR part of the synchronous `saveDocument()` path.

---

# 31. OCR State Machine

Use explicit state.

Conceptually:

```text
NOT_REQUESTED
    ↓
QUEUED
    ↓
PROCESSING
    ↓
AVAILABLE
```

Failure:

```text
PROCESSING
    ↓
FAILED
    ↓
QUEUED
```

The exact enum names may follow project conventions.

The semantics are required.

---

# 32. OCR Data Model

Do NOT store only one giant OCR string.

Preserve both:

1. searchable plain text
2. positional/geometry information

Conceptually:

```text
OcrDocument
 ├── language
 ├── engine
 ├── engineVersion
 ├── schemaVersion
 ├── processedAt
 └── pages

OcrPage
 ├── pageNumber
 ├── plainText
 ├── width
 ├── height
 └── blocks

OcrBlock
 ├── text
 ├── bounds
 └── lines

OcrLine
 ├── text
 ├── bounds
 └── words

OcrWord
 ├── text
 ├── bounds
 └── confidence
```

The hierarchy may be simplified if the actual OCR engine does not provide every level, but preserve the highest useful fidelity it provides.

---

# 33. Position Data — Required

Position data MUST use a normalized coordinate system.

Do not store only raw pixels.

Define Quiet Paper's canonical OCR coordinate system as:

```text
x = 0.0 at left edge
x = 1.0 at right edge

y = 0.0 at top edge
y = 1.0 at bottom edge
```

Store bounding rectangles as:

```text
x
y
width
height
```

all normalized to `[0.0, 1.0]`.

Example:

```json
{
  "x": 0.468,
  "y": 0.091,
  "width": 0.176,
  "height": 0.029
}
```

The source OCR engine's coordinate convention MUST be converted into this canonical representation.

Do not allow engine-specific coordinates to leak into the app domain.

This ensures geometry remains valid when the page is rendered at:

* different resolutions
* different zoom levels
* different devices
* different screen sizes
* different PDF render scales

---

# 34. Why Geometry Exists

The geometry is not merely for display.

It MUST be retained because it enables future:

* search-result highlighting
* jump-to-result
* page-aware search
* OCR text overlays
* selectable scanned text
* copying recognized text
* exact result positioning

Do not omit geometry merely because V1's UI doesn't use all of it.

---

# 35. OCR Page Coordinates

Each OCR page must preserve its source dimensions or aspect-ratio context.

Store either:

```text
sourceWidth
sourceHeight
```

or an equivalent representation needed to interpret normalized geometry reliably.

Do not assume all pages have identical dimensions.

---

# 36. PDF Coordinates vs OCR Coordinates

Do not expose PDF coordinate systems directly to the application.

PDFs may use coordinate systems where:

* origin is bottom-left
* Y increases upward

OCR engines/images commonly use:

* origin top-left
* Y increases downward

Quiet Paper MUST internally use:

```text
top-left origin
Y increases downward
normalized 0.0–1.0
```

Convert everything into this representation.

The viewer performs the inverse mapping when needed.

---

# 37. Word Confidence

Preserve OCR confidence where the chosen OCR engine provides it.

Make it nullable:

```text
double?
```

because different engines may not provide confidence.

Do not reject the entire OCR result because confidence is unavailable.

---

# 38. Plain Text Representation

Each page MUST have a plain-text representation suitable for indexing/search.

Example:

```text
ACME CORPORATION

Invoice #4829

Laptop 1 €1,499
Monitor 2 €399

TOTAL €2,297
```

Maintain sensible whitespace/line boundaries.

The exact normalization rules must be deterministic and tested.

---

# 39. OCR Storage

OCR is derived data.

Do NOT make OCR part of Markdown.

Do NOT put OCR text inside:

```text
qp://document/<UUID>
```

The URI only identifies the document.

OCR belongs to the document's derived processing data.

Recommended conceptual relationship:

```text
Document
 ├── canonical encrypted PDF
 └── derived encrypted OCR data
```

---

# 40. Encrypt OCR Before Sync

OCR can contain highly sensitive semantic content.

Therefore:

```text
plaintext OCR
 ↓
client-side encryption
 ↓
sync
```

Cloudinary/Turso/backend must not receive plaintext OCR.

If OCR is synchronized, it must remain crypto-blind just like the PDF.

---

# 41. OCR Encryption

Reuse the existing Quiet Paper master-key architecture.

Do not create an OCR-specific password.

Use a distinct associated-data namespace and explicit envelope version.

Conceptually:

```text
quietpaper:document-ocr:<documentId>:v1
```

Use authenticated encryption.

The OCR payload must be protected against tampering.

---

# 42. OCR Versioning

Store metadata such as:

```text
ocrEngine
ocrEngineVersion
ocrSchemaVersion
language
processedAt
```

This allows future reprocessing when:

* OCR engine improves
* OCR schema changes
* language support expands

Do not invalidate the canonical PDF when OCR changes.

---

# 43. OCR for Scanned Documents

The scanner pipeline MUST run OCR on the final rendered page after all user-approved image adjustments.

Pipeline:

```text
Camera capture
 ↓
document detection
 ↓
perspective correction
 ↓
crop/rotate/brightness/contrast/saturation/grayscale
 ↓
final page render
 ├───────────────┐
 ▼               ▼
PDF page        OCR page
```

This guarantees that the OCR corresponds to the exact document visual content saved in the PDF.

Do NOT OCR the unedited camera frame while the PDF contains a differently cropped/rotated page.

---

# 44. OCR for Imported PDFs

Use this priority:

```text
Imported PDF
   ↓
usable text layer?
   ├── YES → extract + normalize
   └── NO  → render pages + OCR
```

If a text layer exists, use it.

If not, OCR rendered pages.

Do not OCR a text PDF unnecessarily.

---

# 45. PDF Text Extraction Abstraction

Create an abstraction such as:

```dart
abstract class PdfTextExtractor {
  Future<PdfTextExtractionResult?> extract(File pdf);
}
```

The exact API can follow project conventions.

A practical PDF library candidate may be:

```yaml
syncfusion_flutter_pdf
```

subject to its current package/version compatibility and licensing requirements for the project.

Do not lock the rest of the architecture to that library.

---

# 46. PDF Rendering Abstraction

Create an abstraction such as:

```dart
abstract class PdfPageRenderer {
  Future<RenderedPage> render(
    File pdf,
    int pageNumber, {
    required double targetDpi,
  });
}
```

Use a Flutter/native PDF rendering solution appropriate for the supported platforms.

A `pdfx`-style package is one candidate to evaluate, but verify current compatibility before adding it.

The rest of the application must depend on the abstraction, not directly on the package.

---

# 47. OCR Resolution

Do not blindly OCR huge source renders.

For imported PDFs without text layers:

```text
PDF
 ↓
render at an OCR-suitable resolution
 ↓
cap maximum dimensions
 ↓
OCR
```

Start with a reasonable range around 200–300 DPI and benchmark against real documents before finalizing defaults.

Test:

* A4 documents
* receipts
* invoices
* small type
* skewed scans
* low-light scans
* grayscale scans

---

# 48. Image Processing Library

The scanner's adjustments require a local image processing layer.

A practical initial candidate is:

```yaml
image
```

from the Dart image-processing ecosystem.

But the application MUST wrap it behind an abstraction such as:

```dart
abstract class ImageProcessor {
  Future<ProcessedImage> process(
    Uint8List source,
    ImageAdjustments adjustments,
  );
}
```

Do not let UI/domain code depend directly on package-specific APIs.

This allows future replacement with native/GPU image processing if performance demands it.

---

# 49. Camera/Scanner Abstraction

Do not make scanner UI depend directly on a camera plugin.

Create a scanner abstraction:

```dart
abstract class DocumentScannerService {
  Future<ScannedPage?> capturePage();
}
```

or an equivalent repository-conforming interface.

This lets you replace the underlying platform implementation later.

Document detection and camera acquisition are separate concerns from OCR.

---

# 50. Suggested Library Responsibilities

The implementation should separate responsibilities approximately like this:

```text
Camera/scanner library
    camera preview + capture + document detection

Image-processing library
    crop
    rotation
    brightness
    contrast
    saturation
    grayscale
    perspective normalization

PDF library
    PDF generation
    PDF metadata/page inspection
    text extraction where supported

PDF renderer
    render imported/scanned PDF pages for OCR/preview

OCR library
    on-device text recognition
```

Do not search for a single dependency that does everything.

---

# 51. Candidate Flutter Dependencies

Before finalizing versions, verify current compatibility with the project's Flutter/Dart version and supported platforms.

Initial candidates to evaluate:

```yaml
dependencies:
  google_mlkit_text_recognition: <current-compatible-version>
  image: <current-compatible-version>
  # PDF parser/text extraction candidate:
  syncfusion_flutter_pdf: <current-compatible-version>
  # PDF rendering candidate:
  pdfx: <current-compatible-version>
```

The scanner/camera package should be selected based on current platform support and the actual repository's existing camera dependencies.

Do not blindly add duplicate camera/PDF libraries if the repository already contains suitable equivalents.

If an existing dependency already provides part of this functionality, extend/reuse it.

---

# 52. Licensing

Before adopting any third-party dependency:

* inspect its license
* verify compatibility with Quiet Paper's distribution model
* verify Android/iOS support
* verify current Flutter/Dart compatibility
* avoid unnecessary duplicate dependencies

Do not silently introduce a package with licensing restrictions incompatible with the application.

---

# 53. Document Processing Queue Architecture

Introduce a document-processing coordinator.

Conceptually:

```text
DocumentProcessingService
 ├── extractPdfText()
 ├── renderPages()
 ├── runOcr()
 ├── generatePreview()
 └── generateThumbnail()
```

It should enqueue work rather than execute everything synchronously.

The document domain should expose processing state separately from upload sync state.

Example:

```text
Document:
    uploadState = SYNCED

Processing:
    ocrState = PROCESSING
```

This is valid.

Do not conflate:

```text
cloud synchronization
```

with:

```text
local OCR processing
```

---

# 54. Document Processing Persistence

If the app is killed while OCR is running:

* the document must remain valid
* the OCR job must be recoverable
* the PDF must not be lost
* the next app launch must detect pending processing and resume/retry safely

Do not require the user to scan/import the document again.

---

# 55. Document Viewer

Create a dedicated document viewer.

The viewer must:

* resolve `qp://document/<UUID>`
* locate the local document
* decrypt locally
* download encrypted PDF when required
* render pages
* scroll through pages
* zoom reasonably
* show page numbers/count
* work on phone
* work on tablet
* respect read-only mode
* never expose Cloudinary URLs as user-facing document links

Do not build:

* PDF annotation
* PDF editing
* OCR text editing
* document markup

---

# 56. Future OCR Overlay Capability

The document viewer architecture should be capable of eventually doing:

```text
PDF page
   +
OCR geometry overlay
   ↓
selectable/highlightable text
```

Do NOT fully implement selectable OCR overlays unless required for this phase.

But the viewer's internal page coordinate system must be compatible with the normalized OCR geometry.

---

# 57. Search Architecture

Existing Quiet Paper search is local.

Prepare the document subsystem so OCR text can be indexed locally.

Do not require remote search.

Do not implement AI search.

A future search result should be able to carry:

```text
documentId
pageNumber
matchedText
normalizedBounds
```

That data model should be possible without changing the OCR schema later.

---

# 58. OCR Search Result Example

Conceptually:

```json
{
  "documentId": "...",
  "pageNumber": 3,
  "text": "invoice",
  "bounds": {
    "x": 0.14,
    "y": 0.22,
    "width": 0.12,
    "height": 0.03
  }
}
```

Future viewer behavior:

```text
search
 ↓
document
 ↓
page 3
 ↓
scroll to bounds
 ↓
highlight matched words
```

Do not put this geometry into Markdown.

---

# 59. Document Preview

The document reference in Markdown should render as a quiet document card/inline object rather than as raw Markdown.

Example:

```text
┌────────────────────────────────────┐
│  document icon                     │
│  Scanned Document                  │
│  4 pages · Searchable              │
└────────────────────────────────────┘
```

For an imported PDF:

```text
┌────────────────────────────────────┐
│  PDF icon                          │
│  Quarterly Report                  │
│  12 pages · Searchable             │
└────────────────────────────────────┘
```

Do not show:

* Cloudinary URL
* UUID
* raw `qp://` URI
* internal sync state

in normal presentation.

---

# 60. OCR Status in Document Preview

The preview can communicate:

```text
Processing text…
Searchable
OCR unavailable
```

quietly.

Do not display technical stack errors directly in the document card.

Failures should be handled through an appropriate app-level error/retry path.

---

# 61. OCR Language Status

The document should remember which OCR language was used.

Conceptually:

```text
language = english
```

This matters for future reprocessing and additional languages.

Do not hard-code English into encrypted payload logic.

---

# 62. Local OCR Security

During OCR:

* plaintext page images may exist temporarily in memory/files
* process them only locally
* clean temporary files when possible
* do not upload them
* do not log their contents
* do not include OCR text in analytics/telemetry
* do not write OCR plaintext to ordinary application logs

OCR results are sensitive document content.

---

# 63. Logging

Never log:

* PDF contents
* OCR text
* document plaintext
* image plaintext
* encryption keys
* plaintext document filenames if they are sensitive

Structured logs may contain:

```text
documentId
pageNumber
processing state
error class
duration
```

but avoid sensitive content.

---

# 64. Attachment and Document Sync

Use the existing sync architecture.

The existing project already has offline queueing, revision tracking, idempotency, push/pull, and conflict handling.

Documents become another synchronized resource.

Conceptually:

```text
SyncChange
 ├── NoteChange
 ├── AssetChange
 └── DocumentChange
```

or an equivalent generalized resource-change model.

Do not create a separate sync engine for documents.

---

# 65. PDF Binary Data Must Never Pass Through Vercel

This is a hard requirement.

Binary upload:

```text
Flutter
 ↓
encrypt
 ↓
Cloudinary
```

Metadata/control plane:

```text
Flutter
 ↓
Vercel
 ↓
Turso
```

Never:

```text
Flutter
 ↓
Vercel
 ↓
Cloudinary
```

for PDF bytes.

Vercel must not become a binary proxy because of serverless execution/request limitations.

---

# 66. Cloudinary

Cloudinary stores:

```text
encrypted canonical PDF
```

Potentially under an opaque identifier such as:

```text
document/<documentId>/original
```

Cloudinary does NOT receive plaintext PDFs.

Cloudinary does NOT perform OCR.

Cloudinary does NOT generate the canonical PDF.

Cloudinary does NOT hold Quiet Paper encryption keys.

Cloudinary object identifiers are storage metadata, not document identity.

---

# 67. Direct Upload Authorization

Use the existing Firebase authentication/session.

Flow:

```text
Flutter
 ↓
request document upload authorization
 ↓
Vercel
 ↓
authenticate Firebase user
 ↓
verify note/document ownership
 ↓
generate scoped Cloudinary upload authorization
 ↓
Flutter
 ↓
direct encrypted upload to Cloudinary
 ↓
Flutter
 ↓
confirm metadata/upload result with Vercel
```

The PDF bytes never enter the Vercel request.

Never embed a permanent Cloudinary secret in Flutter.

---

# 68. Download Architecture

Retrieval should mirror upload:

```text
Document reference
 ↓
local document?
 ├── yes → decrypt locally
 └── no
      ↓
retrieve encrypted object directly
      ↓
decrypt locally
      ↓
verify integrity
      ↓
render
```

Do not proxy PDF downloads through Vercel.

---

# 69. Document Encryption

Use the existing Quiet Paper master key architecture.

Do not introduce a new password.

Use XChaCha20-Poly1305 or the exact existing content-encryption implementation.

Each document/derived encrypted resource must have:

* unique nonce
* explicit envelope version
* encryption key version
* authenticated associated data
* tamper detection

Use distinct associated-data namespaces for:

```text
document PDF
OCR payload
```

Conceptually:

```text
quietpaper:document:<documentId>:v1
quietpaper:document-ocr:<documentId>:v1
```

Use whatever exact naming convention best matches the current crypto implementation.

---

# 70. OCR Encryption

OCR text and geometry are sensitive.

Encrypt the OCR payload before synchronization.

Suggested conceptual model:

```text
Document OCR
 ├── page 1 structured OCR
 ├── page 2 structured OCR
 └── page 3 structured OCR
```

serialize it deterministically

```text
JSON/CBOR/etc.
 ↓
encrypt
 ↓
sync
```

The backend must never decrypt it.

---

# 71. Database Model for OCR

Avoid unnecessarily complex relational geometry tables initially.

A practical design is:

```text
document_ocr_pages
────────────────────────────
document_id
page_number
encrypted_payload

ocr_schema_version
ocr_engine
ocr_engine_version
language
processed_at
```

The encrypted payload contains:

```json
{
  "text": "...",
  "sourceWidth": 2480,
  "sourceHeight": 3508,
  "blocks": [
    {
      "text": "...",
      "bounds": {
        "x": 0.1,
        "y": 0.2,
        "width": 0.4,
        "height": 0.05
      },
      "lines": [
        {
          "text": "...",
          "bounds": {...},
          "words": [
            {
              "text": "...",
              "bounds": {...},
              "confidence": 0.98
            }
          ]
        }
      ]
    }
  ]
}
```

Exact serialization can differ, but the semantics must be preserved.

This keeps the Drift schema manageable while preserving word/line/block geometry.

---

# 72. OCR Data Compression

OCR JSON can grow for large documents.

Consider compact serialization/compression before encryption where it actually provides meaningful benefit.

Do not prematurely optimize.

Benchmark:

* 1-page receipt
* 10-page contract
* 100-page document

before adding unnecessary complexity.

The encrypted payload must remain versioned.

---

# 73. OCR Deduplication / Reprocessing

If the PDF content hash has not changed and the OCR configuration has not changed:

```text
same PDF
same language
same engine/schema
```

do not unnecessarily recompute OCR.

If:

```text
PDF hash changes
language changes
OCR engine changes
OCR schema changes
```

the OCR may be regenerated.

The canonical PDF remains unchanged during OCR regeneration.

---

# 74. OCR Language Change

If additional languages are introduced in the future, language changes should trigger reprocessing.

For this release, only English exists, but the data model must support:

```text
language = english
```

as a real configuration value.

Do not store human-readable UI strings such as `"English"` as the only backend identity.

Use a stable language code internally, for example:

```text
en
```

with a localized UI label.

---

# 75. OCR Text Extraction vs OCR Engine

For imported PDFs:

```text
PDF text layer
```

is not technically the same thing as OCR.

However, normalize both into the same application-level `OcrPage` representation where possible.

That means downstream search/viewer code can consume:

```text
OcrPage
```

regardless of whether its source was:

```text
embedded PDF text
```

or:

```text
ML OCR
```

Store source metadata:

```text
embeddedText
ocr
```

where useful.

---

# 76. Document Source and OCR Source

Use separate metadata:

```text
document.source:
    scanner
    importedPdf

ocr.source:
    embeddedPdfText
    onDeviceOcr
```

Do not confuse how the document was created with how its text was obtained.

---

# 77. Backup and Restore

The existing app has `.qpbackup` with optional encryption, restore conflict strategies, and cloud-sync compatibility.

Extend backup/restore to include:

### Document

* ID
* note association
* source
* page count
* size
* hash
* encryption metadata
* canonical encrypted PDF payload or equivalent secure representation

### OCR

* processing state
* language
* engine/version
* encrypted structured OCR payload

Do not lose document references during restore.

Do not silently lose OCR.

Restored documents should be marked appropriately for cloud synchronization.

Do not accidentally trigger remote deletion during restore.

---

# 78. Backup Compatibility

Existing notes without documents must restore exactly as before.

Existing image attachments must continue to work.

Document migration must be additive.

No existing Markdown should be rewritten solely because document support has been introduced.

---

# 79. Read-Only and Locked Notes

Respect the existing read-only and note-password features.

Read-only:

* cannot scan
* cannot attach PDF
* cannot delete document
* cannot change document reference

Locked/password-protected note:

* document contents must not be exposed before unlock
* document preview must remain protected
* decrypted OCR must remain protected
* document viewer must respect note lock semantics

The existing note-level password protection is client-side and uses Argon2id/XChaCha20-Poly1305; preserve its security boundary.

---

# 80. Search Architecture

Do not implement full document search UI unless the repository already has a suitable extension point.

However, the OCR subsystem MUST produce local searchable text.

The design should make future local search straightforward:

```text
search query
 ↓
notes
+
OCR text
 ↓
document/page match
 ↓
document viewer
 ↓
page + bounding box
```

Search must remain offline-capable.

No server-side document search.

---

# 81. Image Attachment Compatibility

The repository already supports image attachments.

Do not regress them.

Existing images continue to use:

```text
qp://asset/<UUID>
```

Documents use:

```text
qp://document/<UUID>
```

Share lower-level:

* encryption
* local resource storage
* Cloudinary upload
* sync metadata
* resource URI parsing

but keep the domain semantics distinct.

---

# 82. External URLs

Existing external links continue using the app's external-link safety confirmation.

Internal:

```text
qp://asset/...
qp://document/...
qp://note/...
```

must stay internal.

Do not pass them to `url_launcher`.

Do not show the external-domain trust dialog for them.

---

# 83. Performance

Do not:

* load an entire 100-page PDF into RAM
* render all pages simultaneously
* OCR all pages synchronously on the UI thread
* repeatedly re-encode images
* send binary data through Vercel
* keep unnecessary plaintext copies
* block editor autosave on OCR
* block editor interaction on upload

Use lazy loading and background processing where appropriate.

---

# 84. PDF Viewer Performance

Use lazy page rendering.

Only render pages near the viewport.

Use reasonable page-resolution targets.

Cache intelligently.

Avoid rendering full-resolution 6000×8000 pages when a smaller viewer representation is sufficient.

Ensure zoom remains visually useful without exhausting memory.

---

# 85. Scanner Image Processing Performance

Live preview adjustments should be responsive.

Do not run full-resolution expensive transformations on every slider tick if it causes frame drops.

Use:

```text
preview resolution
```

while interacting.

Apply the final transformations at full needed resolution when the user commits the page.

This is important for:

* brightness
* contrast
* saturation
* grayscale
* crop
* rotation

---

# 86. Camera Permissions

Handle camera permission states:

```text
granted
denied
permanently denied
unavailable
```

Provide a graceful explanation and system-settings path where appropriate.

Do not crash.

Do not request unrelated permissions.

---

# 87. Scanner Cancellation

If the user cancels a scan session before generating the PDF:

* discard temporary pages
* do not create a document resource
* do not modify the note
* do not create cloud upload jobs

If a PDF has already been generated and persisted but the note insertion failed, recover or clean up safely instead of losing the document.

---

# 88. Atomic Document Insertion

Once the final PDF is locally persisted:

```text
document saved
+
Markdown reference saved
```

should be made as atomic/transactional as practical.

Do not leave:

```text
Markdown references missing document
```

or:

```text
document exists forever but note never references it
```

without an orphan-cleanup strategy.

---

# 89. Orphan Cleanup

If a document exists without a Markdown reference:

Do NOT immediately delete it.

Allow time for:

* undo
* transaction recovery
* sync
* restore
* editing transitions

Use delayed orphan cleanup.

---

# 90. Deletion Lifecycle

Removing:

```markdown
[Document](qp://document/ABC)
```

should result in:

```text
reference removed
 ↓
document tombstone
 ↓
sync deletion metadata
 ↓
delayed Cloudinary deletion
```

not immediate cloud deletion.

Cloudinary physical deletion must be authorized securely.

The client must not possess unrestricted Cloudinary deletion credentials.

---

# 91. Conflict Semantics

Do not merge PDF content.

Two devices can create:

```text
document/A
document/B
```

and both are valid.

If note Markdown conflicts, resolve the note conflict according to the existing sync mechanism.

Documents remain independent immutable resources.

---

# 92. Idempotency

All document metadata registration/completion/deletion operations must be idempotent.

Retries must not create:

* duplicate document records
* duplicate tombstones
* inconsistent revisions
* orphan cloud objects where avoidable

The document UUID remains stable through retries.

---

# 93. Security Invariants

The finished implementation MUST maintain:

```text
PDF plaintext:
    client only

OCR plaintext:
    client only

Image plaintext:
    client only

Cloudinary:
    encrypted PDF only

Turso:
    metadata + encrypted data as designed

Vercel:
    control plane only

Master key:
    client/device secure storage only

OCR:
    local/on-device only
```

Do not add server-side decryption.

Do not add cloud OCR.

Do not add plaintext analytics.

---

# 94. Testing — URI

Test:

```text
qp://asset/<UUID>
qp://document/<UUID>
qp://note/<UUID>
```

Test malformed variants.

Test round trips.

Test resource type dispatch.

Test resolver behavior for:

* missing
* deleted
* locked
* corrupted
* unavailable

---

# 95. Testing — Scanner

Test:

* scanner initialization
* permission denied
* detection
* fallback capture
* capture
* retake
* delete page
* reorder pages
* multi-page scan
* cancel
* complete
* PDF generation failure
* local persistence

Use mocks/fakes for camera/platform dependencies.

---

# 96. Testing — Image Adjustments

Test each adjustment independently:

* crop
* rotation
* brightness
* contrast
* saturation
* grayscale

Test combinations.

Test neutral/default values.

Test non-destructive parameter behavior.

Test that the original source isn't overwritten during preview.

Test final output dimensions.

---

# 97. Testing — PDF Import

Test:

* valid PDF
* invalid file
* large PDF
* single page
* multi-page
* text PDF
* scanned/image-only PDF
* corrupted PDF
* cancellation
* local persistence

---

# 98. Testing — PDF Text Extraction

Test:

```text
text PDF
 ↓
text extraction
```

and:

```text
scanned PDF
 ↓
no usable text
 ↓
OCR fallback
```

Test mixed/partial text cases according to the chosen PDF library's behavior.

---

# 99. Testing — OCR

Test:

* English selected
* OCR language persists
* correct language code passed to engine
* OCR queue
* processing
* success
* failure
* retry
* process restart
* multiple pages
* plain text
* blocks
* lines
* words
* bounding boxes
* normalized coordinates
* confidence
* corrupted OCR payload
* wrong encryption key
* tampered OCR payload

---

# 100. Testing — OCR Geometry

Given an OCR result such as:

```text
source size = 2480 × 3508

box:
x = 1160
y = 319
width = 440
height = 102
```

verify conversion approximately produces:

```text
x ≈ 0.4677
y ≈ 0.0910
width ≈ 0.1774
height ≈ 0.0290
```

Test conversion back to a rendered page rectangle.

Test:

* portrait
* landscape
* resized page
* zoomed page
* different page resolutions

This protects the future search/highlight system.

---

# 101. Testing — OCR Source

Test:

```text
OCR source = embeddedPdfText
```

and:

```text
OCR source = onDeviceOcr
```

Both should normalize into the common `OcrPage` model.

---

# 102. Testing — Encryption

Test:

* PDF roundtrip
* OCR roundtrip
* wrong key
* tampered ciphertext
* invalid associated data
* wrong encryption version
* unique nonces
* hash verification

The backend must have no decrypt path.

---

# 103. Testing — Direct Cloudinary Upload

Mock/directly verify the architecture:

```text
Flutter → Cloudinary
```

for PDF bytes.

And:

```text
Flutter → Vercel
```

for authorization/metadata only.

There MUST NOT be an API endpoint that accepts the PDF binary.

Test:

* authorization
* upload
* completion registration
* retry
* expired signature
* duplicate completion
* ownership validation

---

# 104. Testing — Sync

Test:

* offline creation
* online upload
* retry
* remote pull
* remote deletion
* local deletion
* deletion race
* note deletion while document upload pending
* duplicate change
* revision handling
* cursor pull
* idempotency
* multi-device synchronization

Ensure remote deletion does not re-enqueue itself.

The current handoff already identifies deletion tombstones and queue-loop prevention as critical synchronization concerns.

---

# 105. Testing — Backup/Restore

Test:

* backup with scanned documents
* backup with imported PDFs
* encrypted backup
* restore
* merge
* keep-both
* clean replace
* OCR restoration
* document references
* document IDs
* sync after restore
* missing cloud objects

---

# 106. Testing — Editor

Test:

```markdown
[Scanned Document](qp://document/UUID)
```

for:

* source preservation
* cursor movement
* deletion
* undo/redo
* copy/paste
* Markdown formatting adjacent to document references
* mixed images/documents/text
* malformed URIs

Do not regress the existing Markdown WYSIWYG behavior.

---

# 107. Database Migration

Add a proper Drift migration for:

* documents
* document processing state
* OCR metadata
* OCR payload references/state

Do not break existing image attachments.

Do not rewrite existing Markdown.

Test upgrade from the current schema version.

Test fresh installation.

---

# 108. Backend Migration

Add backend/Turso migrations for:

* document metadata
* document revision/state
* document tombstones
* Cloudinary object identifiers
* OCR synchronization metadata if OCR is synchronized independently

Never add plaintext document content.

Never add plaintext OCR columns.

---

# 109. Backup Architecture

The existing backup subsystem uses a `.qpbackup` format and optional client-side encryption.

Extend it carefully.

The backup must preserve:

```text
document ID
note relationship
source
page count
hash
PDF
OCR metadata
OCR encrypted payload as appropriate
```

Do not turn the backup system into a new upload mechanism.

Do not upload backups automatically to Cloudinary unless the existing product requires that separately.

---

# 110. Documentation

Update the engineering handoff and relevant architecture/security documents to explain:

## Resource URIs

```text
qp://asset/<UUID>
qp://document/<UUID>
qp://note/<UUID>
```

## Document lifecycle

```text
scanner/import
 ↓
local PDF
 ↓
encryption
 ↓
Cloudinary direct upload
```

## OCR

```text
embedded PDF text → extract
otherwise → local OCR
```

## OCR language

Initial:

```text
English / en
```

## OCR geometry

Normalized top-left coordinates.

## Trust boundaries

```text
Vercel = control plane
Cloudinary = encrypted blob storage
Flutter = crypto/OCR/PDF processing
```

## Backups

Document and OCR handling.

---

# 111. Suggested Code Organization

Follow the repository's current organization, but conceptually keep responsibilities separated.

Possible structure:

```text
lib/core/documents/
    document_models.dart
    document_repository.dart
    document_service.dart
    document_crypto.dart
    document_processing_service.dart
    document_sync.dart
    document_provider.dart

lib/core/ocr/
    ocr_models.dart
    ocr_service.dart
    ocr_language.dart
    ocr_provider.dart
    ocr_processing.dart
    mlkit_ocr_service.dart
    pdf_text_extractor.dart

lib/core/pdf/
    pdf_generator.dart
    pdf_renderer.dart
    pdf_metadata.dart

lib/core/image_processing/
    image_processor.dart
    image_adjustments.dart

lib/core/scanner/
    document_scanner_service.dart
    scanner_models.dart

lib/core/uri/
    quiet_paper_uri.dart
    resource_resolver.dart

lib/features/scanner/
    presentation/
    application/

lib/features/documents/
    presentation/
    application/
```

Adapt to existing repository architecture.

Do not duplicate functionality already present.

---

# 112. Suggested Dependency Boundaries

Application/domain code should depend on abstractions:

```text
OcrService
PdfTextExtractor
PdfPageRenderer
ImageProcessor
DocumentScannerService
```

Infrastructure adapters depend on specific libraries.

For example:

```text
MlKitOcrService
SyncfusionPdfTextExtractor
PdfxPageRenderer
DartImageProcessor
Native/CameraScannerService
```

This prevents third-party packages from becoming architecture-defining dependencies.

---

# 113. Candidate Packages

Verify exact current compatible versions before adding them.

Potential initial candidates:

```yaml
dependencies:
  google_mlkit_text_recognition: <verify-current-version>
  image: <verify-current-version>
  syncfusion_flutter_pdf: <verify-current-version-and-license>
  pdfx: <verify-current-version>
```

For scanning/camera:

* inspect existing repository dependencies first
* reuse a suitable existing camera implementation where possible
* otherwise select a maintained camera/document-scanning package compatible with the project's platforms

Do not add multiple overlapping PDF/camera packages without a concrete reason.

---

# 114. Package Selection Rule

Before introducing a package:

1. Check whether the repository already has an equivalent.
2. Check platform support.
3. Check Flutter/Dart compatibility.
4. Check licensing.
5. Check performance.
6. Check whether it supports offline/on-device processing.
7. Wrap it behind an application abstraction.

Do not allow a package-specific API to spread through the domain/editor layers.

---

# 115. Performance Requirements

The system must:

* remain responsive during scanner preview
* use lower-resolution previews while adjusting
* apply full-resolution transformations only on commit
* process OCR off the UI thread where required
* lazily render PDF pages
* avoid full-document memory loads
* retain encrypted local PDF for retry
* avoid plaintext cloud transfer
* avoid Vercel binary transport

---

# 116. Security Requirements for Temporary Files

Temporary plaintext page images and PDF files may exist while scanning/processing.

They must:

* remain in app-private locations
* not be exposed publicly
* not be indexed into user media storage unnecessarily
* be cleaned after successful processing where no longer needed
* not be logged
* not be uploaded except through the intended encrypted path

---

# 117. User Experience During OCR

Do not interrupt the user's writing session.

After scanning:

```text
[Scanned Document]
3 pages · Processing…
```

After OCR:

```text
[Scanned Document]
3 pages · Searchable
```

For imported PDFs:

```text
[Quarterly Report]
42 pages · Searchable
```

Do not show raw engine/version details to ordinary users.

---

# 118. User Experience for OCR Language

The settings UI or document-specific action should expose:

```text
OCR Language
    English
```

Use a picker.

The available language list initially contains exactly:

```text
English
```

The architecture must allow:

```text
Dutch
German
French
Spanish
...
```

to be added later without restructuring the OCR pipeline.

Do not show unsupported languages.

---

# 119. Document Viewer Search Preparation

Even if document search UI is not fully implemented now, the viewer should have enough internal architecture to accept future navigation:

```text
DocumentViewer.open(
  documentId,
  page: 3,
  highlight: normalizedRect,
)
```

This is a future-facing API shape.

Do not require the viewer to expose this publicly if it isn't needed yet, but avoid making it impossible.

---

# 120. Final End-to-End Architecture

The finished architecture should conceptually be:

```text
                           QUIET PAPER
                                │
                                ▼
                           Markdown
                                │
                   ┌────────────┴────────────┐
                   │                         │
                   ▼                         ▼
              qp://asset/...          qp://document/...
                   │                         │
                 Image                    Document
                                             │
                              ┌──────────────┼───────────────┐
                              │              │               │
                              ▼              ▼               ▼
                            PDF           Metadata          OCR
                              │                               │
                              │                               │
                        encrypt locally                 encrypt locally
                              │                               │
                              ▼                               ▼
                         Cloudinary                         Sync
                         ciphertext                         metadata
                              │                               │
                              └──────────────┬────────────────┘
                                             ▼
                                           Vercel
                                             │
                                             ▼
                                            Turso
```

Scanner:

```text
Camera
 ↓
document detection
 ↓
capture
 ↓
automatic perspective correction
 ↓
crop / rotate / brightness / contrast / saturation / grayscale
 ↓
final page
 ├───────────────┐
 ▼               ▼
PDF generation   OCR
 ↓               ↓
canonical PDF    structured OCR
 ↓               ↓
encrypt          encrypt
 ↓               ↓
Cloudinary       sync
```

Imported PDF:

```text
File picker
 ↓
original PDF
 ↓
persist locally
 ↓
encrypt
 ↓
Cloudinary
 │
 └── text layer?
       ├── yes → extract/normalize
       └── no  → render pages → OCR
```

---

# 121. Explicitly Out of Scope

Do NOT implement:

* OCR cloud services
* AI document summarization
* AI document classification
* handwriting recognition
* handwritten OCR
* document annotations
* PDF annotations
* PDF editing
* PDF page editing after import
* filters beyond the specified scanner adjustments
* arbitrary image effects
* image markup
* public document URLs
* collaborative PDF editing
* note-to-note linking UI
* `[[wikilink]]` syntax
* searchable-PDF rewriting
* cloud OCR
* Vercel PDF proxying
* plaintext PDF upload
* plaintext OCR synchronization

---

# 122. Non-Negotiable Final Invariants

Before declaring the implementation complete, verify every statement below is true:

```text
Markdown remains the canonical note representation.

qp://asset/<UUID> identifies normal attachments.

qp://document/<UUID> identifies scanned/imported PDF documents.

qp://note/<UUID> is reserved for future note-to-note links.

Scanner and imported PDFs both produce Document resources.

The canonical Document payload is a PDF.

Scanned PDFs are generated locally.

Imported PDFs are preserved byte-for-byte as their canonical source.

The PDF is encrypted before cloud upload.

OCR runs locally/on-device.

The user can select an OCR language.

The initial language list contains exactly English.

OCR language is represented internally by a stable language identifier.

OCR is asynchronous.

OCR is separately stored from the PDF.

OCR text is encrypted before synchronization.

OCR preserves page boundaries.

OCR preserves normalized geometry.

OCR coordinates use top-left origin and normalized 0.0–1.0 coordinates.

OCR can preserve blocks, lines, words, and confidence when available.

Existing embedded PDF text is extracted before OCR is attempted.

Cloudinary receives encrypted PDF data only.

Cloudinary never receives plaintext OCR.

Vercel never receives PDF byte streams.

Vercel is the control plane.

Turso contains metadata/state but not plaintext document contents.

Document uploads are independent from note sync.

Offline scanning works.

Offline PDF import works.

Cloud upload can resume/retry later.

The scanner supports crop.

The scanner supports rotation.

The scanner supports brightness.

The scanner supports contrast.

The scanner supports saturation.

The scanner supports grayscale.

Adjustments are non-destructive until final page rendering.

OCR runs against the final adjusted page.

The scanner button is immediately adjacent to the image button.

The PDF resource is rendered through a dedicated document viewer.

Document deletion uses tombstones and delayed cloud deletion.

Remote deletion does not re-enqueue itself.

Read-only notes cannot be modified through scanner/PDF controls.

Password-protected notes cannot expose document plaintext without unlock.

Existing image attachments continue to work.

Existing Markdown editor source/selection behavior remains intact.

No alternate rich-text source of truth is introduced.

No cloud OCR is introduced.

No image/document editing beyond the specified scanner adjustments is introduced.

Backup/restore does not lose documents or OCR.

Flutter analysis passes.

Flutter tests pass.

Backend tests pass.

Backend build/typecheck passes.

Database migrations pass.

The implementation is documented.
```

---

# 123. Required Implementation Report

When the implementation is complete, report:

1. Files created.
2. Files modified.
3. Flutter dependencies added and why.
4. Exact third-party packages used for:

   * scanner/camera
   * image processing
   * PDF generation
   * PDF rendering
   * PDF text extraction
   * OCR
5. Dependency licensing considerations.
6. Drift schema changes.
7. Backend schema/API changes.
8. Cloudinary upload architecture.
9. Encryption/envelope design.
10. Document resource model.
11. Scanner workflow.
12. Image-adjustment implementation.
13. PDF import workflow.
14. OCR architecture.
15. OCR language model and English implementation.
16. OCR geometry model.
17. Document processing queue.
18. Viewer implementation.
19. Backup/restore changes.
20. Sync changes.
21. Deletion/tombstone behavior.
22. Tests added.
23. Commands actually executed.
24. Actual test/analyze/build results.
25. Any repository-specific deviation from this specification and the reason.

Do not claim a feature works unless it was actually implemented and tested.

Do not claim direct Cloudinary upload unless the binary path is genuinely Flutter → Cloudinary.

Do not claim zero-knowledge OCR unless OCR plaintext is genuinely kept on-device and OCR payloads are encrypted before synchronization.

Do not silently reduce the specification.

The final implementation should make Quiet Paper's document system feel native and coherent:

```text
                         Quiet Paper Documents

        ┌──────────────┬──────────────────┐
        │              │                  │
      Camera         Add PDF          Existing data
        │              │                  │
        ▼              ▼                  │
      Scanner       Imported PDF          │
        │              │                  │
        └──────────────┴──────────────────┘
                       │
                       ▼
                qp://document/<UUID>
                       │
             ┌─────────┴──────────┐
             │                    │
          PDF                    OCR
       canonical              derived/index
             │                    │
       encrypted               encrypted
             │                    │
             ▼                    ▼
        Cloudinary             Sync layer
                               / local search
```

The user experience should remain simple:

**Scan → adjust → add pages → done.**

Or:

**Choose PDF → attach.**

Behind that simple experience, the implementation must provide a robust, offline-first, encrypted document architecture with local OCR, selectable OCR language beginning with English, normalized positional data, direct Cloudinary uploads, safe synchronization, and a reusable `qp://` resource model for the future note-linking system.
