

# Production-Ready AI Coding Agent Prompt — Quiet Paper Editor & Markdown Previewer Image Experience

## Role

You are a senior Flutter engineer specializing in rich-text/Markdown editors, document rendering, media handling, responsive UI, and production mobile/desktop applications.

You are working on **Quiet Paper**, an existing production note-taking application.

Your task is to improve the **note editor and Markdown previewer**, specifically the way images and other inline document media are rendered.

The application stores note bodies as **canonical Markdown**.

The note editor and previewer must continue using Markdown as the canonical representation.

Do **not** redesign the Notes List.
Do **not** modify the Bear-inspired Notes List implementation that already exists.

This task is strictly about:

* note editor image handling
* Markdown preview image handling
* consistent editor/preview rendering
* automatic image sizing
* fullscreen image viewing
* image zooming
* image navigation
* image loading
* image caching
* image failures
* image accessibility
* captions
* attachment integration
* Cloudinary integration where already used
* responsive behavior
* Light Paper theme
* Dark Paper theme

---

# 1. Current Problem

The existing Quiet Paper screenshots show that images inside notes currently behave too much like unrestricted full-width blocks.

The desired behavior is:

* images should automatically determine an appropriate display size
* small images should not be unnecessarily enlarged
* large images should fit the available content width
* extremely tall images should be constrained intelligently
* images must never be distorted
* images must never be cropped inside the note
* images should remain centered
* images should have subtle rounded corners
* tapping an image should open an immersive fullscreen viewer
* fullscreen viewing should support zooming and panning
* users should not need resize handles
* users should not manually position images
* Markdown must remain clean and canonical

The user explicitly does **not** want blur-up/progressive blurred image loading.

Do not implement blur loading.

---

# 2. Critical Architecture Requirement

Before modifying code, inspect the existing implementation.

Identify:

* Markdown editor
* Markdown previewer
* Markdown parser
* Markdown renderer
* image node/widget
* attachment system
* image attachment model
* Cloudinary integration
* image URL generation
* image caching
* note repository/provider architecture
* note body model
* canonical Markdown storage
* protected/password note behavior
* synchronization behavior
* existing fullscreen/media viewer, if any
* existing theme system
* Light Paper theme
* Dark Paper theme
* existing typography tokens
* existing spacing tokens
* existing animation conventions
* existing mobile navigation
* existing desktop/tablet editor architecture
* existing accessibility infrastructure

Do not create parallel implementations when existing abstractions can be extended.

Do not modify canonical Markdown to solve a rendering problem.

Do not migrate the note body to JSON.

---

# 3. Scope

## In scope

### Editor

* image presentation while editing
* image insertion presentation
* image loading
* image sizing
* image selection behavior if one already exists
* image interaction
* editor/preview visual consistency

### Previewer

* inline image rendering
* sizing
* alignment
* spacing
* loading
* error handling
* captions
* accessibility
* fullscreen viewer entry

### Shared media system

* sizing algorithm
* caching
* fullscreen viewer
* zoom
* pan
* multi-image navigation
* share/save/copy where supported
* theme support

## Out of scope

Do not modify:

* Notes List layout
* Notes List grouping
* Notes List sorting UI
* Notes List filtering UI
* sidebar redesign
* note-list thumbnails
* note-list metadata
* unrelated editor formatting features
* unrelated search architecture
* database redesign
* Markdown-to-JSON migration

---

# 4. Core Product Philosophy

Images are **content**, not layout objects.

The user should not have to think about:

* width
* height
* x/y position
* cropping
* layout coordinates
* responsive scaling

Quiet Paper should automatically make a sensible presentation decision.

The experience should feel closer to a polished reading application than a page-layout editor.

---

# 5. Canonical Markdown Must Remain Canonical

Quiet Paper currently stores the note body as canonical Markdown.

This must remain unchanged.

Do not introduce:

```text
x position
y position
width
height
canvas coordinates
absolute positioning
```

into canonical note content.

Do not migrate the body into JSON.

Do not introduce a proprietary document database format merely to support images.

Transient in-memory parsing structures are acceptable.

Persistent Markdown remains the source of truth.

---

# 6. Image Rendering Model

Treat an image as a **block-level document element**.

Conceptually:

```text
paragraph

image

paragraph

heading

image

paragraph
```

The image's position is determined entirely by document order.

The renderer controls visual presentation automatically.

There must be no freeform canvas behavior.

---

# 7. Automatic Image Sizing

Implement a reusable image sizing system used by both the editor and previewer.

The system must consider:

* intrinsic image width
* intrinsic image height
* intrinsic aspect ratio
* available content width
* viewport dimensions
* orientation
* device class where relevant
* whether image is currently in inline mode or fullscreen mode

Conceptual logic:

```text
displayWidth =
    min(intrinsicWidth, availableContentWidth)

displayHeight =
    displayWidth / aspectRatio
```

Then enforce a reasonable maximum height for unusually tall images.

For example:

```text
if displayHeight > maxAllowedHeight:
    displayHeight = maxAllowedHeight
    displayWidth = displayHeight * aspectRatio
```

Use sensible values derived from the current layout rather than arbitrary hardcoded device-specific values.

---

# 8. Never Distort Images

Images must always preserve their original aspect ratio.

Never use a rendering configuration equivalent to:

```dart
BoxFit.fill
```

for the note-body image.

Use proportional fitting.

The following are explicitly forbidden in the note body:

* stretching
* squashing
* forced width + forced unrelated height
* arbitrary cropping

---

# 9. Never Crop Note-Body Images

An image in the note must remain fully visible.

Do not use:

```text
cover
crop
centerCrop
```

for the actual note-body image.

Cropping may be appropriate for separate thumbnail contexts elsewhere in the app, but **not for the note editor/preview body**.

The actual note content must remain intact.

---

# 10. Small Images Must Not Be Unnecessarily Upscaled

If the original image is significantly smaller than the available content width, preserve a sensible natural size.

Example:

```text
intrinsic width = 400
content width = 900
```

Do not automatically render it at 900.

The objective is a natural-looking document.

Small:

```text
        ┌──────────────┐
        │    image     │
        └──────────────┘
```

Wide:

```text
┌────────────────────────────┐
│           image            │
└────────────────────────────┘
```

---

# 11. Large Landscape Images

Large landscape images such as:

* charts
* diagrams
* screenshots
* photos

should scale down to the available content width.

They may use the full content width.

They must:

* preserve aspect ratio
* remain fully visible
* avoid horizontal scrolling
* remain sharp enough for normal reading

---

# 12. Extremely Tall Images

For very tall images such as:

* long screenshots
* phone screenshots
* scanned pages
* infographics

apply a viewport-aware maximum height.

The image must not dominate the screen unnecessarily.

Do not crop it.

Do not hide content.

The fullscreen viewer exists so the user can inspect it in detail.

---

# 13. Center Images

Inline note-body images should normally be centered horizontally.

Example:

```text
Paragraph...

        ┌────────────────┐
        │                │
        │     image      │
        │                │
        └────────────────┘

Next paragraph...
```

Normal text should retain its existing text alignment.

Only the image block is centered.

---

# 14. Image Spacing

Images should have intentional vertical spacing.

Use the existing spacing system where possible.

Conceptually:

```text
paragraph

16–24 px

image

24–32 px

next paragraph
```

Do not introduce giant gaps.

Do not make images appear glued to surrounding text.

---

# 15. Rounded Corners

Images should receive subtle corner rounding consistent with Quiet Paper's design language.

Approximately:

```text
8–12 logical px
```

depending on existing design tokens.

Do not add heavy borders.

Do not add unnecessary shadows.

---

# 16. Responsive Image Behavior

The same rendering system must work on:

* phones
* tablets
* desktop
* narrow windows
* wide windows
* portrait
* landscape

The available content width must be measured dynamically.

Do not create separate implementations for phone and desktop unless the underlying platform genuinely requires it.

---

# 17. Very Wide Images on Mobile

Very wide images such as charts and diagrams may use almost the entire available screen width on narrow devices where beneficial.

Normal text should retain normal content margins.

Do not make every image edge-to-edge.

Do not introduce horizontal scrolling for normal document reading.

---

# 18. Image Loading

Image loading should feel quiet and unobtrusive.

Do not implement blur-up loading.

Explicitly do **not** generate or display blurred miniature image placeholders.

A neutral placeholder is acceptable if necessary.

Avoid unnecessary spinners.

The image should appear naturally when loaded.

---

# 19. Prevent Layout Shifts

When image dimensions are known or can be determined:

reserve the correct aspect-ratio region before the image finishes loading.

This is critical.

Bad:

```text
text

tiny empty area

image loads

everything below moves downward
```

Good:

```text
text

reserved image region

image appears inside reserved region

text below stays stable
```

No large document jumps when remote images load.

---

# 20. Image Loading Transition

A very subtle appearance transition is acceptable.

For example:

```text
placeholder → image
```

using a restrained fade.

Do not:

* bounce
* zoom
* slide
* scale aggressively
* animate layout geometry

The transition should barely be noticeable.

---

# 21. No Blur Loading

This is an explicit requirement.

**Do not implement blur-up loading.**

Do not generate:

* blurred Cloudinary previews
* low-resolution blurred placeholders
* progressive blur effects

Normal caching, placeholders, and standard image loading are sufficient.

---

# 22. Editor and Preview Must Share the Same Rendering Logic

The image should not look one way in edit mode and another way in preview mode.

Create or reuse a shared image-rendering abstraction.

Conceptually:

```text
Canonical Markdown
       ↓
Markdown parser
       ↓
Image node
       ↓
Shared Quiet Paper Image Renderer
       ├── editor presentation
       ├── preview presentation
       ├── sizing
       ├── loading
       ├── caching
       ├── accessibility
       └── fullscreen viewer
```

The editor may add editor-specific interactions, but visual media rules should remain consistent.

---

# 23. Editor Image Behavior

In editor mode:

* preserve Markdown semantics
* preserve insertion/removal behavior
* preserve cursor behavior
* preserve existing Markdown editing behavior
* render the image predictably
* do not introduce drag handles
* do not introduce manual resizing
* do not make the image a free-positioned block
* allow normal document editing around it

If the current editor already exposes image selection, preserve that behavior and improve its presentation rather than replacing it unnecessarily.

---

# 24. No Manual Image Resizing

Do **not** implement:

* resize handles
* draggable width controls
* corner handles
* drag-to-resize
* stored user-defined dimensions

The user does not manually control image presentation size.

Quiet Paper determines it automatically.

---

# 25. No Manual Image Positioning

Do not implement:

* drag-to-move
* floating image layouts
* text wrapping around images as a manual layout control
* arbitrary image positions

Images follow document order.

---

# 26. Fullscreen Image Viewer

Tapping an inline image should open a fullscreen/immersive viewer.

The viewer should support:

* fit-to-screen
* pinch-to-zoom
* double-tap zoom
* panning
* close/back
* high-resolution display
* multiple-image navigation
* image counter when appropriate
* share
* save
* copy
* original/open action where meaningful and supported

Use existing media-viewing architecture if one already exists.

Otherwise create a reusable production-quality viewer.

---

# 27. Fullscreen Viewer Visual Design

The viewer should be visually minimal.

The image should be the focus.

Keep controls unobtrusive.

Do not cover important image content unnecessarily.

Support:

* system back
* close button where appropriate
* desktop escape
* appropriate gesture dismissal where supported by existing navigation architecture

---

# 28. Pinch-to-Zoom

Use a smooth, bounded zoom system.

Support:

* pinch gesture
* panning while zoomed
* sensible min zoom
* sensible max zoom

Do not allow absurd infinite zoom.

The exact limits should be chosen based on image resolution and practical usability.

---

# 29. Double-Tap Zoom

Double-tap should intelligently switch between approximately:

```text
Fit
  ↕
Useful zoom
```

For example:

```text
fit → readable/detail zoom
detail zoom → fit
```

Do not require multiple taps through arbitrary zoom percentages.

Pinch remains available for finer control.

---

# 30. Pan Behavior

When zoomed:

* pan naturally
* remain inside valid image bounds
* avoid showing huge blank areas
* preserve touch responsiveness
* do not fight the user's gesture

When fit-to-screen, normal note-viewer navigation should not accidentally interpret ordinary taps as large pans.

---

# 31. High-Resolution Assets

Inline rendering does not have to decode the original maximum-resolution asset if doing so would be wasteful.

Fullscreen viewing should use the best practical available resolution.

This is especially important for:

* screenshots
* charts
* diagrams
* scanned documents
* technical images
* images containing text

Do not permanently downsample original assets.

---

# 32. Multiple Images in a Note

Do not convert multiple images into an inline carousel.

Keep document structure:

```text
image

paragraph

image

paragraph

image
```

In fullscreen mode, however, all images in the current note should be navigable.

---

# 33. Multiple-Image Navigation

If the current image is image 2 of 5:

```text
2 / 5
```

may be shown subtly.

Allow:

```text
previous image
next image
```

through appropriate touch/desktop interactions.

The viewer must open on the exact image the user tapped.

---

# 34. Image Counter

Only show the counter when there is more than one image.

Example:

```text
2 / 7
```

Keep it subtle.

For one image, don't display unnecessary `1 / 1`.

---

# 35. Preserve Document Position

This is critical.

If the user is reading a long note:

```text
paragraph
paragraph
image
paragraph
paragraph
```

and opens the image:

1. open fullscreen
2. inspect image
3. zoom/pan
4. close
5. return to exactly the same note scroll position

Do not reset the document to the top.

Do not jump to an unrelated location.

---

# 36. Viewer Zoom Lifecycle

While the viewer is open:

* preserve current zoom
* preserve pan position
* avoid unexpected resets from rebuilds

When the viewer is closed and later opened again:

* normally start at fit-to-screen

Unless existing application UX already establishes different behavior.

---

# 37. Captions

Support captions through existing Markdown semantics where practical.

For example:

```markdown
![Hugging Face agent activity](image-url)

*Agent activity during the attack*
```

Render approximately as:

```text
        [ IMAGE ]

    Agent activity during the attack
```

Caption styling should be:

* smaller than body text
* secondary color
* subtle
* visually subordinate

Do not create a new database field purely for captions unless the project already has such a concept.

---

# 38. Alt Text

Respect Markdown alt text.

Example:

```markdown
![Architecture diagram](...)
```

Use:

> Architecture diagram

for accessibility.

If alt text is missing, provide a sensible fallback such as:

> Image in note

Do not expose:

* Cloudinary URLs
* attachment IDs
* implementation details

to screen readers.

---

# 39. Accessibility — Image

Ensure the image is semantically interactive when tap opens fullscreen.

Accessibility should communicate something equivalent to:

> Architecture diagram, image. Double tap to open.

Adapt to platform conventions.

Do not require visual perception to understand that the image can be opened.

---

# 40. Image Error Handling

Handle:

* missing image
* missing attachment
* invalid URL
* expired URL
* deleted Cloudinary asset
* offline state
* corrupt asset
* decode failure
* permission error

Show a calm fallback:

```text
Unable to load image
Tap to retry
```

or the project's existing error-state equivalent.

Do not remove or modify the Markdown reference because the asset failed to load.

---

# 41. Retry

Retry should use the existing attachment/network architecture.

Do not create an independent networking stack inside the image widget.

Do not repeatedly retry indefinitely.

Use a sensible retry mechanism.

---

# 42. Offline Image Support

Where the existing architecture allows it:

* cached images should remain visible offline
* previously viewed images should not unnecessarily become blank
* local/remote resolution should respect attachment identity

Do not compromise existing encryption or sync design.

---

# 43. Cloudinary Integration

Quiet Paper already uses Cloudinary.

Do not duplicate Cloudinary URL generation.

Reuse existing services.

The image renderer should depend on an abstract/resolved image source rather than assuming a hardcoded URL format.

Respect existing:

* transformations
* attachment IDs
* asset lifecycle
* caching
* sync
* deletion
* offline behavior

---

# 44. Image Caching

Use the application's existing caching architecture where available.

Avoid:

* repeated network requests
* repeated URL resolution
* unnecessary image decoding
* cache bypasses on every rebuild

A previously loaded image should generally be reused efficiently.

Do not introduce a second cache unless there is a compelling architectural requirement.

---

# 45. Image Dimensions

Where possible, obtain intrinsic image dimensions efficiently.

Sources may include:

* existing attachment metadata
* known dimensions from upload
* image provider metadata
* cached dimension information

Avoid fully decoding huge original images purely to discover their dimensions when a cheaper source already exists.

Do not change the database schema solely to support this unless existing architecture makes it genuinely necessary.

---

# 46. Context Menu — Desktop

For pointer devices, an image context menu may provide:

```text
Open
Copy Image
Save Image
Share
```

Only expose actions actually supported on the current platform.

Do not show non-functional options.

---

# 47. Long Press — Mobile

A long press may expose:

```text
Open
Share
Save
Copy
Open Original
```

where supported.

Normal tap should remain:

> Open fullscreen viewer.

Do not force the user to long-press for basic image interaction.

---

# 48. Copy Image

Where the platform supports it, copying should place actual image data on the clipboard.

Do not merely copy:

* image URL
* Cloudinary URL
* attachment ID

Handle failure gracefully.

---

# 49. Save Image

Use the platform-appropriate storage/gallery mechanism.

Respect permissions.

Do not silently overwrite files.

Handle failure cleanly.

Do not expose fake success messages.

---

# 50. Share Image

Use existing native sharing infrastructure where available.

Share the actual image asset rather than simply sharing the internal URL unless the application's existing behavior explicitly dictates otherwise.

---

# 51. Open Original

Where meaningful, provide the ability to open the original/full-resolution source.

Do not expose internal implementation details.

---

# 52. Editor/Preview Consistency

The following should remain consistent between editor and preview:

* image alignment
* image max width
* image natural sizing
* aspect ratio
* tall-image handling
* corner radius
* spacing
* captions
* accessibility
* fullscreen interaction

Editor-only behavior may include:

* selection
* cursor interaction
* deletion/insertion

but the actual visual media presentation should remain coherent.

---

# 53. Markdown Compatibility

Image syntax must continue to work correctly for standard Markdown forms already supported by Quiet Paper.

Do not break:

```markdown
![alt](url)
```

or the application's existing attachment/image syntax.

Preserve existing Markdown parsing rules unless a genuine bug is found.

---

# 54. Markdown Parser Rules

Do not solve image rendering by modifying canonical Markdown structure unnecessarily.

If the parser currently creates image nodes, improve rendering at the image-node level.

If image parsing is currently scattered, consolidate only where this materially improves correctness and maintainability.

---

# 55. Image URLs and Attachment References

Determine how Quiet Paper currently represents images:

* direct URLs
* attachment IDs
* Cloudinary references
* Markdown URLs
* internal schemes

Then use the existing canonical representation.

Do not introduce a second incompatible syntax.

---

# 56. Broken/Unavailable Images Must Not Corrupt Notes

This is an absolute requirement.

A failed network request must not alter:

* Markdown
* attachment records
* sync state
* note state

Rendering failure is presentation state only.

---

# 57. Password-Protected Notes

Respect existing protected-note architecture.

Do not leak protected note content through:

* image accessibility labels
* metadata
* logs
* cache keys exposed to users
* error messages
* debugging UI

Do not bypass encryption.

---

# 58. Sync Safety

Do not change synchronization semantics.

Image rendering state such as:

* current zoom
* viewer position
* temporary loading state
* temporary error state

must not be persisted into note canonical data.

Do not add image layout properties to sync payloads.

---

# 59. No Persistent Image Layout State

Do not persist:

```text
imageWidth
imageHeight
x
y
zoom
pan
```

as note content metadata merely because of this feature.

Zoom and pan are ephemeral viewer state.

Rendered size is derived from current device/layout conditions.

---

# 60. Image Size Must Adapt Across Devices

An image viewed on desktop should not permanently store:

```text
width = 900px
```

and expect a phone to use it.

Instead:

```text
same Markdown
    ↓
different available content width
    ↓
different calculated presentation size
```

This keeps notes portable.

---

# 61. Theme Integration

The feature must work fully with the existing two Paper themes:

1. **Light Paper**
2. **Dark Paper**

Do not create another theme.

Do not duplicate the renderer for the two themes.

---

# 62. Light Paper

Ensure:

* image corners fit the theme
* captions use correct semantic secondary text
* placeholders are paper-compatible
* error surfaces fit the Paper aesthetic
* fullscreen viewer feels cohesive
* controls don't look like unrelated Material UI

Avoid hardcoded pure-white surfaces unless already defined by the theme.

---

# 63. Dark Paper

Ensure:

* image presentation remains natural
* captions have sufficient contrast
* error state is readable
* fullscreen controls are readable
* viewer background works correctly
* no light-mode leakage remains

The same widget architecture must work in Dark Paper.

---

# 64. Theme Token Audit

Inspect affected widgets for hardcoded values such as:

```dart
Colors.white
Colors.black
Colors.grey
```

or equivalent assumptions.

Replace inappropriate hardcoded colors with semantic theme values.

Theme changes must update:

* captions
* placeholders
* errors
* viewer controls
* viewer background
* focus states
* image-related surfaces

---

# 65. Typography

Do not introduce an unrelated typography system.

Use existing Quiet Paper typography tokens.

Captions should be visually subordinate.

Error messages should remain readable but restrained.

Viewer controls should be legible without dominating the image.

---

# 66. Animation

Keep animation subtle.

Target roughly:

```text
120–200 ms
```

for ordinary UI state transitions unless current project conventions dictate otherwise.

Suitable:

* subtle image appearance
* fullscreen opening/closing
* viewer control visibility
* selection transitions

Avoid:

* bouncing
* aggressive zoom animations
* decorative motion
* layout jumps

---

# 67. Reduced Motion

Respect existing reduced-motion/accessibility settings where available.

Do not introduce unavoidable elaborate transitions.

---

# 68. Memory Management

Images may be extremely large.

Pay attention to:

* decode size
* image cache pressure
* fullscreen images
* multiple-image navigation
* rapid image switching

Do not eagerly load every image in a very long note at full resolution.

Only load what is necessary.

---

# 69. Long Notes

Test notes containing:

* hundreds of paragraphs
* many images
* mixed images and text
* large screenshots
* charts
* PDFs/attachments
* clipped web content

The renderer must remain responsive.

Do not parse/recompute the entire document on every minor interaction if avoidable.

---

# 70. Scrolling Stability

When images load:

* surrounding text must not jump unnecessarily
* editor cursor must remain stable
* preview scroll position must remain stable
* fullscreen viewer must preserve return position

This is especially important for long web clips.

---

# 71. Editor Cursor Stability

Image insertion/loading must not cause:

* cursor relocation
* editor scroll reset
* focus loss
* text selection loss

unless the user explicitly interacted with the image.

---

# 72. Preview Scroll Stability

Refreshing image state should not reset the Markdown preview to the beginning.

Do not reconstruct the entire scrollable document unnecessarily when one image finishes loading.

---

# 73. Shared Media Rendering Infrastructure

Prefer a reusable abstraction rather than independently implementing sizing in multiple places.

Conceptually:

```text
ImageSource
ImageLayoutCalculator
QuietPaperInlineImage
QuietPaperImageViewer
```

Use actual project naming conventions rather than blindly using these names.

The important requirement is shared logic.

---

# 74. Test Small Images

Example scenarios:

* 100 × 100 icon
* 300 × 200 screenshot
* small diagram
* small photograph

Verify that they don't become absurdly enlarged.

---

# 75. Test Wide Images

Examples:

* 1600 × 600 chart
* 1920 × 1080 screenshot
* landscape photograph

Verify:

* proportional scaling
* content width constraint
* no distortion
* no horizontal overflow

---

# 76. Test Tall Images

Examples:

* 1080 × 3000 screenshot
* 1000 × 5000 infographic
* tall scanned page

Verify:

* viewport-aware height
* proportional scaling
* no cropping
* fullscreen inspection works

---

# 77. Test Extreme Aspect Ratios

Test unusual images such as:

* 3000 × 200
* 200 × 3000
* 4000 × 4000

The renderer must behave predictably.

---

# 78. Test Missing Dimensions

If intrinsic dimensions are temporarily unavailable:

* render using an appropriate temporary state
* update once dimensions are available
* avoid major layout jumps
* preserve the document position

---

# 79. Test Failed Images

Test:

* invalid URL
* unavailable Cloudinary asset
* offline
* corrupted image
* permission error

Verify the note remains intact.

---

# 80. Test Multiple Images

Create a note with at least:

```text
Image 1
paragraph
Image 2
paragraph
Image 3
```

Verify:

* independent inline rendering
* correct document ordering
* viewer opens correct image
* navigation works
* counter is correct
* closing returns to original location

---

# 81. Test Editor and Preview

The same Markdown should display consistently in:

### Editor

and

### Preview

with the same media sizing logic.

There may be editor-specific interactions, but the image should not suddenly become dramatically larger/smaller simply because the user changed viewing mode.

---

# 82. Test Both Themes

Repeat image tests in:

### Light Paper

and:

### Dark Paper

Check:

* corners
* spacing
* captions
* placeholders
* errors
* viewer
* controls
* accessibility contrast

---

# 83. Test Responsive Layout

Test:

### Phone

Portrait and landscape.

### Tablet

Portrait and landscape.

### Desktop

Normal and narrow windows.

### Very wide desktop

Ensure the image doesn't become unreasonably gigantic simply because the monitor is huge.

There should be a sensible content-width constraint inherited from the note editor.

---

# 84. Accessibility Tests

Verify:

* alt text
* image activation
* viewer accessibility
* close action
* navigation
* zoom controls if exposed
* error announcements
* keyboard access
* sufficient contrast
* focus visibility

---

# 85. Performance Requirements

The implementation must not introduce:

* expensive work in widget `build()`
* repeated network requests
* repeated image dimension calculations
* repeated full-document parsing
* unnecessary image decoding
* full editor reconstruction on image load
* full preview reconstruction when only one image changes

Use stable keys and appropriate state boundaries.

---

# 86. Dependency Rules

Do not add a new dependency unless necessary.

Prefer existing:

* Flutter primitives
* image APIs
* navigation
* state management
* cache
* attachment services

If an existing package already solves fullscreen zooming and the project already uses it, reuse it.

Otherwise, a new package must have a clear production justification.

---

# 87. Error Logging

Use existing logging infrastructure.

Do not log:

* protected note content
* sensitive image contents
* Cloudinary credentials
* authentication tokens
* private URLs unnecessarily

Error messages should contain enough information for diagnosis without leaking sensitive data.

---

# 88. Do Not Break Existing Markdown

Regression test other Markdown structures near images:

* headings
* paragraphs
* bold
* italic
* links
* lists
* blockquotes
* tables
* code blocks
* horizontal rules
* inline code

Images must integrate naturally with the existing renderer.

Do not fix the image system by breaking unrelated Markdown.

---

# 89. Do Not Redesign Code Blocks

Syntax highlighting and code-block work are separate concerns.

Unless required for image layout integration, do not change the existing code-block architecture as part of this task.

---

# 90. Do Not Redesign the Editor Toolbar

Do not modify the editor toolbar unless a tiny integration change is required for image interactions.

The focus is media rendering and viewing.

---

# 91. Production Code Quality

Follow existing:

* architecture
* naming
* formatting
* linting
* state management
* repository patterns
* dependency conventions

Avoid:

* dead code
* duplicate widgets
* temporary hacks
* placeholder implementation
* excessive comments explaining obvious code
* magic numbers scattered throughout the codebase

Where new behavior requires constants, centralize them appropriately.

---

# 92. Architecture Validation

Before finalizing, verify:

```text
Markdown
   ↓
existing parser
   ↓
image node
   ↓
shared image presentation
   ↓
automatic sizing
   ↓
existing attachment/image source
```

and:

```text
inline image
   ↓
tap
   ↓
fullscreen viewer
   ↓
zoom / pan / navigation
   ↓
close
   ↓
same document position
```

No duplicate source of truth should exist.

---

# 93. Required Tests

Add/update tests for:

### Image sizing

* small
* medium
* large
* landscape
* portrait
* tall
* extreme aspect ratios

### Image rendering

* center alignment
* aspect-ratio preservation
* no crop
* no distortion
* responsive behavior
* loading
* failed loading
* retry

### Viewer

* open
* close
* pinch zoom
* double-tap zoom
* pan
* multiple-image navigation
* counter
* correct initial image
* return position

### Markdown

* standard image syntax
* alt text
* captions
* multiple images
* images adjacent to headings/paragraphs

### Themes

* Light Paper
* Dark Paper

### Accessibility

* labels
* alt text
* focus
* keyboard navigation

---

# 94. Manual QA Matrix

Before declaring completion, manually verify:

| Scenario             | Editor | Preview | Viewer |
| -------------------- | -----: | ------: | -----: |
| Small image          |      ✓ |       ✓ |      ✓ |
| Wide image           |      ✓ |       ✓ |      ✓ |
| Tall image           |      ✓ |       ✓ |      ✓ |
| Huge image           |      ✓ |       ✓ |      ✓ |
| Multiple images      |      ✓ |       ✓ |      ✓ |
| Failed image         |      ✓ |       ✓ |      ✓ |
| Offline cached image |      ✓ |       ✓ |      ✓ |
| Caption              |      ✓ |       ✓ |      ✓ |
| Alt text             |      ✓ |       ✓ |      ✓ |
| Light Paper          |      ✓ |       ✓ |      ✓ |
| Dark Paper           |      ✓ |       ✓ |      ✓ |
| Mobile               |      ✓ |       ✓ |      ✓ |
| Tablet               |      ✓ |       ✓ |      ✓ |
| Desktop              |      ✓ |       ✓ |      ✓ |

---

# 95. Definition of Done

The implementation is complete only when:

* [ ] editor images render intelligently
* [ ] preview images render intelligently
* [ ] editor and preview use shared media presentation logic
* [ ] small images aren't unnecessarily upscaled
* [ ] large images scale to content width
* [ ] very tall images receive sensible height constraints
* [ ] aspect ratio is always preserved
* [ ] note-body images are never cropped
* [ ] images are centered
* [ ] image spacing is polished
* [ ] subtle corner rounding is implemented
* [ ] layout does not jump during image loading
* [ ] blur loading is not implemented
* [ ] image caching uses existing infrastructure
* [ ] offline behavior is respected
* [ ] image failures are graceful
* [ ] retry works
* [ ] alt text is supported
* [ ] captions are supported through Markdown semantics
* [ ] tapping opens fullscreen
* [ ] fullscreen supports pinch zoom
* [ ] fullscreen supports double-tap zoom
* [ ] fullscreen supports pan
* [ ] fullscreen supports multiple-image navigation
* [ ] correct image opens initially
* [ ] image counter is shown only when appropriate
* [ ] closing viewer restores document position
* [ ] share works where supported
* [ ] save works where supported
* [ ] copy image works where supported
* [ ] desktop context actions work where appropriate
* [ ] mobile long-press actions work where appropriate
* [ ] high-resolution images are available in fullscreen where practical
* [ ] no image positioning/resizing system is introduced
* [ ] canonical Markdown remains unchanged
* [ ] no JSON migration occurs
* [ ] Cloudinary architecture is respected
* [ ] sync behavior is unchanged
* [ ] protected-note boundaries are preserved
* [ ] Light Paper works correctly
* [ ] Dark Paper works correctly
* [ ] accessibility is preserved/improved
* [ ] mobile works correctly
* [ ] tablet works correctly
* [ ] desktop works correctly
* [ ] performance remains good
* [ ] tests pass
* [ ] lint/static analysis passes
* [ ] no dead code remains

---

# 96. Final Agent Workflow

Follow this exact workflow.

### Phase 1 — Inspect

Inspect the actual codebase and identify:

* editor
* previewer
* Markdown parser
* image renderer
* attachment system
* Cloudinary integration
* caching
* themes
* navigation
* existing viewer

### Phase 2 — Plan

Provide a concise implementation plan referencing the actual project files/classes.

Do not invent file names before inspection.

### Phase 3 — Build Shared Media Infrastructure

Implement/refactor the shared:

* image source resolution
* intrinsic dimension handling
* responsive sizing
* loading/error states
* rendering
* accessibility

### Phase 4 — Integrate Editor

Make editor image behavior use the shared implementation while preserving existing editing semantics.

### Phase 5 — Integrate Previewer

Make preview images use exactly the same sizing and visual rules.

### Phase 6 — Implement Fullscreen Viewer

Add:

* open
* fit
* pinch zoom
* double-tap zoom
* pan
* multiple-image navigation
* counter
* close
* share
* save
* copy
* appropriate desktop/mobile actions

### Phase 7 — Integrate Themes

Verify:

* Light Paper
* Dark Paper

### Phase 8 — Performance Pass

Check:

* large images
* long documents
* multiple images
* cache behavior
* rebuild behavior
* memory usage

### Phase 9 — Testing

Run appropriate:

* unit tests
* widget tests
* integration tests
* static analysis
* formatting

### Phase 10 — Visual QA

Test real notes containing:

* photographs
* screenshots
* charts
* diagrams
* long images
* scanned pages
* multiple images
* images with captions
* images with alt text

---

# Final Product Requirement

The final experience should feel like this:

```text
                 Quiet Paper

Paragraph...

       ┌─────────────────────────┐
       │                         │
       │          IMAGE          │
       │                         │
       └─────────────────────────┘

       Optional caption

Next paragraph...

                  ↓ tap

       ┌─────────────────────────┐
       │                         │
       │                         │
       │         IMAGE           │
       │                         │
       │                         │
       └─────────────────────────┘

                    2 / 5

            pinch / double-tap / pan

                  ↓ close

       return to exact reading position
```

The user should **never need to resize or position an image manually**.

The document should automatically look good regardless of whether the user inserts:

* a tiny image
* a phone screenshot
* a huge chart
* a photograph
* a tall infographic
* a scanned page
* a technical diagram

The same Markdown must remain portable and clean.

The renderer should intelligently adapt the visual presentation to the current device and available content width.

Most importantly:

> **Do not turn Quiet Paper into a page-layout editor.**
>
> Images are content.
>
> Markdown remains canonical.
>
> Quiet Paper handles the presentation intelligently.
