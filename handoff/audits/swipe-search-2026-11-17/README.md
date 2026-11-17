# Notes-list swipe-search animation audit — November 17, 2026

Audited the real `NotesScreen` in a separate native Linux debug window under
Hyprland/Wayland, before and after the fix. The harness uses an in-memory database,
35 sample notes, isolated XDG directories and a separate D-Bus session. No user
notes are opened or changed. Phone layout is 420 × 800dp; tablet is 1024 × 800dp.
Baseline revision: `5d869e94e8c6b45c82fdfb9ffbed56febcfba81b`.
The final branch also integrates main `6fa397e`, whose editor fixes leave the
notes/search source unchanged. All 49 relevant tests, analysis and the normal
Linux build pass again after that integration; the linked logs record that run.

Native input comes from a Wayland virtual pointer: real button and motion events
enter the running Flutter engine. The harness enables mouse dragging and overrides
the target platform to Android to exercise the mobile list physics. It does not
inject Flutter gesture notifications. Screenshots and post-layout frame snapshots
record the actual render tree, scroll positions, search state and Flutter errors.

## Confirmed failures and fixes

| Finding | Before | After |
| --- | --- | --- |
| List bounce adds a second movement underneath the translated card | Up to **111.61dp** extra row movement during the full pull | **0dp** extra movement in the corresponding captured frames |
| Back during opening is ignored | Early native Back tap leaves search open | Same replay closes search and restores the list |

The old scroll-notification release path could also wait for the ballistic bounce
to finish. The fix handles pointer release/cancel directly while keeping scroll
notifications responsible for arming. `PullDownSearchScrollPhysics` holds the list
at its minimum only while the deliberate reveal owns the gesture, including upward
reversal. Ordinary mid-list scrolling retains the platform physics.

One animation controller now handles spring-back, opening and closing from the
current position. It accepts Back during opening and reopening during closing.
Search receives focus only when the opening slide completes; closing removes focus.
An inline `PopScope` follows the reveal's own state, so system Back can close it
without depending on a parent rebuild. A canceled pointer always restores notes.

Compare the [baseline held pull](baseline-full-held.png) with the
[fixed held pull](fixed-full-held.png). Completed search is captured for
[phone](fixed-full-end.png), [tablet](fixed-tablet-full-end.png) and the
[empty phone list during a pull](fixed-empty-full-held.png).

## Verification

All **12 native cases pass**, with zero recorded Flutter errors: short pull,
full pull, upward reversal and early Back, each on populated phone, populated
tablet and empty phone layouts. Tablet intentionally opens the existing full-window
search route after the compact reveal. Once reversal consumes the tablet reveal,
further upward movement scrolls notes normally. Each independent pull begins at
rest at the top; the replay restores the list after that normal upward scroll.

[Native checks and derived metrics](native-summary.json) accompany
[compressed raw frame/state evidence](native-frames.json.gz). Metrics use completed
layout frames; immediate HTTP snapshots can fall between a state change and paint.

`flutter analyze`: **no issues**. All **49 relevant tests pass** across:

- `test/features/notes/pull_down_search_animation_test.dart`
- `test/features/notes/gestures_test.dart`
- `test/editor/in_note_search_test.dart`
- `test/search/search_workspace_test.dart`

The eight animation tests cover single movement, immediate release, reversal,
pointer cancellation, interrupted opening/closing/spring-back, system Back and
mid-list flings. Notes-screen integration also verifies focus timing and early
Back with the actual search screen. Existing tests retain phone/tablet, empty-list,
disabled-setting, desktop toolbar/keyboard and drawer coverage. See the
[test log](flutter-tests.log.txt) and [analysis log](flutter-analyze.log.txt).

The audit window is closed and the ordinary `lib/main.dart` Linux debug bundle
is rebuilt after verification; see the [build log](flutter-linux-build.log.txt)
and [final native replay log](native-replay.log.txt). No full test suite was run.

## Replay and limits

Sources are retained in [`replay/`](replay/). Copy `harness.dart.txt` to
`.dart_tool/swipe-audit/main.dart`, and the Python `.txt` sources to their `.py`
names in `/tmp/qp-swipe-audit/`. Generate `pointer.h` and `pointer-code.c` using
`wayland-scanner client-header/private-code` on `pointer.xml`; compile them with
`pointer.c` using `gcc ... -lwayland-client -lm -o /tmp/qp-swipe-audit/pointer`.
The replay assumes this checkout at `/home/dog/git/quitepaper`, a running Hyprland
session and Flutter's Linux build dependencies. `final_replay.py` builds and starts
the isolated window, runs the 12 cases, closes it, and restores the normal bundle.

Initial click-only input attempts and tablet drags outside the notes pane were
discarded. The retained baseline and final evidence use real motion inside the
measured pane bounds. Window-mapping startup races were corrected with polling.
System Back, pointer cancellation and keyboard focus timing use widget tests;
physical Android/iOS touchscreens and software-keyboard animation remain untested.
These are debug-build correctness observations, not release-frame performance
benchmarks. The native harness only records errors; it does not change production
error handling.
