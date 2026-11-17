# PDF fix verification — November 17, 2026

PDF-09: fixed list extents and direct jumps bound thumbnail requests to eight per
viewport; the pre-fix 16ms-frame regression requested 79 thumbnails for page 125
(`navigation-before.txt`). Concurrent thumbnail renders now share a native PDF
handle and page dimensions, with reference-counted cleanup. PNG compression runs
on a worker isolate; raster safety limits use native dimensions directly.

`native-navigation.json` records a fresh isolated Linux debug process, the same
250-page synthetic PDF and 1180×680 window as the original audit, sidebar open.
All six jumps (2, 125, 200, 50, 249, 1) passed at 0.466–0.759 seconds, including
450ms intentional waiting. Every selected thumbnail was visible; captured Flutter
error arrays were empty. Startup and prior pages may already have cached tiles;
this is not a claim that every request rasterized an uncached page. Release and
physical-device performance remain unmeasured.

Intermediate replays informed the shared-session change and are not counted as
passing final verification. The original harness also attempted to JSON-encode
non-finite transient geometry; the retained verification harness filters those
rectangles. Startup-window targeting and unrefreshed early load-state assertions
were driver calibration failures, excluded from the final results.

18 focused sidebar, renderer and raster-policy tests passed; static analysis was
clean. No full suite ran. Sources are archived as non-executable text.

The isolated native process was closed after verification. The ordinary
`lib/main.dart` Linux debug bundle was rebuilt successfully after all fixes.
