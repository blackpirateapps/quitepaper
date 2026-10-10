# Quiet Paper — Bengali Content Support (Implementation Spec)

**Status:** Planned, not started. **Audience:** coding agents implementing this feature.
**Last updated:** 2026-10-10.

## 0. Follow the repo workflow
Obey `AGENTS.md`: after each change run `flutter analyze` (zero warnings) and `flutter test` (all pass), update `HANDOFF.md` with a new numbered section, then commit with a conventional message and push. Do not commit secrets.

## 1. Scope & non-goals
This feature adds **Bengali content support only** — users can write, read, search, and (via existing Whisper) dictate Bengali *note content*. It does **not** localize the app's own UI chrome.

In scope (this spec):
- **A. Bengali font fallback** so Bengali text renders everywhere, under any chosen Latin font.
- **B. Unicode-aware search & tags** so Bengali notes/tags are findable.
- **C. Journal Bengali dates & numerals** (opt-in, display-only localization).

Explicitly OUT of scope — do not implement:
- App UI localization / `flutter_localizations` / ARB. (Separate future project.)
- **PDF/print export** of Bengali: the `pdf` package shapes complex scripts poorly and `lib/core/pdf/pdf_font_manager.dart` embeds Latin faces only. Leave as-is; Bengali PDF output will be wrong and that is accepted for now.
- **Bengali OCR.** Google ML Kit has no Bengali script pack; do not try to extend `lib/core/ocr/ocr_service.dart`.

Bengali is left-to-right — no bidirectional/RTL handling is required.

## 2. Locked decisions (do not re-litigate)
- The Bengali display font is **Kalpurush** (user-supplied, license verified OK to bundle). It ships bundled in the APK (not via CDN) because it must always be available offline.
- Kalpurush has **only a Regular weight** — there is no Bold or Italic file. Bold/italic Bengali will be **synthesized (faux) bold/italic** by Flutter. This is accepted for v1. Do not attempt per-run weight splitting or source substitute faces.
- Font verified via fontTools: TrueType, 586 glyphs, `GSUB`/`GPOS`/`GDEF` present, scripts `beng`+`bng2`, full Indic feature set (`akhn half blwf pstf rphf vatu pres blws psts abvs nukt haln locl`), covers all everyday Bengali incl. Taka ৳. Flutter's HarfBuzz shaper renders conjuncts/reph/kars correctly.

## 3. Feature A — Bengali font fallback (Kalpurush)

### A.1 Bundle the asset
- The font is already bundled in the repo at `assets/fonts/Kalpurush-Regular.ttf`.
- Register it in `pubspec.yaml` under `flutter: fonts:` as family `Kalpurush` (single Regular asset). The existing `assets/fonts/` Phosphor entries show the pattern.

### A.2 Add a shared fallback constant
Create one source of truth (e.g. in `lib/core/utils/font_family_helper.dart`):
```dart
const String kBengaliFallbackFamily = 'Kalpurush';
const List<String> kContentFontFallback = <String>[kBengaliFallbackFamily];
```

### A.3 Apply the fallback at every text chokepoint
Goal: whatever Latin family the user picks, Bengali runs fall through to Kalpurush. Add `fontFamilyFallback: kContentFontFallback` to the `TextStyle`s that render note content. Known chokepoints:
- `FontFamilyHelper.getTextStyle` (`lib/core/utils/font_family_helper.dart:126-165`) — EVERY return path must carry the fallback: the plain `baseStyle` return (:130-131), the `.copyWith(...)` returns (:134,137,144,152,158,163), AND the `GoogleFonts.getFont(...)` return (:161), which accepts a `fontFamilyFallback:` argument. Prefer computing the style then `.copyWith(fontFamilyFallback: kContentFontFallback)` at a single exit, but pass it into `GoogleFonts.getFont` via its own param and verify the merge in a preview.
- Base app `ThemeData` text theme (`lib/app/app.dart`, the `MaterialApp` at :54-68 sets no text theme today) so Material surfaces that show titles/snippets (dialogs, menus, note list) also fall back.
- Editor styles: `MarkdownEditingController` / `MarkdownParser` body + heading spans; `QuietMarkdownPreview` (`lib/core/markdown/markdown_preview.dart`) markdown style sheet; super_editor styles (`quiet_super_editor*`). Add the fallback wherever these build `TextStyle`.
- **Code font too:** inline code / code blocks use `monospace`; Bengali inside code must still render, so include the fallback on code styles as well (monospace primary, Kalpurush fallback).

### A.4 Faux-bold reality
Kalpurush is Regular-only, so headings and `**bold**` Bengali are engine-synthesized. Accepted. If headings look poor in manual QA, note it in HANDOFF but do not block.

### A.5 Verification
- Widget test asserting `FontFamilyHelper.getTextStyle(...).fontFamilyFallback` contains `'Kalpurush'` for representative inputs (null/System, a cached family, a Google font name).
- Manual: a note mixing scripts (e.g. `Hello আমি ক্ষুধার্ত`) renders both with no tofu, in light + dark, across editor + preview + note-list snippet.

## 4. Feature B — Unicode-aware search & tags

Today Bengali note content and Bengali `#tags` are effectively invisible to search: tokenization uses ASCII `\w` and tag parsing uses `[a-zA-Z0-9]`. This is the must-do core of "Bengali is searchable."

### B.1 Dart search tokenizer
- `lib/core/search/search_tokenizer.dart:47` — replace `RegExp(r'[\w#]+')` with `RegExp(r'[\p{L}\p{N}_#]+', unicode: true)`. (Dart's `\w` is ASCII-only and matches no Bengali, so Bengali currently yields zero tokens.)
- `lib/core/search/fuzzy_search_engine.dart:192` — replace `RegExp(r'\b[\w#]+\b')` with the same `[\p{L}\p{N}_#]+` match (drop the ASCII-only `\b` word boundaries).
- `toLowerCase()` calls (tokenizer :46,:85; fuzzy :156,:164,:220) are harmless for caseless Bengali — leave them.

### B.2 Tag recognition regexes (Bengali hashtags)
These hard-code ASCII and silently truncate Bengali tags at the first non-ASCII char — fix to accept Unicode letters/digits while keeping `#` and the `_-/` separators:
- `lib/features/editor/application/markdown_parser.dart:36` `_tagRegex = RegExp(r'#([a-zA-Z0-9_\-\/]+)')`
- `lib/features/editor/application/markdown_tokenizer.dart:421` (same pattern)
Use e.g. `RegExp(r'#([\p{L}\p{N}_\-\/]+)', unicode: true)`. Leave `lib/core/pdf/pdf_markdown_parser.dart:438` (PDF is out of scope).
- Re-check `tag_autocomplete_trigger.dart:66` and `tag_parser.dart:265-279` with Bengali input — their patterns are negated classes / escaped-literal and should already work; verify, don't blindly rewrite.

### B.3 Unicode normalization (NFC) — recommended
Bengali o-kar (ো U+09CB) and au-kar (ৌ U+09CC) are canonically equivalent to decomposed sequences, and different IMEs emit different forms, so a word can fail to match itself. Normalize to **NFC** both when indexing content and when compiling queries, in the tokenizer/normalizer path (`search_tokenizer.dart`, `lib/core/search/markdown_offset_mapper.dart`). Dart core has no NFC; add a small dependency (e.g. `unorm_dart`) or a focused normalizer. If skipped for v1, record it as a known gap in HANDOFF.

### B.4 FTS5 diacritics — evaluate (needs migration if changed)
`lib/core/database/app_database.dart:392` uses `tokenize = 'unicode61 remove_diacritics 2'`, which strips Bengali matras (combining vowel signs) and conflates distinct words (করি/কর/করা). The now-Unicode-aware Dart re-ranker is the precise matcher, so this mainly over-broadens candidate recall. Evaluate empirically; if it hurts, switch the prefix index to `remove_diacritics 0`. **Changing the tokenizer requires rebuilding the FTS tables** (drop + recreate + reindex) via a schema migration — follow the idempotent-migration pattern in this file (HANDOFF §61). The `trigram` table (:406) is unaffected.

### B.5 Fuzzy edit-distance (low priority)
`FuzzySearchEngine.damerauLevenshtein` (`fuzzy_search_engine.dart:66-131`) compares UTF-16 code units, so edit distance over Bengali conjunct clusters is slightly off. Acceptable for v1; optionally make it grapheme-aware via the `characters` package later.

### B.6 Verification
- Unit tests: tokenizing a Bengali string yields expected tokens (currently none); a Bengali `#বাংলা` tag is extracted; a Bengali query matches a Bengali note end-to-end through `FuzzySearchEngine`.
- Manual: create a Bengali note + Bengali tag, confirm both are found via global search and the tag filter.

## 5. Feature C — Journal Bengali dates & numerals (opt-in, display-only)

### C.1 Setting
Add a boolean journal setting, e.g. `bengaliDates` (default **false**), to the Journal Settings surface added in HANDOFF §164 (locate the journal settings provider/model; persist like the other journal settings). Label it e.g. "Bengali dates & numerals".

### C.2 Apply the locale to DISPLAY formatting only
When the setting is on, format displayed journal dates with the `'bn'` locale — `intl`'s Bengali locale emits both Bengali month names and Bengali numerals (০–৯) automatically, so no manual digit mapping is needed (`DateFormat('MMMM yyyy', 'bn')`).
- At app startup call `initializeDateFormatting('bn', null)` (from `package:intl/date_symbol_data_local.dart`; it is currently never called anywhere) before any `'bn'` DateFormat runs.
- Thread the active locale tag into the journal date helper. Display chokepoints:
  - `lib/core/journal/domain/journal_date_helper.dart` — `formatDisplayDate` (:69), `formatMonthDay` (:81), `formatMonthYear` (:157), `formatMonthYearHeader` (:163), `formatWeekday` (:175), `formatWeekdayShort` (:187), `formatTimelineEntryMetadata` (:194). Add an optional `String? localeTag` (or read the setting) and pass it to each `DateFormat`.
  - `lib/features/journal/domain/journal_visit.dart:119,121` and `lib/features/journal/presentation/widgets/place_card.dart:14` — inline `DateFormat`; apply the same locale.

### C.3 NEVER localize storage/keys
Do **not** touch functions that build canonical keys or parse dates — they must stay ASCII `yyyy-MM-dd` / Western digits:
- `JournalDateHelper.toDateString` (:10), `todayString` (:19), `monthKey` (:228), `tryParseMonthKey` (:235), `_datePattern` (:7), `tryParseDateString` (:50).
Localizing any of these corrupts lookups and stored data. Localization is for human-visible strings only.
- Leave app-wide `lib/core/utils/date_formatter.dart` (note-list times/buckets) in English — extending the setting beyond journal is out of scope here.

### C.4 Verification
- Unit test: with locale `'bn'`, `formatMonthYear` returns Bengali text/numerals; `toDateString`/`monthKey` stay ASCII regardless of the setting.
- Manual: toggle on → timeline datelines, calendar header, place cards show Bengali; toggle off → English. Confirm journal entries still load (keys unchanged).

## 6. Suggested order
1. **A (fonts)** first — foundational; everything else is readable once Bengali renders.
2. **B (search/tags)** — the core content win.
3. **C (journal dates)** — smallest, self-contained.
Each is its own commit + HANDOFF section.

## 7. Noted but out of scope (do not implement unless asked)
- Whisper already supports Bengali via the multilingual model (`languageCode 'auto'`). A per-recording `bn` override could be wired at `lib/core/speech/application/speech_recognition_service.dart:215`, but is not part of this spec.
- Bengali collation/sort order for note/tag lists uses Dart's code-unit compare (roughly Unicode order) — acceptable, not addressed here.



