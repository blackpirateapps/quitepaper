# Quiet Paper — OCR User Experience Implementation Prompt

You are continuing work on **Quiet Paper**, an offline-first Flutter notes application with a Bear-inspired editorial UI, Drift/SQLite local persistence, client-side zero-knowledge encryption, Firebase authentication, a Vercel/TypeScript backend, Turso/libSQL metadata storage, direct Cloudinary object storage, Markdown as the canonical note representation, image attachments, scanned/imported PDF documents, and local OCR.

The previous implementation phase established the document architecture:

```text id="0gd0x2"
qp://asset/<UUID>       → ordinary image/file attachment
qp://document/<UUID>    → scanned/imported PDF document
qp://note/<UUID>        → future internal note link
```

Documents use a canonical PDF representation.

Scanned PDFs are generated locally.

Imported PDFs preserve their original PDF content.

PDFs are encrypted on-device before cloud transfer.

Cloudinary receives encrypted document data directly from Flutter.

Vercel is the control plane and must never proxy document bytes.

OCR runs locally/on-device.

OCR is derived data and is stored separately from the canonical PDF.

OCR preserves page-level text and normalized positional/geometry information.

The initial OCR language is **English only**, but the language architecture is extensible.

The purpose of this phase is to make OCR **actually useful and visible to the user**, rather than merely generating/storing OCR data in the background.

Do not redesign the existing architecture.

Do not replace existing crypto, sync, Markdown, or document models.

---

# 1. Primary Objective

Implement the first complete user-facing OCR experience.

After this phase, the user must be able to:

1. Scan a document.
2. Import a PDF.
3. Have OCR run locally.
4. See OCR processing status.
5. Open the document.
6. View the recognized OCR text.
7. View OCR text organized by page.
8. Select OCR text.
9. Copy OCR text.
10. Copy all OCR text for the document.
11. See whether a document is searchable.
12. Configure OCR language through a language selector.
13. Initially select only English.
14. Retry failed OCR.
15. Regenerate OCR where appropriate.
16. Continue using the PDF independently from OCR.
17. Retain all OCR data encrypted at rest/cloud.
18. Preserve the existing offline-first architecture.

Additionally, implement the foundation needed for future:

```text id="9m0bki"
Search OCR
Search across documents
Jump to exact document/page
Highlight OCR matches
Tap OCR match → document location
Selectable OCR overlays on PDF
```

Do NOT implement those advanced search/overlay features yet unless required to make the current architecture clean.

---

# 2. Important Current Architecture

Preserve these project principles:

* Markdown is canonical note content.
* The document PDF is canonical document content.
* OCR is derived document data.
* The backend/cloud cannot decrypt notes, documents, or OCR.
* Direct Cloudinary upload is used for document binary data.
* Vercel only handles control-plane operations.
* The local device owns decryption and OCR.
* Existing Drift persistence and sync infrastructure must be reused.
* Existing editor source/caret invariants must not regress.

The handoff explicitly states that Markdown remains the single source of truth and that the editor maintains exact source/selection correspondence.

The existing sync architecture already provides revision tracking, push/pull, cursor synchronization, idempotency and conflict handling. Reuse it rather than introducing another synchronization layer.

---

# 3. OCR Is a User-Facing Feature Now

Previous architecture may already generate and store OCR.

That is not sufficient for this phase.

The implementation MUST expose OCR to the user.

The minimum user-facing OCR capability is:

```text id="p4nu0k"
Document
 ├── PDF viewer
 └── OCR text viewer
```

The user must be able to move between those representations.

---

# 4. Document Viewer Menu

When the user opens a document, provide a quiet overflow/menu action.

Conceptually:

```text id="4w3iw1"
Document
────────────────────
View OCR Text
Copy OCR Text
Retry OCR        // only when failed
OCR Language
```

Do not necessarily expose every option in every state.

For example:

### OCR available

```text id="9vy4c9"
View OCR Text
Copy OCR Text
```

### OCR processing

```text id="50xzkf"
OCR Processing…
```

### OCR failed

```text id="ehq5wb"
Retry OCR
```

### OCR not available yet

```text id="2sywbe"
Generate OCR
```

Use the existing Quiet Paper menu/action patterns.

Do not create a large document-management UI.

---

# 5. "View OCR Text" — Required

Implement a dedicated OCR text viewer.

Example:

```text id="2vxm00"
┌─────────────────────────────────────┐
│ ←  OCR Text                    ⋯   │
├─────────────────────────────────────┤
│                                     │
│ ACME CORPORATION                    │
│                                     │
│ Invoice #4829                       │
│                                     │
│ Laptop             1       €1,499   │
│ Monitor            2       €399     │
│                                     │
│ TOTAL                       €2,297  │
│                                     │
└─────────────────────────────────────┘
```

The screen must:

* use the existing Quiet Paper typography
* use the existing light/dark theme
* support phone and tablet layouts
* be vertically scrollable
* make text selectable
* allow copy
* clearly distinguish page boundaries
* retain sensible document structure/whitespace
* remain offline-capable

Do not show the raw OCR JSON.

Do not show OCR engine details in the normal UI.

---

# 6. Page-by-Page OCR Presentation

OCR MUST retain page boundaries.

The OCR viewer should display page separation.

Preferred structure:

```text id="t1umq3"
Page 1
────────────

ACME CORPORATION

Invoice #4829

...

Page 2
────────────

Terms and Conditions

...

Page 3
────────────
...
```

Page headers should be quiet and unobtrusive.

Do not merge the entire document into one giant text blob without page information.

The user should understand where each piece of text came from.

---

# 7. OCR Text Selection

The OCR viewer must use normal Flutter text-selection behavior.

The user must be able to:

* long-press/select text
* select a range
* copy selected text
* use system copy behavior where appropriate
* select all where platform controls support it

Do not create a custom selection engine unless the existing Flutter text widgets make that impossible.

Prefer native text selection.

---

# 8. Copy OCR Text

Implement:

```text id="0uy6cm"
Copy OCR Text
```

from the document menu.

It must copy the entire normalized OCR text.

Recommended format:

```text id="apq5uw"
Page 1

ACME CORPORATION
Invoice #4829
...

Page 2

...
```

Use stable page separators.

Do not copy raw OCR metadata.

Do not copy bounding boxes.

Do not expose internal IDs.

---

# 9. Copy Selected OCR Text

The text viewer's native selection behavior should support normal copying.

If the user selects:

```text id="upx08w"
Invoice #4829
```

and taps Copy:

clipboard becomes:

```text id="qfl1uy"
Invoice #4829
```

not JSON.

---

# 10. OCR Processing Status

Document preview must make OCR status understandable.

At minimum support:

```text id="0l8mp5"
OCR not generated
OCR processing…
Searchable
OCR unavailable
OCR failed
```

Potential document card:

```text id="fv9u4j"
Scanned Document
4 pages · Processing text…
```

Then:

```text id="vty3hp"
Scanned Document
4 pages · Searchable
```

If failed:

```text id="8l0nuz"
Scanned Document
4 pages · Text unavailable
```

The UI should not expose stack traces, package errors, or implementation details.

---

# 11. OCR Status Must Be Separate From Upload State

Do not conflate:

```text id="4ahf9y"
OCR status
```

with:

```text id="cfb8in"
Cloud sync/upload status
```

Valid example:

```text id="1w5o2t"
PDF:
    Cloud synced

OCR:
    Processing
```

Another valid example:

```text id="5z9fev"
PDF:
    Upload pending

OCR:
    Available
```

The user must be able to view OCR offline even if the document has not finished uploading.

---

# 12. OCR State Model

Use explicit states.

Conceptually:

```text id="6iz7ek"
NOT_REQUESTED
QUEUED
PROCESSING
AVAILABLE
FAILED
```

Optional:

```text id="2n5p9h"
STALE
```

if useful for OCR version/config invalidation.

Do not use a simple boolean such as:

```text id="4c0dpf"
hasOcr = true/false
```

because the system has meaningful intermediate states.

---

# 13. Retry OCR

When OCR fails, the user must be able to retry.

Document menu:

```text id="t2xvd9"
Retry OCR
```

Retry should:

* retain the existing PDF
* retain the document UUID
* reset only OCR processing state
* not re-upload the PDF unnecessarily
* not alter Markdown
* not create a new document
* use the currently configured OCR language
* regenerate OCR from the canonical PDF

Do not require the user to rescan or re-import the PDF.

---

# 14. OCR Generation / Regeneration

Provide an application-level OCR generation action where appropriate.

For example, if the document has no OCR:

```text id="zq1p76"
Generate OCR
```

If OCR exists but is stale:

```text id="tgnl7r"
Regenerate OCR
```

The exact UI labels may be simplified, but the system should distinguish:

```text id="r7p2bs"
missing
failed
available
stale
```

where useful.

---

# 15. OCR Language Selection

The user MUST be able to choose OCR language.

For this release, there is exactly one supported language:

```text id="j6q6zn"
English
```

Internally, use a stable language identifier such as:

```text id="0i8jjv"
en
```

Do NOT scatter `"English"` or `"en"` throughout the implementation.

Create a real language model/enum/configuration.

Conceptually:

```dart id="0vlrv2"
enum OcrLanguage {
  english,
}
```

or repository-appropriate equivalent.

The architecture must allow additional languages later without changing the document/OCR schema.

---

# 16. OCR Language UI

Provide an OCR language selector accessible from document settings/actions or another appropriate existing settings mechanism.

Conceptually:

```text id="jmr7xu"
OCR Language
English
```

Tapping it opens:

```text id="c1q1ch"
OCR Language

○ English
```

There must be no fake/disabled languages in this release.

Only English is selectable.

Store the selected language using the stable internal identifier.

---

# 17. Language Persistence

Determine and implement a coherent rule for language selection.

Preferred behavior:

* application has an OCR language preference
* initial/default value = English
* document OCR stores the language actually used
* changing the application preference does not silently invalidate existing OCR
* new OCR uses the current selected language
* explicit regeneration can use the newly selected language

This allows future multilingual support without destructive behavior.

---

# 18. OCR Source

For each document, determine OCR source:

```text id="dkmmb4"
embeddedPdfText
onDeviceOcr
```

If a usable PDF text layer exists:

```text id="13g2pz"
PDF
 ↓
extract text
 ↓
normalize
 ↓
store OCR model
```

Do not unnecessarily invoke the OCR engine.

If a usable text layer does not exist:

```text id="e1a28n"
PDF
 ↓
render pages
 ↓
on-device OCR
```

Both paths should feed the same normalized OCR data model.

---

# 19. OCR Text Model

Keep a common application model.

Conceptually:

```dart id="5v8yme"
class OcrDocument {
  final String documentId;
  final OcrLanguage language;
  final OcrSource source;
  final String engine;
  final String engineVersion;
  final int schemaVersion;
  final List<OcrPage> pages;
}
```

Page:

```dart id="8tdokl"
class OcrPage {
  final int pageNumber;
  final String plainText;
  final double sourceWidth;
  final double sourceHeight;
  final List<OcrBlock> blocks;
}
```

Block:

```dart id="bhrqru"
class OcrBlock {
  final String text;
  final NormalizedRect bounds;
  final List<OcrLine> lines;
}
```

Line:

```dart id="9oqy9b"
class OcrLine {
  final String text;
  final NormalizedRect bounds;
  final List<OcrWord> words;
}
```

Word:

```dart id="a5sz0k"
class OcrWord {
  final String text;
  final NormalizedRect bounds;
  final double? confidence;
}
```

Adapt class names to repository style.

Do not store more hierarchy than the chosen OCR engine can reliably provide.

---

# 20. Normalized Geometry

The canonical Quiet Paper OCR coordinate system is:

```text id="v3q1jv"
x = 0.0 left → 1.0 right
y = 0.0 top  → 1.0 bottom
```

Each rectangle:

```text id="o9f64f"
x
y
width
height
```

all normalized to `[0.0, 1.0]`.

Do not store only raw source pixels.

Do not leak ML Kit's/native coordinate conventions into application code.

Convert all engine coordinates to Quiet Paper's canonical coordinate system inside the adapter.

---

# 21. Geometry Must Remain Available Even Though V1 Doesn't Fully Use It

Do not remove position data because the current UI only displays text.

Geometry is required to support future:

* search-result highlighting
* page jumping
* exact match navigation
* OCR overlays
* selectable OCR over the PDF
* visual highlighting

The current UI does not need to expose all these capabilities.

---

# 22. OCR Text Normalization

The plain OCR text must be deterministic.

Normalize:

* line endings
* page boundaries
* obvious duplicated whitespace where appropriate
* OCR engine-specific line artifacts where safe

Do not aggressively "correct" user document content.

Do not spell-correct OCR text automatically.

Do not use AI to rewrite OCR text.

The goal is:

> faithful transcription suitable for search/copying.

---

# 23. Preserve OCR Confidence

Where the OCR engine provides word confidence, preserve it.

Make it nullable:

```text id="mva6h1"
confidence: double?
```

Do not fail OCR because confidence is unavailable.

Do not display confidence to ordinary users yet.

It is retained for future quality-aware search/highlighting.

---

# 24. OCR Viewer Architecture

Keep OCR viewer separate from PDF viewer.

Conceptually:

```text id="f3k2a9"
DocumentViewer
    ├── PDF view
    └── OCR text view
```

The user can choose:

```text id="1e4opm"
View Document
View OCR Text
```

Do not transform the PDF viewer into a text editor.

Do not allow editing OCR text in this phase.

---

# 25. OCR Text Is Read-Only

V1 OCR text must be read-only.

The user can:

* view
* select
* copy

The user cannot:

* edit OCR
* correct OCR
* write changes back to the PDF
* create a new PDF from corrected OCR

Those are separate future features.

---

# 26. OCR Viewer Typography

Use the user's normal reading/body typography where appropriate.

Respect current typography settings where they make sense.

The existing application supports configurable body/heading/code typography. Do not invent a disconnected OCR typography system.

However, OCR text should prioritize readability and selection.

Do not apply excessive editor Markdown styling to OCR text.

OCR is plain recognized text.

---

# 27. OCR Page Navigation

The initial OCR viewer can be vertically continuous.

However, internally retain page boundaries.

A future page navigation model should be possible.

A practical V1 UI:

```text id="2h13s6"
Page 1
────────────
text...

Page 2
────────────
text...

Page 3
────────────
text...
```

A tablet may later add a page index.

Do not overcomplicate V1.

---

# 28. Copy Entire OCR Result

Implement a single action:

```text id="agv2eg"
Copy OCR Text
```

The output format must be deterministic.

Recommended:

```text id="k9h88h"
Page 1

<page text>


Page 2

<page text>


Page 3

<page text>
```

Use stable separators.

Do not include:

* UUID
* OCR engine
* confidence
* coordinates
* JSON
* internal metadata

---

# 29. Copy Selected Text

Use normal Flutter clipboard behavior.

The clipboard receives only the selected textual content.

No internal document metadata.

---

# 30. OCR Text Viewer Menu

Possible actions:

```text id="zwb8ps"
Copy All
OCR Language
Regenerate OCR
```

Only show actions appropriate to current state.

Do not add PDF editing actions here.

---

# 31. OCR Processing UI

When OCR is processing, show a subtle state.

Examples:

```text id="5bhwxr"
Processing text…
```

or:

```text id="k9x4md"
Preparing searchable text…
```

Do not show:

```text id="e6b3r8"
ML Kit initializing...
Tensor inference...
Page 3/12...
```

unless inside a deliberate debug build.

---

# 32. OCR Failure UI

If OCR fails:

Document card:

```text id="01uqbt"
4 pages · Text unavailable
```

Menu:

```text id="w1qu0q"
Retry OCR
```

An error explanation may say:

> Quiet Paper couldn't recognize text from this document.

Do not expose package/library names to the user.

---

# 33. OCR Not Needed

If a PDF already contains a useful text layer, OCR processing should complete via extraction rather than ML OCR.

The user-facing state should still simply become:

```text id="6v2x4l"
Searchable
```

Do not make the user care whether text came from embedded PDF text or OCR.

The source can be stored internally for diagnostics/reprocessing.

---

# 34. Scanner OCR Flow

For scanned pages:

```text id="rcogee"
Camera capture
 ↓
automatic document detection
 ↓
perspective correction
 ↓
crop/rotate/brightness/contrast/saturation/grayscale
 ↓
final page raster
 ├──────────────┐
 ▼              ▼
PDF page       OCR input
```

OCR MUST run against the final rendered page, not the unedited camera capture.

This ensures the OCR matches what the user saved into the PDF.

---

# 35. PDF Import OCR Flow

For imported PDFs:

```text id="b2fyzb"
Import PDF
 ↓
preserve original PDF
 ↓
check text layer
    ├── usable → normalize text
    └── absent → render → OCR
 ↓
store OCR
```

Do not alter the imported PDF to create OCR.

---

# 36. OCR Processing Queue

The document processor must support:

```text id="h09wxt"
extractPdfText
runOcr
```

and existing processing tasks such as:

```text id="02zo0a"
generatePreview
generateThumbnail
```

Do not make OCR part of synchronous document insertion.

---

# 37. Process Restart

If OCR is interrupted:

* document remains valid
* PDF remains intact
* OCR status returns to a recoverable state
* next app launch can resume/retry

Do not ask the user to rescan/reimport.

---

# 38. Offline OCR

OCR must work without network access.

Test:

```text id="5tfr7a"
airplane mode
 ↓
scan/import
 ↓
OCR
 ↓
View OCR Text
```

Everything must work locally.

No network request should be necessary for OCR.

---

# 39. OCR and Cloud Sync

The PDF and OCR are independently synchronized resources/derived data.

Example:

```text id="6y9mrv"
PDF:
    synced

OCR:
    local only
```

is valid.

Later OCR can synchronize when available.

Alternatively, if product policy chooses to sync OCR together with the document metadata, keep the payload encrypted.

Do not force the PDF upload to wait for OCR.

Do not force OCR to wait for cloud upload.

---

# 40. OCR Encryption

The OCR payload MUST be encrypted before synchronization.

Conceptually:

```text id="p16cl5"
OCR structure
 ↓
serialize
 ↓
encrypt locally
 ↓
sync/storage
```

Use the existing Quiet Paper master-key infrastructure.

Do not create a separate OCR password.

Use dedicated associated-data context and explicit versioning.

---

# 41. OCR Storage

A practical initial storage design:

```text id="b9h5n3"
document_ocr_pages
────────────────────────
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

```json id="0qh95m"
{
  "text": "...",
  "sourceWidth": 2480,
  "sourceHeight": 3508,
  "blocks": [...]
}
```

This keeps the Drift schema manageable.

Do not create multiple relational tables for every word/line/block unless benchmarking proves that it is necessary.

---

# 42. OCR Schema Versioning

Use a stable:

```text id="jyqnw1"
ocrSchemaVersion
```

The current version should start at `1`.

If the structure changes in the future:

```text id="au1rcv"
schema 1 → schema 2
```

must be migratable/regenerable.

---

# 43. OCR Engine Metadata

Store:

```text id="6sj5jc"
ocrEngine
ocrEngineVersion
language
ocrSchemaVersion
```

This makes derived data reproducible and allows future reprocessing.

Do not show these fields in normal user UI.

---

# 44. OCR Language Configuration

The selected OCR language is configuration, not Markdown content.

Do not put language in:

```markdown id="od2n6n"
[Document](qp://document/id)
```

Do not make document identity dependent on OCR language.

A document remains the same document regardless of whether OCR is run in English later.

---

# 45. Future Multilingual Architecture

Even though V1 supports English only, do not design:

```text id="ny3iyy"
Document
  language: String
```

as an arbitrary UI string.

Use a stable enum/code.

Future examples:

```text id="qx9tpt"
en
nl
de
fr
es
```

The OCR viewer should not require architectural changes when those arrive.

---

# 46. OCR Search Foundation — Do Not Fully Implement Yet

Prepare the search layer for:

```text id="tsg680"
Search query
 ↓
OCR text index
 ↓
document result
 ↓
page number
 ↓
normalized bounding box
```

Do not yet implement the global UI for searching across OCR documents unless it is already trivial to add.

The important part is preserving sufficient structured OCR data.

---

# 47. Future Search Result Shape

Design the internal model so a future search result can look like:

```text id="r8ll4s"
OcrSearchMatch
 ├── documentId
 ├── pageNumber
 ├── text
 └── bounds
```

This is a foundation only.

Do not expose raw search internals to users yet.

---

# 48. Future Highlighting

Preserve geometry so the future viewer can:

```text id="y9e5h6"
open document
 ↓
page 3
 ↓
jump to bounding box
 ↓
highlight matched OCR text
```

Do not implement the highlighting feature now unless needed for the current viewer architecture.

---

# 49. Future OCR Overlay

Do not implement selectable OCR overlays on top of the PDF in this phase.

However, ensure:

* page dimensions are available
* normalized geometry is correct
* viewer has a page-coordinate conversion layer

so future overlay implementation does not require redesign.

---

# 50. No OCR Editing

V1 OCR is read-only.

Do not implement:

* OCR correction
* word editing
* page text editing
* PDF text replacement
* regenerated PDF from edited OCR

The source of truth remains the PDF.

---

# 51. Existing Image and Document Systems

Do not break existing image attachments.

Do not duplicate Cloudinary upload infrastructure.

Do not duplicate encryption.

Do not create a separate resource URI system.

Extend existing abstractions.

The resource hierarchy remains:

```text id="7lo23c"
asset
document
note
```

---

# 52. Direct Cloudinary Requirements Remain

The PDF binary path remains:

```text id="l4b8ca"
Flutter
 ↓
encrypt
 ↓
Cloudinary
```

Never:

```text id="k5fn19"
Flutter
 ↓
Vercel
 ↓
Cloudinary
```

for PDF bytes.

Vercel handles:

* authentication
* authorization
* metadata
* upload authorization
* synchronization
* deletion authorization

Vercel must never receive plaintext or encrypted PDF byte streams.

---

# 53. Existing Backup Requirements Remain

OCR and documents must continue participating in backup/restore.

The backup must preserve:

* document references
* document records
* canonical PDF
* OCR processing metadata
* encrypted OCR payload where appropriate
* OCR language
* OCR schema/engine metadata

Restore must not silently lose OCR.

Existing `.qpbackup` encryption and restore semantics must remain intact.

---

# 54. Read-Only Notes

Read-only mode remains read-only.

Users may view OCR and copy OCR text from a read-only note.

Users may NOT:

* regenerate OCR
* change OCR language for processing
* delete the document
* replace the document
* create a new scan

unless the action is explicitly non-mutating.

Viewing/copying is allowed.

---

# 55. Locked/Password-Protected Notes

If the note is locked:

* PDF remains unavailable until the note/document security requirements are satisfied
* OCR text remains unavailable
* OCR copy must not bypass the lock
* OCR data must not appear in notifications/logs
* document previews must remain protected

The existing note-level security architecture must remain the authority.

---

# 56. Accessibility

OCR text viewer must support:

* accessible text
* selectable text
* logical page headings
* reasonable text scaling
* screen-reader compatibility
* dark mode
* keyboard navigation where supported

Do not render OCR purely as custom painted pixels.

Use normal accessible text widgets.

---

# 57. Tablet UX

On tablets:

* document viewer remains comfortable
* OCR viewer uses sensible max-width
* content does not stretch unnecessarily
* page text can be centered/constrained
* existing Quiet Paper tablet width conventions should be respected

The existing application already constrains wide layouts such as Settings to reasonable max widths. Follow similar conventions.

---

# 58. OCR Text Viewer Navigation

The back button returns to the document viewer.

The document viewer returns to the note/editor.

Do not push multiple unnecessary nested routes for every OCR page.

Use the project's existing navigation architecture.

---

# 59. OCR Status Refresh

If OCR completes while the document is already open:

* update the UI reactively
* avoid requiring the user to close/reopen the document
* show "Searchable" when available
* enable View OCR Text immediately

Use the existing Riverpod/state management architecture.

---

# 60. OCR Progress

Do not require exact percentage progress.

OCR engine progress may not map reliably to a meaningful percentage.

Prefer status:

```text id="t90r6v"
Processing text…
```

and, if reliable:

```text id="m0t0sv"
Processing page 3 of 8…
```

Do not fake percentages.

---

# 61. OCR Cancellation

If practical, support cancellation from the document/OCR processing action.

If cancellation is not safe with the chosen OCR engine, allow the job to finish in the background while keeping UI navigation free.

Do not corrupt partial OCR data.

If cancellation is implemented:

* preserve last known valid OCR
* do not overwrite good OCR with partial OCR
* move state to an appropriate retryable status

---

# 62. OCR Atomicity

When generating OCR:

Do not replace a good existing OCR payload with partial processing results.

Preferred:

```text id="q9be6s"
existing OCR
      ↓
new OCR processing
      ↓
complete success
      ↓
atomic replace
```

If new OCR fails:

```text id="9p3wxo"
existing OCR remains intact
state = failed/stale
```

This is especially important when regenerating OCR.

---

# 63. OCR Regeneration

If OCR is regenerated with:

* new language
* new OCR engine
* new schema

do not delete the old OCR until new OCR succeeds.

Build new result.

Validate.

Encrypt.

Persist.

Then atomically replace the current OCR version.

---

# 64. OCR Language Change Workflow

Current release has only English, so changing language is not yet a meaningful user workflow.

However, architect it as:

```text id="r9bnwr"
select language
 ↓
document OCR becomes stale
 ↓
user chooses Regenerate OCR
 ↓
new language OCR generated
 ↓
old OCR retained until success
```

Do not automatically destroy old OCR merely because the preference changes.

---

# 65. OCR Text Quality

Do not perform semantic correction.

Do not use language models to rewrite OCR.

Preserve what the OCR engine recognized.

OCR text is for:

* viewing
* copying
* future searching

not automatic content modification.

---

# 66. OCR Copy Formatting

Use predictable formatting.

For example:

```text id="a2h5tr"
Page 1
================================

ACME CORPORATION

Invoice #4829

TOTAL €2,297


Page 2
================================

...
```

The separator can use the app's own convention.

The important requirements are:

* page boundaries remain clear
* text remains human-readable
* no internal metadata leaks

---

# 67. OCR Viewer Search Within Text

Do NOT implement search within the OCR viewer yet unless the existing TextField/search architecture makes it trivial.

Prepare the structure so later:

```text id="hk3t0j"
OCR Text
      ↓
find "invoice"
      ↓
scroll/highlight
```

can be added cleanly.

---

# 68. OCR Data Integrity

The OCR payload must contain enough metadata to detect stale data.

At minimum compare:

```text id="y20qmb"
document hash
OCR language
OCR engine
OCR schema
```

If the canonical PDF hash changes, old OCR is invalid.

If OCR configuration changes, old OCR may be stale.

---

# 69. Document Hash Relationship

Store:

```text id="4g5oz6"
document.sha256
ocr.sourceDocumentSha256
```

or an equivalent binding.

This ensures OCR belongs to the exact PDF content that generated it.

If:

```text id="38b7fw"
OCR source PDF hash != current PDF hash
```

do not present OCR as current.

Mark it stale.

---

# 70. OCR and Imported PDFs

If imported PDF is byte-preserved:

```text id="sv87nh"
PDF hash
```

must remain stable.

If OCR is generated from a rendered page, OCR's source-document hash binds it to that PDF.

No need to rewrite the PDF.

---

# 71. Unit Tests — OCR Models

Test:

* page ordering
* block ordering
* line ordering
* word ordering
* bounds normalization
* confidence nullable
* language serialization
* source serialization
* schema version
* document hash binding

---

# 72. Unit Tests — OCR Viewer

Test:

* OCR available → View OCR Text exists
* OCR failed → Retry OCR exists
* OCR processing → processing state shown
* OCR unavailable → appropriate state
* text visible
* pages separated
* selection works
* copy selected text
* copy all text

Use widget tests consistent with existing app patterns.

---

# 73. Widget Tests — OCR Menu

Test menu state:

```text id="3dg6o2"
AVAILABLE
PROCESSING
FAILED
NOT_REQUESTED
```

Ensure the right actions appear.

---

# 74. Widget Tests — Language Picker

Test:

* picker opens
* English exists
* English is selected by default
* selected language persists
* stable language code is stored
* unsupported languages are not displayed

---

# 75. Integration Tests — Scanner → OCR

Test:

```text id="8vmi2p"
scan document
 ↓
generate PDF
 ↓
save document
 ↓
insert Markdown
 ↓
OCR job
 ↓
OCR available
 ↓
open document
 ↓
View OCR Text
 ↓
copy text
```

Do not require network.

Mock camera and OCR where appropriate for deterministic CI tests.

---

# 76. Integration Tests — PDF → OCR

Test:

```text id="e6ul47"
import text PDF
 ↓
extract text
 ↓
View OCR Text
```

and:

```text id="n0bl36"
import image-only PDF
 ↓
render
 ↓
OCR
 ↓
View OCR Text
```

---

# 77. Integration Tests — Offline

Test with network unavailable:

```text id="h5ci0c"
scan/import
 ↓
OCR
 ↓
view
 ↓
copy
```

Everything must continue to work.

---

# 78. Integration Tests — Cloud Failure

Test:

```text id="8opd6p"
OCR complete
PDF upload fails
```

OCR should still be viewable locally.

Also:

```text id="0b4j6p"
PDF synced
OCR sync delayed
```

must not prevent PDF viewing.

---

# 79. Security Tests

Verify:

* OCR plaintext never enters network request body
* PDF plaintext never enters network request body
* OCR is encrypted at rest
* OCR is encrypted before synchronization
* backend has no decrypt implementation
* OCR copy is blocked while note security is locked
* document hash/association is validated

---

# 80. Performance Tests

Benchmark at least:

```text id="ldrxs0"
1-page receipt
5-page document
20-page document
```

Measure:

* OCR duration
* memory usage
* UI responsiveness
* OCR payload size
* PDF rendering performance
* OCR viewer rendering performance

Do not optimize blindly.

---

# 81. Dependency Verification

Before finalizing the implementation:

* inspect existing `pubspec.yaml`
* avoid duplicate packages
* verify current Flutter SDK compatibility
* verify Android/iOS compatibility
* verify package licensing
* verify native setup requirements
* verify release build behavior

Do not assume a package works merely because it worked in an older Flutter version.

---

# 82. Static Analysis / Validation

Run the actual project validation commands.

At minimum:

```bash id="t2criw"
flutter analyze
flutter test
```

Run backend validation:

```bash id="j4q6vd"
npm test
npm run build
```

Run code generation if required:

```bash id="6rfu1d"
dart run build_runner build --delete-conflicting-outputs
```

Do not claim any command passed unless it was actually executed.

Do not suppress warnings.

---

# 83. Existing Functionality Must Not Regress

Regression test:

* normal notes
* Markdown editor
* images
* tags
* search
* sync
* backups
* read-only notes
* password-protected notes
* typography
* external links
* existing document viewing
* existing Cloudinary attachments

The project already has substantial automated test coverage. Extend it rather than replacing it.

---

# 84. Explicitly Out of Scope

Do NOT implement in this phase:

* OCR correction/editing
* handwriting recognition
* cloud OCR
* AI OCR cleanup
* OCR summarization
* automatic semantic extraction
* searchable-document global search UI
* exact search-result highlighting
* OCR overlay on PDF
* selecting text directly over the PDF
* OCR-to-PDF rewriting
* OCR-generated editable PDFs
* note-to-note linking UI
* additional OCR languages beyond English
* document annotations
* PDF annotation
* document collaboration

These are future opportunities.

---

# 85. Future Roadmap Enabled by This Phase

The architecture should now make these future features straightforward:

### V2 — Local document search

```text id="vgy0pg"
Search
 ↓
OCR index
 ↓
documents/pages
```

### V3 — Exact search navigation

```text id="29nvq4"
Search result
 ↓
document
 ↓
page
 ↓
normalized bounding box
 ↓
highlight
```

### V4 — OCR overlay

```text id="oix4kl"
PDF
 +
OCR geometry
 ↓
selectable text overlay
```

### V5 — More OCR languages

```text id="9j3gts"
English
Dutch
German
French
...
```

### V6 — OCR correction

Only if a future product decision requires it.

Do not build these now.

---

# 86. Final User Experience

After this implementation, the user should experience:

### Scanner

```text id="w1h4c1"
Scan
 ↓
adjust
 ↓
add pages
 ↓
Done
 ↓
document appears in note
 ↓
OCR processes automatically
```

### Imported PDF

```text id="69yfr8"
Add PDF
 ↓
choose file
 ↓
document appears in note
 ↓
text extraction/OCR processes automatically
```

### Viewing

```text id="d8a1p0"
Open document
 ↓
PDF viewer
 ↓
⋯
 ├── View OCR Text
 ├── Copy OCR Text
 └── Retry/Regenerate OCR when appropriate
```

### OCR text

```text id="w2k4s1"
OCR Text
 ↓
Page 1
text...
 ↓
Page 2
text...
 ↓
Page 3
text...
```

The user can select and copy the text normally.

---

# 87. Final Architectural Invariants

Before declaring this phase complete, verify:

```text id="7q6r9g"
OCR is user-visible.

Users can view OCR text.

Users can copy OCR text.

Users can select and copy portions of OCR text.

OCR is organized by page.

OCR status is visible.

OCR can be retried.

OCR language is user-configurable.

English is the only currently supported language.

OCR language uses a stable internal identifier.

OCR is processed locally.

OCR plaintext never reaches Vercel.

OCR plaintext never reaches Cloudinary.

OCR data is encrypted before synchronization.

PDF remains canonical.

OCR is derived data.

OCR preserves normalized word/line/block positions where available.

OCR binds to the PDF content hash.

OCR can be regenerated without altering the PDF.

Imported text PDFs use their existing text layer where practical.

Scanned PDFs use local OCR when no text layer exists.

Scanner OCR uses the final adjusted page.

OCR processing does not block note editing.

OCR processing does not block PDF upload.

PDF upload remains direct Flutter → Cloudinary.

Vercel remains control plane only.

qp://document/<UUID> remains the canonical document reference.

The Markdown source does not contain OCR data.

No OCR editing exists.

No cloud OCR exists.

No additional OCR languages exist yet.

Existing image/document/sync/backup/security functionality is preserved.
```

---

# 88. Required Agent Completion Report

When finished, report:

1. Files created.
2. Files modified.
3. OCR library selected and exact version.
4. OCR native/platform setup changes.
5. PDF extraction library selected.
6. PDF rendering library selected.
7. Any package additions and licensing notes.
8. OCR language implementation.
9. OCR state model.
10. OCR storage model.
11. OCR encryption format.
12. OCR geometry representation.
13. OCR viewer implementation.
14. Copy/select implementation.
15. Document menu changes.
16. Retry/regeneration behavior.
17. Backup/restore changes.
18. Sync changes.
19. Tests added.
20. Commands actually executed.
21. Actual validation results.
22. Any implementation deviations and why.

Do not claim functionality was implemented unless it is actually implemented and tested.

The finished result should transform OCR from a hidden processing subsystem into a real Quiet Paper capability:

**Scan or import → OCR automatically → see “Searchable” → open “View OCR Text” → select/copy text**, while keeping the PDF authoritative, OCR derived and encrypted, processing fully local, and the existing zero-knowledge/offline-first architecture intact.
