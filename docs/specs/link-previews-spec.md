# Link Previews ("Wake up, Link!") — Spec

Status: Proposed — not started. No code written yet.
Owner: editor
Scope: Rich preview cards for external web links. Companion to `link-enhancements-spec.md`
(features 1–5); do that work first. Inspiration:
https://blog.bear.app/2025/12/things-you-might-not-know-about-links-in-bear/

## Locked decisions (from design Q&A)

- **Metadata storage:** **baked into the note** (not derived/cache-only). The card's
  title/description/site live in the note content; the thumbnail rides as a synced
  attachment reference.
- **Trigger:** a URL **alone on its own line** auto-promotes to a card. Inline URLs stay
  plain text links. Reuses the existing lone-line → card promotion
  (`rich_document_parser.dart:291-294`).
- **Fetch timing:** auto-load, but only when the shared **"Smart web links"** toggle is
  ON (default **OFF**). No lazy tap-to-load.
- **Thumbnails:** cached locally **and synced**. Transport = a normal **encrypted
  attachment** (`qp://asset/<id>`) over the existing crypto-blind Cloudinary pipeline — a
  fresh device fetches the ciphertext once from *our* store, never the origin site.
  Image is **compressed to a small thumb** (~800px) before storing. Stored as an
  **internal/hidden** attachment (kept out of the note's user-facing attachment list).
  **Deleted with the preview** when the preview is removed.
- **Bake timing:** **on note open** (toggle ON) — opening a note fetches/bakes any
  not-yet-previewed lone-line URLs, which marks the note dirty and re-syncs it.
- **Toggle scope:** the toggle controls **both fetching and display**. A device with the
  toggle OFF renders already-baked previews as **plain links**, not cards. So a card only
  ever appears on a device whose toggle is ON.
- **Empty state:** a lone-line URL with no baked preview (toggle off, never baked, or
  fetch failed) renders as a **plain link**.
- **Refresh:** **manual only** — a "Refresh preview" action re-fetches/re-bakes;
  otherwise the snapshot stays frozen.
- **Surfaces:** render cards in **Visual (WYSIWYG)**, **Super Editor** (atomic block,
  like image/attachment components), and the **read-only Markdown preview**. Raw-Markdown
  source mode keeps the URL as plain text.
- **Toggle:** **shared** with the auto-title feature — one "Smart web links" switch.
- **Out of scope:** provider-specific rich embeds (YouTube/Twitter players); internal
  `qp://note` links (they already have their own card promotion).

## Why this is cheap to build: the pipeline already exists

The web clipper already does "fetch a remote image → encrypt → store locally → sync →
resolve on other devices," which is exactly what a synced thumbnail needs:
- `AttachmentService.importImageFromBytes` (`attachment_service.dart:85-167`): 10 MB cap
  → encrypt (XChaCha20-Poly1305 under Master Key, `attachment_crypto.dart`) → write
  `<id>.enc` to disk → RAM-cache plaintext → DB row (`uploadPending`, `isDirty`) →
  returns `{attachment, markdownSnippet}` where the snippet is `![](qp://asset/<id>)`.
- `AttachmentSyncService.syncPendingAttachments` (`attachment_sync_service.dart:59-217`)
  uploads the ciphertext to Cloudinary (`resource_type: raw`) and confirms
  metadata-only to the backend.
- `AttachmentService.resolveAsset` (`attachment_service.dart:399-528`) resolves a
  `qp://asset/<id>` ref local-first, Cloudinary-fallback, decrypt, verify.
- `WebImageDownloader.downloadAndEncryptImages` (`web_image_downloader.dart:21-111`) is
  the fetch-then-import helper; `web_clipper_service.dart:60-230` is the end-to-end
  precedent.
- `DefaultImageCompressionService.compressImage` (`image_compression_service.dart:111`,
  provider `:288`) downscales in a background isolate — call with `force: true` and a
  small preset for the thumb.
- Page metadata: `ArticleExtractor` (`web_clipper/article_extractor.dart`) already pulls
  `<title>` / OpenGraph / Twitter-card fields.

So a synced thumbnail = fetch OG image bytes → `compressImage(force:true, ~800px)` →
`importImageFromBytes` → embed the returned `qp://asset/<id>` in the card.

## Data model — the baked card

A card carries: `url`, `title`, `description`, `siteName`, `thumbnailAssetId`
(`qp://asset/<id>`, nullable), `fetchedAt` (ISO-8601). Two representations, one per note
format:

- **RichDocument JSON (Visual notes):** a new block type, e.g. `linkPreview`, in
  `rich_block.dart` / `rich_document.dart`, holding the fields above. The serializer
  (`rich_document_serializer.dart`) emits the Markdown form below; the parser
  (`rich_document_parser.dart`, extending the lone-line promotion at `:291-294`) builds
  the block from it.
- **Markdown notes / export round-trip:** keep the visible link on its own line and bake
  the extras in an adjacent HTML comment — the same sentinel style the app already uses
  for encrypted notes (`note_model.dart:53-54`):

  ```
  [Title](https://example.com/post)
  <!-- qp-link-preview: {"desc":"…","site":"example.com","img":"qp://asset/<id>","ts":"2026-10-11T…"} -->
  ```

  This survives Markdown export (invisible comment) and converts cleanly to/from the
  RichDocument block. **Decided** (sign-off received) — this is the canonical on-disk /
  export encoding.

### Thumbnail attachment specifics
- Stored via `importImageFromBytes` with `noteId` set (so note deletion cascades) but a
  **distinct kind** (e.g. `kind: 'linkPreview'`, `attachments_table.dart:25`) so it is
  excluded from the note's attachment list and `note_thumbnail_view` candidates.
- Single `original` variant only — the `attachment_variants` table is scaffolding with
  no generators yet; don't rely on it. Compression at import time gives us the small
  size directly.
- On preview removal: tombstone the attachment (`isDeleted`/`deletedAt`,
  `attachments_table.dart:52-55`) so sync propagates the delete.

## Behaviour flows

**Bake on open (toggle ON).** On note open, scan for lone-line external URLs without a
baked preview. For each: fetch metadata (`ArticleExtractor`) + download/compress/store
the OG image (→ `qp://asset/<id>`), write the `linkPreview` block/comment into the note.
This mutates the note → `isDirty` → normal sync. Do it off the main thread, debounced,
and skip if offline (retry next open). Never block rendering on the fetch — show the
plain link until data lands, then swap in the card.

**Toggle OFF (fetch + display gate).** No scanning, no fetching, no mutation. Any
already-baked `linkPreview` data in the note renders as a **plain link** (ignore the
baked card). Turning the toggle back ON makes baked cards appear again (and backfills
new ones on next open).

**Empty / failed state.** No baked data (or fetch failed) → plain clickable link, no card
chrome. A failed fetch is retried on a later open (toggle ON); don't bake a broken card.

**Refresh.** Card overflow menu → "Refresh preview": re-fetch metadata + image, replace
the thumbnail attachment (tombstone old, import new), re-bake. No automatic TTL.

**Removal.** Card overflow menu → "Remove preview": demote to a plain inline link
(`[Title](url)`), strip the `linkPreview` block/comment, tombstone the thumbnail.

## Rendering & interaction

- Shared `LinkPreviewCard` widget consumed by all three surfaces. In Super Editor it's a
  custom atomic component alongside `widgets/super_editor/` (image/attachment/table/task);
  in Visual it's the `linkPreview` block renderer; in `markdown_preview.dart` it renders
  read-only.
- Layout: thumbnail (if any) + title (1–2 lines) + description (2–3 lines) + site/domain
  row. Degrade gracefully when fields are missing (no image → text-only card; no title →
  domain as title).
- Thumbnail image resolves through `resolveAsset('…', variant:'original')` — local-first,
  so it works offline once synced.
- Tap → open the URL via `LinkLauncherHelper.handleLinkTap`
  (`link_launcher_helper.dart:58`), preserving the trusted-domain confirmation gate.
- The card is a single atomic unit for caret/selection/delete, like the image component.

## Privacy & crypto-blind notes

- Fetching happens only with the toggle ON (default OFF), consistent with the auto-title
  posture. The origin site is contacted only by the device that bakes the preview; other
  devices pull the encrypted thumbnail from our Cloudinary store, never the origin.
- The thumbnail is encrypted exactly like any user image (`attachment_crypto.dart`,
  XChaCha20-Poly1305 under the Master Key) — the backend/CDN stays crypto-blind.
- Baked text metadata lives inside the note's `contentCiphertext`, so it is also
  crypto-blind on sync (`docs/sync-protocol.md`).

## Testing plan (per AGENTS.md: `flutter analyze` + `flutter test` green)

- Unit: lone-line-URL detection; parse/serialize round-trip of the `linkPreview`
  block ⇄ Markdown comment form (incl. missing optional fields, note with no preview).
- Unit: metadata extraction mapping from `ArticleExtractor` output to card fields
  (missing OG → domain fallback).
- Logic: thumbnail import path with a mocked `http.Client` + compression (stores a
  `linkPreview`-kind attachment, excluded from the attachment list; removal tombstones).
- Behaviour: toggle OFF renders baked data as a plain link and performs no fetch/mutation;
  toggle ON bakes on open and marks dirty; refresh replaces the thumbnail.
- Regression: `qp://note` card promotion and `qp://asset` image rendering unchanged.

## Open questions (surface for sign-off; sensible defaults proposed above)

1. **Bake-on-open side effect:** opening a note (toggle ON) can modify + re-sync it, and
   could cause bake races if two devices open the same note before syncing. Acceptable
   via normal last-writer/merge, or do we want baking confined to the note's own device
   edits? (Locked answer was "on note open"; this notes the consequence.)
2. **Thumbnail dimension/quality** — proposed ~800px via an existing small preset; confirm
   exact numbers.
3. Non-HTML link targets (PDF/image URLs) — treat as plain link (no card)? (Assumed yes.)

### Resolved
- **Markdown encoding of baked metadata** → the `<!-- qp-link-preview: {…} -->` comment
  form next to the link (see Data model). Signed off.

