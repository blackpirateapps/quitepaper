# Quiet Paper — Production Theme Engine Refactor + New Warm Paper Theme

## ROLE

You are the lead Flutter architect working on Quiet Paper, a production-grade Bear-style notes application.

Implement a complete, maintainable, extensible theme engine and add a new theme family called:

    Warm Paper

with:

    Warm Paper Light
    Midnight Paper Dark

The application already has:

    - System Default
    - Light Paper
    - Dark Paper

The existing visual appearance of those themes must be preserved exactly.

Do NOT redesign, approximate, simplify, or replace the existing Classic Paper appearance.

This task is a theme architecture refactor plus the addition of the new Warm Paper family.

The implementation must be production-ready, fully integrated, testable, persistent, responsive, and free of placeholders.

--------------------------------------------------
## 1. CURRENT PRODUCT MODEL
--------------------------------------------------

Quiet Paper is a Flutter note-taking application with:

- Bear-style 3-pane navigation/layout
- Markdown-based editor
- Markdown preview mode
- Canonical Markdown storage
- No canonical JSON document representation
- Rich Markdown rendering
- Code blocks
- Planned/implemented syntax highlighting
- Search
- Tags
- Pinned notes
- Archive
- Trash
- Attachments
- Cloudinary-backed media
- OCR/document support
- Sync
- Password-protected notes
- Various settings/preferences
- Custom scrolling behavior
- Intelligent scrollbar / heading navigation being introduced

The theme implementation must work across the entire product, not only the editor.

--------------------------------------------------
## 2. REQUIRED SETTINGS MODEL
--------------------------------------------------

Separate:

A) Theme Family

from:

B) Appearance Mode

The conceptual model must be:

Theme Family:
    - Classic Paper
    - Warm Paper

Appearance:
    - System
    - Light
    - Dark

Do NOT model System as a separate theme.

Do NOT create separate top-level themes such as:

    - System Default
    - Light Paper
    - Dark Paper
    - Warm Paper
    - Midnight Paper

Instead:

    themeFamily = classicPaper | warmPaper
    appearance = system | light | dark

Resolution rules:

Classic Paper + Light
    -> existing Light Paper appearance

Classic Paper + Dark
    -> existing Dark Paper appearance

Classic Paper + System
    -> existing Light Paper or Dark Paper based on OS appearance

Warm Paper + Light
    -> Warm Paper Light

Warm Paper + Dark
    -> Midnight Paper

Warm Paper + System
    -> Warm Paper Light or Midnight Paper based on OS appearance

The resolved theme must update reactively when:

- Theme family changes
- Appearance changes
- System brightness changes while Appearance = System

Do not require an app restart.

--------------------------------------------------
## 3. EXISTING THEME PRESERVATION
--------------------------------------------------

This is a hard requirement.

The existing Classic Paper visual appearance must remain unchanged.

Before modifying the implementation:

1. Inspect the entire existing theme system.
2. Identify every current theme color and semantic usage.
3. Identify hardcoded color literals throughout the UI.
4. Determine which existing colors belong to:
   - background
   - surfaces
   - borders
   - text
   - icons
   - interactive states
   - editor
   - preview
   - code blocks
   - syntax highlighting
   - scrollbar
   - selections
   - search highlighting
   - tags
   - buttons
   - dialogs
   - bottom sheets
   - snackbars
   - menus
   - settings
   - sidebars
   - note lists
   - attachments
   - OCR/document UI
   - trash
   - archive
   - empty states
   - error states
   - loading states

Refactor them into semantic theme tokens.

Do not alter the existing Classic Paper token values.

The user's current Classic Paper experience should be visually indistinguishable before and after this implementation.

--------------------------------------------------
## 4. NEW THEME PALETTE
--------------------------------------------------

Implement the following exact Warm Paper / Midnight Paper palette.

Do NOT substitute nearby colors.

Do NOT "improve" these colors.

Do NOT use generated shades.

Use these exact values as the canonical source palette.

### WARM PAPER — LIGHT

Background:
    #F2F1EE

Primary surface:
    #FFFFFF

Secondary surface:
    #FBFAF8

Subtle surface:
    #F5F4F1

Borders / dividers:
    #E5E3DF

Primary text:
    #202124

Secondary text:
    #414141

Muted text:
    #777777

Disabled / subtle text:
    #9A9994

Scrollbar:
    #9DA1AA

Scrollbar active:
    #60646D

Accent:
    #666BD3

Accent light:
    #D8DAFF

Sidebar:
    #202329

Sidebar selected surface:
    #353A43

### MIDNIGHT PAPER — DARK

Background:
    #11151A

Primary surface:
    #171C22

Secondary surface:
    #1D232B

Subtle surface:
    #222932

Borders / dividers:
    #303741

Primary text:
    #F1F2F4

Secondary text:
    #C5C8CE

Muted text:
    #8D939D

Scrollbar:
    #777D88

Scrollbar active:
    #A99AFF

Accent:
    #8570E8

Accent light:
    #A99AFF

Sidebar:
    #11151A

Sidebar selected surface:
    #1F2630

Do not arbitrarily change the palette.

--------------------------------------------------
## 5. SEMANTIC COLOR SYSTEM
--------------------------------------------------

Do NOT expose raw palette colors directly throughout widgets.

Create a semantic color layer.

At minimum define semantic tokens equivalent to:

- background
- surface
- surfaceSecondary
- surfaceSubtle
- surfaceElevated
- border
- borderSubtle
- textPrimary
- textSecondary
- textMuted
- textDisabled
- iconPrimary
- iconSecondary
- iconMuted
- accent
- accentLight
- accentStrong
- selection
- focus
- scrollbar
- scrollbarActive
- sidebarBackground
- sidebarSelected
- editorBackground
- previewBackground
- codeBackground
- codeBorder
- codeText
- link
- searchHighlight
- searchHighlightActive
- success
- warning
- error
- info

The exact existing Classic Paper values must populate the Classic Paper semantic token set.

Warm Paper and Midnight Paper must populate the same token structure.

Every widget must consume semantic tokens rather than palette literals.

--------------------------------------------------
## 6. MATERIAL / FLUTTER THEME INTEGRATION
--------------------------------------------------

Use Flutter's theme system appropriately.

Prefer:

- ThemeData
- ColorScheme
- ThemeExtension

where appropriate.

Do not abuse ColorScheme by forcing unrelated visual concepts into existing Material roles.

Create a dedicated application-level theme extension for Quiet Paper-specific semantics.

Example conceptual structure:

    QuietPaperThemeExtension

with all app-specific semantic values.

Use Theme.of(context) / Theme extensions rather than importing static palette values directly into widgets.

Theme resolution must happen centrally.

Do not scatter theme-family / appearance checks throughout the UI.

Bad:

    if (isWarmPaper) ...

inside dozens of widgets.

Good:

    final colors = context.quietPaperTheme;

and the widget simply consumes semantic colors.

--------------------------------------------------
## 7. THEME RESOLUTION ARCHITECTURE
--------------------------------------------------

Create a central theme resolver.

Conceptually:

    ThemeFamily
        classicPaper
        warmPaper

    AppearanceMode
        system
        light
        dark

    ResolvedTheme
        classicPaperLight
        classicPaperDark
        warmPaperLight
        midnightPaper

The resolver is responsible for selecting the final ThemeData / ThemeExtension.

The rest of the application must not need to understand the resolution logic.

When:

    appearance == system

the resolver must react to Flutter's platform brightness.

Do not manually query platform brightness in individual widgets.

--------------------------------------------------
## 8. PERSISTENCE + MIGRATION
--------------------------------------------------

Inspect the application's existing settings/preferences architecture.

Extend the existing persistence mechanism instead of creating a parallel settings store.

Persist:

    themeFamily
    appearanceMode

Use stable serialized values.

Example:

    classic_paper
    warm_paper

and:

    system
    light
    dark

Do not persist resolved theme values.

Do not persist raw colors.

Handle migration from the existing theme preference implementation.

This migration must preserve the user's current visual choice.

For example, if the existing app currently stores:

    system
    light
    dark

then map those existing values to:

    themeFamily = classicPaper
    appearance = corresponding existing value

Do not silently reset existing users to a new theme.

If the existing storage format is different, inspect it and implement a safe migration.

The migration must be idempotent.

--------------------------------------------------
## 9. SETTINGS UI
--------------------------------------------------

Update the settings UI to reflect the new architecture.

Create:

### Theme

Theme family picker:

    Classic Paper
    Warm Paper

### Appearance

Three-state segmented control / selector:

    System
    Light
    Dark

Do not present five unrelated theme options.

The selected theme family and appearance mode must be independently changeable.

Theme previews in Settings should visually demonstrate the real palette.

Do not build fake preview colors separate from the actual theme definitions.

The preview must be generated from the same theme tokens used by the application.

Theme changes must apply immediately.

No restart.

No navigation reset.

No note loss.

No editor state loss.

--------------------------------------------------
## 10. FULL APPLICATION COVERAGE
--------------------------------------------------

This theme engine must be applied across the entire application.

Audit and update all UI components.

At minimum:

### Global
- App background
- Navigation surfaces
- App bars
- system-safe surfaces
- dividers
- overlays
- modal backgrounds

### 3-pane layout
- sidebar
- sidebar selected item
- note list
- selected note
- editor pane
- preview pane

### Sidebar
- labels
- icons
- active navigation
- hover state
- pressed state
- notebook sections
- counts
- separators

### Note list
- note title
- preview text
- timestamps
- selected state
- hover state
- context menus
- empty states
- pinned indicators

### Editor
- editor background
- text
- cursor
- selection
- active line if applicable
- placeholder
- toolbar
- buttons
- toolbar icons
- markdown syntax UI
- links
- checkboxes
- inline code
- blockquotes
- horizontal rules

### Preview
- background
- heading text
- body text
- links
- lists
- tables
- blockquotes
- code blocks
- images / attachment cards
- separators

### Search
- search field
- result cards
- result text
- matched text
- active match
- search loading state
- no-results state

### Tags
- tag pills
- tag pages
- tag selection
- tag browser
- pinned tags
- counts

### Trash
- trash rows
- warning states
- restore action
- permanent delete action
- confirmation dialogs

### Archive
- archived note rows
- archive controls

### Attachments
- attachment cards
- previews
- download/open buttons
- document viewer surfaces

### OCR
- OCR status
- scan/document UI
- text extraction state
- document pages
- errors

### Sync
- synchronization indicators
- sync status
- retry state
- conflict state
- conflict resolution UI

### Dialogs
- dialogs
- confirmation dialogs
- alert dialogs
- bottom sheets
- popovers
- menus

### Feedback
- snackbars
- toasts
- loading indicators
- error banners
- success messages
- warnings

### Settings
- sections
- rows
- switches
- segmented controls
- dropdowns
- buttons
- previews

Nothing should remain visibly tied to the old palette when Warm Paper is selected.

--------------------------------------------------
## 11. NO HARDCODED COLORS
--------------------------------------------------

Perform a repository-wide audit for UI color literals.

Search for:

- Color(...)
- Colors.*
- hex literals
- ARGB literals
- opacity-based hardcoded colors
- hardcoded decoration colors
- hardcoded text colors
- hardcoded icon colors
- hardcoded border colors
- hardcoded selection colors
- hardcoded shadows where theme-sensitive
- hardcoded canvas/background colors

Replace theme-sensitive UI colors with semantic theme tokens.

Do not blindly replace legitimate non-theme colors such as:

- image pixel colors
- chart data colors when intentionally data-defined
- syntax token palettes when routed through the syntax theme
- third-party SDK rendering values
- actual document/content colors
- platform-required colors

However, explicitly audit every occurrence and decide whether it should be themed.

There must be no accidental light-theme white surfaces or dark-theme black surfaces remaining after switching themes.

--------------------------------------------------
## 12. EDITOR + PREVIEW THEMING
--------------------------------------------------

The Markdown editor and preview must share the application's resolved theme.

Do not give them independent hardcoded palettes.

Editor:

- text color
- cursor color
- selection color
- placeholder color
- heading colors
- link color
- inline code
- code block background
- code block border
- blockquote marker
- checkbox appearance
- toolbar

Preview:

- body text
- heading hierarchy
- link
- code
- blockquote
- table
- separators
- metadata

The visual relationship between editor and preview should remain consistent.

--------------------------------------------------
## 13. SYNTAX HIGHLIGHTING
--------------------------------------------------

Integrate syntax highlighting into the theme architecture.

Do NOT hardcode syntax colors independently inside individual code block renderers.

Create a semantic syntax-highlighting palette.

At minimum support:

- keyword
- string
- number
- comment
- function
- class/type
- variable
- property
- operator
- punctuation
- constant
- annotation
- tag / markup

Syntax highlighting must have theme-specific palettes.

The Warm Paper palette should be restrained and editorial.

Do not create a rainbow-like developer-tool appearance.

Warm Paper should use muted colors harmonious with:

    #666BD3

Midnight Paper should use brighter versions with sufficient contrast against:

    #11151A
    #171C22
    #1D232B

Syntax highlighting must automatically switch when the app theme changes.

No restart.

No manual "syntax theme" selector is required for this task.

The syntax theme is derived from the active Quiet Paper theme.

If an existing syntax highlighter/library is already present:

- preserve its parsing/tokenization architecture
- replace only the visual theme integration
- do not unnecessarily rewrite syntax parsing

If syntax highlighting is already implemented elsewhere in the codebase, consolidate its color decisions into the theme engine.

--------------------------------------------------
## 14. INTELLIGENT SCROLLBAR THEMING
--------------------------------------------------

The intelligent scrollbar being developed for long notes must also use the active theme.

For Warm Paper:

Scrollbar:
    #9DA1AA

Active scrollbar:
    #60646D

Current heading:
    #666BD3

Heading text:
    semantic muted / secondary text

Heading gradient:
    derived from the current surface/background, NOT a fixed white overlay

For Midnight Paper:

Scrollbar:
    #777D88

Active scrollbar:
    #A99AFF

Current heading:
    #A99AFF / appropriate semantic accent

Heading text:
    semantic muted / secondary text

Heading gradient:
    derived from the current dark surface/background, NOT a fixed white gradient

Critical requirement:

The intelligent scrollbar's heading-navigation gradient must switch correctly between light and dark themes.

Do NOT leave a white gradient when Midnight Paper is active.

Do NOT use hardcoded:

    Colors.white
    Colors.black

for the navigation gradient.

The gradient must be derived from the active theme surface.

The existing scrollbar interaction behavior must remain:

- scrollbar is subtle when idle
- appears during scrolling
- becomes interactive on hover/touch
- headings appear beside the scrollbar when interacting
- no separate TOC panel
- current section is highlighted
- heading navigation remains usable for very long notes
- nearby headings are shown rather than flooding the UI with every heading
- heading list moves as the user scrolls
- labels disappear after interaction ends

Do not regress this behavior while applying theme changes.

--------------------------------------------------
## 15. GRADIENT / OPACITY RULES
--------------------------------------------------

For all theme-sensitive gradients:

Do not assume white is the surface.

Bad:

    LinearGradient(
        colors: [
            Colors.white,
            Colors.white.withOpacity(0),
        ],
    )

Good:

    LinearGradient(
        colors: [
            theme.surface.withOpacity(...),
            theme.surface.withOpacity(0),
        ],
    )

Likewise, shadow/overlay colors should derive from semantic theme values where appropriate.

Dark mode must not contain light-mode artifacts.

Light mode must not contain dark-mode artifacts.

--------------------------------------------------
## 16. STATES
--------------------------------------------------

Theme every state consistently.

Required states:

- default
- hover
- pressed
- focused
- selected
- disabled
- active
- dragging
- loading
- error
- success
- warning
- empty
- syncing
- synced
- conflict

Do not derive these by randomly changing RGB values inside widgets.

Define semantic state tokens or clearly documented transformations centrally.

--------------------------------------------------
## 17. ACCESSIBILITY / CONTRAST
--------------------------------------------------

The theme implementation must maintain readable contrast.

Check:

- body text
- secondary text
- muted text
- disabled text
- links
- selected items
- active headings
- scrollbar
- code
- buttons
- controls
- error/warning states

Do not reduce text contrast simply to make the palette look subtle.

Warm Paper should remain comfortable for long reading.

Midnight Paper should avoid excessively bright whites and excessive contrast spikes.

--------------------------------------------------
## 18. TYPOGRAPHY
--------------------------------------------------

Do not replace the application's existing font system as part of this task.

However, audit theme-sensitive typography:

- title
- body
- headings
- metadata
- labels
- navigation
- code

Ensure typography uses theme text colors consistently.

Do not create a separate typography system unless one already exists.

--------------------------------------------------
## 19. DARK THEME BEHAVIOR
--------------------------------------------------

Do not implement Midnight Paper as:

    invert(light colors)

Do not use automatic color inversion.

Midnight Paper is an intentionally designed dark palette.

Use exactly the provided Midnight Paper palette and semantic extensions.

Avoid pure black unless an existing product-specific reason requires it.

The dark theme should feel like:

    deep graphite
    soft slate
    muted indigo/lavender

rather than generic Material dark mode.

--------------------------------------------------
## 20. LIGHT THEME BEHAVIOR
--------------------------------------------------

Warm Paper is intentionally warmer than the existing Light Paper.

It should feel:

- paper-like
- editorial
- quiet
- premium
- low glare
- warm but not sepia

Do not add yellow/beige tones beyond the specified palette.

--------------------------------------------------
## 21. THEME PREVIEW / SETTINGS SWATCHES
--------------------------------------------------

For the Warm Paper settings preview, show:

- background
- surface
- primary text
- secondary text
- accent
- border

For Midnight Paper preview, show the equivalent.

Use the real resolved theme tokens.

Do not maintain a duplicate preview palette.

--------------------------------------------------
## 22. REPOSITORY ARCHITECTURE
--------------------------------------------------

Before writing code, inspect the project and identify:

- current theme files
- settings/preferences implementation
- app root
- MaterialApp/CupertinoApp setup
- theme provider/state management
- editor theme architecture
- preview renderer theme architecture
- syntax highlighting implementation
- scrollbar implementation
- settings UI
- any hardcoded UI colors
- any package/theme coupling

Respect the existing architecture and state-management approach.

Do not introduce a new state-management framework.

Do not create unnecessary global singletons.

Do not duplicate theme state.

Reuse existing dependency injection/provider architecture.

--------------------------------------------------
## 23. IMPLEMENTATION PRINCIPLES
--------------------------------------------------

The implementation must be:

- production-ready
- type-safe
- maintainable
- testable
- reactive
- backwards compatible
- performant

Avoid:

- giant switch statements inside widgets
- raw hex colors in UI files
- theme checks scattered throughout the codebase
- duplicated palette definitions
- duplicated settings state
- magic opacity constants repeated across the UI
- unnecessary rebuilds
- global mutable theme state
- tightly coupling editor widgets to a specific theme family

--------------------------------------------------
## 24. TESTING
--------------------------------------------------

Add automated tests for the theme engine.

At minimum test:

### Theme resolution

Classic Paper + System + light OS
    -> Classic Paper Light

Classic Paper + System + dark OS
    -> Classic Paper Dark

Classic Paper + Light
    -> Classic Paper Light

Classic Paper + Dark
    -> Classic Paper Dark

Warm Paper + Light
    -> Warm Paper Light

Warm Paper + Dark
    -> Midnight Paper

Warm Paper + System + light OS
    -> Warm Paper Light

Warm Paper + System + dark OS
    -> Midnight Paper

### Persistence

Changing theme family persists it.

Changing appearance persists it.

Old preference format migrates correctly.

Migration is idempotent.

### Theme token correctness

Assert that the Warm Paper theme exposes the exact required palette values.

Assert that Midnight Paper exposes the exact required palette values.

### Reactive behavior

Changing theme family updates the UI.

Changing appearance updates the UI.

Changing OS brightness while in System mode updates the resolved theme.

### Syntax highlighting

Code block syntax colors change when theme changes.

### Scrollbar

Scrollbar colors change when theme changes.

Heading navigation gradient uses current theme surface.

No light gradient remains in Midnight Paper.

### UI regression

Where practical, add widget/golden tests for:

- settings theme picker
- 3-pane layout
- editor
- preview
- code block
- sidebar
- note list
- intelligent scrollbar

--------------------------------------------------
## 25. PERFORMANCE
--------------------------------------------------

Theme changes must not cause unnecessary expensive work.

In particular:

- Do not reparse Markdown because the theme changed.
- Do not rebuild database state.
- Do not trigger note synchronization.
- Do not reload attachments.
- Do not rerun OCR.
- Do not rerun search indexing.
- Do not recreate expensive editor/document models unless required by the editor library.
- Do not dispose and recreate the entire application state.

Only theme-dependent UI/rendering state should update.

--------------------------------------------------
## 26. DEVELOPER EXPERIENCE
--------------------------------------------------

Create clear APIs for theme access.

The final implementation should make it easy for future widgets to do something like:

    final theme = context.quietPaperTheme;

and use:

    theme.background
    theme.surface
    theme.textPrimary
    theme.textSecondary
    theme.accent
    theme.border
    theme.scrollbar
    theme.scrollbarActive

Do not force developers to remember raw color values.

Document the semantic theme contract.

Document how to add a future theme family.

--------------------------------------------------
## 27. FUTURE EXTENSIBILITY
--------------------------------------------------

Design the architecture so future themes can be added without changing every widget.

A future theme should only require:

1. Define palette/token set.
2. Register theme family.
3. Provide light/dark variants.
4. Add Settings metadata/preview.

Do not hardcode assumptions that only two theme families will ever exist.

Do not implement "Warm Paper" as a collection of special cases.

--------------------------------------------------
## 28. STRICT VISUAL REQUIREMENT
--------------------------------------------------

When Warm Paper is active:

EVERY theme-sensitive application surface must visibly follow the Warm Paper palette.

When Midnight Paper is active:

EVERY theme-sensitive application surface must visibly follow the Midnight Paper palette.

There must be no accidental remnants such as:

- old white cards
- old dark panels
- old gray borders
- old blue links
- old scrollbar colors
- old editor backgrounds
- old code backgrounds
- old selection colors
- old hardcoded dialog surfaces
- old hardcoded snackbar colors

Do a repository-wide search after implementation to verify this.

Do not consider the task complete just because the main editor changes color.

--------------------------------------------------
## 29. "NO PLACEHOLDERS" REQUIREMENT
--------------------------------------------------

Do NOT leave:

- TODOs
- placeholder palettes
- temporary Color values
- "use existing color here"
- unfinished token mappings
- comments saying a value should be replaced later
- fake settings previews
- mock theme classes
- partial migration logic

Every token must have a real value.

Every theme-sensitive UI component must be wired to the theme system.

--------------------------------------------------
## 30. VALIDATION CHECKLIST
--------------------------------------------------

Before declaring the work complete:

1. Existing Classic Paper Light looks unchanged.
2. Existing Classic Paper Dark looks unchanged.
3. Existing System behavior remains unchanged.
4. Warm Paper Light works.
5. Midnight Paper works.
6. Warm Paper + System follows OS brightness.
7. Theme family persists.
8. Appearance mode persists.
9. Existing users migrate safely.
10. Theme changes apply immediately.
11. Editor updates.
12. Preview updates.
13. Syntax highlighting updates.
14. Code block backgrounds update.
15. Search UI updates.
16. Sidebar updates.
17. Note list updates.
18. Tags update.
19. Trash updates.
20. Archive updates.
21. Dialogs update.
22. Settings updates.
23. Attachments/document UI updates.
24. OCR UI updates.
25. Sync/conflict UI updates.
26. Intelligent scrollbar updates.
27. Intelligent scrollbar gradient changes correctly.
28. Heading labels use the active theme.
29. No separate TOC panel is introduced.
30. No hardcoded light-mode artifacts remain in dark mode.
31. No hardcoded dark-mode artifacts remain in light mode.
32. No unnecessary rebuild/performance regression is introduced.
33. Tests pass.
34. Analyzer reports no new warnings/errors.
35. Formatter passes.
36. Existing functionality continues working.

--------------------------------------------------
## 31. REQUIRED WORKFLOW
--------------------------------------------------

Do NOT immediately start changing code.

First:

### Phase 1 — Inspect

Inspect the existing:

- theme architecture
- settings persistence
- app root
- state management
- editor
- preview
- syntax highlighting
- scrollbar
- navigation
- all major UI surfaces

Identify:

- current theme enums
- current preference keys
- migration requirements
- hardcoded colors
- theme-sensitive components
- architectural risks

### Phase 2 — Report

Before implementation, provide a concise technical report containing:

- current theme architecture
- current setting storage
- exact files/classes involved
- migration strategy
- hardcoded color problem areas
- proposed semantic token architecture
- files that will be changed
- files that will be added
- testing strategy

Do not implement until the inspection/report is complete.

### Phase 3 — Implement

Then implement the complete architecture.

Do not stop after implementing only the central ThemeData.

Perform the repository-wide integration.

### Phase 4 — Verify

Run:

- formatter
- analyzer
- unit tests
- widget tests
- relevant integration tests

Search the repository again for hardcoded theme-sensitive colors.

Fix any remaining theme leaks.

### Phase 5 — Final report

Return:

- implementation summary
- files changed
- migration details
- theme architecture
- tests run
- issues found
- issues fixed
- any remaining limitations

Do not claim success if tests or analysis fail.

--------------------------------------------------
## 32. IMPORTANT DESIGN DECISION
--------------------------------------------------

The final user-facing model must be:

Theme Family:
    Classic Paper
    Warm Paper

Appearance:
    System | Light | Dark

And the resolved themes are:

    Classic Paper Light
    Classic Paper Dark
    Warm Paper Light
    Midnight Paper

"System" is an appearance mode, not a theme.

This architecture must be reflected consistently in:

- code
- settings
- persistence
- state management
- tests
- UI labels
- documentation

--------------------------------------------------
## FINAL ACCEPTANCE CRITERION
--------------------------------------------------

This task is complete only when Quiet Paper has a real centralized theme engine in which:

- Classic Paper remains unchanged.
- Warm Paper is fully implemented.
- Midnight Paper is fully implemented.
- System/Light/Dark is an appearance selector.
- Theme family and appearance are persisted independently.
- All theme-sensitive UI consumes semantic tokens.
- Editor and preview follow the theme.
- Syntax highlighting follows the theme.
- Intelligent scrollbar follows the theme.
- Scrollbar heading gradient follows the theme.
- No separate TOC panel is introduced.
- No placeholders exist.
- No theme-sensitive hardcoded colors remain.
- Theme changes are immediate and reactive.
- Existing users are safely migrated.
- Tests cover resolution, persistence, migration, rendering, and major interactive surfaces.
- The implementation is suitable for production release.
