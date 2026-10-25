# Quiet Paper — First-Run Onboarding & Interactive Coach Marks

**Status:** Implementation-ready. This document is the single source of truth.
**Branch:** `feat/onboarding-flow`
**Scope:** Flutter client only. No backend, API, database schema, sync protocol, or cryptography changes.
**Product owner decisions:** All decisions in this document were explicitly chosen by the user. Do not re-litigate them. If an implementation detail is not stated, choose the simplest option consistent with the existing Quiet Paper design system and this document.

---

## 1. Objective

Add a calm, first-run onboarding experience for Quiet Paper that:

1. Welcomes the user after installing the app.
2. Showcases four headline features:
   - end-to-end encryption + local-first operation,
   - native voice notes + on-device transcription,
   - one-list simplicity with tags and search,
   - built-in offline OCR.
3. Offers optional cloud sync through account creation or sign-in.
4. Offers backup restore and authentication from the Welcome page.
5. Lets the user choose a paper style, brightness, and optionally load sample notes.
6. Ends with an interactive first-note coach-mark tour over the real Notes screen.
7. Can be skipped at any point.
8. Can be replayed from Settings → About → Show welcome tour.

The experience must feel like Quiet Paper: warm, editorial, quiet, typography-led, and free of noisy marketing cards, stock illustrations, or aggressive growth prompts.

---

## 2. Locked decisions

| Area | Decision |
|---|---|
| Presentation | `PageView` carousel, one idea per page |
| Feature structure | Four feature pages: privacy + local-first combined, voice/transcription, simplicity, OCR |
| Visuals | Hand-built Flutter vignettes; no new bitmap assets except the existing app icon |
| Extra pages | Optional sync page, merged “Make it yours” page, first-note page |
| Theme page | Classic/Warm Paper + System/Light/Dark + sample notes |
| Sample notes | Dedicated block/button; loads the existing five sample notes |
| First-note guide | Full interactive coach-mark tour on the real Notes screen |
| Coach interaction | Spotlight is visual only; tour-card buttons drive the flow |
| Coach tour scope | Sidebar/tags → search → create note → editor tips |
| Welcome entry points | Restore a backup, Sign in, Create account |
| Sync entry points | Both Welcome links and a dedicated optional sync page |
| After auth/restore | Show a success page, then enter the app |
| Skip behavior | Sets onboarding complete permanently; replay available in Settings |
| Existing users | See the full onboarding once after this feature ships, then never again |
| Replay location | Settings → About → “Show welcome tour” |
| Copy tone | Playful and warm, still calm and editorial |
| Account requirement | None; local use is fully supported without sign-up |

---

## 3. Non-goals

Do not implement any of the following:

- A required account, sign-up wall, or sync prompt that blocks local use.
- Backend, API, Turso, Firebase, encryption, or sync protocol changes.
- New bitmap illustrations, Lottie files, videos, or screenshot assets.
- A “What’s new” / versioned re-onboarding system.
- Migration detection that silently skips existing users. The user explicitly chose “show to everyone once.”
- Localisation. All onboarding strings are English.
- A new settings screen for onboarding.
- A version bump.
- Changes to the sample note content itself.
- Onboarding inside the existing `SyncAuthScreen`. The existing auth flow remains separate and is opened from the new onboarding.
- Permissions priming for microphone, notifications, or storage. Permissions are requested in context by the features that need them.

---

## 4. High-level flow

```text
App launch
  └── AppRoot
        ├── onboarding_completed_v1 == false ──► OnboardingScreen
        │     ┌──────────────────────────────────────────────────────────┐
        │     │ 1. Welcome                                               │
        │     │      ├── Restore a backup ──► Success ──► NotesScreen    │
        │     │      ├── Sign in ──────────► Success ──► NotesScreen    │
        │     │      ├── Create account ───► Success ──► NotesScreen    │
        │     │      └── Come on in                                    │
        │     ├── 2. Privacy + local-first                             │
        │     ├── 3. Voice + transcription                             │
        │     ├── 4. One list, one way                                 │
        │     ├── 5. Offline OCR                                       │
        │     ├── 6. Optional sync                                     │
        │     │      ├── Create account ──► Success ──► NotesScreen    │
        │     │      ├── Sign in ─────────► Success ──► NotesScreen    │
        │     │      └── Keep it local                                 │
        │     ├── 7. Make it yours (paper style + appearance + samples)│
        │     └── 8. Ready when you are                                │
        │            ├── Show me around ──► NotesScreen + coach marks  │
        │            │                       └── Create note ──► Editor │
        │            │                                          tips   │
        │            └── I'll find my way ──► NotesScreen              │
        └── onboarding_completed_v1 == true ──► NotesScreen
                                                └── if tour not seen:
                                                    show coach marks
```

### Skip paths

- On any carousel page, top-right **Skip**:
  - set `completed = true`,
  - set `tourSeen = true`,
  - leave onboarding.
- On the final first-note page, **I'll find my way** has the same effect.
- On the success page after a completed auth or restore action, **Continue**:
  - set `completed = true`,
  - set `tourSeen = true`,
  - enter NotesScreen.
- The success page has no Skip; the user has already completed a meaningful action.

---

## 5. State machine and persistence

### 5.1 Persistent keys

Create an `OnboardingKeys` class in `lib/features/onboarding/application/onboarding_provider.dart`:

```dart
abstract final class OnboardingKeys {
  static const String completed = 'onboarding_completed_v1';
  static const String tourSeen = 'onboarding_tour_seen_v1';
}
```

No other persistent onboarding keys are required.

- Do **not** persist which carousel page the user reached.
- Do **not** persist whether sample notes were loaded. Use the live active-note count to decide whether the sample block should offer loading.
- Do **not** persist editor-tip dismissal. The editor tips are only passed to the one note created by the coach-mark tour.

### 5.2 State model

```dart
@immutable
class OnboardingStatus {
  const OnboardingStatus({
    required this.completed,
    required this.tourSeen,
  });

  final bool completed;
  final bool tourSeen;

  OnboardingStatus copyWith({bool? completed, bool? tourSeen}) {
    return OnboardingStatus(
      completed: completed ?? this.completed,
      tourSeen: tourSeen ?? this.tourSeen,
    );
  }
}
```

Defaults when the keys are absent:

- `completed = false`
- `tourSeen = false`

### 5.3 Notifier

Create `OnboardingStatusNotifier extends StateNotifier<OnboardingStatus>`.

Required methods:

```dart
Future<void> complete();          // completed = true
Future<void> markTourSeen();      // tourSeen = true
Future<void> clearTourSeen();     // tourSeen = false
Future<void> finishWithoutTour(); // completed = true; tourSeen = true
Future<void> finishWithTour();    // completed = true; tourSeen = false
```

All methods must persist to `SharedPreferences` before or immediately after updating state. Await the `setBool` calls in async methods.

Provider:

```dart
final onboardingStatusProvider =
    StateNotifierProvider<OnboardingStatusNotifier, OnboardingStatus>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return OnboardingStatusNotifier(prefs);
});
```

### 5.4 Completion matrix

| User action | completed | tourSeen | Navigation result |
|---|---:|---:|---|
| Top-right Skip | true | true | NotesScreen |
| Final page “I'll find my way” | true | true | NotesScreen |
| Final page “Show me around” | true | false | NotesScreen + coach marks |
| Success page Continue (auth/restore) | true | true | NotesScreen |
| Coach marks “Skip tour” | unchanged | true | overlay closes |
| Coach marks “Create my first note” | unchanged | true | overlay closes, editor opens |
| Replay → Skip | unchanged (already true) | true | pop back to About |
| Replay → normal finish | unchanged | true | pop back to About |
| Replay → Show me around | unchanged | false | pop to root; coach marks show |
| Replay → auth/restore success → Continue | true | true | pop to root; NotesScreen |

If the app is killed during the carousel, onboarding restarts from page 1.
If the app is killed during coach marks, they reappear on next launch because `tourSeen` is still false.
If the app is killed during editor tips, they do not reappear because `tourSeen` was already set true when the note was created.

### 5.5 Existing users

The user chose **show to everyone once** after this feature ships.

- Do not inspect existing notes or preferences to silently skip onboarding.
- If `onboarding_completed_v1` is absent, show onboarding.
- After the user skips or finishes once, the key is set and onboarding never appears automatically again.
- Existing notes, tags, settings, and sync sessions are left untouched.
- Because existing users may have notes, the sample-notes block detects an existing library and does not offer to load samples again.

---

## 6. App gating and route responsibilities

### 6.1 `lib/app/app_root.dart`

Add:

```dart
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onboardingStatusProvider);

    if (!status.completed) {
      return const OnboardingScreen();
    }

    return NotesScreen(showOnboardingTour: !status.tourSeen);
  }
}
```

Important:

- Do **not** use an `AnimatedSwitcher` here. It would build `NotesScreen` while onboarding is still visible and trigger update checks, auto-backup, and other launch side effects too early.
- `NotesScreen` must preserve its state when `showOnboardingTour` changes. The widget type and position stay the same, so this is safe.
- `AppRoot` is the only place that watches the onboarding provider for the gate. `NotesScreen` receives a boolean prop so direct `NotesScreen` tests do not require onboarding providers.

### 6.2 `lib/app/app.dart`

Change:

```dart
home: const NotesScreen(),
```

to:

```dart
home: const AppRoot(),
```

Add the import.

### 6.3 Launch side effects

`NotesScreen.initState` currently triggers update checks and auto-backup. Those should run only after onboarding is complete because `NotesScreen` is not built until then. This is intentional.

`QuietPaperApp.initState` keeps its search-index integrity check and share/quick-capture initialization. Do not change those.

---

## 7. Onboarding screen structure

### 7.1 Files

Create:

- `lib/features/onboarding/presentation/onboarding_screen.dart`
- `lib/features/onboarding/presentation/widgets/onboarding_page_layout.dart`
- `lib/features/onboarding/presentation/widgets/onboarding_vignettes.dart`
- `lib/features/onboarding/presentation/widgets/onboarding_personalize_page.dart`
- `lib/features/onboarding/presentation/widgets/onboarding_success_page.dart`

### 7.2 Widget shape

```dart
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.isReplay = false});

  final bool isReplay;
}
```

State:

- `PageController _pageController`
- `int _pageIndex = 0`
- `OnboardingSuccessKind _successKind = OnboardingSuccessKind.none`
- `int _restoredCount = 0`
- `bool _isFinishing = false`

`OnboardingSuccessKind`:

```dart
enum OnboardingSuccessKind { none, sync, restore }
```

The screen is a `Scaffold` with `backgroundColor: colors.background` and a `SafeArea`.

Layout:

```text
Column
  ├── top bar (48dp): back button or spacer; Skip on the right unless success
  ├── Expanded
  │     └── PageView (8 pages) or success page
  └── footer (fixed):
        ├── progress dots (hidden on success)
        ├── primary QuietButton (full width, max 520)
        └── optional secondary text button (only on page 8)
```

### 7.3 Top bar

- Height: 48dp.
- Horizontal padding: 16dp on phones, 24dp on tablets.
- Left:
  - If `_pageIndex > 0`: back arrow `Icons.arrow_back_rounded`, 44×44 tap target, tooltip “Back”.
  - On page 1: a 44×44 spacer.
- Right:
  - `TextButton` labelled **Skip**.
  - Style: 14sp, `colors.textSecondary`, min 44dp tap target, 12dp horizontal padding.
  - Hidden on the success page.
- Key: `const Key('onboarding-skip')`.
- Android back and desktop Escape behaviour:
  - Page > 1 → previous page.
  - Page == 1 on first run → allow normal app exit.
  - Page == 1 in replay → pop back to About.
- Use `PopScope` around the scaffold:
  - `canPop` is true only on page 1 and when not showing the success page.
  - `onPopInvokedWithResult`: if not popped and page > 1, go to the previous page.
  - On the success page, `canPop: false`; a system back triggers the same completion as Continue.

### 7.4 Footer

- Horizontal padding: 24dp.
- Top padding: 12dp.
- Bottom padding: 16dp + `MediaQuery.padding.bottom`.
- Max width: 520dp, centered.
- Progress dots:
  - Always 8 dots in the carousel, including the current page.
  - Active: width 18dp, height 6dp, `colors.accent`, radius 3dp.
  - Inactive: 6×6dp, `colors.divider`, radius 3dp.
  - Gap: 6dp.
  - Animate active width with `AnimatedContainer` (180ms) unless `MediaQuery.disableAnimations` is true.
  - Semantics: “Page X of 8”.
- Primary button:
  - `QuietButton` with `isFullWidth: true`, `variant: QuietButtonVariant.primary`.
  - Key: `const Key('onboarding-primary')`.
  - Labels:
    - Page 1: **Come on in**
    - Page 6 (sync): **Keep it local**
    - Page 8: **Show me around**
    - All other pages: **Continue**
- Secondary button on page 8:
  - `TextButton`, label **I'll find my way**.
  - Key: `const Key('onboarding-secondary')`.
  - Same completion behavior as Skip.
- Footer is not part of the scrollable page.

### 7.5 PageView

- `PageView.builder` with 8 items.
- `physics: const PageScrollPhysics()`.
- Horizontal swipe allowed.
- `_pageIndex` updates via `onPageChanged`.
- `animateToPage` duration: 280ms; `Duration.zero` when `MediaQuery.disableAnimations`.
- Keyboard shortcuts on desktop:
  - Right arrow, PageDown, Enter → next page.
  - Left arrow, PageUp → previous page.
  - Escape → Skip.
  - Do not intercept these while an auth screen or dialog is on top.
- Do not use a custom page transition; the default PageView motion is acceptable.

### 7.6 Shared page layout

`OnboardingPageLayout` takes:

```dart
final String eyebrow;
final String title;
final String body;
final Widget? visual;       // Flutter vignette
final Widget? extra;        // controls for the personalize page
final String? footnote;
final bool visualFirst;     // true only for Welcome
```

Layout rules:

- Scrollable with `SingleChildScrollView` and `AlwaysScrollableScrollPhysics`.
- Horizontal content padding:
  - phones: 24dp,
  - width ≥ 700dp: 40dp.
- Maximum content width: 860dp, centered.
- If available width ≥ 760dp:
  - two columns: copy (flex 5) and visual/extra (flex 6),
  - 48dp gap,
  - vertically centred.
- If available width < 760dp:
  - single column:
    - Welcome: visual first, then copy.
    - All other pages: copy first, then visual/extra.
  - Copy → visual gap: 28dp.
- Top padding: 8dp.
- Bottom padding: 24dp.
- Never place the title and body in a fixed-height box.

### 7.7 Typography and colours

Use existing tokens; do not hardcode colours.

- Eyebrow:
  - `AppTypography.caption`,
  - 11.5sp,
  - `FontWeight.w700`,
  - `letterSpacing: 1.2`,
  - `colors.accent`,
  - uppercase.
- Title:
  - `AppTypography.display`,
  - phone 34sp, tablet 40sp,
  - font weight 700,
  - height 1.14,
  - letterSpacing -0.6,
  - `colors.textPrimary`.
- Body:
  - `AppTypography.bodyLarge` on tablets,
  - 17sp / 1.55 line height on phones,
  - `colors.textSecondary`.
- Footnote:
  - 12.5sp,
  - `colors.textTertiary`,
  - height 1.45.
- Links / text buttons:
  - 14sp,
  - `colors.textSecondary`,
  - accent on hover/focus.
- Page background: `colors.background`.
- Cards: `colors.surface`, 1px `colors.divider` border, `AppRadii.borderLg` (16dp), no heavy shadows.
- Accent pills/chips: background `colors.accentSoft`, text `colors.accentDark`, radius 999.
- Use `withValues(alpha: ...)`, consistent with the codebase; do not use deprecated `withOpacity`.

---

## 8. Page-by-page specification

### Page 1 — Welcome

**Eyebrow:** “QUIET PAPER” (optional; omit if the visual already carries the brand)
**Title:** “A quiet place to think.”
**Body:** “No feeds. No algorithms. No one reading over your shoulder. Just your words, a warm page, and a little breathing room.”
**Primary footer:** **Come on in**
**Visual first:** yes.

Visual:

- Existing app icon from `assets/icons/icon.png`, 88×88dp, `BoxFit.cover`, `ClipRRect` radius 22dp.
- Behind it, two offset paper cards:
  - 180×120dp,
  - `colors.surface`,
  - 1px `colors.divider` border,
  - radius 14dp,
  - rotations -3° and +2°,
  - no heavy shadow.
- Optional small caption under the icon: “Quiet Paper” in 13sp `colors.textTertiary`, letterSpacing 0.3.
- The whole composition is decorative and excluded from semantics.

Below the body, inside the page:

- A thin divider (`colors.divider`) with 24dp vertical space.
- Label: “Already have a library?” in 13sp `colors.textTertiary`.
- A `Wrap` with three `TextButton`s:
  - **Restore a backup** — key `onboarding-welcome-restore`
  - **Sign in** — key `onboarding-welcome-sign-in`
  - **Create account** — key `onboarding-welcome-create-account`
- Separator between links: a middle dot (`·`) in `colors.textTertiary`.
- If `currentUserProvider` is non-null:
  - hide Sign in and Create account,
  - keep Restore a backup.
- Tapping a link opens the corresponding flow (see Auth and Restore sections).
- All links are optional. Skip remains available top-right.

### Page 2 — Privacy + local-first

**Eyebrow:** “PRIVATE BY DEFAULT”
**Title:** “Your words. Your business.”
**Body:** “Notes live on your device first, so Quiet Paper works on planes, in cafés with questionable Wi-Fi, and anywhere else ideas show up. If you turn on sync, everything is end-to-end encrypted before it leaves. The server gets ciphertext—not a peek.”
**Footnote:** “No account needed to start.”
**Primary footer:** **Continue**

Visual — “Encrypted note” vignette:

- A 280×150dp note card:
  - `colors.surface`,
  - border `colors.divider`,
  - radius 16dp,
  - padding 18dp.
- Card title: “Morning thoughts” in 16sp semibold `colors.textPrimary`.
- Three skeleton lines below:
  - heights 6dp, radius 3dp, `colors.surfaceSubtle`,
  - widths 92%, 78%, 56%.
- A lock pill at the bottom-left:
  - icon `Icons.lock_outline_rounded`, 14dp, accent,
  - label “Encrypted on device”, 11sp accentDark,
  - background accentSoft.
- To the right/behind:
  - an outlined cloud icon `Icons.cloud_outlined`, 44dp, `colors.textTertiary`,
  - a dashed line from the note card to the cloud,
  - a small label under the cloud: “ciphertext only”, 10.5sp, `colors.textTertiary`.
- All decorative; exclude semantics.

### Page 3 — Voice notes + transcription

**Eyebrow:** “VOICE NOTES”
**Title:** “Talk. We’ll take notes.”
**Body:** “Record a voice memo and turn it into text with on-device transcription. Download the small model once, then it works offline. Your voice never leaves your device.”
**Footnote:** “One-time language-model download required.”
**Primary footer:** **Continue**

Visual — “Voice memo → transcript” vignette:

- Top card, 320×96dp:
  - play circle (36dp, accentSoft background, accent play icon),
  - 17 waveform bars with heights:
    `[8, 14, 20, 28, 18, 34, 24, 16, 30, 22, 12, 26, 32, 18, 24, 14, 10]`,
    width 3.5dp, gap 3dp, radius 2dp, `colors.accent` at 70% opacity,
  - “0:42” caption at the right,
  - small subtitle “Voice memo” under the waveform.
- An “On-device” pill:
  - icon `Icons.memory_rounded`,
  - background `colors.success.withValues(alpha: 0.14)`,
  - text `colors.success`.
- Transcript card below, 320×92dp:
  - label “TRANSCRIPT” in 10.5sp letterSpacing 1.0 `colors.textTertiary`,
  - three text skeleton lines,
  - first line 88%, second 96%, third 64%.
- The composition implies audio → text, not the other way round.

### Page 4 — One list, one way

**Eyebrow:** “ONE LIST, ONE WAY”
**Title:** “No folders. No filing. No guilt.”
**Body:** “Every note lives in one calm list. Tag what matters with #anything, pin the keepers, and search the rest. That’s the whole system.”
**Primary footer:** **Continue**

Visual — “One list” vignette:

- A rounded list card, 320×190dp.
- Three note rows inside, separated by `colors.divider`:
  1. “A quiet place to think” with a pin icon and `#welcome`;
  2. “Books I want to read” with `#reading`;
  3. “Morning thoughts” with `#journal`.
- Row title 14sp textPrimary; tags in small tag chips (`colors.tagBackground`, `colors.tagText`).
- Above the list, a single chip: `Icons.folder_off_outlined` + “No folders” in textTertiary.
- Below the list, a row of loose tag chips: `#ideas`, `#writing`, `#reference`.
- No nested folder trees or workspace diagrams.

### Page 5 — Offline OCR

**Eyebrow:** “OFFLINE OCR”
**Title:** “Paper in. Words out.”
**Body:** “Scan a page, import a PDF, and pull out searchable text right on your device. Receipts, recipes, scribbled ideas—all findable later. No upload required.”
**Primary footer:** **Continue**

Visual — “Scan → text” vignette:

- A 240×180dp document card rotated -1.5°:
  - surface, border, radius 12dp.
  - Several grey text lines.
  - One line highlighted with an accentSoft rounded rectangle.
  - Four accent corner brackets around the card to imply a scanner frame. Build with four small `Container`s, not an image.
- A downward arrow or vertical dotted line in `colors.accent`.
- A smaller extracted-text card, 250×70dp:
  - label “SEARCHABLE TEXT” in 10sp,
  - one real line: “The quietest notes are often the truest.”,
  - one skeleton line underneath,
  - small `Icons.search_rounded` in the corner.

### Page 6 — Optional sync

**Eyebrow:** “OPTIONAL SYNC”
**Title:** “Same notes. Every device. Still private.”
**Body:** “Quiet Paper is perfectly happy staying local. If you’d like your library on more than one device, sign in or create an account. Your encryption password never leaves your device.”
**Footnote:** “You can set this up later in Settings.”
**Primary footer:** **Keep it local**

Page actions (only when signed out):

- `QuietButton` primary, full width: **Create account**.
  - Key: `onboarding-sync-create-account`.
  - Opens `SyncAuthScreen` with `initialView: SyncAuthInitialView.createAccount`.
- 8dp gap.
- `QuietButton` secondary, full width: **Sign in**.
  - Key: `onboarding-sync-sign-in`.
  - Opens `SyncAuthScreen` with `initialView: SyncAuthInitialView.signIn`.

Signed-in state:

- Watch `currentUserProvider`.
- If non-null:
  - Eyebrow: “SYNC IS ON”
  - Title: “You’re already connected.”
  - Body: “Signed in as {email}. Your notes sync quietly in the background.” If email is null: “You’re signed in. Your notes sync quietly in the background.”
  - Show a check/shield card with `Icons.verified_user_outlined` and the account email.
  - No auth buttons.
  - Footer: **Continue**.
  - Footnote: “Manage sync in Settings.”

If auth is cancelled or fails:

- Return to this page.
- Do not show the success page.
- No snackbar is required; the auth screen owns its error messages.

Visual:

- Two outlined device shapes: a phone (90×150dp) and a laptop (150×90dp).
- A dotted line connecting them.
- A lock badge in the centre with accentSoft background.
- Small label: “end-to-end encrypted”.
- If signed in, the connection line can be solid accent instead of dotted.

### Page 7 — Make it yours

**Eyebrow:** “MAKE IT YOURS”
**Title:** “A desk that feels like yours.”
**Body:** “Pick a paper tone and a brightness. Then, if you’d like a few notes to poke around in, we’ll leave some on the desk.”
**Primary footer:** **Continue**

This page uses `extra`, not a decorative vignette. On wide screens, copy is on the left and the controls card is on the right. On phones, controls follow the copy.

Controls card:

- Surface container, 1px border, radius 16dp, padding 18dp.

#### PAPER STYLE

- Section label “PAPER STYLE”, 10.5sp, letterSpacing 1.0, textTertiary.
- Two selectable cards side by side (equal width):
  - **Classic Paper**
    - Key: `onboarding-paper-classic`
    - Description: “Warm terracotta on soft paper.”
    - Swatches: `classicLight.background`, `classicLight.surface`, `classicLight.accent` in light mode; `classicDark.background`, `classicDark.surface`, `classicDark.accent` in dark mode.
  - **Warm Paper**
    - Key: `onboarding-paper-warm`
    - Description: “Ivory and slate with a calm blue accent.”
    - Swatches: `warmPaperLight` equivalents in light mode; `midnightPaperDark` equivalents in dark mode.
- Each card:
  - minimum height 78dp,
  - padding 12dp,
  - radius 12dp,
  - background: selected `colors.accentSoft`, unselected `colors.background`,
  - border: selected `colors.accent`, unselected `colors.divider`,
  - a 3-dot swatch row at the top,
  - name 13sp semibold,
  - description 11sp textTertiary,
  - check icon if selected.
- Tapping calls `themeSettingsProvider.notifier.setThemeFamily(...)`.
- The whole app theme changes immediately; the current onboarding page must remain on page 7.

#### APPEARANCE

- Section label “APPEARANCE”.
- Three-segment control:
  - background `colors.background`,
  - 1px `colors.divider` border,
  - radius 12dp,
  - 4dp inner padding,
  - each segment 40dp tall, `Expanded`,
  - icon + label:
    - System: `Icons.brightness_auto_rounded` / “System”
    - Light: `Icons.light_mode_outlined` / “Light”
    - Dark: `Icons.dark_mode_outlined` / “Dark”
  - selected segment background `colors.accentSoft`, text/icon `colors.accentDark`;
  - unselected text/icon `colors.textSecondary`.
- Keys: `onboarding-appearance-system`, `onboarding-appearance-light`, `onboarding-appearance-dark`.
- Tapping calls `themeSettingsProvider.notifier.setAppearanceMode(...)`.

#### SAMPLE NOTES

- Section label “SAMPLE NOTES”.
- Use `activeNotesCountProvider` from `lib/features/notes/application/notes_provider.dart`.

States:

1. **Loading (`AsyncLoading`)**:
   - Show a 52dp high row with a small `CircularProgressIndicator.adaptive`.
   - No load button yet.

2. **Library empty (`data == 0`), not loaded in this session**:
   - Title: “A few notes to start with?”
   - Body: “Five examples of Markdown, tags, checklists, and editorial formatting.”
   - Button: **Leave sample notes**, secondary variant with `Icons.auto_stories_outlined`.
   - Key: `onboarding-sample-load`.
   - On tap:
     - set local `_sampleLoading = true`,
     - await `SampleNotes.populateSampleNotes(ref.read(notesRepositoryProvider))`,
     - refresh `notesCollectionProvider`,
     - set local `_sampleLoaded = true`,
     - if `mounted`, setState.
   - While loading, `QuietButton.isLoading` is true and interactions are disabled.
   - On error:
     - set `_sampleError = true`,
     - show: “Couldn't load the sample notes. You can try again from Settings → Advanced.”
     - colour `colors.error` for the message.
     - re-enable the button.
   - On success, switch immediately to the loaded state.

3. **Loaded in this session or active count > 0**:
   - If active count > 0 and no samples were just loaded by this page:
     - Title: “Your desk already has notes.”
     - Body: “We'll leave your library just as it is.”
   - If samples were just loaded by this page:
     - Title: “Sample notes are on the desk.”
     - Body: “Five little examples, ready to poke around in.”
   - Both show a check icon in `colors.success`.
   - Do not show the load button.

4. **Error (`AsyncError`)**:
   - Treat as 0 and show the button. The load action has its own error handling.

Footnote under the controls card:

- “Change any of this later in Settings.”

No duplicate-safety key is needed: the live active note count prevents offering sample loading when notes already exist, and local state prevents a second load within the same onboarding session.

### Page 8 — Ready when you are

**Eyebrow:** “ONE LAST THING”
**Title:** “Ready when you are.”
**Body:** “We’ll point out where your first note begins. There’s no wrong way to start—even one word counts.”
**Primary footer:** **Show me around**
**Secondary footer:** **I'll find my way**

Visual:

- A miniature notes screen card, 300×170dp:
  - two note rows with skeleton lines,
  - a + button in the bottom-right inside a soft accent halo,
  - a small spotlight ring around the +.
- Decorative only; exclude semantics.

Behaviour:

- **Show me around**:
  - `await finishWithTour()`.
  - First run: `AppRoot` swaps to `NotesScreen(showOnboardingTour: true)`.
  - Replay: clear the tour flag and `Navigator.popUntil((route) => route.isFirst)`.
- **I'll find my way**:
  - `await finishWithoutTour()`.
  - First run: NotesScreen.
  - Replay: pop back to About.

### Success page (branch, not part of the 8-page carousel)

Shown after a successful auth or backup restore.

Layout:

- Full-screen background `colors.background`.
- No Skip.
- `PopScope(canPop: false)`; system back triggers the same completion as Continue.
- Centered, max width 480dp.
- 72dp circle with `colors.accentSoft` background and `Icons.check_rounded` in `colors.accent`.
- Eyebrow: “ALL SET”.
- Title and body depend on the result.

Sync success:

- Title: “You’re in.”
- Body: “Your notes will sync quietly in the background. Pick up on another device whenever you like.”
- If email is known: caption “Signed in as {email}.”
- Button: **Continue**.

Restore success:

- Title: “Welcome back.”
- Body if count > 0:
  - “Your backup is home. We put back {count} {note/notes} and their tags.”
  - Use singular “note” when count == 1.
- Body if count == 0:
  - “Your backup is home. Everything is right where you left it.”
- Button: **Continue**.

Continue behaviour:

- Set completed = true.
- Set tourSeen = true.
- If `isReplay`: `Navigator.popUntil((route) => route.isFirst)` so the user lands on NotesScreen and sees restored/synced content.
- First run: `AppRoot` swaps to NotesScreen.
- Guard against double taps with `_isFinishing`.

---

## 9. Canonical copy deck

All user-facing strings in this feature must match this list exactly.

### Welcome

- “A quiet place to think.”
- “No feeds. No algorithms. No one reading over your shoulder. Just your words, a warm page, and a little breathing room.”
- “Come on in”
- “Already have a library?”
- “Restore a backup”
- “Sign in”
- “Create account”
- “Skip”

### Privacy

- “PRIVATE BY DEFAULT”
- “Your words. Your business.”
- “Notes live on your device first, so Quiet Paper works on planes, in cafés with questionable Wi-Fi, and anywhere else ideas show up. If you turn on sync, everything is end-to-end encrypted before it leaves. The server gets ciphertext—not a peek.”
- “No account needed to start.”

### Voice

- “VOICE NOTES”
- “Talk. We’ll take notes.”
- “Record a voice memo and turn it into text with on-device transcription. Download the small model once, then it works offline. Your voice never leaves your device.”
- “One-time language-model download required.”

### Simplicity

- “ONE LIST, ONE WAY”
- “No folders. No filing. No guilt.”
- “Every note lives in one calm list. Tag what matters with #anything, pin the keepers, and search the rest. That’s the whole system.”

### OCR

- “OFFLINE OCR”
- “Paper in. Words out.”
- “Scan a page, import a PDF, and pull out searchable text right on your device. Receipts, recipes, scribbled ideas—all findable later. No upload required.”

### Sync

- “OPTIONAL SYNC”
- “Same notes. Every device. Still private.”
- “Quiet Paper is perfectly happy staying local. If you’d like your library on more than one device, sign in or create an account. Your encryption password never leaves your device.”
- “You can set this up later in Settings.”
- “Keep it local”
- “Create account”
- “Sign in”
- “SYNC IS ON”
- “You’re already connected.”
- “Signed in as {email}. Your notes sync quietly in the background.”
- “You’re signed in. Your notes sync quietly in the background.”
- “Manage sync in Settings.”

### Make it yours

- “MAKE IT YOURS”
- “A desk that feels like yours.”
- “Pick a paper tone and a brightness. Then, if you’d like a few notes to poke around in, we’ll leave some on the desk.”
- “PAPER STYLE”
- “Classic Paper”
- “Warm terracotta on soft paper.”
- “Warm Paper”
- “Ivory and slate with a calm blue accent.”
- “APPEARANCE”
- “System”
- “Light”
- “Dark”
- “SAMPLE NOTES”
- “A few notes to start with?”
- “Five examples of Markdown, tags, checklists, and editorial formatting.”
- “Leave sample notes”
- “Sample notes are on the desk.”
- “Five little examples, ready to poke around in.”
- “Your desk already has notes.”
- “We'll leave your library just as it is.”
- “Couldn't load the sample notes. You can try again from Settings → Advanced.”
- “Change any of this later in Settings.”

### First note

- “ONE LAST THING”
- “Ready when you are.”
- “We’ll point out where your first note begins. There’s no wrong way to start—even one word counts.”
- “Show me around”
- “I'll find my way”

### Success

- “ALL SET”
- “You’re in.”
- “Your notes will sync quietly in the background. Pick up on another device whenever you like.”
- “Signed in as {email}.”
- “Welcome back.”
- “Your backup is home. We put back {count} notes and their tags.”
- “Your backup is home. Everything is right where you left it.”
- “Continue”

### Coach marks

- “1 of 3”, “2 of 3”, “3 of 3”
- “Skip tour”
- “Next”
- “Create my first note”
- “YOUR LIBRARY”
- “Everything, in one place.”
- “All notes, pinned, archive, and tags live here. One list. No filing system required.”
- “FIND ANYTHING”
- “Find it in a blink.”
- “Search titles, text, and tags—fully offline. Even the words inside your scans.”
- “THE FRONT DOOR”
- “This is where notes begin.”
- “Tap it whenever a thought arrives—or let us make the first one for you.”

### Editor tips

- “A few quiet tricks”
- “No save button—everything saves as you type.”
- “Type #tag anywhere to organize.”
- “Skip the title? The first line becomes it.”
- “Got it”

### Settings

- “WELCOME TOUR”
- “Show welcome tour”
- “Revisit the introduction and first-note tips.”

---

## 10. Auth integration

### 10.1 `SyncAuthInitialView`

In `lib/features/sync/presentation/sync_auth_screen.dart`, add a public enum:

```dart
enum SyncAuthInitialView {
  intro,
  signIn,
  createAccount,
}
```

Change the constructor:

```dart
const SyncAuthScreen({
  super.key,
  this.initialView = SyncAuthInitialView.intro,
});

final SyncAuthInitialView initialView;
```

Change `_step` from a field initializer to a `late` field set in `initState`:

```dart
_last step:
  intro         -> _AuthFlowStep.onboarding
  signIn        -> _AuthFlowStep.signIn
  createAccount -> _AuthFlowStep.signupEmail
```

Existing callers continue to use the default intro view.

### 10.2 Back navigation

Keep the existing wizard back behaviour for the default intro flow.

For direct-entry modes:

- If `initialView == signIn` and `_step == _AuthFlowStep.signIn`, the app bar back button should pop the screen without a success result.
- If `initialView == createAccount` and `_step == _AuthFlowStep.signupEmail`, the app bar back button should pop the screen without a success result.
- If the user has advanced beyond the direct-entry step, keep the existing step-back behaviour.
- On `signupComplete`, pressing back must pop with `true`, because the account and recovery key already exist.

### 10.3 Success results

Change terminal success pops to return `true`:

- successful sign-in → `Navigator.of(context).pop(true)`
- “Done — Saved Recovery Key” on the signup-complete screen → `Navigator.of(context).pop(true)`
- back from the signup-complete screen → `Navigator.of(context).pop(true)`

Plain cancellation/back paths continue to pop with no result.

### 10.4 Onboarding call

```dart
Future<void> _openAuth(SyncAuthInitialView view) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => SyncAuthScreen(initialView: view),
    ),
  );

  if (!mounted) return;

  final signedIn = ref.read(currentUserProvider) != null;
  if (result == true || signedIn) {
    setState(() {
      _successKind = OnboardingSuccessKind.sync;
    });
  }
}
```

The `currentUser` fallback covers the case where the OS back gesture pops the auth screen after account creation without returning a result.

Do not show the success page if auth was cancelled before a session existed.

### 10.5 Already signed in

- On Welcome: hide Sign in and Create account; keep Restore a backup.
- On the sync page: show the connected state described in Page 6.
- Never prompt an already signed-in user to sign in again during onboarding.

---

## 11. Backup restore integration

### 11.1 Return the restored count

In `lib/core/backup/presentation/restore_backup_dialog.dart`:

Change:

```dart
static Future<void> show(BuildContext context)
```

to:

```dart
static Future<int?> show(
  BuildContext context, {
  bool showSuccessSnackBar = true,
})
```

Pass both arguments to the dialog widget.

The dialog adds:

```dart
final bool showSuccessSnackBar;
```

In `_handleRestore`, after a successful restore:

- If `showSuccessSnackBar` is true, show the existing “Restored X notes…” snackbar. Show it before popping, or use a root scaffold messenger that survives the dialog pop.
- Pop the dialog with `result.totalRestored`:
  ```dart
  Navigator.of(context).pop(result.totalRestored);
  ```

Cancellation and close paths use `Navigator.of(context).pop()` with no result.

Existing callers in Settings keep working and keep the snackbar because the default is true.

### 11.2 Onboarding call

```dart
Future<void> _restoreBackup() async {
  final count = await RestoreBackupDialog.show(
    context,
    showSuccessSnackBar: false,
  );

  if (!mounted || count == null) return;

  ref.read(notesCollectionProvider.notifier).refresh();
  setState(() {
    _restoredCount = count;
    _successKind = OnboardingSuccessKind.restore;
  });
}
```

Do not mark onboarding complete until the user taps Continue on the success page.

---

## 12. Sample notes integration

- Use the existing `SampleNotes.populateSampleNotes(repository)` unchanged.
- Repository: `ref.read(notesRepositoryProvider)`.
- After loading:
  - `ref.read(notesCollectionProvider.notifier).refresh();`
  - set local `_sampleLoaded = true`.
- Do not add a persistent sample-loaded key.
- Do not alter the five sample notes.
- The Settings → Advanced → Load sample notes row remains unchanged.
- If the user already has notes, the onboarding sample offer is hidden. They can still use Settings.
- The sample button is a secondary action; it must never block Continue.

---

## 13. Coach marks

### 13.1 Trigger

`NotesScreen` gains:

```dart
const NotesScreen({super.key, this.showOnboardingTour = false});
final bool showOnboardingTour;
```

`AppRoot` passes `showOnboardingTour: !status.tourSeen` when completed.

NotesScreen shows the tour when:

- `widget.showOnboardingTour` becomes true in `didUpdateWidget`, or
- `widget.showOnboardingTour` is true in `initState`.

Local state:

- `_tourDismissed = false`
- `_tourStarted = false`

When the tour starts:

1. Reset the workspace so all targets exist:
   - `currentDestinationProvider = AppDestination.allNotes`
   - `selectedTagFilterProvider = null`
   - `selectedTagIdProvider = null`
   - `notesQueryProvider.notifier.clearAllFilters()`
   - `isNavSidebarVisibleProvider = true`
   - `isNoteListVisibleProvider = true`
2. Set `_tourStarted = true` after the next frame so targets are laid out.
3. Do not reset the user's workspace on first launch beyond the defaults; this is harmless.

The overlay is visible only while:
`widget.showOnboardingTour && !_tourDismissed`.

When the user skips or creates:

- set `_tourDismissed = true`;
- call `ref.read(onboardingStatusProvider.notifier).markTourSeen()`.

`AppRoot` will rebuild with `showOnboardingTour = false`; the overlay disappears.

### 13.2 Target keys

Add these `GlobalKey`s to `_NotesScreenState`:

```dart
final _onboardingSidebarTargetKey = GlobalKey(debugLabel: 'onboarding-sidebar');
final _onboardingSearchTargetKey = GlobalKey(debugLabel: 'onboarding-search');
final _onboardingCreateTargetKey = GlobalKey(debugLabel: 'onboarding-create');
```

Phone layout:

- Sidebar/menu target:
  - the `QuietIconButton` that opens the navigation drawer in the default All Notes app bar.
  - Add the key there.
- Search target:
  - the search `QuietIconButton` in the same app bar actions.
- Create target:
  - the `QuietFab` used for `_createAndOpenNote`.

Tablet layout:

- Sidebar target:
  - the fixed-width sidebar content inside `SidebarView`’s 280dp container. Use a `KeyedSubtree` with `_onboardingSidebarTargetKey` around the `Container` that holds `SidebarView(isCollapsible: true)`.
  - The sidebar is forced visible when the tour starts.
- Search target:
  - the search `QuietIconButton` in the default middle-pane header.
- Create target:
  - the `+` `QuietIconButton` in the default middle-pane header.

Do not attach keys to both layouts at once; only one layout is built.

If a key’s render box is missing or has zero size, show the coach card centered with the full-screen dim and no spotlight. Never skip a step or crash.

### 13.3 Overlay

Create `lib/features/onboarding/presentation/coach_marks/onboarding_coach_marks.dart`.

API:

```dart
class OnboardingCoachMarks extends StatefulWidget {
  const OnboardingCoachMarks({
    super.key,
    required this.sidebarTarget,
    required this.searchTarget,
    required this.createTarget,
    required this.isTablet,
    required this.onCreateFirstNote,
    required this.onDismiss,
  });

  final GlobalKey sidebarTarget;
  final GlobalKey searchTarget;
  final GlobalKey createTarget;
  final bool isTablet;
  final VoidCallback onCreateFirstNote;
  final VoidCallback onDismiss;
}
```

Rendering:

- Full-screen `Positioned.fill` overlay inside a `Stack` above the NotesScreen layout.
- A full-screen `GestureDetector` with `behavior: HitTestBehavior.opaque` and an empty `onTap` blocks all underlying interactions.
- A `CustomPaint` dim layer:
  - dim colour: `Colors.black.withValues(alpha: 0.55)`;
  - cutout: target rectangle inflated by 8dp, rounded 12dp;
  - draw the dim as a path with the rounded target subtracted;
  - draw a 2dp accent border around the cutout.
- The coach card is above the dim and receives taps.
- Use a `CustomSingleChildLayout` with a delegate so the card can be measured and positioned without hard-coded heights.

Placement:

- Card width: `min(360, screenWidth - 32)`.
- Preferred: 16dp below the target if there is room for the measured card plus 16dp margin.
- Otherwise: 16dp above the target.
- If neither fits:
  - for a large sidebar target, place the card to the right of the target if there is room, otherwise to the left;
  - otherwise centre the card.
- Clamp horizontally to 16dp screen margins.
- Respect safe area top/bottom.
- Recompute after:
  - first frame,
  - step change,
  - orientation change / metrics change.
- If the target is missing, centre the card and dim the whole screen.

Card:

- Background `colors.surface`.
- 1px `colors.divider` border.
- Radius 16dp.
- Padding 20dp.
- Subtle shadow: black 8% opacity, blur 24, offset (0, 8).
- Top row:
  - “1 of 3” in 11.5sp `colors.textTertiary`;
  - right-aligned `TextButton` **Skip tour** in `colors.textSecondary`.
- 12dp gap.
- Eyebrow in 10.5sp uppercase, letterSpacing 1.0, accent.
- Title in 20sp, weight 700, `colors.textPrimary`.
- Body in 14.5sp, height 1.5, `colors.textSecondary`.
- 16dp gap.
- Primary `QuietButton`, full width, primary variant:
  - **Next** for steps 1 and 2.
  - **Create my first note** for step 3.
- Keys:
  - `onboarding-coach-next` for Next,
  - `onboarding-coach-create` for Create,
  - `onboarding-coach-skip` for Skip tour.

Steps:

1. **YOUR LIBRARY**
   - “Everything, in one place.”
   - “All notes, pinned, archive, and tags live here. One list. No filing system required.”
   - Target: sidebar/menu.

2. **FIND ANYTHING**
   - “Find it in a blink.”
   - “Search titles, text, and tags—fully offline. Even the words inside your scans.”
   - Target: search.

3. **THE FRONT DOOR**
   - “This is where notes begin.”
   - “Tap it whenever a thought arrives—or let us make the first one for you.”
   - Target: create button.
   - Primary: **Create my first note**.

Behaviour:

- Next advances one step.
- Skip tour calls `onDismiss`.
- Create calls `onCreateFirstNote`.
- The spotlight is visual only; the underlying target does not receive taps.
- The card is focusable; screen readers announce the step title and body.

### 13.4 Creating the first note

`NotesScreen`:

```dart
void _handleCoachCreate(BuildContext context, {required bool isTablet}) {
  ref.read(onboardingStatusProvider.notifier).markTourSeen();
  setState(() {
    _tourDismissed = true;
  });

  if (isTablet) {
    _createAndOpenNoteTablet(showFirstNoteTips: true);
  } else {
    _createAndOpenNote(context, showFirstNoteTips: true);
  }
}
```

- `isTablet` is the existing note-screen layout check (`MediaQuery.sizeOf(context).width >= 900`).
- `_createAndOpenNote` and `_createAndOpenNoteTablet` gain:

```dart
{bool showFirstNoteTips = false}
```

- Phone passes `showFirstNoteTips` to the pushed `EditorScreen`.
- Tablet stores `_showFirstNoteTipsForTablet = true` and passes it to the embedded `EditorScreen`.
- Reset `_showFirstNoteTipsForTablet` to false when:
  - the tablet editor is closed,
  - a different note is selected from the list,
  - a normal (non-coach) new note is created.
- Normal note creation never shows the tips.

---

## 14. Editor tips

### 14.1 `EditorScreen` API

Add:

```dart
final bool showFirstNoteTips;
```

Constructor default: `false`.

### 14.2 Rendering

Create `lib/features/onboarding/presentation/widgets/first_note_tips_card.dart`.

In `EditorScreen`’s main edit-mode `Scaffold` body `Column`, insert the card:

- after the in-note search bar and desktop toolbar,
- before the `Expanded` editor content.

Condition:

```dart
widget.showFirstNoteTips &&
!editorState.isPreviewMode &&
!editorState.isReadOnly &&
!_firstNoteTipsDismissed
```

Card design:

- Surface background, 1px divider border, radius 12dp.
- Margin: 16dp horizontal, 8dp vertical.
- Padding: 14dp.
- Leading icon: `Icons.auto_awesome_rounded`, 18dp, accent, inside a 32dp accentSoft circle.
- Title: **A few quiet tricks** in 13.5sp semibold.
- Three compact tips in 12.5sp, height 1.45, `colors.textSecondary`:
  - **No save button—everything saves as you type.**
  - **Type #tag anywhere to organize.**
  - **Skip the title? The first line becomes it.**
- Trailing/under-title `TextButton` **Got it**, accent.
- On tap: set `_firstNoteTipsDismissed = true` with `setState`.
- Non-modal. Do not block typing, autofocus, or the keyboard.
- Dismissal is not persisted. The card is only shown for the note created by the coach-mark tour.
- Exclude the card from preview mode.

---

## 15. Settings replay

### 15.1 About screen row

In `lib/features/settings/presentation/about_app_screen.dart`, add a section before “Links & Resources”:

- Header: **WELCOME TOUR**
- `SettingsGroup` with one `SettingsRow`:
  - icon: `Icons.auto_awesome_outlined`
  - title: **Show welcome tour**
  - subtitle: **Revisit the introduction and first-note tips.**
  - trailing chevron: `Icons.chevron_right_rounded`, 14dp, `colors.textTertiary`
  - key: `const Key('settings-show-welcome-tour')`
  - onTap:
    ```dart
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnboardingScreen(isReplay: true),
      ),
    );
    ```

### 15.2 Replay behaviour

- `isReplay == true` means the onboarding screen was pushed, not used as the app root.
- Skip or normal finish:
  - mark tour seen,
  - `Navigator.pop(context)` back to About.
- “Show me around”:
  - `clearTourSeen()`,
  - `Navigator.popUntil((route) => route.isFirst)` so NotesScreen is visible,
  - AppRoot rebuilds NotesScreen with `showOnboardingTour: true`.
- Auth/restore success → Continue:
  - set completed true (idempotent),
  - set tour seen true,
  - pop to root so the user lands on NotesScreen.
- Theme choices and sample notes persist immediately.
- Replaying while signed in:
  - Welcome hides Sign in / Create account.
  - Sync page shows the connected state.
  - Restore remains available.

---

## 16. Responsive, accessibility, and motion

### 16.1 Breakpoints

- Phone: < 760dp content width.
- Tablet/desktop two-column: ≥ 760dp.
- NotesScreen tablet layout remains its existing `>= 900dp` breakpoint.

Test at:

- 360×800 logical dp,
- 320×568 logical dp (small phone),
- 1024×768 logical dp (tablet),
- 1440×900 logical dp (desktop).

### 16.2 Scrolling and overflow

- Every carousel page is vertically scrollable.
- Footer remains fixed and outside the scroll.
- On short screens, the footer buttons must remain reachable.
- No RenderFlex overflow under the global text scale clamp.
- Do not use fixed heights for text-heavy sections.
- Theme page controls may be taller than the viewport; scrolling is expected.

### 16.3 Semantics

- Page title: `Semantics(header: true)`.
- Progress: live region “Page X of 8”.
- Decorative vignettes: `ExcludeSemantics`.
- Theme option cards: `Semantics(selected: true/false, button: true)`.
- Coach card: `Semantics(container: true, liveRegion: true)`.
- All icon-only buttons have tooltips.
- Minimum tap target: 44×44dp.

### 16.4 Reduced motion

- If `MediaQuery.disableAnimations` is true:
  - use `Duration.zero` for `PageController.animateToPage`,
  - disable non-essential decorative animation,
  - keep progress dots static (no width animation).
- Do not disable scrolling.

### 16.5 Text scaling

- The app already clamps text scaling to 0.85–1.35 in `QuietPaperApp`.
- Do not bypass that clamp.
- Use `Flexible`/`Expanded` and allow wrapping; never use `maxLines: 1` on onboarding body copy.

---

## 17. Error handling and edge cases

| Case | Required behaviour |
|---|---|
| Auth cancelled | Stay on the current onboarding page; no success page. |
| Auth fails | Stay on auth screen; its own error UI handles it. |
| Auth succeeds then user presses system back from a completed signup screen | Pop with `true`; onboarding detects currentUser and shows the success page. |
| Restore cancelled | Stay on the current page; no success page. |
| Restore succeeds with 0 notes | Show the restore success page with the zero-note copy. |
| Restore succeeds | Refresh notes collection before showing the success page. |
| Sample notes load fails | Inline error; Continue is still enabled; button re-enabled. |
| Sample notes already exist | Show “Your desk already has notes.” and no load button. |
| Sample button tapped twice | Disable while loading. |
| Coach target missing or zero-sized | Centered card, full dim, no spotlight; do not crash. |
| Coach overlay active and user presses system back | Let NotesScreen’s normal back behaviour run; the overlay can remain. Do not add a nested PopScope unless tests show a problem. |
| App killed mid-carousel | Onboarding restarts from page 1. |
| App killed mid-coach-marks | Coach marks show again on next launch. |
| App killed mid-editor-tips | Tips do not show again. |
| Replay while signed in | No auth prompts; connected state shown. |
| Existing user with notes | Sample loader hidden; Skip available on every page. |
| Theme changed mid-page | Page index preserved; whole theme updates immediately. |
| Orientation change during coach marks | Re-measure targets and reposition the card. |
| Double tap on Continue/Finish | Guard with `_isFinishing`. |
| Back from success page | Same as Continue. |
| User has no notes and skips | NotesScreen empty state remains unchanged. |

---

## 18. File manifest

### New files

```text
lib/app/app_root.dart
lib/features/onboarding/application/onboarding_provider.dart
lib/features/onboarding/presentation/onboarding_screen.dart
lib/features/onboarding/presentation/widgets/onboarding_page_layout.dart
lib/features/onboarding/presentation/widgets/onboarding_vignettes.dart
lib/features/onboarding/presentation/widgets/onboarding_personalize_page.dart
lib/features/onboarding/presentation/widgets/onboarding_success_page.dart
lib/features/onboarding/presentation/widgets/first_note_tips_card.dart
lib/features/onboarding/presentation/coach_marks/onboarding_coach_marks.dart
test/onboarding/onboarding_provider_test.dart
test/onboarding/onboarding_screen_test.dart
test/onboarding/coach_marks_test.dart
test/settings/about_app_screen_test.dart
```

### Modified files

```text
lib/app/app.dart
lib/features/notes/presentation/notes_screen.dart
lib/features/editor/presentation/editor_screen.dart
lib/features/sync/presentation/sync_auth_screen.dart
lib/core/backup/presentation/restore_backup_dialog.dart
lib/features/settings/presentation/about_app_screen.dart
test/widget_test.dart
test/sync/sync_screens_test.dart
HANDOFF.md
```

No new dependencies, assets, backend files, migrations, or generated code.

---

## 19. Implementation notes / pseudocode

### 19.1 Onboarding provider

```dart
class OnboardingStatusNotifier extends StateNotifier<OnboardingStatus> {
  OnboardingStatusNotifier(this._prefs)
      : super(OnboardingStatus(
          completed: _prefs.getBool(OnboardingKeys.completed) ?? false,
          tourSeen: _prefs.getBool(OnboardingKeys.tourSeen) ?? false,
        ));

  final SharedPreferences _prefs;

  Future<void> complete() async {
    state = state.copyWith(completed: true);
    await _prefs.setBool(OnboardingKeys.completed, true);
  }

  Future<void> markTourSeen() async {
    state = state.copyWith(tourSeen: true);
    await _prefs.setBool(OnboardingKeys.tourSeen, true);
  }

  Future<void> clearTourSeen() async {
    state = state.copyWith(tourSeen: false);
    await _prefs.setBool(OnboardingKeys.tourSeen, false);
  }

  Future<void> finishWithoutTour() async {
    await complete();
    await markTourSeen();
  }

  Future<void> finishWithTour() async {
    await complete();
    await clearTourSeen();
  }
}
```

### 19.2 Onboarding completion helper

```dart
Future<void> _completeAndLeave({required bool showTour}) async {
  if (_isFinishing) return;
  setState(() => _isFinishing = true);

  if (showTour) {
    await ref.read(onboardingStatusProvider.notifier).finishWithTour();
  } else {
    await ref.read(onboardingStatusProvider.notifier).finishWithoutTour();
  }

  if (!mounted) return;

  if (widget.isReplay) {
    if (showTour) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      Navigator.of(context).pop();
    }
  }
}
```

First-run completion does not call Navigator; `AppRoot` switches.

### 19.3 Success completion

```dart
Future<void> _finishSuccess() async {
  if (_isFinishing) return;
  setState(() => _isFinishing = true);

  await ref.read(onboardingStatusProvider.notifier).finishWithoutTour();

  if (!mounted) return;

  if (widget.isReplay) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
```

### 19.4 AppRoot

```dart
class AppRoot extends ConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(onboardingStatusProvider);

    if (!status.completed) {
      return const OnboardingScreen();
    }

    return NotesScreen(showOnboardingTour: !status.tourSeen);
  }
}
```

### 19.5 Coach overlay layout delegate

Use a `CustomSingleChildLayout` whose delegate receives:

- the resolved target `Rect?`,
- the screen `Size`,
- safe area padding,
- the measured child size from `getPositionForChild(Size size, Size childSize)`.

Position rules are defined in section 13.3.

### 19.6 NotesScreen tour lifecycle

```dart
@override
void initState() {
  super.initState();
  if (widget.showOnboardingTour) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOnboardingTour());
  }
}

@override
void didUpdateWidget(NotesScreen oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (!oldWidget.showOnboardingTour && widget.showOnboardingTour) {
    _tourDismissed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startOnboardingTour());
  }
}
```

`_startOnboardingTour` resets navigation state and sets `_tourStarted = true` with `setState`.

### 19.7 Editor tips lifecycle

- `_firstNoteTipsDismissed` starts false.
- Only show if `widget.showFirstNoteTips` is true.
- If the parent rebuilds, the local dismissal remains true.
- Do not mark tour seen again from the editor.

---

## 20. Test plan

### 20.1 Existing tests to update

`test/widget_test.dart`:

- In `setUp`, seed:
  ```dart
  SharedPreferences.setMockInitialValues({
    OnboardingKeys.completed: true,
    OnboardingKeys.tourSeen: true,
  });
  ```
- This keeps existing app-level tests starting on NotesScreen.
- Add one new test that empty prefs starts on onboarding, if not already covered by the new onboarding tests.

Direct `NotesScreen` tests do not need changes because `showOnboardingTour` defaults to false.

### 20.2 New provider tests

`test/onboarding/onboarding_provider_test.dart`:

1. Defaults are `completed: false`, `tourSeen: false` when keys are absent.
2. `complete()` persists `onboarding_completed_v1 = true`.
3. `markTourSeen()` persists `onboarding_tour_seen_v1 = true`.
4. `clearTourSeen()` persists false.
5. `finishWithTour()` sets completed true and tourSeen false.
6. `finishWithoutTour()` sets both true.
7. A new provider instance reads persisted state back.

### 20.3 New onboarding screen tests

`test/onboarding/onboarding_screen_test.dart`:

Use a `ProviderScope` with:
- in-memory `AppDatabase`,
- `DriftNotesRepository`,
- mock `SharedPreferences`,
- overrides for `databaseProvider`, `notesRepositoryProvider`, `sharedPreferencesProvider`.

Tests:

1. **Fresh prefs shows Welcome**
   - `find.text('A quiet place to think.')`
   - `find.text('Come on in')`
   - `find.text('Restore a backup')`
   - `find.text('Sign in')`
   - `find.text('Create account')`
   - Skip visible.

2. **All eight pages advance with correct primary labels**
   - Tap through pages.
   - Verify each title and footer label in order.
   - Verify page 6 label `Keep it local`.
   - Verify page 8 labels `Show me around` and `I'll find my way`.

3. **Skip persists and lands on NotesScreen**
   - Pump `QuietPaperApp`.
   - Tap Skip.
   - Expect `All Notes` and `No notes yet`.
   - Expect both prefs keys true.

4. **Show me around persists completed but not tour seen**
   - Navigate to page 8.
   - Tap Show me around.
   - Expect NotesScreen.
   - Expect completed true, tourSeen false.

5. **Theme choices persist**
   - Go to page 7.
   - Tap Warm Paper; expect `app_theme_family == 'warm_paper'`.
   - Tap Dark; expect `app_appearance_mode == 'dark'`.

6. **Sample notes load**
   - Empty DB.
   - Go to page 7.
   - Tap `Leave sample notes`.
   - Expect the success text.
   - Query repository / database and expect five notes.

7. **Sample block hidden when notes exist**
   - Seed one note before pumping.
   - Go to page 7.
   - Expect “Your desk already has notes.”
   - Expect no `Leave sample notes` button.

8. **Welcome auth links open correct auth views**
   - Tap Sign in; expect the sign-in form.
   - Go back; tap Create account; expect the signup email step.
   - This can be a focused test with the auth screen in a route.

9. **Success page copy**
   - Widget-test `OnboardingSuccessPage` for sync and restore variants.
   - Verify restore pluralisation.

10. **Small-phone layout has no overflow**
    - Set 320×568.
    - Pump each page, scroll, and assert `tester.takeException()` is null.

### 20.4 New coach-mark tests

`test/onboarding/coach_marks_test.dart`:

Pump `NotesScreen(showOnboardingTour: true)` with prefs overriding both status keys (completed true, tourSeen false), in-memory DB, and repository.

1. **Shows three steps**
   - Step 1 text.
   - Tap Next → step 2 text.
   - Tap Next → step 3 text.
2. **Skip tour**
   - Tap `Skip tour`.
   - Overlay disappears.
   - `onboarding_tour_seen_v1` becomes true.
3. **Create first note**
   - Advance to step 3.
   - Tap `Create my first note`.
   - Editor opens (title and body fields present).
   - Tips banner text visible.
   - One note exists in the DB.
4. **Dismiss editor tips**
   - Tap `Got it`.
   - Banner disappears.
5. **Fallback**
   - If targets are unavailable, the card is still present and can advance.
   - This can be tested by pumping at a size where the target key is not attached, or by directly testing the overlay with missing keys.

### 20.5 Auth tests

Add to `test/sync/sync_screens_test.dart`:

1. `SyncAuthScreen(initialView: signIn)` opens directly on “Sign In to Quiet Paper”.
2. `SyncAuthScreen(initialView: createAccount)` opens directly on the signup email step.

Existing default constructor tests must continue passing.

### 20.6 Settings replay tests

`test/settings/about_app_screen_test.dart` or add to `test/settings/settings_screen_test.dart`:

1. About screen renders “Show welcome tour”.
2. Tapping it opens `OnboardingScreen`.
3. (Optional integration) On replay, tapping Show me around sets tourSeen false.

### 20.7 Manual QA checklist

- Android phone, fresh install.
- Android tablet, fresh install.
- Linux desktop, fresh install.
- Existing install with notes: onboarding appears once.
- Skip from every page.
- Theme changes live update.
- Sample notes load and appear in NotesScreen.
- Sign in with existing account, cancel, and success.
- Create account through recovery key; success page.
- Restore a backup; success page shows the count.
- Coach marks on phone and tablet.
- Editor tips appear only on the first note.
- Settings replay.
- Replay while signed in.
- Small phone and large text scale.

---

## 21. Acceptance criteria

1. Fresh install opens the new Welcome page.
2. Welcome shows app icon, headline, body, and the three library/auth links.
3. Top-right Skip works on every carousel page.
4. There are exactly eight carousel pages in this order:
   - Welcome
   - Privacy + local-first
   - Voice + transcription
   - One list, one way
   - Offline OCR
   - Optional sync
   - Make it yours
   - Ready when you are
5. Copy matches the canonical copy deck exactly.
6. Each feature page has a Flutter-drawn vignette; no new image assets are used.
7. “Make it yours” offers Classic/Warm Paper, System/Light/Dark, and sample notes.
8. Theme changes apply immediately and persist.
9. Sample notes are loaded through the existing service and do not duplicate when notes already exist.
10. Sign in and Create account open the existing auth flow at the correct step.
11. Auth success shows the success page and then enters NotesScreen.
12. Restore backup opens the existing dialog; a successful restore shows the success page with the count.
13. The final page offers Show me around and I'll find my way.
14. Show me around closes onboarding and starts the coach-mark tour on the real NotesScreen.
15. The coach tour has sidebar, search, and create steps with the exact copy.
16. The coach tour’s Create action opens a blank editor with autofocus.
17. The editor shows the one-time “A few quiet tricks” card.
18. Completing or skipping the tour persists `tour_seen` so it does not reappear.
19. Settings → About → Show welcome tour replays the flow.
20. Existing users see onboarding once after this update, then never again.
21. `flutter analyze` reports zero errors and zero warnings.
22. `flutter test` passes.
23. `HANDOFF.md` documents the feature.
24. Changes are committed and pushed on `feat/onboarding-flow`.

---

## 22. Implementation order

1. Create the branch (already done for this plan file).
2. Add `OnboardingStatus`, notifier, keys, and provider.
3. Add `AppRoot`; update `app.dart`.
4. Build `OnboardingScreen` scaffold, page layout, top bar, footer, progress dots, and keyboard handling.
5. Add the Welcome, Privacy, Voice, Simplicity, OCR, Sync, Personalize, and First Note pages.
6. Add the Flutter vignettes.
7. Add the theme + appearance + sample-notes controls.
8. Add auth `initialView` and success results.
9. Add restore count result and optional snackbar.
10. Add the success page and completion wiring.
11. Add NotesScreen target keys, tour lifecycle, and overlay.
12. Add `showFirstNoteTips` to `EditorScreen` and the tips card.
13. Add the About replay row.
14. Update `test/widget_test.dart` and add new tests.
15. Run `flutter analyze`.
16. Run `flutter test`.
17. Fix any failures or overflows.
18. Update `HANDOFF.md`.
19. Commit and push.

---

## 23. Verification and delivery

Run from the repository root:

```bash
flutter analyze
flutter test
```

Expected:

- `flutter analyze`: no issues.
- `flutter test`: all tests pass, including the new onboarding/coach tests.

Backend tests are not required because there are no backend changes.

### HANDOFF update

Append a new section to `HANDOFF.md` after the latest numbered section:

```markdown
## 235. First-Run Onboarding, Interactive Coach Marks & Settings Replay (October 2026)

### Overview
...

### Flow
...

### Persistence
- onboarding_completed_v1
- onboarding_tour_seen_v1

### Auth & Restore
...

### Coach Marks
...

### Files
...

### Verification
- flutter analyze
- flutter test
```

Include at minimum:

- the eight-page flow,
- the existing-users-see-once decision,
- auth/restore entry points and success page,
- coach-mark behaviour and editor tips,
- Settings replay,
- the two persisted keys,
- no backend/schema changes,
- test results.

### Commit and push

```bash
git add .
git commit -m "feat(onboarding): add first-run welcome flow and interactive coach marks"
git push -u origin feat/onboarding-flow
```

Do not bump the app version for this feature.

---

## 24. Out of scope / future ideas

These were discussed during brainstorming but are explicitly **not** part of this implementation:

- A separate appearance-only page.
- “What’s new” tours after major versions.
- A first-run import prompt for Markdown folders.
- Tappable coach-mark spotlights that open the real drawer/search.
- Animated illustrations or video.
- Permission priming for microphone/storage/notifications.
- A permanent “Reset onboarding” option (replay replaces it).
- Changes to the sample note content.
- Onboarding-driven account creation inside the Notes screen.
- Localisation.

---

## 25. Final implementation checklist

- [ ] Branch `feat/onboarding-flow` checked out.
- [ ] Onboarding provider + keys implemented.
- [ ] AppRoot gate wired into `app.dart`.
- [ ] Eight carousel pages implemented with exact copy.
- [ ] Flutter vignettes implemented; no new assets.
- [ ] Theme + appearance + sample notes implemented.
- [ ] Welcome auth/restore links implemented.
- [ ] Sync page auth links + connected state implemented.
- [ ] Success page implemented for sync and restore.
- [ ] Auth `initialView` + success results implemented.
- [ ] Restore returns count + optional snackbar.
- [ ] NotesScreen target keys + coach overlay implemented.
- [ ] Editor first-note tips implemented.
- [ ] About replay row implemented.
- [ ] Existing tests updated.
- [ ] New provider/screen/coach/auth/replay tests added.
- [ ] Small-phone and tablet overflow checks pass.
- [ ] `flutter analyze` clean.
- [ ] `flutter test` green.
- [ ] `HANDOFF.md` updated.
- [ ] Commit and push completed.
