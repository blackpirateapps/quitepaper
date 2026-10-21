# Quiet Paper — Bear-Inspired Flutter Design System

## 1. Design Philosophy

The interface should feel like a **place to write**, not a productivity dashboard.

### Principles

1. **Content first**

   * Notes are the primary visual element.
   * UI controls should disappear when they aren't needed.

2. **Warm, not sterile**

   * Avoid pure white and pure black.
   * Use warm neutrals and restrained accent colors.

3. **Typography creates hierarchy**

   * Prefer size, weight, spacing, and color over borders and cards.

4. **Quiet surfaces**

   * Minimal shadows.
   * Minimal borders.
   * Subtle changes in surface tone.

5. **Native-feeling, but distinctive**

   * Follow platform interaction conventions.
   * Don't let Material components dictate the visual identity.

6. **Writing should feel luxurious**

   * Generous line height.
   * Comfortable reading width.
   * Excellent cursor, selection, keyboard, and scrolling behavior.

---

# 2. Color System

Colors are deliberately muted.

## Light Theme

```text
Background       #F7F6F2
Surface          #FBFAF7
Elevated         #FFFFFF

Text Primary     #292824
Text Secondary   #77736C
Text Tertiary    #A6A29B

Divider          #E8E5DF
Selection        #E8DDD9

Accent           #D65F55
Accent Dark      #B94B43
Accent Soft      #F1DAD6

Tag Background   #ECE9E3
Tag Text         #68645D

Success          #6F9275
Warning          #C18A4A
Error            #C95D57
```

### Usage

The accent color should **not** be everywhere.

Use it primarily for:

* active controls
* selected navigation
* links
* tags when appropriate
* important interactive states
* cursor/focus indicators

Most of the application should remain neutral.

---

# 3. Dark Theme

Dark mode should feel like **dark paper**, not OLED black.

```text
Background       #1D1C1A
Surface          #242320
Elevated         #2B2926

Text Primary     #E8E5DE
Text Secondary   #AAA69E
Text Tertiary    #77736C

Divider          #37342F
Selection        #463A36

Accent           #E4776D
Accent Dark      #D26259
Accent Soft      #3D2926

Tag Background   #302E2A
Tag Text         #B8B3AA

Success          #86A88A
Warning          #D09A58
Error            #DF7169
```

Never use `#000000` as the main background.

---

# 4. Typography

Typography is one of the most important parts of the identity.

Use the platform's excellent system font rather than introducing a decorative font.

## UI Font

```text
Font family: platform system sans-serif
```

Flutter:

```dart
fontFamily: 'system'
```

The exact platform font can vary between Android versions.

## UI Scale

```text
Display       32 / 38   weight 700
Title         24 / 30   weight 700
Headline      20 / 26   weight 650
Body Large    18 / 28   weight 400
Body          16 / 25   weight 400
Body Small    14 / 20   weight 400
Caption       12 / 17   weight 500
```

## Editor Typography

The editor should be larger than ordinary application UI.

```text
Note title        30 / 36
H1                26 / 33
H2                22 / 29
H3                19 / 26
Body              18 / 29
Quote             18 / 29
Code              15 / 23
Caption           14 / 20
```

The goal is **comfortable long-form reading**, not maximum information density.

---

# 5. Reading Width

The editor should not stretch indefinitely on tablets or landscape phones.

```text
Phone:
horizontal padding: 24dp

Large phone:
horizontal padding: 32dp

Tablet:
maximum content width: 720dp
```

For very large screens:

```text
max editor width = 760dp
```

The note should remain visually centered.

---

# 6. Spacing

Use a 4dp base grid.

```text
4dp     Micro
8dp     Small
12dp    Compact
16dp    Default
20dp    Comfortable
24dp    Large
32dp    Section
40dp    Major
48dp    Hero
64dp    Editorial
```

The app should generally feel **more spacious than a typical Material application**.

---

# 7. Shapes

Avoid excessive rounded cards.

```text
Small controls       8dp
Buttons              10dp
Menus                12dp
Sheets               16dp
Large surfaces       18dp
```

Notes themselves should **not** normally appear inside cards.

A note list should feel like a document library rather than a dashboard.

---

# 8. Elevation

Use elevation extremely sparingly.

Preferred hierarchy:

```text
background
    ↓
surface color
    ↓
slightly elevated surface
```

rather than:

```text
background
    ↓
card
    ↓
large shadow
```

Shadows:

```text
Toolbar:       0–2dp
Popup:         4–8dp
Bottom sheet:  8–16dp
```

Most UI elements should have **zero elevation**.

---

# 9. Icons

Use a consistent, simple icon family.

Characteristics:

* thin/medium stroke
* rounded geometry
* monochrome
* 20–24dp
* no decorative icon backgrounds unless necessary

Standard sizes:

```text
Small       16dp
Default     20dp
Primary     24dp
Large       28dp
```

Icons should generally use:

```text
Text Secondary
```

and become:

```text
Accent
```

only for active states.

---

# 10. Navigation

The navigation system should be deliberately quiet.

## Phone

Primary structure:

```text
┌─────────────────────────┐
│ Notes             🔍    │
│                         │
│ Today                   │
│   Project ideas         │
│   Things to remember   │
│                         │
│ Yesterday               │
│   Morning thoughts      │
│   Book notes            │
│                         │
│                         │
│                     ＋   │
└─────────────────────────┘
```

The list should dominate the screen.

## Tablet

Use a split layout:

```text
┌──────────────┬──────────────────────────────┐
│ Notes        │                              │
│              │       Note title             │
│ Today        │                              │
│  Note one    │       Note content...        │
│  Note two    │                              │
│              │                              │
│ Yesterday    │                              │
│  Note three  │                              │
└──────────────┴──────────────────────────────┘
```

The sidebar should be around:

```text
280–320dp
```

---

# 11. Note List

Don't use conventional Material cards.

Each row should be essentially:

```text
Title
Preview text
Metadata / tags
```

Example:

```text
Ideas for the new app
I think the editor should feel more like...
#design   #ideas
```

Suggested dimensions:

```text
Horizontal padding: 20–24dp
Vertical padding:   14–18dp
Title:              16–17sp / medium
Preview:            14–15sp
Metadata:           12–13sp
```

The title gets the strongest contrast.

---

# 12. Tags

Tags are an important part of the visual language.

They should feel like **textual metadata**, not colorful pills.

Preferred:

```text
#ideas   #flutter   #design
```

rather than:

```text
[ IDEAS ] [ FLUTTER ] [ DESIGN ]
```

If a background is used:

```text
Tag Background
#ECE9E3
```

with:

```text
8–10dp horizontal padding
4–6dp vertical padding
8dp radius
```

Avoid giving every tag a different color.

---

# 13. Editor

This is the most important screen.

When editing, reduce visual noise.

```text
                     ⋯

My Note

This is where the writing begins.

The interface should feel almost
invisible while I'm thinking.

#ideas  #writing
```

### Editor rules

* No heavy toolbar permanently occupying space.
* Keep title visually distinct.
* Large comfortable body text.
* Generous line spacing.
* Minimal chrome.
* Smooth scrolling.
* Preserve cursor position.
* Keyboard should not cause visual jumps.
* Support selection handles naturally.
* Contextual formatting controls should appear when useful.

---

# 14. Markdown Presentation

Markdown syntax should not visually overwhelm the writing experience.

For example:

```text
# My Heading
```

should render visually as:

```text
My Heading
```

while editing can preserve the underlying Markdown.

Formatting should feel **semantic rather than technical**.

### Visual hierarchy

```text
H1
26sp / bold

H2
22sp / bold

H3
19sp / semibold

Body
18sp / regular

Quote
18sp / regular
muted + subtle accent line

Code
15sp / monospace
soft surface background
```

---

# 15. Formatting Toolbar

The toolbar should be compact.

```text
┌─────────────────────────────────────┐
│ B   I   S   •   H   "   `   🔗    │
└─────────────────────────────────────┘
```

But don't permanently show it if the design can avoid it.

Prefer:

* selection-triggered formatting
* keyboard-aware toolbar
* small bottom formatting bar
* contextual menus

The user should spend more time looking at the note than the toolbar.

---

# 16. Search

Search should feel instant.

Initial state:

```text
Search notes
```

When active:

```text
←   Search notes...
```

Results should preserve the same typography as the note list.

Highlight matches subtly:

```text
Project
ideas for the new app
```

Use accent color sparingly for the matched text.

---

# 17. Buttons

Avoid large, loud buttons.

Primary action:

```text
+ New Note
```

can simply become:

```text
＋
```

in the main interface.

For explicit actions:

```text
Create note
Delete note
Export
```

use quiet filled/tonal controls.

Primary accent should be reserved for genuinely primary actions.

---

# 18. Floating Action Button

Do not automatically use the standard Material FAB.

Instead:

```text
                         ＋
```

with a small circular or softly rounded surface.

It should feel like part of the application rather than a Material component dropped into it.

---

# 19. Motion

Animation should communicate state rather than attract attention.

```text
Fast interaction:     120ms
Normal transition:    180ms
Major transition:     240ms
```

Use:

* ease-out for entering
* ease-in for leaving
* subtle fade
* small scale changes
* shared-element transitions only where useful

Avoid:

* bouncing
* excessive spring physics
* large transforms
* decorative animations

The app should feel **calm**.

---

# 20. Empty States

Avoid giant illustrations.

Example:

```text
No notes yet

Start writing something.
```

That's enough.

The product's personality comes from typography and spacing.

---

# 21. Context Menus

Long press / overflow menus should contain actions such as:

```text
Pin
Duplicate
Move
Export
Delete
```

Menus should use:

```text
Surface
12dp radius
subtle elevation
16dp row height/padding
```

Destructive actions use the error color.

---

# 22. Accessibility

The aesthetic should never compromise usability.

Minimum targets:

```text
Touch target: 48 × 48dp
```

Support:

* Android font scaling
* screen readers
* sufficient contrast
* keyboard navigation where applicable
* reduced motion
* dynamic layout on tablets/foldables

The visual design can be quiet without making controls difficult to use.

---

# 23. Flutter Theme Structure

The visual tokens should exist independently of widgets.

```dart
abstract final class AppColors {
  static const background = Color(0xFFF7F6F2);
  static const surface = Color(0xFFFBFAF7);
  static const elevated = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF292824);
  static const textSecondary = Color(0xFF77736C);
  static const textTertiary = Color(0xFFA6A29B);

  static const divider = Color(0xFFE8E5DF);

  static const accent = Color(0xFFD65F55);
  static const accentDark = Color(0xFFB94B43);
  static const accentSoft = Color(0xFFF1DAD6);

  static const tagBackground = Color(0xFFECE9E3);
  static const tagText = Color(0xFF68645D);
}
```

Then:

```dart
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}
```

And:

```dart
abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 18.0;
}
```

---

# 24. The Golden Rule

When deciding between two UI implementations:

> **Choose the one that makes the interface less noticeable.**

If a user is thinking:

> "Wow, what a beautiful toolbar."

the toolbar may be too prominent.

If they're thinking:

> "I really like writing in this."

the design is working.

The goal is not to make a **Bear-looking app**.

The goal is to create the same feeling:

**open → write → disappear into the content.**
