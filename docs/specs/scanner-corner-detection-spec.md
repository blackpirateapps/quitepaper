# Document Scanner — Automatic Corner Detection & Perspective Dewarp (Spec)

> Status: **Not built.** Author: 2026-10-10. The remaining half of the "make the scanner feel real"
> effort; pairs with [`scanner-presets-spec.md`](./scanner-presets-spec.md) (the *look*, done) —
> this is the *shape*.
> Read §0–§3 before touching anything.

---

## 0. Summary

Replace the scanner's **fake auto-crop** with real document geometry: detect the page's four corners
in the captured photo, let the user fine-tune them, and **perspective-dewarp** the quadrilateral into
a flat, rectangular scan. This is what turns an angled desk photo into something that looks fed
through a flatbed.

**Pure Dart, no OpenCV.** OpenCV was dropped from this project for app size
([`scanner-presets-spec.md`](./scanner-presets-spec.md) §3), so detection and the homography warp
are implemented on the `image` package + plain math, on-device, offline.

---

## 1. Problem / Motivation (verified in code, 2026-10-10)

- `DartImageProcessor.normalizePage()` returns a hardcoded 3% inset
  `NormalizedRect(0.03, 0.03, 0.94, 0.94)` for **every** image — it detects nothing.
- `estimateDocumentConfidence()` only checks mean luminance (dark/washed-out → low), not edges.
- The crop UI (`InteractiveCropOverlay`) is an axis-aligned **rectangle**, so even manual cropping
  cannot correct keystone/perspective skew — a page shot at an angle stays a trapezoid.

Result: angled or partial captures produce skewed pages with background bleed. The presets fixed the
tone; nothing fixes the shape.

---

## 2. Scope

### In scope
- A **4-corner (quadrilateral) adjustable overlay** replacing/extending the rectangular crop, with
  draggable corner handles and a magnifier loupe for precision.
- **Perspective dewarp**: map the chosen quad onto an upright rectangle (homography + bilinear
  sampling), baked at final compile — composed *before* the `ScanMode` pipeline (geometry → mode →
  tone, extending the presets order).
- **Best-effort automatic corner detection** to pre-fill the handles (user always confirms/adjusts).
- Output aspect-ratio estimation from the detected quad (so a dewarped A4 looks like A4, not square).

### Out of scope
- ML-based document segmentation / any model download.
- Live corner tracking in the viewfinder (detection runs **post-capture**, like the mode carousel).
- Multi-document detection in one frame.
- Re-detecting on imported (non-camera) images is best-effort only.

---

## 3. Constraints

- **Pure Dart / `image` pkg**, on-device, offline, zero-knowledge — no new native deps, no network.
- All heavy work off the UI isolate (existing `compute()` pattern), bytes/params in → result out.
- **Non-destructive**: the quad is stored as four normalized points on the scan page and applied at
  compile time; the raw capture still drives every re-render. Degrades to the current full-frame /
  manual rectangle when detection fails or confidence is low.
- Resolution-independent cost: detect on a downscaled copy, map corners back to full res.

---

## 4. Approach

### 4a. Detection (best-effort, pre-fill only)
Pipeline on a downscaled (~500px) grayscale copy:
1. Blur → gradient/edge map (Sobel, already in `image`) → threshold to an edge mask.
2. Find the dominant page boundary. Two candidate techniques, simplest first:
   - **Border-scan + largest-contour heuristic**: flood/scan inward for the biggest bright
     quadrilateral region; fit a 4-gon to its hull.
   - If that proves flaky, a lightweight **Hough line** vote for the 2 strongest near-horizontal and
     2 near-vertical lines, intersected to 4 corners.
3. Score confidence (coverage, convexity, corner angles ≈ 90°, area fraction). Below threshold →
   fall back to the full-frame quad; never force a bad crop.
Corners are mapped back to normalized `[0,1]` coordinates on the full image.

### 4b. Manual adjust
Extend the overlay to a convex quadrilateral: 4 corner handles (clamped to stay convex), edges drawn
between them, a magnifier near the dragged handle, and a "reset to full page" affordance.

### 4c. Perspective dewarp (the core math, pure Dart)
- Compute the **homography** H mapping the 4 source corners → destination rectangle corners (solve
  the 8×8 linear system; standard DLT). Destination size from the quad's estimated width/height
  (average of opposite edge lengths), capped at the 2048px bound.
- **Inverse-map** each destination pixel through H⁻¹ into the source with **bilinear** sampling.
- Runs in the isolate; output feeds the existing `ScanMode` → tone → encode chain.

---

## 5. Integration points

- `ImageProcessor`: add `detectDocumentQuad(bytes) → ({List<Point> corners, double confidence})`
  and `dewarp(bytes, quad, {maxDimension})`; or fold the quad into the existing geometry step of
  `processHighResolution`. Replace `normalizePage`'s hardcoded inset with a detect call.
- `ScannedPage` / `ImageAdjustments`: carry an optional `List<NormalizedPoint> documentQuad` (null =
  no dewarp, use rectangle crop as today). In-session only (no persistence; HANDOFF §41).
- Scanner UI: offer the quad overlay in the capture/adjust flow; auto-detect on capture pre-fills it,
  with a one-tap "use full page" escape.
- Compile order becomes: orientation → **dewarp (if quad)** else rotate/crop → downscale → mode →
  tone → encode.

---

## 6. Phasing

- **Phase 1 — Manual quad + dewarp.** Quad overlay + homography warp wired into compile. High value,
  fully deterministic, no detection flakiness. Ship this first.
- **Phase 2 — Auto-detect pre-fill.** Edge/line detection to seed the handles; confidence gating +
  full-frame fallback.
- **Phase 3 — Polish.** Aspect-ratio estimation, magnifier loupe, confidence hint on capture.

---

## 7. Acceptance criteria

- [ ] A page shot at a moderate angle can be dewarped to a flat rectangle with straight edges.
- [ ] Manual 4-corner adjustment is precise (handles + magnifier) and constrained to a convex quad.
- [ ] Auto-detect pre-fills a sensible quad on a clear page-on-contrasting-background shot, and
      cleanly falls back to full-frame when unsure (no silently-wrong crop).
- [ ] Dewarp composes correctly with the capture modes and tone/rotate (defined order).
- [ ] Pure Dart; `flutter analyze` clean; new pipeline/golden tests pass; no app-size delta.

---

## 8. Risks & open questions

- **Detection robustness in pure Dart** is the hard part (no OpenCV `findContours`/`HoughLines`).
  Mitigation: Phase 1 ships value with manual-only; auto-detect is explicitly best-effort pre-fill.
- **Performance** of per-pixel inverse warp at 2048px — acceptable in an isolate; sample on a mid
  phone and cap destination size if needed.
- **Open:** should dewarp replace the rectangular crop entirely, or coexist (rectangle for simple
  cases, quad when skew is detected)? Leaning coexist: default rectangle, upgrade to quad when
  auto-detect/opt-in.
- **Open:** tuning fixtures — reuse the sample scans gathered for the presets tuning pass.
