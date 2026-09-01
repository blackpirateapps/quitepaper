# Quiet Paper — Phosphor Icon System & Full Offline Tag Icon Picker

You are working inside the existing **Quiet Paper Flutter application**.

Implement a complete, production-quality **Phosphor Icons integration and tag icon system**.

This is not a mockup or prototype.

Do not create placeholder icons, fake icon data, incomplete catalogs, hard-coded demo entries, or TODO implementations.

Everything described below must be functional.

Before modifying code, inspect the repository and read `HANDOFF.md` in full. Also inspect the current:

- theme system
- tag model/database
- tag creation/editing UI
- sidebar/tag UI
- editor toolbar
- settings
- existing icon usage
- asset/build configuration
- database migrations
- test conventions

The implementation must integrate naturally with the architecture that already exists.

---

# 1. Product Goal

Replace Quiet Paper's current generic iconography with **Phosphor Icons** and establish Phosphor as the application's canonical icon family.

Additionally, users choosing an icon for a tag must have access to the **full available Phosphor icon catalog**, while keeping the application:

- offline-first
- performant
- memory-conscious
- responsive
- stable
- production-ready

The user should be able to open:

```text
Tag → Choose Icon
```

and browse/search the complete local Phosphor catalog without requiring an internet connection.

The entire catalog must not be represented as thousands of individual Flutter asset files/widgets unnecessarily.

Use a compact local vector/icon catalog that can be lazily loaded and virtualized.

---

# 2. Core Architectural Principle

Separate:

### Application icon usage

Only the icons actually used by Quiet Paper's UI need to be directly referenced/compiled into the normal UI icon implementation.

### Tag icon catalog

The tag picker exposes the entire Phosphor catalog through a compact local catalog.

Conceptually:

```text
Phosphor source
      ↓
build-time catalog generation
      ↓
compressed local vector catalog
      ↓
Quiet Paper Icon Registry
      ↓
┌───────────────────────┐
│                       │
│ App UI icons           │
│ Tag picker catalog     │
│                       │
└───────────────────────┘
```

Do not make runtime CDN/network access a requirement.

The tag icon picker must work fully offline.

---

# 3. Important Offline Requirement

Do NOT fetch icons from a CDN when the user opens the picker.

Do NOT make tag icons dependent on:

- internet connectivity
- HTTP availability
- Cloudinary
- Vercel
- Firebase
- any external icon service

The entire tag icon catalog required for the picker must be available locally in the app.

A CDN or remote Phosphor source may be used by a **build-time generation/update script**, but never as a runtime dependency.

---

# 4. Use Phosphor Icons as the Canonical Icon Family

Adopt Phosphor consistently throughout Quiet Paper wherever an icon exists.

Do not introduce:

- Material Icons for new UI elements
- random SVG icons
- another icon library
- emoji as icon substitutes
- inconsistent custom icons for ordinary UI actions

Existing icons may be migrated progressively, but this implementation should establish Phosphor as the canonical system.

Use Phosphor semantics and naming consistently.

---

# 5. Phosphor Weights

Phosphor supports multiple visual weights.

For application UI, support the appropriate Phosphor weights available through the chosen integration.

Preferred default:

```text
Regular
```

Use lighter/heavier/fill variants only when the existing Quiet Paper visual language benefits from them.

Do not mix weights randomly.

Establish explicit rules.

Recommended:

### Standard UI

Regular

### Quiet secondary UI

Light

### Emphasis/selected state

Fill or Bold where appropriate

### Tag icons

Use one canonical default weight initially, preferably:

```text
Regular
```

Do not make users choose the weight for every tag.

The database should store the semantic icon identity, not a specific generated asset filename.

---

# 6. Stable Tag Icon Storage

A tag must store a stable icon identifier.

Recommended representation:

```text
phosphor:heart
```

or another stable equivalent.

Do NOT store:

- SVG bytes in SQLite
- path data in SQLite
- array indexes
- Flutter widget names
- package-specific generated class names

Do not use:

```text
iconIndex = 482
```

because catalog ordering can change.

Use stable semantic icon IDs.

Example:

```text
tag
 ├── id
 ├── name
 ├── iconKey = "phosphor:book-open"
 └── ...
```

---

# 7. Database Migration

Inspect the existing Tag/Tags database schema.

If an icon field does not already exist:

add a nullable/icon-key column using the repository's established migration conventions.

For example:

```text
icon_key TEXT NULL
```

Do not store the icon's rendered representation.

The migration must work correctly for:

- fresh installs
- all currently supported existing database versions
- upgrades
- restored databases

Existing tags must remain valid and simply have no icon until assigned.

Do not assign random default icons during migration.

---

# 8. Tag Icon Default Behavior

A tag without an icon remains completely valid.

Do not force users to choose an icon.

Where no icon exists:

- render the existing fallback/tag representation
- do not show an empty placeholder glyph
- do not display a broken image

The application must continue functioning exactly as before for tags without custom icons.

---

# 9. Central Icon Registry

Create a single application-level icon registry/resolver.

Conceptually:

```dart
IconDefinition? resolveIcon(String iconKey);
```

or equivalent according to the existing architecture.

Responsibilities:

- validate icon keys
- resolve Phosphor icons
- provide metadata for picker
- provide render information
- gracefully handle unknown/deprecated IDs

Do not scatter string comparisons such as:

```dart
if (iconKey == 'heart') ...
```

throughout the codebase.

---

# 10. Unknown Icon Handling

A tag may contain an icon key that the current catalog no longer recognizes.

This can happen after:

- app upgrade
- catalog changes
- legacy data
- malformed imported data

Do not crash.

Graceful fallback:

```text
unknown icon key
      ↓
standard tag fallback
```

Preserve the original icon key in storage unless the user explicitly changes it.

Do not silently overwrite user data merely because the renderer cannot resolve an icon.

---

# 11. Full Phosphor Catalog

The tag picker must expose the complete catalog available from the chosen Phosphor version.

Do not manually enumerate a small subset.

Do not create 50 demo icons and claim full support.

Build a reproducible catalog-generation process.

The repository should contain whatever source/generation tooling is necessary so that the catalog can be regenerated when the Phosphor version is upgraded.

---

# 12. Build-Time Catalog Generation

Implement a deterministic build-time generation process.

The process should:

1. obtain the pinned Phosphor icon source/version
2. enumerate the complete supported icon set
3. extract stable icon identifiers
4. extract vector/path data required for rendering
5. extract useful metadata
6. normalize the data
7. generate a compact local catalog
8. optionally compress it
9. generate an index optimized for search

Do not require manual editing of thousands of entries.

The generation process must be reproducible.

Pin the exact Phosphor version used by the application.

Do not silently consume “latest” during normal builds.

---

# 13. Catalog Metadata

Each catalog entry should contain only the metadata required for the product.

At minimum:

```text
id
displayName
searchTerms / aliases
category
vector data
```

Do not include unnecessary source metadata that inflates the application bundle.

Example conceptual entry:

```json
{
  "id": "camera",
  "name": "Camera",
  "category": "Media",
  "aliases": ["photo", "photograph", "capture"],
  "paths": "..."
}
```

Adapt the actual vector representation to the chosen renderer.

---

# 14. Compact Vector Representation

Do not package thousands of SVG files separately unless there is a concrete measured reason.

Prefer a compact catalog representation such as:

- normalized SVG path data
- compact vector commands
- generated path definitions
- compressed JSON/binary catalog

The catalog should be optimized for:

- APK/AAB size
- parsing speed
- low memory
- fast icon lookup

Do not optimize prematurely.

Measure the actual resulting release sizes.

---

# 15. Catalog Compression

If appropriate, compress the catalog as a local resource.

For example:

```text
phosphor_catalog.json.gz
```

or another format that is well-supported in the Flutter application.

At runtime:

```text
compressed catalog
      ↓
lazy load
      ↓
decode/index
      ↓
memory cache
```

Do not decompress the entire catalog on application startup.

---

# 16. Lazy Loading

The application should not pay the full runtime parsing cost for the icon catalog just because it launched.

Load the full tag catalog only when needed.

Recommended:

```text
App starts
↓
No catalog loaded

User opens Choose Icon
↓
Load catalog

User closes picker
↓
Catalog remains cached if inexpensive,
otherwise release according to memory policy
```

Do not block application startup on icon catalog loading.

---

# 17. Search Index

Build an efficient local search index for icons.

Search should operate on:

- icon name
- normalized name
- aliases
- search keywords

Examples:

Searching:

```text
camera
```

should find:

```text
Camera
Camera Slash
Camera Plus
Camera Rotate
...
```

Searching:

```text
book
```

should find:

```text
Book
Book Open
Books
Bookmark
Notebook
...
```

Searching:

```text
photo
```

should find relevant camera/image icons through aliases.

---

# 18. Search Normalization

Normalize icon queries consistently.

Support:

- case-insensitive search
- whitespace normalization
- punctuation normalization
- prefix search
- substring search
- aliases

Search:

```text
book open
```

should match:

```text
Book Open
```

Search:

```text
bookopen
```

may also match if practical.

Do not introduce an unnecessarily expensive fuzzy-search implementation if straightforward token/prefix matching is sufficient.

---

# 19. Search Ranking

Use sensible ranking:

1. exact icon name
2. exact normalized name
3. name prefix
4. token prefix
5. name substring
6. alias match
7. category relevance

Keep results deterministic.

Do not randomly reorder results.

---

# 20. Categories

Create a useful Quiet Paper-facing category system.

Do not blindly expose internal source taxonomy if it is too fragmented.

Use practical categories such as:

- Activity
- Arrows
- Brands
- Buildings
- Communication
- Design
- Development
- Education
- Files
- Finance
- Food
- Health
- Maps
- Media
- Nature
- Objects
- People
- Places
- Science
- Security
- Shapes
- System
- Technology
- Transportation
- Weather

Adapt categories to the actual Phosphor catalog.

Every catalog icon should belong to one or more useful categories where practical.

---

# 21. “All Icons”

The picker must always provide:

```text
ALL
```

showing the entire catalog.

Do not impose artificial limits.

Use virtualization/lazy rendering so the full catalog can be browsed without instantiating thousands of widgets.

---

# 22. Virtualized Icon Grid

This is mandatory.

Do NOT create:

```dart
children: allIcons.map(...).toList()
```

for thousands of entries if that causes all widgets to be constructed.

Use an appropriate lazy/virtualized grid.

Conceptually:

```text
filtered catalog
      ↓
GridView.builder / equivalent
      ↓
only visible icons rendered
```

The picker must remain responsive while scrolling through the entire catalog.

---

# 23. Tag Icon Picker UX

Design it as a premium Quiet Paper surface.

Do not use a giant generic Material dialog.

Recommended structure:

```text
┌──────────────────────────────────┐
│ Choose icon                       │
│                                   │
│ 🔎 Search icons…                  │
│                                   │
│ Recent   Favorites   All          │
│                                   │
│ Activity                          │
│                                   │
│  ◇   ◇   ◇   ◇   ◇   ◇          │
│  ◇   ◇   ◇   ◇   ◇   ◇          │
│  ◇   ◇   ◇   ◇   ◇   ◇          │
│                                   │
└──────────────────────────────────┘
```

Use Quiet Paper's existing:

- paper surfaces
- typography
- spacing
- border radius
- semantic colors
- theme tokens

Do not invent a new visual system.

---

# 24. Search State

When searching:

```text
Search: camera
```

the category browser should transition naturally into search results.

Do not force the user through another screen.

Clear search:

→ restore the previous category/results context.

Do not unnecessarily reset the user's picker state.

---

# 25. Recent Icons

Implement local “Recently Used” icons.

Store recent icon IDs locally using the project's existing preferences infrastructure.

Recommended:

```text
8–12 most recent icons
```

Deduplicate them.

When an icon is chosen:

- move it to the front
- remove duplicate occurrence
- cap the list

This does not need cloud synchronization.

---

# 26. Favorites

Implement icon favorites.

Users should be able to mark an icon as a favorite.

Recommended interactions:

- long press
- context action
- secondary favorite button

Show:

```text
Favorites
```

as a filter/tab.

Store only stable icon IDs locally.

Do not store icon vector data in preferences.

---

# 27. Long Press

Long-pressing an icon may provide:

```text
Add to Favorites
```

or:

```text
Remove from Favorites
```

Keep the interaction compact.

Do not open a large context menu for trivial actions.

---

# 28. Category Navigation

Category selection should update the grid immediately.

Use a horizontally scrollable category selector or another compact control appropriate for the current device.

On small screens:

- avoid a massive permanent category rail
- allow horizontal scrolling
- keep the search field accessible

On tablets:

- use available width intelligently
- don't inflate icon sizes excessively

---

# 29. Icon Size

Icons should be large enough to identify comfortably.

Picker grid:

approximately:

```text
32–40dp visual icon
```

inside an accessible touch target.

Do not make the actual visual glyph fill the entire touch target.

Maintain breathing room.

---

# 30. Selection State

When an icon is selected:

- use a subtle Quiet Paper selected treatment
- show a clear check/selection state
- do not rely solely on color

The selected icon should remain visually stable when the picker scrolls.

---

# 31. Current Tag Icon

When editing a tag that already has an icon:

show the current icon clearly at the top of the picker.

Allow:

```text
Change icon
Remove icon
```

Do not require the user to scroll through the catalog to remove it.

---

# 32. Remove Icon

Provide a simple:

```text
Remove icon
```

action.

This should set:

```text
icon_key = null
```

and preserve the rest of the tag.

Do not delete the tag.

Do not modify notes associated with the tag.

---

# 33. Tag Editor Integration

Integrate the picker into the existing tag creation/edit flow.

The user should be able to:

1. create tag
2. choose icon
3. save tag

and:

1. edit tag
2. change icon
3. save

Changes must persist immediately according to the existing tag lifecycle.

Do not create a parallel tag editing system.

---

# 34. Sidebar Integration

Where tags are displayed in the Quiet Paper sidebar:

if a tag has an icon, render it.

Example:

```text
◇ Reading
◇ Mathematics
◇ Projects
```

Use the same icon resolver as the picker.

Do not create a separate sidebar icon mapping.

---

# 35. Tag List Integration

Where tag chips/rows/cards are shown elsewhere:

use the same icon resolution logic.

The same tag must always resolve its icon consistently.

Avoid one part of the app using Regular and another using a completely different interpretation unless explicitly required by the design system.

---

# 36. Tag Detail / Pinned Tag Integration

If the existing pinned-tags feature displays tags with icons:

- integrate icon rendering there too
- preserve pinned behavior
- preserve tag counts
- preserve ordering

Changing an icon must never affect pin state.

---

# 37. App UI Migration

Begin migrating existing application icons to Phosphor.

Prioritize:

- note creation
- search
- pin
- archive
- trash
- tags
- links
- backlinks
- attachments
- scanner
- crop
- rotate
- OCR
- sync
- backups
- settings
- export
- navigation

Do not blindly replace every icon one-for-one if a Phosphor metaphor is poor.

Choose the closest semantic Phosphor icon.

Do not retain Material icons merely because replacement is inconvenient.

---

# 38. Icon Semantics

Some actions should use intentionally different metaphors.

Examples:

### Scan

Use a document-scanning/page-corner concept rather than generic camera where appropriate.

### Note

Use a notebook/page concept.

### Link

Use Phosphor's link/reference metaphor.

### Backlink

Use an appropriate returning/arrow relationship icon rather than a duplicate generic chain symbol.

### Settings

Use the closest subtle settings/control icon.

### Tag

Use the most semantically appropriate Phosphor tag/hash representation.

Do not introduce icons merely for decoration.

---

# 39. Consistent Weight Rules

Create a central icon rendering policy.

For example:

```text
QuietIconWeight.regular
QuietIconWeight.light
QuietIconWeight.fill
```

Then application surfaces can use consistent choices.

Do not scatter:

```dart
PhosphorIcons.xxx(PhosphorIcons.yyy...)
```

with arbitrary weight decisions everywhere.

---

# 40. Theme Integration

Icon colors must use existing semantic theme colors.

Do not hard-code:

```dart
Colors.black
Colors.white
Colors.blue
```

Use current Quiet Paper color/theme APIs.

Verify:

- Classic Paper Light
- Classic Paper Dark
- Warm Paper Light
- Warm Paper Dark
- System appearance

all render correctly.

---

# 41. Tag Icon Color

Do not store custom per-tag icon colors in V1.

The icon should inherit the current UI semantic foreground/accent treatment.

This keeps tag appearance:

- theme-aware
- consistent
- simple

The tag icon identity and icon color remain separate concerns.

---

# 42. Accessibility

Every icon picker item must have an accessible name.

Example:

```text
Camera
Heart
Book Open
Map Pin
```

Do not expose raw IDs like:

```text
phosphor:camera
```

to screen readers.

The selected state must be announced meaningfully.

Example:

```text
Camera, selected
```

Long-press/favorite actions must also be accessible through non-gesture means.

---

# 43. Keyboard Navigation

On desktop/tablet with hardware keyboard, support:

- arrow navigation
- enter/select
- escape/close
- tab traversal where appropriate

Typing while the picker is open should focus search naturally.

Do not trap the keyboard unexpectedly.

---

# 44. Picker Performance

The following must remain responsive:

- opening picker
- typing search
- changing category
- scrolling grid
- selecting icon
- opening Favorites
- opening Recent

Do not parse/rebuild the entire catalog on every keystroke.

Load/index once.

Filter against a preprocessed searchable representation.

Only visible grid cells should render icon vectors.

---

# 45. Caching Strategy

Use bounded caching.

Recommended:

```text
Catalog cache
    stable for session

Rendered icon cache
    only if needed
    bounded size
```

Do not cache every rendered icon bitmap indefinitely.

Prefer vector rendering if it is efficient.

If raster caching materially improves performance:

- use a bounded LRU
- establish memory limits
- evict safely

Do not create an unbounded cache.

---

# 46. Memory Requirements

The full catalog being available does NOT mean:

> every icon must be rendered and retained in memory.

The design must distinguish:

```text
catalog metadata/path data
```

from:

```text
live rendered widgets
```

and:

```text
decoded raster images
```

Only the minimum necessary runtime state should be retained.

---

# 47. App Startup

Adding the full icon catalog must not cause:

- noticeable startup delay
- large synchronous parsing operation on the UI thread
- excessive initial memory allocation

The catalog must load lazily.

If parsing is expensive:

- move work off the UI isolate
- cache the indexed representation for the session
- avoid reparsing

---

# 48. Build Size Measurement

Before implementation, measure:

```text
baseline release APK/AAB size
```

After implementation measure:

```text
with icon catalog
```

Document:

- raw catalog size
- compressed catalog size
- APK/AAB delta
- approximate installed/runtime memory impact if measurable

Do not claim the catalog is “small” without measuring.

---

# 49. Optimize Based on Measurement

If catalog size is unexpectedly large:

investigate in this order:

1. remove unnecessary metadata
2. remove unused weights from the tag catalog
3. compress path data/catalog
4. use a more compact vector representation
5. deduplicate shared data if applicable

Do NOT solve size problems by removing icons from the user-facing catalog.

The requirement is that the entire Phosphor catalog remains available.

---

# 50. Tag Catalog Weight Policy

For the full user-facing tag catalog, bundle a single canonical rendering weight initially:

```text
Regular
```

unless the chosen Phosphor integration makes another representation materially smaller without compromising the catalog.

The picker must provide all icon identities, not every visual weight variant.

The user chooses:

```text
Camera
```

not:

```text
Camera Thin
Camera Light
Camera Regular
Camera Bold
Camera Fill
Camera Duotone
```

This keeps the picker simple and reduces storage.

---

# 51. Future-Proof Icon Keys

Use a namespaced stable key:

```text
phosphor:<icon-id>
```

Examples:

```text
phosphor:heart
phosphor:camera
phosphor:book-open
```

This makes future migrations possible.

Do not depend directly on Dart class names generated by the current Phosphor Flutter package.

---

# 52. Phosphor Version Pinning

Pin a specific Phosphor version.

Record it in the project/build metadata.

The catalog must correspond exactly to the pinned version.

When updating the icon library later:

- regenerate catalog
- run migration/compatibility checks
- verify existing stored icon IDs
- ensure removed/renamed icons have graceful fallbacks

Do not update icon source silently.

---

# 53. Catalog Regeneration Validation

The generation script must fail loudly when:

- duplicate IDs are generated
- malformed vector data appears
- required fields are missing
- icon IDs are invalid
- generated catalog is empty
- category mapping is invalid

Do not silently produce a partial catalog.

---

# 54. Integrity Check

Generate a catalog manifest containing enough information to verify the packaged catalog corresponds to the expected source.

For example:

```text
Phosphor version
catalog version
icon count
catalog SHA-256
```

Do not use this for security decisions; it is for build integrity/reproducibility.

---

# 55. Catalog Count

After generation, record the exact number of icons discovered.

The application should be able to expose this in development/debug diagnostics.

Do not hard-code an assumed icon count from memory.

The build process itself should determine it.

---

# 56. Testing — Catalog

Add tests verifying:

- catalog loads successfully
- catalog is non-empty
- every ID is unique
- every icon has required metadata
- vector data is valid enough to render
- search index contains every icon
- category index contains expected entries
- `phosphor:` namespace resolves correctly

---

# 57. Testing — Resolver

Test:

```text
phosphor:heart
phosphor:camera
phosphor:book-open
```

and:

```text
phosphor:does-not-exist
unknown:heart
malformed
null
empty
```

Unknown values must never crash.

---

# 58. Testing — Tag Persistence

Test:

1. create tag
2. assign icon
3. save
4. reload database
5. verify icon key remains
6. display tag
7. change icon
8. verify new icon persists
9. remove icon
10. verify null state

---

# 59. Testing — Picker Search

Test:

```text
camera
book
arrow
heart
```

and verify expected icons occur.

Test case-insensitivity.

Test no-result query.

Test category filtering.

Test clearing query.

Test long query.

---

# 60. Testing — Recents

Test:

- selecting icon adds to recents
- selecting same icon again moves it to front
- duplicates are removed
- maximum count is enforced
- invalid/stale IDs are handled gracefully

---

# 61. Testing — Favorites

Test:

- add favorite
- remove favorite
- persistence across app restart
- invalid icon ID handling
- duplicate prevention

---

# 62. Testing — Virtualization

Add widget/instrumentation tests where practical to verify the picker does not eagerly instantiate the entire catalog.

If the framework makes exact widget-count verification impractical, validate the underlying lazy builder architecture and use performance/profile testing.

---

# 63. Testing — Navigation/Tag Integration

Verify that changing an icon does not affect:

- tag ID
- tag name
- note associations
- pinned state
- sort order
- note counts

Only the tag presentation icon changes.

---

# 64. Testing — Themes

Verify representative icons across every existing theme family and appearance.

Check:

- contrast
- selected state
- disabled state
- picker background
- category text
- search field
- favorite state

No hard-coded light/dark assumptions.

---

# 65. Testing — Accessibility

Verify:

- icon names are exposed
- selected state is exposed
- remove icon action is labeled
- favorite action is accessible
- search field is accessible
- keyboard navigation works where applicable

---

# 66. Testing — Migration

Test existing databases with no icon information.

Verify:

- migration succeeds
- all existing tags remain
- no notes lose tag relationships
- icon field is null
- no unrelated schema changes occur

---

# 67. Testing — Build

Run the relevant production build path.

At minimum:

```bash
flutter analyze
flutter test
flutter build apk --release
```

Also run any required code generation.

If the project has additional release/build verification, run it.

---

# 68. No Runtime CDN

Explicitly verify through code review that the production app does not perform an HTTP request to obtain tag icons.

The tag icon picker must work in airplane mode.

Test this manually or through an appropriate integration test.

---

# 69. Offline Test

Test:

1. disable network
2. launch Quiet Paper
3. open tag icon picker
4. search icon
5. choose icon
6. save tag
7. close/reopen tag
8. verify icon renders

The entire flow must work without internet access.

---

# 70. Icon Picker State Restoration

Where platform behavior allows:

if the keyboard causes the picker to resize/re-layout:

- search text must not disappear
- category selection must not unexpectedly reset
- selected icon must remain stable

Handle:

- orientation changes
- tablet/phone resizing
- keyboard appearance/disappearance

without corrupting picker state.

---

# 71. Search Result Stability

During rapid typing:

```text
c
ca
cam
came
camera
```

older searches must not overwrite newer results.

Use a generation token or equivalent if asynchronous search/indexing is involved.

The visible result set must always correspond to the latest query.

---

# 72. Performance Instrumentation

Add development-only metrics for:

- catalog load time
- catalog parse time
- search latency
- first-grid-render latency
- icon render latency if measurable
- memory usage if practical
- catalog size

Do not log user content.

These metrics should help catch regressions.

---

# 73. Error Handling

If the catalog fails to load:

do not crash Quiet Paper.

The tag picker should show a clear recoverable state such as:

```text
Icons unavailable

Try again
```

while keeping the rest of tag functionality usable.

If an individual icon fails to render:

- show fallback tag/icon behavior
- do not crash the entire grid

---

# 74. Graceful Catalog Version Upgrade

When the app receives a newer catalog:

existing tag icon keys should continue resolving where IDs remain stable.

For removed icons:

```text
old icon ID
↓
unavailable
↓
fallback rendering
```

Do not automatically rewrite all affected tags.

Provide a deterministic compatibility layer if aliases/renames are known.

---

# 75. Avoid Unnecessary Dependencies

Do not add multiple overlapping icon/rendering packages.

Use the smallest set of dependencies necessary for:

- Phosphor application icons
- local vector catalog rendering
- catalog generation

Any new dependency must have a concrete technical reason.

---

# 76. Code Organization

Keep responsibilities separated.

Conceptually:

```text
icons/
  domain/
    icon_definition
    icon_category

  application/
    icon_registry
    icon_catalog_service
    icon_search_service
    icon_recents_service
    icon_favorites_service

  presentation/
    icon_picker
    icon_grid
    icon_search_field
    icon_category_selector
```

Adapt this to the existing Quiet Paper architecture.

Do not create unnecessary abstractions solely to match this example.

---

# 77. Generated Assets

Generated catalog files must:

- have deterministic output
- be excluded from hand-maintained source where appropriate
- have clear generation instructions
- not contain unnecessary debug metadata

Do not manually edit generated catalog files.

---

# 78. Source License/Attribution

Verify the current Phosphor license requirements from the exact version being used.

Include any required attribution/license notices in the appropriate project/legal location.

Do not copy external icon source without respecting its license.

The build should retain the necessary third-party attribution.

---

# 79. Documentation

Add concise developer documentation covering:

- pinned Phosphor version
- how to regenerate the catalog
- generated file location
- icon-key format
- tag database representation
- rendering approach
- lazy loading
- search/index architecture
- how to update Phosphor safely

Do not write vague documentation.

A new developer should be able to regenerate the catalog without reverse-engineering the system.

---

# 80. Final User Experience

A user should be able to open tag editing and see:

```text
Choose icon

Search icons…

RECENT
♡   📚   ☕   ◆

FAVORITES
★   ◇   ✦

ALL

ACTIVITY
○ ○ ○ ○ ○ ○

ARROWS
→ ↑ ↗ ↘ ↩ …

BOOKS / FILES
...
```

They should be able to search:

```text
camera
```

and immediately browse the complete relevant set.

They should be able to long-press:

```text
Camera
```

and add it to Favorites.

They should be able to assign it to:

```text
#photography
```

and then see the same Phosphor icon everywhere that tag appears.

All of it must work offline.

---

# 81. Final Acceptance Criteria

The implementation is complete only when:

- [ ] Phosphor is the canonical icon system for new Quiet Paper UI work.
- [ ] Existing relevant UI icons are migrated appropriately.
- [ ] Tag icons use stable `phosphor:<id>` keys.
- [ ] Tag icon state is persisted in SQLite.
- [ ] Existing tags migrate safely.
- [ ] Unknown icon IDs never crash.
- [ ] The complete catalog for the pinned Phosphor version is available locally.
- [ ] Catalog generation is reproducible.
- [ ] Catalog is compact and optimized.
- [ ] Catalog does not require runtime internet access.
- [ ] Catalog is loaded lazily.
- [ ] Catalog is not parsed synchronously during app startup.
- [ ] Picker uses virtualized/lazy icon rendering.
- [ ] Search is local.
- [ ] Search is fast.
- [ ] Search supports names and useful aliases.
- [ ] Categories work.
- [ ] All Icons view works.
- [ ] Recent Icons works.
- [ ] Favorites works.
- [ ] Current tag icon is shown.
- [ ] Remove icon works.
- [ ] Tag create/edit flow works.
- [ ] Sidebar/tag surfaces display assigned icons.
- [ ] Icon colors are theme-aware.
- [ ] Light themes work.
- [ ] Dark themes work.
- [ ] Phone layout works.
- [ ] Tablet layout works.
- [ ] Accessibility labels exist.
- [ ] Keyboard navigation works where applicable.
- [ ] Rapid search does not show stale results.
- [ ] Picker remains responsive with the full catalog.
- [ ] Offline mode works completely.
- [ ] No runtime CDN/network icon fetching exists.
- [ ] Icon data is not stored in SQLite.
- [ ] Icon array indexes are never used as persistent identifiers.
- [ ] App startup performance remains unaffected.
- [ ] Release bundle size has been measured before/after.
- [ ] Catalog size has been measured.
- [ ] Memory behavior has been considered/measured.
- [ ] Required Phosphor attribution/license requirements are satisfied.
- [ ] Tests cover resolver, catalog, search, persistence, favorites, recents, migrations, themes, and picker behavior.
- [ ] `flutter analyze` passes with zero issues.
- [ ] `flutter test` passes completely.
- [ ] Release build succeeds.
- [ ] No TODOs/placeholders remain.

---

# 82. Required Final Verification Report

At the end of the implementation, report:

### Phosphor version

Exact pinned version.

### Catalog

Exact number of icons packaged.

### Catalog representation

Explain whether it uses:

- generated vector data
- compressed JSON
- another format

and why.

### Bundle impact

Report:

```text
Before
After
Delta
```

for release APK/AAB where measurable.

### Runtime

Report approximate:

- catalog load time
- first picker render time
- search latency
- memory characteristics

where measurable.

### Tag storage

Explain the persisted icon-key format.

### Migration

Explain database migration behavior.

### UI migration

Summarize major application surfaces converted to Phosphor.

### Tests

Report:

```text
flutter analyze
flutter test
flutter build apk --release
```

results.

### Known limitations

Only mention genuine limitations discovered during implementation.

Do not claim success without actual verification.

---

# Final Product Principle

Quiet Paper should not feel like an app that happens to use Phosphor.

It should feel like it has a **single, deliberate visual language**.

The user should be able to choose almost any Phosphor icon they can imagine for a tag, without waiting for downloads, without navigating an ugly icon browser, and without the application becoming bloated with thousands of individually rendered assets.

The architecture should therefore be:

```text
                    PHOSPHOR
                       │
              pinned source version
                       │
                build-time generator
                       │
             compact local catalog
                       │
                  lazy loader
                       │
              ┌────────┴────────┐
              │                 │
         Icon Registry      Icon Picker
              │                 │
        app UI rendering   search/categories
                                │
                        recent/favorites
                                │
                         virtualized grid
                                │
                              select
                                │
                                ▼
                     "phosphor:camera"
                                │
                                ▼
                             Tag DB
```

The icon catalog is **available to the user**, but the application only renders what is actually visible or needed.

The system must remain offline-first, performant, theme-aware, accessible, and maintainable.