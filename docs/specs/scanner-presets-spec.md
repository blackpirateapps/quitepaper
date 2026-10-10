# Document Scanner Presets — Feature Spec

> Status: **Implemented (2026-10-10).** Author: product brainstorm, 2026-10-09.
> Audience: a coding agent / reviewer picking this up cold in a new session.
> Pairs with [`scanner-presets-design.md`](./scanner-presets-design.md) (the technical design).
> Read §0–§3 before touching anything.

> **Implementation status (2026-10-10).** Shipped on `main` in **pure Dart** (the `image`
> package), not OpenCV — see HANDOFF §169. The six capture modes, the post-capture carousel,
> per-page + last-used-mode state, and composition with the tone sliders/crop/rotate are all live
> and tested. OpenCV (`dartcv4`) was prototyped on a branch and **dropped** because the bundled
> native libs increased app size for little gain over the pure-Dart pipelines; the pure-Dart
> processor is the shipping (and only) implementation on every platform. The OpenCV-specific wording
> below is kept as historical design context — read "OpenCV pipeline" as "spatial image pipeline".
>
> **Still outstanding:** automatic document corner detection + perspective dewarp (the fake
> `normalizePage` crop) — see §2 "Out of scope" and [`scanner-corner-detection-spec.md`](./scanner-corner-detection-spec.md).

---

## 0. Summary

Make the document scanner feel like a real scanner instead of a camera. Add Office Lens–style
**capture modes** (Auto / Magic, Document, Whiteboard, Grayscale, B&W Text, Original) powered by
**on-device spatial image pipelines** (shipped in pure Dart), selected from a **post-capture
thumbnail carousel**. Works on all platforms. The existing manual tone sliders and crop/rotate stay
and layer on top of the chosen mode.

This is **presets first**. Real edge-detection + perspective dewarping (to replace today's fake
auto-crop) is explicitly a **separate, later effort** — see §2.

---

## 1. Problem / Motivation

The scanner today opens the camera, lets you crop, and bakes a PDF — but the "scanner" feel is
missing. Concretely (verified in code, 2026-10-09):

- **The presets are fake.** `ImageAdjustments.auto` is just `contrast 0.20 / brightness 0.05`;
  `blackAndWhite` is `grayscale + contrast 0.25 / brightness 0.10`. These are global knobs, not
  scanner algorithms — no adaptive thresholding, shadow removal, or background whitening.
- **The auto-crop is fake.** `normalizePage()` returns a hardcoded 3% inset
  (`NormalizedRect(0.03, 0.03, 0.94, 0.94)`) for every image; `estimateDocumentConfidence()` only
  checks mean luminance. There is no real document detection or perspective correction.

Users photographing a page under uneven desk light get a dim, shadowed, slightly-skewed photo —
not a crisp flat scan. The modes below fix the *look*; the deferred detection work fixes the *shape*.

---

## 2. Scope

### In scope
- Six capture **modes** (§4), each a distinct spatial image pipeline.
- **Post-capture carousel**: after a page is captured, a strip of thumbnails previews every mode;
  tapping one selects it for that page.
- **Per-page** mode selection in multi-page scans; **remember last-used mode** within a scan session.
- Manual **tone sliders** (brightness/contrast/saturation/grayscale) and **crop/rotate** continue to
  work, layered on top of the selected mode.
- Pipelines run on **all platforms** (pure Dart; no native dependency).
- *(Done, same effort)* `enhanceForOcr()` routed through the B&W pipeline, to help ML Kit.

### Out of scope — deferred, do not build here
- **Real edge detection + perspective dewarping** (replacing the 3% inset). **Still outstanding** —
  own spec: [`scanner-corner-detection-spec.md`](./scanner-corner-detection-spec.md).
- **Live preset preview in the viewfinder.** Post-capture only. (Live manual sliders stay.)
- **Automatic mode detection** (guessing whiteboard vs document). Manual selection first.
- Any change to PDF compilation, encryption (QPD1), sync, or the OCR subsystem beyond `enhanceForOcr`.

---

## 3. Locked decisions

| Decision | Choice | Outcome / Rationale |
|---|---|---|
| Processing library | ~~`opencv_core`~~ → **pure Dart (`image` pkg)** | OpenCV (via `dartcv4`) was prototyped then **dropped**: native libs grew app size for little gain. Pure-Dart spatial pipelines ship instead — same `ImageProcessor` seam, works everywhere. |
| Platforms | **All platforms** | Pure Dart has no native requirement, so modes work on desktop/web too (not just mobile). |
| App size | **No increase** | The reason OpenCV was dropped; pure-Dart adds no binary weight. |
| Preview | Post-capture carousel | Live viewfinder processing is far heavier; carousel matches Office Lens and is cheap. |
| Scope | Presets first; detection later | Separable; presets are the biggest perceived win with the least risk. |
| Mode selection | Manual first | Auto-detection deferred. |
| Fallback | `DartImageProcessor` is the impl | It is now the single implementation (OpenCV path removed). |

---

## 4. The modes

Default on capture: **Auto**. Each page remembers its own mode.

| Mode | Intent / when to use | Result |
|---|---|---|
| **Auto (Magic)** | The default. Any document under imperfect lighting. | Shadows flattened, white-balanced, crisp, lightly punchy. "It just looks scanned." |
| **Document (Color)** | Forms, receipts, colored docs where color must stay true. | Flattened lighting + gentle contrast, colors faithful. |
| **Whiteboard** | Photos of whiteboards/flip charts. | Background driven to white, marker colors boosted, glare tamed. |
| **Grayscale** | Mixed text/images where B&W is too harsh. | Neutral gray, mild local contrast. |
| **B&W (Text)** | Pure text pages; smallest files; best OCR input. | Adaptive-thresholded black ink on white, despeckled. |
| **Original** | Escape hatch; photos/art where fidelity matters. | Just geometry (crop/rotate/resize), no tone transform. |

---

## 5. UX flow

1. User captures a page (existing camera flow).
2. Page is processed into the **Auto** look by default and shown on the preview canvas.
3. A **mode carousel** appears (thumbnail per mode, each the current page rendered in that mode).
   Tapping a thumbnail switches the page's mode; the preview updates.
4. Optional fine-tune via the existing **"Tone & Exposure"** sliders and **"Crop & Rotate"** tab
   (`PageAdjustmentSheet`). These apply *on top of* the chosen mode.
5. Repeat per page; each page keeps its own mode. New captures default to the **last-used mode**.
6. **Done** compiles the PDF exactly as today (modes are baked into the final full-res render).

---

## 6. Non-functional constraints

- **Performance:** carousel thumbnails (6 × ~600px) rendered within ~1s of capture on a mid-range
  phone; final full-res (2048px) mode render adds no more than a modest delay to "Done". All heavy
  work off the UI isolate (existing `compute` pattern).
- **Offline & zero-knowledge:** no new network calls. All processing on-device. QPD1 encryption and
  sync paths unchanged.
- **Graceful degradation:** the pure-Dart processor is the single implementation, so there is no
  native-lib availability concern; it runs identically on every platform. No crash, no blank page.
- **Non-destructive:** mode + manual adjustments are parameters applied at compile time; the raw
  capture drives every re-render during the scan session.

---

## 7. Acceptance criteria

- [x] Capturing a page shows a carousel with a live thumbnail for all six modes.
- [x] Selecting **B&W** yields adaptively-thresholded output (clean on uneven lighting), not a
      globally-darkened grayscale image.
- [x] Selecting **Auto** visibly removes a soft desk shadow that the old `auto` preset left in
      (illumination flatten).
- [x] **Whiteboard** drives a gray whiteboard background toward white and keeps marker color.
- [x] Each page in a multi-page scan can hold a different mode; new captures reuse the last mode.
- [x] Manual sliders + crop/rotate still work and compose with the mode.
- [x] Works with no OpenCV present (there is no OpenCV; pure Dart runs everywhere).
- [x] `flutter analyze` clean; tests (incl. new pipeline tests) pass.
- [x] App size: **no increase** (pure Dart). OpenCV was dropped precisely to avoid the increase.

---

## 8. Phasing — as built

- **Phase 1–2 (done, HANDOFF §169).** `ScanMode` enum + `ScanPipelines` (pure Dart) + all six modes
  + the post-capture carousel + per-page/last-used state, wired through the `ImageProcessor` seam.
- **Phase 3 (done).** `enhanceForOcr()` routed through the flatten + adaptive-threshold pipeline.
- **OpenCV spike (done, reverted).** Prototyped `OpenCvImageProcessor` on `dartcv4`; dropped for app
  size (recorded in §169 follow-ups; prototype branch + files deleted).
- **Later / separate spec — Real detection (DONE 2026-10-10).** Edge detection + perspective
  dewarp → [`scanner-corner-detection-spec.md`](./scanner-corner-detection-spec.md) (HANDOFF §172).

---

## 9. Risks & resolved questions

- **B&W parameters are DPI-sensitive:** `adaptiveThreshold` block size/C are scaled to the image but
  a tuning pass against real captures at the 2048px bound is still pending (sample scans to come).
- **Mode × manual-knob precedence** — defined (design §7): under a monochrome mode the saturation
  knob and grayscale toggle are no-ops (disabled in the UI).
- **Resolved — persistence:** scan drafts are **not** serialized today (raw photos are discarded
  after compile; HANDOFF §41), so `ScanMode` is purely in-session and persisted nowhere.

