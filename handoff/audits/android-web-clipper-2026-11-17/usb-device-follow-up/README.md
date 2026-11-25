# Android USB follow-up — 2026-11-17

**Historical audit: six additional bugs, WC-11 through WC-16. Five have physical-device/real-page evidence; WC-15 is a focused component reproduction.** The original WC-09 save/navigation bug and WC-07 stale-message state are also reproduced on the phone. No application fix was made.

All six have since been fixed. Current statuses and regression validation are linked from the [main audit index](../README.md); the device evidence below describes the original unfixed source. [Evidence](evidence.md) contains the observed counts, state, focused checks and screenshots; [replay sources](replay.md) preserve the exact executed harness and component probes.

## Device and isolation

- Redmi K20 Pro, Android 16, arm64-v8a, connected through authorized USB debugging.
- Physical display 1080×2340, density 440dpi (2.75 pixels per logical pixel), system font scale 1.0.
- Android System WebView 145.0.7632.45.
- Application source: 810704c40ce943d9b339279e5b83193001d32b01, unchanged from the initial audit.
- Separate package com.blackpiratex.quietpaper.audit, labeled Quiet Paper Audit. The existing production package was not updated, cleared or uninstalled.
- Dedicated in-memory test notebook, synthetic encryption key, anonymous auth provider, actual clipper services and real network responses. No sign-in or sync engine. Attachment/snapshot storage belongs to the separate audit app.

The resource-limited Android build completed in 174.6 seconds with a 2GB Java heap and one worker. Builds and tests were serialized, with no emulator. An earlier emulator attempt ended after the user reported a laptop crash; none of its incomplete results are counted here.

## Real links exercised

| Public link | Path used | Observation |
| --- | --- | --- |
| [Paul Graham essay](https://www.paulgraham.com/ds.html) | Phone direct HTTP, native URL dialog/save, actual WebView capture/save | Direct response repeats prose three times; mobile WebView receives different markup. Native save confirms WC-09. |
| [RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html) | Phone direct HTTP and actual WebView capture | Both select the index appendix instead of the document. |
| [Hexo Writing](https://hexo.io/docs/writing.html) | Phone direct HTTP and actual WebView capture | Two code example strings remain in the cleaned DOM but disappear from Markdown. |
| [NASA Stars](https://science.nasa.gov/universe/stars/) | Phone direct HTTP | Acquisition control. Matching star-alt cards were outside the selected article; no live photo-loss claim. |
| [MDN Array.map](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/map) | Phone direct HTTP | Acquisition control; all 18 pre blocks remain in the cleaned DOM. |
| [Wikipedia Flutter](https://en.wikipedia.org/wiki/Flutter_(software)) | Phone direct HTTP | Acquisition control; all 13 identified article/main paragraphs remain. |
| [Wikipedia Star](https://en.wikipedia.org/wiki/Star) | Phone direct HTTP | Acquisition control, not a reproduction of WC-15. |
| [NeverSSL](http://neverssl.com/) | Actual WebView navigation | Android cleartext-policy failure is incorrectly followed by Ready to clip. |

Direct-scan controls do not prove full content fidelity. The table separates these controls from confirmed defects. No authenticated or paywalled website was tested.

## Validation and cleanup

- 23 relevant existing tests and four temporary characterization probes pass, with concurrency 1. The exact file list and output are in evidence.md.
- Static analysis is recorded in the main audit index after temporary Dart sources are removed.
- No full test suite ran.
- All temporary Android build configuration and manifest changes were restored.
- The separate audit app and its synthetic data were uninstalled, both USB forwards removed, and the original Quiet Paper package remained installed.
- Generated audit APK copies and the earlier Linux audit bundle were removed; no normal Linux rebuild was attempted after the host crash.
- Executable harness/probe source is archived in Markdown and removed from lib/ and test/. No production Dart, Kotlin or manifest changes are part of this audit.

A native loading-state layout bug was initially suspected to be in the preview. The actual screenshot narrows WC-11 to the URL dialog’s spinner; the settled preview footer fits. No extra preview-layout bug is counted.
