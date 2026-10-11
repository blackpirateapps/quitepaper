# Link Enhancements (Bear-style web links) — Spec

Status: Proposed — not started. No code written yet.
Owner: editor
Scope: Bring Bear's web/URL link conveniences to Quiet Paper's editors.
Source of inspiration: https://blog.bear.app/2025/12/things-you-might-not-know-about-links-in-bear/

## Locked decisions (from design Q&A)

- **Surfaces:** Visual (WYSIWYG) **and** Super Editor. The raw-Markdown source mode is
  **out of scope** for this pass.
- **Link previews ("Wake up, Link!"):** specified separately in
  `link-previews-spec.md`. Features 1–5 here ship first.
- **Auto-title fetch:** **Opt-in, default OFF** — honours the app's privacy posture
  (trusted-domain tap gate, crypto-blind sync). No outbound request happens unless the
  user turns the setting on.
- **Shared toggle:** the opt-in setting is a single **"Smart web links"** switch
  (default OFF) that governs *both* auto-filled titles (Feature 1 here) *and* preview
  cards (see `link-previews-spec.md`). One switch, both behaviours.
- **Link kind in scope:** external web links only (`http(s)://…`). Internal `qp://note`
  links, backlinks, and `#tags` already exceed Bear's article and are untouched.

## Background — how links work today

Three link kinds already exist:
- External `[text](url)`
- Internal note links `[display](qp://note/<UUID>)` ⇄ `[[Title]]` in the rich model
- Hashtags `#tag`

Relevant code:
- Style enum: `lib/features/editor/domain/editor_editing_style.dart` (`superEditor`,
  `wysiwyg` [default], `markdown`).
- Host screen: `lib/features/editor/presentation/editor_screen.dart`
  (central paste `_handlePaste` ~`:2717`; Ctrl/Cmd+V binding ~`:1628`; link dialog
  invoked ~`:958`).
- Dispatcher: `lib/features/editor/presentation/widgets/markdown_editor.dart`
  (`superEditor` → `QuietSuperEditor`; `wysiwyg` → `RichEditorSurface`; `markdown` →
  text field).
- Visual model: `lib/features/editor/domain/text_attributes.dart` — links are **inline
  span attributes** `linkUrl` / `linkTitle` (~`:40-44`), not nodes. Spans:
  `rich_inline.dart` (`RichInlineSpan`).
- Serialize link → `[text](url "title")`:
  `lib/features/editor/application/rich_document_serializer.dart` ~`:132-137`.
- Parse inline link (regex `\[([^\]\n]+)\]\(([^)\s]+)(?:\s+"([^"]*)")?\)`):
  `lib/features/editor/application/rich_document_parser.dart` ~`:362-379`.
- Insert-link UI: `LinkPromptDialog`
  (`lib/features/editor/presentation/widgets/link_prompt_dialog.dart`) — title + URL only.
- Template helper: `MarkdownHelper.insertLink`
  (`lib/core/markdown/markdown_helper.dart:222`).
- Link tap + safety: `LinkLauncherHelper`
  (`lib/core/utils/link_launcher_helper.dart:58`) with a trusted-domains confirmation
  dialog persisted under SharedPreferences key `trusted_domains`.
- Page metadata fetch (reusable): `ArticleExtractor`
  (`lib/core/web_clipper/article_extractor.dart`) already extracts `<title>` /
  OpenGraph / Twitter-card metadata; `http.Client` with a browser `User-Agent` as in
  `web_image_downloader.dart` / `web_snapshot_generator.dart`.
- URL regex (bare link detection): `markdown_parser.dart:35`.

## The paste problem (read before implementing features 1 & 4)

Paste is handled in **two independent places**, and both must learn the URL logic:

1. **WYSIWYG / dispatch path:** `EditorScreen._handlePaste`
   (`editor_screen.dart:2717`). Plain text is already in hand here before the
   plain-insert fallback (~`:2878`) — the natural interception point.
2. **Super Editor path:** `quiet_super_editor_controller.dart:478-512` uses
   SuperEditor's own `PasteStructuredContentEditorRequest`, **bypassing**
   `_handlePaste`. The URL detection must be wired in here separately (this is the
   fiddlier of the two). Confirm the exact request/reaction hook before coding.

A shared pure helper (see Cross-cutting) keeps the two paths consistent.

## Out of scope (this pass)

- Rich link preview cards (image / title / description) — deferred, brainstormed
  separately.
- Raw-Markdown source editing mode.
- Any change to internal note links, backlinks, or hashtags.
- Auto-fetching titles by default (always opt-in here).

## Feature 1 — Auto-filled titles on paste (opt-in)

**Behavior.** With the setting ON, pasting a message whose entire payload is a single
`http(s)` URL inserts a titled link instead of raw text:
1. Insert `[<url>](<url>)` immediately (never block the paste on the network).
2. Fire an async fetch of the page title/OG title.
3. On success, replace only the display text in place → `[<Real Title>](<url>)`. On
   failure/timeout, leave the URL-as-title link untouched. Guard against the user
   having edited/moved away before the fetch resolves (match by a stable marker, not a
   raw offset).

With the setting OFF, paste behaves exactly as today (raw URL text).

**Surfaces.** WYSIWYG: build the `linkUrl/linkTitle` span directly, then patch
`linkTitle` when the title arrives. Super Editor: insert text with `LinkAttribution`,
then patch the attributed text run.

**Hooks.** `_handlePaste` (`:2717`) + Super Editor paste (`:478-512`); fetch via
`ArticleExtractor` + `http.Client`; gated by the new setting (Feature 6).

**Edge cases.** Trailing whitespace/newline tolerated; multi-line or non-URL payloads
ignored; `qp://` and `mailto:`/other schemes excluded (web links only); a short fetch
timeout (~5 s) with cancellation; redaction-safe (don't log the URL).

## Feature 2 — "Edit Link" panel + ⌘K

**Behavior.** One shortcut opens a panel to add **or edit** a link:
- Fields: URL, Title, (preview toggle intentionally absent until previews ship).
- If the caret sits inside an existing link, the panel pre-fills from it and edits in
  place rather than inserting a new one.
- Desktop: bind **Cmd/Ctrl+K** alongside existing shortcuts
  (`editor_screen.dart:1628`). Mobile: keep the toolbar entry (~`:958`) as the opener.

**Surfaces.** WYSIWYG: read/write `linkUrl`/`linkTitle` on the span under the caret.
Super Editor: read/write `LinkAttribution` on the selected range.

**Hooks.** Extend `LinkPromptDialog`
(`link_prompt_dialog.dart`) to accept initial URL+title and an "edit existing" mode;
add link-at-caret lookup helpers per surface.

**Edge cases.** Selection spanning a partial link; caret between adjacent links; empty
title defaults to the URL.

## Feature 3 — Smart clipboard detection

**Behavior.** When the Edit Link panel opens with an empty URL field, peek the
clipboard; if it holds a single `http(s)` URL, pre-fill the URL field (and focus the
Title field so the user just types a title). Never overwrite a URL the user is editing.

**Hooks.** `Clipboard.getData(kTextPlain)` inside the panel's init; same URL validator
as Feature 1. No network, no persistence — purely local.

## Feature 4 — Paste-onto-selection → titled link

**Behavior.** With a **non-empty text selection**, pasting a single `http(s)` URL wraps
the selection as `[<selection>](<pasted url>)` — selection becomes the title, pasted
URL becomes the href. This is an explicit gesture, so it works **regardless** of the
Feature 1 opt-in toggle and does **no** network fetch.

Note: today's `MarkdownHelper.insertLink` does the *inverse* (treats a selected URL as
the href). This feature adds the Bear direction; keep both.

**Surfaces + hooks.** Both paste paths (`:2717` and `:478-512`): if selection is
non-empty and clipboard/paste text is a lone URL, apply link attributes to the selected
range instead of replacing it.

**Edge cases.** Selection that already contains a link (replace vs. nest — spec:
replace the link target); selection crossing block boundaries (fall back to plain
paste).

## Feature 5 — Easy revert / edit

**Behavior.** In the Edit Link panel:
- Clearing the **Title** and confirming → link renders as a plain URL (`[url](url)` or
  bare, consistent with serializer output).
- Clearing the **URL** and confirming → the text reverts to plain text (link
  attributes removed), keeping the characters.

**Surfaces + hooks.** WYSIWYG: remove/adjust `linkUrl`/`linkTitle` span attributes.
Super Editor: remove `LinkAttribution` over the range. No reparse of the whole doc.

## Cross-cutting

### Settings toggle (Feature 6 — shared "Smart web links" switch, enables Feature 1)
- Single boolean, default **false**, SharedPreferences-backed Riverpod notifier
  mirroring `EditingStyleNotifier` (`settings_provider.dart:121-148`), e.g. key
  `app_smart_web_links`.
- Governs **both** this spec's Feature 1 (auto-fill titles on paste) **and** the preview
  cards in `link-previews-spec.md` (fetch + display). One switch, both behaviours.
- Surface a `CupertinoSwitch` (pattern at `settings_screen.dart:1285`) in the **EDITOR**
  section (`settings_screen.dart:918`), with a one-line caption noting it makes network
  requests to pasted/linked URLs.

### Shared URL helper (new, pure/testable)
- `isSingleWebUrl(String)` → bool and `normalizeWebUrl(String)` in a small util under
  `lib/core/utils/` (reuse the `markdown_parser.dart:35` regex semantics). Used by
  Features 1, 3, 4 so all three paths agree on what "a URL" is.

### Title fetch service (new, thin wrapper)
- Wrap `ArticleExtractor` title/OG extraction behind a `LinkTitleFetcher` with an
  injected `http.Client`, timeout, and cancellation; returns `String?`. No caching in
  this pass (previews will own caching later).

## Testing plan (per AGENTS.md: `flutter analyze` + `flutter test` must be green)

- Unit: `isSingleWebUrl` / `normalizeWebUrl` (URLs, trailing newline, non-URLs, `qp://`,
  `mailto:`, multi-line).
- Unit: `LinkTitleFetcher` with a mocked `http.Client` (success, 404, timeout, non-HTML,
  missing title → falls back to URL).
- Widget/logic: paste-onto-selection produces the expected span/attribution on both
  surfaces; auto-title OFF = raw paste; panel edit/revert transitions (title cleared,
  URL cleared).
- Regression: existing `LinkPromptDialog` callers still work; `qp://` note-link paste
  and tap behavior unchanged.

## Open questions (non-blocking; sensible defaults chosen above)

1. Super Editor paste interception — exact request/reaction seam to use (confirm in
   code before implementing Features 1 & 4).
2. Should auto-title (Feature 1) also respect the trusted-domain gate, or is the
   master opt-in toggle enough? (Spec assumes toggle is enough; revisit if desired.)
3. Fetch timeout value and whether to show any subtle "fetching…" affordance (spec:
   silent, 5 s).

## Related: link previews

Rich preview cards ("Wake up, Link!") are specified in `link-previews-spec.md`. They
share the "Smart web links" toggle above and reuse the parser's lone-line-link → card
promotion mechanism (`rich_document_parser.dart:291-294`).

