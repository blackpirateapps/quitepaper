# Document Scanner Presets — Technical Design

> Status: **Implemented (2026-10-10).** Author: product brainstorm, 2026-10-09.
> Pairs with [`scanner-presets-spec.md`](./scanner-presets-spec.md) (the feature spec).
> This doc is the *how*; the spec is the *what*. Read the spec's §0–§4 first.

> **Implementation note (2026-10-10).** Built in **pure Dart** (the `image` package), not OpenCV.
> OpenCV (`dartcv4`) was prototyped behind the same seam and **dropped for app size** (HANDOFF §169
> for the shipped design; §170 recorded the reverted OpenCV spike). The §1/§4 OpenCV material below
> is retained as design rationale; the shipping code lives in
> `lib/core/image_processing/scan_pipelines.dart` (spatial ops) + `scan_mode.dart`, called from
> `DartImageProcessor`. Where this doc says "OpenCV", read "the pure-Dart `ScanPipelines`
> equivalent". Automatic corner detection remains unbuilt →
> [`scanner-corner-detection-spec.md`](./scanner-corner-detection-spec.md).

---

## 0. Ground truth (current code, verified 2026-10-09)

- **Seam:** `lib/core/image_processing/image_processor.dart` defines the abstract `ImageProcessor`
  with: `createPageRepresentations`, `process`, `processHighResolution`, `normalizePage`,
  `enhanceForOcr`, `estimateDocumentConfidence`. One implementation: `DartImageProcessor`
  (pure-Dart `image` package).
- **Adjustments model:** `lib/core/image_processing/image_adjustments.dart` — `ImageAdjustments`
  holds `crop`, `rotationQuarterTurns`, `brightness`, `contrast`, `saturation`, `grayscale`; has
  `toColorMatrix()` (4×5 GPU matrix for live preview), `toJson`/`fromJson`, and the two fake presets.
- **Resolutions:** preview 600px, thumbnail 200px, final 2048px (`DartImageProcessor` constants).
- **Final render** currently: `bakeOrientation → rotate → crop → downscale → grayscale → contrast →
  brightness/saturation → encodeJpg(q85)`, run in a `compute()` isolate (`_executeHighResProcessing`).
- **Live preview** uses the GPU color matrix, not the `image` package — fast, but can only express
  linear per-pixel transforms.
- **Persistence note:** per HANDOFF §41, individual raw photos are *not retained* after compile;
  the PDF is the canonical artifact. So **mode is scan-session state**, applied before "Done"; it
  does not need to live in the stored document. (Confirm whether a resumable scan *draft* serializes
  `ImageAdjustments` — if so, `ScanMode` rides alongside it.)

---

## 1. Dependency — none (as built)

- **No new dependency.** The pipelines use the already-present `image` package. OpenCV was
  evaluated (`dartcv4`, the maintained successor to the discontinued `opencv_core`) and removed
  because the bundled native libs grew the app for little gain.
- **Platforms:** pure Dart, so the modes run on every platform (not just mobile).
- **Threading/memory:** no native `Mat` lifetimes to manage. Heavy work runs in the existing
  `compute()` isolate (bytes in → bytes out); the illumination-flatten background is estimated on a
  downscaled copy so cost is roughly resolution-independent.

---

## 2. The new concept: `ScanMode`

A mode selects a whole *pipeline*; it is **orthogonal** to the continuous `ImageAdjustments` knobs.
Do not try to express modes as knob values (that's the mistake the current fake presets make).

```dart
enum ScanMode { original, auto, document, whiteboard, grayscale, blackAndWhite }
```

- Lives on the per-page scan state next to `ImageAdjustments` (both ephemeral scan-session data; see §0).
- Default = `ScanMode.auto`. New captures inherit the last-used mode.
- `ImageAdjustments` stays exactly as-is and applies **on top of** the mode's output.

---

## 3. `ImageProcessor` changes

Add two capabilities, keep the interface the single seam:

```dart
// Decode once, return a 600px render of EACH requested mode for the carousel.
Future<Map<ScanMode, Uint8List>> renderModePreviews(
  Uint8List sourceBytes, {
  List<ScanMode> modes = ScanMode.values,
  int maxDimension = 600,
});

// Add `mode` to the existing render entry points (defaulting to original = today's behavior).
Future<({Uint8List imageBytes, int width, int height})> processHighResolution(
  Uint8List rawBytes,
  ImageAdjustments adjustments, {
  ScanMode mode = ScanMode.original,
  int maxDimension = 2048,
});
```

Implementations:
- **`OpenCvImageProcessor implements ImageProcessor`** — the real pipelines (§4). Used on mobile.
- **`DartImageProcessor`** stays the fallback. Its `renderModePreviews` approximates what it can with
  existing knobs (e.g. `blackAndWhite` ≈ grayscale+contrast) and treats the rest as `original`; its
  `processHighResolution` ignores unknown modes gracefully. No OpenCV import in this class.
- **Selection:** the processor provider picks `OpenCvImageProcessor` when the native lib is present
  (mobile), else `DartImageProcessor`. Wrap the first OpenCV call in a capability check so a missing
  lib falls back instead of throwing.

---

## 4. Pipeline recipes

All operate on the already-geometry-corrected image (after rotate/crop/resize). Parameters are
starting points; expect a tuning pass (spec §9). **As built,** these are implemented in pure Dart in
`ScanPipelines` (`lib/core/image_processing/scan_pipelines.dart`); the OpenCV calls below map 1:1 to
`image`-package equivalents (e.g. `adaptiveThreshold` → local-mean threshold via a downscaled blur;
`divide`/`medianBlur`/`dilate` → their `image` counterparts).

**Building block — illumination flatten** (the core "scanner" trick; powers Auto/Document/Whiteboard):
```
bg   = medianBlur(dilate(src, 7x7), ksize≈21)   // estimate of the lighting/background
flat = divide(src, bg, scale=255)                // or normalize(src - bg + 255)
```
This is what removes soft shadows and uneven lighting — it is spatial, so it **cannot** be a color
matrix or a global contrast curve (which is why today's stack can't do it).

| Mode | Pipeline |
|---|---|
| `original` | No color transform (geometry only). |
| `grayscale` | `cvtColor BGR2GRAY` → mild CLAHE → back to 3-channel for PDF embedding. |
| `blackAndWhite` | gray → illumination flatten → `adaptiveThreshold(255, GAUSSIAN_C, BINARY, block≈21, C≈10)` → `medianBlur(3)` despeckle → optional `morphologyEx OPEN 2×2`. |
| `document` | illumination flatten (gentle) → mild CLAHE on LAB-L → keep colors true (no saturation boost). |
| `auto` | illumination flatten → gray-world white balance (`xphoto` or manual channel-mean scaling) → CLAHE on LAB-L (clip≈2.0, tiles 8×8) → light unsharp (`addWeighted(src,1.5, blur,-0.5)`) → small saturation bump. |
| `whiteboard` | aggressive illumination flatten (background→white) → white balance → HSV saturation ×≈1.3 → optional glare clamp on near-white blown regions. |

---

## 5. Rendering & threading

- Reuse the existing `compute()` isolate pattern. Pass **bytes + mode + adjustments** in, get
  **bytes** out. All `imdecode`/Mat/`imencode` work and disposal happen inside.
- **Carousel:** `renderModePreviews` decodes the 600px source **once**, then applies each mode and
  encodes a thumbnail — one isolate round, N outputs. Cache the map keyed by `ScanMode`; invalidate
  when crop/rotate changes (geometry feeds the mode input).
- Keep JPEG quality as today (preview 75, final 85); B&W may encode smaller.

---

## 6. Preview architecture (hybrid — important)

Modes are **baked**, manual sliders stay **GPU-live**:

- The **carousel** shows baked `renderModePreviews` thumbnails.
- The **main preview canvas** shows the selected mode's baked 600px render, with the existing
  `ImageAdjustments.toColorMatrix()` applied **on top** via `ColorFiltered`. So the user drags
  brightness/contrast/saturation at 60fps over the already-moded image — no re-bake per tick.
- Rationale: adaptive threshold / shadow removal are spatial and can't live in the color matrix, but
  the *fine-tune knobs* still can. Best of both.

---

## 7. Final compile path & precedence

Order of operations when "Done" bakes the full-res (2048px) page:

```
bakeOrientation → rotate → crop → downscale(2048) → [MODE pipeline] → [ImageAdjustments knobs] → encodeJpg
```

Precedence rules (define explicitly to avoid surprises):
- Mode sets the base look; manual knobs fine-tune the result.
- Under `blackAndWhite`, the `grayscale`/`saturation` knobs are **no-ops** (already binarized);
  brightness/contrast still nudge the threshold result. Surface this in the sheet (disable the
  irrelevant controls when B&W is active).
- `original` + neutral adjustments must short-circuit to today's raw-passthrough fast path.

---

## 8. Persistence

- `ScanMode` is in-session per-page state, serialized **only** where `ImageAdjustments` already is
  (scan draft JSON, if any). Add `'scanMode': mode.name` to that JSON; default to `auto` (or
  `original` for backward-compat drafts) when absent.
- Nothing changes in the stored document (`documents` table, QPD1 payload) — mode is baked into the
  PDF before persistence.

---

## 9. Testing

- **Golden/byte tests:** each mode on a set of sample fixtures (shadowed page, whiteboard photo,
  colored receipt) produces stable, inspected output.
- **Fallback test:** `DartImageProcessor.renderModePreviews` returns a thumbnail for every mode and
  never throws when OpenCV is absent.
- **Composition test:** mode + manual knobs + crop/rotate compose in the defined order.
- **Perf guard:** full-res mode render stays within an agreed budget on a representative image.
- **Capability test:** missing-native-lib path falls back without crashing.

---

## 10. Rollout — done

Shipped on `main` (HANDOFF §169): `ScanMode` + `ScanPipelines` + all six modes + carousel +
per-page/last-used state + `enhanceForOcr` polish, `flutter analyze` + `flutter test` clean, no
app-size delta (pure Dart). The OpenCV variant was prototyped and reverted (§170). Remaining work is
the separate automatic corner-detection effort → [`scanner-corner-detection-spec.md`](./scanner-corner-detection-spec.md).

