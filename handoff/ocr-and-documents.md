# Quiet Paper — Scanned Documents, PDF Viewer & OCR Architecture

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Document Architecture & Non-Destructive Storage

Quiet Paper treats imported PDFs and scanned paper documents as first-class, non-destructive assets linked to notes via internal URI schemes:
- **Document URI Scheme**: `qp://document/<UUID>`
- **Asset URI Scheme**: `qp://asset/<UUID>`

Documents are encrypted client-side and saved into the app's local document vault. The original binary is never modified or stripped; annotations, OCR text, and display caches remain non-destructive companion layers.

---

## 2. Syncfusion PDF Viewer (`lib/features/pdf_viewer/`)

Quiet Paper migrated from a custom rasterized viewer to the production-grade **Syncfusion Flutter PDF Viewer** (`syncfusion_flutter_pdfviewer`):
- **Smooth 60 FPS Performance**: Supports high-fidelity vector rendering, virtualized page rendering, and lag-free pinch-to-zoom (up to 12x zoom range).
- **Dual-Storage Strategy**: Fast memory caching of rendered pages alongside encrypted on-disk storage.
- **Custom Floating Selection Menu**: Quiet Paper branded context menu for copying text, highlighting, or searching directly from the PDF canvas.
- **In-Document Search**: High-speed keyword search with occurrence cycling and highlight markers.

---

## 3. OCR Engines & Text Extraction Pipelines

The OCR system lives in [`lib/core/ocr/`](file:///home/dog/git/quitepaper/lib/core/ocr/) and [`lib/core/pdf/`](file:///home/dog/git/quitepaper/lib/core/pdf/).

### Direct Vector Text Layer Bypass
- Before running heavy optical recognition on a PDF, the extraction engine inspects whether the document already possesses embedded digital text layers.
- If selectable digital text is present, it is extracted immediately via background isolates without invoking computer vision models, saving battery and CPU cycles.

### Mobile: Hardware-Accelerated Google ML Kit
- **Platform**: Android & iOS.
- **Engine**: Google ML Kit Text Recognition with bundled standalone models (does not depend on Google Play Services dynamic delivery).
- **Architecture**:
  - Processing runs in background Dart isolates (`compute`) to keep the UI running at 60 FPS.
  - Multi-page PDFs are chunked into batches to prevent memory spikes.
  - Hardened with ProGuard / R8 keep rules to eliminate NPEs during release minification.

### Desktop: Local LLM & DeepSeek-OCR / Ollama
- **Platform**: Linux, macOS, Windows.
- **Engine**: Local Ollama server executing DeepSeek-OCR vision models.
- **Key Enhancements**:
  - **Markdown Table Conversion**: Automatically detects tabular data in scanned receipts/documents and formats them into standard Markdown tables.
  - **Coordinate Clamping**: Defensive clamping avoids `ArgumentError` when bounding boxes touch canvas borders.
  - **Paragraph-Aware Visual Line/Word Partitioning**: Groups visually adjacent word tokens into coherent paragraphs.
  - **Clean Prompt Canonicalization**: Eliminates hallucinated tutorial text from local model responses.

---

## 4. Zero-Knowledge OCR Text Sync & Processing Policy

- **Manual-Only Recognition Policy**: OCR does not run automatically in the background for battery and privacy reasons; it is triggered manually or on explicit document import settings.
- **Encrypted Sync Pipeline**: Extracted OCR text is encrypted using the user's master key and synced to the cloud alongside note metadata.
- **Global Search Integration**: Decrypted OCR text is fully searchable across the entire notebook via the global search interface, with direct jump-to-page navigation.

---

## Key References & Logs
- Syncfusion PDF Viewer Migration: [Latest Logs, Section 215 & 217](latest-logs.md#215-feature-syncfusion-flutter-pdf-viewer-migration-with-non-destructive-dual-storage-october-2026)
- Custom Floating Menu & PDF Search: [Latest Logs, Section 216](latest-logs.md#216-feature-quiet-paper-custom-floating-text-selection-menu--in-document-pdf-search-october-2026)
- DeepSeek-OCR Table Formatting & Ollama Integration: [Latest Logs, Section 211–214](latest-logs.md#211-deepseek-ocr-table-formatting--native-markdown-table-conversion-october-2026)
- Zero-Knowledge OCR Text Sync: [Latest Logs, Section 218 & 235](latest-logs.md#218-feature-zero-knowledge-ocr-text-sync-manual-only-recognition-policy-and-3-way-conflict-merge-pipeline-october-2026)
- Google ML Kit OCR Integration & Isolate Processing: [Historical Logs v1.0–v1.4, Section 46–52](archive/logs-v1.0-v1.4.md#46-hardware-accelerated-google-ml-kit-ocr-engine-integration)
