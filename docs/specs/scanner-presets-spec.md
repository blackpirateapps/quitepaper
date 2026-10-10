# Document Scanner Presets — Feature Spec

> Status: **Approved design, not yet built.** Author: product brainstorm, 2026-10-09.
> Audience: a coding agent / reviewer picking this up cold in a new session.
> Pairs with [`scanner-presets-design.md`](./scanner-presets-design.md) (the technical design).
> Read §0–§3 before touching anything.

---

## 0. Summary

Make the document scanner feel like a real scanner instead of a camera. Add Office Lens–style
**capture modes** (Auto / Magic, Document, Whiteboard, Grayscale, B&W Text, Original) powered by
**OpenCV**, selected from a **post-capture thumbnail carousel**. Mobile only (Android/iOS). The
existing manual tone sliders and crop/rotate stay and layer on top of the chosen mode.

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
- Six capture **modes** (§4), each a distinct OpenCV pipeline.
- **Post-capture carousel**: after a page is captured, a strip of thumbnails previews every mode;
  tapping one selects it for that page.
- **Per-page** mode selection in multi-page scans; **remember last-used mode** within a scan session.
- Manual **tone sliders** (brightness/contrast/saturation/grayscale) and **crop/rotate** continue to
  work, layered on top of the selected mode.
- OpenCV shipped on **Android + iOS** only.
- *(Nice-to-have, same effort)* upgrade `enhanceForOcr()` to use the B&W pipeline, to help ML Kit.

### Out of scope — deferred, do not build here
- **Real edge detection + perspective dewarping** (replacing the 3% inset). Own spec, later.
- **Live preset preview in the viewfinder.** Post-capture only. (Live manual sliders stay.)
- **Automatic mode detection** (guessing whiteboard vs document). Manual selection first.
- **OpenCV on desktop.** Desktop/simulator stay import-only on the existing Dart processor.
- Any change to PDF compilation, encryption (QPD1), sync, or the OCR subsystem beyond `enhanceForOcr`.

---

## 3. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Processing library | `opencv_core` (opencv_dart family) | Apache-2.0, permissive, FFI; project already has `ffi`. Image-only package, no video. |
| Platforms | Mobile only (Android/iOS) | Live camera is mobile-only; desktop is already import-only. Smallest footprint. |
| App size | A few MB per ABI accepted | Confirmed not a concern. |
| Preview | Post-capture carousel | Live viewfinder processing is far heavier; carousel matches Office Lens and is cheap. |
| Scope | Presets first; detection later | Separable; presets are the biggest perceived win with the least risk. |
| Mode selection | Manual first | Auto-detection deferred. |
| Fallback | Keep `DartImageProcessor` | Desktop + any platform without native libs degrades gracefully. |

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
- **Graceful degradation:** if native OpenCV is unavailable (desktop, load failure), fall back to
  the current Dart processor; modes that can't be reproduced approximate with existing knobs or are
  hidden. No crash, no blank page.
- **Non-destructive:** mode + manual adjustments are parameters applied at compile time; the raw
  capture drives every re-render during the scan session.

---

## 7. Acceptance criteria

- [ ] Capturing a page shows a carousel with a live thumbnail for all six modes.
- [ ] Selecting **B&W** yields adaptively-thresholded output (clean on uneven lighting), not a
      globally-darkened grayscale image.
- [ ] Selecting **Auto** visibly removes a soft desk shadow that the old `auto` preset left in.
- [ ] **Whiteboard** drives a gray whiteboard background toward white and keeps marker color.
- [ ] Each page in a multi-page scan can hold a different mode; new captures reuse the last mode.
- [ ] Manual sliders + crop/rotate still work and compose with the mode.
- [ ] Desktop/import path still works with no OpenCV present.
- [ ] `flutter analyze` clean; tests (incl. new golden/pipeline tests) pass.
- [ ] App size increase measured and recorded in HANDOFF.

---

## 8. Phasing

- **Phase 0 — Dependency spike.** Add `opencv_core`, build Android + iOS, measure size + CI impact.
  Abort/rethink if build or size surprises.
- **Phase 1 — Core pipelines.** `OpenCvImageProcessor` + `ScanMode` enum + **Auto** and **B&W**
  wired into the existing single-mode render path (no carousel yet). Prove quality.
- **Phase 2 — Carousel + remaining modes.** Document, Whiteboard, Grayscale, Original + the
  post-capture carousel UI + per-page/last-used state.
- **Phase 3 — (optional) OCR polish.** Route `enhanceForOcr()` through the B&W pipeline.
- **Later / separate spec — Real detection.** Edge detection + perspective dewarping.

---

## 9. Risks & open questions

- **Build/CI:** the plugin links prebuilt native libs at build time; validate offline/CI builds in
  Phase 0.
- **B&W parameters are DPI-sensitive:** `adaptiveThreshold` block size/C need tuning against real
  captures at your 2048px bound. Expect a tuning pass with sample fixtures.
- **Mode × manual-knob precedence** must be defined (see design §7) — e.g. the grayscale toggle is
  redundant under B&W mode.
- **Open:** should the selected mode persist into a resumable scan *draft* (if drafts exist), or is
  it purely in-session? Confirm whether scan drafts are serialized today.

