# WC-15: A meaningful photo is rejected when its alt text mentions a star

Status: **Fixed**. Priority: **P2**. Added during the physical-device follow-up on 2026-11-17. Application source remains `810704c40ce943d9b339279e5b83193001d32b01`.

## Impact

Article illustrations can be removed solely because their descriptions include a word treated as decoration. This affects a plain img element even when it has large explicit dimensions.

## Reproduction

Pass a 1200×800 photo with alt="A star cluster in a nebula" through ClippedImageFilter.isUsefulContentImage, then repeat with only the word star removed from the alt text.

**Expected:** A content photo remains useful in both cases; mentioning its astronomical subject does not make it a rating icon.

**Observed:** The same URL and dimensions are rejected with the star description and accepted with the neutral description.

## Evidence and cause

The decorative alt regular expression matches the substring star without contextual or word-boundary checks. Both DOM image filtering and URL candidate filtering reuse this expression.

Confirmed by the focused component probe. No specific photo loss on the live NASA Stars or Wikipedia Star pages is claimed: the matching NASA card was outside the selected article, and the Wikipedia photographs lacked the relevant alt text. This is the one new finding without a matching live-page reproduction.

See [USB follow-up evidence](usb-device-follow-up/evidence.md) for numeric observations, device setup, limitations and the exact executed harness. No fix was made.

## Source locations

- [`lib/core/web_clipper/clipped_image_filter.dart:20`](../../../lib/core/web_clipper/clipped_image_filter.dart#L20)
- [`lib/core/web_clipper/clipped_image_filter.dart:103`](../../../lib/core/web_clipper/clipped_image_filter.dart#L103)
- [`lib/core/web_clipper/clipped_image_filter.dart:146`](../../../lib/core/web_clipper/clipped_image_filter.dart#L146)

## Resolution

Alt-text filtering no longer treats the substring star as decoration. Astronomy photos, Star labels and Startup descriptions survive both DOM and URL filtering; explicit rating-star labels and tiny icons remain excluded.

Validation: flutter analyze: clean; 17 image-filter, picture extraction and scanner tests passed. No full suite ran.
