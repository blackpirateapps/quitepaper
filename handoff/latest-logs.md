# Quiet Paper — Latest Engineering Logs (v1.6.0+ / October 2026 – Present)

> Active development logs, architecture decisions, and bugfixes for Quiet Paper v1.6.0 and beyond.
> New handoff entries should be appended to this file. For the master handoff index, see [INDEX.md](INDEX.md).

---

## 132. App Version Bump to 1.6.0 (Build 18)

### 1. Overview & Motivation
Bumped the official application version from `1.5.9+17` to `1.6.0+18`. In addition to updating `pubspec.yaml`, synchronized all hardcoded application version strings that were previously lingering at `1.5.8` across the update checker, backup metadata, device information, settings display, export envelopes, and HTTP client user agents.

### 2. File Updates
- [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml): Updated version from `1.5.9+17` to `1.6.0+18`.
- [`lib/features/settings/presentation/settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart): Updated version label in the About section from `Version 1.5.8` to `Version 1.6.0`.
- [`lib/core/update/update_provider.dart`](file:///home/dog/git/quitepaper/lib/core/update/update_provider.dart): Updated `currentVersion` from `'1.5.8'` to `'1.6.0'` so GitHub release update checking accurately compares against new tags.
- [`lib/core/backup/backup_service.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart) & [`lib/core/backup/backup_provider.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_provider.dart): Updated backup archive metadata version to `'1.6.0'`.
- [`lib/core/device/device_info_service.dart`](file:///home/dog/git/quitepaper/lib/core/device/device_info_service.dart): Updated default `appVersion` parameter for device registration to `'1.6.0'`.
- [`lib/core/location/location_service.dart`](file:///home/dog/git/quitepaper/lib/core/location/location_service.dart): Updated HTTP `User-Agent` header to `QuitePaper/1.6.0`.
- [`lib/features/export/application/exporters/qpnote_exporter.dart`](file:///home/dog/git/quitepaper/lib/features/export/application/exporters/qpnote_exporter.dart): Updated manifest and encrypted envelope `appVersion` metadata to `'1.6.0'`.

### 3. Verification & Quality
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Automated tests: `flutter test` across settings, update dialogs, backups, device management, and exports (**125/125 passing**).

---

## 133. Automated CI Build Numbers (Git Commit Count) & Dynamic Runtime Version Resolution

### 1. Overview & Motivation
Prior to this enhancement, application version codes and build numbers were manually maintained in `pubspec.yaml` and hardcoded across various in-app components. Every commit pushed to GitHub Actions resulted in APKs and AABs compiled with the exact same `versionCode`, leading to Android Package Manager and Google Play update rejections ("App not installed: An existing package by the same name with a conflicting signature or version code is already installed") unless manually bumped.

### 2. Architectural & Workflow Enhancements

#### Automated Build Numbers in CI Workflows
- In all GitHub Actions build workflows ([`.github/workflows/build_apk.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_apk.yml), [`.github/workflows/build_aab.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_aab.yml), [`.github/workflows/release.yml`](file:///home/dog/git/quitepaper/.github/workflows/release.yml), and [`.github/workflows/build_linux.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_linux.yml)):
  - Configured `actions/checkout@v4` with `fetch-depth: 0` to fetch full git commit history.
  - Dynamically resolved the build number using `BUILD_NUMBER=$(git rev-list --count HEAD)`.
  - Injected `--build-name="$VERSION_NAME"` and `--build-number="$BUILD_NUMBER"` into `flutter build apk`, `flutter build appbundle`, and `flutter build linux`.
  - Because `git rev-list --count HEAD` strictly increments on each commit (e.g. 263 -> 264 -> 265), Android's `versionCode` monotonically increases without manual intervention.
  - APK artifacts are named with the build number (e.g. `quiet-paper-1.6.0-b264-arm64-v8a.apk`) for immediate traceability.

#### Dynamic Runtime Version Resolution (`package_info_plus`)
- Added `package_info_plus: ^9.0.1` as a direct dependency in [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml).
- Implemented [`AppVersionInfo`](file:///home/dog/git/quitepaper/lib/core/version/app_version_provider.dart) model and Riverpod providers:
  - `packageInfoProvider`: Defaults to safe fallback values (`version: '1.6.0'`, `buildNumber: '0'`) for unit and widget tests, avoiding the need for boilerplate overrides in tests.
  - `appVersionInfoProvider`: Exposes parsed `version`, `buildNumber`, `displayVersion` (`"Version 1.6.0 (264)"`), and `fullVersion` (`"1.6.0+264"`).
- In [`lib/main.dart`](file:///home/dog/git/quitepaper/lib/main.dart): Resolved `PackageInfo.fromPlatform()` at app startup and overrode `packageInfoProvider` in the root `ProviderScope`.
- Migrated all in-app services to read dynamically:
  - **[`SettingsScreen`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart)**: About section renders `${appVersionInfo.displayVersion}` (`Version 1.6.0 (264)`).
  - **[`UpdateService`](file:///home/dog/git/quitepaper/lib/core/update/update_provider.dart)**: Injects `versionInfo.version` for comparing with GitHub release tags.
  - **[`BackupService`](file:///home/dog/git/quitepaper/lib/core/backup/backup_provider.dart)**: Injects `versionInfo.fullVersion` into backup archive manifests.
  - **[`DeviceInfoService`](file:///home/dog/git/quitepaper/lib/core/device/device_info_service.dart)**: Injects dynamic `versionInfo.version` for device registration.
  - **[`LocationService`](file:///home/dog/git/quitepaper/lib/core/location/location_service.dart)**: Dynamically formats `User-Agent: QuitePaper/${version}` header.
  - **[`QpNotePackageExporter`](file:///home/dog/git/quitepaper/lib/features/export/application/export_provider.dart)**: Uses dynamic version for package manifests and encrypted envelopes.

### 3. File Inventory
- **New Files**:
  - `lib/core/version/app_version_provider.dart`: `AppVersionInfo` domain class, `packageInfoProvider`, and `appVersionInfoProvider`.
  - `test/version/app_version_test.dart`: Unit tests for `AppVersionInfo`, formatting helpers, and Riverpod provider overrides.
- **Updated Files**:
  - `pubspec.yaml` & `pubspec.lock`: Promoted `package_info_plus` to direct dependency.
  - `lib/main.dart`: Platform package info resolution and provider override.
  - `lib/features/settings/presentation/settings_screen.dart`: Dynamic version display in About section.
  - `lib/core/update/update_provider.dart`: Dynamic `currentVersion` injection.
  - `lib/core/backup/backup_provider.dart`: Dynamic `appVersion` injection into `BackupService`.
  - `lib/core/device/device_info_service.dart`: Dynamic `appVersion` injection into `DeviceInfoService`.
  - `lib/core/location/location_service.dart`: Dynamic User-Agent header version formatting.
  - `lib/features/export/application/export_provider.dart` & `exporters/qpnote_exporter.dart`: Dynamic version in `.qpnote` exports.
  - `.github/workflows/build_apk.yml`, `.github/workflows/build_aab.yml`, `.github/workflows/release.yml`, `.github/workflows/build_linux.yml`: Added `fetch-depth: 0`, `BUILD_NUMBER=$(git rev-list --count HEAD)`, and `--build-name`/`--build-number` parameters.

### 4. Verification & Quality
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Automated tests: `flutter test` across versioning, settings, update checks, backups, devices, and exports (**130/130 passing**).
## 135. Image Compression on Upload with Quick Dialog, Remember Choice & Settings

### 1. Overview & Motivation
Previously, adding images to a note—whether through the attachment file picker, clipboard paste (raw image bytes or copied files), or desktop drag-and-drop—stored images in their raw, full uncompressed size. High-resolution photos from modern smartphones and cameras (often 5–20 MB each) rapidly bloated local database storage and significantly slowed down client-side encrypted cloud synchronization.

To solve this, a production-grade, non-blocking image compression system was implemented:
1. **Intelligent Thresholding**: Only images larger than 500 KB trigger compression processing or prompts; smaller images ($\le$ 500 KB) bypass dialogs and are imported as-is.
2. **Editorial Prompt with Remember My Choice**: When inserting an image $> 500$ KB under default settings, a clean dialog displays image metadata (filename, byte size, resolution) and lets the user choose between **Compress & Optimize** (recommended) or **Keep Original**, with a **Remember my choice** checkbox.
3. **Isolate-Based Background Processing**: Heavy image decoding, EXIF orientation correction (`img.bakeOrientation`), aspect-ratio downscaling, and JPEG/PNG encoding run on background worker isolates via `compute()`, guaranteeing the UI thread remains 100% fluid.
4. **Configurable Default Settings**: Users can manage default compression behavior (*Ask every time*, *Always compress*, *Keep original*) and compression quality presets (*Balanced*, *High Quality*, *Compact*) in `Settings → Default Settings`.

### 2. Architecture & Implementation Details

#### A. Domain Models & Settings Persistence
- **[`lib/features/settings/domain/default_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/default_settings.dart)**:
  - `ImageCompressionAction`: Enum representing action on image import:
    - `ask` (`'ask'`, default): Displays `ImageCompressionDialog` for images $> 500$ KB.
    - `alwaysCompress` (`'always_compress'`): Compresses automatically according to selected preset without prompting.
    - `keepOriginal` (`'keep_original'`): Preserves full raw resolution without prompting.
  - `ImageCompressionPreset`: Enum representing compression quality:
    - `balanced` (default): Max dimension 1920px, JPEG quality 80%.
    - `highQuality`: Max dimension 2560px, JPEG quality 85%.
    - `compact`: Max dimension 1280px, JPEG quality 70%.
  - Added fields, `copyWith`, equality, and hash code to `DefaultSettings`.
- **[`lib/features/settings/application/default_settings_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/default_settings_provider.dart)**:
  - Added persistence keys `setting_image_compression_action` and `setting_image_compression_preset`.
  - Added `setImageCompressionAction` and `setImageCompressionPreset` methods persisting changes to `SharedPreferences`.

#### B. Image Processing Service
- **[`lib/core/image_processing/image_compression_service.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/image_compression_service.dart)**:
  - `ImageCompressionService`: Defines contract for `isEligibleForCompression(int byteSize)`, `probeDimensions(Uint8List rawBytes)`, and `compressImage(...)`.
  - `DefaultImageCompressionService`: Pure-Dart implementation using `package:image`:
    - `probeDimensions`: Probes image dimensions in an isolate without altering bytes.
    - `compressImage`:
      - Runs decoding, EXIF orientation baking (`bakeOrientation`), downscaling, and encoding in a background isolate via `compute()`.
      - **Alpha Transparency Preservation**: Detects PNG images with alpha channel (`image.hasAlpha`) and re-encodes to optimized PNG (level 6) to avoid black backgrounds. Non-alpha images encode to optimized JPEG.
      - **Size Invariant Safeguard**: If compressed output is greater than or equal to original size, the original bytes are retained (`wasCompressed: false`).
      - In case of malformed or corrupted bytes, gracefully falls back to original bytes without throwing or crashing.
  - Exposed via Riverpod `imageCompressionServiceProvider`.

#### C. Editorial Image Compression Dialog
- **[`lib/features/editor/presentation/widgets/image_compression_dialog.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/image_compression_dialog.dart)**:
  - `ImageCompressionDialog`: AlertDialog styled with Warm Editorial tokens (`context.appColors`).
  - Metadata card displaying filename, formatted byte size (`KB`/`MB`), and pixel dimensions.
  - Selectable cards for **Compress & Optimize** (with "Recommended" pill badge and space-savings estimate) and **Keep Original**.
  - **Remember my choice** checkbox: when confirmed, automatically persists choice to `DefaultSettingsNotifier`.

#### D. Editor Screen Integration
- **[`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)**:
  - Added helper `_prepareImageForImport(...)` which resolves MIME type, checks size threshold, queries `defaultSettingsProvider`, prompts the dialog if needed, persists "remember choice", and executes compression.
  - Unified across all image entry points:
    1. `_handleInsertImage()`: File picker image selection.
    2. `_handlePaste()`: Clipboard image files and raw clipboard image bytes.
    3. `_handleDroppedFiles()`: Desktop drag-and-drop file transfers.

#### E. Settings Screen UI
- **[`lib/features/settings/presentation/default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart)**:
  - Added new `IMAGE ATTACHMENTS` section to the iOS Grouped Table.
  - Added rows for:
    - **Default Compression**: Shows current action (*Ask every time*, *Always compress*, *Keep original*) with chevron; opens bottom modal selection sheet.
    - **Compression Quality**: Shows current preset (*Balanced*, *High Quality*, *Compact*) with chevron; opens bottom modal selection sheet.

### 3. File Inventory
- **Modified**:
  - [`lib/features/settings/domain/default_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/default_settings.dart): Compression action & preset enums and domain fields.
  - [`lib/features/settings/application/default_settings_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/default_settings_provider.dart): SharedPreferences persistence.
  - [`lib/features/settings/presentation/default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart): UI rows and modal picker sheets.
  - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart): Integration across file picker, pasteboard, and drag-and-drop.
  - [`test/settings/default_settings_test.dart`](file:///home/dog/git/quitepaper/test/settings/default_settings_test.dart): Unit and widget tests for new domain fields and settings screen rows.
- **New**:
  - [`lib/core/image_processing/image_compression_service.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/image_compression_service.dart): Isolate-based compression service.
  - [`lib/features/editor/presentation/widgets/image_compression_dialog.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/image_compression_dialog.dart): Compression dialog widget.
  - [`test/image_processing/image_compression_service_test.dart`](file:///home/dog/git/quitepaper/test/image_processing/image_compression_service_test.dart): Unit tests for compression service.
  - [`test/editor/image_compression_dialog_test.dart`](file:///home/dog/git/quitepaper/test/editor/image_compression_dialog_test.dart): Widget tests for compression dialog.
  - [`test/editor/editor_image_upload_compression_test.dart`](file:///home/dog/git/quitepaper/test/editor/editor_image_upload_compression_test.dart): Integration tests for editor image drop, dialog trigger, remember choice, and settings bypass.

### 4. Verification & Quality
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Automated tests:
  - Feature test suite: `flutter test test/settings/default_settings_test.dart test/image_processing/image_compression_service_test.dart test/editor/image_compression_dialog_test.dart test/editor/editor_image_upload_compression_test.dart` (**32/32 passing**).
  - Full repository test suite: `flutter test` (**1596/1596 passing**).


---

## 136. Production-Grade RichDocument Visual Editor Architecture

### 1. Problem & Architectural Motivation
Previously, Visual/WYSIWYG editing in Quiet Paper relied on a hybrid approach where every block in the document was rendered as an independent `TextField` widget with separate `TextEditingController` and `FocusNode` instances, mapping selections through source-range offsets in the underlying Markdown string. This architecture had inherent limitations:
- **Focus & Caret Churn**: Tapping between blocks or pressing Up/Down arrow keys jumped focus between independent `TextField`s, causing caret stuttering, IME reset, and keyboard flicker on mobile.
- **Selection Fragmentation**: Text selection could not span smoothly across block boundaries (e.g. from a heading into a paragraph or across list items).
- **String-Rewriting Overhead**: Every keystroke performed regex parsing and string replacements against the canonical Markdown string, creating race conditions during fast typing.

To resolve this, a production-grade, authoritative rich-text document architecture was implemented following the specifications in `new-visual-architechture.txt`.

### 2. Core Invariants & Design Principles
1. **RichDocument is Authoritative in Visual Mode**: In Visual mode, the in-memory `RichDocument` is the single source of truth. Mutations (inline styling, block conversion, checklist toggling, Enter/Backspace) operate directly on structured domain models without touching Markdown strings.
2. **Markdown as Interchange & Storage Format**: Markdown is used strictly at boundaries:
   - When opening or switching to Visual mode (`RichDocumentParser.parse()`).
   - When autosaving to local storage (`RichDocumentController.toMarkdown()` debounced at 700ms).
   - When switching to Markdown mode or exiting the editor (`_flushRichMarkdown()`).
3. **Continuous Paper Writing Surface**: Contiguous text blocks (paragraphs, headings, lists, quotes) are rendered within a unified, continuous `RichTextEditor` surface. The user experiences a seamless document with native-feeling selection, arrow navigation, copy/paste, and IME composition.
4. **Zero Compromise on Existing Features**: Full fidelity was preserved for YAML frontmatter preservation, image attachments, table editing, syntax-highlighted code blocks, note links, tags, autosave, undo/redo, and end-to-end encrypted synchronization.

### 3. Architecture & Implementation Details

#### A. Domain Layer (`lib/features/editor/domain/`)
- **[`text_attributes.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/text_attributes.dart)**:
  - Immutable record of styling attributes: `bold`, `italic`, `strike`, `highlight`, `inlineCode`, `link`, `noteLink`, `tag`.
  - Methods `merge()`, `diff()`, `copyWith()`, and empty singleton `TextAttributes.none`.
- **[`rich_inline.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_inline.dart)**:
  - `RichInlineSpan`: Represents an atomic text run with associated `TextAttributes`.
  - `List<RichInlineSpan>.normalized()`: Combines adjacent spans with identical attributes and strips empty spans.
  - Span slicing and range replacement utilities.
- **[`rich_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_block.dart)**:
  - Structural block hierarchy inheriting from abstract immutable `RichBlock`:
    - `ParagraphBlock`: Regular text paragraphs.
    - `HeadingBlock`: Headings from level 1 to 6.
    - `ChecklistItemBlock`: Checklists with boolean `isChecked` status and toggle support.
    - `BulletedListItemBlock`: Bulleted list items with indentation support.
    - `OrderedListItemBlock`: Numbered list items with sequential ordering and indentation.
    - `QuoteBlock`: Blockquotes.
    - `CodeBlock`: Monospace fenced code blocks with language tag.
    - `HorizontalRuleBlock`: Divider blocks.
    - `ImageBlock`: Standalone images with `url` and `alt` text.
    - `TableBlock`: Interactive tables embedding `MarkdownTable`.
- **[`document_selection.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/document_selection.dart)**:
  - `RichDocumentPosition`: Discrete cursor position (`blockIndex`, `blockId`, `offset`).
  - `RichDocumentSelection`: Document-wide selection range (`base`, `extent`, `start`, `end`, `isCollapsed`).
- **[`rich_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_document.dart)**:
  - Authoritative document model holding `List<RichBlock> blocks`.
  - Global offset and document position bidirectional mapping.
  - Block lookups and immutable replacement helpers.
- **[`editor_editing_style.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/editor_editing_style.dart)**:
  - Updated user-facing display label for WYSIWYG mode to `'Visual'`.

#### B. Application Layer (`lib/features/editor/application/`)
- **[`rich_document_parser.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_parser.dart)**:
  - Pure-Dart compiler converting canonical Markdown source into a structured `RichDocument`.
  - Handles fenced code blocks, tables, horizontal rules, standalone images, headings (H1–H6), checklists, bullet/ordered lists, blockquotes, and paragraphs.
  - Inline syntax parser extracting bold (`**`, `__`), italic (`*`, `_`), strikethrough (`~~`), highlights (`==`), inline code (`` ` ``), Markdown links, note links (`[[...]]`), and tags (`#...`).
- **[`rich_document_serializer.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_serializer.dart)**:
  - Deterministic serializer emitting canonical Markdown from `RichDocument`.
  - Ensures 100% round-trip fidelity with proper blank line spacing between structural blocks.
- **[`rich_document_mutations.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_mutations.dart)**:
  - Pure functional document transforms:
    - Inline formatting toggles across selection ranges.
    - Block style conversions (paragraph $\leftrightarrow$ heading $\leftrightarrow$ checklist $\leftrightarrow$ quote).
    - Smart Enter: continues list/checklist items, exits on empty item, splits headings to paragraphs.
    - Smart Backspace: un-indents lists, converts non-paragraphs to paragraphs at offset 0, and merges adjacent blocks.
    - Block insertions (code blocks, dividers, images, tables).
- **[`rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart)**:
  - Primary coordinator for Visual mode editing sessions.
  - In-memory undo/redo history stack (`_EditorSnapshot`).
  - Selection tracking and active typing attributes for collapsed carets.
  - Surgical YAML frontmatter preservation: strips frontmatter for visual editing canvas while maintaining the exact frontmatter prefix on serialize.

#### C. Presentation Layer (`lib/features/editor/presentation/widgets/`)
- **[`rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart)**:
  - Continuous editing surface using custom `_RichTextEditingController`.
  - Composes `TextSpan` styling for headings, quotes, bold, italic, code, highlights, links, and tags.
  - Embeds interactive checkbox icons (`WidgetSpan`) for checklist items with hit-testing and tap-toggle.
  - Intercepts Enter, Backspace, Tab, and keyboard shortcuts (`Cmd/Ctrl+B`, `Cmd/Ctrl+I`, `Cmd/Ctrl+K`).
- **[`rich_editor_surface.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_editor_surface.dart)**:
  - Composes contiguous text blocks into `RichTextEditor` segments while interleaving specialized non-text blocks (`RichCodeBlock`, `RichTableEditor`, `RichImageBlock`, `_DividerBlock`).
- **[`rich_code_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_code_block.dart)**:
  - Code block widget with language badge, code copy button, and `LanguageSelectorSheet` modal picker.
- **[`rich_table_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_table_editor.dart)**:
  - Table surface embedding `MarkdownTableView` with interactive row/column insertion and deletion.
- **[`rich_image_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_image_block.dart)**:
  - Semantic image preview displaying image surface, alt title, url reference, and remove button.
- **[`formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart)**:
  - Updated to accept `RichDocumentController? richController` and route heading cycles, bold, italic, lists, quotes, tables, and images directly to the rich controller.
- **[`markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart)** & **[`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)**:
  - Integrated `RichDocumentController` lifecycle alongside existing Markdown controllers.
  - Automated fallback to Markdown mode when notes exceed the large-document threshold.
  - Robust deactivation guards protecting Riverpod providers during widget unmounts.

### 4. File Inventory
- **New Domain & Application Files**:
  - [`lib/features/editor/domain/text_attributes.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/text_attributes.dart)
  - [`lib/features/editor/domain/rich_inline.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_inline.dart)
  - [`lib/features/editor/domain/rich_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_block.dart)
  - [`lib/features/editor/domain/document_selection.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/document_selection.dart)
  - [`lib/features/editor/domain/rich_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_document.dart)
  - [`lib/features/editor/application/rich_document_parser.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_parser.dart)
  - [`lib/features/editor/application/rich_document_serializer.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_serializer.dart)
  - [`lib/features/editor/application/rich_document_mutations.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_mutations.dart)
  - [`lib/features/editor/application/rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart)
  - [`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart)
  - [`lib/features/editor/presentation/widgets/rich_editor_surface.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_editor_surface.dart)
  - [`lib/features/editor/presentation/widgets/rich_code_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_code_block.dart)
  - [`lib/features/editor/presentation/widgets/rich_table_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_table_editor.dart)
  - [`lib/features/editor/presentation/widgets/rich_image_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_image_block.dart)
  - [`test/editor/rich_document_parser_serializer_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_document_parser_serializer_test.dart)
  - [`test/editor/rich_document_controller_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_document_controller_test.dart)
- **Modified Files**:
  - [`lib/features/editor/domain/editor_editing_style.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/editor_editing_style.dart)
  - [`lib/features/editor/presentation/widgets/formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart)
  - [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart)
  - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)
  - [`test/editor/dual_mode_editor_screen_test.dart`](file:///home/dog/git/quitepaper/test/editor/dual_mode_editor_screen_test.dart)
  - [`test/editor/editing_style_settings_test.dart`](file:///home/dog/git/quitepaper/test/editor/editing_style_settings_test.dart)
  - [`test/editor/golden_document_integration_test.dart`](file:///home/dog/git/quitepaper/test/editor/golden_document_integration_test.dart)
  - [`test/widget_test.dart`](file:///home/dog/git/quitepaper/test/widget_test.dart)

### 5. Verification & Quality
- Static analysis: `flutter analyze` completed with **0 issues found!** (zero errors, zero warnings).
- Automated tests: `flutter test` completed with **1620/1620 tests passing!** (100% pass rate).

---

## 137. Complete Deprecation and Removal of Legacy Semantic WYSIWYG Architecture

### 1. Problem & Motivation
Following the implementation and stabilization of the new `RichDocument` continuous paper editor (Section 136, per `new-visual-architechture.txt` Sections 36 & 42), the codebase still retained the legacy semantic block editor files and dual controller routing. Specifically:
- `SemanticEditorController`, `SemanticDocument`, `SemanticNodes`, `SemanticMarkdownParser`, `SemanticMutationService`, `SourceRange`, `DocumentPosition`, and `VisualDocumentEditor` were still present in the codebase.
- Presentation widgets (`MarkdownEditor`, `EditorScreen`, `FormattingToolbar`) retained duplicate routing pathways, fallback parameters (`semanticController`, `onSemanticControllerChanged`), and listener attachments.
- Unit tests contained duplicate and obsolete test files validating deprecated regex-based mutations and per-block `TextField` widgets.

In this update, the legacy WYSIWYG architecture was cleanly and completely removed, unifying visual editing exclusively under `RichDocumentController` and `RichEditorSurface`.

### 2. Changes & File Cleanups

#### A. Production Cleanups (`lib/`)
1. **Formatting Toolbar ([`formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart))**:
   - Removed `semanticController` and `SemanticEditorController` import.
   - Removed dual listener subscriptions and semantic fallback branching.
   - All visual formatting operations route purely to `richController`, falling back to `controller` in Markdown mode.
2. **Markdown Editor ([`markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart))**:
   - Removed `_semanticController`, `onSemanticControllerChanged`, `_initSemanticController()`, and `_onSemanticMarkdownChanged()`.
   - Removed `VisualDocumentEditor` imports and conditional rendering branch. Visual mode exclusively renders `RichEditorSurface`.
   - Wired large-document threshold checks and mode fallback directly to `RichDocumentController.isDocumentTooLargeForWysiwyg()`.
3. **Editor Screen ([`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart))**:
   - Removed `_semanticEditorController` state field, imports, and passing of semantic controller props.
   - Removed legacy semantic branches from formatting shortcuts, autocomplete handlers (tags, note links), and snippet insertions.
4. **Rich Document Controller ([`rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart))**:
   - Added `maxWysiwygCharacters`, `largeDocumentThresholdCharacters`, `largeDocumentThresholdLines`.
   - Added static helper `isDocumentTooLargeForWysiwyg(text)`.
   - Added `exceedsWysiwygThreshold` and `hasFrontmatter` convenience getters.
5. **Deleted 8 Obsolete Legacy Files**:
   - `lib/features/editor/application/semantic_markdown_parser.dart`
   - `lib/features/editor/application/semantic_mutation_service.dart`
   - `lib/features/editor/application/semantic_editor_controller.dart`
   - `lib/features/editor/domain/semantic_document.dart`
   - `lib/features/editor/domain/semantic_nodes.dart`
   - `lib/features/editor/domain/source_range.dart`
   - `lib/features/editor/domain/document_position.dart`
   - `lib/features/editor/presentation/widgets/visual_document_editor.dart`

#### B. Test Suite Migrations & Cleanups (`test/`)
1. **Golden Document Test ([`golden_document_integration_test.dart`](file:///home/dog/git/quitepaper/test/editor/golden_document_integration_test.dart))**:
   - Fully migrated to `RichDocumentParser`, `RichDocumentController`, and `RichEditorSurface`.
   - Validated CommonMark table serialization formatting and lossless visual mode switching.
2. **Heading Widget Test ([`markdown_heading_widget_test.dart`](file:///home/dog/git/quitepaper/test/editor/markdown_heading_widget_test.dart))**:
   - Removed legacy `VisualDocumentEditor` and `SemanticEditorController` test groups while preserving `MarkdownHeadingBadge` and `MarkdownHeadingActionSheet` widget tests.
3. **Large Document Performance Test ([`wysiwyg_large_document_performance_test.dart`](file:///home/dog/git/quitepaper/test/editor/wysiwyg_large_document_performance_test.dart))**:
   - Migrated to test `RichDocumentController.isDocumentTooLargeForWysiwyg` and `MarkdownEditor` automatic fallback to Markdown mode.
4. **Frontmatter Preservation Test ([`frontmatter_wysiwyg_preservation_test.dart`](file:///home/dog/git/quitepaper/test/editor/frontmatter_wysiwyg_preservation_test.dart))**:
   - Migrated to test `RichDocumentController` frontmatter prefix retention and span mutations.
5. **Deleted 10 Obsolete Legacy Test Files**:
   - `test/editor/semantic_document_model_test.dart`
   - `test/editor/semantic_markdown_parser_test.dart`
   - `test/editor/semantic_mutation_service_test.dart`
   - `test/editor/visual_document_editor_widget_test.dart`
   - `test/editor/visual_document_editor_selection_bugs_test.dart`
   - `test/editor/wysiwyg_heading_and_enter_key_test.dart`
   - `test/editor/wysiwyg_inline_formatting_test.dart`
   - `test/editor/wysiwyg_checklist_test.dart`
   - `test/editor/wysiwyg_divider_test.dart`
   - `test/editor/wysiwyg_table_editing_test.dart`

### 3. Verification & Quality
- Static analysis: `flutter analyze` completed with **0 issues found!** (zero errors, zero warnings).
- Automated tests: `flutter test` fully passed with zero failures across all test suites.

---

## 138. Rich Text Editor — Formattings Verification, Bugfixes & Highlight Integration (October 2026)

### 1. Overview & Objectives
As the visual editing engine migrated exclusively to the `RichDocument` / `RichEditorSurface` architecture, an exhaustive, granular test suite was implemented to test every single formatting type supported by the editor one by one, expose any underlying bugs in mutations and controller typing logic, and fix them with 100% test pass rate.

In addition, Highlight (`==text==`) was fully integrated across the visual engine, the Bear-inspired `FormattingHubSheet` (`Aa` menu), the `FormattingToolbar`, and the main editor keyboard shortcuts (`Ctrl+Shift+H` / `Cmd+Shift+H`).

### 2. Comprehensive Test Suite
Created [`test/editor/rich_text_editor_formattings_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_editor_formattings_test.dart) containing **56 granular tests** across 19 categories:
1. **Bold Formatting (`**text**`)**: Selection toggle, collapsed caret `typingAttributes` toggling, lossless CommonMark round-tripping.
2. **Italic Formatting (`*text*`)**: Selection toggle, collapsed caret typing attributes, parser/serializer round-tripping.
3. **Strikethrough Formatting (`~~text~~`)**: Selection toggle, collapsed caret typing attributes, round-trip serialization.
4. **Highlight Formatting (`==text==`)**: Selection toggle, collapsed caret typing attributes, `==text==` round-tripping.
5. **Inline Code (`` `code` ``)**: Selection toggle, atomic preservation of symbols without stripping backticks.
6. **External Hyperlinks (`[label](url)`)**: Selection replacement, collapsed caret insertion, fallback of empty label to URL.
7. **Wiki Note Links (`[[Note Title]]` / `qp://note/id`)**: Selection replacement, collapsed caret insertion, round-tripping.
8. **Hashtags (`#tag`)**: Selection replacement, collapsed caret insertion, round-tripping.
9. **Composable Inlines**: Combining Bold + Italic (`***text***`), Bold + Strikethrough + Highlight, Bold links (`[**bold**](url)`).
10. **Headings 1 through 6**: Setting level 1-6, cycling (P -> H1 -> H2 -> H3 -> P), Enter key paragraph split, Backspace at index 0 converting to paragraph.
11. **Checklists (`- [ ]`, `- [x]`)**: Toggle paragraph to task item, toggle checkbox checked state, Enter creates new unchecked item, Enter on empty task item exits list, Backspace at index 0 converts to paragraph.
12. **Bulleted Lists (`- item`)**: Toggle item, Enter creates continuation bullet, Enter on empty bullet exits list, nested indentation round-tripping.
13. **Ordered Lists (`1. item`)**: Toggle item, Enter creates incremented numbering (`1.` -> `2.`), Enter on empty item exits list.
14. **Blockquotes (`> quote`)**: Toggle item, Enter creates continuation quote, Enter on empty quote exits list.
15. **Fenced Code Blocks (```` ```lang ````)**: Insert block with paragraph below, verbatim multiline code round-tripping.
16. **Dividers (`---`)**: Insertion creates Divider and trailing paragraph, round-tripping of `---`, `***`, `___`.
17. **Markdown Tables**: Insert table block with row/column dimensions, CommonMark table alignment parsing/serialization.
18. **Images (`![alt](url)`)**: Insert image block, round-tripping of source and title.
19. **Widget Rendering & Typing Preservation**: `RichTextEditor` widget rendering with correct styling, interactive checklist tapping, and character typing inside lines containing pre-formatted spans without formatting loss.

### 3. Bugs Discovered & Resolved
1. **Typing Span Erasure in Visual Block Controller ([`rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart))**:
   - *Problem*: In `_RichTextEditingController.applyTextChangesToDocument`, any single-line keystroke inside a block with formatted spans (e.g., typing a character inside `"Hello **world** test"`) was replacing all spans in the line with `block.spans.first.attributes`, destroying all bold, italic, code, and link spans across the rest of the line.
   - *Fix*: Implemented a diff-based `_spliceSpans` algorithm in `_RichTextEditingController` that finds the exact edit range (`editStart`, `oldLen`, `newText`), preserves all untouched spans before and after the edit, slices the overlapping span, and applies typing attributes to the inserted slice.
2. **Collapsed Selection No-Op on Link, Note Link, and Tag Insertion ([`rich_document_mutations.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_mutations.dart) & [`rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart))**:
   - *Problem*: `applyLink`, `applyNoteLink`, and `applyTag` relied on `_applyAttributeRange`, which returned early without changes when `selection.isCollapsed`.
   - *Fix*: Added `_insertSpanAtPosition` mutation to splice new spans at the caret position. Updated `applyLink`, `applyNoteLink`, and `applyTag` to branch on `selection.isCollapsed`, inserting the span directly at the caret and positioning the cursor immediately after the inserted span. Empty link titles gracefully fall back to the URL.
3. **Format Hub & Toolbar Highlight Missing ([`formatting_hub_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_hub_sheet.dart) & [`formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart))**:
   - *Fix*: Added `FormattingOption.highlight` to `FormattingOption` enum. Added `isHighlight` active-state indicator and a dedicated Highlight tile under `TEXT STYLES` with `PhosphorIconsRegular.highlighter`, `Ctrl+Shift+H` shortcut badge, and `==text==` syntax descriptor. Wired `FormattingToolbar` to track `_isHighlightActive()` and dispatch `widget.richController?.toggleHighlight()` (visual mode) or `_applyFormat(MarkdownFormatter.toggleHighlight)` (markdown mode).
4. **Editor Screen Shortcut Routing ([`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart))**:
   - *Fix*: Added `_toggleHighlight()` method to `EditorScreen` and registered `Ctrl+Shift+H` / `Cmd+Shift+H` shortcuts. Updated `_handleLinkPrompt` to call `_richDocumentController!.applyLink(url: result.url, title: result.title)` when in visual mode.
5. **Markdown Mode Parity ([`markdown_formatter.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_formatter.dart) & [`markdown_editing_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_editing_controller.dart))**:
   - *Fix*: Added `MarkdownFormatter.toggleHighlight` and `MarkdownFormatter.isHighlightAt` alongside `MarkdownEditingController.isHighlightActive` so both editor modes have identical highlight formatting capabilities.

### 4. Verification & Quality
- `flutter analyze`: **0 issues found** (zero warnings, zero errors).
- `flutter test test/editor/rich_text_editor_formattings_test.dart`: **56/56 tests passing**.
- `flutter test`: **348/348 tests passing** with zero failures across the entire test suite.

---

## 139. Visual Rich Text Editor: In-Memory AST Architecture, Enter Key Formatting Preservation & Selection Formatting (October 2026)

### 1. Overview & Objectives
This update addressed fundamental issues in the visual rich text editing experience and revamped the data lifecycle:
1. **In-Memory Rich Text Architecture**: Previously, typing in the visual editor triggered full CommonMark markdown serialization on every keystroke (`widget.onChanged?.call(widget.controller.toMarkdown())`), and parsing back regexes. The visual editor now maintains its rich document abstract syntax tree (`RichDocument`) completely in-memory with full JSON serialization support (`toJson()` / `fromJson()`), postponing Markdown transformation strictly until note save/flush operations (autosave debouncer, mode toggles, navigation exit).
2. **Enter Key Formatting Loss Fixed**: Pressing Enter on formatted text (headings, bold, italic, strikethrough, etc.) previously lost formatting or broke styling runs because `handleEnter` only targeted paragraph blocks or plain-text reparsing occurred. Now, Enter key splits preserve block attributes and reset trailing inline typing attributes cleanly without dropping existing inline styling runs.
3. **Selection Range Formatting Fixed**: Selecting text and clicking toolbar buttons (Bold, Italic, Strikethrough, Highlight, Code, Headings, Lists, Quotes) previously failed or did nothing because the controller selection was collapsed on toolbar tap and multi-block ranges were not properly mapped. Selection ranges are now preserved, toolbar state reflects selected spans, and formatting applies cleanly across selected text.

### 2. Key Architectural Components & Changes

#### A. In-Memory Domain Model & JSON Serialization
- [`lib/features/editor/domain/text_attributes.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/text_attributes.dart):
  - Added `toJson()` and `TextAttributes.fromJson(Map<String, dynamic> json)` supporting `bold`, `italic`, `strikethrough`, `highlight`, `code`, `linkUrl`, `linkTitle`, `noteLink`, and `tag`.
- [`lib/features/editor/domain/rich_inline.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_inline.dart):
  - Added `toJson()` and `RichInlineSpan.fromJson(Map<String, dynamic> json)`.
- [`lib/features/editor/domain/rich_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_block.dart):
  - Added polymorphic `toJson()` and `RichBlock.fromJson(Map<String, dynamic> json)` factory supporting all 10 block types (`ParagraphBlock`, `HeadingBlock`, `ChecklistItemBlock`, `BulletedListItemBlock`, `OrderedListItemBlock`, `QuoteBlock`, `CodeBlock`, `HorizontalRuleBlock`, `ImageBlock`, `TableBlock`).
- [`lib/features/editor/domain/rich_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_document.dart):
  - Added `toJson()` and `RichDocument.fromJson(Map<String, dynamic> json)`.

#### B. Controller In-Memory State & Enter Key Handling
- [`lib/features/editor/application/rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart):
  - Added `isDirty`, `markClean()`, and `notifyContentMutated()` so in-memory mutations notify listeners without triggering eager markdown serialization.
  - Added `setDocument(RichDocument newDoc, {RichDocumentSelection? newSelection})` allowing direct in-memory AST mutations without regex reparsing.
  - Implemented `handleEnterAt(RichDocumentPosition position)` that handles Enter key splits cleanly across text blocks (`ParagraphBlock`, `HeadingBlock`), resetting `_typingAttributes = TextAttributes.none` for the new line while keeping pre-split formatting intact.
  - Updated formatting active checks (`isBoldActive`, `isItalicActive`, `isStrikeActive`, `isHighlightActive`, `isCodeActive`) to inspect the selection range when `!_selection.isCollapsed`.
  - Updated block operations (`setHeadingLevel`, `convertHeadingToParagraph`, `toggleChecklist`, `toggleBulletedList`, `toggleOrderedList`, `toggleQuote`) to operate across multi-block selections.

#### C. Rich Text Editor Widget & Selection Synchronization
- [`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart):
  - Replaced per-keystroke `widget.onChanged?.call(widget.controller.toMarkdown())` with `widget.controller.notifyContentMutated()`.
  - Updated `_onTextControllerChanged` to preserve non-collapsed selections `RichDocumentSelection(base: basePos, extent: extentPos, affinity: sel.affinity)`.
  - Implemented `resolveSegmentOffset(RichDocumentPosition position)` in `_RichTextEditingController` and updated `_syncFromDocument()` to map selection base/extent back to segment offsets and call `markNeedsRebuild()`, so formatting changes on selected text immediately re-render in `EditableText.buildTextSpan`.
  - Updated `Focus.onKeyEvent` to check `if (block.isTextBlock)` so Enter key splits headings and paragraphs consistently.
  - Refactored `applyTextChangesToDocument` to eliminate raw plain-text `parser.parse(newSegmentText)` calls, replacing them with in-memory AST span slicing (`_deleteRange`, `_replaceRangeWithText`, `_splitSpans`, `_copyBlockWithSpans`) which preserves existing formatted spans and block types on soft keyboard / mobile IME Enter and multiline pastes.
- [`lib/features/editor/presentation/widgets/formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart):
  - Added `widget.focusNode?.requestFocus()` to inline format buttons so text selection and focus remain active in the editor when tapping toolbar actions.
- [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart):
  - Tuned `_autosaveDebouncer` to 50ms so in-memory visual typing smoothly coalesces before synchronizing with the repository 700ms autosave timer.
- [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
  - Updated `_onTargetChanged` to derive the note title directly from the in-memory active target controller (`_activeTargetController!.text`) without triggering Markdown string serialization.

### 3. Automated Verification & Quality
- Created [`test/editor/rich_text_in_memory_and_selection_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_in_memory_and_selection_test.dart) with 11 comprehensive tests:
  - `TextAttributes`, `RichInlineSpan`, `RichBlock`, and `RichDocument` JSON round-trip serialization.
  - Enter key in-memory paragraph split preserving inline formatting runs.
  - Enter key in-memory heading split converting the second line to a paragraph while maintaining heading attributes.
  - Applying bold to selected text across partial spans.
  - Toggling bold off on selected bold text.
  - Applying heading level across selected blocks.
  - In-memory typing without rebuilding Markdown string.
- Full test suite: `flutter test` (**all 1564 tests passed with 0 failures**).
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).

---

## 140. Visual Rich Text Editor: RichText AST as Source of Truth, Zero-Compilation Saves & On-Demand Mode Conversion (October 2026)

### 1. Overview & Motivation
Previously, the editor enforced Markdown as the sole canonical storage format for note bodies (`notes.content`). Even when users worked entirely within the Visual (WYSIWYG) editor, every note save or autosave flushed by serializing the entire in-memory AST (`RichDocument`) into a CommonMark markdown string. When reloaded, this Markdown string was reparsed through regexes back into blocks and spans.

This update introduces **Single Polymorphic Content Storage** for note bodies:
1. **Zero-Compilation Note Saves in Visual Mode**: In Visual (WYSIWYG) mode, the editor saves the in-memory AST directly as canonical RichDocument JSON (`quietpaper:rich_document:v1`). The expensive string serialization to CommonMark is completely skipped on save.
2. **On-Demand Mode Conversion**: Markdown compilation and JSON deserialization are triggered strictly when the user switches editor styles (from Visual to Markdown mode, or vice versa), or when exporting/sharing.
3. **No Duplicate Payloads**: Rather than storing both Markdown and JSON, `notes.content` stores either 100% RichText JSON AST (Visual mode notes) or 100% Markdown string (Markdown mode notes).
4. **Transparent Full-Text Search & Metadata Indexing**: SQLite FTS search index projections, preview snippet generators, and auto-title extractors normalize `Note.plainText` directly from the AST so JSON structure tokens (`"spans"`, `"attributes"`, `"isBold"`, `"type"`) are never indexed into SQLite FTS or shown in snippets.

### 2. Key Architectural Components & Changes

#### A. Domain Models & Polymorphic Storage
- [`lib/features/editor/domain/rich_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_document.dart):
  - Defined `static const schemaId = 'quietpaper:rich_document:v1'`.
  - Added `$schema` property in `toJson()`.
  - Implemented `RichDocument.isJson(String text)` for fast $O(1)$ JSON structure detection (`startsWith('{')` and contains `"schemaId"` or `'"blocks"'`).
- [`lib/features/notes/domain/note_model.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_model.dart):
  - Added `bool get isRichText => isRichTextContent(content)`.
  - Added `String get plainText`: returns plain user text extracted across all blocks if JSON, or the raw string if Markdown.
  - Added `String get markdownContent`: on-demand Markdown conversion using `RichDocumentSerializer` for external consumers (export, share, preview).
  - Updated `deriveTitle(String content)`: safely inspects first block/line without returning raw JSON syntax tokens.
  - Updated `wordCount` and `charCount`: calculates metrics from `plainText` rather than raw JSON strings.
- [`lib/features/notes/domain/note_metadata_extractor.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_metadata_extractor.dart):
  - Updated `deriveTitle` and `derivePreviewSnippet` to parse JSON AST into clean user text runs.

#### B. Search Indexing & Query Execution
- [`lib/core/search/search_index_projection.dart`](file:///home/dog/git/quitepaper/lib/core/search/search_index_projection.dart):
  - In `projectBody(Note doc)`, projects `doc.plainText` into the SQLite FTS index table so searches match only user text and ignore AST syntax tokens.
- [`lib/features/notes/data/notes_query_executor.dart`](file:///home/dog/git/quitepaper/lib/features/notes/data/notes_query_executor.dart):
  - Updated `hasCode`, `hasChecklist`, `hasIncompleteTasks`, `hasCompletedTasks`, and `hasLinks` queries to check both Markdown syntax (`- [ ]`, ```` ````) and JSON AST tokens (`"checklist_item"`, `"code_block"`, `"linkUrl"`).

#### C. Editor Application & Presentation Layer
- [`lib/features/editor/application/rich_document_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_controller.dart):
  - Updated constructor to detect `RichDocument.isJson(initialMarkdown)` and deserialize directly via `RichDocument.fromJson()` with zero regex parsing.
  - Added `toJsonString()` (`jsonEncode(_document.toJson())`) and `toPlainText()`.
  - Added `setContent(String content)` to dynamically switch content without tearing down controller state.
  - Updated `isDocumentTooLargeForWysiwyg(String content)` to inspect plain text length when given JSON payloads.
- [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart):
  - In Visual mode, `_flushRichContent()` flushes `_richController.toJsonString()` directly to `widget.controller.value` and `widget.onChanged` without CommonMark compilation.
  - For notes containing YAML frontmatter (`hasFrontmatter == true`), preserves YAML frontmatter headers via `toMarkdown()` and respects `FrontmatterPropertiesSection`.
  - In `didUpdateWidget`, when switching between `wysiwyg` and `markdown` modes, seamlessly converts between JSON AST and clean Markdown on demand.
- [`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart):
  - In `_processMarkdown()`, detects `RichDocument.isJson()` and formats text seamlessly on the fly so markdown previews display properly.

### 3. Automated Verification & Quality
- Created dedicated test suite [`test/editor/rich_text_source_of_truth_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_source_of_truth_test.dart) covering:
  1. `RichDocument.toJson` schema inclusion and `RichDocument.isJson` detection.
  2. `Note` model polymorphic detection, `plainText`, and `markdownContent`.
  3. `SearchIndexProjection` indexing pure user plain text without JSON tokens.
  4. `NoteMetadataExtractor` preview snippet extraction from RichDocument JSON.
  5. `RichDocumentController` direct JSON instantiation with zero regex parsing.
  6. `RichDocumentController.isDocumentTooLargeForWysiwyg` measuring plain text length.
  7. `MarkdownEditor` flushing JSON in Visual mode and converting on mode switch.
  8. `QuietMarkdownPreview` seamless rendering of RichDocument JSON.
- Re-verified all dual-mode frontmatter tests in [`test/editor/dual_mode_editor_screen_test.dart`](file:///home/dog/git/quitepaper/test/editor/dual_mode_editor_screen_test.dart).
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- Test suite: `flutter test` (**all 1,572 tests passed with 0 failures** across the entire project).

---

## 141. Note Details Dialog: Storage Format Indicator (October 2026)

### 1. Overview & UI Enhancements
- Added a dedicated **Format** row in the **Note details** dialog ([`EditorStatsDialog`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/editor_stats_dialog.dart)), accessible via the 3-dot overflow menu in [`EditorScreen`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart).
- The dialog inspects `note.isRichText` to inform the user whether the note is saved as:
  - `Rich text` (stored as polymorphic JSON AST `quietpaper:rich_document:v1` in Visual mode)
  - `Plain markdown` (stored as plain Markdown text in Markdown mode)
- In `EditorScreen`, passes the latest in-memory editor content snapshot (`currentNote = note.copyWith(content: _contentController.text, title: _titleController.text)`) when opening the dialog, ensuring immediate, accurate format and stat reporting even prior to repository autosave debouncer flush.

### 2. Verification & Automated Tests
- Created dedicated test suite [`test/editor/editor_stats_dialog_test.dart`](file:///home/dog/git/quitepaper/test/editor/editor_stats_dialog_test.dart) covering:
  1. `EditorStatsDialog` rendering `Rich text` for `RichDocument` JSON note.
  2. `EditorStatsDialog` rendering `Plain markdown` for Markdown note.
  3. Opening 3-dot overflow menu $\to$ `Note details` in Markdown mode displaying `Format: Plain markdown`.
  4. Opening 3-dot overflow menu $\to$ `Note details` in Visual/JSON mode displaying `Format: Rich text`.
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- Test suite: `flutter test` (**all 1,576 tests passed with 0 failures**).

---

## 142. Rich Text Editor: Inline Styling Mid-Sentence Deactivation & Lexical Parity (October 2026)

### 1. Overview & Problem Description
In the Visual (WYSIWYG) rich text editor (`RichTextEditor`), when typing mid-sentence, users could activate an inline style (such as Bold, Italic, Strikethrough, Inline Code, or Highlight) from the formatting toolbar or keyboard shortcuts, type the formatted word, and then tap the formatting button to deactivate the style.
- While the toolbar button un-highlighted correctly, newly typed characters immediately following the formatted word continued to be styled anyway.
- The formatting only stopped when the user pressed Enter and started a new line.
- The issue occurred across Bold, Italic, Strikethrough, Inline Code, and Highlight.

### 2. Root Cause
In `_RichTextEditingController._spliceSpans` ([`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart)):
- Lines previously contained fallback expressions:
  `final insertAttrs = defaultAttributes.isEmpty ? span.attributes : defaultAttributes;`
  and
  `final insertAttrs = defaultAttributes.isEmpty ? lastAttrs : defaultAttributes;`
- When a user deactivates formatting on a collapsed caret, `editorController.typingAttributes` becomes `TextAttributes.none` (i.e. `defaultAttributes.isEmpty` is `true`).
- Because of `defaultAttributes.isEmpty ? ...`, the algorithm discarded the user's explicit deactivation and fell back to `lastAttrs` or `span.attributes` (the previous span's bold/italic/strike/code format).
- Consequently, the typed characters were inserted with the previous formatting and merged into the preceding formatted span.
- When cursor selection synchronized, `_updateTypingAttributesFromSelection` inspected the cursor inside the merged formatted span, turning active formatting back on in the toolbar.

### 3. Solution & Architectural Alignment
1. **Direct Attribute Assignment**: Removed the faulty `defaultAttributes.isEmpty ? ... : defaultAttributes` checks in `_spliceSpans`. Inserted spans now directly take `defaultAttributes` (`editorController.typingAttributes`), ensuring that explicitly toggled-off formatting applies immediately to subsequent keystrokes on the same line.
2. **Range Replacement Compatibility**: Updated `_replaceRangeWithText` to accept `attributes` parameter from `editorController.typingAttributes`.
3. **Composable Text Decorations**: In `_buildInlineSpans`, combined multiple text decorations (such as strikethrough + link underline) via `TextDecoration.combine` instead of overriding earlier decorations.
4. **Lexical Parity Verification**: Recreated paragraph (5) and paragraph (14) from the Lexical editor playground in automated widget tests:
   ```text
   The playground is a demo environment built with `@lexical/react`. Try typing in **some text** with *different* formats.
   Make sure to check out the various plugins in the toolbar. You can also write something. ~~This is some strikethorugh text~~
   ```
   Verified that toggling inline styles (code, bold, italic, strikethrough, highlight) mid-sentence immediately applies and deactivates styling without requiring Enter key line breaks.

### 4. Verification & Quality
- Static analysis: `flutter analyze` completed with **0 issues found** (zero errors, zero warnings).
- Automated tests: Added 7 new tests in [`test/editor/rich_text_editor_formattings_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_editor_formattings_test.dart) covering mid-sentence bold, italic, strikethrough, inline code, highlight, Lexical playground 7-span document tree creation, and mid-span splitting.
- Full test suite: `flutter test` passed with zero failures across all test suites.

---

## 143. Note Export: Share Note as Screenshot with Branding & Full Colorization (October 2026)

### 1. Overview & Requirements
Quiet Paper previously supported exporting notes to Markdown (`.md`), PDF (`.pdf`), HTML (`.html`), Plain Text (`.txt`), Microsoft Word (`.docx`), and Quiet Paper Packages (`.qpnote`). Users needed an easy, visually stunning way to share notes as a continuous, full-length image on social platforms, messaging apps, and portfolios without losing rich formatting or context.

Requirements:
1. **Full-Length Note Screenshot**: Capture the complete note continuously from top to bottom (never clipped to the device viewport).
2. **Quiet Paper Branding**: Include an official footer with Quiet Paper iconography and the domain `quietpaper.blackpiratex.com`.
3. **Full Colorization & Typography Parity**: Preserve syntax-highlighted code blocks, custom tag chips colorized with `TagColors`, Markdown highlight syntax (`==text==`), checklists (`[x]`), and editorial paper theme styling (`classicLight`, `warmPaperLight`, `classicDark`).
4. **First-Class Export Integration**:
   - Add `ExportFormat.image` (`.png`) as a first-class format in `ExportNoteSheet` with format-specific advanced options and dynamic action button labels (`Save Image` / `Share Image`).
   - Add a direct overflow action in `EditorScreen` (`Share as screenshot`) for 1-tap sharing.

### 2. Architecture & Implementation

#### 2.1 Domain & Options Model
- Added `ExportFormat.image` (`'png'`, `'Image Screenshot'`, `'image/png'`) to [`ExportFormat`](file:///home/dog/git/quitepaper/lib/features/export/domain/export_models.dart).
- Added `ImageExportOptions` with settings:
  - `themeMode`: `'current'`, `'light'`, `'dark'`, or `'warm'`.
  - `includeMetadata`: toggles note creation date header.
  - `includeTags`: toggles colorized tag chip pills.
  - `includeBranding`: toggles Quiet Paper watermark footer (`quietpaper.blackpiratex.com`).
  - `brandingUrl`: defaults to `'quietpaper.blackpiratex.com'`.
  - `brandingTitle`: defaults to `'Quiet Paper'`.
  - `pixelRatio`: defaults to `2.5` for crisp high-DPI rendering.
  - `logicalWidth`: defaults to `600.0` dp for consistent column width across mobile and desktop.
- Integrated `imageOptions` into `ExportRequest`, `ExportRequest.forFormat`, and `ExportRequest.copyWith`.

#### 2.2 Editorial Screenshot Widget (`NoteScreenshotCard`)
- Implemented [`NoteScreenshotCard`](file:///home/dog/git/quitepaper/lib/features/export/presentation/widgets/note_screenshot_card.dart):
  - Renders document title and created date using Quiet Paper's warm editorial typography (`AppTypography`).
  - Resolves tag background and foreground colors dynamically through [`TagColors`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_colors.dart) definition lookups.
  - Formats body Markdown via `MarkdownBody` with:
    - `HighlightElementBuilder` for `==text==` yellow highlight pill styling.
    - `QuietCodeBlockElementBuilder` connected to `SyntaxHighlighter` and `SyntaxLanguageResolver` for code syntax highlighting.
    - Checkbox lists rendered with interactive styling (`check_box_rounded` / `check_box_outline_blank_rounded`).
    - Custom inline and block image builder for embedded attachments.
  - Includes Quiet Paper watermark footer featuring app branding and `quietpaper.blackpiratex.com` link pill.

#### 2.3 Off-Screen Rasterization Engine (`NoteImageRasterizer`)
- Implemented [`NoteImageRasterizer`](file:///home/dog/git/quitepaper/lib/features/export/application/note_image_rasterizer.dart):
  - Uses Flutter's `OverlayEntry` attached to `Navigator.of(context).overlay` offscreen (`left: -10000`, `top: -10000`) wrapped in an unconstrained `SingleChildScrollView` and `RepaintBoundary`.
  - Waits for widget rendering via `WidgetsBinding.instance.endOfFrame`.
  - Calls `RenderRepaintBoundary.toImage(pixelRatio: 2.5)` to generate a high-resolution `ui.Image`.
  - Converts image to PNG byte buffer using `toByteData(format: ui.ImageByteFormat.png)` and cleans up the overlay entry safely.

#### 2.4 Exporter & Service Integration
- Implemented [`ImageExporter`](file:///home/dog/git/quitepaper/lib/features/export/application/exporters/image_exporter.dart) and injected it into [`ExportService`](file:///home/dog/git/quitepaper/lib/features/export/application/export_service.dart) and `exportServiceProvider`.
- Supported optional `imageRasterizer` override parameter on `ExportService.exportNote` and `ExportService.exportAndSave` to facilitate mock rasterization in headless unit and widget tests.

#### 2.5 Presentation Layer & Editor Shortcut
- Updated [`ExportNoteSheet`](file:///home/dog/git/quitepaper/lib/features/export/presentation/export_note_sheet.dart):
  - Added `Image Screenshot` format row with `.png · Full Note Image` subtitle.
  - Added dedicated Advanced Options toggles for Image format: `Include metadata`, `Include tags`, `Branding footer`, and `Include attachments`.
  - Dynamically switched action button labels to `Save Image` and `Share Image`.
  - Wired `NoteImageRasterizer.rasterize` to offscreen render the note snapshot.
- Added direct shortcut to [`EditorScreen`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
  - Added `Share as screenshot` item with `photo_camera_back_outlined` icon in `⋯` overflow menu.
  - Created `_shareAsScreenshot` method that initiates rasterization and system share sheet directly.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` completed with **0 issues found** (zero warnings, zero errors).
- Export Tests: `flutter test test/features/export/` passed (**47 of 47 tests passed**).
- Editor Tests: `flutter test test/editor/` passed (**452 of 452 tests passed**).
- Added comprehensive widget test suite [`test/features/export/note_screenshot_card_test.dart`](file:///home/dog/git/quitepaper/test/features/export/note_screenshot_card_test.dart) verifying typography, tag pills, markdown body, watermark footer, and options toggles.
- Updated [`test/features/export/export_note_sheet_test.dart`](file:///home/dog/git/quitepaper/test/features/export/export_note_sheet_test.dart) and [`test/features/export/export_service_test.dart`](file:///home/dog/git/quitepaper/test/features/export/export_service_test.dart) to cover `ExportFormat.image`.

---

## 144. Note Export: RichDocument JSON AST Leak Fix for Screenshots & Exporters (October 2026)

### 1. Overview & Bug Description
When sharing or exporting a note that was authored or edited in the Visual (WYSIWYG) rich-text editor, the exported screenshot or document rendered raw JSON text (e.g. `{"$schema":"quietpaper:rich_document:v1","blocks":[{"type":"paragraph", ...}]}`) instead of rendered text and formatting.

### 2. Root Cause
In Visual mode, notes persist their AST in canonical JSON (`quietpaper:rich_document:v1`).
1. [`ExportService.exportNote`](file:///home/dog/git/quitepaper/lib/features/export/application/export_service.dart) previously passed `unlocked.content` directly to `_attachmentResolver.resolveResourcesForNote` as `canonicalMarkdown` without checking `Note.isRichTextContent(unlocked.content)`.
2. Consequently, `NoteExportSnapshot.markdown` was populated with raw JSON AST strings. Exporters and [`NoteScreenshotCard`](file:///home/dog/git/quitepaper/lib/features/export/presentation/widgets/note_screenshot_card.dart) rendered the raw JSON syntax directly as paragraphs.
3. In [`EditorScreen`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart), tapping "Export note" or "Share as screenshot" did not flush active in-memory debounced state via `saveNow()` prior to opening export sheets.

### 3. Solution
1. **Canonical Markdown Compilation in Export Pipeline**:
   - In [`ExportService.exportNote`](file:///home/dog/git/quitepaper/lib/features/export/application/export_service.dart), checked `Note.isRichTextContent(unlocked.content)` and invoked `Note.markdownContent` (which uses [`RichDocumentSerializer`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_serializer.dart)) to compile the AST into clean, canonical Markdown.
   - All subsequent export steps (attachment image resolution, note link transformation, PDF generation, image rasterization, HTML, DOCX, PlainText) now receive valid Markdown.
2. **Defense-in-Depth in `NoteScreenshotCard`**:
   - In [`NoteScreenshotCard._cleanMarkdownBody`](file:///home/dog/git/quitepaper/lib/features/export/presentation/widgets/note_screenshot_card.dart), added automatic deserialization of `RichDocument` JSON to Markdown via `RichDocumentSerializer` before passing to `MarkdownBody`.
3. **Editor Flush Synchronization**:
   - In [`EditorScreen`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart), awaited `notifier.saveNow()` before displaying `ExportNoteSheet` or executing `_shareAsScreenshot`.
4. **Automated Test Coverage**:
   - Added widget test in [`test/features/export/note_screenshot_card_test.dart`](file:///home/dog/git/quitepaper/test/features/export/note_screenshot_card_test.dart) ensuring `NoteScreenshotCard` converts RichDocument JSON into rendered text without leaking any JSON syntax.
   - Added end-to-end integration test in [`test/features/export/export_service_test.dart`](file:///home/dog/git/quitepaper/test/features/export/export_service_test.dart) verifying `ExportService` exports notes with `quietpaper:rich_document:v1` storage to formatted Markdown without leaking JSON keys.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` completed with **0 issues found** (0 errors, 0 warnings).
- Export Tests: `flutter test test/features/export/` passed (**49 of 49 tests passed**).
- Editor Tests: `flutter test test/editor/` passed (**452 of 452 tests passed**).

---

## 145. Rich Text Editor: Trailing Whitespace Cursor Preservation Before Newlines (October 2026)

### 1. Overview & Bug Description
In the continuous rich text editor ([`RichTextEditor`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart)), when an active document has multiple lines (e.g. 5 lines) and the user moves the cursor to the end of any line preceding a newline `\n` (lines 1 to 4) and presses Space:
- The cursor did not move forward visually.
- Pressing Space multiple times kept the cursor frozen at the boundary of the last visible character.
- Only upon typing an alphanumeric character (e.g. `'a'`) did the cursor suddenly advance along with all typed spaces.
- On the final line of the document (which is not followed by a trailing `\n`), typing spaces advanced the cursor normally.

### 2. Root Cause
In Flutter's text layout engine (SkParagraph / LibTxt), whitespace immediately preceding a mandatory hard break (`\n`) is treated as trailing whitespace of the line box according to the Unicode Line Breaking Algorithm (UAX #14).
- By design in Unicode line-layout standards, trailing spaces at line breaks are collapsed and measured with zero typographic advance width (`width = 0`).
- Because `RichTextEditor` renders document blocks sequentially separated by `TextSpan(text: '\n')`, any spaces typed at the end of a block (lines 1–4) immediately precede `\n`.
- SkParagraph collapsed their advance width to 0, pinning the caret geometry to the end of the last non-space glyph until a non-space character was entered.
- On the last line (Line 5), there is no trailing `\n`, so spaces were not collapsed by the engine.

### 3. Architectural Solution
1. **Presentation-Layer Trailing Space Preservation**:
   - In [`_RichTextEditingController.buildTextSpan`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart), any trailing ASCII spaces (`' '`, `0x20`) on lines immediately preceding the block delimiter `TextSpan(text: '\n')` are converted to Non-Breaking Spaces (`\u00A0`, U+00A0 NO-BREAK SPACE) via `_preserveTrailingSpacesInSpans`.
   - Because `\u00A0` belongs to Unicode line break class `GL` (Glue / Non-breaking), SkParagraph does not collapse it and gives it the exact advance width of a space glyph.
   - The caret visually advances by font space width per keystroke immediately.
2. **Model Purity & 1:1 UTF-16 Invariants**:
   - The underlying text model ([`TextEditingValue.text`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart), [`RichDocument`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_document.dart) AST, [`ParagraphBlock.spans`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_block.dart), Markdown export, Drift DB, and Cloud Sync) strictly retains canonical ASCII spaces (`' '`, `0x20`).
   - Substitution only occurs during visual display in `buildTextSpan`.
   - Because `\u00A0` is exactly 1 UTF-16 code unit (identical to `' '`), character offsets, selection ranges, cursor indexing, backspacing, IME composing bounds, and gesture tap-to-caret mappings remain 100% 1:1 aligned with zero offset shifts or desynchronization.
3. **Comprehensive Block Type Coverage**:
   - Trailing space preservation applies across all text block types: `ParagraphBlock`, `HeadingBlock`, `ChecklistItemBlock`, `BulletedListItemBlock`, `OrderedListItemBlock`, and `QuoteBlock`, as well as blank lines containing only spaces.
   - On the final line without a trailing newline, spaces remain standard ASCII spaces, preserving natural soft-wrapping behavior at the viewport edge.

### 4. Modified & Added Files
- [`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart): Added `_preserveTrailingSpacesInSpans` and trailing whitespace preservation in `_RichTextEditingController.buildTextSpan`.
- [`test/editor/rich_text_trailing_space_cursor_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_trailing_space_cursor_test.dart): New unit and widget test suite verifying visual `\u00A0` conversion before `\n`, ASCII preservation in `RichDocument`, monotonic caret advancement, and block-type coverage.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 145 documenting the fix.

### 5. Verification & Quality
- Static Analysis: `flutter analyze` completed with **0 issues found** (0 errors, 0 warnings).
- Trailing Space Test Suite: `flutter test test/editor/rich_text_trailing_space_cursor_test.dart` passed (**4 of 4 tests passed**).
- Full Test Suite: `flutter test` passed (**1,591 of 1,591 tests passed**).

---

## 146. Editor 3-Dot Overflow Menu Reorganization & Streamlining (October 2026)

### 1. Overview & Motivation
The note editor 3-dot overflow menu (`⋯`) had previously become cramped with 12–14 vertically stacked list items, causing unnecessary vertical scrolling and visual clutter. To align with Quiet Paper's calm editorial design principles:
- High-frequency note actions (**Pin**, **Archive**, **Delete**) are elevated into a prominent 3-column quick-action bar at the top of the menu with large icons.
- Related export and sharing actions are consolidated into a dedicated **Share** submenu.
- Security and access-control actions are consolidated into a dedicated **Privacy** submenu.
- **Version history** is removed from the 3-dot sheet and moved directly into the **Note details** dialog (`EditorStatsDialog`) beside the "Close" button.
- Core content actions (**Insert**, **Find in note**, **Add tag**, **Edit Visually / Markdown**) remain directly accessible in the main menu.

### 2. Architectural & UI Structure
1. **`EditorQuickActionsBar` (`lib/features/editor/presentation/widgets/editor_quick_actions_bar.dart`)**:
   - Rendered at the top of the overflow menu sheet as a single row of 3 equal-width columns.
   - Built with subtle rounded cards (`colors.surfaceSecondary`, `AppRadii.rMd`), 26dp tactile monochrome icons, and concise labels (`AppTypography.caption`).
   - Adapts to note state:
     - **Active Notes**: `Pin / Unpin`, `Archive`, `Delete`.
     - **Archived Notes**: `Pin / Unpin`, `Unarchive`, `Delete`.
     - **Trashed Notes**: `Restore`, `Delete permanently`.
2. **Smooth In-Sheet Submenu Drilldowns (`_OverflowMenuPage`)**:
   - Expanded enum: `_OverflowMenuPage { main, insert, share, privacy }`.
   - **`_OverflowMenuPage.share`**: Animated submenu view containing:
     - `Export note` (`Icons.ios_share_rounded`)
     - `Share as screenshot` (`Icons.image_outlined`)
     - `Share as URL` (`Icons.link_rounded`)
     - `Copy markdown` (`Icons.copy_rounded`)
     - Top header with back button returning to `_OverflowMenuPage.main`.
   - **`_OverflowMenuPage.privacy`**: Animated submenu view containing:
     - `Lock note (Read-only)` / `Unlock note (Edit mode)`
     - `Protect with password` / `Change note password` / `Remove password protection` / `Lock note now`
     - Top header with back button returning to `_OverflowMenuPage.main`.
3. **Note Details Dialog & Version History Integration (`EditorStatsDialog`)**:
   - Added `onOpenVersionHistory` optional callback to `EditorStatsDialog`.
   - Added a `Version history` action button (`QuietButtonVariant.secondary`, `Icons.history_rounded`) placed to the left of the `Close` button.
   - When tapped, dismisses the dialog and presents `VersionHistorySheet`.
4. **Modular Implementation in `EditorScreen`**:
   - Extracted `_buildOverflowMenuPage` to separate submenu view rendering from sheet boilerplate, improving maintainability.

### 3. Modified & Added Files
- [`lib/features/editor/presentation/widgets/editor_quick_actions_bar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/editor_quick_actions_bar.dart): New 3-column tactile quick action bar widget.
- [`lib/features/editor/presentation/widgets/editor_stats_dialog.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/editor_stats_dialog.dart): Added `onOpenVersionHistory` callback and `Version history` button.
- [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart): Refactored `_showOverflowMenu` and `_buildOverflowMenuPage` with `share` and `privacy` submenus, quick actions bar, and version history wireup.
- [`test/editor/editor_overflow_menu_test.dart`](file:///home/dog/git/quitepaper/test/editor/editor_overflow_menu_test.dart): Updated and added widget tests for quick actions, Share submenu, Privacy submenu, and Note details version history button.
- [`test/editor/editor_stats_dialog_test.dart`](file:///home/dog/git/quitepaper/test/editor/editor_stats_dialog_test.dart): Added unit test for `EditorStatsDialog` `onOpenVersionHistory` action button.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 146.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` completed with **0 issues found** (0 errors, 0 warnings).
- Targeted Tests: `flutter test test/editor/editor_overflow_menu_test.dart test/editor/editor_stats_dialog_test.dart` passed (**14 of 14 tests passed**).
- Full Test Suite: `flutter test` passed (**1,591 of 1,591 tests passed**).

---

## 147. Rich Text Editor: Todolist & Checklist 1:1 Caret Parity, Gutter Clamping & Block Alignment (October 2026)

### 1. Overview & Bug Description
In Quiet Paper's Visual (WYSIWYG) rich-text editor ([`RichTextEditor`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart)), checklists and todolists exhibited several related caret and layout bugs:
1. **Cursor trapped before checkbox**: Tapping the checklist icon on the formatting toolbar inserted an unchecked checkbox (`- [ ]`), but the blinking cursor appeared to the left of the checkbox inside the margin. There was no way to move the cursor after the checkbox because the text length was 0.
2. **Caret jumping and lagging behind while typing**: When typing text (e.g. `"hey"`), the cursor lagged behind by 1 character (appearing after `'e'` rather than after `'y'`). In multi-line checklists, this offset grew cumulatively (+1 per checklist line, +2 per bullet line, +3 per numbered item), causing severe caret desynchronization.
3. **Misplaced checkbox on Enter**: Pressing Enter on a checklist item sometimes inserted a new checkbox lines below rather than on the immediate next line because the desynchronized caret offset resolved to the wrong block in the document AST.

### 2. Root Cause Analysis
In `_RichTextEditingController.buildTextSpan`:
- For `ChecklistItemBlock`, an interactive `WidgetSpan` containing the checkbox icon was prepended to the block's text spans.
- In Flutter's text layout engine (SkParagraph / LibTxt), every `PlaceholderSpan`/`WidgetSpan` consumes **1 code unit** (`\uFFFC`, `PlaceholderSpan.placeholderCodeUnit`) in the laid-out `Paragraph`.
- However, `_RichTextEditingController.computeSegmentText()` constructed the underlying controller text strictly from `block.plainText`.
- For an empty checklist item, `block.plainText` was `""` (0 code units), while the paragraph layout had 1 code unit (`\uFFFC`).
- Consequently:
  - At offset 0 in the text, Flutter painted the cursor at offset 0 in the paragraph: **before the checkbox**.
  - There was no offset 1 in the string, making it impossible to place the cursor after the checkbox until typing began.
  - While typing, `text.length` was always 1 code unit behind `TextPainter`, causing the cursor to lag behind by 1 position (after `'e'` instead of `'y'`).
  - In multi-item lists, every preceding list item added unrepresented code units, causing cumulative line drift and leading `resolveDocumentPosition` to resolve Enter keystrokes to the wrong block further down the document.

### 3. Architectural Solution
1. **Presentation-Layer 1:1 Code Unit Parity (`prefixForBlock`)**:
   - In `_RichTextEditingController`, defined `prefixForBlock(RichBlock block)`:
     - `ChecklistItemBlock`: `'\uFFFC'` (Unicode Object Replacement Character `0xFFFC`, matching Flutter's `PlaceholderSpan.placeholderCodeUnit` exactly).
     - `BulletedListItemBlock`: `('  ' * block.indent) + '• '`.
     - `OrderedListItemBlock`: `('  ' * block.indent) + '${block.order}. '`.
     - `QuoteBlock`: `'▌ '`.
     - `HeadingBlock` & `ParagraphBlock`: `''`.
   - Updated `computeSegmentText()` to prepend `prefixForBlock(block)` to each line, establishing exact 1:1 code unit parity between `_textController.text` and `TextPainter` across all lines.
2. **Prefix-Aware Resolvers**:
   - Refactored `resolveDocumentPosition(int segmentOffset)` to subtract `prefixLength` and `runningOffset`, yielding accurate content offsets within `0..block.plainText.length`.
   - Refactored `resolveSegmentOffset(RichDocumentPosition position)` to map to `runningOffset + prefixLength + position.offset`. For new checklist items at offset 0, this places the caret at `runningOffset + 1` (immediately after the checkbox).
3. **Prefix Gutter Clamping (`clampSelectionAwayFromPrefixes`)**:
   - Clamps any selection offset landing in `[runningOffset, runningOffset + prefixLength)` to `runningOffset + prefixLength`.
   - Prevents the caret from ever being placed into the uneditable checkbox gutter before the checkbox.
4. **Model Purity & Clean Persistence**:
   - In `applyTextChangesToDocument`, stripped presentation prefixes before updating `block.spans`.
   - If the user backspaces into the prefix via soft keyboard/IME, `convertBlockToParagraph` cleanly converts the item to a regular paragraph.
   - The authoritative `RichDocument` AST, `ChecklistItemBlock.spans`, Markdown serializer (`- [ ] `), Drift SQLite DB, and E2EE cloud sync payloads remain 100% pure (zero `\uFFFC` leakage).
5. **Key Bindings & Toolbar Wireup**:
   - Added `Ctrl+Shift+C` and `Cmd+Shift+C` shortcut bindings for `toggleChecklist` in `RichTextEditor`.
   - Ensured `widget.controller.handleEnterAt(docPos)` passes the resolved document position directly on Enter.

### 4. Modified & Added Files
- [`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart): Added `prefixForBlock`, `clampSelectionAwayFromPrefixes`, prefix-aware `computeSegmentText`, `resolveDocumentPosition`, `resolveSegmentOffset`, `applyTextChangesToDocument`, and `Ctrl+Shift+C` shortcut.
- [`test/editor/rich_text_checklist_editor_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_checklist_editor_test.dart): New comprehensive test suite with 9 tests covering empty-checklist caret placement, "hey" typing advance, gutter clamping, Enter continuation, empty-item Enter exit, Backspace-to-paragraph, checkbox toggle, multi-item drift resistance, and bullet list prefix parity.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 147.

### 5. Verification & Quality
- Static Analysis: `flutter analyze` completed with **0 issues found** (0 errors, 0 warnings).
- Checklist Test Suite: `flutter test test/editor/rich_text_checklist_editor_test.dart` passed (**9 of 9 tests passed**).
- Full Test Suite: `flutter test` passed.

---

## 148. Journal & Frontmatter Location Display Visual Overhaul & Alignment (October 2026)

### 1. Overview & Problem Description
In visual WYSIWYG mode and markdown preview, location metadata in note frontmatter rendered in an awkward, crowded layout:
1. **Vertical Centering in Property Rows**: In [`FrontmatterPropertiesSection`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart), `_PropertyRow` used `crossAxisAlignment: CrossAxisAlignment.center` with a fixed label width of `105dp`. When an address wrapped over multiple lines, the "Location" label and pin icon floated in the vertical dead-center of a tall multiline block rather than aligning cleanly at the top.
2. **Cramped Address Width**: In `_buildLocationField`, the address text was placed in a horizontal `Row` alongside three action buttons (`open_in_new_rounded`, `refresh_rounded`, `close_rounded`). On mobile devices (~360dp width), this squeezed the text column down to ~110dp, forcing addresses to wrap into 10+ narrow lines of 1–2 words each.
3. **Floating Centered Actions**: Because the row was vertically centered, the action buttons and coordinates floated next to the middle of the tall column of wrapped text.
4. **Markdown Preview Inconsistency**: In [`QuietFrontmatterCard`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart), the address similarly shared a horizontal row with the "Open in Maps" pill, compressing long addresses.

### 2. Solution & Visual Enhancements
1. **Full-Width Address Presentation**:
   - In both [`FrontmatterPropertiesSection`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart) and [`QuietFrontmatterCard`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart), the address text is granted 100% of the available value width with `1.35` line height. Addresses flow naturally across 1–2 lines without artificial wrapping.
2. **Secondary Metadata & Action Bar**:
   - Placed coordinates (`location.coordinatesString`) and action buttons in a dedicated secondary row directly beneath the address text.
   - Coordinates are styled with muted tertiary caption typography (`AppTypography.caption`, 11sp) on the left, while compact action buttons (`open_in_new_rounded`, `refresh_rounded`, `close_rounded` in edit mode; `Open in Maps` in preview mode) align cleanly on the right.
   - For coordinate-only locations (no human-readable address), single-line horizontal alignment is preserved.
3. **Top-Aligned Property Rows (`CrossAxisAlignment.start`)**:
   - Updated `_PropertyRow` in `FrontmatterPropertiesSection` to `crossAxisAlignment: CrossAxisAlignment.start` with an 88dp label width and 6dp top offset to align the label with the first line of content across all properties (Author, Created, Location, Source, Description, Tags).

### 3. Modified Files
- [`lib/features/editor/presentation/widgets/frontmatter_properties_section.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart): Top-aligned property rows, full-width address display, secondary row for coordinates and action buttons.
- [`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart): Full-width address presentation and secondary coordinates/Open in Maps row in `QuietFrontmatterCard`.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 148.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Full Test Suite: `flutter test` (**all 1605 tests passed, 0 failures**).

---

## 149. Journal Frontmatter Properties: Mood, Activities, Weather & Moment (October 2026)

### 1. Overview & Requirements
Expanded Quiet Paper's journal and note frontmatter capabilities to support rich, human-centered metadata alongside existing location and date tracking:
1. **Mood**: A 10-level visual scale (1 to 10) representing emotional state with expressive icons/emojis (`😭`, `😢`, `😔`, `😕`, `😐`, `🙂`, `😊`, `😁`, `🥳`, `🤩`) instead of plain text strings, saved as integer `mood: <1..10>` in YAML frontmatter.
2. **Activities**: Multi-select activity categorization with icons (e.g. `activities: [exercise, reading]`). Supports 15 standard presets plus user-created custom activities with selectable icons, automatically persisted to `SharedPreferences` and resurfaced across sessions.
3. **Weather**: Automated weather fetching via Open-Meteo API using device GPS coordinates or existing frontmatter location coordinates (free, zero API key required, privacy-respecting), saved in YAML frontmatter under `weather:` (`temperature`, `condition`, `code`). Includes manual refresh and removal actions.
4. **Moment**: A single-select context category chosen from 10 curated types (`ordinary`, `travel`, `work`, `family`, `social`, `health`, `creative`, `celebration`, `difficult`, `reflection`) with distinct icons, saved as `moment: <key>`.

### 2. Architecture & Components
1. **Domain Models**:
   - [`lib/core/journal/domain/journal_mood.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_mood.dart): 10-level mood scale (`JournalMood`), emoji mappings, labels, and `fromLevel` resolver.
   - [`lib/core/journal/domain/journal_moment.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_moment.dart): 10 curated moment categories with Material icon mappings and `fromKey` resolver.
   - [`lib/core/journal/domain/journal_activity.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_activity.dart): Activity model with icon codepoint serialization, 15 standard presets, and custom activity flags.
   - [`lib/core/journal/domain/journal_weather.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_weather.dart): Weather metadata model, WMO code interpretation, icon mappings, and `temperatureString` helper.
2. **Application Services**:
   - [`lib/core/journal/application/weather_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/weather_service.dart): Open-Meteo current forecast integration querying temperature and WMO weather codes.
   - [`lib/core/journal/application/activity_storage_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/activity_storage_service.dart): Custom activity persistence in `SharedPreferences` (`quietpaper_custom_activities_v1`) merged with standard presets and synchronous cache lookup `findActivitySync`.
3. **Frontmatter Infrastructure**:
   - [`lib/features/editor/domain/frontmatter_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/frontmatter_document.dart): Added `mood`, `activities`, `weather`, and `moment` properties and display predicates.
   - [`lib/features/editor/application/frontmatter_editor_helper.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/frontmatter_editor_helper.dart): Added parser support and manipulation helpers: `updateMood`, `removeMood`, `updateMoment`, `removeMoment`, `updateActivities`, `removeActivities`, `updateWeather`, `removeWeather`, and `removeProperty`.
   - [`lib/features/import/application/markdown_frontmatter_parser.dart`](file:///home/dog/git/quitepaper/lib/features/import/application/markdown_frontmatter_parser.dart): Parser extraction and display checks for `ParsedMarkdown`.
4. **Interactive Modal Sheets**:
   - [`lib/features/editor/presentation/widgets/mood_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/mood_picker_sheet.dart): 10-level visual mood grid with emoji icons, level badges, and clear option.
   - [`lib/features/editor/presentation/widgets/moment_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/moment_picker_sheet.dart): 10-moment selection list with icons, descriptions, and active state highlights.
   - [`lib/features/editor/presentation/widgets/activity_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/activity_picker_sheet.dart): Multi-select activity chip picker with dialog to create custom activities with icons.
5. **Visual WYSIWYG & Preview Presentation**:
   - [`lib/features/editor/presentation/widgets/frontmatter_properties_section.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart): Interactive rows for Moment, Mood, Weather, Location, and Activities with top-aligned layout, badge pills, add/remove buttons, and summary bar preview.
   - [`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart): Read-only rendering in `QuietFrontmatterCard` with consistent typography, icons, and chip wraps.

### 3. Modified & Added Files
- [`lib/core/journal/domain/journal_mood.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_mood.dart): Created mood domain model.
- [`lib/core/journal/domain/journal_moment.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_moment.dart): Created moment domain model.
- [`lib/core/journal/domain/journal_activity.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_activity.dart): Created activity domain model and presets.
- [`lib/core/journal/domain/journal_weather.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_weather.dart): Created weather domain model.
- [`lib/core/journal/application/weather_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/weather_service.dart): Open-Meteo weather service.
- [`lib/core/journal/application/activity_storage_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/activity_storage_service.dart): Activity storage and memory service.
- [`lib/features/editor/presentation/widgets/mood_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/mood_picker_sheet.dart): Mood picker bottom sheet.
- [`lib/features/editor/presentation/widgets/moment_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/moment_picker_sheet.dart): Moment picker bottom sheet.
- [`lib/features/editor/presentation/widgets/activity_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/activity_picker_sheet.dart): Activity picker and custom creator bottom sheet.
- [`lib/features/editor/presentation/widgets/frontmatter_properties_section.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart): Interactive WYSIWYG properties section integration.
- [`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart): Preview card rendering.
- [`lib/features/editor/domain/frontmatter_document.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/frontmatter_document.dart): Model extensions.
- [`lib/features/editor/application/frontmatter_editor_helper.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/frontmatter_editor_helper.dart): Parser and modifier updates.
- [`lib/features/import/application/markdown_frontmatter_parser.dart`](file:///home/dog/git/quitepaper/lib/features/import/application/markdown_frontmatter_parser.dart): Import and preview parser updates.
- [`test/editor/frontmatter_editor_helper_test.dart`](file:///home/dog/git/quitepaper/test/editor/frontmatter_editor_helper_test.dart): Unit tests for mood, moment, activities, and weather.
- [`test/import/markdown_frontmatter_parser_test.dart`](file:///home/dog/git/quitepaper/test/import/markdown_frontmatter_parser_test.dart): Unit tests for parser.
- [`test/editor/frontmatter_properties_section_test.dart`](file:///home/dog/git/quitepaper/test/editor/frontmatter_properties_section_test.dart): Widget tests for visual edit mode.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 149.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Full Test Suite: `flutter test` (**all 1,612 tests passed, 0 failures**).

---

## 150. Journal Properties Phosphor Icon Unification & Tree-Shaking Fix (October 2026)

### 1. Overview & Problem Statement
In Flutter release builds (e.g. CI GitHub Actions `compileFlutterBuildGithubRelease`), Flutter performs Ahead-Of-Time (AOT) icon font tree shaking (`--tree-shake-icons`). A dynamic runtime constructor call `IconData(codePoint, ...)` was previously present in `JournalActivity.fromJson`, causing release builds to fail with:
```text
This application cannot tree shake icons fonts. It has non-constant instances of IconData at the following locations:
  - file:///.../lib/core/journal/domain/journal_activity.dart:48:13
Target aot_android_asset_bundle failed: Error: Avoid non-constant invocations of IconData or try to build again with --no-tree-shake-icons.
```
In addition, the journal models previously mixed Material icons with the rest of Quiet Paper's design system.

### 2. Architectural Adjustments
1. **Unification with Existing Phosphor Icon Ecosystem**:
   - Quiet Paper already maintains a complete compile-time constant Phosphor icon catalog in [`lib/features/tags/domain/phosphor_icons.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/phosphor_icons.dart) and [`lib/features/tags/domain/tag_icon_registry.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_icon_registry.dart).
   - Migrated all journal models and sheets to use `PhosphorIconsRegular` compile-time constants:
     - `JournalActivity`: Standard presets use `PhosphorIconsRegular` constants (`personSimpleRun`, `bookOpen`, `laptop`, `personSimpleWalk`, `cookingPot`, `musicNotes`, `peace`, `gameController`, `shoppingBag`, `filmSlate`, `bed`, `coffee`, `house`, `tree`, `palette`).
     - `JournalMoment`: All 10 moments use `PhosphorIconsRegular` constants (`coffee` for ordinary, `airplane` for travel, `briefcase` for work, `house` for family, `chatsTeardrop` for social, `heart` for health, `palette` for creative, `confetti` for celebration, `cloudRain` for difficult, `sparkle` for reflection).
     - `JournalWeather`: `iconForWmoCode` maps WMO codes to `PhosphorIconsRegular` constants (`sun`, `cloudSun`, `cloudFog`, `cloudRain`, `snowflake`, `cloudLightning`, `cloud`).
     - `ActivityPickerSheet`: Custom activity icon picker offers curated Phosphor icon options.
2. **Elimination of Non-Constant `IconData` Invocations**:
   - `JournalActivity` now serializes `iconKey: String` (e.g. `'person-simple-run'`, `'mountains'`).
   - Deserialization in `JournalActivity.fromJson` maps `rawIconKey` synchronously via `TagIconRegistry.resolveIcon(rawIconKey, fallback: PhosphorIconsRegular.star)` using the pre-compiled `kPhosphorRegularIcons` map.
   - Zero dynamic `IconData(codePoint, ...)` constructor invocations exist in the entire codebase, ensuring complete compatibility with Flutter icon tree-shaking in release builds.

### 3. Modified & Added Files
- [`lib/core/journal/domain/journal_activity.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_activity.dart): Switched presets and deserialization to Phosphor icons and `TagIconRegistry`.
- [`lib/core/journal/domain/journal_moment.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_moment.dart): Switched moment icons to `PhosphorIconsRegular`.
- [`lib/core/journal/domain/journal_weather.dart`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_weather.dart): Switched WMO code icon mappings to `PhosphorIconsRegular`.
- [`lib/features/editor/presentation/widgets/activity_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/activity_picker_sheet.dart): Switched custom activity dialog icon picker to Phosphor icons.
- [`test/journal/journal_properties_domain_test.dart`](file:///home/dog/git/quitepaper/test/journal/journal_properties_domain_test.dart): Added comprehensive domain unit tests verifying Phosphor icon mappings and serialization.
- [`HANDOFF.md`](file:///home/dog/git/quitepaper/HANDOFF.md): Added Section 150.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Full Test Suite: `flutter test` (**all 1,620 tests passed, 0 failures**).
- Non-constant IconData verification: `git grep "IconData("` confirmed zero dynamic non-const `IconData` calls in codebase.

---

## 151. SuperEditor Integration as 3rd Editor Mode with Native Task Checklists (October 2026)

### 1. Overview & Motivation
Checklists and interactive task items (`- [ ]`, `- [x]`) in standard Flutter `EditableText` / `TextField` implementations suffer from cursor jumping, `WidgetSpan` / `\uFFFC` touch-stealing, and caret desynchronization when tapping checkboxes directly within the text layout.
To resolve this while keeping the writing experience calm and intuitive:
- Integrated `super_editor` (`^0.3.0-dev.52`) as a 3rd distinct editor mode: **Super Editor** (`EditorEditingStyle.superEditor`), joining the existing **Visual** (in-memory AST) and **Markdown** (source text) modes.
- SuperEditor provides a native block-based document architecture where task checklist items are represented as first-class `TaskNode` models with dedicated `TaskComponentBuilder` checkboxes. Checkbox taps cleanly execute `ChangeTaskCompletionRequest` without cursor fighting or touch conflicts.
- Adheres to standard CommonMark / GitHub Flavored Markdown (GFM) persistence via SuperEditor's built-in `deserializeMarkdownToDocument` and `serializeDocumentToMarkdown` serializers. Notes are saved as clean Markdown, allowing seamless bidirectional opening and editing across all three modes (Super Editor, Visual, Markdown).

### 2. Architectural Adjustments & Implementation Details
1. **Domain Model & Persistence**:
   - [`lib/features/editor/domain/editor_editing_style.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/editor_editing_style.dart): Added `EditorEditingStyle.superEditor` with label `'Super Editor'` and description `'Block-based editor with native task checkboxes'`.
   - Maintained `wysiwyg` as the factory default fallback for unconfigured environments to preserve existing workflows, while enabling `superEditor` as an active setting selectable globally and per-note.
   - Persistence keys: `'superEditor'` and `'super_editor'` seamlessly deserialize in `fromString(val)`.
2. **Settings Screen Integration**:
   - [`lib/features/settings/presentation/settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart): Added dedicated `Super Editor` row under **APPEARANCE → Editor style** with `Icons.auto_awesome_rounded` and instant toggle persistence via `editorEditingStyleProvider`.
3. **Dedicated SuperEditor Surface Widget**:
   - [`lib/features/editor/presentation/widgets/quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart): Created `QuietSuperEditor` wrapping `SuperEditor`, `MutableDocument`, `createDefaultDocumentEditor`, and `MutableDocumentComposer`.
   - **Frontmatter Preservation**: When `stripFrontmatter` is enabled, YAML metadata header (`--- ... ---`) is safely extracted and preserved in the document body prefix, so note frontmatter properties remain untouched while the body is edited inside `SuperEditor`.
   - **Typography & Color Harmony**: Dynamically derives a custom `Stylesheet` adapting `TypographySettings` (body font, heading fonts, scaled sizes, line height, letter spacing) and `AppColors` (palette tones for light and dark themes).
   - **Scroll & Viewport Isolation**: SuperEditor's internal `DocumentScrollable` expects either no ancestor scrollable or a custom sliver context. To prevent `_RenderSliverHybridStack` crashes when hosted inside `Column` within `SingleChildScrollView`, `QuietSuperEditor` embeds `SuperEditor` inside a horizontal scroll isolation boundary with matching width constraints (`LayoutBuilder` + `SingleChildScrollView(scrollDirection: Axis.horizontal, physics: NeverScrollableScrollPhysics())`), ensuring smooth vertical scrolling within the note editor sheet.
4. **Editor Screen Routing & Overflow Menu**:
   - [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart): Routes to `QuietSuperEditor` when `effectiveEditingStyle == EditorEditingStyle.superEditor`.
   - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
     - Hides bottom `FormattingToolbar` when SuperEditor is active, delegating to SuperEditor's native floating toolbar and gesture system.
     - Added `_OverflowMenuPage.editorStyle` submenu in the 3-dot overflow menu (⋯) allowing instant switching between Super Editor, Visual, and Markdown modes for individual notes.
     - Retained quick toggle tile (`Edit Markdown` / `Edit Visually`) for single-tap switching between visual and source modes.
     - Implemented `_switchEditingStyle` method cleanly converting note representations when switching modes on the fly.
   - [`lib/features/editor/application/editor_provider.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/editor_provider.dart): Updated `togglePerNoteEditingStyle` cycling logic across all three styles (`superEditor` -> `markdown` -> `wysiwyg`).

### 3. Verification & Quality
- `flutter analyze`: **0 issues found** (zero warnings, zero errors).
- `test/editor/quiet_super_editor_test.dart`: 5 dedicated tests verifying:
  - Markdown deserialization into `ParagraphNode` and `TaskNode`.
  - Task completion toggling and GFM task serialization (`- [ ]`, `- [x]`).
  - Widget rendering and typography injection.
  - Frontmatter preservation on save.
- `test/editor/editing_style_settings_test.dart`: Domain and persistence tests for `superEditor`.
- `test/editor/desktop_file_drop_and_paste_test.dart`: All drag-and-drop overlay tests passing.
- `test/editor/dual_mode_editor_screen_test.dart`: All mode toggling tests passing.
- `test/widget_test.dart`: All 18 smoke & flow tests passing.
- Full test suite: `flutter test` passing with zero failures.

---

## 152. Super Editor Dark Mode Caret Visibility & Quiet Formatting Toolbar Integration (October 2026)

### 1. Overview & Motivation
Following the initial introduction of Super Editor mode (`EditorEditingStyle.superEditor`), two critical user-experience issues were addressed:
1. **Dark Mode Cursor Invisibility**:
   - In Light Mode (`#F7F6F2`), the text cursor was visible. In Dark Mode (`#1D1C1A`), the caret was invisible because `super_editor`'s `DefaultCaretOverlayBuilder` defaulted to `Colors.black` and only rendered on desktop by default (`displayOnAllPlatforms: false`), while Android and iOS handle layers fell back to `Theme.of(context).primaryColor` (which in Flutter Material 3 dark themes resolves to `#212121`, blending into `#1D1C1A`).
2. **Missing Formatting Toolbar in Super Editor Mode**:
   - The primary Quiet Paper formatting toolbar (`FormattingToolbar`) above the keyboard was previously hidden when `_isSuperEditor` was active. Users expected Quiet Paper's familiar formatting buttons (Bold, Italic, Strikethrough, Code, Headings H1–H6, Checklist `- [ ]`, Bullet list, Numbered list, Blockquote, Divider, Link, Undo, Redo, and Snippet insertion) to work directly on the active Super Editor document without requiring gestures or desktop mouse selections.

### 2. Architectural Adjustments & Implementation Details

1. **Dark & Light Mode Caret & Handle Theme Support**:
   - [`lib/app/theme/app_theme.dart`](file:///home/dog/git/quitepaper/lib/app/theme/app_theme.dart): Added `primaryColor: colors.accent` in both `ThemeData.light` and `ThemeData.dark`. Any fallback lookups for `primaryColor` inside third-party widgets (like SuperEditor handle layers) now resolve to Quiet Paper's warm editorial accent color instead of black or dark grey.
   - [`lib/features/editor/presentation/widgets/quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart):
     - Configured `selectionStyle: SelectionStyles(selectionColor: colors.selection)`.
     - Explicitly specified `androidHandleColor: colors.accent` and `iOSHandleColor: colors.accent`.
     - Injected explicit `documentOverlayBuilders`:
       - `SuperEditorIosToolbarFocalPointDocumentLayerBuilder()`
       - `SuperEditorIosHandlesDocumentLayerBuilder(handleColor: colors.accent)`
       - `SuperEditorAndroidToolbarFocalPointDocumentLayerBuilder()`
       - `SuperEditorAndroidHandlesDocumentLayerBuilder(caretColor: colors.accent)`
       - `DefaultCaretOverlayBuilder(caretStyle: CaretStyle(width: 2, color: colors.accent), displayOnAllPlatforms: true)` ensuring high-contrast caret visibility across all platforms and themes.

2. **`QuietSuperEditorController` Architecture**:
   - [`lib/features/editor/application/quiet_super_editor_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/quiet_super_editor_controller.dart):
     - Created a specialized `ChangeNotifier` that binds directly to SuperEditor's `Editor` and `MutableDocumentComposer`.
     - **Inline formatting**: `toggleBold()`, `toggleItalic()`, `toggleStrike()`, `toggleCode()`, `isBoldActive`, `isItalicActive`, `isStrikeActive`, `isCodeActive` using SuperEditor's `ToggleTextAttributionsRequest` and `Attribution` spans.
     - **Block formatting**: `setHeadingLevel(1..6)`, `convertHeadingToParagraph()`, `cycleHeadingLevel()`, `toggleChecklist()`, `toggleBulletedList()`, `toggleOrderedList()`, `toggleQuote()` executing `ChangeParagraphBlockTypeRequest`, `ConvertListItemToParagraphRequest`, `ConvertTaskToParagraphRequest`, and `ChangeListItemTypeRequest`.
     - **Insertions**: `insertHorizontalRule()`, `applyLink({required url, title})`, `insertCodeBlock()`, `insertSnippet(snippet)`.
     - **History & Undo/Redo**: `canUndo`, `canRedo`, `undo()`, `redo()` delegating directly to `_editor.history`, `_editor.future`, `_editor.undo()`, and `_editor.redo()`.
     - **Disposal Safety**: Guarded `notifyListeners()` with `_isDisposed` to prevent late element unmount lifecycle assertions.

3. **Toolbar & Editor Screen Integration**:
   - [`lib/features/editor/presentation/widgets/formatting_toolbar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart):
     - Added `superController` parameter and listener bindings.
     - Dynamic state getters (`_isBoldActive`, `_getActiveHeadingLevel`, `_isChecklistActive`, etc.) route directly to `superController` when in Super Editor mode.
     - Actions (`_handleBold`, `_setHeadingLevel`, `_handleLink`, `_handleCodeBlock`, etc.) execute through `superController`.
     - Undo/Redo buttons automatically reflect `superController.canUndo` / `superController.canRedo`.
   - [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart):
     - Forwards `superController` into `QuietSuperEditor`.
   - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
     - Owns `_superEditorController = QuietSuperEditorController()`, disposed cleanly on screen exit.
     - Unhidden toolbar in `_buildToolbarOrSpeechBar` for Super Editor mode.
     - Forwarded `superController` into both `FormattingToolbar` and `MarkdownEditor`.
     - Updated desktop keyboard shortcuts (Bold, Italic, Headings, Lists, Quotes, Divider, Code) to invoke `_superEditorController` when `_isSuperEditor` is true.
     - Updated `_insertSnippetAtCursor` and `LinkPromptDialog` handling to insert directly into SuperEditor.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Dedicated Tests: `test/editor/quiet_super_editor_test.dart` (8 passing unit & widget tests verifying document serialization, task toggles, controller attachment, bold toggle, headings, undo/redo, and dark mode caret builder).
- Full Test Suite: `flutter test` (**all 1,628 tests passed, 0 failures**).

---

## 153. Super Editor Checklist Polish, Encrypted Image Attachments, & Interactive Table Component (October 2026)

### 1. Overview & Motivation
Following the integration of the formatting toolbar and dark mode caret visibility in Super Editor mode, three essential content component improvements were implemented:
1. **Checklist Polish (`TaskNode`)**:
   - Stock `super_editor` uses a standard 48dp Material `Checkbox` with wide margins and noticeable baseline misalignment. In Quiet Paper's warm editorial design, checklists must use Phosphor icons (`PhosphorIconsRegular.square` and `PhosphorIconsFill.checkSquare`), tight 8–10dp gap, zero extra indent, and baseline alignment matching normal paragraph text.
2. **Local Encrypted Image & Attachment Support (`ImageNode`)**:
   - Stock `ImageComponent` renders raw network URLs (`http(s)://`) directly via standard Flutter image widgets, failing for Quiet Paper's encrypted local attachments (`attachment:<UUID>`, `qp://asset/<UUID>`), documents, and encrypted vault storage.
3. **Interactive & Editable Tables (`TableBlockNode`)**:
   - `super_editor` includes an experimental `TableBlockNode` and parser, but lacks an inline cell editor widget. By embedding Quiet Paper's established `MarkdownTableView` inside Super Editor alongside `MarkdownTableEditor` modal editing, users can seamlessly view and edit table rows, columns, alignments, and cell text directly within the Super Editor canvas.

### 2. Architectural Adjustments & Implementation Details

1. **`QuietTaskComponentBuilder` & `QuietTaskComponent`**:
   - [`lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart):
     - Replaces SuperEditor's default `TaskComponentBuilder`.
     - Builds a custom `QuietTaskComponent` implementing `ProxyDocumentComponent` and `ProxyTextComposable`.
     - Renders an interactive Phosphor icon checkbox with `AppColors.accent` check color and `AppColors.textSecondary` outline.
     - Features precise baseline positioning (`top: 2.0`, `right: 8.0`) inside a 22×22 hit target for effortless finger and stylus tapping without disrupting document layout.
     - Integrates SuperEditor's `ChangeTaskCompletionRequest` to update task state and serialize directly to standard Markdown `- [ ]` / `- [x]`.

2. **`QuietImageComponentBuilder`**:
   - [`lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart):
     - Overrides `ImageComponentBuilder` to route image URLs through `QuietPaperUri`.
     - Renders encrypted local note attachments and vault assets via `QuietAssetImageView(noteId: noteId, uri: parsedUri)`.
     - Supports non-image document attachments via `QuietDocumentCard(uri: parsedUri)`.
     - Falls back cleanly to regular web image URLs with rounded corners and error placeholders.

3. **`QuietTableComponentBuilder` & `QuietTableComponent`**:
   - [`lib/features/editor/presentation/widgets/super_editor/quiet_table_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_table_component.dart):
     - Intercepts `TableBlockNode` (parsed via `super_editor_markdown`'s GFM table parser).
     - Renders a clean editorial container wrapping `MarkdownTableView` with horizontal scrolling, subtle borders, and header row tinting.
     - Embeds an editorial header bar showing table dimensions (`Table (r × c)`), an "Edit" action button, and a "Delete" trash action executing `DeleteNodeRequest`.
     - Tapping any table cell or the "Edit" action opens Quiet Paper's `MarkdownTableEditor` modal sheet. Modifying rows, columns, alignment, or cell content updates the document via `ReplaceNodeRequest`, seamlessly persisting updated Markdown tables.

4. **Editor Wiring & Table Insertion**:
   - [`lib/features/editor/presentation/widgets/quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart):
     - Added optional `noteId` property for asset decryption context.
     - Pre-pended `QuietTaskComponentBuilder`, `QuietImageComponentBuilder`, and `QuietTableComponentBuilder` to `componentBuilders` ahead of default builders.
   - [`lib/features/editor/presentation/widgets/markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart):
     - Forwarded `noteId` down to `QuietSuperEditor`.
   - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
     - Forwarded `note.id` into `MarkdownEditor`.
     - Updated `_handleInsertTable` to insert standard table Markdown snippets into `QuietSuperEditorController` when `_isSuperEditor` is active.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Test Suite: `test/editor/quiet_super_editor_test.dart` (11 unit & widget tests covering task checkboxes, task serialization, table rendering, table node deletion, image node rendering, dark mode caret, undo/redo).
- Full Test Suite: `flutter test` (**all 1,631 tests passed, 0 failures**).

---

## 154. Super Editor Image & Block Node Persistence Across Preview Toggle (October 2026)

### 1. Overview & Bug Analysis
A bug was reported where an image entered in Super Editor mode appeared upon initial insertion, but after switching to preview mode and toggling back to edit mode, the image failed to show up.

### 2. Root Cause Investigation
1. **Single-Newline Serialization**:
   - SuperEditor's built-in `ImageNodeSerializer` and `TableBlockNodeSerializer` did not emit a trailing newline after the node.
   - When joined in `serializeDocumentToMarkdown` via `buffer.writeln("")`, subsequent nodes were separated by only a single newline (`\n`), producing `![alt](url)\nFollowing text`.
   - In CommonMark/Markdown, a single newline does not break a paragraph. Consequently, `![alt](url)\nFollowing text` was parsed by `package:markdown` as a single paragraph containing both an image tag and text.
   - SuperEditor's `_InlineMarkdownImageVisitor.isImage` strictly requires that block images contain no text (`_textStack.first.isEmpty`). Because the paragraph contained text from the next line, it rejected the block image and dropped the `ImageNode`, keeping only the text as a `ParagraphNode`.
2. **Raw Plain Text Insertion**:
   - `QuietSuperEditorController.insertSnippet` executed `InsertPlainTextAtCaretRequest(snippet)`, inserting the raw string `![alt](url)` as text into the active paragraph instead of parsing it into an `ImageNode`.
3. **Editor Screen Attachment Snippet Isolation**:
   - `_pickAndImportImage` directly modified `_contentController.value` with `\n${snippet}\n` without routing through `_superEditorController` or using double newlines for block isolation.

### 3. Architectural Adjustments & Implementation Details

1. **`QuietImageNodeSerializer` & `QuietTableBlockNodeSerializer`**:
   - [`lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart) & [`lib/features/editor/presentation/widgets/super_editor/quiet_table_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_table_component.dart):
   - Created custom `NodeTypedDocumentNodeMarkdownSerializer` classes for both `ImageNode` and `TableBlockNode`.
   - If the node is not the last node in the document, appends a trailing newline (`buffer.writeln()`), guaranteeing that `serializeDocumentToMarkdown` emits a full blank line (`\n\n`) between block nodes and adjacent paragraphs.
   - Registered both custom serializers in `QuietSuperEditor._onDocumentChange`.

2. **Markdown Normalization before Deserialization (`normalizeMarkdownForSuperEditor`)**:
   - Added `normalizeMarkdownForSuperEditor(String markdown)` in `quiet_image_component.dart`.
   - Iterates lines and ensures any standalone image tag (`![alt](url)`) or table block is framed with blank lines (`\n\n`) before being deserialized by `deserializeMarkdownToDocument`.
   - Prevents existing or imported notes with single-newline formatting from losing images when deserialized in `QuietSuperEditor._initEditor()`.

3. **Structured Content Insertion in `QuietSuperEditorController`**:
   - [`lib/features/editor/application/quiet_super_editor_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/quiet_super_editor_controller.dart):
   - Updated `insertSnippet(String snippet)` to inspect whether the snippet contains block Markdown (images or tables).
   - If block markdown is detected, normalizes and deserializes the snippet, executing `PasteStructuredContentEditorRequest` with the structured document at the composer's caret. This splits the current paragraph cleanly and embeds the `ImageNode` or `TableBlockNode` directly.

4. **Editor Screen Snippet Routing**:
   - [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
   - Updated `_pickAndImportImage` to use `\n\n${importResult.markdownSnippet}\n\n` and route to `_insertSnippetAtCursor` when `_isSuperEditor` is active.
   - Updated pasted and imported file/image snippets across `editor_screen.dart` to use double newlines (`\n\n`).

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Dedicated Tests: `test/editor/quiet_super_editor_test.dart` (14 passing tests, including image round-trip with following paragraphs, table round-trip, `insertSnippet` structured insertion, and full widget edit -> preview -> edit toggle cycle).
- Full Test Suite: `flutter test` (**all 1,634 tests passed, 0 failures**).

---

## 155. Frontmatter Properties Card in Super Editor Mode (October 2026)

### 1. Summary
The editable frontmatter **Properties** card (Author, Created, Source, Description, Location, Tags, Mood, Weather, Moment, Activities) previously rendered only in WYSIWYG mode. It is now shared by the Super Editor surface as well, giving journal entries and metadata-rich notes the same editing affordance in both visual editors. Markdown source mode is intentionally unchanged — it continues to show the raw YAML frontmatter inline.

### 2. Problem
In Super Editor mode the frontmatter block was never stripped (`stripFrontmatter` was gated on `isWysiwyg`), so a note's `---` metadata block leaked into the editable body — the `---` delimiters rendered as horizontal rules and `key: value` lines as stray paragraphs. There was also no Properties card to edit that metadata.

### 3. Architectural Adjustments & Implementation Details

1. **Shared rendering gate** ([`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)):
   - Introduced `isSuperEditor` and a unified `showsPropertiesSection = isWysiwyg || isSuperEditor` flag in `build()`.
   - `frontmatterDoc` is now parsed for both visual modes (previously `isWysiwyg`-only).
   - The Properties card render gate, the fallback tags-bar gate, and the `MarkdownEditor.stripFrontmatter` flag all now key off `showsPropertiesSection`.
   - `FrontmatterPropertiesSection` is reused verbatim — it is already editor-agnostic (operates on raw Markdown via `FrontmatterEditorHelper` and a change callback), so no changes to the widget itself were needed.

2. **Reactive frontmatter prefix in `QuietSuperEditor`** ([`lib/features/editor/presentation/widgets/quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart)):
   - Extracted a `_splitFrontmatter(markdown)` record helper (prefix + body) reused by `_initEditor()`.
   - `didUpdateWidget` now distinguishes a **frontmatter-only change** (the Properties card edited metadata; body byte-identical) from a body change. On a frontmatter-only change it refreshes `_frontmatterPrefix` in place and advances `_lastSerializedMarkdown` — **without** tearing down and rebuilding the SuperEditor document. This preserves caret/selection, avoids flicker, and critically prevents a **stale prefix from clobbering the metadata edit** on the next body keystroke. Body changes (or a `stripFrontmatter` toggle) still trigger a full re-init as before.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Dedicated Tests: `test/editor/quiet_super_editor_test.dart` — added `frontmatter-only change refreshes preserved prefix without clobbering next body edit`, verifying the body document survives a metadata edit and the next body edit re-prepends the new prefix (not the stale one).
- Full Test Suite: `flutter test` (**all 1,635 tests passed, 0 failures**).



## 156. Pull-Down-to-Search Rewrite: Deliberate Two-Phase Gesture (October 2026)

### 1. Summary
The pull-down-to-search gesture on both the **notes list** and **inside the editor** triggered constantly by accident. Both surfaces were rewritten to share a single, deliberate *two-phase* gesture engine (`PullDownSearchReveal`) that only engages when a pull **begins from rest at the very top** of the content. The animation (content slides down with rubber-band resistance to reveal a search bar; commit on release past a threshold) is preserved and retuned, while the trigger logic is far stricter.

### 2. Problem
Two different, both-too-eager implementations:
- **Notes list** (`pull_down_search_reveal.dart`): wrapped the whole `Scaffold` in a raw `GestureDetector(onVerticalDragUpdate)` **and** a scroll `NotificationListener` — two competing gesture sources (also fighting the drawer edge-drag). It committed navigation on release whenever the offset *ever* crossed a low 70px threshold, so a quick downward flick to scroll up could momentarily cross it and fire.
- **Editor** (`editor_screen.dart`): an inline `NotificationListener` opened the find bar the instant overscroll passed **−15px** (or a −12px scroll delta at the top) — no release, no confirmation. On short notes or a fling-bounce at the top, almost any downward touch opened search.

### 3. Architectural Adjustments & Implementation Details

1. **Two-phase arming** ([`lib/features/notes/presentation/widgets/pull_down_search_reveal.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/pull_down_search_reveal.dart)):
   - The raw `GestureDetector` is removed; the widget is driven **purely by scroll notifications**.
   - **Phase 1 (arm):** on `ScrollStartNotification`, the pull arms only if the scrollable is already at the top (`pixels <= 0`) **and** the scroll is user-initiated (`dragDetails != null`). A drag that starts mid-list and scrolls up into the top boundary never arms; a ballistic fling-bounce (null `dragDetails`) never arms. The user must lift and touch again from rest at the top. This is the core accidental-trigger fix.
   - **Phase 2 (pull):** while armed, the pull is accumulated from the **raw finger delta** (`dragDetails.delta.dy`), not the physics-damped overscroll (which varies wildly with content length). Bouncing physics surfaces this as negative pixels on a `ScrollUpdateNotification`; clamping physics surfaces it as an `OverscrollNotification` — both paths are handled, gated on `armed && dragDetails != null`.
   - **Phase 3 (commit):** on release (`ScrollEndNotification` / idle `UserScrollNotification`), crossing `threshold` navigates; otherwise the content springs back. A `_committed` guard prevents a double-fire across the idle + end notifications.
   - Threshold raised to **96px** (max pull **150px**) with a single rubber-band resistance curve; haptic tick + "Release" pill at the threshold are retained. Horizontal scrollables (tags filter bar) are ignored via an `axis == Axis.vertical` guard.
   - New optional `hintText` parameter lets each surface label the revealed bar.

2. **Editor reuses the shared engine, tailored** ([`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)):
   - The inline `NotificationListener` is replaced by `PullDownSearchReveal` wrapping `IntelligentHeadingScrollbar`, gated on `swipeToSearchEditor`, labelled `'Find in note'`, committing to the inline find bar (`_openSearch()`) rather than navigating.
   - The editor's body `SingleChildScrollView` physics changed from `AlwaysScrollableScrollPhysics` to `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` so overscroll is reported consistently across platforms (clamping Android previously emitted none).

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Dedicated Tests ([`test/features/notes/gestures_test.dart`](file:///home/dog/git/quitepaper/test/features/notes/gestures_test.dart)): drag distances retuned to the new 96px threshold; added **"a drag that starts mid-list and scrolls up into the top does NOT open search"** covering the two-phase guard. Editor coverage (`test/editor/in_note_search_test.dart`) continues to pass for both the enabled reveal and the disabled setting.
- Full Test Suite: `flutter test` (all tests passing).

---

## 157. Global Search UI Redesign: Editorial Large-Title, Segmented Filter Control & Decluttered Empty State (October 2026)

### 1. Summary
The Global Search screen ([`lib/features/search/presentation/search_screen.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart)) looked unfinished and "un-premium": the query was a bare `TextField` floating in the `AppBar` with no field affordance, the category filters were four separately-bordered pills with chunky count badges, and the empty state stacked a large grey magnifier above a hint line that merely repeated the field placeholder. Three coordinated changes bring it in line with the warm-editorial aesthetic: an **editorial large-title header with a contained search field**, a **sliding segmented control** for the category filters, and a **decluttered empty state**.

### 2. Changes

1. **Editorial large-title header** ([`search_screen.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart)):
   - The `TextField` is removed from the `AppBar` `title`; the bar is now just `←` (back) and `+` (new note). The old inline clear action in the `AppBar` is gone.
   - A new `_buildHeader()` renders a large **"Search"** title (`AppTypography.display`, 30sp) above `_buildSearchField()`. The title is wrapped in `AnimatedSize` and **collapses when a query is active** (`hasQuery`) so the results list gains vertical room — an iOS-style large title that recedes on active search.
   - `_buildSearchField()` is a contained, filled field: `colors.surface` fill, `AppRadii.borderLg`, 1px `borderSubtle`, a leading `search_rounded` glyph, and an **inline clear button** driven by a `ValueListenableBuilder` on the controller so it toggles instantly (not after the 150ms search debounce).

2. **Segmented filter control** ([`search_filter_bar.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/widgets/search_filter_bar.dart)):
   - The four bordered pills are replaced by a single rounded track (`colors.surfaceSubtle`) holding four equal `Expanded` segments. An `AnimatedPositioned` elevated "thumb" (`colors.surface` + soft shadow) slides between positions (220ms `easeOutCubic`) to mark the selection.
   - Counts become light inline numbers (`textTertiary`, 10.5sp) instead of filled badges. The selected label is `textPrimary`/w600, unselected `textSecondary`/w500.
   - The long **"Documents & OCR"** label is shortened to **"Docs"** so four segments fit an equal split on phones (the results section header still reads "DOCUMENTS & SCANNED OCR"). Each segment carries a stable `ValueKey` (`search_filter_all|notes|documents|tags`) for testability. The `searchFilterProvider` read/write and `SearchFilter` mapping are unchanged.

3. **Decluttered empty state** (`_buildInitialState` in [`search_screen.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart)):
   - The centered magnifier icon and duplicate "Search notes, documents, OCR text, or tags" hint are removed in favour of a single quiet one-line intro. The "TAGS SHORTCUTS" header is renamed **"QUICK TAGS"**. Pinned-tag and quick-tag chip sections are otherwise unchanged.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found**).
- Test update ([`test/search/ocr_global_search_test.dart`](file:///home/dog/git/quitepaper/test/search/ocr_global_search_test.dart)): the filter assertions follow the "Docs" label and tap the `documents` segment by its `ValueKey` rather than by the removed "Documents & OCR" text.
- Full Test Suite: `flutter test` (all tests passing).

---

## 158. Inline Table Editing + Full-Screen Table Workspace (October 2026)

### 1. Summary
Markdown tables in the two visual editor modes could not be edited in place. **Super Editor** mode opened a modal bottom-sheet popup to edit a table; **WYSIWYG** mode could not edit cells at all (its `onCellTap` was a no-op — only add-row/delete existed). Both now support **inline tap-to-activate editing** (matching Markdown mode) and an **expand button that opens a full-screen enhanced table workspace** on a new route. The bottom-sheet popup is removed.

### 2. Architecture
All three surfaces now share the existing cell-edit engine (`MarkdownTableController` + `MarkdownTableEditor`), which operates on a **standalone table-Markdown string** via `getDocumentValue`/`onUpdateDocument` callbacks. Each surface bridges its native table representation to that string:
- **Super Editor** ([`quiet_table_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_table_component.dart)): serializes the `TableBlockNode` to Markdown; commits edits back via `ReplaceNodeRequest`. Following the §155 frontmatter lesson, the node is rewritten **only on commit** (tap "Done"/Escape, or returning from full-screen) — typing never tears down the live component.
- **WYSIWYG** ([`rich_table_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_table_editor.dart)): reconstructs Markdown from the `TableBlock.table` rows' `rawLine`; commits via the new `RichDocumentController.updateTable(blockIndex, MarkdownTable)` → `RichDocumentMutations.updateTable` (replaces the block in place, preserving its id). Also commits only on done.

### 3. New building blocks
- **Formatter ops** ([`markdown_table_formatter.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_table_formatter.dart)): `moveRow`, `moveColumn` (alignment travels with the column), `duplicateRow`, `duplicateColumn` — source-preserving, following the existing full-rebuild pattern. Controller wrappers: `duplicateCurrentRow/Column`, `moveCurrentRow/Column`, and `reloadFrom` (re-projects after an external Markdown rewrite).
- **Clipboard parser** ([`table_clipboard_parser.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/table_clipboard_parser.dart)): RFC-4180 CSV + TSV → `List<List<String>>` for paste-to-fill.
- **Full-screen workspace** ([`table_editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/table/table_editor_screen.dart)): a `MaterialPageRoute` editing one table's Markdown in isolation and returning the result via `Navigator.pop` (empty string = delete). Reuses `MarkdownTableEditor` for the grid and adds an app bar with **undo/redo** (Markdown-snapshot stacks), and an overflow menu for **duplicate row/column, move row/column, promote-row-to-header, paste CSV/TSV, and live-preview toggle**. Add/remove row & column, per-column alignment, and inline cell formatting come from the reused editor + toolbar.

### 4. Notes & constraints
- "Make row the header" swaps the chosen row with the header row (GFM requires a header; there is no header-off state).
- View-only enhancements still pending (not persisted to Markdown by design): sticky header row, resizable column widths, density toggle, fit-to-width, row/column multi-select, and drag-to-reorder in the full-screen grid. The formatter `moveRow`/`moveColumn` ops that back drag-reorder already exist and are wired to the overflow menu's move actions.

### 5. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found, 0 warnings**).
- Dedicated tests: `test/editor/markdown_table_formatter_ops_test.dart` (move/duplicate ops), `test/editor/table_clipboard_parser_test.dart` (CSV/TSV), `test/editor/table_editor_screen_test.dart` (full-screen render, duplicate-row-returns-changed-markdown, delete sentinel), and a new Super Editor case asserting a cell tap activates the inline `MarkdownTableEditor` (no popup).
- Full Test Suite: `flutter test` (all tests passing).

## 159. Journal: Backfilling Historical Entries by Date (October 2026)

### 1. Summary
The Journal could only ever create **today's** entry — the sole creation path was `openOrCreateTodayFlow` (sidebar "Today"), and selecting a past date on the calendar showed a dead "No journal entry" label. This blocked the real use case of transcribing **old paper-diary entries** (each dated in the past, often with a photo of the physical page attached). Two entry points now let you create a journal entry for **any date up to today**: a "Write entry for this day" button on the calendar's selected-date preview, and an "Add past entry" (`calendarPlus`) button in the All Entries top bar that opens a date picker.

### 2. Architecture
No data-layer change was needed. `DriftNotesRepository.getOrCreateJournalEntry(DateTime)` ([`notes_repository.dart`](file:///home/dog/git/quitepaper/lib/features/notes/data/notes_repository.dart)) already accepts an arbitrary date and already enforces the at-most-one-per-day invariant via the `notes_journal_date_unique_idx` partial index and race-safe retry. The gap was purely in the flow/UI layer.
- **`JournalService`** ([`journal_service.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/journal_service.dart)): added `getOrCreateForDate(DateTime)` and generalized `openOrCreateTodayFlow` into `openOrCreateEntryFlow(context, date, …)`. `openOrCreateTodayFlow` is now a thin wrapper passing `DateTime.now()`, preserving the sidebar "Today" behaviour and the trash-restore confirmation (its dialog copy is now date-specific, e.g. "March 14, 2019 is in Trash").
- **Ordering is unaffected.** Every journal surface orders by the `date` frontmatter (`journal_date`), not timestamps (`app_database.dart` timeline/calendar/On-This-Day queries all `OrderingTerm.desc(journalDate)`). A backfilled entry therefore slots into the correct chronological position regardless of when it was transcribed, so `createdAt`/`updatedAt` are deliberately left as the real transcription time. (Side effect: a freshly transcribed historical entry surfaces at the top of the main Library list, which sorts by `updatedAt` — accepted, not a journal-view concern.)

### 3. UI entry points
- **Calendar selected-date preview** ([`journal_calendar_view.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/journal_calendar_view.dart)): `_SelectedDatePreview`'s empty branch now renders a "Write entry for this day" `TextButton` when the selected date is today-or-earlier (gated via `dateString.compareTo(JournalDateHelper.todayString()) <= 0`; future dates still show only "No journal entry"). `JournalCalendarView` gained a required `onCreateEntry(DateTime)` callback.
- **All Entries top bar** ([`journal_all_entries_view.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/journal_all_entries_view.dart)): a `calendarPlus` "Add past entry" button (both phone and tablet bars) opens `showDatePicker` (`firstDate: 1900`, `lastDate: today`). Both entry points route through `_createEntryForDate`, which sets `calendarVisibleMonthProvider`/`calendarSelectedDateProvider` so the chosen day stays in context, then calls `openOrCreateEntryFlow` (tablet-aware). Transcription text + the diary-page photo then use the existing editor (image insertion via `FilePicker`) with no new code.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found**).
- Tests: added `getOrCreateForDate` backfill + one-per-day idempotency cases to `test/journal/journal_service_test.dart`. Existing journal suite (incl. "selecting empty date never auto-creates today note") still green.
- Full Test Suite: `flutter test` (all tests passing).

## 160. Journal Location Features — Shared Cached Metadata (§2.1 foundation) (October 2026)

### 1. Summary
First slice of the Journal Location Features spec (`docs/specs/journal-location-features.md`). Establishes the shared data foundation every location feature reads from: journal `location`, `moment`, `mood`, and `weather` are now parsed once and cached on `NoteMetadata`, so no list tile, calendar cell, or Places surface re-parses frontmatter per frame. No user-visible change yet; this unblocks Features 1–4.

### 2. Architectural Adjustments & Implementation Details
- **`NoteMetadata`** ([`note_metadata_extractor.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_metadata_extractor.dart)) gained four nullable fields: `JournalLocation? location`, `String? moment` (normalized key), `int? mood`, `JournalWeather? weather`.
- **Population** reuses `FrontmatterEditorHelper.parse(note.content)` rather than new regexes, inside the existing `extract()` path so the values ride along on the existing content-hash LRU cache (max 500) for free on cache hits. A cheap `trimLeft().startsWith('---')` guard skips the parse for RichDocument-JSON and frontmatter-less notes.
- **Privacy:** metadata is nulled for `isPasswordProtected` notes, mirroring the existing nulling of `attachmentSummary`/`thumbnailData` — locked notes expose no location/moment/mood/weather.
- **"No location" normalization:** a parsed `JournalLocation.isEmpty` (blank address + 0/0 coords) or empty `JournalWeather` is stored as `null`, so downstream features test a single nullable rather than re-checking `isEmpty`.

### 3. Decisions (carried for later phases)
Merge/alias store (§2.3) will be **device-local (SharedPreferences)** for now rather than synced; §2.4 travel-dates provider will **derive from this cached `moment`** (no DB column); §6.7 home detection is **skipped** (never specified).

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues found**).
- Tests: new `test/notes/note_metadata_journal_test.dart` — parses all four fields; locked notes nulled; cache hit returns the same instance; empty/absent location → `null`; non-journal note → all null.
- Full Test Suite: `flutter test` (**all 1668 tests passing**).

## 161. Journal Location Features — Place Grouping Service (§2.2) (October 2026)

### 1. Summary
Pure domain service that groups journal entries by place, powering the forthcoming Places page (Feature 4). No UI, DB, or network — just deterministic grouping logic with thorough unit coverage.

### 2. New building blocks
- **`lib/core/journal/domain/journal_place.dart`**: `JournalPlace` aggregate (display name, normalized match key, granularity, member note ids, first→last date span, `isUnnamed`); `PlaceGranularity {city, region, country}`; `PlaceSortOrder {frequency, recency, firstSeen, alphabetical}` with a stable `matchKey` tiebreak via `comparatorFor` / `sorted`.
- **`lib/core/journal/application/place_grouping_service.dart`**: `PlaceGroupingService.group(entries, {granularity, aliases, sortOrder, coordinateClusterRadiusMeters})`. Input is a decoupled `PlaceEntryInput {noteId, JournalLocation, date}` so the service never imports `Note`/`NoteMetadata`.

### 3. Design
- **Label-first, radius-second — never exact-coordinate match.** Labeled entries (non-blank address) key off comma tokens: City = first token, Country = last token, Region = `city|region` (token before country when ≥3 tokens). Match key normalization lowercases, strips Latin diacritics (dependency-free folding table incl. `ß`→`ss`, `æ`→`ae`), collapses whitespace; a separate pretty display label keeps casing/diacritics.
- **Radius fallback** for blank-address-with-coords entries: greedy seed-anchored haversine clustering (`defaultSpotRadiusMeters` 250 m, `defaultNeighborhoodRadiusMeters` 1500 m default), named `Unnamed place near <lat>, <lng>`.
- **Alias map** (`Map<String, PlaceAlias>`) remaps/renames normalized keys — the §2.3 store that fills it is built later; the service just consumes it.
- Fully deterministic ordering throughout.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `test/journal/place_grouping_service_test.dart` — normalization (diacritics/case/whitespace), alias merge + rename, radius within/outside spot vs neighborhood, haversine known distances, City/Region/Country, all four sort orders + tiebreak determinism.
- Full Test Suite: `flutter test` (all passing).

## 162. Journal Location Features — On This Day Place (Feature 3) (October 2026)

### 1. Summary
Each historical entry on the On This Day view now appends its place to the date + relative-year line, e.g. `October 9, 2020 · 6 years ago · Mumbai`.

### 2. Implementation
[`on_this_day_view.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/on_this_day_view.dart): in `_OnThisDayTile`, read location from the cached `NoteMetadata` (`NoteMetadataExtractor.extract(note).location`) — never re-parsed in `build()`. When non-null, a ` · <City>` segment (muted `colors.textSecondary`, caption) is appended in a `Flexible` + ellipsis so a long city can't overflow or grow tile height, and the accessibility `semanticLabel` gains the place too. City is the first non-empty comma token of the address (tiny private `_cityLabel` helper; §2.2 centralizes later). Absent/empty location or a locked note → the line is byte-identical to before.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `test/journal/on_this_day_place_test.dart` — place appended when present; identical-to-today when absent; no place for a locked entry.
- Full Test Suite: `flutter test` (all passing).

## 163. Journal Location Features — Calendar Travel Marker (Feature 2 + §2.4) (October 2026)

### 1. Summary
Days whose journal entry is `moment: travel` are now distinguished in the calendar month grid by a **hollow accent ring** (vs the normal filled accent dot) — shape/weight only, single accent color, no legend.

### 2. Implementation
- **§2.4 provider** ([`journal_providers.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/journal_providers.dart)): new `travelDatesForMonthProvider` (`Provider.family<Set<String>, ({int year, int month})>`). Derived from `allJournalEntriesStreamProvider` + cached `NoteMetadata.moment == 'travel'`, filtered to the requested month — **no DB column or query added**; moment is never re-parsed per frame. Empty set while entries load.
- **Marker** ([`journal_calendar_view.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/journal_calendar_view.dart)): a date is travel iff it's in both `journalDates` and `travelDatesForMonthProvider(visibleMonth)`. The dot slot is a fixed 5×5 centered box so no marker ever shifts layout: no entry → nothing; entry → 3.5 px filled `colors.accent` dot; travel → 5 px transparent circle with a 1 px `colors.accent` border (hollow ring). Semantics label appends `', travel'` when applicable.

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `test/journal/calendar_travel_marker_test.dart` — provider travel-date set per month; travel day → ring; non-travel entry → filled dot; empty day → no marker; semantics.
- Full Test Suite: `flutter test` (all passing).

## 164. Journal Location Features — Timeline Dateline + Journal Settings (Feature 1 + §6.6) (October 2026)

### 1. Summary
All Entries timeline tiles now carry a quiet place & weather dateline (e.g. `📍 Kolkata · ☁ 24°`), gated by a new Default Settings toggle. Also adds the two Journal settings toggles the spec requires (the second one is the master switch the later backfill nudge flips off).

### 2. Implementation
- **Settings model/provider** ([`default_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/default_settings.dart), [`default_settings_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/default_settings_provider.dart)): two new SharedPreferences-backed booleans, both default **ON** — `showPlaceAndWeatherOnEntries` and `suggestPlaceForPastEntries` (device-local, not synced).
- **Settings UI** ([`default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart)): a new **JOURNAL** section with "Show place & weather on entries" and "Suggest adding a place to past entries".
- **Dateline** ([`journal_timeline_tile.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/journal_timeline_tile.dart)): converted to a `ConsumerStatefulWidget` so it can read the toggle. Between the preview snippet and the tags, a single-line `Text.rich` composes only the parts that exist (place from cached `NoteMetadata.location` city token with a `mapPin` glyph; weather glyph + rounded °) in `textTertiary` caption, 1 line + ellipsis. Renders a zero-size box (no height) when the toggle is off, the note is locked, or neither part exists — so absent metadata never changes tile height.

### 3. Notes
`suggestPlaceForPastEntries` has no consumer yet; it is wired now so the §6.5 backfill nudge (later phase) only has to read it. The city-token helper is duplicated privately in the timeline tile and On This Day view for now; Feature 4 / §2.2 will centralize it.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `test/journal/journal_timeline_dateline_test.dart` — composes place+weather; place-only; nothing when absent; toggle OFF hides it; locked note hidden.
- Full Test Suite: `flutter test` (**all 1705 tests passing**).

## 165. Journal Location Features — Places Data Layer + Device-Local Merge Store (§2.3) (October 2026)

### 1. Summary
The data layer behind the Places page (Feature 4): providers that group located journal entries into places (reusing §2.2's `PlaceGroupingService`), a drill-in + visit sub-grouping, and a reversible, **device-local** place merge/alias store.

### 2. New building blocks
- **`lib/features/journal/application/place_alias_store.dart`**: `PlaceAliasStore extends StateNotifier<Map<String, PlaceAlias>>` + `placeAliasStoreProvider`. `merge(matchKeys, {canonicalKey, displayName})`, `rename({canonicalKey, displayName})`, `unmerge(matchKey)`. Persists one JSON key `journal_place_aliases` in SharedPreferences, with a corrupt-payload guard and in-memory fallback when prefs is absent.
- **`lib/features/journal/application/places_providers.dart`**: `placeGranularityProvider` (default city), `placeSortOrderProvider` (default recency), `placeListProvider` (groups active/non-locked/located entries; **silently excludes** unlocated — §6.4), `placeEntriesProvider(matchKey)` (reverse-chrono members), `placeVisitsProvider(matchKey)`.
- **`lib/features/journal/domain/journal_visit.dart`**: pure `JournalVisit` + `clusterVisits(reverseChronoNotes, {gapThresholdDays = 30})`; a gap > threshold starts a new visit, labeled `October 2024` or `October 2024 – November 2024`.

### 3. Decision (locked, deviates from §2.3)
The merge store is **device-local SharedPreferences, not synced** (per the user's decision for this pass). It is presentation-only — it never mutates note frontmatter — and is fully reversible via `unmerge`.

### 4. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `place_alias_store_test.dart`, `places_providers_test.dart`, `journal_visit_test.dart` — merge/rename/unmerge + persistence round-trip; located-only grouping with granularity/sort/alias; visit gap splitting + labels.
- Full Test Suite: `flutter test` (all passing).

## 166. Journal Location Features — Places Page UI + Navigation (Feature 4) (October 2026)

### 1. Summary
The **Places** journal surface: a map-free, editorial browser of journal entries grouped by place, with a City/Region/Country granularity toggle and a Frequency/Recency/First-seen/A–Z sort, drilling in to a place's entries sub-grouped by visit. New sidebar destination under "On This Day".

### 2. Navigation wiring (mirrors `onThisDay`/`allJournalEntries`)
- [`notes_provider.dart`](file:///home/dog/git/quitepaper/lib/features/notes/application/notes_provider.dart): `places` added to `AppDestination` + `WorkspaceContextType`; `WorkspaceContext.places`, `isPlaces`; cases in `workspaceContextProvider` + `filteredNotesStreamProvider`.
- [`notes_query_provider.dart`](file:///home/dog/git/quitepaper/lib/features/notes/application/notes_query_provider.dart): `places → NotesContext.active` in both switches.
- [`note_empty_state.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_empty_state.dart): `places` case.
- [`notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart): title, preserve-open-note set, null-appBar group, and `AppDestination.places → JournalPlacesView` routing in both the phone and tablet branches.
- [`sidebar_view.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart): a "Places" row below "On This Day" (`mapPin` regular/fill selected-swap). *(All switch sites were found by running whole-project `flutter analyze` after the enum change.)*

### 3. UI (new, under `lib/features/journal/presentation/`)
- `journal_places_view.dart` — `JournalPlacesView` (constructor mirrors the other journal views: `onOpenDrawer`, `isTablet`, `isSidebarVisible`, `selectedNoteId`, `onToggleSidebar`, `onNoteSelected`). List ⇄ drill-in via internal state; in-scroll editorial "Places" header; single-accent `_SegmentedToggle` for granularity + sort; calm `_PlacesEmptyState` ("Places you write from will gather here.") — no Unknown/Without-location bucket.
- `widgets/place_card.dart` — typographic `PlaceCard` (no map): name + region/country secondary, date span (`Oct 2024` / `2024` / `2019 – 2026`), entry count.
- `widgets/place_detail_view.dart` — `PlaceDetailView`: header + entries reusing `JournalTimelineTile`, sub-grouped by `placeVisitsProvider` with `October 2024 · 5 entries` sub-headers; respects `selectedNoteId` / `onNoteSelected`.

### 4. Deferred (later phases / out of scope)
Manual merge/rename UI and the §6.5 backfill nudge are not built here (the alias store is already applied by `placeListProvider`). Per-entry `openInMaps` in the drill-in was left out (optional in §6.3; `JournalTimelineTile` has no action hook). No aggregate map, no map tiles, no thumbnails (§8).

### 5. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `test/journal/journal_places_view_test.dart` — cards per located place + unlocated excluded; learning/empty state; Country toggle collapses to one card; sort reorders; drill-in visit sub-header + tiles + back.
- Full Test Suite: `flutter test` (**all 1729 tests passing**).


---

## 167. Journal Location Features — Backfill Nudge + Place Picker (§6.5/§6.6) (October 2026)

### 1. Summary
The §6.5 backfill nudge: an inline, dismissible prompt rendered above the editor body that offers to add a place to a journal entry that has none. Manual only — location is never inferred. Opens a map-free place picker (known places / typed custom / current device location). Consumes the §6.6 settings fields (already present) and a new device-local per-day suppression set.

### 2. Trigger (all must hold — `BackfillPlaceNudge.build`)
Journal entry (`note.isJournal || frontmatter.isJournal`) AND not password-protected AND cached `NoteMetadataExtractor.extract(note).location == null` AND `defaultSettings.suggestPlaceForPastEntries` ON AND the entry's `YYYY-MM-DD` not in the device-local suppression set AND not dismissed-for-now (ephemeral). Any failing condition renders `SizedBox.shrink()`. Locked notes are short-circuited before any location read (§8).

### 3. Files
- NEW [`backfill_suppression_store.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/backfill_suppression_store.dart) — `BackfillSuppressionStore extends StateNotifier<Set<String>>`; `suppressDay(date)` + `isDaySuppressed(date)`; JSON list in SharedPreferences key `journal_backfill_suppressed_days`; **device-local, not synced** (§7). `backfillSuppressionProvider` mirrors the prefs + try/catch fallback of `place_alias_store.dart`.
- NEW [`backfill_place_nudge.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/backfill_place_nudge.dart) — the four-action nudge (Add place / Not now / Don't ask again for this day / Don't ask again). Writes via `FrontmatterEditorHelper.updateLocation` → the editor's `onDocumentChanged`, then `NoteMetadataExtractor.invalidate(note.id)`.
- NEW [`place_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_picker_sheet.dart) — bottom sheet returning a `JournalLocation?`: known places from `placeListProvider` (resolved from the most recent member entry's cached location, falling back to `JournalLocation(address: displayName, 0, 0)`), typed custom place, and `LocationService().fetchCurrentLocation()` with a "now may differ" caveat. No maps/tiles.
- EDIT [`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart) — one import + one block rendering `BackfillPlaceNudge` right after `FrontmatterPropertiesSection`, gated `showsPropertiesSection && !editorState.isReadOnly`, passing `note`, `rawDocument: contentText`, `isJournal`, and the same `onDocumentChanged` sink (`_contentController.text = updated; editorNotifier.updateContent(updated)`), so autosave persists the write.

### 4. Verification & Quality
- Static Analysis: whole-project `flutter analyze` — **No issues found!**
- Tests: `test/journal/backfill_suppression_store_test.dart` (store add/idempotent/persist-reload/corrupt-fallback/in-memory) + `test/journal/backfill_place_nudge_test.dart` (visibility: positive + each negative case; Add place custom + known-place writes location; Not now persists nothing; per-day suppression affects only that date; Don't-ask-again flips the master toggle off + snackbar). Both files green (**16 tests**).
- Full Test Suite: `flutter test` (**all 1745 tests passing**).

## 168. Journal Location Features — Manual Merge / Rename / Unmerge UI (§2.3) (October 2026)

### 1. Summary
The user-facing controls for the device-local place merge/alias store (§2.3): combine 2+ place cards into one (choosing the canonical name), rename a place, and unmerge to restore the originals. Presentation-only, reversible, never mutates note frontmatter. Completes Feature 4 / the location-features spec (only §6.7 home detection remains intentionally unbuilt).

### 2. Implementation
- **Store** ([`place_alias_store.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/place_alias_store.dart)): added `unmergeCanonical(canonicalKey)` — removes every alias entry pointing at a canonical key (incl. the self-map) and persists; no-op when nothing matches. Existing merge/rename/unmerge untouched.
- **Selection mode** ([`journal_places_view.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/journal_places_view.dart) + [`place_card.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_card.dart)): a quiet "Select" top-bar action (shown when ≥2 places) enters a multi-select mode — cards show a leading accent check, selected cards get an accent-tinted background, the granularity/sort toggles hide, and a "Merge" action appears once ≥2 are selected.
- **Dialogs** ([`place_edit_dialogs.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_edit_dialogs.dart)): `PlaceMergeDialog` (canonical-name picker: each selected name as an accent-check choice + a custom field, default = most-frequent selected name), `PlaceRenameDialog` (prefilled), and `showPlaceActionsSheet` (Rename always; Unmerge only when the place is currently merged). Merge derives the canonical key via `PlaceGroupingService.normalizeKey`.
- Per-place Rename/Unmerge are reached via card long-press and a ⋯ button in the drill-in top bar. Unmerge applies immediately (non-destructive/reversible).

### 3. Verification & Quality
- Static Analysis: `flutter analyze` (**0 issues**).
- Tests: `places_merge_ui_test.dart` (select+merge named/custom; rename; unmerge restores; Unmerge hidden when unmerged; merged state persists) + extended `place_alias_store_test.dart` (`unmergeCanonical`).
- Full Test Suite: `flutter test` (**all 1754 tests passing**).

## 169. Document Scanner — Real Capture Modes / Presets Pipeline (October 2026)

### 1. Summary
Replaced the scanner's **fake presets** (global brightness/contrast knobs) with real, spatial **capture modes** — Office Lens–style — selected from a post-capture thumbnail carousel. Implements the approved spec/design in [`docs/specs/scanner-presets-spec.md`](file:///home/dog/git/quitepaper/docs/specs/scanner-presets-spec.md) + [`scanner-presets-design.md`](file:///home/dog/git/quitepaper/docs/specs/scanner-presets-design.md). Modes: **Original, Auto, Document, Whiteboard, Grayscale, B&W Text**. Each is a genuine image pipeline (illumination flatten, adaptive threshold, gray-world white balance, unsharp), not a color-matrix curve. Per-page selection, last-used-mode memory, and composition with the existing tone sliders + crop/rotate.

**Scope note:** the original spec locked `opencv_core` as the processing library. This feature ships on **pure-Dart pipelines** (`package:image`) behind the existing `ImageProcessor` seam — every platform, no native dependency. OpenCV (`dartcv4`) was later prototyped behind the same seam and **dropped for app size** (see the §7 follow-up below). App-size delta: **none**.

### 2. New concept: `ScanMode`
- [`scan_mode.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/scan_mode.dart) — the `ScanMode` enum, orthogonal to `ImageAdjustments` (a mode sets the base look; the knobs fine-tune on top). `defaultMode = auto`; `isMonochrome`/`isBinary` drive knob precedence; `label`/`description` for UI; `fromName` for forward-compat.
- Modes are ephemeral per-page scan-session state, baked into the PDF at compile time. **Not persisted** anywhere — raw photos are discarded after compile and no scan-draft serialization exists (HANDOFF §41 / design §0,§8). `ScannedPage` gained a `scanMode` field (+ `copyWith`).

### 3. Pipelines
- [`scan_pipelines.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/scan_pipelines.dart) — pure static functions, isolate-safe. Building blocks: **illumination flatten** (background estimated on a downscaled gaussian-blurred copy, upscaled, divided out → removes soft shadows, drives paper to white; resolution-independent cost), **adaptive threshold** (per-pixel vs local mean − C), **3×3 median despeckle**, **gray-world white balance**, **unsharp mask**, **near-white push** (whiteboard). `ScanPipelines.apply(image, mode)` maps each mode to its recipe.

### 4. `ImageProcessor` seam
- [`image_processor.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/image_processor.dart) — added `renderModePreviews(sourceBytes, {modes, maxDimension})` (decode once → one baked thumbnail per mode for the carousel, run in a `compute` isolate) and a `ScanMode mode` param on `process`/`processHighResolution` (default `original` = today's behavior). Final compile order per design §7: `bakeOrientation → rotate → crop → downscale(2048) → MODE pipeline → tone knobs → encodeJpg`; the raw-passthrough fast path now also requires `mode == original`. Precedence: under a monochrome mode the saturation knob is forced off. `enhanceForOcr` upgraded to route through flatten + adaptive-threshold (crisper ML Kit input).

### 5. UI
- NEW [`scan_mode_carousel.dart`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/scan_mode_carousel.dart) — horizontal baked-thumbnail strip; placeholder tiles while previews bake.
- [`document_scanner_screen.dart`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/document_scanner_screen.dart) — `_lastUsedMode` (new captures inherit it) + a `_modePreviews` cache keyed by page id (baked off-isolate after capture, dropped on delete/retake). Carousel shown on phone (above the page strip) and tablet (bottom overlay); the active canvas + both page-thumbnail strips now render the baked selected-mode bytes with the tone color-matrix on top. Finalize passes `mode: page.scanMode`.
- [`page_adjustment_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/page_adjustment_sheet.dart) — the 3 fake preset pills replaced by a 6-mode thumbnail selector; canvas base is the baked mode render (tone knobs stay GPU-live on top, design §6); grayscale toggle + saturation slider disabled under a monochrome mode. Returns `scanMode` on the page.
- [`image_viewer_modal.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/image_viewer_modal.dart) — image editor reuses the sheet; save path now passes `mode` and treats a non-`original` mode as a modification.

### 6. Verification & Quality
- Static Analysis: whole-project `flutter analyze` — **No issues found!**
- Tests: NEW [`scan_pipelines_test.dart`](file:///home/dog/git/quitepaper/test/scanner/scan_pipelines_test.dart) — enum metadata/`fromName`; B&W is near-binary on a shadowed page; Auto drops background variance; Whiteboard brightens the paper >230; every mode returns a valid same-size image; `renderModePreviews` covers all 6 modes + never throws on garbage; `processHighResolution` composes mode + knobs + crop/rotate; mono-knob precedence; `enhanceForOcr` binarizes. Updated `scanner_editor_overhaul_test.dart` + `image_viewer_modal_test.dart` for the new mode UI (B&W → "B&W Text") and the `FakeImageProcessor` override.
- Full Test Suite: `flutter test` (**all 1766 tests passing**).

### 7. Open follow-ups
- ~~Optional: add OpenCV on mobile for faster/higher-quality pipelines.~~ **Evaluated and dropped (2026-10-10):** prototyped on branch `feat/scanner-opencv` with `dartcv4` (opencv_core is discontinued). It increased the app size (bundled OpenCV native libs) for little perceived gain over the pure-Dart pipelines, so it was abandoned — branch and files deleted. The pure-Dart implementation is the shipping one; do not re-add OpenCV without a size/benefit case.
- Deferred separate spec: real edge detection + perspective dewarp (replace the hardcoded 3% `normalizePage` inset).
- Carousel/canvas apply the mode on the oriented preview (crop/rotate are overlaid live, not baked into the preview); final compile bakes geometry before the mode. Immaterial for the modes shipped; revisit if a mode becomes crop-edge-sensitive.

## 170. Visual (WYSIWYG) Editor — Attachment Cards + Encrypted Image Fix (October 2026)

### 1. Summary
Brought the home-grown Visual / WYSIWYG editor (the custom `rich_block` model, not super_editor) to parity with the Markdown preview and super_editor for embedded **document** and **generic-file** attachments, and fixed its broken **encrypted-image** rendering. Previously only `![alt](url)` became a block (an `ImageBlock`); link-form `qp://` references (`[name](qp://asset/<UUID>)` for files, `[title](qp://document/<UUID>)` for documents) stayed inline hyperlinks, and `ImageBlock` rendered `qp://asset` images with a raw `Image.file`/`Image.network`, so encrypted images only showed a placeholder.

The canonical on-disk Markdown contract is unchanged and byte-compatible across all editors + preview + sync: image asset → `![alt](qp://asset/<UUID>)`; generic file → `[name](qp://asset/<UUID>)` (link form, no `!`); document → `[title](qp://document/<UUID>)` (link form).

### 2. New block: `AttachmentBlock`
- [`rich_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/domain/rich_block.dart) — new `AttachmentBlock` (fields: `uri`, `name`, `kind`) with an `AttachmentBlockKind` discriminator (`document` vs `file`; `fromName` defaults to `file` for forward-compat). `plainText => name`. Standard `toJson`/`fromJson` (`type: 'attachment'`) wired into `RichBlock.fromJson`'s dispatch. `ImageBlock` is untouched and still used for images.

### 3. Parser / Serializer
- [`rich_document_parser.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_parser.dart) — new `_parseStandaloneAttachment` promotes a line that is *exactly* a single Markdown link whose URL parses (via `QuietPaperUri.tryParse`) as `qp://document` (→ `document` kind) or `qp://asset` (→ `file` kind) into an `AttachmentBlock`. Runs right after the standalone-image check; image syntax (`![..]`) still wins. Inline links inside a larger paragraph, and non-`qp` links, stay regular inline link spans.
- [`rich_document_serializer.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/rich_document_serializer.dart) — `AttachmentBlock` → `[name](uri)` (link form, no leading `!`). `ImageBlock` still → `![alt](url)`.

### 4. Renderers
- NEW [`rich_attachment_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_attachment_block.dart) — renders `QuietDocumentCard` (document kind) or `QuietAttachmentCard` (file kind), reusing the core cards unmodified. The card's own tap opens the resource; a small overlaid delete control (`QuietIconButton`, top-right) removes the block via `controller.convertBlockToParagraph(blockIndex)` — the same affordance `RichImageBlock` uses.
- [`rich_image_block.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_image_block.dart) — when `block.url` parses as a `qp://asset` URI, the image surface now renders via `QuietAssetImageView(assetId:…, noteId:…)` (resolves + decrypts encrypted assets) instead of raw `Image.file`/`Image.network`; the self-sizing view is placed directly (not inside the fixed 360px `Center`) to avoid an overflow. Raw http/file URLs keep the existing rendering + bounded box. The caption/url bar and delete button are unchanged.
- [`rich_editor_surface.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_editor_surface.dart) — added an `AttachmentBlock` branch to the non-text block switch and a new optional `noteId`, forwarded to `RichImageBlock`.
- [`markdown_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/markdown_editor.dart) — passes `noteId: widget.noteId` to `RichEditorSurface` (mirrors how `QuietSuperEditor` already receives it). Inserts remain handled upstream: `editor_screen` routes snippets through the controller, which re-parses Markdown, so the new parser rule is what makes link-form inserts render as cards.

### 5. Verification & Quality
- Static Analysis: `flutter analyze` — **No issues found!**
- Tests: extended [`rich_document_parser_serializer_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_document_parser_serializer_test.dart) — standalone document/asset links → `AttachmentBlock` (correct kind), image-form asset stays `ImageBlock`, inline/non-`qp` links stay paragraphs, the mixed `[doc]/[file]/![img]` document round-trips **byte-identically**, and an `AttachmentBlock` JSON round-trip for both kinds. Existing `editor_image_upload_compression_test.dart` continues to pass (the encrypted-image path keeps the url caption text it asserts).

## 171. Super Editor — Embedded Document & File Attachment Cards (October 2026)

### 1. Summary
Super Editor mode now embeds **document** (`[title](qp://document/<UUID>)`) and **generic-file** (`[name](qp://asset/<UUID>)`) attachments as rich cards, matching the Markdown preview and the Visual editor (§170). Previously only image syntax (`![alt](qp://asset/<UUID>)`) became a block (`ImageNode`); link-form documents and files deserialized to a `ParagraphNode` with a `LinkAttribution`, so they rendered as plain inline hyperlinks. The canonical on-disk Markdown is unchanged and byte-compatible (see §170 for the contract).

### 2. New node: `QuietAttachmentNode`
- NEW [`super_editor/quiet_attachment_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart) — `QuietAttachmentNode extends BlockNode` (mirrors `ImageNode`; fields `uri`, `displayText`; blockType `quietAttachment`). A dedicated node (not an overloaded `ImageNode`) so it round-trips to link form and never gets rewritten to `![..]` by the built-in `ImageNodeSerializer`.

### 3. Deserialize-time promotion + serializer
- `promoteQuietAttachmentNodes(MutableDocument)` — after `deserializeMarkdownToDocument`, swaps every `ParagraphNode` whose text is exactly one whole-span `LinkAttribution` resolving (via `QuietPaperUri.tryParse`) to `qp://document`/`qp://asset` for a `QuietAttachmentNode` (reusing the paragraph's id). Headings/quotes/code blocks and inline/partial links are skipped. Called from `QuietSuperEditor._initEditor` and `QuietSuperEditorController.insertSnippet`.
- `QuietAttachmentNodeSerializer` (`NodeTypedDocumentNodeMarkdownSerializer<QuietAttachmentNode>`) → `[displayText](uri)` link form, with a trailing newline before non-last nodes (same block-isolation trick as `QuietImageNodeSerializer`/`QuietTableBlockNodeSerializer`). Registered in `QuietSuperEditor._onDocumentChange`'s `customNodeSerializers`.
- [`quiet_image_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart) — `normalizeMarkdownForSuperEditor` now also blank-line-isolates standalone `[..](qp://document|asset/...)` link lines so they deserialize as their own paragraph (then get promoted).

### 4. Renderer
- `QuietAttachmentComponentBuilder` / `QuietAttachmentComponent` render `QuietDocumentCard` (document) or `QuietAttachmentCard` (file) — the cards' own tap opens the resource — with a small corner "Remove from note" control that executes `DeleteNodeRequest` (mirrors the table component's delete). Registered in `QuietSuperEditor`'s `componentBuilders` ahead of the defaults; `showRemove` is gated on `!readOnly`.

### 5. Insertion paths (shared with Visual mode)
- [`quiet_super_editor_controller.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/quiet_super_editor_controller.dart) — `insertSnippet` now detects standalone `qp://document|asset` link snippets as block content, normalizes + deserializes + `promoteQuietAttachmentNodes`, and inserts via `PasteStructuredContentEditorRequest` (so a toolbar/drop/paste insert lands as a card, not inline link text).
- [`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart) — `_handleAttachFile`, `_handleAttachPdf`, and `_handleScanDocument` previously wrote directly into the plain-Markdown `_contentController` (bypassing the active editor). They now route through the mode-aware `_insertSnippetAtCursor` with `\n\n` block isolation, so attachments embed correctly in Super Editor and Visual modes. Drag-drop (`_handleDroppedFiles`) and paste (`_handlePaste`) already used that path.

### 6. Verification & Quality
- Static Analysis: `flutter analyze` — **No issues found!**
- Tests: extended [`quiet_super_editor_test.dart`](file:///home/dog/git/quitepaper/test/editor/quiet_super_editor_test.dart) — promotion of standalone document/file links (image syntax left as `ImageNode`), inline qp link NOT promoted, serializer emits link form (never `![..]`), serialize→deserialize→promote round-trip, and `insertSnippet` with qp document/asset links creating `QuietAttachmentNode`s.

### 7. Branch note
Implemented on `main` (not `feat/scanner-opencv`): that branch's `dartcv4` dependency builds OpenCV via cmake, which is absent in the current environment and blocks `flutter test`. `main` has no such dependency, so the full suite runs there.

## 172. Document Scanner — Automatic Corner Detection & Perspective Dewarp (October 2026)

### 1. Summary
The *shape* half of the scanner overhaul (the modes in §169 were the *look*): replace the fake 3%
`normalizePage` inset with real document geometry — detect the page's four corners on capture, let
the user fine-tune them on a 4-corner overlay, and **perspective-dewarp** the quad into a flat scan
at compile. Pure Dart, no OpenCV (dropped for size, §169). Spec:
[`scanner-corner-detection-spec.md`](file:///home/dog/git/quitepaper/docs/specs/scanner-corner-detection-spec.md).
Built in parallel by three subagents (dewarp / detector / overlay), then integrated.

### 2. New building blocks
- [`document_quad.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/document_quad.dart) — `NormalizedPoint` + `NormalizedQuad` (4 corners clockwise from top-left) with `full`, `fromRect`, `withCorner`, `isConvex`, `isFullFrame`, `boundingRect`, JSON. The shared contract for the three pieces below.
- [`scan_geometry.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/scan_geometry.dart) — `ScanGeometry.dewarp(src, quad, {maxDimension})`: solves the dst-rect→src-quad homography (8×8 Gaussian elimination), forward-maps each output pixel into the source with bilinear sampling. Output size from the quad's edge lengths, capped to `maxDimension`. Returns a clone when the quad is full-frame/non-convex/singular. Pure/isolate-safe.
- [`document_detector.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/document_detector.dart) — `DocumentDetector.detect(img) → ({NormalizedQuad quad, double confidence})`: downscale → grayscale → Otsu threshold → foreground mask → 4 corners as extreme points (handles rotation), both polarities, convexity+fill confidence; low confidence → `(full, 0)`. Never throws.
- [`interactive_quad_overlay.dart`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/interactive_quad_overlay.dart) — draggable 4-corner overlay (scrim outside, accent border, 44px handles) that rejects non-convex drags; mirrors `InteractiveCropOverlay` style.

### 3. Integration
- `ImageProcessor`/[`DartImageProcessor`](file:///home/dog/git/quitepaper/lib/core/image_processing/image_processor.dart): new `detectDocumentQuad(bytes)` (runs the detector in a `compute` isolate); `processHighResolution` gained a `NormalizedQuad? documentQuad` param. Compile order is now **orientation → rotate → (dewarp if quad, else rectangular crop) → downscale → mode → tone → encode**; the raw-passthrough fast path also requires no dewarp. Dewarp supersedes the rectangle crop when a non-full convex quad is present.
- [`ScannedPage`](file:///home/dog/git/quitepaper/lib/features/scanner/domain/scanned_page.dart): `NormalizedQuad? documentQuad` (+ `clearDocumentQuad` in `copyWith`); in-session only.
- [`ScannerPreviewCanvas`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/scanner_preview_canvas.dart): in crop mode shows the quad overlay when a `quad` is supplied, else the rectangle overlay.
- [`PageAdjustmentSheet`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/page_adjustment_sheet.dart): new `enableDocumentQuad` flag (scanner-only; the generic image editor keeps rectangular crop). When on, the Crop & Rotate tab edits the quad and offers **Auto-detect edges** + **Use Full Page**.
- [`document_scanner_screen.dart`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/document_scanner_screen.dart): auto-detects the quad off-isolate on capture (confidence ≥ 0.4 pre-fills it, else full-frame), opens the adjust sheet with `enableDocumentQuad: true`, and passes `documentQuad` into the final compile.

### 4. Verification & Quality
- Static Analysis: whole-project `flutter analyze` — **No issues found!**
- Tests: `scan_geometry_test.dart` (4), `document_detector_test.dart` (5), `interactive_quad_overlay_test.dart` (2), `document_dewarp_integration_test.dart` (detect + dewarp through `processHighResolution`, compose-with-mode, full-frame no-op), plus the `FakeImageProcessor` updated for the new seam.
- Full Test Suite: `flutter test` (**all 1793 tests passing**).

### 5. Follow-ups (Phase 3, per spec §6)
- Magnifier loupe on the dragged corner; output aspect-ratio estimation; capture-time confidence hint; parameter tuning on real captures (pending sample scans). Detection is best-effort by design — manual adjust is always available.

## 173. Document Scanner — Re-open camera on "Add Page" + discard confirmation (October 2026)

### 1. Problem
Once a page was captured the viewport switched to the processed-page review and the live `CameraPreview` left the tree. Tapping "+" / the shutter then called `takePicture()` with no viewfinder visible, so the camera appeared **frozen** (no live feed to frame the next page). Closing the scanner also discarded captured pages with no confirmation.

### 2. Fix (`document_scanner_screen.dart`)
- New `_showCamera` state. The center viewport shows the live camera when `_pages.isEmpty || _showCamera`, else the active-page review.
- "+" slot and (in review) the shutter call `_openCameraForNewPage()` → `resumePreview()` (guards against a frozen texture when the preview re-enters the tree) + `_showCamera = true`, re-mounting `CameraPreview`. The shutter captures when the viewfinder is showing (`_primaryCaptureAction`). A successful capture returns to review (`_showCamera = false`). Tablet "Add Page" button mirrors this (labelled "Capture" while the viewfinder is up). No camera → falls through to file import.
- Discard confirmation: the close (X) and system back now route through `_handleBack()` (via `PopScope(canPop: false)`), which first cancels an in-progress new capture (`_showCamera` → review) and otherwise shows a "Discard scan?" dialog when `_pages.isNotEmpty` before popping.

### 3. Verification & Quality
- `flutter analyze` — **No issues found!**
- Updated the tablet integration test (empty state now reads "Capture", not "Add Page").
- Full Test Suite: `flutter test` (**all 1793 tests passing**).

## 174. Bengali Content Support — Feature A: Kalpurush Font Fallback (October 2026)

Implements §3 of [`docs/specs/bengali-content-support.md`](file:///home/dog/git/quitepaper/docs/specs/bengali-content-support.md). Bengali note content now renders under any chosen Latin/code font by falling through to the bundled Kalpurush face. UI chrome is **not** localized (out of scope).

### 1. Implementation
- **Asset registration** ([`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml)): the already-bundled `assets/fonts/Kalpurush-Regular.ttf` is registered as family `Kalpurush` (single Regular asset).
- **Shared fallback constant** ([`font_family_helper.dart`](file:///home/dog/git/quitepaper/lib/core/utils/font_family_helper.dart)): new top-level `kBengaliFallbackFamily = 'Kalpurush'` and `kContentFontFallback = ['Kalpurush']` — the single source of truth.
- **`FontFamilyHelper.getTextStyle` chokepoint**: refactored into `_resolveTextStyle` (the original family-resolution logic) wrapped by `_withBengaliFallback`, so **every** return path (plain base, serif/monospace copyWith, SF Pro / iA Writer / cached family, and the `GoogleFonts.getFont` path) now carries the fallback. The wrapper preserves any pre-existing fallback and is idempotent (never double-appends Kalpurush). This one change covers the entire TextField/RichText editor (`MarkdownStyles.fromColors` → body/headings/code/blockquote all route through `getTextStyle`, and `MarkdownParser` merges every inline span onto `styles.body`), the markdown preview stylesheet (`QuietMarkdownPreview`), typography previews, and all theme surfaces that call `getTextStyle`.
- **Base app theme** ([`app_theme.dart`](file:///home/dog/git/quitepaper/lib/app/theme/app_theme.dart)): both `light()` and `dark()` now pass `fontFamilyFallback: kContentFontFallback` to `ThemeData` and `.apply(fontFamilyFallback: ...)` to the base `textTheme`, so Material surfaces (note-list titles/snippets, dialogs, menus) fall back too.
- **Super Editor** ([`quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart)): the WYSIWYG path builds its own `Stylesheet` with raw `TextStyle`s and does **not** route through `FontFamilyHelper`, so `fontFamilyFallback: kContentFontFallback` was added to all 11 block `TextStyle`s (base/all, header1–6, paragraph, blockquote, code, task, listItem). Inline bold/italic spans merge onto these block styles, so they inherit the fallback.

### 2. Faux bold/italic (accepted)
Kalpurush ships Regular-only (locked decision §2 of the spec), so headings and `**bold**`/`*italic*` Bengali are engine-synthesized. Accepted for v1.

### 3. Verification & Quality
- New test [`test/utils/font_family_helper_test.dart`](file:///home/dog/git/quitepaper/test/utils/font_family_helper_test.dart): asserts `getTextStyle(...).fontFamilyFallback` contains `'Kalpurush'` for null/`System Sans`/`System Serif`/`monospace`/a Google-font name, and that the append is idempotent.
- `flutter analyze` — **No issues found!**
- Full Test Suite: `flutter test` (**all 1799 tests passing**).

## 175. Bengali Content Support — Feature B: Unicode-aware Search & Tags (October 2026)

Implements §4 of [`docs/specs/bengali-content-support.md`](file:///home/dog/git/quitepaper/docs/specs/bengali-content-support.md). Bengali note content and Bengali `#tags` are now tokenized, indexed, extracted, and matched. Previously ASCII-only `\w` / `[a-zA-Z0-9]` patterns yielded **zero** Bengali tokens, so Bengali notes and tags were invisible to search and the tag filter.

### 1. Implementation — Unicode character class
Every former ASCII word/tag class was replaced with `[\p{L}\p{M}\p{N}…]` (RegExp `unicode: true`):
- **Search tokenizer** ([`search_tokenizer.dart:47`](file:///home/dog/git/quitepaper/lib/core/search/search_tokenizer.dart)): `[\w#]+` → `[\p{L}\p{M}\p{N}_#]+`.
- **Fuzzy re-ranker** ([`fuzzy_search_engine.dart:192`](file:///home/dog/git/quitepaper/lib/core/search/fuzzy_search_engine.dart)): `\b[\w#]+\b` → `[\p{L}\p{M}\p{N}_#]+` (ASCII `\b` boundaries dropped — they never fire between non-ASCII letters).
- **Editor tag regexes** ([`markdown_parser.dart:36`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_parser.dart) `_tagRegex`, [`markdown_tokenizer.dart:421`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_tokenizer.dart)): `#([a-zA-Z0-9_\-\/]+)` → `#([\p{L}\p{M}\p{N}_\-\/]+)`.
- **Tag extraction/validation** ([`tag_parser.dart`](file:///home/dog/git/quitepaper/lib/core/utils/tag_parser.dart) `_tagRegex` and `isValidTag`): also widened to `[\p{L}\p{M}\p{N}_\-/]`.

### 2. Deviations from the spec text (deliberate, to meet its intent)
- **`\p{M}` added beyond the spec's suggested `[\p{L}\p{N}_#]`.** The spec's class omits Unicode **Marks**, but Bengali is full of combining vowel signs (matras), anusvara `ং`, and the conjunct-forming virama `্` — all category `\p{M}`. Verified empirically: without `\p{M}`, `আমি বাংলা` tokenizes as `[আম, ব, ল]` (every word split at the first matra); with it, `[আমি, বাংলা]`. `\p{M}` is required for correct Indic tokenization.
- **`TagParser._tagRegex` + `isValidTag` fixed (not in spec §4.2's list).** Spec §4.2 named only `markdown_parser`/`markdown_tokenizer` for tag *recognition* and said `tag_parser` patterns "should already work". That is true of the escaped-literal *removal* patterns (`_removeTagFromLine`, verified unchanged), **but** `extractTags` → `_tagRegex` + `isValidTag` are ASCII-only and are the real gatekeepers that feed the FTS index (`app_database`), the tag-search service, and the tag filter. Leaving them ASCII would make §4.6's own verification ("a Bengali `#বাংলা` tag is extracted") impossible, so they were widened too. `tag_autocomplete_trigger` uses a terminator class and needed no change (verified).

### 3. Items evaluated and intentionally deferred (known gaps)
- **§4.3 NFC normalization — SKIPPED for v1 (known gap).** Dart core has no NFC and no new dependency was added. More importantly, normalization must be applied consistently across query *and* indexed text or it is actively harmful: the fuzzy re-ranker (`evaluate`) matches the query against the raw, un-normalized note text via `indexOf`/word scan, and `markdown_offset_mapper` relies on a strict 1:1 char map for highlight positioning that NFC (which changes code-point counts) would break. So o-kar/au-kar (ো/ৌ) composed-vs-decomposed equivalence can still cause a self-match miss when IMEs emit different forms. Deferred.
- **§4.4 FTS5 `remove_diacritics 2` — LEFT AS-IS (no migration).** `note_search_prefix` keeps `unicode61 remove_diacritics 2`. It is only a candidate generator; stripping Bengali matras *over-broadens* recall (e.g. করি/কর/করা collapse) but never *excludes* a valid match, and the now-Unicode-aware Dart re-ranker + the (unaffected) trigram index provide precision. Switching to `remove_diacritics 0` would require a risky FTS rebuild migration for marginal benefit, so it was not changed.
- **§4.5 grapheme-aware edit distance — SKIPPED (low priority).** `damerauLevenshtein` still compares UTF-16 code units; acceptable for v1.

### 4. Verification & Quality
- New test [`test/search/bengali_search_test.dart`](file:///home/dog/git/quitepaper/test/search/bengali_search_test.dart): Bengali/mixed tokenization, Bengali hashtag token, Bengali `#tag` + nested-tag extraction, `isValidTag` accept/reject, and a Bengali query matching/not-matching a Bengali note through `FuzzySearchEngine`.
- `flutter analyze` — **No issues found!**
- Full Test Suite: `flutter test` (**all 1808 tests passing**).

## 176. Bengali Content Support — Feature C: Journal Bengali Dates & Numerals (October 2026)

Implements §5 of [`docs/specs/bengali-content-support.md`](file:///home/dog/git/quitepaper/docs/specs/bengali-content-support.md). An opt-in, **display-only** toggle renders journal dates, month names and numerals in Bengali. Canonical date keys and storage stay ASCII `yyyy-MM-dd` always.

### 1. Setting (default OFF)
- `bengaliDates` added to [`DefaultSettings`](file:///home/dog/git/quitepaper/lib/features/settings/domain/default_settings.dart) (model: field, ctor, `copyWith`, `==`/`hashCode`) and [`DefaultSettingsNotifier`](file:///home/dog/git/quitepaper/lib/features/settings/application/default_settings_provider.dart) (SharedPreferences key `setting_bengali_dates`, `setBengaliDates`). Default **false**.
- UI: a "Bengali dates & numerals" switch in the **JOURNAL** section of [`default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart).

### 2. Locale threading (display only)
- Startup: [`main.dart`](file:///home/dog/git/quitepaper/lib/main.dart) now calls `initializeDateFormatting('bn', null)` (added to the existing `Future.wait`) before any `'bn'` DateFormat runs.
- A new `journalLocaleTagProvider` ([`journal_providers.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/journal_providers.dart)) returns `'bn'` when the setting is on, else null — the single source for the active journal display locale.
- [`JournalDateHelper`](file:///home/dog/git/quitepaper/lib/core/journal/domain/journal_date_helper.dart) display methods (`formatDisplayDate`, `formatMonthDay`, `formatMonthYear`, `formatMonthYearHeader`, `formatWeekday`, `formatWeekdayShort`, `formatTimelineEntryMetadata`, `formatDayHeader`) gained an optional `String? localeTag` passed to their `DateFormat`. The canonical/key methods (`toDateString`, `todayString`, `monthKey`, `tryParseMonthKey`, `tryParseDateString`, `_datePattern`) were **not** touched (§5.3).
- Consumers thread the locale from `journalLocaleTagProvider`: `journalMonthGroupsProvider` (timeline month headers), `journal_timeline_tile`, `journal_calendar_view` (+ its `_SelectedDatePreview`), `on_this_day_view` (+ `_OnThisDayTile`), the Places chain (`journal_visit.clusterVisits` → `placeVisitsProvider`; `placeDateSpanLabel` → `PlaceCard`/`journal_places_view` and `_DetailHeader`/`place_detail_view`).
- Left English intentionally (not journal-display, no `ref`): the default-note-title in `notes_repository` and the trash-restore dialog label in `journal_service`; app-wide `date_formatter.dart` is untouched (§5.3). The large day-number glyph in the timeline tile uses `formatDayTwoDigits` (a layout-width primitive, not in the spec's localizable set) and stays Western.

### 3. Verification & Quality
- New test [`test/journal/journal_bengali_dates_test.dart`](file:///home/dog/git/quitepaper/test/journal/journal_bengali_dates_test.dart): with `'bn'`, `formatMonthYear`/`formatDisplayDate`/`formatMonthYearHeader` emit Bengali numerals/month names; null keeps English; `toDateString`/`monthKey`/`tryParseDateString` stay ASCII.
- `flutter analyze` — **No issues found!**
- Full Test Suite: `flutter test` (**all 1815 tests passing**).

## 177. Bengali Content Support — Fix: Kalpurush must fall back only for Bengali, never Latin (October 2026)

Fixes a regression from §174: with the default/System typography (no explicit primary family), **English text rendered in Kalpurush**. Root cause: the bundled `Kalpurush-Regular.ttf` also contains Latin glyphs (A–z, digits, space — 58 Latin entries), and when a style has `fontFamily: null` + `fontFamilyFallback: ['Kalpurush']`, the fallback is consulted ahead of the system font, so Kalpurush — having Latin glyphs — shadowed the system Latin font for all text. (Explicitly-chosen Latin fonts were unaffected, since they sit ahead of Kalpurush in the chain.)

### Fix — ship a Bengali-only subset
- Generated [`assets/fonts/Kalpurush-Bengali.ttf`](file:///home/dog/git/quitepaper/assets/fonts/Kalpurush-Bengali.ttf) via `python3 -m fontTools.subset` from `Kalpurush-Regular.ttf`, keeping only `U+0980–U+09FF` (full Bengali block incl. digits ০–৯ and Taka ৳), `U+200C/U+200D` (ZWNJ/ZWJ for conjunct control), `U+0964–U+0965` (danda), `U+25CC` (dotted circle), with `--layout-features='*'` so `GSUB`/`GPOS`/`GDEF` and all conjunct/reph/kar shaping are preserved (465 glyphs, Latin dropped).
- [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml) now registers family `Kalpurush` → the Bengali-only subset. Because the subset has **no** Latin glyphs, Latin/digits/space always fall through to the chosen or system font, while Bengali resolves to Kalpurush — in both the explicit-font and default-font cases. The original `Kalpurush-Regular.ttf` is kept in the repo as the un-subsetted source (not referenced in `pubspec`, so not bundled).
- No `FontFamilyHelper` logic change was needed — the fallback contract is unchanged; only the asset's glyph coverage was narrowed. Added a regression assertion to [`test/utils/font_family_helper_test.dart`](file:///home/dog/git/quitepaper/test/utils/font_family_helper_test.dart) that Kalpurush is only ever a fallback, never the primary family.

### Verification & Quality
- `flutter analyze` — **No issues found!**
- Full Test Suite: `flutter test` (**all 1816 tests passing**).

## 178. PDF Annotation Tools — non-destructive encrypted vector markup for the document viewer (October 2026)

Implements the approved spec [`docs/specs/pdf-annotation-tools-spec.md`](file:///home/dog/git/quitepaper/docs/specs/pdf-annotation-tools-spec.md) §4–§9. Readers of imported/scanned PDFs can mark up pages with freehand ink, highlighter, shapes, text-anchored marks (highlight/underline/strikethrough/squiggly), comments, and redaction. Marks are a **non-destructive, client-side-encrypted vector sidecar** painted as a `CustomPaint` overlay on the existing raster — the original PDF bytes are never mutated — and are **flattened into pixels only on export/share/print**. Feature G (§10, embedded text-layer extraction) remains a separate, deferred workstream.

### 1. Data model, storage & crypto (§4)
- [`lib/core/documents/annotations/annotation_models.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_models.dart) — `Annotation` (id/documentId/pageIndex/type/geometry/style/text/createdAtMs/updatedAtMs/deleted/z), `AnnotationType` (12 types), `AnnotationStyle` (colorArgb, strokeWidth normalized to page width, opacity, filled), `AnnotationGeometry` (normalized `List<Offset>` points, `List<NormalizedRect>` rects, comment anchor — all 0–1, reusing OCR's `NormalizedRect`), plus the top-level `mergeAnnotations(local, remote)` union-by-id + LWW merge helper (§9).
- [`annotation_crypto.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_crypto.dart) — clones `OcrCrypto` (XChaCha20-Poly1305 AEAD under the Master Key); magic `QPAN`, AAD `quietpaper:document-annotation:$documentId:p$pageIndex:v1`.
- [`annotation_service.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_service.dart) — `DocumentAnnotationService`: `loadPage`/`savePage` (encrypt→base64→DAO upsert), `loadAllPages`/`loadPageCounts`/`hasAnnotations`/`deleteDocument`. Degrades gracefully when locked. Providers in [`annotation_provider.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_provider.dart).
- **New Drift table** [`document_annotations_table.dart`](file:///home/dog/git/quitepaper/lib/core/database/tables/document_annotations_table.dart) (composite PK `{documentId, pageNumber}`, `encryptedPayload` base64, `annotationCount`, `revision`, `isDirty`, `updatedAt`), mirroring `document_ocr_pages`. **Schema bumped 15 → 16** with `_createTableSafely` migration + two `beforeOpen` indexes in [`app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart); regenerated via `dart run build_runner build`. DAO: `saveDocumentAnnotationPage` / `getDocumentAnnotationPage(s)` / `getDirtyDocumentAnnotations` / `markDocumentAnnotationsSynced` / `deleteDocumentAnnotations` / `getAllDocumentAnnotations`.

### 2. Overlay, gestures, tools (§4.3–§4.5, §5, §6)
- [`annotation_editing_controller.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_editing_controller.dart) — session state: active tool/color/width/fill/ruler, per-page lists (tombstones kept so deletes persist & sync), **undo/redo** (per-page snapshots), **debounced encrypted autosave** (no save button).
- [`annotation_overlay.dart`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/annotation_overlay.dart) — `CustomPaint` + `Listener`, laid out at the raster's intrinsic aspect ratio (via `AspectRatio` + `BoxFit.fill`) so **there is no letterbox** and a local gesture position maps to page-normalized coords by a plain divide (spec §4.3's main gotcha). Lives inside `InteractiveViewer` so marks pan/zoom with the page. Renders every type (ink, highlighter w/ multiply blend, rect/ellipse, line/arrow w/ arrowhead, text spans, underline/strike/squiggly, redaction opaque, comment pins). Stroke-level eraser, ruler 0/45/90° snap.
- **Gesture arbitration:** the viewer sets `InteractiveViewer.panEnabled = false` while a markup tool is active, so a one-finger drag can never be stolen for panning; two fingers still pinch-zoom (an in-progress stroke is cancelled when a 2nd pointer lands). The floating [`annotation_toolbar.dart`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/annotation_toolbar.dart) toggles back to Navigate for free pan/zoom. Text tools are disabled with a quiet "preparing text…" hint until `ocrState == available`.
- **Text-anchored resolution** [`annotation_text_selection.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_text_selection.dart): collects `OcrWord` centers inside the drag, groups by `OcrLine` (one rect per line), falls back to line-level snapping when word boxes are missing/zero-size; also powers tap-to-word and select→copy.

### 3. Redaction + export/flatten (§7–§8)
- In-app a `redaction` is an opaque box; the underlying content still exists in the stored (encrypted) PDF — permanence is produced only on export (maintainer-accepted, spec §7).
- [`annotation_flattener.dart`](file:///home/dog/git/quitepaper/lib/core/documents/annotations/annotation_flattener.dart): rasterizes each page at export DPI (`DefaultPdfPageRenderer`, main isolate — `Printing.raster` can't run in `compute`), composites annotations in `z` order (pixel work offloadable to `compute`), **burns redactions as fully opaque black** and (raster-only output ⇒ no recoverable text under the mark), re-wraps page images into a new PDF via the repo's `DefaultPdfGenerator`. Wired into the viewer's `_savePdfToStorage`/`_sharePdf`/`_printPdf`: a document with annotations exports flattened bytes, one with none exports the raw bytes unchanged. **The stored document is never overwritten.**

### 4. Crypto-blind sync & merge (§9) — client + backend
Unlike OCR pages (local-only), annotations **sync** on a new path modeled on tags. Client: `DocumentAnnotationSyncPayload` + pull models in [`sync_models.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_models.dart); `pushDocumentAnnotations`/`pullDocumentAnnotations` in [`sync_api_client.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_api_client.dart); push (dirty-flag) + pull blocks in [`sync_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart) with `sync_metadata` cursor key `annotation_sync_cursor`. Merge is client-side **union-by-id + LWW on `updatedAtMs`** (tombstones follow LWW) via `mergeAnnotations`; the server only stores/returns ciphertext blobs by revision. **Backend (in-repo at `/backend`)**: new migration `backend/migrations/013_document_annotations_schema.sql` (per-user `document_annotations`, revision + cursor), `pushDocumentAnnotations`/`pullDocumentAnnotations` in `backend/src/sync/syncService.ts`, routes `POST /api/v1/sync/document-annotations/push` and `GET|POST …/pull` in `backend/src/api/handler.ts`, Zod schemas in `backend/src/validation/schemas.ts`, and `backend/tests/document_annotations_sync.test.ts`.

### 5. Verification & Quality
- `dart run build_runner build` — regenerated Drift code OK.
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1843 tests passing** (incl. new `test/documents/annotation_models_test.dart`, `annotation_text_selection_test.dart`, `annotation_flattener_test.dart`; journal schema-version assertion updated 15 → 16).
- Backend: `npx tsc --noEmit` clean; `npx vitest run` — **17 files, 116 tests passing** (incl. the 4 new annotation-sync tests).
- **Not yet done:** on-device visual QA (gesture feel, zoom crispness §4.6, flatten fidelity) — this environment is headless, so the overlay/export were verified by analysis + unit/logic tests only, not by running the app. Zoom-in high-DPI re-raster (§4.6) and the annotation index panel (§11) remain deferred polish.

## 179. Open-with / Share-to-Note — import PDF, text & Markdown files from other apps (October 2026)

Android users can now pick **Quiet Paper** from the system "Open with" chooser (ACTION_VIEW) or the share sheet (ACTION_SEND) for PDF, `.txt` and `.md`/`.markdown` files. Each shared file is saved into a **brand-new note** and the most relevant screen opens automatically.

### 1. Behaviour
- **PDF** → imported as an encrypted Quiet Paper document (`DocumentService.importPdfFile`) embedded in a new note via its `qp://document/<id>` markdown link, then the [`DocumentViewerScreen`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/document_viewer_screen.dart) opens automatically.
- **`.md` / `.markdown`** → always imported as the note **body** (never an attachment); front-matter title/tags/dates are honoured via `MarkdownFrontmatterParser`, and the note opens in the editor in Markdown preview mode.
- **`.txt` (and other `text/*`)** → prompts the user with a dialog (**As note** / **As attachment** / Cancel). "As note" pastes the file content into the note body; "As attachment" keeps the file as an attachment only (`AttachmentService.importGenericFileFromFile`). Either way a new note is created and opened in the editor.

### 2. Implementation
- New [`lib/core/sharing/shared_file_importer.dart`](file:///home/dog/git/quitepaper/lib/core/sharing/shared_file_importer.dart): `SharedFileImporter.importFile({path, mimeType, navigatorKey})` classifies by extension + MIME (`_IncomingKind`), creates the note through `notesRepositoryProvider.saveNote` + `notesCollectionProvider.notifier.refresh()`, and pushes the viewer/editor on `rootNavigatorKey.currentState`. Providers are read through `ProviderScope.containerOf(navigatorKey.currentContext)` so the handler stays context-free. Errors surface as a SnackBar and are never rethrown.
- Extended [`share_intent_handler.dart`](file:///home/dog/git/quitepaper/lib/core/web_clipper/share_intent_handler.dart): `_handleSharedFiles` now routes a real on-disk `SharedMediaFile.path` to `SharedFileImporter`, while non-file text (a URL) still opens the web clipper (`WebClipDialog`) — existing web-clip behaviour is unchanged. Reuses the already-wired `receive_sharing_intent` stream (1.9.0 handles ACTION_VIEW + ACTION_SEND).
- [`AndroidManifest.xml`](file:///home/dog/git/quitepaper/android/app/src/main/AndroidManifest.xml): added ACTION_VIEW filters (`content`/`file` scheme) for `application/pdf` and for `text/plain` + `text/markdown` + `text/x-markdown`, plus an ACTION_SEND filter for `application/pdf` + markdown (the pre-existing `text/plain` SEND filter for the web clipper is retained).

### 3. Verification & Notes
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1843 tests passing** (unchanged count; no behavioural regressions).
- **Not verified on-device** (headless env): the actual Android chooser registration and intent delivery were implemented per the plugin's documented contract but not exercised on a device.
- **Known limitation:** `.md` files delivered via `content://` with a generic MIME (`text/plain`) and no `.md` in the resolved path fall into the text branch (prompt) rather than auto-note. File-manager `file://` opens and proper `text/markdown` typing classify correctly.
- iOS share-extension wiring is **not** included (Android-only request).

## 180. Journal Location — pick a place via the sheet (search, known, current) instead of auto-fetching (October 2026)

Adding a location to a journal entry no longer silently captures the current GPS fix. Tapping **Add Location** (and the ↻/change button on an existing one) now opens the shared `PlacePickerSheet` so the place is always a deliberate choice. The sheet gained a **type-or-search** field backed by the device-native geocoder (no external API, no location permission needed — just network).

### 1. Behaviour
- **Editor** ([`frontmatter_properties_section.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/frontmatter_properties_section.dart)): the empty-state location affordance is now **"Add Location"** (`Icons.add_rounded`) and opens `PlacePickerSheet`; when a location already exists, the former "re-fetch" button is now a **"Change location"** button (`Icons.edit_location_alt_outlined`) that re-opens the same sheet. The old auto-fetch-on-tap (`_fetchLocation` / `_isFetchingLocation`) and its inline spinner were removed. `_fetchWeather` still fetches current location directly when needed — unchanged.
- **Sheet** ([`place_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_picker_sheet.dart)): the old "TYPE A PLACE" field + Save button is replaced by one **"TYPE OR SEARCH A PLACE"** field. As you type (500 ms debounce) it lists matching places from the native geocoder; below the results a **Use "<text>" as typed** row (keyed `placePickerUseAsTyped`) always lets you store the raw text verbatim (coordinate-less, the old Save behaviour). "Use current location" and "KNOWN PLACES" sections are unchanged. Reused everywhere the sheet already was (the §6.5 backfill nudge).
- Picking a **search result** resolves its coordinates via the native geocoder (one extra call) so Open-in-Maps and weather work; falls back to the address alone if resolution fails. Typed-verbatim and known-place picks remain coordinate-less (lat/lng = 0), as before.

### 2. Implementation
- [`location_service.dart`](file:///home/dog/git/quitepaper/lib/core/location/location_service.dart): added `searchPlaces(query)` → `List<JournalLocation>` via `Geocoding().placemarkFromAddress` (Android `Geocoder.getFromLocationName`, up to 5 results, de-duped, formatted by `_formatPlacemark`), and `geocodeCoordinates(address)` → `JournalLocation` via `Geocoding().locationFromAddress` for on-pick coordinate resolution. Both catch all errors and degrade gracefully (empty list / coordinate-less), so desktop/no-network never throws.
- Sheet state: `Timer` debounce, `_isSearching`/`_isResolving`/`_results`/`_resultsQuery`, stale-response guard (drops results whose query the user has moved past), `dispose` cancels the timer. Uses `LocationService()` directly, matching the existing current-location path in the same file.

### 3. Verification & Notes
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1843 tests passing** (updated `frontmatter_properties_section_test` for the new "Add Location" label + change icon; updated `backfill_place_nudge_test` to tap the keyed "use as typed" row instead of "Save").
- **Not verified on-device** (headless env): native forward-geocoding results depend on Google Play Services / platform geocoder availability and network; the pure-Dart logic and fallbacks are covered, the actual geocoder round-trip is not.

## 181. Tag icon & color now sync across devices (fix long-standing loss) (October 2026)

A tag's **icon and color never propagated to other devices** since tag-entity sync was introduced (commit `690b6fb`). Tag *names* appeared to sync, so the bug looked icon/color-specific — but names actually arrive for free through note Markdown, which masked the real failure.

### 1. Root cause
Tags are born from `#hashtags` in note Markdown. When a note is saved — including every note **pulled from sync** (`sync_engine.dart:581` → `AppDatabase.saveNote` → `_syncNoteTags`, [`app_database.dart:2038-2051`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart)) — any tag name not already present is created locally with a **fresh random `uuid.v4()` and `isDirty = true`**. So each device mints its **own** tag id for the same name; devices never share an id for organically-created tags.

The tag-entity sync (which is the *only* carrier of icon/color — they travel encrypted inside the tag ciphertext) is keyed by id. Because ids diverge per device, each device also pushes its own **icon-less duplicate** row of the same name. On pull, `upsertSyncedTag` reconciled these by name — but its name-collision branch (and the plain same-id update) wrote the **incoming** icon/color verbatim ([`app_database.dart` ~:1961](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart)), so an icon-less duplicate arriving at a higher revision **erased** the icon/color that another device had set. Tag **names** were unaffected because they are rebuilt identically from note Markdown on every device — which is exactly why the symptom read as "names sync, icon/color don't."

The client crypto, push/pull wiring, serialization (`sync_models.dart`), and the backend (`syncService.ts` `pushTags`/`pullTags`, crypto-blind) are all correct and were left unchanged.

### 2. Fix
`upsertSyncedTag` ([`app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart)) now never lets a sync write **blank out** an icon/color it already holds for a tag. Before the final `insertOnConflictUpdate`, it falls back to the existing local value when the incoming change omits one:

```dart
final priorForTag = existingById ?? existingByName;
final effectiveIcon  = icon  ?? priorForTag?.icon;
final effectiveColor = color ?? priorForTag?.color;
```

This makes icon/color **sticky** across the per-device duplicate churn: the row that has the accent wins over icon-less duplicates regardless of pull order, so a chosen icon/color converges on every device. Note the wire format cannot distinguish "unset" from "cleared" (`TagPlaintext.toJson` drops null fields), so clearing an icon via sync is intentionally not supported — preserving is the safe, non-destructive choice. Edit is localized to the tag path only.

- **No schema change** (no codegen needed).
- **No backend change** — the server already round-trips tag ciphertext intact. **No redeploy required** for this fix.

### 3. Verification & Notes
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1846 tests passing**. Added 3 tests to [`test/sync/tag_sync_test.dart`](file:///home/dog/git/quitepaper/test/sync/tag_sync_test.dart): a regression test proving an icon-less same-name duplicate pulled later no longer wipes a synced icon/color (fails before the fix, passes after), a same-id guard test, and a test documenting that Markdown-born tags get independent ids per device.
- **Not verified on real multi-device hardware** (headless env): the defect and fix are reproduced at the `upsertSyncedTag` merge layer, which is where icon/color were lost; a full two-device round-trip over the live backend was not exercised.

## 182. Journal Places merge/alias map now syncs as an encrypted, crypto-blind collection (October 2026)

The journal Places **merge / rename / unmerge** map (§2.3, the "place alias map") was device-local in SharedPreferences and explicitly deferred. It is now a **synced vault record**: each alias is its own encrypted row that rides a push/pull path cloned from the TAG collection, with a deterministic crypto-blind row id. It remains a presentation-layer mapping only — it **never** mutates note frontmatter and is fully reversible.

### 1. Model — a per-alias collection (not a blob)
Each `matchKey → {canonicalKey, displayName}` mapping is one row in a new `place_aliases` collection (local Drift table + server table), modeled on `tags`.

### 2. Crypto-blind row id (the key design)
The server must never see place names, so the row id is **deterministic, opaque and server-unguessable**:

```
id = HMAC-SHA256(masterKey, "placealias:" + normalizedMatchKey)   // lowercase hex, 64 chars
```

- **Deterministic** ⇒ every device derives the SAME id for the same alias, so pulls reconcile by id (same-id upsert). This deliberately avoids the per-device duplicate-id churn that caused the tag icon/color loss (§181) — there is no name-collision dance here.
- **Keyed** ⇒ the server cannot dictionary-attack low-entropy place names from the id.

The payload `{matchKey, canonicalKey, displayName}` is sealed inside the ciphertext (XChaCha20-Poly1305, raw master key, AAD `quietpaper:placealias:<id>:v1`). New crypto surface in [`crypto_service.dart`](file:///home/dog/git/quitepaper/lib/core/crypto/crypto_service.dart): `PlaceAliasPlaintext`, `computePlaceAliasId`, `encryptPlaceAliasPayload`, `decryptPlaceAliasPayload`. Only opaque metadata is plaintext on the server (id, user_id, revision, timestamps, isDeleted/deletedAt, content/key versions, device ids).

Notably, the **local** `place_aliases` table stores only ciphertext (unlike `tags`, which keeps plaintext name locally) — the store decrypts lazily on load with the master key.

### 3. Store behavior (unchanged public contract)
[`place_alias_store.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/place_alias_store.dart): `placeAliasStoreProvider` still exposes `Map<String, PlaceAlias>` and the same four methods (`merge`/`rename`/`unmerge`/`unmergeCanonical`), so `PlaceGroupingService`, `placeListProvider` and the Places UI are untouched. Internally:
- When the vault is **unlocked**, a `PlaceAliasRepository` persists write-through to the DB (rows marked dirty), a live Drift `watch` keeps the map convergent with remote pulls, and each mutation requests `SyncEngine.triggerSyncDebounced()` so merges propagate promptly.
- `unmerge`/`unmergeCanonical` write **tombstones** (`isDeleted = true`) for synced rows so deletions propagate (a never-synced row is just dropped).
- **One-time migration:** on first unlocked run, any legacy SharedPreferences `journal_place_aliases` entries are imported into the DB (marked dirty, so they sync), guarded by a `place_alias_migrated` metadata flag. The old prefs copy is then ignored.
- When the vault is **locked / DB unavailable**, it gracefully falls back to the legacy device-local SharedPreferences store (no data loss).
- **Unlock activation:** the synced path is gated on `isKeyManagerUnlockedProvider`. For returning users the master key is restored at startup, so it reads unlocked when Places first builds. For a mid-session sign-in/unlock, that flag is now set explicitly on success in [`sync_auth_dialog.dart`](file:///home/dog/git/quitepaper/lib/features/sync/presentation/sync_auth_dialog.dart) and [`sync_auth_screen.dart`](file:///home/dog/git/quitepaper/lib/features/sync/presentation/sync_auth_screen.dart), so the store rebuilds onto the synced path without an app restart.

### 4. Sync wiring
- Table [`place_aliases_table.dart`](file:///home/dog/git/quitepaper/lib/core/database/tables/place_aliases_table.dart) + `app_database.dart` (`schemaVersion` 16 → **17**, `onUpgrade from < 17`, `getDirtyPlaceAliases`/`putLocalPlaceAlias`/`tombstoneLocalPlaceAlias`/`markPlaceAliasSynced`/`upsertSyncedPlaceAlias`/`getAllPlaceAliases`; added to `resetSyncCursors`, `eraseAllLocalVaultData`, unsynced count).
- `sync_models.dart` (`PlaceAliasSyncPayload`/`PullPlaceAliasChangeItem`/`PullPlaceAliasSyncResponse`), `sync_api_client.dart` (`pushPlaceAliases`/`pullPlaceAliases`), `sync_engine.dart` (PUSH phase 2b-ii, PULL phase 4c-ii, new `place_alias_sync_cursor`). `upsertSyncedPlaceAlias` is convergent and keeps a newer local dirty edit over a reordered older remote change.
- Backup: [`backup_models.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_models.dart) `BackupPlaceAlias` (stored **verbatim as ciphertext** + `totalPlaceAliases` manifest count) and [`backup_service.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart) export/restore (+ `RestoreStrategy.replace` wipe clears the table).

### 5. Backend — redeploy required
A backend redeploy is **required** for cross-device sync to work. Changes (user deploys; this agent cannot):
- `backend/src/db/migrate.ts` `INITIAL_SCHEMA_SQL`: `CREATE TABLE place_aliases` (mirrors `tags`, no pinned columns) + `idx_place_aliases_user_id` / `idx_place_aliases_user_rev`. **This is the runtime schema** — the `backend/migrations/*.sql` files are not executed at runtime; `backend/migrations/014_place_aliases_schema.sql` is a reference copy only.
- `backend/src/validation/schemas.ts`: `placeAliasSyncPayloadSchema` (id is an **opaque string**, NOT `.uuid()`) / `pushPlaceAliasesSchema` / `pullPlaceAliasesSchema`.
- `backend/src/sync/syncService.ts`: `pushPlaceAliases` / `pullPlaceAliases` (MAX(revision)+1, +1 hasMore trick, blind `ON CONFLICT(id)` upsert).
- `backend/src/api/handler.ts`: `POST /api/v1/sync/place-aliases/push` and `GET|POST /api/v1/sync/place-aliases/pull` behind the same auth middleware.

Until the backend is redeployed the push/pull calls fail soft (caught, rows stay dirty, retry next cycle); the Places feature keeps working locally.

### 6. Verification
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1858 passing**. New [`test/journal/place_alias_sync_test.dart`](file:///home/dog/git/quitepaper/test/journal/place_alias_sync_test.dart) covers encrypt/decrypt round-trip + zero-knowledge, deterministic/keyed id stability, DB dirty/tombstone/convergence, two-device engine push/pull convergence + tombstone propagation, store write-through, and the SharedPreferences→DB migration. Existing place tests (`place_alias_store_test.dart`, `places_providers_test.dart`, `places_merge_ui_test.dart`) stay green (locked path = legacy prefs). `journal_database_test.dart` schema assertion bumped to 17.
- Backend: `npx tsc --noEmit` clean; `npm test` **all passing** incl. new `backend/tests/place_aliases_sync.test.ts` (push/pull pagination, per-user isolation, tombstone propagation — using opaque hex ids).
- **Not verified on real multi-device hardware** (headless env) and the backend was not deployed/exercised live; convergence is proven at the engine + in-memory-API layer.

## 183. Pinning — per-tag ("local") pins vs. global pins, aggregated Pinned view, refreshed icon (October 2026)

### Summary / behavior
Pinning gained a scope. Previously a note had a single global `isPinned` boolean that floated it to the top of every list. Now:
- **Pin inside a tag view** → the note is pinned *only within that tag* (a "local" pin). It floats to the top of that tag's list and shows in the Pinned view, but does **not** clutter All Notes or other tags.
- **Pin from All Notes** (no tag selected) → a **global** pin, as before: the note floats to the top of All Notes, the Pinned view, and **inside every tag it belongs to** ("always within reach"). This is the locked design decision (user chose *"Global = everywhere"* over fully-independent scopes).
- The sidebar **Pinned** smart view now **aggregates** every pinned note — global pins *and* per-tag pins — and its count badge matches.
- Inside a tag view the Pin action governs *that tag's* pin (labels: "Pin to tag" / "Unpin from tag"); a globally-pinned note still reads as pinned there and is unpinned from All Notes.
- **Refreshed pin icon:** all note pin glyphs unified on the Phosphor `pushPin` (`PhosphorIconsFill.pushPin` active / `PhosphorIconsRegular.pushPin` idle), replacing the Material `Icons.push_pin_*` in note tiles, the editor quick-action bar, and the search "PINNED TAGS" header (the sidebar already used Phosphor).

### Data model
Per-tag pins live **inside the encrypted note content**, so the sync server never learns which tags a note is pinned in (zero-knowledge preserved; **no backend change required**). Global pins keep riding as the existing plaintext `pinned` metadata flag.
- [`notes_table.dart`](file:///home/dog/git/quitepaper/lib/core/database/tables/notes_table.dart): new `pinnedTags` (`TEXT`, nullable) — JSON array of normalized tag names the note is pinned within. Authoritative local store.
- [`note_tags_table.dart`](file:///home/dog/git/quitepaper/lib/core/database/tables/note_tags_table.dart): new `isPinned` (`BOOL`, default false) — a denormalized cache rebuilt from `notes.pinnedTags` on every save, so per-tag pins filter/order via an indexable join instead of parsing JSON. New index `note_tags_pinned_idx (note_id, is_pinned)`.
- `app_database.dart` `schemaVersion` **17 → 18**, `onUpgrade from < 18` adds both columns via `_addColumnSafely` (additive, idempotent; existing global pins untouched, no backfill needed).
- [`note_model.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_model.dart): `Note.pinnedTags`, `isPinnedInTag(tag)`, `isPinnedInContext(tagName)` (global OR tag pin), top-level `decodePinnedTagsJson(raw)`.
- [`crypto_service.dart`](file:///home/dog/git/quitepaper/lib/core/crypto/crypto_service.dart): `NotePlaintext.pinnedTags` (serialized only when non-empty; `fromJson` tolerates its absence for forward/backward compatibility).

### DAO (`app_database.dart`)
- `saveNote(... List<String>? pinnedTags)`: resolves the note's current tag set first, then computes the effective pinned set = (explicit `pinnedTags` from sync, else the existing row's set preserved for local edits) **∩ current tags**, writes `notes.pinnedTags`, and passes it to `_syncNoteTags`. Pruning a tag out of the content drops its pin automatically.
- `_syncNoteTags(noteId, tagNames, {pinnedNames})`: sets `note_tags.is_pinned` per rebuilt join row.
- `setPinned(id, bool)` unchanged = **global** pin.
- **`setPinnedInTag(id, tagName, bool)`** (new): toggles one tag's pin — updates `notes.pinnedTags` + the `note_tags` cache row, marks the note dirty. Exposed via `NotesRepository.setPinnedInTag`.
- `watchPinnedNotesCount()` now counts `isPinned OR EXISTS(note_tags.is_pinned)` so the sidebar badge matches the aggregated view.

### Query / ordering (`notes_query_executor.dart`)
- `_pinnedContextTag(query)` = the single tag an active list is scoped to (else null). `_pinnedInContextExpr(tag)` = `notes.is_pinned OR EXISTS(note_tags⋈tags pinned for that tag)`.
- The "pinned-first" ordering term and the keyset-cursor pinned partition now use `_pinnedInContextExpr` instead of the raw `is_pinned` column, so per-tag pins float correctly inside a tag view while keyset pagination stays consistent. `NotesCursor.fromNote(note, sort, {contextTag})` stores the context-scoped pinned value.
- The `pinnedOnly` predicate (the Pinned smart view) is now `is_pinned OR EXISTS(note_tags.is_pinned)`.
- Grouping ([`note_group.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_group.dart) `groupByDate({contextTag})`): the leading "Pinned" group is shown in All Notes (global pins) **and** inside a single tag view (that tag's pins + global), driven in [`notes_query_provider.dart`](file:///home/dog/git/quitepaper/lib/features/notes/application/notes_query_provider.dart) `groupedNotesCollectionProvider`.

### UI
- [`notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart): `onTogglePin` is context-aware — in a tag view it calls `setPinnedInTag(note, tag, !note.isPinnedInTag(tag))`, otherwise `setPinned` (global). Passes `pinContextTag` to the tile.
- [`note_list_tile.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_list_tile.dart): new `pinContextTag`; `isPinnedHere`/`pinIsTagScoped` drive the inline glyph, the desktop right-click menu, and the bottom-sheet action (Phosphor icon + scope-aware labels). The bottom-sheet pin icon logic (previously inverted) is corrected.
- Icon unification also in [`editor_quick_actions_bar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/editor_quick_actions_bar.dart) and [`search_screen.dart`](file:///home/dog/git/quitepaper/lib/features/search/presentation/search_screen.dart).

### Sync (`sync_engine.dart`, `conflict_resolver.dart`)
- PUSH builds `NotePlaintext(pinnedTags: decodePinnedTagsJson(note.pinnedTags))`; PULL calls `saveNote(pinnedTags: decrypted.pinnedTags)`. Because pins live in the ciphertext, `NoteSyncPayload`/`PullChangeItem` are unchanged and the server stays blind.
- 3-way merge: `merge3Way` carries a merged `pinnedTags` (union of both branches ∩ merged tags); the three local `NotePlaintext` builders include local pins. Conflict-resolver `saveNote` calls omit `pinnedTags` → the DAO preserves the existing per-tag pins (pruned to current tags), so pins are not lost on conflict resolution.
- **No backend changes and no redeploy required** (unlike §182).

### Verification
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1865 passing**. New [`test/notes/note_pin_scope_test.dart`](file:///home/dog/git/quitepaper/test/notes/note_pin_scope_test.dart) covers per-tag pin storage, survival across content edits, pruning when a tag is removed, tag-view vs All-Notes floating, global-pin-everywhere, and Pinned-view aggregation. Icon/schema assertions updated in `editor_overflow_menu_test.dart`, `notes_list_redesign_test.dart`, and `journal_database_test.dart` (schema → 18).
- Not exercised on real multi-device hardware (headless env); per-tag pin sync is proven at the DB + plaintext round-trip layer.

## 184. Bengali Content Support — selectable Bengali font (CDN) + correct Bengali PDF export (October 2026)

Extends the Bengali content work (§§174–177). Adds a user-choosable **Bengali content font** delivered from the backend CDN (not bundled), and fixes **PDF export** so Bengali renders correctly. Image export and share-as-URL were verified and improved to use the same faces.

### 1. New Bengali faces on the CDN (not packaged in the app)
Four user-supplied Bengali families were extracted from the zips previously dropped in `backend/`, **subset to Bengali-only** (same approach as the §177 Kalpurush subset — keep `U+0980–09FF`, ZWJ/ZWNJ, danda, dotted-circle, all GSUB/GPOS/GDEF; drop Latin so they never shadow the Latin font when used as a fallback), and hosted under [`backend/public/fonts/`](file:///home/dog/git/quitepaper/backend/public/fonts/):
- **Kolpona** (Regular + Italic), **Byomgraphy Koushali** (Regular + Italic), **Purno Pran** (Regular + Italic), **Samsung Bengali** (Regular). License/readme files kept alongside each. The Unicode variant of each source face was used (ANSI legacy encodings discarded). Internal font names were preserved (not renamed) for license compliance.
- [`backend/public/fonts/manifest.json`](file:///home/dog/git/quitepaper/backend/public/fonts/manifest.json): 4 new entries (`"category":"Bengali"`), 14 families total.
- [`font_cache_manager.dart`](file:///home/dog/git/quitepaper/lib/core/fonts/font_cache_manager.dart): 4 `HostedFontEntry`s added to `defaultHostedFonts` (byte sizes match the subset files exactly); `_normalizeFamilyName` gained cases for the multi-word families (`ByomgraphyKoushali`→`Byomgraphy Koushali`, etc.) so a re-scan of cached files on restart maps back to the registered family. Downloaded on demand via the existing `downloadAndRegisterFont` → `FontLoader` path.

### 2. Dedicated "Bengali font" typography setting (fallback model)
The Bengali font governs **only** Bengali runs — Latin text keeps the chosen Latin body/heading font. Implemented as the Bengali fallback chain, now user-driven instead of the hardcoded Kalpurush:
- [`font_family_helper.dart`](file:///home/dog/git/quitepaper/lib/core/utils/font_family_helper.dart): `kContentFontFallback` changed from a `const` to a getter → `[?activeBengaliContentFont, 'Kalpurush']`. `setActiveBengaliContentFont(family)` sets the override (selecting the bundled `Kalpurush` clears it). The bundled Kalpurush subset always trails as the always-offline last resort, so Bengali still renders before/if a CDN face is downloaded. New `bengaliFonts` set; `hostedFonts` now includes them.
- [`typography_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/typography_settings.dart): new nullable `bengaliFontFamily` (field, ctor, `copyWith`+`clearBengaliFont`, `==`/`hashCode`, `toJson`/`fromJson`).
- [`typography_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/typography_provider.dart): `CuratedFonts.bengaliPresets` (`Kalpurush` default + the 4 CDN faces); `setBengaliFontFamily` downloads the face, mirrors it into `setActiveBengaliContentFont`, and persists; `_initBengaliFont` restores it on launch; `resetToDefault` clears it.
- [`font_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/font_picker_sheet.dart): new `FontPickerType.bengali`. Because the faces are Bengali-only, the Latin family name is shown in a neutral UI font and each face is previewed on a **Bengali sample line** ("আমার সোনার বাংলা…"); Google-Fonts/Import/custom-query entries are hidden for this type, and Latin `customFonts` are excluded from the list.
- [`typography_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/typography_settings_screen.dart): "Bengali Font" row in the TYPEFACES group; the live preview sample gained a Bengali line so the chosen face renders immediately.

### 3. PDF export now renders Bengali correctly (rasterized pages)
Root cause: the `pdf` package (3.13.0) does **no complex-script shaping** — `ttf_parser` reads no GSUB and `bidi_utils` is Arabic-only — so Bengali conjuncts/matra reordering mis-render in vector text, and the embedded faces were Latin-only anyway (tofu). Fix ([`pdf_exporter.dart`](file:///home/dog/git/quitepaper/lib/features/export/application/exporters/pdf_exporter.dart)):
- When a note contains Bengali (`U+0980–09FF` in body or title) **and** an `ImageRasterizer` is available, the note is rendered through Flutter's own HarfBuzz engine (the identical path image export uses, honoring the selected Bengali font) into one tall PNG, which is sliced into page-height tiles (via the `image` package) and assembled into an image-based PDF (A4/Letter/… per `pdfOptions.pageSize`, 28pt margins). A `partialContent` warning records that the text is not selectable.
- Latin-only notes keep the existing selectable **vector** path unchanged. If no rasterizer is available (non-UI callers), Bengali notes degrade to the vector path.
- Wiring: `export_note_sheet.dart` now builds the context-bound rasterizer for `pdf` as well as `image`; `export_service.dart` forwards `imageRasterizer` to the PDF exporter. **Decision (locked with the user): rasterize only Bengali-containing notes** — Latin PDFs stay vector/selectable.

### 4. Image export & share-as-URL
- **Image export** already renders through Flutter (correct Bengali) and automatically picks up the selected Bengali font via the content fallback — no structural change needed.
- **Share-as-URL** ([`backend/src/share/shareViews.ts`](file:///home/dog/git/quitepaper/backend/src/share/shareViews.ts)): added a hosted `Kolpona` `@font-face` and appended it to the serif/sans/mono CSS chains so shared Bengali notes render in a hosted face instead of the browser default. **Requires a backend rebuild/redeploy** to take effect (TS → `dist/`).

### 5. Verification & Quality
- `flutter analyze` — **No issues found!**
- `flutter test` — **all 1874 passing**. New [`test/features/export/pdf_bengali_export_test.dart`](file:///home/dog/git/quitepaper/test/features/export/pdf_bengali_export_test.dart) (Bengali→rasterized+warning, Latin→vector, Bengali-without-rasterizer→vector fallback); extended `font_family_helper_test.dart` (active Bengali font leads the chain, Kalpurush clears/ trails, faces are hosted), `typography_settings_test.dart` (bengaliFontFamily round-trip/copyWith, bengaliPresets, Kalpurush-clears), and the `font_cache_manager_test.dart` family-count/category assertion (10→14).
- Not exercised on real hardware (headless env): on-device CDN download of a Bengali face and the rasterized Bengali PDF are proven at the unit/service layer (stub rasterizer) but not in a live app session.
- Note: a 5th archive `backend/Shadhinata.zip` (not among the four at task start) was left untouched — out of scope.

## 185. Link Enhancements — Bear-style web links (opt-in titles, ⌘K edit, smart clipboard, paste-to-link) (October 2026)

Implements `docs/specs/link-enhancements-spec.md` (Features 1–5) across **Visual (WYSIWYG)** and **Super Editor**; raw-Markdown source mode is out of scope. Built by fanning out foundation + interaction agents against frozen contracts. A single **"Smart web links"** switch (default **OFF**) gates the only network behaviour (auto-title fetch) and is shared with preview cards (§186).

### 1. Shared foundations
- `lib/core/utils/web_url_helper.dart`: `isSingleWebUrl` / `normalizeWebUrl` behind one canonical anchored matcher `^https?://\S+$` (the pre-existing URL regexes were unanchored and unshared). Used by F1/F3/F4 so every path agrees on "a URL".
- `lib/core/web_clipper/link_title_fetcher.dart`: thin `LinkTitleFetcher` over `ArticleExtractor`, injectable `http.Client`, 5 s timeout, returns null on any failure / non-HTML / missing title; never logs the URL.
- `settings_provider.dart` `smartWebLinksProvider` (SharedPreferences key `app_smart_web_links`, default false, mirrors the nullable-prefs `EditingStyleNotifier`); `settings_screen.dart` adds the switch row (EDITOR section) with a network-request caption.

### 2. Features
- **F1 Auto-filled titles on paste (opt-in).** Collapsed caret + lone-URL paste (toggle ON) inserts `[url](url)` immediately, then an async fetch patches only the display text in place, matched by `href==url && display still==url` so a user edit/move cancels the patch. Never blocks the paste. Toggle OFF = raw paste as before.
- **F2 Edit Link + ⌘K.** ⌘/Ctrl+K was already bound to the link prompt, so the handler was extended to detect a link under the caret/selection and open the dialog in edit mode, applying in place.
- **F3 Smart clipboard.** Dialog peeks the clipboard on open; a lone URL pre-fills the URL field and focuses Title. Local only.
- **F4 Paste-onto-selection → titled link.** Non-empty selection + lone-URL paste wraps the selection as the display text (no toggle gate, no network) on both paste paths; falls back to plain paste across block boundaries / existing links.
- **F5 Revert/edit.** Clearing the URL removes the link attrs but keeps the characters; clearing the title falls the display back to the URL; a "Remove link" button in edit mode.

### 3. Engine / controller API added
- `rich_document_mutations.dart`: `linkRunAt`, `replaceLinkDisplayText`, `editLinkRun` (existing `applyLink`/`removeLink` left unchanged).
- `rich_document_controller.dart`: `isLinkActive`, `selectionHasLink`, `linkAtCaret`, `editLinkAtCaret`, `replaceLinkDisplayText`.
- `quiet_super_editor_controller.dart`: `insertLinkRun` (real `LinkAttribution` run instead of literal `[text](url)`), `linkAtSelection`, `replaceLinkContent`, `removeLinkInRange`, `replaceLinkDisplayText`, `hasExpandedSelection`.
- `link_prompt_dialog.dart`: `isEditing` mode (relabel/prefill/Remove-link/empty-URL submit). Return shape kept as `({String title, String url})`; an empty `url` signals removal, keeping existing insert-path callers and `markdown_selection_toolbar_test` source-compatible.
- Design note: the Bear "title" is the span **display text**, not the Markdown `"title"` tooltip (`linkTitle`), so collapsed inserts carry the title as display text and `linkTitle` serialization is untouched.

## 186. Link Previews — "Wake up, Link!" baked preview cards (October 2026)

Implements `docs/specs/link-previews-spec.md` (companion to §185). A web URL **alone on its own line** auto-promotes to a rich card (title / description / site + a synced encrypted thumbnail), **baked into the note** and gated by the same "Smart web links" toggle.

### 1. Data model + on-disk encoding
- `rich_block.dart`: new `LinkPreviewBlock` (`url`, `title`, `description?`, `siteName?`, `thumbnailAssetId?`, `fetchedAt`), type discriminator `link_preview`, atomic (`isTextBlock=false`).
- Canonical Markdown form (survives export round-trip) — the visible link on its own line + an adjacent sentinel comment carrying the extras:
  ```
  [Title](https://example.com/post)
  <!-- qp-link-preview: {"desc":"…","site":"…","img":"qp://asset/<id>","ts":"ISO"} -->
  ```
- `link_preview_metadata.dart`: `encodeLinkPreviewComment` / `decodeLinkPreview` / `isLinkPreviewComment` (sentinel convention mirrors the encrypted-note envelope). The RichDocument parser does a two-line lookahead; orphan sentinels are dropped (never shown as text); a lone link **without** a sentinel stays a plain inline link (not promoted).

### 2. Thumbnail = hidden encrypted synced attachment
- `attachment_service.dart` `importImageFromBytes` gained `kind` / `skipOcr`; the thumbnail imports with `kind:'linkPreview', skipOcr:true` (no OCR enqueue). `saveAttachment` already accepted `kind` — no schema migration (free-form column).
- `app_database.dart`: `getAttachmentsForNote` / `watchAttachmentsForNote` exclude `kind=='linkPreview'`, keeping previews out of the user attachment list and exports. The `qp://asset/<id>` lives **only** inside the sentinel JSON (never a visible `![]()`), so it is also excluded from the content-driven list-tile thumbnail.
- `link_preview_baker.dart`: fetch page HTML (browser UA) → `ArticleExtractor` metadata → fetch OG image → compress to `maxDimension: 800` via `image_processor.dart` (no settings-enum preset is that small) → import encrypted thumbnail → build the block. Returns null on page-fetch failure (never bakes a broken card); image failure → text-only card. Exposes `findUnbakedLoneLineUrls` + `bakeMarkdown`.

### 3. Rendering — three surfaces, toggle-gated
- Shared `LinkPreviewCard`: thumbnail via `resolveAsset` (local-first/offline), tap via `LinkLauncherHelper.handleLinkTap` so the trusted-domain gate is preserved.
- WYSIWYG `RichLinkPreviewBlock` + arm in `rich_editor_surface.dart`; Super Editor atomic `LinkPreviewNode` / promote pass / component / node-serializer in `super_editor/quiet_link_preview_component.dart`, registered in `quiet_super_editor.dart`; read-only `markdown_preview.dart` `BlockSyntax` + element builder.
- **Toggle OFF renders a baked card as a plain link on every surface**, while the block always serializes (data preserved). Promote/BlockSyntax always consume the sentinel so it never shows as raw text. Refresh (WYSIWYG) re-bakes, tombstones the old thumbnail, and replaces the block (id preserved); Remove demotes to an inline link and tombstones the thumbnail.

### 4. Bake on open
- `editor_screen.dart` `_maybeBakeLinkPreviews` (post-frame in `initState` + on note switch in `didUpdateWidget`): toggle ON → scan for unbaked lone-line URLs, bake off the main thread, write back via `updateContent` (→ `isDirty` → debounced save → sync). Snapshot-guarded against concurrent edits; offline/failed → retried on a later open; already-baked `[title](url)` lines are never re-scanned (no loop).

### 5. Verification & quality
- `flutter analyze` — **No issues found!** `flutter test` — **all 1931 passing.** New tests: `web_url_helper`, `link_title_fetcher`, linkPreview round-trip (serialize⇄parse idempotency, missing-optional subsets, orphan drop, lone-link-stays-plain), attachment hiding + `kind`/`skipOcr`, baker (find / bake happy+failure / offline), and the web-link-enhancement mutations/controller. Also updated three pre-existing attachment test doubles for the new `importImageFromBytes` signature.
- Known limitations (not runtime-verified in this headless env): the live card swap-in after bake, the paste UX, and card visuals are proven at the unit/logic layer only, not in a running app session. Raw-Markdown source mode shows the sentinel as a literal comment line (expected for a source view). Super Editor relies on the sentinel surviving Markdown deserialization as its own paragraph; if a chunk boundary or the deserializer splits the link from its sentinel, the card degrades to a plain link (no raw JSON leak).

## 187. Link Enhancements & Previews Bugfixes & Hardening (Sync Schema, Flutter Markdown Grey Box, Redirect Following, Super Editor Promotion) (October 2026)

Fixes production sync failures, preview mode rendering crashes (grey box bug), Super Editor link preview promotion, and link card fetch failures on external websites.

### 1. Attachment Sync Schema Validation & Client Fallback
- **Root Cause**: Backend attachment upload confirmation endpoint (`/api/v1/attachments/confirm`) validated `kind` using `z.enum(['image', 'document', 'file'])`. Link preview thumbnail attachments upload with `kind: 'linkPreview'`, triggering a 400 validation error (`Invalid confirmation payload: Invalid enum value. Expected 'image' | 'document' | 'file', received 'linkPreview'`).
- **Backend Schema & Service**:
  - `backend/src/validation/schemas.ts`: added `'linkPreview'` to `confirmAttachmentSchema`'s `kind` enum.
  - `backend/src/attachments/cloudinaryService.ts`: updated `shareResourceTypeForKind` so `linkPreview` maps to `'image'` resource type on Cloudinary.
  - `backend/tests/attachments.test.ts`: added test confirming `kind: 'linkPreview'` uploads succeed and persist.
- **Client Resilience**:
  - `lib/core/sync/sync_api_client.dart`: added automatic fallback retry with `kind = 'image'` if the backend returns HTTP 400 for `'linkPreview'` (guarantees sync continuity even against older backend deployments).
  - `lib/core/sync/sync_engine.dart`: during note pull, if an asset is referenced inside a `<!-- qp-link-preview:` sentinel comment, `effectiveKind` is set to `'linkPreview'` even if the backend returned `'image'`.

### 2. Flutter Markdown Grey Box Bugfix
- **Root Cause**: In `lib/core/markdown/markdown_preview.dart`, `LinkPreviewBlockSyntax.parse` emitted `md.Element('linkpreview', [md.Text(title)])`. Because `isBlockElement() == true` in `LinkPreviewElementBuilder` and `visitElementAfterWithContext` returns a `LinkPreviewCard` widget without consuming the child inline text span, `flutter_markdown` failed its `assert(_inlines.isEmpty)` assertion during widget building. In Flutter release mode, builder assertion errors trigger Flutter's default `ErrorWidget`, displaying a solid grey box over the note preview.
- **Fix**: Updated `LinkPreviewBlockSyntax.parse` to return `md.Element.empty('linkpreview')`. Without child inlines, `_inlines` remains clean, eliminating the assertion failure. Regression verified in `test/markdown/markdown_preview_test.dart`.

### 3. Super Editor Link Preview Promotion & Serialization
- **Root Cause**: `super_editor`'s `deserializeMarkdownToDocument` parses CommonMark, which strips raw HTML comments (`<!-- ... -->`) and merges consecutive non-blank lines into a single paragraph. Consequently:
  1. The sentinel comment was dropped, preventing `promoteLinkPreviewNodes` from matching the link-comment pair.
  2. Consecutive links were merged into a single paragraph, violating `_soleHttpLinkOf`'s single-link requirement.
- **Fix**:
  - `lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart`: updated `normalizeMarkdownForSuperEditor` to isolate standalone web links with double newlines (`\n\n`) and escape sentinel comments as `\<!-- qp-link-preview: ... -->` so CommonMark retains them as paragraphs.
  - `lib/features/editor/application/link_preview_metadata.dart`: updated `isLinkPreviewComment` and `decodeLinkPreview` to handle escaped `\<!--` comments seamlessly.
  - `lib/features/editor/presentation/widgets/super_editor/quiet_link_preview_component.dart`:
    - Updated `_soleHttpLinkOf` to handle paragraph trimming gracefully.
    - Updated `promoteLinkPreviewNodes` to defensively delete any orphan sentinel comments so raw JSON never leaks.
    - Updated `LinkPreviewNodeSerializer` to guarantee double newlines after the block when followed by another node.
  - `lib/features/editor/application/quiet_super_editor_controller.dart`: updated `pasteSnippet` to detect link preview comments and promote `LinkPreviewNode`s on paste.
  - Added unit test in `test/editor/quiet_super_editor_test.dart` verifying multiple link preview cards promote and round-trip cleanly.

### 4. Link Preview Fetching & Redirect Handling
- **Root Cause**:
  1. `LinkPreviewBaker.findUnbakedLoneLineUrls` and `bakeMarkdown` only searched for bare URLs via `isSingleWebUrl`. Links pasted with Smart Web Links ON were formatted as `[Title](url)` or `[url](url)` by Feature 1, causing them to be ignored by the baker.
  2. `_htmlHeaders` and `_imageHeaders` included `Sec-Fetch-*` headers which trigger 403 Forbidden on WAFs (Cloudflare/Akamai).
  3. `http.Client` does not follow cross-scheme (HTTP -> HTTPS) redirects, throwing `RedirectException` in `dart:io`.
  4. Sites without explicit `<title>`/OG tags fell back to generic `'Web Article'`.
- **Fix**:
  - Updated `findUnbakedLoneLineUrls` and `bakeMarkdown` to recognize standalone `[Title](https?://...)` links that lack sentinel comments in addition to bare URLs.
  - Cleaned request headers, removing `Sec-Fetch-*`.
  - Added `_getWithRedirects` to manually follow 301/302/303/307/308 redirects across schemes.
  - Added domain/host fallback when extracted title is `'Web Article'` or empty.
  - Added unit tests in `test/core/web_clipper/link_preview_baker_test.dart`.

## 188. Navigation Sidebar Sync Status & Action Tile (October 2026)

Replaces the "Clip Webpage" option in the navigation sidebar footer with a rich, interactive **Sync Status & Action Tile** (`SidebarSyncTile`) directly above **Settings**.

### 1. Functional Capabilities
- **Sync Trigger**: Tapping the tile calls `syncEngine.syncNow()` with visual feedback (a rotating Phosphor `arrowsClockwise` icon driven by an `AnimationController` and status SnackBars).
- **Logged-in Status**: Watches `currentUserProvider` and displays the active user's email address (or "Local Vault" / "Tap to set up sync" when signed out).
- **Sync Status & Timestamp**: Real-time status display matching `SyncStatus`:
  - `synced`: Shows "Sync" title with dynamic relative timestamp ("Just now", "5m ago", "2h ago", etc.) via `DateFormatter.formatRelative`.
  - `syncing`: Animating spinning sync icon with "Syncing..." and "Updating changes...".
  - `offline`: "Offline" title with "Saved locally" caption.
  - `syncError`: "Sync Error" title with "Error • Tap to retry" caption.
  - `pendingSync`: "Encryption Locked" with prompt to unlock.
- **Merge Conflict Alerts**: Watches `pendingConflictsCountStreamProvider` and `syncState.conflictsCount`. When unresolved conflicts exist (`conflictsCount > 0`), renders an amber warning banner (`"$count conflict(s) require review"`) that directly navigates to `ConflictListScreen`.
- **Signed-Out Interaction**: Tapping the tile while logged out opens an editorial "Offline Storage" dialog explaining local-first persistence with a direct button to open `SyncAuthScreen`.
- **Theme-Aware Contrast**: Uses custom contrast tuning for dark sidebars (`isSidebarDark`) and light sidebars for all text, icons, and amber warning pills.

### 2. File Changes
- `lib/features/sidebar/presentation/widgets/sidebar_sync_tile.dart`: New stateful consumer widget implementing `SidebarSyncTile`.
- `lib/features/sidebar/presentation/sidebar_view.dart`: Replaced "Clip Webpage" `SidebarItem` with `SidebarSyncTile`.
- `test/sidebar/sidebar_sync_tile_test.dart`: Added comprehensive widget test suite covering signed-out dialog flow, signed-in sync triggering, active syncing animation, conflict warning banner navigation, encryption locked state, and sidebar layout verification.

## 189. Super Editor Inline Formatting Delimiter Normalization & Bold Preservation (October 2026)

Fixes a bug where applying bold (or italic/strikethrough) formatting inside the Super Editor produced literal asterisks or stripped formatting after toggling preview mode on and returning to the editor ("clicking on editor").

### 1. Root Cause Analysis
- **CommonMark Flanking Rules**: In Markdown / CommonMark specifications, an opening emphasis delimiter cannot be followed by whitespace (left-flanking delimiter run rule), and a closing delimiter cannot be preceded by whitespace (right-flanking delimiter run rule).
- **Loose Selection in Super Editor**: When users select words (e.g., via double-click or drag selection) or type spaces before toggling formatting off, the selection often includes leading and/or trailing whitespace (`" world "`). Applying `boldAttribution` across the raw selection formatted the whitespace as bold.
- **Serialization & Deserialization Collapse**:
  - `serializeDocumentToMarkdown` naively wrapped the entire attribution span with delimiters: `Hello **world ** again`.
  - When switching to preview mode and back to editor, `deserializeMarkdownToDocument` parsed `**world **`. Due to the CommonMark flanking rule violation, `**` could not be parsed as emphasis and was parsed as literal plain text.
  - The deserialized `ParagraphNode` contained literal asterisks with an empty attribution span, stripping the bold styling and displaying `**` to the user.

### 2. Implementation: Two-Layer Defense
1. **Layer 1: Selection Whitespace Trimming in Controller (`QuietSuperEditorController`)**:
   - Added `_trimRangeWhitespace(Document doc, DocumentSelection sel)` to `lib/features/editor/application/quiet_super_editor_controller.dart`.
   - When users toggle bold, italic, or strikethrough via toolbar or keyboard shortcuts, outer whitespace is trimmed from the `DocumentRange` before dispatching `ToggleTextAttributionsRequest`.
   - Replaced deprecated `.text.text` calls with `.text.toPlainText()`.
   - Added `@visibleForTesting` getters for `editor` and `composer`.
2. **Layer 2: Inline Spacing Normalizer (`normalizeInlineMarkdownSpacing`)**:
   - Added `normalizeInlineMarkdownSpacing(String markdown)` in `lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart`.
   - Uses regex replacements to push whitespace outside of delimiter bounds:
     - `**word **` -> `**word** `
     - `** word**` -> ` **word**`
     - `~~word ~~` -> `~~word~~ `
     - `*word *` -> `*word* `
   - Safely skips fenced code blocks (` ``` ` or `~~~`) and inline code backticks (`` ` ``).
   - Integrated into `normalizeMarkdownForSuperEditor()` so existing notes and external markdown strings are repaired on deserialization.
   - Integrated into `QuietSuperEditor._onDocumentChange` before calling `widget.onChanged()`, guaranteeing clean CommonMark on serialization.

### 3. Verification & Quality
- `flutter analyze` — **No issues found!**
- `flutter test` — all tests in `test/editor/` passing (545 passing tests).
- Added comprehensive unit and widget tests in `test/editor/quiet_super_editor_test.dart`:
  - Unit tests verifying `normalizeInlineMarkdownSpacing` with bold, italic, strikethrough, multi-word spans, and code block preservation.
  - Unit test verifying `deserializeMarkdownToDocument` + `normalizeMarkdownForSuperEditor` recovers bold text with trailing space without literal asterisks.
  - Controller unit test confirming `toggleBold` trims whitespace from selection.
  - Widget integration test verifying bold styling survives edit -> preview -> edit toggle cycle with zero literal asterisks and `boldAttribution` intact.

## 190. Keep Image Attachment Import Responsive (October 2026)

Image imports already offloaded large XChaCha20 encryption work to a background isolate, but the progress overlay could still stall while the main isolate hashed the entire image and synchronously flushed its encrypted bytes to disk. `AttachmentCrypto.computeSha256Async` now offloads digests at 256 KB and above while keeping smaller hashes inline, and `AttachmentLocalStorage.saveEncryptedBytes` awaits `File.writeAsBytes`. Image and generic-file import paths use the asynchronous digest. Attachment hashing now runs concurrently with encryption, avoiding serial passes over large payloads. The SHA-256 value and encrypted attachment envelope are unchanged; filesystem writes still flush before the import continues.

## 191. Bound PDF Raster Memory and Skip OCR for Large Imports (October 2026)

Imported PDFs larger than 8 MiB or whose declared page size would exceed the OCR pixel budget are stored without queuing OCR. The PDF remains viewable and the OCR state is `skipped`, shown explicitly in the viewer; manual OCR retry is blocked with an explanation. Backend document confirmation validation accepts and preserves the `skipped` state. `PdfRasterPolicy` computes a reduced raster DPI for pages above 4 megapixels and is applied to the document viewer and PDF thumbnail renderers. OCR also renders and recognizes one page at a time, reducing peak memory for PDFs that remain eligible for OCR. The policy is intentionally conservative for oversized scans; encrypted storage and original PDF bytes are unchanged.

Editor image imports now defer OCR scheduling until after the blocking “Encrypting & saving…” overlay has been removed. Attachment persistence remains synchronous with the import; OCR still runs asynchronously immediately after the UI save step completes.

## 192. Desktop Adaptive Modals — Architecture & Core Abstraction Layer (Phase 1) (October 2026)

### Architectural Overview & Motivation
Quiet Paper previously presented modals across the entire app using mobile `showModalBottomSheet`. On Linux and desktop platforms (mouse and keyboard, widescreen displays), bottom sheets impose significant Fitts's Law inefficiency (cursor traveling from top-bar triggers down to the screen floor), lack visual anchoring to action triggers, hide the active note during comparative tasks, and display mobile-only artifacts (drag handle pills, swipe-to-dismiss gestures).

To address this, Phase 1 establishes the unified core abstraction and 4 adaptive desktop paradigms:
1. **`QuietAdaptiveModal`** ([`lib/core/widgets/quiet_adaptive_modal.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_adaptive_modal.dart)):
   - Centralized presentation facade routing between mobile bottom sheets (`showModalBottomSheet`) and desktop modals (`showQuietPopover`, `showQuietSpotlight`, `showQuietDialog`).
   - Integrates with `PlatformLayoutHelper.isDesktop([context])` to respect runtime theme overrides (`ThemeData.platform`) and `defaultTargetPlatform`.
   - `AdaptiveSheetDragHandle`: Renders a subtle touch handle on mobile, and `SizedBox.shrink` on desktop.
2. **`QuietPopoverRoute` & `showQuietPopover`** ([`lib/core/widgets/quiet_popover.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_popover.dart)):
   - Anchors contextual flyouts adjacent to trigger `GlobalKey` or cursor `Offset`.
   - Dynamic collision detection: Automatically flips between opening below or above the anchor based on available vertical clearance, and clamps horizontally within viewport margins.
   - Editorial styling: Warm `colors.surface`, 0.8px border in `colors.divider`, `AppRadii.borderMd` (12dp), subtle elevation, and `Escape` key dismissal via `CallbackShortcuts`.
3. **`showQuietSpotlight`** ([`lib/core/widgets/quiet_spotlight_dialog.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_spotlight_dialog.dart)):
   - Floating Command Palette modal anchored in the upper-third of the screen (`Alignment(0.0, -0.38)`) for keyboard-first selectors (note links, syntax languages, fonts, tags).
   - Instant keyboard autofocus and `Escape` key dismissal.
4. **`showQuietDialog` & `QuietEditorialDialogCard`** ([`lib/core/widgets/quiet_editorial_dialog.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_editorial_dialog.dart)):
   - Centered editorial dialog with structured header (title, subtitle, trailing actions), discrete '✕' close button, scrollable body, and `Escape` key dismissal.

## 193. Desktop Adaptive Modals — Context Popovers & Action Menus Migration (Phase 2) (October 2026)

### Overview & Enhancements
Phase 2 migrates all quick action menus, contextual options, and tool dropdowns from mobile-only `showModalBottomSheet` to `QuietAdaptiveModal.show` with `AdaptiveModalType.popover`:

- **Editor App Bar `⋯` Overflow Menu** ([`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart)):
  - Anchored directly to `_overflowButtonKey` on the `QuietIconButton` at the top right of the window.
  - Opens as a crisp popover immediately beneath the button on desktop with full sub-menu navigation preserved, while maintaining standard modal bottom sheet on mobile devices.
- **Editor Toolbars & Hubs**:
  - [`MarkdownHeadingActionSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/heading/markdown_heading_action_sheet.dart): Opens as an anchored popover for 1-tap H1–H6 level selection.
  - [`MarkdownTableActionSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/table/markdown_table_action_sheet.dart): Opens adjacent to the table toolbar button for row/column operations.
  - [`FormattingHubSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_hub_sheet.dart): Opens as an anchored formatting popover with `AdaptiveSheetDragHandle` eliminating mobile drag pills on desktop.
- **Context & Selection Menus**:
  - Note list tile context actions in [`NoteListTile`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_list_tile.dart).
  - Sidebar section & tag action menus in [`SidebarView`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart).
  - Inline image attachment context menu in [`QuietAssetImageView`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/quiet_asset_image_view.dart).
  - Tag browser options in [`TagBrowserView`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_browser_view.dart).
  - Tag color picker in [`TagColorPickerSheet`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_color_picker_sheet.dart) with responsive layout and `maxWidth: 380`.
  - Default image compression settings sheets in [`DefaultSettingsScreen`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart).
  - Journal place actions in [`place_edit_dialogs.dart`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_edit_dialogs.dart).
  - Document viewer PDF share variant picker in [`document_viewer_screen.dart`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/document_viewer_screen.dart).
- **Test Coverage**: Added [`test/widgets/context_popover_test.dart`](file:///home/dog/git/quitepaper/test/widgets/context_popover_test.dart) covering Linux popovers, auto-flip positioning, Escape dismissal, and Android bottom sheet fallbacks.

## 194. Desktop Adaptive Modals — Spotlight Command Palettes Migration (Phase 3) (October 2026)

### Overview & Enhancements
Phase 3 migrates all searchable pickers, fast lookup selectors, and command-style prompts from mobile bottom sheets to desktop Spotlight / Command Palette modals (`QuietAdaptiveModal.show` with `AdaptiveModalType.spotlight`):

- **Searchable Pickers & Command Palettes**:
  - **Note Link Picker** ([`lib/features/editor/presentation/widgets/note_link_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/note_link_picker_sheet.dart)):
    - Floats in the upper third of the screen with immediate autofocus on the search input, arrow key navigation (Up/Down/Enter), and Escape dismissal.
    - Expanded height constraint (`360dp` on desktop) displaying more search results comfortably without visual clutter.
  - **Syntax Language Selector** ([`lib/core/syntax/presentation/language_selector_sheet.dart`](file:///home/dog/git/quitepaper/lib/core/syntax/presentation/language_selector_sheet.dart)):
    - Adapts to top-third spotlight modal (`maxWidth: 520`) with instant search autofocus, clean divider-less card, and `AdaptiveSheetDragHandle`.
  - **Tag Browser Palette** ([`lib/features/sidebar/presentation/widgets/tag_browser_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/widgets/tag_browser_sheet.dart)):
    - Opens as a spotlight palette (`maxWidth: 520`) with keyboard autofocus on tag filter textfield, replacing mobile bottom sheet.
  - **Font Picker & Google Fonts Browser** ([`lib/features/settings/presentation/widgets/font_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/font_picker_sheet.dart), [`lib/features/settings/presentation/widgets/google_fonts_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/google_fonts_sheet.dart)):
    - Extracted clean responsive content builders, replacing mobile `DraggableScrollableSheet` with desktop upper-third spotlight modals (`maxWidth: 600-620`), discreet close buttons, and instant search autofocus.
  - **Tag Icon Picker** ([`lib/features/tags/presentation/widgets/tag_icon_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_icon_picker_sheet.dart)):
    - Standardized onto `QuietAdaptiveModal.show` with `AdaptiveModalType.spotlight` (`maxWidth: 640`), keyboard autofocus, and category chips.
  - **Journal Metadata Pickers**:
    - [`ActivityPickerSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/activity_picker_sheet.dart): Activity multi-selector with `AdaptiveSheetDragHandle` and spotlight eye-level positioning (`maxWidth: 520`).
    - [`MomentPickerSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/moment_picker_sheet.dart): 10-moment contextual picker (`maxWidth: 480`).
    - [`MoodPickerSheet`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/mood_picker_sheet.dart): 10-level visual mood grid (`maxWidth: 480`).
    - [`PlacePickerSheet`](file:///home/dog/git/quitepaper/lib/features/journal/presentation/widgets/place_picker_sheet.dart): Forward-geocoded location search with desktop close button, instant search autofocus, and spotlight centering (`maxWidth: 540`).
- **Test Coverage**: Added [`test/widgets/spotlight_palette_test.dart`](file:///home/dog/git/quitepaper/test/widgets/spotlight_palette_test.dart) verifying Linux spotlight rendering, search filtering, Escape key dismissal, and mobile bottom sheet fallbacks on Android.

---

## 195. Desktop Adaptive Modals: Centered Editorial Dialogs Migration (Phase 4)

- **Architecture & Overview**:
  - Implemented Phase 4 of the Desktop Adaptive Modals system, migrating complex multi-step modal workflows, editors, and configuration sheets from mobile bottom sheets to centered editorial dialogs (`AdaptiveModalType.dialog`).
  - Centered dialogs render as elegant card dialogs (`QuietEditorialDialogCard`) constrained by ergonomic widths (`400-680dp`), featuring header rows with dismiss buttons, keyboard `Escape` dismissal, and clean surface backgrounds with elevation and subtle borders.
  - On mobile and touch platforms, all components smoothly fallback to standard `showModalBottomSheet` with drag handles, rounded top borders, and safe areas via `AdaptiveSheetDragHandle()`.
  - Enhanced `QuietAdaptiveModal.show` to support `enableDrag` and `barrierDismissible` across both desktop and mobile presentations.
- **Migrated Modals (11 targets)**:
  1. [`ExportNoteSheet`](file:///home/dog/git/quitepaper/lib/features/export/presentation/export_note_sheet.dart): Centered editorial dialog (`maxWidth: 620`), adaptive scroll container, suppressed drag handle on desktop, and custom header actions.
  2. [`NotesSortSheet`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/notes_sort_sheet.dart): Centered sort dialog (`maxWidth: 440`) with close button, active context filters, and ordering controls.
  3. [`NotesFilterSheet`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/notes_filter_sheet.dart): Centered advanced query filter dialog (`maxWidth: 580`) with tag search, date range pickers, and smart view save actions.
  4. [`SavedFiltersSheet`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/saved_filters_sheet.dart): Centered smart view manager dialog (`maxWidth: 480`) with rename and delete flows.
  5. [`ShareNoteSheet`](file:///home/dog/git/quitepaper/lib/features/share/presentation/share_note_sheet.dart): Centered public URL sharing dialog (`maxWidth: 520`) with password protection options, clipboard actions, and external URL launching.
  6. [`ManageSharesScreen`](file:///home/dog/git/quitepaper/lib/features/share/presentation/manage_shares_screen.dart): Share visibility selector dialog (`maxWidth: 400`) with title and clean list tile choices.
  7. [`DeviceDetailSheet`](file:///home/dog/git/quitepaper/lib/features/devices/presentation/device_detail_sheet.dart): Centered device management dialog (`maxWidth: 480`) with inline rename dialog and sign-out/erase local vault controls.
  8. [`WebClipPreviewSheet`](file:///home/dog/git/quitepaper/lib/features/web_clipper/presentation/web_clip_preview_sheet.dart): Centered web clip commit dialog (`maxWidth: 680`) with live storage estimates, HTML snapshot toggle, and encrypted image tray.
  9. [`WebClipBrowserScreen`](file:///home/dog/git/quitepaper/lib/features/web_clipper/presentation/browser/web_clip_browser_screen.dart): Standardized 3 call sites (lines 98, 190, 214) to `WebClipPreviewSheet.show`, automatically inheriting adaptive dialog behavior.
  10. [`PageAdjustmentSheet`](file:///home/dog/git/quitepaper/lib/features/scanner/presentation/widgets/page_adjustment_sheet.dart): Centered 60fps GPU document adjustment dialog (`maxWidth: 640`, `maxHeight: 740`) with tone, scan mode, rotation, and 4-corner perspective quad editing.
  11. [`MaintenanceProgressSheet`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/maintenance_progress_sheet.dart): Centered non-dismissible maintenance progress dialog (`maxWidth: 440`, `barrierDismissible: false`) with cancellation tokens.
- **Verification & Test Coverage**:
  - Added [`test/widgets/editorial_dialog_test.dart`](file:///home/dog/git/quitepaper/test/widgets/editorial_dialog_test.dart) testing Linux card dialog rendering, Escape key dismissal, Android bottom sheet fallback, `NotesSortSheet`, `SavedFiltersSheet`, and `MaintenanceProgressSheet` barrier properties.
  - Verified static analysis with `flutter analyze` (**0 issues, 0 warnings**).
  - Verified test suite: all widget and regression tests pass (**100% passing**).

---

## 196. Desktop Adaptive Modals: Multi-Pane Right Inspector Pane (Phase 5) (October 2026)

- **Architecture & Overview**:
  - Implemented Phase 5 of the Desktop Adaptive Modals system, establishing the 4th column "Right Inspector Pane" (`AdaptiveModalType.inspector`) docked beside the editor on widescreen desktop environments ($\ge 1100\text{dp}$).
  - Solves the problem of comparative and contextual workflows (version comparison, attachment metadata inspection, file properties) obstructing the active note by allowing concurrent side-by-side editing and inspection without modal barriers.
  - On standard desktop viewports ($< 1100\text{dp}$), components cleanly adapt into centered editorial dialogs (`QuietEditorialDialogCard`).
  - On mobile/touch platforms, components fall back to bottom sheets with drag handles and sheet physics via `AdaptiveSheetDragHandle()`.
- **Key Components & Implementations**:
  1. [`lib/core/utils/platform_layout_helper.dart`](file:///home/dog/git/quitepaper/lib/core/utils/platform_layout_helper.dart):
     - Added `PlatformLayoutHelper.isWidescreen(context, [double breakpoint = 1100])` checking `isDesktop(context) && MediaQuery.of(context).size.width >= breakpoint`.
  2. [`lib/features/editor/presentation/active_inspector_provider.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/active_inspector_provider.dart):
     - Created `activeInspectorProvider`, `ActiveInspectorNotifier`, and `ActiveInspectorState` managing global inspector lifecycle across `versionHistory`, `attachmentDetails`, and `attachmentFileInfo`.
     - Static callers in modal sheets can transparently invoke `container.read(activeInspectorProvider.notifier)...` from anywhere within the widget tree.
  3. [`lib/features/editor/presentation/widgets/editor_inspector_pane.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/editor_inspector_pane.dart):
     - Right-docked 380dp persistent inspector panel with subtle surface coloring (`colors.surface`) and left divider line.
     - Routes active inspector state to `VersionHistorySheet`, `AttachmentDetailsSheet`, or `AttachmentFileInfoSheet` with unified `onClose` callback wiring.
  4. [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
     - Embedded `EditorInspectorPane` adjacent to `PullDownSearchReveal` in a horizontal `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` when `isWidescreen` and `activeInspectorProvider.isOpen`.
     - Automatically resets/closes the inspector on active note switch (`didUpdateWidget`) and screen teardown (`dispose()`).
  5. [`lib/features/editor/presentation/widgets/version_history_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/version_history_sheet.dart):
     - Added widescreen routing in `show()`, header close button, and adaptive container (`BoxConstraints.expand()` when embedded in inspector; `maxHeight: 640` in desktop dialog; `0.85 * viewport` on mobile).
  6. [`lib/core/attachments/presentation/attachment_details_sheet.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/attachment_details_sheet.dart):
     - Added `onClose` callback, widescreen routing to inspector, desktop header close button, and unified `_closeSheet()` handling across preview, open, share, saveAs, rename, and delete actions.
  7. [`lib/core/attachments/presentation/attachment_file_info_sheet.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/attachment_file_info_sheet.dart):
     - Migrated from raw `showModalBottomSheet` to `PlatformLayoutHelper.isWidescreen` inspector docking, desktop centered dialog (`maxWidth: 460`), and mobile bottom sheet fallback.
- **Verification & Test Coverage**:
  - Added [`test/widgets/inspector_pane_test.dart`](file:///home/dog/git/quitepaper/test/widgets/inspector_pane_test.dart) covering:
    - Empty inspector pane when inactive.
    - `VersionHistorySheet` docking on widescreen desktop ($\ge 1100\text{dp}$) and closing via header button.
    - `AttachmentFileInfoSheet` docking on widescreen desktop and closing via header button.
    - Fallback to centered editorial dialog on narrow desktop ($< 1100\text{dp}$) with Escape key dismissal.
    - Fallback to `BottomSheet` on Android mobile platform.
  - Verified regression safety with all 5 adaptive modal test suites passing (**27 of 27 tests passed**).
  - Static analysis: `flutter analyze` reports **0 issues found**.

---

## 197. Desktop Adaptive Modals: Comprehensive Verification & 100% Migration Milestone (Phase 6) (October 2026)

- **Exhaustive Migration Milestone**:
  - Successfully audited all 41 modal occurrences across the entire codebase.
  - Migrated the final mobile insert sheet in [`FormattingToolbar`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/formatting_toolbar.dart) to `QuietAdaptiveModal.show` with `AdaptiveSheetDragHandle()`.
  - Result: There are now **zero** raw `showModalBottomSheet` calls anywhere in the product code outside of the core `QuietAdaptiveModal` routing abstraction itself.
- **Architectural Parity Across All 4 Paradigms**:
  1. **Context Popovers (`AdaptiveModalType.popover`)**: Editor 3-dot overflow menu, toolbar pickers (heading levels, table actions, insert items, formatting hub), note list tile actions, sidebar menus, tag color pickers, and place action sheets.
  2. **Spotlight Command Palettes (`AdaptiveModalType.spotlight`)**: Note link picker, syntax language selector, tag browser, typography/font selector, Google Fonts browser, tag icon picker, and journal metadata pickers (activity, moment, mood, place).
  3. **Centered Editorial Dialogs (`AdaptiveModalType.dialog`)**: Export note sheet, notes sort sheet, notes query filter sheet, saved filters sheet, share note sheet, manage shares screen, device details sheet, web clip preview sheet, and document scanner page adjustment sheet.
  4. **Multi-Pane Right Inspector (`AdaptiveModalType.inspector`)**: Version history & diff sheet, attachment details & action sheet, and attachment file info sheet docking on widescreen displays ($\ge 1100\text{dp}$) beside the active editor.
- **Verification & Test Coverage**:
  - Zero warnings or errors in static analysis (`flutter analyze` clean).
  - 100% passing across the entire test suite including all modal test suites (`quiet_adaptive_modal_test.dart`, `context_popover_test.dart`, `spotlight_palette_test.dart`, `editorial_dialog_test.dart`, `inspector_pane_test.dart`, `formatting_toolbar_test.dart`, `desktop_toolbar_and_shortcuts_test.dart`, and `editor_overflow_menu_test.dart`).

---

## 198. Editor Inspector Lifecycle Hardening & Riverpod Build Safety (October 2026)

- **Problem Description**:
  - In [`EditorScreen.didUpdateWidget`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart), switching active notes triggered synchronous `ref.read(activeInspectorProvider.notifier).close()` during the widget build/update phase.
  - This violated Riverpod's constraint against mutating providers while the widget tree is rebuilding (`Tried to modify a provider while the widget tree was building`), causing CI failures in note-switching integration tests (`editor_scrollbar_test.dart`).
- **Fix & Enhancements**:
  1. [`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart):
     - Wrapped note-switch inspector closing in `WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) ref.read(activeInspectorProvider.notifier).close(); })`.
     - Removed synchronous provider mutation from `dispose()`.
  2. [`lib/features/editor/presentation/active_inspector_provider.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/active_inspector_provider.dart):
     - Guarded `ActiveInspectorNotifier.close()` with `if (state.isOpen)` to eliminate redundant state updates when the inspector is already closed.
- **Verification**:
  - `editor_scrollbar_test.dart` passed completely (**4 of 4 tests passed**).
  - All 47 tests across editor, scrollbar, toolbar, and modal suites pass.
  - `flutter analyze` reports **0 issues found**.

---

## 199. Desktop Ollama OCR (DeepSeek-OCR) Integration & Settings Overhaul (October 2026)

- **Motivation & Background**:
  - Quiet Paper previously utilized Google ML Kit (`google_mlkit_text_recognition`) on Android/iOS, which lacks native desktop support (Linux, macOS, Windows). Desktop builds previously fell back to a heuristic pure-Dart computer-vision line segmentation routine that lacked actual character transcription.
  - Furthermore, ML Kit struggles with complex multi-column layouts, tables, and formatted mathematical text, whereas modern Vision-Language Models like DeepSeek-OCR offer human-grade document-to-Markdown recognition while preserving zero-knowledge offline privacy when executed locally.
- **Architectural Enhancements**:
  1. [`OllamaOcrService`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_service.dart):
     - Implements [`OcrService`](file:///home/dog/git/quitepaper/lib/core/ocr/ocr_service.dart) for desktop targets.
     - Interacts with local Ollama daemon via `POST /api/generate` with Base64 image payload, target model (`deepseek-ocr`), and Markdown transcription prompt (`<|grounding|>Convert the document to markdown.`).
     - Maps Markdown responses into structured `OcrPage` containing single full-page `OcrBlock` (`NormalizedRect(x: 0.05, y: 0.05, width: 0.90, height: 0.90)`), enabling full-text search indexing and formatted copying while bypassing word-level highlight snapping.
  2. [`OllamaOcrSettings` & `OllamaOcrSettingsNotifier`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_settings.dart):
     - Manages persisted settings in `SharedPreferences` (`quietpaper_ollama_ocr_enabled`, `quietpaper_ollama_ocr_endpoint`, `quietpaper_ollama_ocr_model`).
     - Features `checkConnection()` querying `GET /api/tags` with 5-second timeout, discovering locally installed models (e.g., `deepseek-ocr:latest`, `hf.co/ggml-org/DeepSeek-OCR-GGUF:latest`).
  3. [`DefaultOcrService` Delegation & Fallback](file:///home/dog/git/quitepaper/lib/core/ocr/ocr_service.dart):
     - Mobile platforms (Android/iOS) continue using hardware-accelerated Google ML Kit.
     - Desktop platforms (Linux/macOS/Windows) delegate to `OllamaOcrService` when enabled and reachable.
     - On connection failure, daemon timeout, or disabled state, smoothly and quietly falls back to computer-vision fallback without throwing unhandled exceptions.
  4. [`SettingsScreen` Desktop OCR Section](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart):
     - Added dedicated `DESKTOP OCR (OLLAMA)` grouped table section visible on desktop platforms.
     - Features:
       - "Use Local Ollama OCR" toggle (`CupertinoSwitch`).
       - Live Daemon Status with status color indicator (Green: Connected, Amber: Checking, Red: Offline) and refresh icon button to trigger on-demand ping with feedback SnackBar.
       - Tappable "Ollama Endpoint" row opening editorial URL editor dialog.
       - Tappable "OCR Model" row opening model selector dialog listing discovered Ollama models plus custom model entry.
- **Verification & Test Coverage**:
  - Unit tests in [`test/ocr/ollama_ocr_service_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_ocr_service_test.dart): Verified payload generation, markdown mapping, HTTP error handling, document multi-page rasterization, and fallback delegation.
  - Unit tests in [`test/ocr/ollama_ocr_settings_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_ocr_settings_test.dart): Verified preferences persistence, defaults, and `/api/tags` connection checks.
  - Widget tests in [`test/settings/desktop_ollama_ocr_settings_test.dart`](file:///home/dog/git/quitepaper/test/settings/desktop_ollama_ocr_settings_test.dart): Verified desktop section rendering, switch toggling, endpoint edit dialog, and model selector dialog.
  - Zero warnings or errors in static analysis (`flutter analyze` clean).
  - All OCR and Settings tests pass with 100% success.

---

## 200. Linux Client Modernization: Wayland, System Dark Mode, Kinetic Smooth Scrolling & Fractional Scaling (October 2026)

### 1. Architectural Overview & Context
While Quiet Paper supported Linux compilation via Flutter's GTK 3 desktop embedder, several critical gaps affected the user experience on modern Linux desktop environments (particularly KDE Plasma and GNOME on Wayland):
1. **Wayland Nativity & Fractional Scaling Protocol Gap**:
   - Quiet Paper connects directly to the Wayland display server via GDK's Wayland backend (`GDK_BACKEND=wayland`).
   - However, GTK 3 does not implement the modern Wayland fractional scaling protocol (`wp_fractional_scale_v1`). On fractional scaling displays (e.g. 125% scaling on 1080p), GTK 3 only reports integer scale 2, and the Wayland compositor (KWin) performs downscaling interpolation, causing fuzzy text, soft 1px borders/dividers, and presentation jitter.
2. **System Dark Mode Disconnect on KDE Plasma / Non-GNOME Desktops**:
   - In KDE Plasma and modern FreeDesktop environments, dark mode is configured via `org.freedesktop.appearance color-scheme: 1` (`prefer-dark`).
   - However, the GTK theme setting often remains `'Breeze'` rather than `'Breeze-Dark'`. Because `my_application.cc` never instructed GTK to prefer dark themes (`gtk-application-prefer-dark-theme` defaulted to `FALSE`), Flutter's native `fl_settings_plugin` concluded the desktop was in Light Mode, forcing Quiet Paper's `ThemeMode.system` into the Light theme despite the host OS being in Dark Mode.
3. **Rigid Mouse Wheel Scrolling**:
   - Flutter's desktop engine dispatches discrete, rigid `PointerScrollEvent` deltas (each mouse wheel notch instantly teleports by 40–60px).
   - Combined with hardcoded mobile `BouncingScrollPhysics`, scrolling through notes, the sidebar, or long editor documents felt jerky and un-ergonomic compared to native Linux apps.
4. **Mismatched Window HeaderBar on KDE Plasma**:
   - `my_application.cc` previously forced a GNOME-style `GtkHeaderBar` unconditionally under Wayland, clashing with KDE Plasma's Breeze Server-Side Decorations (SSD), shadows, and window buttons.

### 2. Implementation Pillars & Enhancements

#### Pillar 1: Dual-Layer System Dark Mode Synchronization
- **Native C++ Layer ([`linux/runner/my_application.cc`](file:///home/dog/git/quitepaper/linux/runner/my_application.cc))**:
  - Implemented `detect_system_dark_mode()` querying `org.freedesktop.portal.Settings` via GDBus (`org.freedesktop.appearance`, `color-scheme`) with a graceful fallback to GSettings `org.gnome.desktop.interface`.
  - Implemented `sync_gtk_theme_mode()` to set `gtk-application-prefer-dark-theme = TRUE/FALSE` on default `GtkSettings`.
  - Subscribed to the D-Bus `SettingChanged` signal on `org.freedesktop.portal.Settings` in `my_application_startup`, dynamically toggling GTK theme properties and notifying Flutter's `fl_settings_plugin` whenever the system appearance switch is flipped.
- **Dart Layer ([`lib/core/theme/linux_theme_resolver.dart`](file:///home/dog/git/quitepaper/lib/core/theme/linux_theme_resolver.dart) & [`lib/features/settings/application/settings_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/settings_provider.dart))**:
  - Added `LinuxThemeResolver` providing asynchronous portal, GSettings, and KDE globals appearance detection.
  - Exposed `linuxSystemBrightnessProvider` and integrated into [`lib/app/app.dart`](file:///home/dog/git/quitepaper/lib/app/app.dart) so `AppearanceMode.system` immediately resolves to the detected desktop brightness.

#### Pillar 2: Desktop Environment-Aware Window Titlebar & Background Color
- In [`linux/runner/my_application.cc`](file:///home/dog/git/quitepaper/linux/runner/my_application.cc):
  - Detected `XDG_CURRENT_DESKTOP`. When running in GNOME Shell, retains `GtkHeaderBar` (standard GNOME CSD convention). When running in KDE Plasma (or XFCE, Sway, Hyprland), uses the native traditional window titlebar so KDE renders native Breeze SSD with window shadows, buttons, and system integration.
  - Dynamically set `fl_view_set_background_color` based on `gtk-application-prefer-dark-theme` (`#1D1C1A` dark / `#F7F6F2` light), eliminating startup black frame flash.

#### Pillar 3: Kinetic Smooth Mouse Wheel Scrolling Engine
- **[`DesktopSmoothScroll`](file:///home/dog/git/quitepaper/lib/core/widgets/desktop_smooth_scroll.dart)**:
  - Created a dedicated desktop scrolling widget wrapping scrollables (`ListView`, `SingleChildScrollView`).
  - Intercepts `PointerScrollEvent` on desktop platforms (`PlatformLayoutHelper.isDesktopPlatform`), smoothly gliding to the accumulated target offset via `Curves.easeOutCubic` over 200ms with velocity accumulation.
  - Clamps cleanly to scroll extents and passes through on mobile/touch platforms without altering touch fling mechanics.
  - Integrated across:
    - Notes list views (phone and tablet layouts in [`notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart)).
    - Navigation sidebar list in [`sidebar_view.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart).
    - Note editor sheet in [`editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart).
- **[`DesktopAppScrollBehavior`](file:///home/dog/git/quitepaper/lib/app/app.dart)**:
  - Configured global `MaterialApp.scrollBehavior` adapting physics dynamically: `ClampingScrollPhysics` on desktop (eliminating rubber-band bounce on mouse wheels) and `BouncingScrollPhysics` on mobile.

#### Pillar 4: Fractional Scaling Optimizations & Pixel Snapping
- **[`PixelSnap`](file:///home/dog/git/quitepaper/lib/core/utils/pixel_snap.dart)**:
  - Created `PixelSnap.hairlineWidth(context)` returning `(1.0 / dpr).clamp(0.5, 1.0)`, ensuring hairline dividers and borders snap directly to physical device pixels on 1.25x or 1.5x fractional scaling displays.
  - Added coordinate snapping functions (`snap`, `snapOffset`).
- **Text Scaling Bounds ([`lib/app/app.dart`](file:///home/dog/git/quitepaper/lib/app/app.dart))**:
  - Clamped `textScaler` between `0.85` and `1.35` in `MaterialApp.builder` to prevent layout overflow when system font scaling is applied atop fractional monitor scaling.

### 3. File Inventory
- **New Files**:
  - `lib/core/theme/linux_theme_resolver.dart`: FreeDesktop portal and GSettings system theme reader.
  - `lib/core/widgets/desktop_smooth_scroll.dart`: Kinetic smooth mouse-wheel scrolling wrapper.
  - `lib/core/utils/pixel_snap.dart`: Hardware device-pixel snapping for fractional display scaling.
  - `test/theme/linux_theme_resolver_test.dart`: Unit tests for theme resolver queries and fallbacks.
  - `test/widgets/desktop_smooth_scroll_test.dart`: Widget tests for smooth scroll event interception and animation.
  - `test/utils/pixel_snap_test.dart`: Unit tests for hairline widths and coordinate snapping.
- **Modified Files**:
  - `linux/runner/my_application.cc`: D-Bus portal subscription, dark theme GTK sync, KDE-specific native titlebar, and warm initial background.
  - `lib/features/settings/application/settings_provider.dart`: Exposed `linuxThemeResolverProvider` and `linuxSystemBrightnessProvider`.
  - `lib/app/app.dart`: Effective theme mode resolution, `DesktopAppScrollBehavior`, and text scaling clamp.
  - `lib/features/notes/presentation/notes_screen.dart`: Applied `DesktopSmoothScroll` and adaptive scroll physics.
  - `lib/features/sidebar/presentation/sidebar_view.dart`: Applied `DesktopSmoothScroll` to sidebar navigation.
  - `lib/features/editor/presentation/editor_screen.dart`: Applied `DesktopSmoothScroll` and adaptive scroll physics to editor.

### 4. Verification & Quality
- Static analysis: `flutter analyze` (**0 issues, 0 warnings**).
- Automated tests: All unit, widget, and integration tests pass with 100% success.

---

## 201. Tag Browser Anchored Popover Context Menu & Trailing Options Fix (October 2026)

### 1. Issue Overview & Root Cause Analysis
- **Problem**: When clicking the 3-dot vertical action icon (`⋮`) for any tag in the Tag Browser / middle tag pane on desktop (Linux / Wayland / KDE Plasma), the context popover menu opened in the wrong location: floating in the center of the window over the editor pane instead of anchored directly beneath the 3-dot button.
- **Root Cause Investigation**:
  1. **Missing Anchor in `TagBrowserView`**:
     - In [`lib/features/tags/presentation/widgets/tag_browser_view.dart`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_browser_view.dart), `_showTagOptions(context, item)` invoked `QuietAdaptiveModal.show` with `AdaptiveModalType.popover`, but did not pass `anchorKey`, `anchorContext`, or `cursorPosition`.
     - In [`lib/core/widgets/quiet_popover.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_popover.dart), when neither an anchor nor a cursor position was provided, `showQuietPopover` defaulted to `anchorRect = Rect.fromCenter(center: overlay.size.center(Offset.zero))`, placing the popover directly in the center of the entire window (spanning across pane boundaries).
  2. **Lack of Horizontal End Alignment**:
     - `_QuietPopoverLayoutDelegate` previously aligned the popover to `anchorRect.left`. For trailing action buttons situated at the right edge of a pane (such as the 3-dot button at the right of a 300px Tag Browser pane), `x = anchorRect.left` caused a 280px wide popover to project rightwards out of the Tag Browser pane and across the adjacent Editor pane.
  3. **Secondary Tap (Right-Click) Position Loss**:
     - `InkWell` in `_buildTagItem` used `onSecondaryTap` rather than `onSecondaryTapUp: (details) => ...`, failing to capture `details.globalPosition`.
  4. **ReorderableListView Default Drag Handle Collision**:
     - `ReorderableListView.builder` for pinned tags defaulted `buildDefaultDragHandles: true`, which placed Flutter's default Material reorder drag handle over the trailing 3-dot button.
  5. **Modal Header Layout & Material Ancestor Assertion**:
     - The modal header `Row` containing `#${tag.name}` and note counts lacked flex constraints, causing overflow on long tag names.
     - The modal content was wrapped in a `Container(decoration: BoxDecoration(color: colors.surface))` around `ListTile` items, which triggered Flutter framework assertions regarding missing `Material` ancestors.

### 2. Solution & Architectural Enhancements
1. **Adaptive Popover Alignment Strategy ([`lib/core/widgets/quiet_popover.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_popover.dart))**:
   - Introduced `enum PopoverAlignment { start, end, center, auto }`.
   - Updated `_QuietPopoverLayoutDelegate.getPositionForChild`:
     - `PopoverAlignment.end`: Computes `x = anchorRect.right - childSize.width`, anchoring the top-right of the popover flush with the bottom-right of the anchor button, keeping the menu neatly tucked inside the tag pane.
     - `PopoverAlignment.start`: Computes `x = anchorRect.left`.
     - `PopoverAlignment.center`: Aligns `x` to the anchor's horizontal midpoint.
     - `PopoverAlignment.auto`: Automatically flips to end-alignment if the anchor is on the right half of the screen or would overflow the right viewport boundary.
   - Enhanced `showQuietPopover` to accept `BuildContext? anchorContext` in addition to `GlobalKey? anchorKey` and `Offset? cursorPosition`, extracting the global bounding rect from `anchorContext.findRenderObject()`. Added fallback to `context.findRenderObject()` if no explicit anchor is specified.
2. **Modal Controller Routing ([`lib/core/widgets/quiet_adaptive_modal.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_adaptive_modal.dart))**:
   - Exported `PopoverAlignment` from `quiet_adaptive_modal.dart`.
   - Added `BuildContext? anchorContext`, `PopoverAlignment alignment = PopoverAlignment.auto`, and `double minWidth = 200` to `QuietAdaptiveModal.show`, seamlessly forwarding to `showQuietPopover`.
3. **Tag Browser Presentation Refactor ([`lib/features/tags/presentation/widgets/tag_browser_view.dart`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_browser_view.dart))**:
   - Updated `_showTagOptions` to accept `BuildContext? anchorContext`, `Offset? cursorPosition`, and `PopoverAlignment? alignment`.
   - In `_buildTagItem`:
     - Wrapped the 3-dot `IconButton` with `Builder(builder: (btnContext) => ...)` and passed `anchorContext: btnContext` and `alignment: PopoverAlignment.end`.
     - Converted `onSecondaryTap` to `onSecondaryTapUp: (details) => _showTagOptions(context, item, cursorPosition: details.globalPosition)`.
   - Updated `_showTagOptions` modal builder to use `Material(color: colors.surface)` instead of `Container(decoration: ...)` and wrapped `#${tag.name}` in `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))`.
   - Configured `buildDefaultDragHandles: false` on `ReorderableListView.builder` for pinned tags, wrapping items in `ReorderableDelayedDragStartListener` so long-press dragging works cleanly without intrusive overlay handles.

### 3. File Inventory
- **Modified Files**:
  - `lib/core/widgets/quiet_popover.dart`: Added `PopoverAlignment` enum, `anchorContext` parameter and resolution, and alignment positioning logic in `_QuietPopoverLayoutDelegate`.
  - `lib/core/widgets/quiet_adaptive_modal.dart`: Exported `PopoverAlignment`, added `anchorContext`, `alignment`, and `minWidth` to `QuietAdaptiveModal.show`.
  - `lib/features/tags/presentation/widgets/tag_browser_view.dart`: Integrated `anchorContext` on 3-dot button, `onSecondaryTapUp` with `globalPosition`, `buildDefaultDragHandles: false`, and `Material` layout in options modal.
  - `test/widgets/quiet_adaptive_modal_test.dart`: Added widget tests for `anchorContext` resolution with `PopoverAlignment.end` and `PopoverAlignment.start`.
  - `test/tags/tag_ui_test.dart`: Added widget test verifying 3-dot options button opens popover anchored directly beneath the button.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/widgets/context_popover_test.dart test/widgets/quiet_adaptive_modal_test.dart test/tags/tag_ui_test.dart`: **20/20 tests passed**.
- Full test suite verified.

---

## 202. Notes List Thumbnail Caching & Fast Scrolling Optimization (October 2026)

### 1. Issue Overview & Root Cause Analysis
- **Problem**: When rapidly scrolling or flinging through the notes list, the UI stuttered and dropped frames ("jank"). When scrolling back and forth, thumbnail previews constantly re-rendered and flashed placeholders instead of persisting smoothly in memory.
- **Root Cause Investigation**:
  1. **Disposal of Offscreen Tiles on Scroll**:
     - `ListView.builder` in [`lib/features/notes/presentation/notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart) used Flutter's default `cacheExtent` of 250px (~2-3 note tiles). Items scrolling slightly offscreen were immediately unmounted and destroyed.
  2. **Lack of Keep-Alive in `NoteThumbnailView`**:
     - [`NoteThumbnailView`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_thumbnail_view.dart) did not implement `AutomaticKeepAliveClientMixin`. As a result, when a tile scrolled out of view and back into view, the thumbnail widget was recreated from scratch, running `initState` and re-rendering repeatedly.
  3. **Full-Resolution Image Decoding Bloat**:
     - In [`NoteThumbnailView.build`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_thumbnail_view.dart), `Image.memory` and `Image.network` lacked `cacheWidth` and `cacheHeight` constraints. When a user attached high-resolution camera photos (e.g., 12MP–48MP images, 4000x3000px), Flutter decoded the entire 48MB raw uncompressed bitmap into RAM for a 48x48dp display thumbnail.
     - Just 2–3 full-size images exceeded Flutter's 100MB internal `ImageCache`, triggering constant cache evictions and 30–100ms CPU image decoding freezes on the UI/raster thread.
  4. **Redundant Failing Variant Lookups**:
     - `_loadThumbnail()` first requested `service.resolveAsset(assetId, variant: 'thumbnail')`. Since Quiet Paper stores `'original'`, this lookup always failed, incurring wasted database and filesystem checks before falling back to `'original'`.
  5. **No In-Flight Request Deduplication**:
     - Fast scrolling through multiple notes triggered duplicate concurrent disk reads, decryptions, and native PDF rasterizations on the UI thread without deduplication.
  6. **Expensive String Hashing in Cache Keys**:
     - `NoteMetadataExtractor._computeCacheKey` computed `note.content.hashCode` across the entire body of large notes during every build.

### 2. Solution & Architectural Enhancements
1. **Centralized In-Memory `NoteThumbnailCache` Service ([`lib/features/notes/presentation/widgets/note_thumbnail_view.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_thumbnail_view.dart))**:
   - Replaced loose top-level cache maps with `NoteThumbnailCache`:
     - LRU-bounded cache (up to 500 entries) storing rasterized PDF page-0 PNGs and decrypted image assets.
     - Synchronous instant retrieval (`get(uri)`) to eliminate placeholder flashing.
     - In-flight `Future<Uint8List?>` deduplication (`resolve(uri, loader)`) ensuring concurrent requests for the same URI share a single task.
     - Background pre-warming (`NoteThumbnailCache.prewarm(...)`) to prime upcoming thumbnails ahead of user scroll.
2. **Preserved Widget State via `AutomaticKeepAliveClientMixin` ([`lib/features/notes/presentation/widgets/note_thumbnail_view.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/widgets/note_thumbnail_view.dart))**:
   - `_NoteThumbnailViewState` now mixes in `AutomaticKeepAliveClientMixin` with `wantKeepAlive => true`.
   - When note tiles scroll offscreen, their thumbnail elements and textures remain preserved in memory, completely eliminating rebuilds and re-loads when scrolling back.
3. **Constrained Image Decoding Dimensions**:
   - Dynamically computes pixel decode dimensions: `(widget.size * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.5)).round().clamp(96, 240)` (~120–144px).
   - Applied `cacheWidth` and `cacheHeight` on `Image.memory` and `Image.network`.
   - Constrains decoded RGBA textures to ~80KB per thumbnail (down from ~48MB, a >90% memory reduction), fitting hundreds of thumbnails in Flutter's `ImageCache` without evictions.
4. **Optimized Asset Variant Lookup**:
   - Direct resolution of `variant: 'original'`, avoiding failing `'thumbnail'` queries and cutting filesystem/DB overhead in half.
5. **Scroll Cache Extent & Pre-warming ([`lib/features/notes/presentation/notes_screen.dart`](file:///home/dog/git/quitepaper/lib/features/notes/presentation/notes_screen.dart))**:
   - Configured `scrollCacheExtent: const ScrollCacheExtent.pixels(1200.0)` in both phone and tablet layouts, ensuring ~10–15 tiles are prepared offscreen in advance.
   - Added post-frame thumbnail pre-warming when notes collections update.
6. **Fast O(1) Cache Key Generation ([`lib/features/notes/domain/note_metadata_extractor.dart`](file:///home/dog/git/quitepaper/lib/features/notes/domain/note_metadata_extractor.dart))**:
   - Replaced `note.content.hashCode` with `note.content.length` in `_computeCacheKey`.

### 3. File Inventory
- **Modified Files**:
  - `lib/features/notes/presentation/widgets/note_thumbnail_view.dart`: Implemented `NoteThumbnailCache` with LRU bounds, request deduplication, pre-warming, `AutomaticKeepAliveClientMixin`, downscaled `cacheWidth`/`cacheHeight`, and direct variant resolution.
  - `lib/features/notes/domain/note_metadata_extractor.dart`: Optimized `_computeCacheKey` to use `content.length` for O(1) key generation.
  - `lib/features/notes/presentation/notes_screen.dart`: Configured `scrollCacheExtent` (1200px) on both phone and tablet `ListView.builder`s and added `_prewarmThumbnails`.
  - `test/notes/notes_list_redesign_test.dart`: Added unit and widget tests for `NoteThumbnailCache`, request deduplication, LRU capacity, keep-alive, and downscaled image decode constraints.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **2012 tests passed**.

---

## 203. In-Place Pull-Down to Search Unveil & Zero-Lag Transition (October 2026)

### 1. Problem & Motivation
When pulling down to search at the top of the notes list, users previously experienced a jarring visual mismatch and a noticeable time gap:
1. **Time gap / Lag feel**: Upon releasing the finger past the threshold, the old implementation began a 280ms spring animation snapping the notes list back UP to offset 0 (hiding the revealed bar), while concurrently pushing `SearchPageRoute` (which had a 260ms fade-in and slide-down transition). This resulted in an awkward snap-shut pause followed by a delayed screen transition.
2. **Visual Disconnect**: The preview bar shown during the pull was a miniature 44dp proxy widget with a scale animation, custom borders, shadow, and a "Release" badge chip at `top: 0`, whereas the actual search page sat below a 56dp AppBar and a large 30sp "Search" title, with a 50dp search field located ~130dp down the screen with different borders and no shadow.
3. **Broken Mental Model**: The interaction did not feel like sliding down the notes list physically unveiled the search view resting directly behind it.

### 2. Architectural Solution
1. **In-Place Search View Underlay (`PullDownSearchReveal`)**:
   - `PullDownSearchReveal` supports an in-place `SearchViewBuilder` placed in a `Stack` directly behind the sliding content.
   - During the pull-down gesture (`_pullOffset > 0`), the full `SearchScreen` header block (AppBar with Back and New Note buttons + large editorial "Search" title + 50dp search bar) sits stationary behind the sliding notes list.
   - Sliding down the notes list physically unveils the exact search interface that rests behind it.
2. **"Card Sliding from a Deck" Gesture Dynamics**:
   - Direct 1:1 finger tracking: Rather than an artificial ceiling (previously 180dp) with decaying rubber-band resistance, pulling down on the notes list translates the card 1:1 with finger travel up to viewport height. The content never gets stuck or hits an unnatural wall.
   - Bidirectional finger tracking: If the user changes direction mid-drag and slides their finger upwards (`delta < 0`), the notes list tracks the upward finger movement 1:1 back towards the top.
   - Gesture Cancellation on Upward Return: If the card is pushed back up below `effectiveThreshold` (120dp), `isPastThreshold` reverts to false and the tactile haptic state resets. Releasing below threshold (or after pushing the card fully back) smoothly springs the notes list back to 0 without opening search.
3. **Zero-Lag Slide Transition on Commit**:
   - When releasing past `effectiveThreshold` (120dp), the notes list continues sliding smoothly off-screen (`_slideController` translates from `_pullOffset` to viewport height over 240ms with `Curves.easeOutCubic`).
   - `SearchScreen` takes full view in-place and search input receives immediate focus (`_searchFocusNode.requestFocus()`) with zero route delay.
4. **Tactile & Visual Feedback**:
   - When `_pullOffset >= effectiveThreshold`, a light haptic tick (`HapticFeedback.lightImpact()`) triggers. If pulled back below threshold, `_hasTriggeredHaptic` resets so re-crossing threshold delivers consistent feedback.
   - The search field's border illuminates with an accent border glow (`colors.accent.withValues(alpha: 0.6)`) and soft shadow while past threshold.
5. **Clean Dismissal**:
   - Tapping Back (`←`) on `SearchScreen` or triggering the Android system back gesture (`PopScope`) reverses `_slideController`, smoothly sliding the notes list back up from off-screen to `y = 0`.
   - Releasing before the threshold smoothly springs the notes list back up to resting position.
6. **Universal Tablet & Phone Integration**:
   - On phone: Unveils full-screen search view under the phone Scaffold.
   - On tablet: Preserves `const ValueKey('tablet_notes_list')` for AnimatedSwitcher and unveils `SearchScreen` inside the middle pane, allowing note selection directly into the right editor pane.
   - In editor: Preserves the compact inline find-in-note preview bar (`hintText: 'Find in note'`).

### 3. File Inventory
- **Modified Files**:
  - `lib/features/notes/presentation/widgets/pull_down_search_reveal.dart`: Added `searchViewBuilder`, `onStateCreated`, `_slideController` for continuous slide-down on commit, `openSearch()`, `closeSearch()`, 1:1 card-deck tracking without 180dp cap, upward delta handling, and threshold cancellation.
  - `lib/features/search/presentation/search_screen.dart`: Added `onClose`, `isPastThreshold` (accent glow), `autoFocus`, and `onNoteSelected` callbacks.
  - `lib/features/notes/presentation/notes_screen.dart`: Wired `_phonePullDownState` and `_tabletPullDownState`, passed `searchViewBuilder` with `SearchScreen`, wrapped phone and tablet layouts in `PopScope` for back dismissal, and routed `_openSearchScreen` through `openSearch()`.
  - `test/features/notes/gestures_test.dart`: Added tests verifying that tapping Back dismisses search, that dragging down past threshold then dragging back up below threshold cancels search, and that dragging down past 180dp tracks 1:1 without sticking.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/features/notes/gestures_test.dart`: All **12 gesture tests passed**.
- `flutter test test/search/`: All **60 search tests passed**.
- `flutter test test/tags/tag_workspace_navigation_test.dart`: All **9 tests passed**.















---

## 204. Note List Thumbnail Preview Persistent Disk Cache Across App Restarts (October 2026)

### 1. Problem & Motivation
While Section 202 introduced the in-memory L1 LRU thumbnail cache and keep-alive mixin to prevent re-fetching during continuous fast scrolling, previews were lost when terminating the application process or closing the app from the recents menu. On the subsequent cold start:
1. Every PDF note had to re-invoke `Printing.raster` on its first page, consuming 200–500ms of CPU time per document and causing visible thumbnail loading spinners/flickering.
2. Encrypted asset attachments had to re-query the SQLite database, read encrypted files from disk, and perform XChaCha20-Poly1305 decryption all over again.
3. Rapid scrolling immediately after launching the app experienced thumbnail loading delays until each thumbnail was lazily regenerated.

### 2. Architectural Solution
1. **Two-Tiered Hybrid Cache (`NoteThumbnailCache`)**:
   - **L1 In-Memory LRU Cache**: Retains up to 500 thumbnail byte arrays in a `LinkedHashMap<String, Uint8List>` for instantaneous 0ms frame-1 UI display during the active session.
   - **L2 Persistent Disk Cache**: Automatically persists rendered thumbnail byte binaries into the app's local data storage directory (`<app_data>/thumbnails/<sha256(uri)>.thumb`).
2. **Deterministic & Safe Disk Keying**:
   - Raw thumbnail source URIs (such as `qp://document/<uuid>` or `qp://asset/<uuid>`) are hashed using SHA-256 (`crypto.sha256.convert(utf8.encode(uri))`).
   - Generates safe, uniform filenames (`<hash>.thumb`) without special characters, illegal path separators, or operating system filename length constraints.
3. **Atomic Disk Writes**:
   - Disk writes write first to a `.tmp` file (`<hash>.thumb.tmp`) before performing an atomic `renameSync` to the final destination file, preventing partially written or corrupted thumbnail files if the app process is terminated during a write.
4. **Transparent Resolution Hierarchy (`NoteThumbnailCache.resolve`)**:
   - Step 1: Check L1 memory cache. Return immediately if present.
   - Step 2: Check L2 disk cache asynchronously (`readFromDisk(uri)`). If found, populate L1 memory cache and return.
   - Step 3: On a cache miss, invoke the provided `loader()`. Store the resulting byte array in both L1 RAM and L2 disk asynchronously, and return the resolved bytes.
5. **Vault Erase & Cache Purging Integration**:
   - `NoteThumbnailCache.clear({bool clearDisk = true})` purges both the in-memory LRU map and asynchronously deletes the `thumbnails` directory on disk.
   - `NoteThumbnailCache.evict(String uri)` evicts a specific thumbnail from both memory and disk.
   - Integrated into [`VaultEraseService`](file:///home/dog/git/quitepaper/lib/core/vault/vault_erase_service.dart) to ensure all cached thumbnail image previews on disk are wiped clean when the user erases local vaults or resets data.
6. **Isolated Testing Support**:
   - Exposed `@visibleForTesting static Directory? customDirectory` allowing automated unit tests to operate within an isolated `Directory.systemTemp` sandbox with zero interference with host storage or subsequent test runs.

### 3. File Inventory
- **Modified Files**:
  - `lib/features/notes/presentation/widgets/note_thumbnail_view.dart`: Added persistent L2 disk cache logic (`getThumbnailsDirectory`, `readFromDisk`, `writeToDisk`, `evict`, `resolve`, atomic `.tmp` writes, and SHA-256 filename hashing).
  - `lib/core/vault/vault_erase_service.dart`: Added deletion of the persistent `thumbnails` folder and invoked `NoteThumbnailCache.clear(clearDisk: true)` on vault erase.
  - `test/notes/notes_list_redesign_test.dart`: Added unit tests verifying persistent disk restoration across memory clears and disk eviction.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **2017 tests passed**.

---

## 205. Super Editor Link Preview Loading Animation & Failure Diagnostics with Settings Debug Toggle (October 2026)

### 1. Problem & Motivation
Super Editor link preview cards previously lacked real-time loading feedback when fetching metadata, OpenGraph tags, and lead image thumbnails from external URLs. If fetching failed due to network timeouts, HTTP errors (404, 403, 500), DNS lookup failures, or unparseable HTML payloads, users were left without clear context or actionable recovery options. Furthermore, developers and users troubleshooting failing links had no access to diagnostic telemetry (such as HTTP response codes, redirect chains, fetch stage durations, or raw exceptions), and there was no mechanism to disable verbose technical diagnostics in favor of a quiet editorial presentation.

### 2. Architectural Solution
1. **Diagnostic Telemetry Model (`LinkFetchDiagnostics` & `LinkBakeResult`)**:
   - Defined `enum LinkFetchStage` with user-friendly display labels: `dns`, `connect`, `tlsHandshake`, `headers`, `bodyDownload`, `htmlParse`, `metadataExtract`, `thumbnailDownload`, `thumbnailEncrypt`, `complete`.
   - `LinkFetchDiagnostics` encapsulates:
     - Target `url` and formatted ISO-8601 `timestamp`.
     - Failure `stage`.
     - `httpStatusCode` (e.g. 404, 500) and `httpStatusMessage`.
     - `contentType` and redirect destination (`resolvedRedirectUri`).
     - Network / parsing elapsed `duration`.
     - `rawException` and list of non-fatal warnings / thumbnail errors (`errors`).
     - Structured export via `toFormattedReport()` formatted for easy copy-pasting to bug trackers.
   - `LinkBakeResult` cleanly separates successful `metadata` from captured `diagnostics`.

2. **Instrumented Baker (`LinkPreviewBaker.bakeUrlWithDiagnostics`)**:
   - Enhanced `LinkPreviewBaker` with `bakeUrlWithDiagnostics(String url, {String? noteId})`, tracking elapsed time with `Stopwatch` and capturing stage transitions.
   - `_getWithRedirectsDetailed` follows redirects up to 5 hops, recording the final URI and handling network errors with `_friendlyNetworkError` to provide human-readable explanations.
   - `_bakeThumbnailWithDiagnostics` isolates image download and XChaCha20-Poly1305 encryption failures without discarding successfully parsed metadata.

3. **Settings Debug Toggle & State Management**:
   - Created `LinkPreviewDebugNotifier` (`linkPreviewDebugProvider`) in `settings_provider.dart`, persisted in `SharedPreferences` under key `'app_link_preview_debug'` (default: `true`).
   - Added a dedicated "Debug" section to `SettingsScreen` featuring a `CupertinoSwitch` for "Link preview debug info" with an explanatory caption.

4. **Warm Editorial Shimmer Loading Card (`LinkPreviewLoadingCard`)**:
   - Implemented an animated skeleton preview card matching Quiet Paper's warm editorial palette (`#F7F6F2` Light / `#1D1C1A` Dark).
   - Driven by a looping `CurvedAnimation` controller with smooth linear gradient shimmer over placeholder bars (host domain, title, and description).
   - Embedded a miniature progress spinner and favicon/link icon placeholder for responsive, non-jarring document layout.

5. **Detailed Failure Diagnostics Card (`LinkPreviewDebugCard`)**:
   - Renders a quiet editorial error card featuring:
     - Domain host and failure stage pill badge.
     - HTTP status code badge (e.g., `404 Not Found`).
     - Total elapsed duration (e.g., `340ms`).
     - Human-readable error message.
     - Collapsible "Technical Details" accordion displaying raw exception, content-type, final redirect URI, and thumbnail errors.
     - Interactive action bar:
       - **Retry**: Re-initiates metadata baking.
       - **Copy Info**: Copies the formatted diagnostics report to the system clipboard with an animated SnackBar confirmation.
       - **Plain Link**: Converts the block node back to an inline markdown link (`[title](url)`).
       - **Remove**: Deletes the link preview block node from the document.
   - If the debug setting is toggled off (`linkPreviewDebugProvider == false`), the card presents a clean, minimalist fallback view without technical internals.

6. **Super Editor In-Situ Node Lifecycle**:
   - Extended `LinkPreviewNode` with `LinkPreviewStatus { loaded, loading, failed }` and attached `LinkFetchDiagnostics?`.
   - Updated `LinkPreviewNodeSerializer`: emits markdown comments `<!-- qp-link-preview: ... -->` **only** when `status == LinkPreviewStatus.loaded`. Nodes in `loading` or `failed` state serialize as standard `[title](url)` links, preventing corrupted sentinel comments from contaminating markdown storage, exports, or encrypted sync payloads.
   - Updated `promoteLinkPreviewNodes(document, promoteUnbaked: true)` and `QuietSuperEditorController.insertLinkPreview` to insert unbaked URLs directly as in-situ `LinkPreviewNode(status: loading)`, eliminating document flashing and cursor disruption.
   - `QuietLinkPreviewComponent` acts as a reactive `ConsumerStatefulWidget`, automatically initiating baking on mount when in `loading` status and seamlessly transitioning to `loaded` or `failed`.

### 3. File Inventory
- **New Files**:
  - `lib/core/web_clipper/link_fetch_diagnostics.dart`: Diagnostic data structures, stage enum, and formatting helpers.
  - `lib/features/editor/presentation/widgets/super_editor/link_preview_loading_card.dart`: Shimmer skeleton loading widget.
  - `lib/features/editor/presentation/widgets/super_editor/link_preview_debug_card.dart`: Failure diagnostics card with debug accordion and action bar.
  - `test/core/web_clipper/link_fetch_diagnostics_test.dart`: Unit tests for diagnostics model and reports.
  - `test/editor/link_preview_loading_and_debug_test.dart`: Widget and integration tests for loading card, debug card, settings toggle, component lifecycle, and serialization invariants.
- **Modified Files**:
  - `lib/core/web_clipper/link_preview_baker.dart`: Added `bakeUrlWithDiagnostics` and stage tracking.
  - `lib/features/settings/application/settings_provider.dart`: Added `linkPreviewDebugProvider`.
  - `lib/features/settings/presentation/settings_screen.dart`: Added Debug section with toggle switch.
  - `lib/features/editor/presentation/widgets/super_editor/quiet_link_preview_component.dart`: Added `LinkPreviewStatus`, diagnostics integration, in-situ fetch execution, and fallback views.
  - `lib/features/editor/application/quiet_super_editor_controller.dart`: Added `insertLinkPreview` helper.
  - `lib/features/editor/presentation/widgets/quiet_super_editor.dart`: Integrated `promoteUnbaked: true`.
  - `lib/features/editor/presentation/editor_screen.dart`: Updated link paste handling to insert in-situ loading previews.
  - `test/core/web_clipper/link_preview_baker_test.dart`: Extended with comprehensive diagnostic tests.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **2,036 tests passed** (including 28 Super Editor tests, 18 link preview baker tests, 18 round-trip tests, and 10 link preview loading & debug tests).

---

## 206. Mobile Overflow Menu Surface Background & Adaptive Modal Popover Styling (October 2026)

### 1. Problem & Motivation
When tapping the 3-dot overflow menu in the note editor on touch/mobile devices (Android/iOS), the bottom sheet rendered with an almost completely transparent background:
1. Only the 3 quick-action cards at the top (**Pin**, **Archive**, **Delete**) displayed solid container backgrounds (`colors.surfaceSecondary`).
2. The rest of the sheet—including the drag handle, horizontal divider, and all navigation rows (**Find in note**, **Add tag**, **Share**, **Privacy**, **Edit Visually**, **Editor style**, and **Note details**)—rendered directly over the transparent canvas on top of the darkened modal barrier (`Colors.black54`).
3. Typography and icons with secondary/tertiary colors appeared faint, ghost-like, and nearly illegible against the dimmed background.
4. **Root Cause**: In `QuietAdaptiveModal.show`, mobile presentations (`!isDesktop`) delegated to `showModalBottomSheet` with hardcoded `backgroundColor: Colors.transparent`. While desktop popovers (`showQuietPopover`) automatically wrapped children in `Material(color: colors.surface, ...)`, the mobile branch lacked default surface styling, assuming every child widget would draw its own enclosed container.

### 2. Architectural Solution
1. **Adaptive Modal Popover Surface Default (`QuietAdaptiveModal.show`)**:
   - Added optional `backgroundColor`, `shape`, and `showDragHandle` parameters to `QuietAdaptiveModal.show`.
   - On mobile platforms (`!isDesktop`), when `type == AdaptiveModalType.popover`, automatically defaults:
     - `backgroundColor` to `context.appColors.surface` (solid `#FBFAF7` in Light Paper / `#252422` in Dark Paper).
     - `shape` to `RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: AppRadii.rLg))`.
     - `clipBehavior` to `Clip.antiAlias`.
   - For `AdaptiveModalType.dialog` (e.g., custom sheets with self-contained constrained cards like `NotesSortSheet`, `NotesFilterSheet`, `ExportNoteSheet`), retains `Colors.transparent` default background so existing custom layouts remain intact.
2. **Desktop Popover Parameter Propagation (`showQuietPopover`)**:
   - Extended `showQuietPopover` and `QuietPopoverRoute` to accept optional `backgroundColor`, allowing custom background overrides while defaulting to `colors.surface`.
3. **Editor Overflow Menu Integration (`_showOverflowMenu`)**:
   - Explicitly configured `_showOverflowMenu` in `editor_screen.dart` with `backgroundColor: colors.surface`, ensuring an opaque, warm editorial sheet backdrop across all screen densities and themes.
4. **Automated Verification**:
   - Added widget tests in `test/widgets/quiet_adaptive_modal_test.dart` verifying that `AdaptiveModalType.popover` on Android receives `colors.surface`, rounded vertical top borders, and anti-aliased clipping.
   - Added test in `test/editor/editor_overflow_menu_test.dart` ensuring the 3-dot overflow menu renders on an opaque surface `BottomSheet`.

### 3. File Inventory
- **Modified Files**:
  - `lib/core/widgets/quiet_adaptive_modal.dart`: Added `backgroundColor`, `shape`, and `showDragHandle` parameters; defaulted popovers on mobile to `colors.surface` and rounded top border.
  - `lib/core/widgets/quiet_popover.dart`: Added `backgroundColor` support in `showQuietPopover` and `QuietPopoverRoute`.
  - `lib/features/editor/presentation/editor_screen.dart`: Passed `backgroundColor: colors.surface` in `_showOverflowMenu`.
  - `test/widgets/quiet_adaptive_modal_test.dart`: Added tests verifying popover bottom sheet surface color and shape on Android.
  - `test/editor/editor_overflow_menu_test.dart`: Added test verifying 3-dot overflow menu renders on opaque `colors.surface` `BottomSheet`.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **2,039 tests passed**.

---

## 207. Manual Web Link Enhancement Trigger & Multi-Surface Title Automation (October 2026)

### 1. Problem & Motivation
Under the Link Enhancements specification (`docs/specs/link-enhancements-spec.md`), hyperlinks were intended to automatically resolve human-readable page titles and allow easy editing. However, users encountered several limitations:
1. **No Manual Trigger**: There was no way to manually trigger link title enhancement. If automatic title fetching did not trigger upon paste (e.g. background smart links disabled, offline, or older bare link text), users had no way to resolve or update the title without manually typing it.
2. **Redirect Failures in Title Fetcher**: `LinkTitleFetcher` strictly failed on HTTP 3xx redirect status codes (301, 302, 307, 308) because `http.Request` does not follow redirects across scheme boundaries (HTTP to HTTPS) or when location headers are relative, causing frequent title fetch failures on common web URLs. Furthermore, content-type checks rejected `application/xhtml+xml` and other HTML variants.
3. **Immutability of Edited Links**: `replaceLinkDisplayText` was strictly constrained to only replace text that exactly matched the raw URL (`link.title == link.url`). If a link text was ever previously edited, automated or manual enhancement attempts were ignored.
4. **Multi-Surface Paste Inconsistency**: When pasting links into Super Editor, pasted single URLs were routed solely to preview cards rather than inline link titles, preventing inline auto-title fetching from occurring.

### 2. Architectural Solution
1. **Redirect-Following & Resilient Title Fetcher (`LinkTitleFetcher`)**:
   - Implemented a resilient manual redirect resolution loop (supporting up to 5 consecutive hops) across 301, 302, 307, and 308 response codes.
   - Handles scheme transitions (e.g., `http://` to `https://`), relative `Location` URI resolution, and relaxed content-type matching (`text/html`, `application/xhtml+xml`, or any content-type containing `html`/`xml`).
2. **Dedicated Manual Enhancement Button (`LinkEnhanceButton`)**:
   - Created `LinkEnhanceButton`: A compact, editorial icon button displaying `PhosphorIconsRegular.sparkle` in idle state and transitioning to a micro `CircularProgressIndicator` while fetching.
   - Provides clear user feedback: success/failure snackbars (`Enhanced link: "Title"` or `Could not fetch title for link`), custom tooltip support, and dependency injection (`titleFetcher`) for testing.
3. **Link Dialog Manual Sparkle Trigger (`LinkPromptDialog`)**:
   - Added a sparkle suffix icon button to the `Link Text` input field in `LinkPromptDialog`.
   - Tapping the sparkle immediately fetches the title of the URL currently in the `URL` input field and populates the `Link Text` field with micro-spinner feedback.
4. **Forced Replacement Capability (`force: true`)**:
   - Added `bool force = false` parameter to `replaceLinkDisplayText` across `RichDocumentMutations`, `RichDocumentController`, and `QuietSuperEditorController`.
   - When triggered manually by explicit user action on the sparkle icon, `force: true` overrides the bare-URL constraint and updates the link display text regardless of prior edits.
5. **Multi-Surface Editor Integration**:
   - **WYSIWYG Editor (`_RichTextEditingController`)**: Appends an inline `WidgetSpan` containing `LinkEnhanceButton` directly after each web link run when `!readOnly`.
   - **Super Editor (`LinkEnhanceDocumentLayer` & `LinkEnhanceDocumentLayerBuilder`)**: Created an overlay layer computing precise bounding boxes using `documentLayout.getEdgeForPosition` for trailing edges of all `LinkAttribution` spans, floating interactive sparkle buttons.
   - **Markdown Preview (`WebLinkElementBuilder` & `LinkPreviewElementBuilder`)**: Registered custom element builders in `QuietMarkdownPreview` that render `LinkEnhanceButton` alongside web links when `onMarkdownChanged != null` and document is interactive, rewriting `[text](url)` to `[newTitle](url)` upon enhancement.
   - **Link Preview Block Syntax Guard (`LinkPreviewBlockSyntax.canParse`)**: Overrode `canParse` in `LinkPreviewBlockSyntax` to verify both the regex pattern AND the presence of a trailing `isLinkPreviewComment` sentinel. Previously, standard single-line markdown links without a sentinel matched `pattern`, causing `parse` to return `null` without advancing the parser and throwing a `BlockParser did not advance` assertion error in preview mode.
   - **Linux Desktop Build Hardening (`linux/CMakeLists.txt`)**: Added `-Wno-deprecated-literal-operator` to `APPLY_STANDARD_SETTINGS` to prevent third-party C++ header warnings from breaking builds as `-Werror`, and hardened `CMAKE_INSTALL_PREFIX` assignment against stale cache paths.
   - **Editor Screen (`editor_screen.dart`)**: Updated `_maybeInsertSmartWebLink` and `_fetchAndPatchLinkTitle` to reliably trigger title enhancement across Super Editor, WYSIWYG, and plain Markdown.

### 3. File Inventory
- **New Files**:
  - `lib/features/editor/presentation/widgets/link_enhance_button.dart`: Standalone link enhancement button with idle sparkle icon, micro-spinner, and feedback snackbars.
  - `lib/features/editor/presentation/widgets/super_editor/link_enhance_overlay.dart`: Super Editor document layout layer builder and stateful overlay for link enhancement buttons.
  - `test/editor/link_enhance_button_test.dart`: Widget test suite covering button states, dialog suffix trigger, and markdown preview integration.
- **Modified Files**:
  - `lib/core/web_clipper/link_title_fetcher.dart`: Added manual redirect loop (up to 5 hops, HTTP->HTTPS support) and relaxed content-type checks.
  - `lib/features/editor/application/rich_document_mutations.dart`: Added `force` parameter to `replaceLinkDisplayText`.
  - `lib/features/editor/application/rich_document_controller.dart`: Exposed `force` parameter on `replaceLinkDisplayText`.
  - `lib/features/editor/application/quiet_super_editor_controller.dart`: Added `force` parameter to `replaceLinkDisplayText`.
  - `lib/features/editor/presentation/widgets/link_prompt_dialog.dart`: Added sparkle suffix icon to Link Text field with auto-fetch and injectable `titleFetcher`.
  - `lib/features/editor/presentation/widgets/rich_text_editor.dart`: Appended `WidgetSpan` holding `LinkEnhanceButton` after web links.
  - `lib/features/editor/presentation/widgets/quiet_super_editor.dart`: Registered `LinkEnhanceDocumentLayerBuilder` in `documentOverlayBuilders`.
  - `lib/core/markdown/markdown_preview.dart`: Added `WebLinkElementBuilder`, updated `LinkPreviewElementBuilder`, fixed `LinkPreviewBlockSyntax.canParse`, wired `handleEnhanceWebLink` and `titleFetcher`.
  - `lib/features/editor/presentation/editor_screen.dart`: Updated `_maybeInsertSmartWebLink` and `_fetchAndPatchLinkTitle`.
  - `linux/CMakeLists.txt`: Added `-Wno-deprecated-literal-operator` and guarded `CMAKE_INSTALL_PREFIX`.
  - `test/core/web_clipper/link_title_fetcher_test.dart`: Added tests for 301/302 redirects and `application/xhtml+xml`.
  - `test/editor/web_link_enhancements_test.dart`: Added unit tests for `replaceLinkDisplayText` with `force: true`.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **2,047 tests passed** (including 6 link enhance widget and regression tests).

---

## 208. Resilient Secure Storage & Encrypted Local Fallback for Linux (Disabled KDE Wallet) (October 2026)

### 1. Problem & Motivation
On Linux desktop environments (e.g. Fedora with KDE Plasma, GNOME with disabled keyring, or minimalist window managers), users who disable KDE Wallet or lack an active Secret Service daemon (`org.freedesktop.secrets`) experienced session amnesia:
1. When signing in or unlocking the local vault, calls to `flutter_secure_storage`'s Linux plugin failed with `libsecret_error: Failed to unlock the keyring` / `The name is not activatable` / `PlatformException`.
2. `AuthService._saveUserSession`, `SecureKeyManager.setupNewKeys`, and `SecureKeyManager.storeWrappedKeyData` caught and discarded the platform exception.
3. Consequently, neither the user authentication session (`quietpaper_auth_session_v1`) nor the master encryption key (`quietpaper_master_key_v1` / `quietpaper_wrapped_master_key_v1`) were persisted to disk.
4. On every application launch, `AuthService.initialize()` and `SecureKeyManager.initialize()` failed to read the keys, resetting `_currentUser` to `null` and requiring the user to re-enter credentials and encryption passwords on every single launch.

### 2. Architectural Solution
1. **Resilient Secure Storage Wrapper (`QuietSecureStorage`)**:
   - Implemented `QuietSecureStorage extends FlutterSecureStorage` in `lib/core/storage/quiet_secure_storage.dart`.
   - On all operations (`read`, `write`, `delete`, `deleteAll`, `containsKey`, `readAll`), `QuietSecureStorage` first attempts to delegate to the platform's native secure storage (e.g. Android Keystore, iOS Keychain, macOS Keychain, Linux Secret Service).
   - If the platform secure storage throws an error (e.g. `PlatformException` with `Libsecret error: Failed to unlock the keyring` or `The name is not activatable`), it transparently falls back to an encrypted, device-bound local store (`.secure_storage_fallback.enc`).
2. **Device & User-Bound AES-256-GCM Encryption**:
   - The fallback store is encrypted with AES-256-GCM using a cryptographically random 256-bit salt (`.secure_storage_key`) combined via SHA-256 with `/etc/machine-id` (systemd machine ID) and the local `$USER` username.
   - On Linux/macOS, strict POSIX permissions (`0600`, read/write by the current user only) are applied to both `.secure_storage_key` and `.secure_storage_fallback.enc`.
   - File writes are atomic (written to `.tmp` first, then atomically renamed) and serialized with an asynchronous lock to prevent concurrency corruption.
   - Decrypted entries are cached in memory for zero-overhead subsequent reads.
3. **Multi-Service Integration**:
   - Configured `FirebaseAuthService`, `SecureKeyManager`, and `BackupService` to default to `QuietSecureStorage`.
   - When platform secure storage is available, writes update platform storage and remove any stale fallback copies.
   - When platform secure storage is disabled or locked, credentials and keys persist securely and reliably across app restarts.

### 3. File Inventory
- **New Files**:
  - `lib/core/storage/quiet_secure_storage.dart`: Drop-in resilient `FlutterSecureStorage` wrapper with AES-256-GCM device-bound fallback.
  - `test/core/storage/quiet_secure_storage_test.dart`: Unit and integration test suite verifying fallback behavior under simulated keyring failure, disk encryption verification, and persistence across `FirebaseAuthService` and `SecureKeyManager` restarts.
- **Modified Files**:
  - `lib/core/auth/auth_service.dart`: Defaulted `_storage` to `QuietSecureStorage`.
  - `lib/core/crypto/key_manager.dart`: Defaulted `_storage` to `QuietSecureStorage`.
  - `lib/core/backup/backup_service.dart`: Defaulted `_secureStorage` to `QuietSecureStorage`.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All **34 targeted tests passed** (including 7 new `QuietSecureStorage` fallback tests, all crypto tests, and auth resiliency tests).

---

## 209. Ollama Grounding Parser: Clean Note Insertion & Desktop Live Text Selection (October 2026)

### 1. Problem & Motivation
When running local OCR on Linux / Desktop using Ollama and Vision-Language Models like DeepSeek-OCR:
1. **Machine Coordinate Clutter**: With the standard grounding transcription prompt (`<|grounding|>Convert the document to markdown.`), DeepSeek-OCR emits spatial bounding boxes: `<tag>[[ymin, xmin, ymax, xmax]]` (e.g. `image[[22, 127, 452, 646]]` and `text[[4, 641, 450, 789]]`). Because `OllamaOcrService` previously dumped the raw response directly into `plainText`, copying OCR text or clicking "Insert into Note" injected machine coordinates and empty image tags into user notes.
2. **Disabled Image Text Selection**: `OllamaOcrService` previously returned a single full-page `OcrBlock` with `lines: const []`. Because the desktop image viewer's Live Text selection layer (`_LiveTextLayer`) and painter (`_LiveTextPainter`) rely on iterating through `block.lines` and `line.words` to hit-test pointer gestures, dragging or tapping on images failed to select any text on Linux desktop.

### 2. Architectural Solution
1. **Dedicated Grounding Parser (`OllamaGroundingParser`)**:
   - Implemented `OllamaGroundingParser` in `lib/core/ocr/ollama_grounding_parser.dart` to parse grounded VLM responses into structured `ParsedOcrResult`.
   - Strips all `<tag>[[ymin, xmin, ymax, xmax]]` markers from `cleanPlainText`, leaving clean Markdown with math equations (`\( ... \)`) and Unicode/Hindi characters intact.
   - Converts 1000×1000 coordinate grids into normalized `NormalizedRect` bounding boxes using DeepSeek-OCR's canonical `[xmin, ymin, xmax, ymax]` (`x1, y1, x2, y2`) order: $x = \frac{\min(x1, x2)}{1000}$, $y = \frac{\min(y1, y2)}{1000}$, $w = \frac{|x2 - x1|}{1000}$, $h = \frac{|y2 - y1|}{1000}$.
   - Slices text blocks into `OcrLine`s and character-weighted `OcrWord`s, giving precise horizontal word targets for desktop Live Text interaction.
   - Extracts and records detected diagram bounding boxes (`detectedImages`) from `image[[...]]` tags.
2. **Backward-Compatible Non-Grounded Fallback**:
   - For standard Markdown responses without grounding tags (e.g. models like Llama-3.2-Vision or custom prompts), paragraph and line segmentation automatically populates blocks, lines, and words so Live Text selection remains functional.
3. **`OllamaOcrService` Integration & Timeout Adjustment**:
   - `OllamaOcrService.recognizePage` now parses raw responses with `OllamaGroundingParser.parse(rawText)`, passing `parsed.cleanPlainText` and `parsed.blocks` directly to `OcrPage`.
   - Increased default HTTP timeout from 45s to 180s (3 minutes) to accommodate cold-model loading and CPU-bound Vision-Language Model execution (e.g. 4.7 GB DeepSeek-OCR running via `llamacpp`).

### 3. File Inventory
- **New Files**:
  - `lib/core/ocr/ollama_grounding_parser.dart`: Pure-Dart grounding parser for DeepSeek-OCR / Ollama responses with coordinate normalization, tag stripping, and word geometry generation.
  - `test/ocr/ollama_grounding_parser_test.dart`: Comprehensive unit test suite verifying grounded tag stripping, LaTeX/Hindi preservation, line/word geometry, prefix text handling, non-grounded fallbacks, and empty responses.
- **Modified Files**:
  - `lib/core/ocr/ollama_ocr_service.dart`: Integrated `OllamaGroundingParser` and increased timeout to 180s.
  - `test/ocr/ollama_ocr_service_test.dart`: Updated assertions and added unit tests for grounded DeepSeek-OCR transcription.

### 4. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/ocr/`: **All 29 tests passing**.

---

## 210. Tag Sync: Fix SQLite Foreign Key Constraint Failure on Duplicate Tag Merge (`upsertSyncedTag`) (October 2026)

### 1. Problem & Motivation
When syncing tags created across multiple devices:
1. Because tags originate from `#hashtags` in Markdown, different devices independently generate different random UUIDs for the same tag name.
2. In [`upsertSyncedTag`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart#L2032), when reconciling a remote tag whose name matched a local tag with a different ID (`existingByName.id != id`), the method attempted to re-link notes by executing:
   ```dart
   into(noteTagsTable).insertOnConflictUpdate(NoteTagsTableCompanion.insert(noteId: row.noteId, tagId: id))
   ```
3. However, `id` had not yet been inserted into `tagsTable` (the insert occurred later in the transaction). Because Drift enforces SQLite foreign keys (`PRAGMA foreign_keys = ON;`), referencing `id` before inserting it into `tagsTable` immediately threw:
   ```text
   SqliteException(787): while executing statement, FOREIGN KEY constraint failed, constraint failed (code 787)
   Causing statement: INSERT INTO "note_tags" ("note_id", "tag_id") VALUES (?, ?) ...
   ```
4. This rolled back the transaction, leaving tags unmerged and generating repeating sync pull errors in logs.

### 2. Architectural Solution
1. **Ordered Constraint Resolution**:
   - In [`AppDatabase.upsertSyncedTag`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart#L2079):
     1. Temporarily rename `existingByName.name` to `${normalizedName}_merging_${existingByName.id}` to release `normalizedName` without violating `UNIQUE(name)`.
     2. Insert the canonical remote tag row (`id`, `normalizedName`) into `tagsTable` **first** so it exists to satisfy foreign key constraints.
     3. Iterate through `noteTagsTable` rows attached to `existingByName.id`, verify that each referenced `noteId` still exists in `notesTable`, and re-link them to `id`.
     4. Delete the temporary old tag row (which cascades and cleans up obsolete `note_tags`).
2. **Regression Test**:
   - Updated [`test/sync/tag_sync_test.dart`](file:///home/dog/git/quitepaper/test/sync/tag_sync_test.dart) to verify note tag re-linking without foreign key constraint errors when merging duplicate offline tag names.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/sync/`: **All 56 tests passing**.

---

## 211. DeepSeek-OCR Table Formatting & Native Markdown Table Conversion (October 2026)

### 1. Problem & Context
When running local DeepSeek-OCR / Ollama on structured documents containing tables (such as test score cards or financial statements):
1. With unconstrained prompt `<|grounding|>Convert the document to markdown.`, vision models frequently defaulted to raw `<table>` or HTML-like tokens without pipe syntax.
2. In some responses, cell tokens were grouped inside `<table>...</table>` without row or cell delimiters, or emitted as standard HTML `<table><tr><th>...` elements.
3. Because Quiet Paper's editor (`QuietSuperEditor`, `MarkdownTableView`, `MarkdownTableEditor`, `MarkdownTableParser`) and markdown preview (`QuietMarkdownPreview`) are strictly built around GitHub-Flavored Markdown (GFM) pipe tables (`| Col 1 | Col 2 |\n|---|---|\n| Val 1 | Val 2 |`), raw HTML `<table>` elements were not parsed into native table components or rendered cleanly.

### 2. Architectural Solution
1. **Instructed Pipe-Syntax Prompt in `OllamaOcrService`**:
   - In [`OllamaOcrService.defaultPrompt`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_service.dart#L28-L30):
     ```dart
     static const String defaultPrompt =
         '<|grounding|>Convert the document to markdown. Format all tables as standard Markdown tables using pipe syntax (| Col 1 | Col 2 |). Do not use HTML table tags.';
     ```
   - Made `prompt` customizable via the `OllamaOcrService` constructor (`this.prompt = defaultPrompt`) and threaded it to `/api/generate` requests.

2. **Automated HTML Table to GFM Pipe Converter in `OllamaGroundingParser`**:
   - Added [`convertHtmlTablesToMarkdown`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart#L45-L129):
     - Scans for `<table[^>]*>([\\s\\S]*?)<\\/table>` elements.
     - Parses table fragments with `package:html/parser.dart`.
     - Extracts headers and cell values across `<tr>`, `<th>`, and `<td>`, sanitizing newlines and escaping inner pipes (`\|`).
     - Formats standard GFM Markdown pipe tables with header rows, alignment dividers (`| --- | --- |`), and data rows.
     - Automatically handles edge cases: single-row tables, empty cells, and malformed/collapsed HTML5 foster-parented text nodes by cleanly stripping unusable `<table>` wrappers.
   - Applied table conversion to both grounded content blocks (`_parseGroundedResponse`) and non-grounded paragraphs (`_parseNonGroundedMarkdown`).
   - Ensured each table block is split line-by-line into `OcrLine` and `OcrWord` hierarchies so that Live Text overlays and visual selection work cleanly over table regions.

3. **Interoperability Validation**:
   - Added tests in [`test/ocr/ollama_grounding_parser_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_grounding_parser_test.dart) verifying that converted tables are immediately parsed by Quiet Paper's native [`MarkdownTableParser`](file:///home/dog/git/quitepaper/lib/features/editor/application/markdown_table_parser.dart) and rendered cleanly.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/ocr/`: **All 32 tests passing**.
- `flutter test test/editor/`: **All 563 tests passing**.

---

## 212. Ollama OCR: Fix Coordinate Clamping `ArgumentError: 0.005` & Defensive Plaintext Fallback (October 2026)

### 1. Problem & Root Cause
When running local DeepSeek-OCR / Ollama on document images:
1. DeepSeek-OCR emits grounded bounding boxes with integer coordinates on a 1000×1000 grid (`[[xmin, ymin, xmax, ymax]]`). For content or diagrams positioned near document edges (e.g. footers with $y \ge 996$, or right-edge text with $x \ge 996$), normalized coordinates approached $1.0$.
2. In [`OllamaGroundingParser._toNormalizedRect`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart#L369-L370), widths and heights were clamped using `clamp(0.005, 1.0 - normX)`. When `normX > 0.995`, `1.0 - normX < 0.005`. Because Dart's `num.clamp(lowerLimit, upperLimit)` strictly asserts `lowerLimit <= upperLimit`, passing a lower limit greater than upper limit immediately threw:
   ```text
   ArgumentError: Invalid argument(s): 0.005
   ```
3. A similar failure occurred in [`_createBlock`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart#L320-L324): short words in multi-word sentences were clamped up to `0.005`, causing cumulative `currentX` to advance past `0.995` and triggering `wordWidth.clamp(0.005, 1.0 - currentX)` with `lowerLimit > upperLimit`.
4. In [`_parseNonGroundedMarkdown`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart#L247), an artificial `0.02` lower bound on block heights caused documents with $>45$ paragraphs to exceed `1.0`, triggering `clamp(0.02, 1.0 - blockY)` with `Invalid argument(s): 0.02`.
5. When `OllamaGroundingParser.parse` threw `ArgumentError(0.005)`, [`DefaultOcrService`](file:///home/dog/git/quitepaper/lib/core/ocr/ocr_service.dart#L86) logged:
   ```text
   [QuietPaper OCR] Ollama OCR failed or unavailable: Invalid argument(s): 0.005. Falling back to local CV.
   ```
   Because desktop platforms (Linux/macOS/Windows) lack Google ML Kit, the fallback CV pipeline produced 1 block and 0 characters, silently dropping over 1,200 recognized characters from DeepSeek-OCR.

### 2. Architectural Solution
1. **Safe Normalized Coordinate Rectangles (`OllamaGroundingParser._toNormalizedRect`)**:
   - Pre-normalize `normX1`, `normX2`, `normY1`, `normY2` into `[0.0, 1.0]`.
   - Calculate `normW = normX2 - normX1` and `normH = normY2 - normY1`.
   - For tiny or degenerate boxes ($< 0.005$), expand dimensions up to $0.005$ while shifting origin coordinates leftwards or upwards (`normX = (1.0 - normW).clamp(0.0, 1.0)`) so bounding boxes always remain inside `[0.0, 1.0]`.
   - Final rounded dimensions clamp safely against `1.0 - roundedOrigin` with lower limit `0.0`, eliminating any possibility of `lowerLimit > upperLimit`.
2. **Proportional Line and Word Layout (`OllamaGroundingParser._createBlock`)**:
   - Line heights and word widths are computed strictly proportional to their container bounds and character count fractions without artificial upward clamps.
   - Cumulative horizontal tracking (`currentX`) advances smoothly along the line, with each word's width clamped against `maxWordW = (1.0 - wordX).clamp(0.0, 1.0)`.
   - Guaranteed `roundedWordW > 0.0` for non-empty words when space is available.
3. **Responsive Non-Grounded Paragraph Layout (`_parseNonGroundedMarkdown`)**:
   - Paragraph height divides available space (`usableHeight / nonEmpties.length`) without an artificial minimum clamp, gracefully handling documents with arbitrarily large paragraph counts.
4. **Defensive Plaintext Recovery in `OllamaOcrService`**:
   - Wrapped `OllamaGroundingParser.parse(rawText)` in a `try / catch` block in [`OllamaOcrService.recognizePage`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_service.dart#L85-L101).
   - If an unexpected parsing error ever occurs on an anomalous model output, the service logs the error and gracefully falls back to returning the recognized plaintext with a full-page bounding box rather than dropping the recognized text or falling back to a 0-character local CV result.
5. **Regression Unit Tests**:
   - Added tests in [`test/ocr/ollama_grounding_parser_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_grounding_parser_test.dart) covering boundary coordinates ($x, y \ge 996$, $[1000, 1000, 1000, 1000]$), right-edge multi-word lines, and 60-paragraph non-grounded documents.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/ocr/`: **All 34 tests passing**.
- `flutter test`: **All 2,064 tests passing** with zero warnings or errors.

---

## 213. Ollama Live Text: Paragraph-Aware Visual Line & Word Partitioning (October 2026)

### 1. Problem & Root Cause
When inspecting OCR documents with the Live Text layer in the desktop image viewer:
1. DeepSeek-OCR / Ollama transcribes text blocks as standard Markdown paragraphs without hard visual line breaks (`\n`) for word wrapping (e.g. `text[[350, 380, 900, 630]]` followed by a 10-line, 550-character continuous string).
2. In [`OllamaGroundingParser._createBlock`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart), lines were previously derived purely by splitting on explicit newline characters (`text.split('\n')`).
3. For multi-line paragraphs containing no newline characters:
   - `rawParagraphs.length` evaluated to `1`.
   - `lineHeight` evaluated to `bounds.height` (the full height of all 10 lines combined, e.g. `0.25`).
   - All words in the entire paragraph (e.g. 100 words) were assigned to that single line, with `wordBounds.height = bounds.height` and `wordBounds.width` sliced into $\sim 1/100\text{th}$ of the container width ($\sim 0.005$).
4. This manifested visually as a dense "barcode fence" of tall, razor-thin vertical blue rectangles spanning the full height of the paragraph across the document, severely distorting Live Text hit-testing and word selection.

### 2. Architectural Solution
1. **Paragraph-Aware Visual Line Estimation**:
   - In `OllamaGroundingParser._createBlock`, each text paragraph computes its single-line character capacity based on container width (`singleLineCapacity = (wBox * 85).clamp(25.0, 100.0)`).
   - Paragraphs are partitioned into $L = \text{round}(C_p / \text{singleLineCapacity})$ visual lines. Single-line headings and formula lines remain as 1 line, while multi-line paragraphs cleanly wrap into their visual line count (e.g. 10-12 lines for 550 characters in a 0.55-width column).
2. **Greedy Word Wrapping**:
   - Words are wrapped into visual lines using target character capacity with 15% line-balancing flexibility and lookahead to ensure remaining lines are populated.
3. **Proportional Line & Word Geometry**:
   - Uniform line height is distributed across all visual lines (`bounds.height / totalLines`).
   - Words on line $j$ are assigned `wordBounds.y = lineBounds.y` and `wordBounds.height = lineBounds.height`, with horizontal bounds matching the word's position and width on that specific visual line.
4. **Regression Verification**:
   - Added unit tests in [`test/ocr/ollama_grounding_parser_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_grounding_parser_test.dart) verifying that 550-character continuous paragraphs wrap into distinct horizontal visual lines ($>8$ lines, each with height $< 0.04$) and properly stepped vertical $Y$ coordinates without vertical stripe distortion.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/ocr/`: **All 35 tests passing**.

---

## 214. Ollama Live Text: DeepSeek-OCR Prompt Canonicalization & Elimination of Tutorial Hallucinations (October 2026)

### 1. Problem & Root Cause
1. During document OCR processing with local Ollama (`DeepSeek-OCR-GGUF`), extraneous hallucinated text was appended or prepended to the OCR output:
   ```text
   For a complete guide on table syntax, see the [W3Schools](http://www.w3schools.com/table.asp) documentation. For more information on the Markdown syntax, see the [Markdown documentation](http://daringfireball.net/projects/markdown).
   ```
   None of this text was present in the scanned document image.
2. In commit `794983e`, [`OllamaOcrService.defaultPrompt`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_service.dart#L28) had been modified to:
   ```text
   <|grounding|>Convert the document to markdown. Format all tables as standard Markdown tables using pipe syntax (| Col 1 | Col 2 |). Do not use HTML table tags.
   ```
3. DeepSeek-OCR is a specialized vision-language grounding model fine-tuned on rigid special tokens (`<|grounding|>Convert the document to markdown.`). Injecting free-form conversational or imperative text instructions (`Format all tables as standard Markdown tables...`) triggers the model's language completion priors, causing it to produce explanatory web tutorial references (such as links to W3Schools and Daring Fireball) rather than strict grounded document transcription.
4. Furthermore, HTML `<table>` elements emitted by DeepSeek-OCR are already automatically parsed and converted into GitHub Flavored Markdown (GFM) pipe tables in pure Dart by [`OllamaGroundingParser.convertHtmlTablesToMarkdown`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_grounding_parser.dart#L286), making natural language table formatting prompts completely redundant.

### 2. Architectural Solution
1. **Restored Canonical DeepSeek-OCR Prompt**:
   - In [`OllamaOcrService.defaultPrompt`](file:///home/dog/git/quitepaper/lib/core/ocr/ollama_ocr_service.dart#L28), reverted the prompt to the exact official model preset:
     ```dart
     static const String defaultPrompt = '<|grounding|>Convert the document to markdown.';
     ```
   - This prevents conversational mode activation and completely eliminates hallucinated documentation and markdown tutorial links.
2. **Deterministic Downstream HTML-to-GFM Pipeline**:
   - Confirmed that all HTML table syntax conversions remain handled deterministically by `OllamaGroundingParser.convertHtmlTablesToMarkdown` and unit tests in `ollama_grounding_parser_test.dart`.
3. **Automated Verification**:
   - Added a regression test in [`test/ocr/ollama_ocr_service_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ollama_ocr_service_test.dart) asserting `OllamaOcrService.defaultPrompt` matches the canonical `<|grounding|>Convert the document to markdown.` token string without conversational instructions.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/ocr/`: **All 36 tests passing**.

---

## 215. Feature: Syncfusion Flutter PDF Viewer Migration with Non-Destructive Dual Storage (October 2026)

### 1. Context & Motivation
1. Previously, QuietPaper rendered PDFs by rasterizing each page to PNG bitmaps using `Printing.raster()` and displaying them within an `InteractiveViewer`. User annotations (freehand drawings) were recorded as screen coordinates in an `AnnotationOverlay` and baked into exported PDFs using `pdf/widgets.dart`.
2. This approach had critical limitations:
   - Text inside PDF documents could not be selected, copied, or highlighted natively.
   - Vector fidelity was degraded upon zooming rasterized images.
   - Annotations were limited to custom freehand drawing layers rather than industry-standard PDF annotation objects (`/Annots`).
3. The user requested migrating to `syncfusion_flutter_pdfviewer` on dedicated branch `feature/syncfusion-pdf-viewer`, preserving the original document completely untouched (non-destructive editing), providing native text selection, built-in PDF annotation tools (highlight, underline, strikethrough, squiggly, sticky notes), and export options for both original and annotated versions.

### 2. Architectural Design & Implementation

1. **Dependency Integration**:
   - Added `syncfusion_flutter_pdfviewer: ^33.2.13` to [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml).
   - Resolved dependencies cleanly with zero conflicts.

2. **Non-Destructive Dual Storage Invariant**:
   - The original encrypted PDF document file `<documentId>.qpd` is treated as immutable and is **never** overwritten by user annotation edits.
   - User annotations are bundled directly into a standard PDF byte stream via `PdfViewerController.saveDocument()` and persisted as a separate encrypted derivative file `<documentId>.annotated.qpd`.
   - In [`DocumentStorage`](file:///home/dog/git/quitepaper/lib/core/documents/document_storage.dart):
     - Added `saveEncryptedAnnotatedBytes`, `readEncryptedAnnotatedBytes`, `deleteEncryptedAnnotatedFile`, and `hasEncryptedAnnotatedFile`.
     - In-memory decrypted cache holds keys `annotated_$id` alongside original `$id` with independent cache invalidation.
   - In [`DocumentService`](file:///home/dog/git/quitepaper/lib/core/documents/document_service.dart):
     - `resolveAnnotatedBytes(id)`: Returns decrypted annotated bytes if available; falls back transparently to original document bytes.
     - `saveAnnotatedDocument(id, bytes)`: Encrypts and writes to `<documentId>.annotated.qpd` without mutating `<documentId>.qpd`.
     - `revertToOriginalDocument(id)`: Deletes `<documentId>.annotated.qpd` and evicts the annotated memory cache, safely reverting to the original unmodified document.
     - `deleteDocument(id)`: Cleans up both original and annotated files and metadata.

3. **Viewer & Annotation Experience (`DocumentViewerScreen`)**:
   - Replaced rasterized page list and `AnnotationOverlay` with `SfPdfViewer.memory(decryptedBytes, controller: _pdfViewerController, undoController: _undoController)`.
   - Zero-knowledge security is strictly maintained: `SfPdfViewer.memory` loads decrypted PDF bytes directly from memory without writing plaintext PDF files to disk.
   - Integrated full annotation toolbar:
     - Text markup: Highlight, Underline, Strikethrough, Squiggly.
     - Sticky Notes.
     - Active annotation mode banner with Undo, Redo, and Done controls.
   - Implemented non-destructive lifecycle:
     - Auto-saves annotations on screen pop / back navigation using `PopScope(onPopInvokedWithResult: ...)`.
     - Added manual Save action in the AppBar (`Icons.save_outlined`).
     - Added "Revert to Original Document" menu option with user confirmation modal.
     - Added dual export modal offering "Annotated PDF" and "Original Clean PDF" when saving to device or sharing.
     - Responsive title subtitle with `SingleChildScrollView(scrollDirection: Axis.horizontal)` to prevent flex overflow across all display widths.

4. **Automated Verification**:
   - Extended [`test/documents/document_service_test.dart`](file:///home/dog/git/quitepaper/test/documents/document_service_test.dart) with unit tests for:
     - Initial resolution fallback to original document bytes.
     - Saving annotated PDF without modifying original encrypted file.
     - Reverting annotated PDF to restore original bytes.
     - Cleanup of both original and annotated files upon document deletion.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All test suites passing.

---

## 216. Feature: Quiet Paper Custom Floating Text Selection Menu & In-Document PDF Search (October 2026)

### 1. Context & Motivation
1. After migrating to `syncfusion_flutter_pdfviewer` on `feature/syncfusion-pdf-viewer`, text selection triggered Syncfusion's default Material 3 context menu (a dark rectangular overlay with default styling and icons).
2. The user requested authentic **Quiet Paper styling** for the text selection experience.
3. User preferences aligned on:
   - Form Factor: **Floating Horizontal Pill** toolbar floating directly above or below the selected text.
   - Core Actions: **Copy**, **Highlight** (amber/gold markup), **Underline**, **Strike** (strikethrough), **Squiggly**, **Note** (add sticky note to selection), and **Search** (search selected text in document).

### 2. Architectural Design & Implementation

1. **Suppression of Default Context Menu**:
   - In [`DocumentViewerScreen`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/document_viewer_screen.dart), configured `SfPdfViewer.memory` with:
     - `canShowTextSelectionMenu: false`: Completely disables Syncfusion's internal dark overlay.
     - `enableTextSelection: true`: Retains high-performance native text selection and handles.
     - `onTextSelectionChanged: _handleTextSelectionChanged`: Receives selection updates with `globalSelectedRegion` and `selectedText`.

2. **Responsive Floating Pill Menu (`_showFloatingSelectionMenu`)**:
   - Rendered using an `OverlayEntry` directly inserted into `Overlay.of(context, rootOverlay: true)`, ensuring instantaneous rendering in global coordinates without waiting for widget subtree layout cycles.
   - Vertical collision detection: Floats 10dp above the selection if space permits (`top = region.top - 44 - 10`); flips smoothly below the selection if near top of viewport; clamped against screen boundaries.
   - Horizontal centering: Proportional alignment centered over `region.center.dx`, clamped safely within `[12, screenWidth - menuWidth - 12]`.
   - Aesthetics: Rounded pill (`BorderRadius.circular(24.0)`), warm editorial surface (`colors.surface`), 0.8dp divider border (`colors.divider`), and elevation shadows.
   - Horizontal scroll container: `SingleChildScrollView(scrollDirection: Axis.horizontal)` guarantees zero flex overflow across small phones (320-360dp) and desktop screens.
   - Actions provided:
     - **Copy**: Writes text to clipboard and displays confirmation toast.
     - **Highlight / Underline / Strike / Squiggly**: Fetches vector text line bounds from `SfPdfViewerState.getSelectedTextLines()` and creates standard PDF markup annotations.
     - **Note**: Opens a Quiet Paper modal dialog displaying a truncated quote of the selection with a text editor to attach a `StickyNoteAnnotation` anchored to the selected text.
     - **Search**: Triggers in-document text search with the selected query.

3. **Elimination of Bottom Sheet Overflow (`_showAnnotationToolsModal`)**:
   - Configured `showModalBottomSheet` with `isScrollControlled: true` and wrapped the content in a `SingleChildScrollView`.
   - Completely resolved the `BOTTOM OVERFLOWED BY 62 PIXELS` error shown on compact screen heights when invoking annotation tools from the AppBar.

4. **In-Document PDF Search Navigation (`_buildSearchBar`)**:
   - Invokes `PdfViewerController.searchText(query)` with live match notifications.
   - Renders a quiet editorial search bar docked below the AppBar with search term, match index (`"1 of 5"`), Previous (`keyboard_arrow_up_rounded`), Next (`keyboard_arrow_down_rounded`), and Close (`close_rounded`) controls.
   - Also integrated a "Search in Document" action inside the overflow menu (`more_vert_rounded`) with an interactive search prompt dialog.

5. **Automated Verification**:
   - Added widget test in [`test/documents/document_viewer_text_selection_test.dart`](file:///home/dog/git/quitepaper/test/documents/document_viewer_text_selection_test.dart) verifying document viewer rendering and search menu integration.
   - `flutter test test/documents/`: **All 56 tests passing**.
   - `flutter test test/scanner/scanner_ui_test.dart`: **All 3 tests passing**.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All test suites passing.

---

## 217. Migration: Syncfusion PDF Viewer Promoted to Main & Legacy Viewer Archived (`old-pdf-viewer`) (October 2026)

### 1. Context & Motivation
Following the successful implementation, text selection styling customization, and automated test verification of the Syncfusion PDF Viewer (`feature/syncfusion-pdf-viewer`), the feature branch was promoted to the canonical `main` branch. 

To ensure complete reversibility and reference integrity for the historical custom raster-based PDF rendering pipeline, the previous state of `main` (commit `05c2b98`) was preserved on branch `old-pdf-viewer`.

### 2. Branch Topology & Details
- **Archival Branch (`old-pdf-viewer`)**:
  - Pushed to `origin/old-pdf-viewer` at commit `05c2b98`.
  - Preserves the legacy custom PDF pipeline (`PdfPageRenderer`, custom vector overlay canvases, manual gesture pinch/zoom, and thumbnail strip).
- **Primary Branch (`main`)**:
  - Fast-forward merged with `feature/syncfusion-pdf-viewer` (commits `593c45d`, `d240276`, and `01247cc`).
  - Active native PDF engine: `syncfusion_flutter_pdfviewer` with non-destructive dual storage (`<docId>.qpd` and `<docId>.annotated.qpd`), floating horizontal pill text selection toolbar, in-document search, and zero-knowledge in-memory loading.

### 3. Verification & Quality
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test`: All tests passing.

---

## 218. Feature: Zero-Knowledge OCR Text Sync, Manual-Only Recognition Policy, and 3-Way Conflict Merge Pipeline (October 2026)

### 1. Context & Motivation
1. Previously, OCR extraction results for PDF documents (`document_ocr_pages`) and image attachments (`attachment_ocr_pages`) remained strictly local to the device that performed the scan or import. Consequently, searching for text within documents or attachments on a secondary synced device returned no matches unless OCR was manually triggered again on that device.
2. In addition, automatic OCR was prone to redundant re-processing whenever documents or attachments were touched.
3. The user established three core architectural requirements:
   - **Zero-Knowledge Cloud Synchronization**: OCR text must synchronize end-to-end encrypted across devices using XChaCha20-Poly1305 and the user's Master Key. The serverless backend must remain completely crypto-blind, storing and forwarding opaque encrypted payloads without possessing plaintext text or master keys.
   - **Manual-Only OCR Policy**: When a document or attachment already has OCR text (whether from local extraction or cloud sync), OCR must never automatically re-run. OCR only runs automatically on initial local scans/imports where no OCR data exists yet. Any re-processing must be explicitly initiated by the user via "Re-run OCR" (`force: true`).
   - **3-Way Diff3 Conflict Merge Pipeline**: OCR text sync conflicts must follow the same merge pipeline as notes:
     - Non-overlapping edits auto-merge cleanly via `MarkdownMergeEngine` (3-way diff3 merge).
     - When no common ancestor base revision is available, a synthesized virtual base is extracted via Longest Common Subsequence (`computeLcsBase`).
     - Overlapping collisions flag a `SyncConflict` record (`isOcr: true`) and route to the `ConflictResolutionScreen` for manual resolution ("Keep Mine", "Keep Server", or "Custom Merge"). "Keep Both" is hidden for OCR pages because pages cannot duplicate within a document.

### 2. Architecture & Implementation

#### A. Backend Architecture & Schema Migration (015)
1. **Schema Migration ([`backend/migrations/015_ocr_sync_and_conflicts_schema.sql`](file:///home/dog/git/quitepaper/backend/migrations/015_ocr_sync_and_conflicts_schema.sql))**:
   - Added `revision INTEGER NOT NULL DEFAULT 1`, `base_revision INTEGER`, `is_dirty INTEGER NOT NULL DEFAULT 0`, `is_deleted INTEGER NOT NULL DEFAULT 0`, and `updated_at DATETIME` to both `document_ocr_pages` and `attachment_ocr_pages`.
   - Created cursor tracking index and added migration `015` to [`backend/src/db/migrate.ts`](file:///home/dog/git/quitepaper/backend/src/db/migrate.ts).
   - Ensured `document_ocr_pages` schema alignment: `document_ocr_pages` uses `processed_at` and `updated_at`, safely adding `created_at TEXT` via migration while omitting it from `pushOcrPages` queries to guarantee compatibility across existing and new Turso instances.
2. **API Endpoints ([`backend/src/api/handler.ts`](file:///home/dog/git/quitepaper/backend/src/api/handler.ts) & [`backend/src/sync/syncService.ts`](file:///home/dog/git/quitepaper/backend/src/sync/syncService.ts))**:
   - `POST /api/v1/sync/ocr/push`: Validates `OcrPushPayloadSchema` (max 50 pages per batch). Enforces optimistic concurrency: if `baseRevision != null && baseRevision < serverRevision`, returns `status: 'conflict'` with current server payload, revision, and updated timestamp.
   - `GET /api/v1/sync/ocr/pull`: Validates cursor and limit (max 100). Returns ordered changes past cursor with updated global cursor and `hasMore` pagination.
3. **Backend Tests ([`backend/tests/ocr_sync.test.ts`](file:///home/dog/git/quitepaper/backend/tests/ocr_sync.test.ts))**:
   - Verified push, pull, cursor advancement, and revision conflict detection (122 tests passing across backend suite).

#### B. Client Drift Schema & DAOs (Schema v19)
1. **Schema Bump ([`lib/core/database/app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart))**:
   - Bumped `schemaVersion` to **19**.
   - Added `revision`, `baseRevision`, `isDirty`, `isDeleted`, and `updatedAt` to both `DocumentOcrPagesTable` and `AttachmentOcrPagesTable`.
   - SQLite migration constraint fix: in SQLite, `ALTER TABLE ... ADD COLUMN` strictly forbids non-constant default expressions (such as `CURRENT_TIMESTAMP` or `strftime(...)`). `updatedAt` was made a nullable `dateTime().nullable()()`, allowing clean `ADD COLUMN "updated_at" INTEGER;` execution during migration. Existing rows are safely backfilled from `processed_at` via an idempotent `UPDATE ... WHERE updated_at IS NULL`.
2. **DAO Methods**:
   - `getDirtyDocumentOcrPages()`, `getDirtyAttachmentOcrPages()`.
   - `markDocumentOcrPageSynced(docId, pageNumber, revision, updatedAt)`.
   - `markAttachmentOcrPageSynced(attId, pageNumber, revision, updatedAt)`.
   - `getAttachmentOcrPage(attId, pageNumber)`.
   - Added `ocr_sync_cursor` to `resetSyncCursors()` in `app_database.dart`.

#### C. Manual-Only OCR Execution Policy
1. **PDF Document OCR ([`lib/core/ocr/document_processing_service.dart`](file:///home/dog/git/quitepaper/lib/core/ocr/document_processing_service.dart))**:
   - In `processDocument({..., bool force = false})`: checks `db.getDocumentOcrPages(documentId)`.
   - If pages exist and `!force`, logs `Document <id> already has OCR text (<N> pages). Skipping automatic OCR.` and returns existing data immediately without invoking MLKit or Ollama.
2. **Image Attachment OCR ([`lib/core/attachments/attachment_processing_service.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/attachment_processing_service.dart))**:
   - In `processAttachment({..., bool force = false})`: checks `db.getAttachmentOcrPages(attachmentId)`.
   - If pages exist and `!force`, logs `Attachment <id> already has OCR text. Skipping automatic OCR.` and returns immediately.
3. **Automated Verification ([`test/ocr/ocr_manual_policy_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ocr_manual_policy_test.dart))**:
   - Unit tests confirm automatic OCR is skipped when OCR pages already exist and `force: false`, and executes properly when `force: true`.

#### D. Sync Engine & 3-Way Diff3 Conflict Merge
1. **Push Pipeline ([`lib/core/sync/sync_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart))**:
   - In `_pushDirtyOcrPages()`: gathers dirty pages from both tables, batches them as `OcrPageSyncPayload`, and sends to `apiClient.pushOcrPages()`.
   - Applied items are marked clean via `mark...Synced`.
   - Conflicted items are processed via `_processOcrPushConflicts()`.
2. **Diff3 Auto-Merge & Virtual LCS Base**:
   - Decrypts local payload and remote payload using `OcrCrypto`.
   - If local and remote plain text are identical or non-overlapping, `MarkdownMergeEngine.merge()` auto-resolves cleanly.
   - When no ancestor base is available (`base == null`), `computeLcsBase(local, remote)` in [`lib/core/sync/conflict/markdown_merge_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/conflict/markdown_merge_engine.dart) extracts the longest common subsequence of lines as a synthesized virtual base.
   - If clean merge succeeds: re-encrypts the merged text, saves to SQLite with updated `baseRevision = conflict.serverRevision`, and sets `isDirty = true` for the next push pass.
   - If overlapping collision occurs: constructs a `SyncConflict` record (`isOcr: true`, `extraData` with `resourceType`, `resourceId`, `pageNumber`, and `remoteEncryptedPayload`) and stores it in SQLite via `saveConflict()`.
   - `_ensureValidNoteId()` ensures foreign key validity against `NotesTable.id`.
3. **Pull Pipeline**:
   - In `_pullOcrPages()`: pulls changes past `ocr_sync_cursor`.
   - If local record is not dirty, applies remote payload directly and updates revision.
   - If local record is dirty with differing content, invokes the 3-way merge pipeline.
   - Invalidates `OcrSearchService` in-memory document/attachment cache immediately so search results reflect fresh synced text.

#### E. Conflict Resolution UI & Resolver
1. **Conflict Model ([`lib/core/sync/conflict/conflict_model.dart`](file:///home/dog/git/quitepaper/lib/core/sync/conflict/conflict_model.dart))**:
   - Added `extraData` map to `SyncConflict`.
   - Added `isOcrConflict` getter and dynamic `effectiveDisplayTitle` (`OCR: Page X (<doc/att title>)`).
2. **Conflict Resolver ([`lib/core/sync/conflict/conflict_resolver.dart`](file:///home/dog/git/quitepaper/lib/core/sync/conflict/conflict_resolver.dart))**:
   - Implemented `resolveOcrKeepMine`: keeps local OCR text, updates `baseRevision` to remote revision, marks `isDirty = true`, and deletes conflict record.
   - Implemented `resolveOcrKeepTheirs`: overwrites local page with remote encrypted payload, updates revision, marks `isDirty = false`, and deletes conflict record.
   - Implemented `resolveOcrManual`: takes user's edited plaintext, encrypts with Master Key, sets `baseRevision` to remote revision, marks `isDirty = true`, and deletes conflict record.
   - Routed seamlessly from `resolveKeepMine`, `resolveKeepTheirs`, and `resolveWithCustomMerge`.
3. **Conflict Resolution Screen ([`lib/features/sync/presentation/conflict_resolution_screen.dart`](file:///home/dog/git/quitepaper/lib/features/sync/presentation/conflict_resolution_screen.dart))**:
   - Hides the "Keep Both" button when `conflict.isOcrConflict` is true.
   - Hides the title editing field for OCR page conflicts (only body text is editable).
   - Tailored toast messages ("Local OCR text retained", "Remote OCR text accepted", "OCR text merged successfully").

### 3. Verification & Quality
- **Backend Quality**:
  - `npm test`: 19 test files, 122 tests passing (100%).
  - `npm run build`: Clean TypeScript compilation with zero errors.
- **Client Quality**:
  - `flutter analyze`: **0 issues found**.
  - `flutter test test/ocr/ocr_manual_policy_test.dart`: All tests passing.
  - `flutter test test/sync/ocr_sync_test.dart`: All 7 tests passing.
  - `flutter test test/sync/conflict_merge_engine_test.dart`: All 13 tests passing.
  - `flutter test test/journal/journal_database_test.dart`: All 9 tests passing.

---

## 219. Release Version Bump to 1.6.1 (Build 19) (October 2026)

### 1. Overview & Motivation
Bumped the official application version from `1.6.0+18` to `1.6.1+19` to package the accumulated editor, OCR, PDF-viewer, and sync fixes since the last release. The build suffix increments `versionCode` from `18` to `19`, so Android Package Manager and the in-app GitHub Releases update checker recognize the new build as an upgrade (CI additionally overrides the build number with the git commit count).

### 2. File Updates (per Section 17)
- [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml#L19): `version: 1.6.0+18` → `version: 1.6.1+19`.
- [`lib/core/version/app_version_provider.dart`](file:///home/dog/git/quitepaper/lib/core/version/app_version_provider.dart): `packageInfoProvider` fallback version and `appVersionInfoProvider` empty-string fallback updated to `'1.6.1'`; doc-comment examples refreshed.
- [`lib/main.dart`](file:///home/dog/git/quitepaper/lib/main.dart#L31): startup `PackageInfo` fallback updated to `'1.6.1'`.
- [`lib/core/location/location_service.dart`](file:///home/dog/git/quitepaper/lib/core/location/location_service.dart#L19): default `_appVersion` updated to `'1.6.1'`.
- [`lib/core/device/device_info_service.dart`](file:///home/dog/git/quitepaper/lib/core/device/device_info_service.dart#L28): default `appVersion` updated to `'1.6.1'`.
- [`lib/core/backup/backup_service.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart#L25): default `appVersion` updated to `'1.6.1'`.
- [`lib/core/journal/application/weather_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/weather_service.dart#L30): `User-Agent` updated to `QuitePaper/1.6.1`.
- [`lib/features/export/application/exporters/qpnote_exporter.dart`](file:///home/dog/git/quitepaper/lib/features/export/application/exporters/qpnote_exporter.dart#L12): default `_appVersion` updated to `'1.6.1'`.
- `update_provider.dart`, `backup_provider.dart`, and `settings_screen.dart` required no edits because they resolve the version dynamically via `appVersionInfoProvider` (`package_info_plus`).

### 3. Documentation
- Section 17's **App Version Bump Checklist** was refreshed: it now lists the actual current hardcoded fallback locations, notes which consumers read the version dynamically, and includes the mirrored public-site version badges.

### 4. Public Site Refresh
- Updated the version badge and footer to `v1.6.1` in [`public/index.html`](file:///home/dog/git/quitepaper/public/index.html) and the footers of [`public/changelog.html`](file:///home/dog/git/quitepaper/public/changelog.html), [`public/privacy.html`](file:///home/dog/git/quitepaper/public/privacy.html), and [`public/terms.html`](file:///home/dog/git/quitepaper/public/terms.html).
- Added the four missing release entries to the public changelog, newest first:
  - **1.6.1 (October 20, 2026)** — visual editor V5/RichDocument, Super Editor attachments, image compression, screenshot export, Syncfusion PDF viewer + annotations/search, zero-knowledge OCR sync + 3-way merge, desktop adaptive modals, Linux modernization, journal places, and Bengali support.
  - **1.6.0 (October 2, 2026)** — server-rendered public note sharing, in-app share client, branded OG cards, dynamic runtime versions, and commit-counted CI build numbers.
  - **1.5.9 (September 29, 2026)** — background-isolate attachment encryption with progress overlay, plus Linux clipboard file paste and drag-and-drop.
  - **1.5.8 (September 10, 2026)** — table caret stability, empty-list exit, `[[`/`#` autocomplete backspace fixes, and selection retention.
- Mirrored all four edited pages into `backend/public/` so both served copies remain byte-identical.

### 5. Verification & Quality
- Static analysis: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- Automated tests: `flutter test` (**full suite passing**).
- Repository sanity check: no remaining `1.6.0` app-version fallbacks outside `test/version/app_version_test.dart` (arbitrary fixture values) and `pubspec.lock` (third-party dependency version).

---

## 220. Adaptive Lower-Resolution OCR for Large PDF and Scanned Documents (October 2026)

### 1. Problem & Motivation
Prior to this enhancement, imported PDF documents exceeding 8 MiB or whose declared page dimensions exceeded 4 megapixels at 150 DPI unconditionally skipped on-device OCR (`ocrState: 'skipped'`). In the Document Viewer, the OCR action was disabled with tooltip *"OCR skipped for this large PDF"*, and manual retries were blocked with a toast.

In practice, scanned documents (contracts, receipts, books, multi-page paper scans) routinely exceed 8 MiB (often 10–50 MiB) because each page embeds high-resolution camera or scanner bitmaps. Bounding memory by completely abandoning OCR prevented full-text search and OCR text viewing for the very documents that needed it most.

### 2. Architectural Solution
1. **Adaptive Raster DPI Policy ([`lib/core/pdf/pdf_page_renderer.dart`](file:///home/dog/git/quitepaper/lib/core/pdf/pdf_page_renderer.dart))**:
   - Replaced the hard 8 MiB skip limit with an extreme memory safety ceiling of 100 MiB (`maxAllowedPdfBytes = 100 * 1024 * 1024`).
   - Added `PdfRasterPolicy.isLarge(bytes)` (`> 8 MiB`) and `PdfRasterPolicy.ocrDpi(bytes)`.
   - Small documents (< 8 MiB, standard page sizes) rasterize at high-fidelity `150.0 DPI` bounded by `safeDpi`.
   - Large documents (> 8 MiB or oversized page bounds) rasterize at lower-resolution `90.0 DPI` (yielding ~750x1050 px for A4), saving ~65% memory and CPU during native rendering.
   - Oversized page dimensions no longer skip OCR; `safeDpi` scales down DPI so that pixel budget per page is guaranteed $\le 4\text{ MP}$.
2. **Two-Stage Downscaling Pipeline ([`lib/core/image_processing/image_processor.dart`](file:///home/dog/git/quitepaper/lib/core/image_processing/image_processor.dart) & [`lib/core/ocr/ocr_service.dart`](file:///home/dog/git/quitepaper/lib/core/ocr/ocr_service.dart))**:
   - Added `maxDimension` parameter (default 1600px) to `ImageProcessor.enhanceForOcr`.
   - `DartImageProcessor.enhanceForOcr` clamps rendered bitmaps exceeding 1600px to max dimension 1600px before grayscale and adaptive binarization thresholding.
   - Binarization and ML Kit text recognition execute dramatically faster and consume minimal RAM.
   - Because bounding box coordinates in `OcrWord`, `OcrLine`, and `OcrBlock` are normalized ratios ($0.0 \dots 1.0$), scaling the bitmap uniformly preserves geometry and search highlighting on the original PDF pages.
   - `DefaultOcrService.recognizeDocument` and CV fallback automatically utilize `PdfRasterPolicy.ocrDpi` and 1600px dimension clamping.
3. **Background Document Processing Service ([`lib/core/ocr/document_processing_service.dart`](file:///home/dog/git/quitepaper/lib/core/ocr/document_processing_service.dart) & [`lib/core/documents/document_service.dart`](file:///home/dog/git/quitepaper/lib/core/documents/document_service.dart))**:
   - `processDocument` uses `PdfRasterPolicy.ocrDpi(pdfBytes)` to render each page at the adaptive resolution.
   - Processes multi-page documents page-by-page, periodically yielding to the event loop (`await Future.delayed(Duration.zero)`) every 2 pages to keep the UI thread responsive during long scans.
   - `DocumentService.saveDocument` enqueues background OCR for scanned documents without skipping.
4. **Document Viewer UI Unlocking ([`lib/core/documents/presentation/document_viewer_screen.dart`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/document_viewer_screen.dart))**:
   - Removed the guard in `_regenerateOcr` that blocked execution when `ocrState == 'skipped'`.
   - Unlocked the AppBar OCR button for previously skipped documents, providing tooltip `"Run OCR (adaptive resolution)"`.

### 3. Automated Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- **Automated Tests**:
   - `test/documents/pdf_raster_policy_test.dart`: verifies `ocrDpi` adapts to 90 DPI for large PDFs, safe DPI scales oversized pages, and extreme >100MB ceiling skips safely.
   - `test/documents/ocr_processing_service_test.dart`: verifies 8MB+ imported PDFs are processed at adaptive DPI rather than skipped.
   - `test/documents/document_viewer_ocr_menu_test.dart`: verifies "Run OCR" action is enabled with adaptive tooltip on skipped documents.
   - `test/ocr/ocr_adaptive_enhancement_test.dart`: verifies `DartImageProcessor.enhanceForOcr` clamps oversized bitmaps to 1600px while preserving smaller images.
   - **Full Suite**: `flutter test` (**2,083 tests passing, 0 failures**).

---

## 221. Android Quick Capture & Home-Screen Widget (October 2026)

### 1. Overview & Motivation
Implemented an end-to-end, production-ready Quick Capture feature for Android, allowing users to save thoughts or shared content nearly instantaneously:
- **Core Philosophy**: "Capture the thought. Save it locally. Close immediately. Let the user organize it later, if ever."
- **Home-Screen Widget**: Compact 3x2 / 4x1 Android home-screen widget with Quiet Paper branding and a single prominent action button (`+ Capture a thought`) styled in the warm editorial aesthetic (`#F7F6F2` Light / `#1D1C1A` Dark, `#D26753` Coral Accent).
- **Dedicated Quick Capture Screen**: Lightweight distraction-free interface matching the editorial design with automatic keyboard focus, multiline editing, live auto-titling, local draft recovery, and source-aware navigation.
- **Android Share Sheet Integration**: Plain-text, quoted text, and URL shares route into Quick Capture with content prefilled, while preserving full webpage clipping via an inline "Clip full article" action.
- **Local Draft Recovery**: Dedicated SQLite draft table (`quick_capture_drafts`, Schema v20) with 300ms debounce and lifecycle flushes, completely isolated from cloud sync and note queries.

### 2. Architecture & Components

#### A. Native Android Widget & AppWidgetProvider
1. **Layout & Visuals ([`android/app/src/main/res/layout/widget_quick_capture.xml`](file:///home/dog/git/quitepaper/android/app/src/main/res/layout/widget_quick_capture.xml))**:
   - Matches the compact home-screen widget design with warm rounded background (`widget_background.xml`), branded notepad/pencil icon (`ic_widget_note.xml`), `Quiet Paper` title, `A place for your thoughts.` subtitle, and a prominent coral button (`widget_button_background.xml`) labeled `+ Capture a thought`.
   - Supports light and dark mode through `res/values/colors.xml` and `res/values-night/colors.xml`.
2. **Provider & Intent Delivery ([`android/app/src/main/kotlin/com/blackpiratex/quietpaper/widget/QuickCaptureWidgetProvider.kt`](file:///home/dog/git/quitepaper/android/app/src/main/kotlin/com/blackpiratex/quietpaper/widget/QuickCaptureWidgetProvider.kt))**:
   - Inherits `AppWidgetProvider`. In `onUpdate()`, attaches an explicit `PendingIntent` for `ACTION_QUICK_CAPTURE` (`com.blackpiratex.quietpaper.QUICK_CAPTURE`) targeting `MainActivity` with `FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE`.
   - Registered in [`android/app/src/main/AndroidManifest.xml`](file:///home/dog/git/quitepaper/android/app/src/main/AndroidManifest.xml) with metadata [`@xml/widget_quick_capture_info`](file:///home/dog/git/quitepaper/android/app/src/main/res/xml/widget_quick_capture_info.xml).

#### B. Native-to-Flutter Launch Bridge & MethodChannel
1. **Activity Handling ([`android/app/src/main/kotlin/com/blackpiratex/quietpaper/MainActivity.kt`](file:///home/dog/git/quitepaper/android/app/src/main/kotlin/com/blackpiratex/quietpaper/MainActivity.kt))**:
   - `com.blackpiratex.quietpaper/quick_capture` channel manages capture launches and source-aware navigation.
   - **Cold Start**: On `onCreate()`, caches initial widget intent. Flutter retrieves it via `getInitialCaptureRequest` on startup.
   - **Warm Start**: On `onNewIntent()`, sets the latest intent and pushes an event to Flutter via `onQuickCaptureRequested`.
   - **Task Return (`moveTaskToBack`)**: Provides a native method channel call to `moveTaskToBack(true)`, returning the user to the launcher (for widget-origin captures) or the originating app (for share-origin captures) without destroying app state.

#### C. Share Normalization & Coordinator
1. **Normalizer ([`lib/features/quick_capture/application/quick_capture_normalizer.dart`](file:///home/dog/git/quitepaper/lib/features/quick_capture/application/quick_capture_normalizer.dart))**:
   - Sanitizes and normalizes untrusted input per Section 5.3 rules:
     - Handles plain text, quotations, and URLs.
     - Preserves line breaks, unicode, and emoji.
     - Detects embedded URLs and prevents duplicating URLs when separate URI fields are provided.
     - Caps oversized payloads at 500,000 characters safely.
     - Derives title hints from email/browser subjects when distinct from the body.
2. **Coordinator ([`lib/features/quick_capture/application/quick_capture_coordinator.dart`](file:///home/dog/git/quitepaper/lib/features/quick_capture/application/quick_capture_coordinator.dart))**:
   - Listens to the native quick capture channel and initial launch requests.
   - Prevents duplicate routes if a capture is already open, and delivers subsequent share intents to the active session.
   - Integrated with [`ShareIntentHandler`](file:///home/dog/git/quitepaper/lib/core/web_clipper/share_intent_handler.dart) so shared text and URLs open Quick Capture while preserving file imports for documents.

#### D. Local Draft Storage & Drift Schema v20
1. **Table Schema ([`lib/core/database/tables/quick_capture_drafts_table.dart`](file:///home/dog/git/quitepaper/lib/core/database/tables/quick_capture_drafts_table.dart))**:
   - Stores `id` (UUID session ID), `target_note_id` (stable note ID), `content`, `source`, `source_url`, `title_hint`, `cursor_position`, `created_at`, `updated_at`.
   - Index on `updated_at DESC`.
2. **Schema Upgrade & DAOs ([`lib/core/database/app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart))**:
   - Bumped `schemaVersion` to **20**.
   - Safe migration: `if (from < 20) await _createTableSafely(m, quickCaptureDraftsTable);`.
   - `saveQuickCaptureDraft()`, `getQuickCaptureDraft()`, `getAllQuickCaptureDrafts()`, `deleteQuickCaptureDraft()`, `deleteAllQuickCaptureDrafts()`.
   - `commitQuickCaptureNote()`: Atomically commits the canonical note to SQLite and deletes the active draft session inside a single database transaction.
   - Erased cleanly by `eraseAllLocalVaultData()`.
   - Invariant: Drafts are completely excluded from notes queries, FTS search index, and cloud sync dirty queues.

#### E. Capture UI & State Management
1. **State & Controller ([`lib/features/quick_capture/application/quick_capture_controller.dart`](file:///home/dog/git/quitepaper/lib/features/quick_capture/application/quick_capture_controller.dart))**:
   - Auto-saves draft with 300ms debounce.
   - Flushes draft on `AppLifecycleState` transitions (paused, hidden, inactive) and on close if non-empty.
   - Manages concurrent share arrival: preserves active draft and presents a nonintrusive switch action so no typing is lost.
   - Auto-derives title from content via `Note.deriveTitle(content)` with fallback to `titleHint`.
2. **Capture Screen ([`lib/features/quick_capture/presentation/quick_capture_screen.dart`](file:///home/dog/git/quitepaper/lib/features/quick_capture/presentation/quick_capture_screen.dart))**:
   - Warm editorial design matching the spec and Image 1:
     - Top bar: Close icon `✕ Quick Capture` and coral `Save` button (opacity 0.45 when empty, animated spinner when saving).
     - Divider line.
     - Editorial title: `What's on your mind?`.
     - Multiline text field with hint: `The idea goes here. Start typing immediately, without a title or any extra setup.`.
     - Automatic keyboard focus on mount.
     - Secondary actions: `Clip full article` (if URL present, launches `WebClipDialog`) and `Resume unfinished capture (N)` (shows bottom sheet of earlier drafts).
     - Footer: `Saved on your device first` with lock icon.
     - Responsive constraints (max-width 680dp on tablets; flex layout for narrow 320dp phones).

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- **Automated Tests**:
  - `test/quick_capture/quick_capture_normalizer_test.dart`: 9 tests passing (empty input, unicode/line breaks, URL-only, distinct subject hints, duplicate URL prevention, payload limits, stable session IDs).
  - `test/quick_capture/quick_capture_database_test.dart`: 6 tests passing (draft CRUD, ordering by updatedAt, exclusion from search/sync/notes queries, atomic commit transaction, idempotent save retry, erase vault data).
  - `test/quick_capture/quick_capture_service_test.dart`: 6 tests passing (empty init, prefilled session, debounced draft persistence, save commit, concurrent incoming share preservation, draft resume).
  - `test/quick_capture/quick_capture_screen_test.dart`: 6 tests passing (visual elements hierarchy, auto keyboard focus, save button enablement & commit, URL prefill & Clip action, resume draft sheet, narrow viewport layout).
  - `test/web_clipper/`: 42 tests passing with zero regressions.
  - Android unit tests: `QuickCaptureWidgetTest` passing.






---

## 36. Audio Journaling & In-Editor Voice Memos (prompts/audio.md)

### 1. Overview & Experience Design
- **In-Editor Voice Capture**: First-class voice memos recorded directly inside Quiet Paper notes from Super Editor, toolbar formatting hub, and keyboard accessory row.
- **Visual Design Parity**:
  - **Compact Inline Audio Row (Image 0)**: Warm surface container with coral microphone icon (`PhosphorIconsFill.microphone`), bold private title, timestamp and duration subtitle (`9:05 AM · 03:18`), and circular play/expand button.
  - **Expanded Rich Player Card (`QuietAudioCard`, Image 1)**: Waveform icon, title, datetime header (`21 Oct 2026 · 4:12 PM`), overflow menu (`⋯` with *Rename*, *Export audio*, and *Delete*), circular play/pause control, elapsed timer (`00:08`), seekable 32-bar interactive waveform (coral active progress, muted remaining), duration (`04:36`), and security badge (`Encrypted attachment · Available offline` with lock icon).
  - **Audio Recording Dock Bar (`AudioRecordingBar`)**: Compact docked recording panel anchored above the toolbar during recording with pulsing recording dot, live elapsed duration timer, live decibel-driven normalized amplitude visualizer, pause/resume, cancel/discard, and finish.
  - **Note Footer Summary (Image 0)**: Displays memo count and combined runtime (`2 recordings · 7 min 54 sec total`).
- **Dictation Isolation**: Whisper speech transcription (`AudioRecorderService` / `WhisperRecognitionEngine`) remains completely isolated and untouched.

### 2. Architecture & Service Boundaries

#### A. Domain & State Machine (`lib/core/audio/`)
1. **Lifecycle States ([`lib/core/audio/domain/audio_journal_models.dart`](file:///home/dog/git/quitepaper/lib/core/audio/domain/audio_journal_models.dart))**:
   - `AudioJournalStatus`: `idle`, `requestingPermission`, `preparing`, `recording`, `paused`, `finalizing`, `encrypting`, `saving`, `completed`, `failed`, `cancelled`.
   - `AudioJournalRecordingSession`: Immutable snapshot containing status, exact elapsed duration, instantaneous decibels, 120-sample visualizer buffer, working file reference, and captured Super Editor cursor anchor (`capturedNodeId`, `capturedCaretOffset`).
   - `AudioJournalConfig`: Configurable max duration (default 1 hour), max file size (default 50 MB), sample rate (44.1 kHz), and bit rate (128 kbps).
2. **Helpers ([`lib/core/audio/application/audio_duration_helper.dart`](file:///home/dog/git/quitepaper/lib/core/audio/application/audio_duration_helper.dart))**:
   - Formats `MM:SS`, `H:MM:SS`, human summary totals (`X recordings · Y min Z sec total`), and timestamps.
   - Extracts 32-bar normalized amplitude envelopes from audio bytes for playback visualization.

#### B. Capture & Recording Infrastructure
1. **Recording Service ([`lib/core/audio/infrastructure/audio_journal_recording_service.dart`](file:///home/dog/git/quitepaper/lib/core/audio/infrastructure/audio_journal_recording_service.dart))**:
   - Encodes AAC LC `.m4a` with automatic `.wav` fallback for platforms with limited AAC container support.
   - Precise elapsed time accumulation excluding paused intervals.
   - Live decibel stream (`150ms`) normalized to `[0.0..1.0]` with smooth power curve.
   - Automatic cleanup of stale temporary sessions (`>24h`) and file-size/duration limit guards.
   - Concurrent recording guard (`throws StateError`).
   - Supports dependency injection of `customTempDirectory` for isolated test runners.

#### C. Playback Infrastructure
1. **Playback Service ([`lib/core/audio/infrastructure/audio_playback_service.dart`](file:///home/dog/git/quitepaper/lib/core/audio/infrastructure/audio_playback_service.dart))**:
   - Coordinates `audioplayers: ^6.8.1`.
   - Enforces a strict single-active-player policy across the application (starting a second audio clip stops any active playback).
   - Direct in-memory `BytesSource` playback with fallback to ephemeral decrypted cache file.
   - Reactive streams for position, duration, and playback state (`AudioPlaybackSnapshot`).

#### D. Encrypted Attachment & Zero-Leak Sync Model
1. **Subsystem Reuse**: Reuses existing generic attachment infrastructure (`AttachmentService`, `AttachmentCrypto`, `qp://asset/<UUID>`). Zero database migrations or new schema tables introduced.
2. **Title Privacy Protection**: Persists a technical neutral filename (`recording_<UUID>.m4a`) in SQLite `attachments` records and cloud sync headers. The user-assigned voice memo title lives exclusively inside the client-side encrypted note body Markdown link: `[User Title](qp://asset/<UUID>)`.
3. **Encryption Standard**: Audio is encrypted before persistence using client-side authenticated XChaCha20-Poly1305 (`QPA1`).
4. **OCR Pipeline Exclusion**: `AttachmentTypeResolver.isAudio` strictly excludes audio attachments from OCR processing (`ocrState: not_requested`).

#### E. Super Editor & Document Integration
1. **Node Promotion ([`lib/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_attachment_component.dart))**:
   - Standalone `[Title](qp://asset/<UUID>)` links promote to `QuietAttachmentNode`.
   - `QuietAttachmentCard` detects audio via `AttachmentTypeResolver.isAudio` and renders `QuietAudioCard`.
   - `QuietAttachmentNodeSerializer` guarantees serializing back to standard link syntax `[Title](qp://asset/<UUID>)`.
2. **Caret & Anchor Preservation**:
   - `QuietSuperEditorController.insertAttachment` captures the logical anchor/caret node ID before launching the recording bar.
   - Replaces empty paragraph or inserts immediately after anchor with trailing paragraph for continuous writing.
   - Renaming voice memo updates node `displayText` without mutating underlying UUID or `qp://asset/` URI.

#### F. Public Sharing Privacy Safeguards (Section 10.4)
1. **Cloudinary Upload Exclusion ([`lib/features/share/application/share_service.dart`](file:///home/dog/git/quitepaper/lib/features/share/application/share_service.dart))**:
   - Audio attachments are strictly excluded from public Cloudinary uploads.
   - Markdown links are rewritten to `> *[Voice memo excluded from public share]*` and private `qp://asset/<UUID>` URIs are completely stripped.
2. **User Heads-Up Warning ([`lib/features/share/presentation/share_warning_dialog.dart`](file:///home/dog/git/quitepaper/lib/features/share/presentation/share_warning_dialog.dart))**:
   - If a shared note contains audio attachments, `ShareWarningDialog` renders an explicit disclaimer: `Voice recordings will be excluded from the public link to protect your privacy.`.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found**).
- **Automated Audio Test Suites** (39 tests total):
  - `test/audio/audio_duration_helper_test.dart` (4 tests): MM:SS formatting, human totals, timestamp labels, amplitude byte extraction.
  - `test/audio/audio_journal_recording_service_test.dart` (11 tests): Permissions, session lifecycle, pause/resume duration accumulation, finish, cancel cleanup, stale file pruning, amplitude stream.
  - `test/audio/audio_playback_service_test.dart` (7 tests): Play, pause, seek, single active player enforcement, onPlayerComplete.
  - `test/audio/audio_attachment_crypto_test.dart` (4 tests): Ingest audio, neutral technical filenames, QPA1 encryption envelopes, authenticated decryption, tampered ciphertext rejection, audio type resolver.
  - `test/audio/super_editor_audio_test.dart` (5 tests): Standalone link promotion, link serialization round-trips, consecutive blocks, insertAttachment at cursor, rename without URI mutation.
  - `test/audio/quiet_audio_card_test.dart` (4 tests): Compact view, tap-to-expand, rich player controls, dark theme rendering.
  - `test/audio/audio_sharing_privacy_test.dart` (4 tests): Public share audio exclusion, link rewrite to omission notice, private URI stripping, share warning dialog.
- **Regression Tests**:
  - `test/attachments/`, `test/speech/`, `test/share/`: 184 tests passing with zero regressions.


---

## 222. Cross-Device Tag Synchronization Architecture: Deletions, Renames, Convergent Deterministic IDs & Accent Lifecycle (October 2026)

### 1. Problem Statement & Root Cause Analysis
Users reported that tags were not synchronizing correctly across devices:
- **Remote Tag Deletion Failure**: Deleting a tag on Device A did not delete it on Device B. Even if Device B processed a delete, note contents still contained `#tag` strings, causing SQLite/Drift's note tag detection (`_syncNoteTags`) to immediately resurrect the deleted tag upon opening or saving the note.
- **Tombstone Decryption Omission**: When syncing deleted tags, `sync_engine.dart` skipped decrypting the payload and passed `name: ''`, preventing `upsertSyncedTag` from knowing the tag name to clean up note Markdown references.
- **Premature Hard Deletes**: `deleteTag` immediately hard-deleted tags whenever `serverRevision == 0`, ignoring active sync sessions where `serverRevision` hadn't yet been returned or where `syncCursor`/`syncedAt` indicated existing synchronization history.
- **Rename Propagation Failure**: Renaming a tag on Device A was not propagating the Markdown note updates to Device B.
- **Accents (Color/Icon) Clearing**: Clearing a tag's color or icon on Device A didn't reflect on Device B because `TagPlaintext.toJson()` omitted null entries and `upsertSyncedTag` defaulted to existing accents when fields were absent.
- **Non-Deterministic Tag IDs**: Devices independently minted random UUID v4s for tags extracted from note Markdown, resulting in duplicate tag entries on the crypto-blind backend.
- **Missing Sync Debounce Triggers**: Tag mutation methods in `TagService` did not trigger debounced sync.
- **Pull Phase Inversion**: Notes were pulled before tags in `SyncEngine`, so incoming note text triggered tag insertion before remote tag metadata and accents arrived.

### 2. Architectural Solution & Changes

#### A. Convergent RFC 4122 UUID v5 Tag Identifiers (`lib/core/utils/tag_parser.dart`)
- Implemented `TagParser.deterministicTagId(String name)` using RFC 4122 UUID v5 rooted in a dedicated Quiet Paper namespace:
  ```dart
  static String deterministicTagId(String name) {
    final normalized = normalize(name);
    return const Uuid().v5(Namespace.url.value, 'quitepaper:tag:$normalized');
  }
  ```
- Both `createTag` and `_syncNoteTags` in `AppDatabase` now use `TagParser.deterministicTagId`. When a user types `#tag` on any device, all devices generate the exact same canonical UUID for the same normalized tag name without requiring server coordination.

#### B. TagPlaintext Schema Expansion (`lib/core/crypto/crypto_service.dart`)
- Expanded `TagPlaintext` to carry explicit clearing flags and rename lineage:
  - `clearColor: bool`
  - `clearIcon: bool`
  - `renamedFrom: String?`
  - `renamedTo: String?`
- Proper JSON serialization and SHA-256 payload hashing ensure zero-knowledge integrity across clients.

#### C. Full Remote Deletion & Anti-Resurrection Pipeline (`lib/core/database/app_database.dart`)
- **Tombstone Decryption**: In `sync_engine.dart`, deleted tag payloads are decrypted with the master key before calling `upsertSyncedTag`.
- **Note Markdown Cleansing**: When `isDeleted: true` arrives in `upsertSyncedTag`:
  - Locates all notes containing the tag.
  - Strips `#tag` from titles and note bodies using `TagParser.removeTagFromText`.
  - Saves cleansed notes with `isDirty: false` to avoid echoing unnecessary updates back to the cloud.
  - Deletes all associations from `noteTagsTable` and removes the tag from `tagsTable`.
- **Resilient Tombstoning**: `deleteTag` preserves a soft-deletion tombstone whenever `serverRevision > 0 || syncedAt != null || syncCursor != null`.

#### D. Remote Tag Renaming & Markdown Rewriting (`lib/core/database/app_database.dart`)
- Renaming a tag on Device A writes `renamedFrom` and `renamedTo` in the encrypted payload.
- In `upsertSyncedTag`:
  - Atomically updates `tagsTable` first with the new name to satisfy foreign keys and avoid unique constraint collisions.
  - Rewrites occurrences of `#oldTag` to `#newTag` across all local notes using `TagParser.replaceTagInText` (with `isDirty: false`).
  - Cleans up legacy tag IDs and associates note tags with the canonical ID.

#### E. Accent Lifecycle & Explicit Clearing
- When `clearIcon` or `clearColor` is true, `upsertSyncedTag` explicitly resets the column to `null`.
- When an icon or color is provided, it updates the existing tag.

#### F. Sync Engine Ordering & Debounce Hooks
- **Pull Ordering**: Tag Pull is executed *before* Note Pull in `SyncEngine.syncNow()`, ensuring tag metadata and styling arrive before notes parse tags from text.
- **Mutation Debounce**: Wired `onTagMutation: engine.triggerSyncDebounced` in `TagService` across create, update, delete, rename, pin, and unpin operations.
- **Engine Lifecycle**: `SyncEngine` tracks `_isDisposed` and cancels `_authSubscription` and `_syncDebouncer` upon disposal, eliminating race conditions against closed SQLite databases during test teardown and app backgrounding.

### 3. Verification & Quality
- `flutter analyze`: **0 issues found**.
- `flutter test`: **100% passing across all 2,160+ tests**:
  - `test/sync/tag_sync_test.dart` (14 end-to-end integration tests).
  - `test/tags/tag_database_test.dart` (7 tests).
  - `test/tags/tag_service_test.dart` (8 tests).
  - `test/tags/tag_ui_test.dart` and `test/tags/tag_icon_picker_sheet_test.dart` (all passing).


---

## 223. Typewriter Scrolling: Ambient Cursor Vertical Centering Across All Editor Modes (October 2026)

### 1. Problem Statement & Writing Ergonomics
In digital note applications, writing extensive documents naturally pushes the active cursor down toward the bottom boundary of the screen. On mobile devices (Android & iOS), the cursor ends up pinned directly against the top edge of the virtual software keyboard or `FormattingToolbar`, forcing the user's line of sight down and causing neck strain. On desktop environments, the cursor similarly collides with the window bottom.

In accordance with Quiet Paper's core vision (*Content First, Warm Editorial Aesthetic, Exceptional Core Writing Loop*), **Typewriter Scrolling** was implemented to keep the active cursor line vertically anchored at approximately **45% from the top of the viewport** as the user types.

### 2. Architectural Design & Behavior

```
┌────────────────────────────────────────────────────────────────────────┐
│                        EditorScreen (Viewport)                         │
│                                                                        │
│   [AppBar / Top Search / Docked Toolbar]                               │
│   ──────────────────────────────────────────────────────────────────   │
│   ▲                                                                    │
│   │ 45% of Visible Viewport (Natural Eye Level)                        │
│   ▼                                                                    │
│   ══════════════════════ [Active Cursor Line] ══════════════════════   │
│   ▲                                                                    │
│   │ 55% Breathing Room                                                 │
│   ▼                                                                    │
│   ──────────────────────────────────────────────────────────────────   │
│   [Bottom FormattingToolbar / Software Keyboard]                       │
└────────────────────────────────────────────────────────────────────────┘
```

#### A. Core Principles
1. **Always-On Ambient Ergonomics**: Typewriter scrolling is active by default across all editors with zero settings clutter or extraneous UI switches.
2. **Natural Document Start**: New notes and short documents start naturally with line 1 at the top of the sheet. The viewport begins scrolling only once writing progresses down to the 45% waterline.
3. **Manual Scrolling Invariant**: When a user drags with touch or uses the mouse wheel to review earlier text, `scrollController.position.isScrollingNotifier.value` prevents auto-scrolling so reading is never interrupted. As soon as typing resumes, the editor smoothly glides to anchor the cursor at 45%.
4. **Jitter-Free Typing**: Moving horizontally within the same line produces $\Delta y = 0$, requiring no scroll. Vertical adjustments use a 2px deadband tolerance and a 120ms `Curves.easeOutCubic` animation for seamless visual stability.

#### B. Architectural Components

1. **`TypewriterScrollCoordinator` ([`lib/features/editor/application/typewriter_scroll_coordinator.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/typewriter_scroll_coordinator.dart))**:
   - Manages viewport geometry and executes scroll animations.
   - Calculates the target waterline: $Y_{\text{target}} = Y_{\text{viewport\_top}} + (H_{\text{viewport}} \times 0.45)$.
   - Traverses active focus trees to locate `RenderEditable` instances in `TextField`-based editors (Markdown mode, Visual / WYSIWYG mode, note title).
   - Resolves global caret positions via `renderEditable.getLocalRectForCaret(TextPosition(offset: selection.extentOffset))`.
   - Coalesces rapid keystrokes within the same animation frame via `WidgetsBinding.instance.addPostFrameCallback`.

2. **`TypewriterDocumentLayer` ([`lib/features/editor/presentation/widgets/super_editor/typewriter_document_layer.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/typewriter_document_layer.dart))**:
   - SuperEditor layer builder integrated into `QuietSuperEditor.documentOverlayBuilders`.
   - Queries `DocumentLayout.getEdgeForPosition(selection.extent)` on composer selection updates.
   - Maps document coordinates to global screen coordinates via the overlay's `RenderBox.localToGlobal` and notifies `TypewriterScrollCoordinator`.

3. **Editor Screen & Dynamic Bottom Spacer ([`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart))**:
   - Maintains `_viewportKey` on the `DesktopSmoothScroll` / `SingleChildScrollView` container.
   - Wires typing listeners in `_onContentChanged`, `_onTargetChanged`, and `_onTitleChanged`.
   - Embeds a dynamic bottom scroll spacer:
     ```dart
     final bottomScrollPadding = max(
       isDesktop ? 220.0 : 300.0,
       viewportHeight * 0.55,
     );
     ```
     This guarantees that even the very last line of any document has at least 55% of the viewport height beneath it, enabling it to reach the 45% centerline on any display resolution.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- **Automated Tests**:
  - `test/editor/typewriter_scrolling_test.dart` (7 tests passing):
    - Viewport math & 45% waterline calculation.
    - 2px deadband tolerance to prevent redundant scroll calls.
    - Clamping within `[minScrollExtent, maxScrollExtent]`.
    - Manual touch/drag gesture protection via `isScrollingNotifier`.
    - Coalescing and post-frame scheduling for rapid keystrokes.
    - `RenderEditable` global caret coordinate extraction.
    - `SuperEditor` `TypewriterDocumentLayer` position reporting.
    - Full `EditorScreen` integration test verifying body typing glides to 45%.
- **Regression Tests**:
  - `test/editor/dual_mode_editor_screen_test.dart`, `test/editor/quiet_super_editor_test.dart`, and `test/editor/markdown_editor_widget_test.dart` (63 tests passing with 0 regressions).

---

## 37. On-Device Audio Journal Transcription (prompts/transcriptionforaudio.md)

### 1. Overview & Experience Design
- **Local On-Device Inference**: Offline transcription powered by Whisper GGML models managed by `SpeechModelManager`. Voice memos and spoken thoughts never leave the user's local device.
- **Audio Attachment Source of Truth**: The encrypted audio attachment file (`.enc`) is never mutated, re-encoded, or altered when transcripts are generated, regenerated, edited, or deleted.
- **Visual Design Parity**:
  - **In-Progress Transcription State (`QuietAudioCard`, Image 1)**: Waveform icon, memo title, subtitle (`Whisper Base · English`), loading spinner, stage status (`Transcribing on device…`), progress percentage (`55%`), linear progress indicator, privacy assurance badge (`Your audio stays on this device during transcription.` with shield icon), and `Cancel` button.
  - **Collapsible Transcript Card (`QuietAudioCard`, Image 0)**: Document text icon (`PhosphorIconsRegular.fileText`), "Transcript" title, subtitle (`Available · English` or `Edited manually · English`), chevron expand/collapse toggle (`caretDown`/`caretUp`), rounded transcript container (`SelectableText`), origin badge (`Generated on device` or `Edited manually`), inline text editing (`Edit transcript`, `Save`, `Cancel`), and overflow menu options (*Copy transcript*, *Edit transcript*, *Insert into note*, *Regenerate transcript…* with confirmation dialog).

### 2. Architecture & Service Boundaries

#### A. Audio File Transcription Infrastructure ([`lib/core/audio/infrastructure/audio_file_transcription_service.dart`](file:///home/dog/git/quitepaper/lib/core/audio/infrastructure/audio_file_transcription_service.dart))
1. **Decrypted Lifecycle**: Decrypts audio bytes into an ephemeral working file only during inference; securely deletes both the temporary decrypted file and 16kHz mono WAV conversion immediately upon completion, error, or cancellation.
2. **Deduplication**: Concurrent transcription requests for the same attachment ID are deduplicated against in-flight jobs.
3. **Cancellation**: Safe cancellation aborts execution and discards partial outputs without corrupting note content or attachment storage.

#### B. Canonical Markdown Representation ([`lib/core/audio/application/audio_transcript_markdown_helper.dart`](file:///home/dog/git/quitepaper/lib/core/audio/application/audio_transcript_markdown_helper.dart))
1. **Canonical Link Format**: `[Title](qp://asset/<UUID>?transcript=1&lang=en&edited=0)` followed by companion blockquote lines (`> Spoken text line 1\n> Spoken text line 2`).
2. **Manual Edits Marked**: `edited=1` marks user-edited transcripts and preserves edits during reloads.
3. **Clean Asset URI**: `qp://asset/<UUID>` is maintained as the canonical reference without leaking query parameters into internal node URIs.
4. **Standalone Quote Preservation**: Standalone user blockquotes are preserved; only immediately consecutive companion blockquote lines following an audio link with `transcript=1` are absorbed.

#### C. Multi-Mode Editor Support
1. **Super Editor (`QuietAttachmentNode`)**: Absorbs companion blockquotes on deserialization; serializes back to canonical link with parameters and companion blockquotes; `insertParagraphAfterBlock` affordance for inserting transcript text directly into the note.
2. **Visual Mode (`AttachmentBlock`)**: `RichDocumentParser` and `RichDocumentSerializer` round-trip audio attachments with transcripts and edit markers across mode transitions.
3. **Preview & Reading Modes (`QuietMarkdownPreview`)**: `stripTranscriptBlockquotesForPreview` prevents duplicate rendering so companion quotes appear only inside the audio card.

#### D. FTS5 Search & Privacy
1. **Full-Text Indexing**: Companion blockquote text naturally indexes into SQLite FTS5 for full-text search.
2. **Metadata Sanitization**: `MarkdownOffsetMapper` strips `>` and internal `qp://asset/...` links/parameters to prevent metadata leaks in snippets and search results.
3. **Public Share Safeguard ([`lib/features/share/application/share_service.dart`](file:///home/dog/git/quitepaper/lib/features/share/application/share_service.dart))**: `ShareService` automatically strips audio links and their companion transcript blockquotes from public shares unless explicitly opted in.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- **Automated Audio Test Suites** (56 tests passing across `test/audio/`):
  - `test/audio/audio_file_transcription_service_test.dart` (4 tests): Transcribes WAV attachment, fails safely if speech model missing, deduplicates concurrent requests, cancellation safeguards.
  - `test/audio/super_editor_audio_test.dart` (12 tests): Standalone link promotion, link serialization round-trips, consecutive blocks, insertAttachment at cursor, rename without URI mutation, transcript persistence, manual edits (`edited=1`), consecutive transcript blocks, Visual mode round-tripping, preview blockquote stripping, cross deletion tombstone and file deletion via `AttachmentService` in Super Editor and Visual mode.
  - `test/audio/quiet_audio_card_test.dart` (9 tests): Compact view, tap-to-expand, rich player controls, dark theme, transcript display (Image 0), edited manually badge, inline transcript editing, insert into note, in-progress processing UI (Image 1), overflow-free footer with `Encrypted attachment` label.
  - `test/audio/audio_sharing_privacy_test.dart` (5 tests): Public share audio exclusion, companion transcript blockquote exclusion, image upload with audio exclusion, share warning dialogs.
  - `test/audio/audio_duration_helper_test.dart` (4 tests), `test/audio/audio_journal_recording_service_test.dart` (11 tests), `test/audio/audio_playback_service_test.dart` (7 tests), `test/audio/audio_attachment_crypto_test.dart` (4 tests).
- **Search Verification**:
  - `test/search/search_index_projection_test.dart`: Spoken audio transcript text indexed while stripping internal URI and query parameters.

---

## 224. Linux App Build Pipeline & GStreamer Dependency Resolution (October 2026)

### 1. Overview & Root Cause Analysis
- **Problem Statement**: The GitHub Actions Linux application building workflow failed during release compilation with CMake error:
  ```text
  CMake Error at /usr/local/share/cmake-4.4/Modules/FindPkgConfig.cmake:1093 (message):
    The following required packages were not found:

     - gstreamer-1.0

  Call Stack (most recent call first):
    flutter/ephemeral/.plugin_symlinks/audioplayers_linux/linux/CMakeLists.txt:24 (pkg_check_modules)
  ```
- **Root Cause**: The addition of `audioplayers: ^6.8.1` for audio journaling introduced `audioplayers_linux` on Linux desktop. The plugin CMake configuration requires `gstreamer-1.0`, `gstreamer-app-1.0`, and `gstreamer-audio-1.0` via `pkg-config`. The runner environment lacked `libgstreamer1.0-dev` and `libgstreamer-plugins-base1.0-dev`.
- **Trigger Limitation**: The `.github/workflows/build_linux.yml` workflow was previously restricted to `workflow_dispatch` only, meaning pushes to `main` did not automatically build and package the Linux release artifacts (tarball, RPM, AppImage).

### 2. Implementation Details
- **Automated Workflow Push Trigger ([`.github/workflows/build_linux.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_linux.yml))**:
  - Added `push` and `pull_request` triggers targeting `main`, aligning the Linux build pipeline with the Android APK pipeline (`build_apk.yml`).
  - Retained `workflow_dispatch` for manual runs.
- **GStreamer Development & Runtime Package Installation**:
  - Extended the `Install Linux build dependencies` step to install:
    - Development headers: `libgstreamer1.0-dev`, `libgstreamer-plugins-base1.0-dev` (satisfying `gstreamer-1.0`, `gstreamer-app-1.0`, and `gstreamer-audio-1.0` pkg-config dependencies).
    - Codec and plugin libraries: `gstreamer1.0-plugins-base`, `gstreamer1.0-plugins-good`, `gstreamer1.0-plugins-bad`, `gstreamer1.0-libav` (ensuring comprehensive audio playback and decoding support for AAC, MP3, WAV, etc.).
- **RPM Packaging Specification ([`linux/packaging/quietpaper.spec`](file:///home/dog/git/quitepaper/linux/packaging/quietpaper.spec))**:
  - Added runtime package requirements to `quietpaper.spec`:
    - `Requires: gstreamer1 >= 1.16`
    - `Requires: gstreamer1-plugins-base >= 1.16`
    - `Requires: gstreamer1-plugins-good`
  - Ensures clean runtime execution and audio playback when installed on Fedora, openSUSE, and RHEL-based distributions without manual package discovery.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` (**0 issues found, ran in 8.1s**).
- **Automated Tests**: `flutter test` (**2,184 passed, 0 failures, 0 regressions**).
- **Native Release Build**: `flutter build linux --release` verified successfully (`Built build/linux/x64/release/bundle/quitepaper`).

- **Bug Fixes (Post-Verification)**:
  - **Audio Card Footer Overflow**: Removed ` · Available offline` suffix from the footer label in `QuietAudioCard` so `Transcribe audio` never overflows on narrow screens, and wrapped the label in `Expanded`/`Flexible` with `TextOverflow.ellipsis`.
  - **Cross (X) / Delete Button Asset Purging**: Connected the cross button and delete action in both `QuietAttachmentComponent` and `RichAttachmentBlock` to `AttachmentService.deleteAttachment()`. This invalidates the decrypted cache, marks the record deleted, enqueues a sync tombstone for the cloud garbage collector, and deletes the local encrypted file (`.enc`) from storage.
  - **Transcription Loading Screen Lifecycle**: Resolved missing loading screen when transcription begins. Immediate processing UI (`_buildProcessingInterface` matching Image 1) now activates upon tapping "Transcribe audio" with stage-by-stage status ("Checking speech model…", "Preparing audio…", "Transcribing on device…"), linear & circular progress indicators, and cancellation. Stabilized `audioFileTranscriptionServiceProvider` by decoupling from `speechModelManagerProvider` listener churn, caching active job states, and passing direct `onStateChange` callbacks to eliminate stream delivery latency. Verified with dedicated automated widget test (57 audio tests passing).
  - **Real Audio Waveform Extraction & Local Cache**: Replaced the static synthetic sine curve with real audio waveform rendering backed by a local on-device cache (`AudioWaveformCacheService`). Extended `AudioJournalRecordingService` to record all incoming microphone decibels across the full session into `sessionAmplitudes`, downsampling to 32 normalized bars and caching immediately upon finishing a recording. Enhanced `AudioDurationHelper.extractAmplitudesFromBytes()` with genuine WAV 16-bit PCM RMS extraction and pure-Dart MP4/M4A `stsz` (sample size box) frame energy parsing. `QuietAudioCard` loads cached waveforms instantly without decrypting the vault file; if uncomputed, it decrypts locally once in the background, extracts the true waveform, and persists it locally. Automated verification expanded to 64 passing tests across `test/audio/`.

---

## 225. Audio Card & Companion Component Typography Settings Integration (October 2026)

### 1. Problem Statement & Design Requirements
- **Context**: The audio card (`QuietAudioCard`) and its companion components (the floating recording dock `AudioRecordingBar`, audio attachment `AudioRenameDialog`, and the note editor's `_AudioSummaryFooter`) previously relied on static, hardcoded font sizes (e.g., 15.0, 13.0, 12.0, 11.0) and unstyled system text themes.
- **Defect**: When users customized typography preferences in Appearance Settings (adjusting base font size, heading or body font families, line height, or letter spacing), audio cards and associated voice memo UI elements failed to reflect the chosen typography, breaking visual harmony and accessibility for users relying on larger font scales.

### 2. Architectural Design & Implementation

#### A. Proportional Scaling & Legibility Bounds in `TypographySettings` ([`lib/features/settings/domain/typography_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/typography_settings.dart))
- Extended `TypographySettings` with proportional scaling logic relative to the canonical editor base body font size (18.0pt):
  ```dart
  double scaleFontSize(double baseSize, {double min = 9.0}) {
    final scale = fontSize / 18.0;
    return (baseSize * scale).clamp(min, double.infinity);
  }
  ```
- Provided ergonomic getters for standard typography hierarchy tiers:
  - `scaledBodyLargeSize`: Proportional size for large body and title elements (base: 18.0).
  - `scaledBodyMediumSize`: Proportional size for standard body text, transcript content, and text input fields (base: 16.0).
  - `scaledBodySmallSize`: Proportional size for subheadings and secondary metadata (base: 14.0).
  - `scaledCaptionSize`: Proportional size for badges, timestamps, waveform durations, and footers (base: 12.0, clamped to min 9.0).

#### B. Dynamic Styling in `QuietAudioCard` ([`lib/core/audio/presentation/quiet_audio_card.dart`](file:///home/dog/git/quitepaper/lib/core/audio/presentation/quiet_audio_card.dart))
- Replaced static text styles with reactive watchers of `typographySettingsProvider`.
- Implemented typography helper methods leveraging `FontFamilyHelper.resolveFont()`:
  - `_headingStyle()`: Applies `typography.headingFontFamily`, scaled font sizes, and letter spacing to card titles and section headers.
  - `_bodyStyle()`: Applies `typography.bodyFontFamily`, `scaledBodyMediumSize`, user-configured line height, and letter spacing to transcript bodies, action labels, and descriptions.
  - `_captionStyle()`: Applies `typography.bodyFontFamily`, `scaledCaptionSize`, and letter spacing to duration timestamps, waveform labels, security badges, and transcript metadata.
- Integrated across all audio card view states:
  - Compact player: Title, duration labels, play/pause controls.
  - Expanded player: Title, encrypted attachment lock badge, live waveform elapsed and total duration markers, overflow actions.
  - In-flight transcription loading screen: Stage label ("Transcribing on device…"), progress percentage, model descriptor badge, privacy notice ("Your audio stays on this device…"), and cancel button.
  - Transcript view: Section header ("Transcript"), status badge ("Available · English" / "Edited manually · English"), transcript body (`SelectableText`), inline edit mode (`TextField` preserving cursor, font size, and line height), and footer action buttons.

#### C. Companion Audio Components Integration
- **`AudioRecordingBar` ([`lib/core/audio/presentation/audio_recording_bar.dart`](file:///home/dog/git/quitepaper/lib/core/audio/presentation/audio_recording_bar.dart))**: Converted to `ConsumerStatefulWidget` to watch `typographySettingsProvider`. Elapsed recording timer, status text ("Recording voice memo..."), and permission/error messages now dynamically scale with `scaledCaptionSize` and `bodyFontFamily`.
- **`AudioRenameDialog` ([`lib/core/audio/presentation/audio_rename_dialog.dart`](file:///home/dog/git/quitepaper/lib/core/audio/presentation/audio_rename_dialog.dart))**: Converted to `ConsumerStatefulWidget` to watch `typographySettingsProvider`. The dialog title scales with `scaledBodyLargeSize` and `headingFontFamily`, while the title edit `TextField` scales with `scaledBodyMediumSize` and `bodyFontFamily`.
- **`_AudioSummaryFooter` ([`lib/features/editor/presentation/editor_screen.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/editor_screen.dart))**: Applied `typography.scaleFontSize(12.5)` and `typography.bodyFontFamily` with dynamic line height to the note editor's sticky audio attachment summary footer.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` completed with **0 issues found**.
- **Unit & Widget Test Suites**:
  - `test/settings/typography_settings_test.dart` (12 tests passed): Proportional scaling accuracy, minimum clamping behavior, serialization roundtrip.
  - `test/audio/quiet_audio_card_test.dart` (16 tests passed):
    - Scaled font size verification under large font preferences (27pt base size).
    - Minimum legible bound clamping under small font preferences (12pt base size).
    - Encrypted lock badge scaling when no transcript is present.
    - Custom heading (`Playfair Display`) and body (`Lora`) font family inheritance.
    - Inline transcript editor `TextField` typography inheritance.
  - Full audio test suite `test/audio/` (69 tests passed with 100% success rate).

---

## 226. Settings Hierarchy Reorganization & Dedicated Author Showcase Screen (October 2026)

### 1. Problem Statement & Design Requirements
- **Settings Clutter**: The primary [settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart) had accumulated numerous long, vertically scrolling sections (Cloud Sync with password/session controls, Editor styling choices, Storage & Attachments, Import/Export, and Maintenance actions), making discovery difficult and degrading the quiet, restrained editorial aesthetic.
- **Hierarchy Simplification**:
  - **Cloud Sync & Encryption**: Streamlined to 3 rows when authenticated (Email/Status, Sync Now, Advanced).
  - **Sync Advanced**: Offload account/encryption passwords, devices & active sessions, sign out, and the entire **Storage and Attachments** section (5 options) into a dedicated sub-page ([sync_advanced_settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/sync_advanced_settings_screen.dart)).
  - **General Settings**:
    - Retain **Default Settings** and migrate all **Editor** options (Super Editor, WYSIWYG with Beta pill, Markdown, Speech Recognition, Smart web links) into [default_settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart).
    - Add **Appearance** (subtitle: *"Themes and typography"*), opening [appearance_settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/appearance_settings_screen.dart) containing Theme Family swatches, Appearance mode (System, Light, Dark), and Typography navigation.
    - Add **Backup and import**, opening [backup_import_settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/backup_import_settings_screen.dart) containing Markdown Import and Local Backup & Restore.
    - Add **Advanced**, opening [general_advanced_settings_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/general_advanced_settings_screen.dart) containing the 3 maintenance options (Download Attachments, Rerun OCR, Rebuild Index), Desktop OCR (Ollama), Sample Notes, and Debug tools.
  - **About Section & Author Showcase**:
    - Make the app title and version tile clickable in the About section, navigating to a new [about_app_screen.dart](file:///home/dog/git/quitepaper/lib/features/settings/presentation/about_app_screen.dart).
    - Serve the author hero image remotely from the backend static asset directory (`backend/public/images/DSC01473-3.jpg`) via `syncApiClientProvider.baseUrl` (never bundled in the APK asset manifest).
    - Attribute *"Designed and developed by Sudip Mandal"*, link to `https://blackpiratex.com`, provide an expanded editorial app vision description, and include links to the Author Blog (`https://blackpiratex.com/blog`), GitHub repo (`https://github.com/blackpirateapps/quitepaper`), Terms of Service, and Privacy Policy.

### 2. Architectural Design & Implementation Details

#### A. Shared Reusable Settings Primitives ([`lib/features/settings/presentation/widgets/settings_shared_widgets.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/settings_shared_widgets.dart))
- Extracted shared settings building blocks to ensure visual coherence across all sub-screens:
  - `SettingsGroup`: Grouped container with rounded borders, surface styling, and optional padding.
  - `SettingsRow`: Configurable settings list tile supporting leading icons, badge pills, titles, subtitles, custom trailing widgets (chevrons, switches), selected state indicators, and tap handlers.
  - `SettingsInfoTile`: Visual notice and informational alert banners.
  - `BetaBadge`: Distinctive badge pill for experimental features like WYSIWYG editing.
  - `buildSectionHeader`: Standardized uppercase section titles with letter spacing.
  - `buildDivider`: Thin divider matching `AppColors.divider`.
  - `buildThemePreviewSwatches`: Live palette swatches rendering background, card surface, and accent tokens.

#### B. Streamlined Main Settings Screen ([`lib/features/settings/presentation/settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/settings_screen.dart))
- Restructured `SettingsScreen` into 3 concise sections:
  1. **Cloud Sync & Encryption**:
     - When unauthenticated: Promo card with setup CTA.
     - When authenticated: Exactly 3 rows:
       1. User email with live sync status indicator badge.
       2. "Sync Now" with manual trigger and feedback.
       3. "Advanced" row navigating to `SyncAdvancedSettingsScreen`.
  2. **General**:
     - "Default Settings" (navigates to `DefaultSettingsScreen`).
     - "Appearance" with subtitle *"Themes and typography"* (navigates to `AppearanceSettingsScreen`).
     - "Backup and import" with subtitle *"Markdown import and local backups"* (navigates to `BackupImportSettingsScreen`).
     - "Advanced" with subtitle *"Maintenance, debug tools, and sample notes"* (navigates to `GeneralAdvancedSettingsScreen`).
  3. **About**:
     - Clickable "Quiet Paper" app header tile navigating to `AboutAppScreen`.
     - Privacy Policy, Terms & Conditions, and "Check for updates" (flavor-aware).

#### C. Dedicated Sub-Screens
1. **`SyncAdvancedSettingsScreen` ([`lib/features/settings/presentation/sync_advanced_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/sync_advanced_settings_screen.dart))**:
   - Hosts email verification banner (with cooldown timer), Devices & Sessions, Account Password dialog trigger, Encryption Password rotation screen, Conflict Resolution review, and Sign Out confirmation dialog.
   - Hosts the full **Storage and Attachments** section (all 5 options: Cloud Storage tier quota breakdown, Shared links management, Storage & Cleanup, Attached Assets inspector, and Orphaned Assets cleanup).
2. **`DefaultSettingsScreen` ([`lib/features/settings/presentation/default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart))**:
   - Consolidated with all Editor preferences: Super Editor, WYSIWYG (with `BetaBadge`), Markdown, Speech Recognition, and Smart web link toggles, alongside search and gesture preferences.
3. **`AppearanceSettingsScreen` ([`lib/features/settings/presentation/appearance_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/appearance_settings_screen.dart))**:
   - Theme Family selection (Classic Paper & Warm Paper) with live color preview swatches.
   - Appearance mode selector (System, Light, Dark).
   - Typography settings navigation row.
4. **`BackupImportSettingsScreen` ([`lib/features/settings/presentation/backup_import_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/backup_import_settings_screen.dart))**:
   - Import section: Markdown folders and file picker.
   - Local Backup & Restore section: On-demand backup creation, restoration from archive, daily auto-backup switch, retention schedule dropdown, and optional password encryption.
5. **`GeneralAdvancedSettingsScreen` ([`lib/features/settings/presentation/general_advanced_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/general_advanced_settings_screen.dart))**:
   - Advanced Maintenance: Download All Attachments, Rerun OCR for All Files, Rebuild Search Index.
   - Desktop OCR (Ollama): Endpoint configuration and model selector (Linux, macOS, Windows).
   - Sample Notes: Initial database population helper.
   - Debug: Web link preview cache diagnostic toggles.
6. **`AboutAppScreen` ([`lib/features/settings/presentation/about_app_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/about_app_screen.dart))**:
   - Author Hero Card: Remote image loading with progressive indicator and graceful fallback icon.
   - Attribution: *"Designed and developed by Sudip Mandal"* and link button to `https://blackpiratex.com`.
   - Editorial Overview: Full description of Quiet Paper's zero-knowledge cryptography and calm distraction-free offline design.
   - Resource Links: Direct link tiles to Author Blog (`https://blackpiratex.com/blog`), GitHub Repository (`https://github.com/blackpirateapps/quitepaper`), Terms of Service, and Privacy Policy.

#### D. Remote Backend Asset Optimization
- Stored author hero image at [`backend/public/images/DSC01473-3.jpg`](file:///home/dog/git/quitepaper/backend/public/images/DSC01473-3.jpg).
- Compressed 24-megapixel 6.4MB raw image to a 1200px width 300KB progressive JPEG, optimizing mobile bandwidth while preserving high visual fidelity on Retina displays.
- Excluded from Flutter `pubspec.yaml` assets so the APK package size remains minimal.

### 3. Verification & Quality
- **Static Analysis**: `flutter analyze` completed with **0 issues found** (zero errors, zero warnings).
- **Automated Test Suites**:
  - `test/settings/settings_screen_test.dart` (17 tests passed): Navigation to all new sub-screens, 3-row Cloud Sync constraint, unauthenticated and authenticated layouts, tablet responsiveness.
  - `test/settings/default_settings_test.dart` (14 tests passed): Editor style radio options, gestures, compression presets, and persistence.
  - `test/settings/advanced_maintenance_settings_test.dart` (5 tests passed): Advanced maintenance actions and progress sheets.
  - `test/settings/desktop_ollama_ocr_settings_test.dart` (4 tests passed): Desktop Ollama OCR configuration.
  - `test/settings/settings_cloud_storage_row_test.dart` (3 tests passed): Cloud Storage row in `SyncAdvancedSettingsScreen`.
  - `test/theme/theme_engine_test.dart` (23 tests passed): Theme engine and appearance settings.

---

## 24. Opaque Surface Backgrounds on Mobile Bottom Sheets & Overflow Layout Fix

### Problem & Root Cause
On mobile viewports (Android/iOS), several modal presentation sheets rendered with a completely transparent background:
1. **Typography Settings Font Chooser (`FontPickerSheet`)**:
   - `FontPickerSheet` and `GoogleFontsSheet` presented via `QuietAdaptiveModal.show(type: AdaptiveModalType.spotlight)` on mobile use `DraggableScrollableSheet`.
   - `QuietAdaptiveModal.show` on touch platforms defaults modal bottom sheet backgrounds to `Colors.transparent` for non-popover types to permit custom rounded card containers and child draggable sheets.
   - However, `FontPickerSheet` and `GoogleFontsSheet` built their content columns directly inside `DraggableScrollableSheet` without an opaque `Material` or `Container(color: colors.surface)` wrapper. Consequently, the sheet was 100% transparent and floated directly over the settings screen behind it.
   - Additionally, the top header row in `FontPickerSheet` previously placed the full-title text and two expanded `TextButton.icon` widgets ("Google Fonts" and "Import .ttf") in an unconstrained `Row`, which overflowed by 44px on standard $\le 400\text{dp}$ mobile screens.
2. **Attachment Inspector Sheets (`AttachmentDetailsSheet` & `AttachmentFileInfoSheet`)**:
   - Both sheets included a surface background container only when docked inside `EditorInspectorPane` (`isInInspector == true`).
   - When presented modally on mobile bottom sheets (`!isDesktop && !isInInspector`), they returned `content` directly without a surface container, resulting in transparent sheets.
3. **Share Visibility Sheet (`_VisibilityPicker` in `manage_shares_screen.dart`)**:
   - `_VisibilityPicker` returned a plain `SafeArea(child: Column(...))` without a container or drag handle on mobile.

### Solution
1. **Opaque Rounded Material Surface Wrappers**:
   - Wrapped `DraggableScrollableSheet` builders in [`font_picker_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/font_picker_sheet.dart) and [`google_fonts_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/google_fonts_sheet.dart) in `Material` with `color: colors.surface`, `borderRadius: const BorderRadius.vertical(top: AppRadii.rLg)`, `clipBehavior: Clip.antiAlias`, and `SafeArea(top: false)`. Using `Material` ensures proper `ListTile` splash/ink response without framework assertion warnings.
   - Wrapped mobile layouts (`!isDesktop && !isInInspector`) in [`attachment_details_sheet.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/attachment_details_sheet.dart) and [`attachment_file_info_sheet.dart`](file:///home/dog/git/quitepaper/lib/core/attachments/presentation/attachment_file_info_sheet.dart) with `Material(color: colors.surface, borderRadius: BorderRadius.vertical(top: AppRadii.rLg))`.
   - Updated `_VisibilityPicker` in [`manage_shares_screen.dart`](file:///home/dog/git/quitepaper/lib/features/share/presentation/manage_shares_screen.dart) with `AdaptiveSheetDragHandle`, title header, and `Material(color: colors.surface, borderRadius: BorderRadius.vertical(top: AppRadii.rLg))`.
2. **Mobile Header Layout & Overflow Prevention**:
   - In `FontPickerSheet`, constrained the title with `maxLines: 1` and `TextOverflow.ellipsis`.
   - On narrow mobile screens, shortened action button labels to `'Google'` and `'Import'` with compact tap padding to prevent any RenderFlex overflow.
3. **Automated Verification**:
   - Created [`test/settings/font_picker_sheet_test.dart`](file:///home/dog/git/quitepaper/test/settings/font_picker_sheet_test.dart) covering mobile surface background rendering for both `FontPickerSheet` and `GoogleFontsSheet`.
   - Added widget test coverage in [`test/widgets/quiet_adaptive_modal_test.dart`](file:///home/dog/git/quitepaper/test/widgets/quiet_adaptive_modal_test.dart) verifying `AttachmentFileInfoSheet` surface rendering.
   - Synchronized legacy Settings navigation journeys in [`test/widget_test.dart`](file:///home/dog/git/quitepaper/test/widget_test.dart) to reflect the sub-page structure ("Appearance" and "Backup and import").
   - Verified 0 issues with `flutter analyze`.

---

## 25. Revert of WhatsApp Chat Formatting Feature

### Overview
Reverted repository state to commit `9138944b1c748f3fad5619011ee67d8ab95791be` (`fix(ui): restore opaque surface backgrounds on mobile bottom sheets`), undoing the WhatsApp chat formatting and editorial block rendering features previously introduced across commits `569c1bd`, `fb5c94a`, and `8930a29`.

### Reverted Changes
- Removed WhatsApp formatter feature module (`lib/features/whatsapp_formatter/`).
- Removed `WhatsAppChatNode` block component, builders, and serializers from Super Editor (`lib/features/editor/presentation/widgets/super_editor/whatsapp_chat_component.dart`).
- Reverted WhatsApp code block interception in Markdown preview (`lib/core/markdown/quiet_code_block_element_builder.dart` and `lib/core/markdown/markdown_preview.dart`).
- Reverted `WhatsAppChatBlock` AST definition, parser, and serializer in WYSIWYG editor mode (`lib/features/editor/domain/rich_block.dart`, `lib/features/editor/application/rich_document_parser.dart`, `lib/features/editor/application/rich_document_serializer.dart`, and `lib/features/editor/presentation/widgets/rich_editor_surface.dart`).
- Reverted inline suggestion banner and editor detection hooks (`lib/features/editor/presentation/editor_screen.dart`).
- Reverted WhatsApp formatting badge indicator from note list tiles (`lib/features/notes/presentation/widgets/note_list_tile.dart` and `lib/features/notes/domain/note_metadata_extractor.dart`).
- Removed dedicated test suite under `test/whatsapp/`.

### Automated Verification
- Static analysis: `flutter analyze` (**0 issues found**).
- Test suite: `flutter test` (**2208/2208 tests passed**).

---

## 26. Markdown Preview Web Link & Bullet List RenderFlex Overflow Fix

### Problem & Root Cause
In `QuietMarkdownPreview`, `WebLinkElementBuilder` and `LinkPreviewElementBuilder` (fallback path when smart web links are disabled or decode fails) paired the link display text with an interactive manual enhancement button (`LinkEnhanceButton`) inside a horizontal `Row(mainAxisSize: MainAxisSize.min, children: [Text(text), LinkEnhanceButton(...)])`:
1. **Unconstrained Child Layout in `Row`**: In Flutter's `Row` flex container, non-flexible children (such as `Text(text)` without `Flexible` or `Expanded`) are measured with unbounded horizontal constraints (`maxWidth: double.infinity`).
2. **Long URLs in Bullet Lists**: When notes contained long URLs (e.g. social sharing links with lengthy query parameters like `https://www.facebook.com/sharer/sharer.php?u=...` or `https://twitter.com/intent/tweet?url=...` inside markdown bulleted lists `* https://...`), the single-word URL string exceeded the available width of the list item.
3. **RenderFlex Overflow Assertion**: Because `Text` was unconstrained, the total width of `Text` + `LinkEnhanceButton` exceeded the available layout width, causing Flutter's `RenderFlex` to throw layout overflow exceptions (e.g., `A RenderFlex overflowed by 50 pixels on the right`, `A RenderFlex overflowed by 34 pixels on the right`) and display yellow-and-black diagonal hazard striping.

### Solution
1. **Flexible Text Constraints in `WebLinkElementBuilder` ([`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart))**:
   - Wrapped `Text(text, style: linkStyle)` inside `Flexible(child: Text(...))` within `WebLinkElementBuilder`'s `Row`.
   - On narrow mobile viewports and inside constrained list-item containers, the link text is properly constrained to the remaining available space after reserving room for `LinkEnhanceButton`.
2. **Defensive Flexible Wrapper in `LinkPreviewElementBuilder` ([`lib/core/markdown/markdown_preview.dart`](file:///home/dog/git/quitepaper/lib/core/markdown/markdown_preview.dart))**:
   - Wrapped `InkWell(child: Text(label, ...))` inside `Flexible(child: ...)` within `LinkPreviewElementBuilder`'s fallback row for unbaked or disabled preview links with long titles/URLs.
3. **Automated Regression Test Suite ([`test/markdown/markdown_link_overflow_test.dart`](file:///home/dog/git/quitepaper/test/markdown/markdown_link_overflow_test.dart))**:
   - Added automated widget tests parameterized for narrow mobile viewports (360dp width) reproducing the exact note structure with multi-query URL bullet points and unbaked link fallbacks, verifying zero `RenderFlex` overflow assertions.

### Automated Verification
- Static analysis: `flutter analyze` (**0 issues found**).
- Full Flutter test suite: `flutter test` (**2210/2210 tests passed**).
- Backend test suite: `cd backend && npm test` (**122/122 tests passed across 19 suites**).

---

## 27. PDF Viewer Mobile Zoom Lag Elimination & 12x Max Zoom Range Extension

### Problem & Root Cause
Users reported that inside the document PDF viewer (`DocumentViewerScreen`), pinch-to-zoom was laggy and sluggish on mobile devices, and that the viewer did not permit zooming in far enough:
1. **Unbounded Full-Screen Widget Rebuilds on Page Scroll/Boundary Crossing**:
   - `DocumentViewerScreen.build()` subscribed to `onPageChanged: (details) => setState(() => _selectedPageIndex = details.newPageNumber - 1)`.
   - Every time a user scrolled or zoomed past a page boundary, `setState` rebuilt the entire `DocumentViewerScreen` widget tree (Scaffold, AppBar, Top/Bottom overlay action bars, Floating Annotation Palettes, and `SfPdfViewer`).
2. **Synchronous Multi-Megabyte Buffer Equality Checks on Touch Events**:
   - `SfPdfViewer.memory(...)` creates a fresh `BytePDFSource` instance on every build invocation.
   - Because `BytePDFSource` lacks identity/value memoization, `SfPdfViewerState.didUpdateWidget` triggered an internal `_compareDocument` call executing `listEquals(oldBytes, newBytes)` comparing millions of raw bytes synchronously on Flutter's main UI thread during gesture tracking.
3. **ScrollHead Gesture Arena Conflict on Mobile Touchscreens**:
   - `SfPdfViewer` was instantiated with `canShowScrollHead: true` unconditionally.
   - On mobile screens, this renders a 48px vertical draggable scroll handle along the right edge of the viewport. During pinch-to-zoom and multi-finger pan interactions, this handle competed in Flutter's `GestureArena`, intercepting touch pointer events and causing stuttering and dropped frames.
4. **Constrained Default Zoom Ceiling**:
   - `SfPdfViewer` defaults `maxZoomLevel` to `3` (300%). For dense PDF documents, technical schematics, contracts, or scanned papers, 3x is insufficient for fine legibility.

### Solution & Architectural Improvements
1. **Targeted ValueNotifier Decoupling (`ValueNotifier<int> _selectedPageIndexNotifier`)**:
   - Replaced state variable `_selectedPageIndex` and `setState` in `onPageChanged` with an isolated `ValueNotifier<int> _selectedPageIndexNotifier`.
   - The AppBar page indicator (`Page X of Y`) now listens via `ValueListenableBuilder<int>`, updating the subtitle text in isolation without rebuilding the Scaffold, Body, or `SfPdfViewer`.
2. **Persistent Document Source Memoization (`PDFSource _cachedPdfSource`)**:
   - Replaced dynamic instantiation of `SfPdfViewer.memory(...)` with `SfPdfViewer(source: _cachedPdfSource!, ...)`.
   - `_cachedPdfSource` is instantiated once when PDF bytes are loaded or re-annotated and reused across widget updates.
   - This completely eliminates `listEquals` main-thread byte comparisons during gestures.
3. **Platform-Aware Scroll Head Policy**:
   - Configured `canShowScrollHead: isDesktop` and `canShowScrollStatus: isDesktop` using `PlatformLayoutHelper.isDesktop(context)`.
   - On mobile touchscreens (Android & iOS), the touch-intercepting scroll head is disabled, giving pinch-to-zoom full gesture arena priority. On desktop platforms (Linux, macOS, Windows, Web), the desktop scrollhead is retained for mouse drag interaction.
4. **12x Max Zoom Level & High-DPI Tiling**:
   - Defined `kPdfViewerMaxZoomLevel = 12.0` (1200% zoom) and `kPdfViewerMinZoomLevel = 1.0`.
   - Syncfusion's native tiling engine automatically fetches high-resolution tile images (`getTileImage`) for the visible viewport without ballooning raster memory.
5. **Floating Quick-Zoom Controller Pill**:
   - Added `_buildFloatingZoomPill` providing one-tap Zoom Out (`-`), live Zoom Percentage badge (e.g. `100%`, tap to reset to 1.0x), and Zoom In (`+`).
   - Integrated `_zoomLevelNotifier` hooked into `SfPdfViewer.onZoomLevelChanged` to update the badge dynamically without rebuilding the PDF viewport.
   - Automatically hides when the annotation palette or drawing mode is active to preserve screen real estate.
6. **Automated Verification**:
   - Created comprehensive unit & widget tests in [`test/documents/document_viewer_zoom_test.dart`](file:///home/dog/git/quitepaper/test/documents/document_viewer_zoom_test.dart) testing:
     - Configuration of `maxZoomLevel: 12.0` and mobile scrollhead suppression.
     - Quick-zoom pill 1.35x step increments/decrements and tap-to-reset behavior.
     - Page navigation isolation via `_selectedPageIndexNotifier` without viewer reconstruction.
     - Automatic hiding of quick-zoom controls when entering annotation mode.
   - Restored the page-count value in the AppBar subtitle (`Page 1 of 3 (3 pages)`) after the `ValueListenableBuilder` refactor.
   - Verified 0 issues with `flutter analyze` and 2224/2224 passing Flutter tests.

---

## 28. Notes Multi-Select & Batch Actions

### Overview
Added first-class multi-select to the notes list on phone and tablet, with batch operations for archive, trash, permanent delete, restore, unarchive, pin/unpin, tag, and export.

### Entry Points
1. **Mobile**:
   - Long-press any note to enter selection mode with that note selected.
   - Choose **Select notes** from the overflow menu.
   - Choose **Select** from a note's long-press context menu (search/tag surfaces).
   - The former top-bar **Select** text action next to the new-note and search icons has been removed; selection mode remains reachable via long-press and the overflow menu.
2. **Desktop**:
   - Ctrl/Cmd+click to toggle individual notes.
   - Shift+click to select a contiguous range from the anchor note.
   - Ctrl/Cmd+A selects all notes in the current view; Escape, Delete, and Ctrl/Cmd+Shift+A provide select-all, trash, and archive shortcuts.
3. **Tablet**:
   - Selecting a note replaces the middle-pane header with a selection header containing the count, close button, and batch action buttons.
4. **Exit behavior**:
   - The close button, Escape, system back, or changing destination/tag exits selection mode.
   - The FAB and swipe-to-dismiss gestures are disabled while selecting.

### Batch Actions
- **Archive / Trash**: `_archiveSelected` and `_trashOrDeleteSelected` perform batch persistence and remove affected notes locally.
- **Trash view**: batch restore and permanent delete with the existing confirmation dialog.
- **Archive view**: batch unarchive and move to Trash.
- **More menu**: Pin/Unpin (respecting the active tag scope), Add tag (skips notes that already have the tag), and Export.
- **Export**: a single selected note opens the existing export sheet; multiple notes produce a ZIP of Markdown files, skipping password-protected notes and de-duplicating filenames.
- **Pluralized feedback**: single-note actions report `Note archived`, `Note moved to Trash`, `Note pinned`, etc., while multi-note actions report `N notes archived`, etc.

### Focus & Keyboard Handling
- Added `_multiSelectFocusNode`, requested when entering selection mode and placed inside `CallbackShortcuts`, so Escape/Ctrl+A shortcuts receive key events even when no list child owns focus.
- Multi-select shortcuts only act while selection mode is active, preserving editor Ctrl+A behavior.

### Regression Fixes & Tests
- Updated legacy `test/widget_test.dart` archive/trash/pin flows for the new mobile long-press-to-select UX.
- Added [`test/notes/notes_multi_select_test.dart`](file:///home/dog/git/quitepaper/test/notes/notes_multi_select_test.dart) covering entry points, Escape/destination exits, batch archive/trash, and `NoteListTile` long-press/context-menu callbacks.
- Removed the `_NotesSelectTextAction` widget from both the phone AppBar and tablet list header; the app-bar test now asserts the text action is absent while the overflow-menu entry point remains covered.
- Automated verification: `flutter analyze` (**0 issues**) and `flutter test` (**2224/2224 tests passed**).

---

## 29. Local-First Storage & Assets

### Overview
The **Storage & Assets** page (formerly the cloud-only Attached/Orphaned lists) now merges encrypted Drift rows with the backend cloud resource listing. On-device assets render immediately, including while offline or signed out; cloud metadata fills in best-effort and never blocks the local view.

### Models & Providers
- Added [`lib/core/storage/storage_asset_models.dart`](file:///home/dog/git/quitepaper/lib/core/storage/storage_asset_models.dart):
  - `StorageAssetType` (`attachment` / `document`).
  - `StorageAssetSyncState` with display labels `Synced`, `Local only`, `Cloud only`, `Upload pending`, `Upload failed`.
  - `StorageAssetItem`, which unifies local attachment/document entities with optional cloud resources and tracks `existsLocally`, `existsInCloud`, parent note, orphan grace state, and sync state.
  - `StorageLocalAssets`, `StorageCloudResources`, and `StorageAssetsSnapshot.merge()`.
- `StorageManagementService.getLocalStorageAssets()` scans all attachment rows, document rows, and note content once. Deleted rows and internal `linkPreview` records are excluded. Reference detection uses the same `qp://(?:attachment|asset)/<uuid>` and `qp://document/<uuid>` patterns as sync.
- Providers in [`storage_management_service.dart`](file:///home/dog/git/quitepaper/lib/core/storage/storage_management_service.dart):
  - `localStorageAssetsProvider` resolves without network access.
  - `cloudStorageResourcesProvider` returns `StorageCloudResources.unavailable(...)` on failure, uses an 8-second timeout, and skips the request for signed-out users.
  - `storageAssetsProvider` merges by `type:id`, keeping local rows visible while the cloud request is pending or failed.
- Merge rules: an asset is Attached when a note references it locally **or** the cloud status is `referenced`; otherwise it is Orphaned. Local + cloud becomes `Synced`; local-only derives its badge from `uploadState`; remote-only becomes `Cloud only`. Local unreferenced rows are immediately eligible for permanent deletion.

### UI Changes
- [`storage_management_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/storage_management_screen.dart) is now titled **Storage & Assets**.
- The Overview tab shows an **On This Device** summary (`localBytes`, total/attached/orphaned/in-cloud counts), the cloud profile breakdown, and a non-blocking offline banner with **Retry**.
- Attached/Orphaned tabs show real filenames, type/size, resolved icons for images/files/audio/documents, full status badges, grace-period subtitles, empty states, and pull-to-refresh.
- Tapping any tile opens the new adaptive [`StorageAssetDetailsSheet`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/widgets/storage_asset_details_sheet.dart) with:
  - Location, type, added/updated, parent-note title, orphan status, and SHA-256 prefix.
  - Explicit Preview for images, scanned documents, and text/code/Markdown/CSV.
  - External open for generic binary, audio, and PDF attachments.
  - Download to device for cloud-only items, Share, Save to storage, Rename for local attachments, and confirmed permanent deletion for orphaned items.
- Cloud-linked deletion failure offers **Remove from device only**, leaving the encrypted cloud copy for backend GC.
- Updated the Attached/Orphaned subtitles in `sync_advanced_settings_screen.dart` and `cloud_storage_screen.dart`.

### Local Purge & Deletion
- Added `AttachmentService.purgeLocalAttachment()` and `DocumentService.purgeLocalDocument()`: invalidate decrypted caches, delete original/variant `.enc` (and document `.qpd`/annotated files), delete variants/OCR/annotation rows, remove pending sync-queue entries, and delete the Drift row.
- Added `AppDatabase.deleteAttachmentVariants()` and `removeSyncQueueEntriesForEntity()`.
- `StorageManagementService.deleteOrphanedAsset()` / `deleteOrphanedResource()` delete cloud objects (unless device-only) and purge local data. Local-only assets are purged immediately; remote-only assets only hit the backend.

### Backend Metadata
- `/api/v1/storage/resources` now returns `fileName` and `kind` for attachments, uses `file_name` as the title when present (instead of hardcoded `"Image Attachment"`), excludes `linkPreview` rows, and reports `kind: 'document'` for scanned documents.
- `StorageResourceItem` in Flutter parses the optional `fileName`/`kind` fields with backward-compatible constructors.

### Cloud-Only Viewer Regression
- `AttachmentViewerScreen._loadAttachment()` re-fetches the Drift entity after `resolveAsset()`, so a cloud-only text attachment detects its real filename and text format on the first open instead of falling back to an unknown binary.

### Tests & Verification
- Added [`test/storage/storage_assets_test.dart`](file:///home/dog/git/quitepaper/test/storage/storage_assets_test.dart): 13 merge/classification and local-purge tests covering local-only, synced, remote-only, orphaned, offline cloud failure, link-preview exclusion, audio, documents, upload failure, cloud+local deletion, and device-only deletion.
- Expanded [`test/storage/storage_management_test.dart`](file:///home/dog/git/quitepaper/test/storage/storage_management_test.dart): offline local-only rendering, details-sheet routing, all five badge labels, and delete-confirmation UI.
- Added [`test/attachments/attachment_viewer_cloud_only_test.dart`](file:///home/dog/git/quitepaper/test/attachments/attachment_viewer_cloud_only_test.dart) for the cloud-only filename/format regression.
- Extended backend `lifecycle.test.ts` to assert attachment `fileName`/`kind`/title and document `kind`.
- Verified `flutter analyze` (**0 issues**), `flutter test` (**2242/2242 tests passed**), backend `npm test` (**122/122 tests passed**), and backend `npm run build`.


---

## 30. Manual-Only PDF OCR Processing Policy

### Overview
When a PDF document is imported into Quiet Paper or attached to a note (via file attachment, pasting, drag-and-drop, or creating a note from a PDF file), OCR processing is now strictly manual-only. Background OCR recognition is no longer automatically triggered upon import or note attachment.

### Key Changes
1. **Explicit `autoRunOcr` Control ([`lib/core/documents/document_service.dart`](file:///home/dog/git/quitepaper/lib/core/documents/document_service.dart))**:
   - Added optional `bool? autoRunOcr` to `DocumentService.createDocumentFromPdfBytes`.
   - Resolves `shouldAutoRunOcr = autoRunOcr ?? (source == DocumentSource.scanner)`. For all imported PDFs (`DocumentSource.importedPdf`), automatic OCR execution is disabled by default.
   - `DocumentService.importPdfFile` sets `autoRunOcr: false` by default.
   - Initial `ocrState` is set to `OcrProcessingState.notRequested` (`'not_requested'`) rather than `'queued'`.
   - The asynchronous background OCR task (`processingService!.processDocument(...)`) is only enqueued if `shouldAutoRunOcr` is explicitly true and `!skipOcr`.
2. **UI & Card Experience**:
   - Note editor and markdown preview cards (`QuietDocumentCard`) display page count and clean file size (e.g. `2 pages • 1.4 MB`) without unwanted `"Processing text…"` banners.
   - In [`DocumentViewerScreen`](file:///home/dog/git/quitepaper/lib/core/documents/presentation/document_viewer_screen.dart), imported PDFs display the editorial `'PDF'` badge pill.
   - The top AppBar features a dedicated `"Run OCR"` icon button (`Icons.document_scanner_outlined`).
   - Tapping `"Run OCR"` or selecting `"Run / Regenerate OCR"` from the overflow menu starts on-demand text extraction in the background with snackbar feedback, seamlessly updating the badge to `'Searchable (OCR)'` and unlocking `"View OCR Text"` once completed.
3. **Automated Verification**:
   - [`test/documents/document_service_test.dart`](file:///home/dog/git/quitepaper/test/documents/document_service_test.dart): Verified that imported PDFs initialize with `ocrState: 'not_requested'` and that `createDocumentFromPdfBytes` respects `autoRunOcr` configuration.
   - [`test/ocr/ocr_manual_policy_test.dart`](file:///home/dog/git/quitepaper/test/ocr/ocr_manual_policy_test.dart): Verified that `DocumentService` imported PDF initialization skips recognition calls without explicit user request.
   - [`test/documents/document_viewer_ocr_menu_test.dart`](file:///home/dog/git/quitepaper/test/documents/document_viewer_ocr_menu_test.dart): Verified viewer badge and OCR trigger flows.

---

## 227. Nested Tag Hierarchy with Path-Based Identity (October 2026)

### Overview
Tags now support slash-separated hierarchy (`#work/projects/alpha`) using the **full normalized path as the canonical identity**. No `parentId` column or parallel folder model was added: every tag remains an ordinary synced entity whose name contains its full path, and parent/child relationships are derived in memory. This keeps offline creation, Markdown parsing, imports, and encrypted sync convergent without a schema migration.

### Domain Model
- Added [`lib/features/tags/domain/tag_path.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_path.dart) with `TagPath.parse` / `tryParse`, `segments`, `leaf`, `parent`, `ancestors`, `breadcrumb`, `token`, and descendant checks. `/` separates segments; empty, leading, trailing, or invalid segments are rejected. Validation reuses `TagParser` rules, including the existing case-folding and Unicode behavior. No new NFC normalization was introduced.
- Added [`lib/features/tags/domain/tag_tree.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_tree.dart) as a derived presentation model. It synthesizes implicit ancestors deterministically when only a legacy child row exists, without persisting rows. `Tag` gained `isImplicit` / `isNew`, and `TagWithCount` gained `isImplicit`.
- `TagParser.isValidTag` now validates each path segment individually. Hashtag extraction and Markdown rewrites remain segment/path-prefix aware, so renaming or removing `work` never touches `workflow` or `work/projects`.

### Database & Filtering
- `createTag` / `ensureTagPathExists` create every missing ancestor in one transaction and reuse existing rows. Only the requested leaf receives the supplied icon, color, and pin metadata; ancestors are created dirty but are never implicitly assigned to notes.
- `watchNotes(filterTag: ...)` and the notes query executor match the selected path plus all descendants using exact equality and an escaped `LIKE 'path/%'` predicate (`escapeChar: '\'`). Notes are deduplicated and textual prefixes such as `workflow` are excluded.
- `watchAllTagsWithCount` computes subtree counts as **distinct active notes** and synthesizes implicit ancestors with deterministic IDs. `getAllTagNames` includes ancestor paths for autocomplete and validation.
- Branch operations are transactional locally:
  - `renameTag` renames the whole subtree in place, preserves IDs/metadata/assignments, rewrites Markdown and YAML frontmatter segment-aware, and removes old ancestors that become unused.
  - `deleteTag` defaults to deleting the branch; `TagBranchDeleteMode.moveChildrenUp` promotes direct children and preserves their IDs. Collisions roll back.
  - `moveTag` reparents a branch (or promotes it to the top level), while `mergeTags` folds a branch into a destination and reconciles conflicting target names by re-pointing note assignments.
- Orphan cleanup now preserves tags that still have live descendants. Distributed atomicity is deliberately not claimed for renames/moves/merges; each affected tag syncs as its own entity.

### Navigation & UI
- Sidebar tag section and tag browser render expandable trees with leaf names, indentation, and full accessible paths. Expansion state persists locally through `ExpandedTagPathsNotifier`. Pinned tags remain a flat, reorderable section.
- `TagContextHeader` shows the leaf in the title and the full breadcrumb underneath for nested tags.
- Note chips display only the leaf. Tapping a nested chip opens a disclosure showing the full breadcrumb and an **Open tag** action; flat chips keep direct navigation. Chip semantics now announce the full path exactly (`#work/projects/alpha, nested tag`).
- Inline tag autocomplete offers a synthetic **Create #path** candidate for missing valid nested paths, while existing tags keep precedence. Flat unknown queries preserve the legacy no-create behavior.
- Rename/delete/merge dialogs and sidebar/browser actions remain available. Branch deletion offers delete-branch or move-children-up choices when descendants exist.

### Markdown Import
- Folder-derived tags remain flat by default. A new local preference (`import_mirror_folder_hierarchy`) and a per-import toggle opt into a single deepest nested tag derived from the folder path (for example `articles/wikipedia`). Existing picked-file imports remain flat.

### Sync
- The full path stays inside the encrypted tag name; each ancestor is an ordinary synced entity. When a remote child arrives before its ancestors, `upsertSyncedTag` hydrates missing local ancestors as dirty entities without resurrecting existing tombstones. Duplicate-name reconciliation, revision handling, and dirty states are preserved.
- Expansion and selection state are local-only and never enter sync payloads.

### Migration
- `beforeOpen` runs `_backfillTagHierarchy`, which creates missing ancestors for existing tags containing `/`. It preserves IDs, metadata, assignments, and note content; generated ancestors are marked dirty. A `sync_metadata` marker (`tag_hierarchy_backfill_v1`) makes the pass idempotent. Malformed legacy paths are left untouched. Drift schema version remains **20**.

### Tests & Verification
- Added `test/tags/tag_path_test.dart`, `test/tags/tag_tree_test.dart`, `test/tags/tag_hierarchy_database_test.dart`, and `test/tags/tag_hierarchy_ui_test.dart`.
- Extended parser, search/autocomplete, import scanner, sync, and tag dialog tests for nested paths, branch operations, child-before-ancestor sync, duplicate reconciliation, tombstones, migration, and accessibility.
- Sequential verification: `flutter analyze` (**0 issues**) and `flutter test` (**2326/2326 tests passed**).

---

## 228. Tag Picker on '#', Full Path Note Display, and Deferred Tag Creation (October 2026)

### Overview
Addressed three tag UX issues in the editor:
1. **Tag Picker on `#`**: Typing `#` alone now immediately triggers the inline tag autocomplete picker showing all known tags, instead of requiring a character to be typed first.
2. **Full Path Tag Display in Opened Notes**: When a note is opened in the editor or preview mode, tag chips in the note header bar display their full hierarchical path (e.g. `#journal/daily` or `#work/projects`) rather than truncating to only the leaf name (`#daily`).
3. **Deferred Tag Creation While Typing**: In-body tags typed into note content are no longer extracted or added to the note tags bar prematurely while typing. The tag is only committed once terminated by whitespace (`Space`, `Enter`/newline) or delimiter/punctuation.

### Implementation Details
1. **Tag Picker Autocomplete Trigger**:
   - In [`lib/features/editor/application/tag_autocomplete_trigger.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/tag_autocomplete_trigger.dart), relaxed `cursor < 2` to `cursor < 1` and permitted `queryStart == queryEnd` (`query: ''`).
   - When `#` is typed alone at line start or after whitespace, `TagAutocompleteTrigger` emits a trigger with `query: ''`.
   - In [`lib/features/editor/application/tag_search_service.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/tag_search_service.dart), empty queries (`query: ''`) rank and return all available existing and inline tags up to `limit` sorted by `isPinned DESC, noteCount DESC, name ASC`.
   - Maintained `# ` space termination and ATX heading suppression (`##`..`######` at line start) so markdown headings remain unhindered.
2. **Full Tag Path in Opened Notes**:
   - In [`lib/core/widgets/quiet_tag_chip.dart`](file:///home/dog/git/quitepaper/lib/core/widgets/quiet_tag_chip.dart), added `showFullPath: bool` (default `false`). When `true`, renders `TagParser.formatDisplay(tag)` and skips the disclosure popup since the full path is already visible.
   - In [`lib/features/editor/presentation/widgets/tag_editor_bar.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/tag_editor_bar.dart), added `showFullPath: bool` (default `true`) and passed it to all child `QuietTagChip` instances.
   - Opened notes in `EditorScreen`, `FrontmatterPropertiesSection`, and `MarkdownPreview` render the complete hierarchical tag path. Compact multi-note list tiles (`NoteListTile`) retain `showFullPath: false` with tap disclosure.
3. **Deferred In-Body Tag Extraction & Persistence**:
   - In [`lib/core/utils/tag_parser.dart`](file:///home/dog/git/quitepaper/lib/core/utils/tag_parser.dart), introduced `_tagWithTerminatorRegex` and `requireTerminator: bool = false` on `TagParser.extractTags`. When `requireTerminator: true`, hashtags must be followed by whitespace (`\s`) or closing punctuation/delimiters, omitting end-of-string lookahead `|$`.
   - In [`lib/features/editor/application/editor_provider.dart`](file:///home/dog/git/quitepaper/lib/features/editor/application/editor_provider.dart), debounced autosave (`saveNow`) uses `requireTerminator: true` when scanning content. In-progress typing spans (e.g. `#t`, `#ta`) are not extracted or merged into `state.note.tags`.
   - In [`lib/core/database/app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart) and [`lib/features/notes/data/notes_repository.dart`](file:///home/dog/git/quitepaper/lib/features/notes/data/notes_repository.dart), added `preserveEmptyTags: bool = false` to `saveNote`. When `EditorNotifier` saves with an explicitly empty tag set, the database respects it without triggering legacy fallback tag extraction from unterminated markdown content.
4. **Automated Verification**:
   - Updated `test/editor/tag_autocomplete_trigger_test.dart` and `test/editor/tag_search_service_test.dart` for `#` trigger and empty query candidate rankings.
   - Added `test/editor/tag_inline_menu_test.dart` coverage for empty-query inline menu rendering and full-path `TagEditorBar` chip display.
   - Added `test/utils/tag_parser_test.dart` and `test/editor/editor_provider_tag_test.dart` coverage for `requireTerminator: true` and deferred tag creation on space / enter.
   - Synchronized `test/editor/wysiwyg_autocomplete_test.dart` and `test/editor/wysiwyg_backspace_test.dart` for immediate `#` trigger visibility.
   - Verified `flutter analyze` (**0 issues found**) and `flutter test` (**2337/2337 passing tests**).

---

## 229. Prominently Collapsible Children Tags in Sidebar and Tags Page (October 2026)

### Overview
Addressed user-reported issues where child tags were not effectively collapsible or their expanders were difficult to discover/interact with in both the navigation sidebar (`SidebarView`) and the tag browser (`TagBrowserView` / `TagBrowserSheet`). Specifically:
1. **Visible & Prominent Expand/Collapse Chevrons on the Right**: Chevrons are placed on the trailing (right) side of each tag row, styled with a 32x32 hit area, 18sp icon size, high contrast (`accent` when expanded, `textSecondary` or light grey on dark sidebar when collapsed), and rounded hover/splash feedback. Tags are collapsed by default.
2. **Sidebar Child Truncation Fix**: Expanding a root tag previously pushed total displayed items beyond the 7-tag limit (`_maxVisibleTags`), truncating children into `... and N more`. Now, visible root count is capped at 7 while all expanded descendants of visible roots are flattened inline.
3. **Sidebar Alignment & Padding Fix**: Fixed asymmetric padding in `SidebarItem` so deeper nested tags keep their trailing badges and chevrons aligned flush to the right edge.
4. **Tag Browser Layout & Alignment Cleanup**: Removed the small left-side chevron and empty placeholders in `TagBrowserView`; all tag icons align consistently to their depth indentation (`indent * 16.0`), and chevrons appear on the right side next to the note count.
5. **Implicit Parent Tag Tap Toggle**: For implicit parent tags without direct notes, tapping the entire row toggles expansion.
6. **Hierarchy Menu Actions**: Added "Expand all sub-tags" and "Collapse all sub-tags" in both the compact popup menu (`Sort and filter tags`) and the desktop/tablet header menu (`Tag hierarchy options` with `PhosphorIconsRegular.treeStructure`).

### Implementation Details
- **Domain & Application**:
  - In [`lib/features/tags/domain/tag_tree.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_tree.dart), added optional `roots` parameter to `TagTree.flatten()` to enable flattening a subset of root nodes and their descendants in linear time.
  - In [`lib/features/tags/application/tag_providers.dart`](file:///home/dog/git/quitepaper/lib/features/tags/application/tag_providers.dart), added `bool isExpanded(String path)` helper to `ExpandedTagPathsNotifier`.
- **Sidebar Presentation**:
  - In [`lib/features/sidebar/presentation/widgets/sidebar_item.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/widgets/sidebar_item.dart), changed padding from symmetric `horizontal: AppSpacing.md + (indent * 14.0)` to `left: AppSpacing.md + (indent * 16.0), right: AppSpacing.sm` to maintain right-aligned trailing controls across all nesting levels.
  - In [`lib/features/sidebar/presentation/sidebar_view.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart), updated visible tag calculation to `TagTree.flatten(tree, expandedPaths: expandedPaths, roots: tree.roots.take(_maxVisibleTags).toList())`. Promoted the trailing chevron button to 32x32 dp, 18sp icon size, with high-contrast color and tap toggle for implicit parents.
- **Tag Browser & Sheet**:
  - In [`lib/features/tags/presentation/widgets/tag_browser_view.dart`](file:///home/dog/git/quitepaper/lib/features/tags/presentation/widgets/tag_browser_view.dart), moved the expand/collapse button to the trailing position after the note count, eliminated leading placeholders for uniform icon alignment, added row tap expansion for implicit tags, and introduced "Expand all sub-tags" and "Collapse all sub-tags" actions in both compact and wide header menus.
  - In [`lib/features/sidebar/presentation/widgets/tag_browser_sheet.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/widgets/tag_browser_sheet.dart), aligned trailing expander styling to 32x32 dp, 18sp icon, and high-contrast color scheme.
- **Automated Verification**:
  - In [`test/tags/tag_hierarchy_ui_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_hierarchy_ui_test.dart), added widget tests for:
    - Expanding parent tags under `_maxVisibleTags` without child truncation.
    - Tapping implicit parent rows to toggle expansion.
    - Expanding all and collapsing all sub-tags from both wide (`Tag hierarchy options`) and compact (`Sort and filter tags`) popup menus.

---

## 230. Sidebar Most-Used Tag Ordering & Parent Subtree Count Propagation (October 2026)

### Overview
Addressed two interconnected issues where parent tags in the sidebar failed to display or showed incorrect note counts:
1. **Most Used Parent Tag Missing in Sidebar**: `SidebarView` was building `TagTree` with default alphabetical sorting (`_defaultCompare`), which caused `tree.roots.take(_maxVisibleTags)` to select the first 7 roots alphabetically (e.g. `a` through `g`). If a user had 8 or more roots and their most used parent tag started with a later letter (e.g. `#work`), it was excluded from the sidebar even when it had the most notes in the app.
2. **Missing Subtree Note Count on Parent Tags**: When parent tags were implicit (synthesized for presentation when notes were tagged with `#parent/child` without an explicit `#parent` row) or had zero direct notes, `TagTree.build` created them with `noteCount: 0`. While the Tag Browser computed subtree counts at the SQL/query level, in-memory tree derivation in `TagTree` lacked recursive subtree aggregation, causing parent tags to display `0` or drop to the bottom of usage sorts.

### Implementation Details
- **Subtree Count Propagation in `TagTree`**:
  - In [`lib/features/tags/domain/tag_tree.dart`](file:///home/dog/git/quitepaper/lib/features/tags/domain/tag_tree.dart):
    - Added `int get totalNoteCount` on `TagTreeNode` to recursively aggregate child note counts.
    - Updated `TagTree.build` to perform a post-construction bottom-up pass (`computeSubtreeCounts`) ensuring every parent node's `tag.noteCount` reflects the total active notes across its entire subtree (`max(tag.noteCount, childSum)`).
    - Exposed `TagTree.compareByUsage` (pinned first, then `noteCount DESC`, then alphabetical) and `TagTree.compareByName` (pinned first, then alphabetical).
- **Sidebar Ordering by Usage**:
  - In [`lib/features/sidebar/presentation/sidebar_view.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart), updated `TagTree.build` to use `compare: TagTree.compareByUsage`.
  - The 7 visible root slots in the sidebar now prioritize the user's most used parent tags.
  - Added fallback check to ensure that if a tag outside the top 7 is currently active (`selectedTag`), its root is included in `visibleRoots` so selection state remains visible in the sidebar.
- **Automated Verification**:
  - In [`test/tags/tag_tree_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_tree_test.dart), added unit tests verifying subtree note count propagation and `TagTree.compareByUsage` sorting.
  - In [`test/tags/tag_hierarchy_ui_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_hierarchy_ui_test.dart), verified that parent tags display their full aggregated note count and that the most used parent tag displays in the sidebar even when more than 7 root tags exist.

---

## 231. Support for Nested Tags with Numeric Segments (e.g. #journal/2026) (October 2026)

### Problem & Root Cause
When attempting to create a nested tag like `journal/2026` via the note's 3-dot overflow menu ("Add tag"), inline hashtags in markdown (`#journal/2026`), or tag creation dialogs, the tag was rejected and failed to be created.
The root cause was located in [`lib/core/utils/tag_parser.dart`](file:///home/dog/git/quitepaper/lib/core/utils/tag_parser.dart): `TagParser.isValidTag` applied a purely numeric rejection check (`int.tryParse(segment) != null`) across **every** segment of a slash-separated path. While root/standalone tags cannot be purely numeric (preventing collisions with hex colors, markdown numbers, or issue IDs like `#2026` or `#123`), sub-path segments in hierarchical tags commonly represent years, months, days, or version numbers (e.g. `journal/2026`, `finance/2024/01`, `work/project/1`).

### Solution
- **Refined Tag Validation (`lib/core/utils/tag_parser.dart`)**:
  - Confined the purely numeric rejection check (`int.tryParse(segment) != null || _pureNumericRegex.hasMatch(segment)`) strictly to the root segment (`i == 0`).
  - Permitted child segments (`i > 0`) to be purely numeric while retaining all other format invariants (non-empty, Unicode word/numeric/hyphen/underscore regex, and no leading/trailing hyphens or underscores).
- **Editor Add Tag Validation & Error Feedback (`lib/features/editor/presentation/widgets/tag_editor_bar.dart`)**:
  - Updated `TagEditorBar.showAddTagDialog` with dynamic validation and editorial error feedback if invalid characters or malformed shapes are entered, clearing on text change.
  - Updated placeholder hint text to `'e.g. ideas, journal/2026'`.
- **Automated Verification**:
  - In [`test/utils/tag_parser_test.dart`](file:///home/dog/git/quitepaper/test/utils/tag_parser_test.dart), added unit tests verifying extraction and validation of `journal/2026`, `archive/2024/01`, `work/123`, while rejecting purely numeric roots like `123` and `123/projects`.
  - In [`test/tags/tag_path_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_path_test.dart), added tests verifying `TagPath.parse('journal/2026')` correctly resolves parent and leaf segments.
  - In [`test/editor/tag_search_service_test.dart`](file:///home/dog/git/quitepaper/test/editor/tag_search_service_test.dart), verified that searching `journal/2026` produces a create candidate item.
  - In [`test/tags/tag_tree_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_tree_test.dart), verified that `TagTree.build` nests `2026` as a child node under `journal`.
  - In [`test/editor/editor_overflow_menu_test.dart`](file:///home/dog/git/quitepaper/test/editor/editor_overflow_menu_test.dart), added full widget journey test confirming that adding `journal/2026` via the 3-dot overflow menu creates the tag and its ancestor in the database and renders the `#journal/2026` tag chip.

---

## 232. Tag Browser Long-Press Menu Unification and "Add nested tag" Action (October 2026)

### Problem & Objectives
1. **Long-Press Menu Parity**: In the Tag Browser page (`TagBrowserView`), long-pressing a tag row lacked parity with the 3-dot overflow button (`dotsThreeVertical`). On desktop/tablet, `onLongPress` did not anchor to the specific row context, and haptic feedback was missing.
2. **"Add nested tag" Action**: Users needed a quick way to create sub-tags directly nested under an existing parent tag without having to manually type out full hierarchical paths from scratch.

### Implementation Details
- **Nested Tag Creation Dialog (`lib/features/tags/presentation/widgets/tag_action_dialogs.dart`)**:
  - Extended `TagCreateDialog` and added `TagCreateDialog.showNested(context, parentTag: tag, existingTags: ...)` supporting `parentTagName: String?`.
  - When `parentTagName` is specified:
    - Dialog title: **"New Nested Tag"**.
    - Input prefix: `#<parentTagName>/`.
    - Placeholder: `'sub-tag (e.g. 2026, projects)'`.
    - Automatically combines the parent path with the child segment and validates via `TagParser.isValidTag` and checks for duplicates.
    - Pre-populates the parent tag's icon and color while leaving them customizable.
- **Tag Browser View (`lib/features/tags/presentation/widgets/tag_browser_view.dart`)**:
  - Added **"Add nested tag"** (`PhosphorIconsRegular.folderPlus`) directly beneath **"Open"** in the tag options menu (`_showTagOptions`).
  - Added `_handleAddNestedTag` handler: creates the tag via `tagServiceProvider.createTag`, automatically expands the parent tag in `expandedTagPathsProvider` so the new sub-tag is immediately revealed in the hierarchy tree, and shows a confirmation SnackBar.
  - Wrapped `_buildTagRow` with a `Builder` to capture `rowContext`, invoking `HapticFeedback.mediumImpact()` and anchoring popovers directly to the clicked row.
  - Verified that long-press on both unpinned and pinned tag rows reliably presents the options menu.
- **Consistent Availability Across Tag Surfaces**:
  - **Sidebar (`lib/features/sidebar/presentation/sidebar_view.dart`)**: Added **"Add nested tag"** with `PhosphorIconsRegular.folderPlus` directly beneath "Open" for both desktop `showMenu` and mobile adaptive popovers/sheets.
  - **Tag Context Header (`lib/features/tags/presentation/widgets/tag_context_header.dart`)**: Added **"Add nested tag"** to the 3-dot popup menu at the top of note lists filtered by a tag.
- **Automated Verification**:
  - In [`test/tags/tag_dialogs_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_dialogs_test.dart), added tests verifying `TagCreateDialog.showNested` static prefix, child segment validation, duplicate checking, and nested tag entity generation.
  - In [`test/tags/tag_ui_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_ui_test.dart), added widget tests verifying that both 3-dot buttons and row long-presses open the unified menu with "Add nested tag", and that tapping it opens the nested dialog scoped under `#parent/`.
  - In [`test/tags/tag_workspace_navigation_test.dart`](file:///home/dog/git/quitepaper/test/tags/tag_workspace_navigation_test.dart), verified that "Add nested tag" appears in the Tag Context Header actions menu.
  - Static analysis: `flutter analyze` (**0 issues**).

---

## 233. Multi-Platform GitHub Release Workflow: Linux Packages (RPM, DEB, AppImage, Flatpak) (October 2026)

### Overview
Expanded the official GitHub Release workflow ([`.github/workflows/release.yml`](file:///home/dog/git/quitepaper/.github/workflows/release.yml)) to build and release native Linux distributions alongside multi-architecture Android APKs. Quiet Paper releases now automatically generate and attach 9 distinct installation binaries for every published version tag or manual workflow dispatch.

### Pipeline Architecture & Concurrency
The release pipeline is structured into 5 decoupled, concurrent jobs:
1. **`prepare`**: Checks out repository, extracts semantic version name (`VERSION_NAME`) from `pubspec.yaml`, computes monotonic build number via `git rev-list --count HEAD`, and resolves release tag and title into workflow outputs.
2. **`build-android`** *(runs in parallel with `build-linux`)*: Sets up Temurin Java 17, imports signing keystore, and compiles:
   - Modern 64-bit Android: `quiet-paper-<version>-arm64-v8a.apk`
   - Legacy 32-bit Android: `quiet-paper-<version>-armeabi-v7a.apk`
   - Chromebooks & Emulators: `quiet-paper-<version>-x86_64.apk`
   - Universal Fat APK: `quiet-paper-<version>-universal.apk`
3. **`build-linux`** *(runs in parallel with `build-android`)*:
   - Installs native build tools: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `liblzma-dev`, `libsqlite3-dev`, `libsecret-1-dev`, `libgstreamer1.0-dev`, `gstreamer1.0-plugins-*`, `rpm`, `curl`, `file`, and `dpkg`.
   - Compiles release bundle: `flutter build linux --release`.
   - Packages portable tarball: `quiet-paper-<version>-linux-x64.tar.gz`.
   - Compiles native RPM: `quiet-paper-<version>-1.x86_64.rpm` via `rpmbuild` and [`linux/packaging/quietpaper.spec`](file:///home/dog/git/quitepaper/linux/packaging/quietpaper.spec) with dynamic version injection (`--define "app_version <version>"`).
   - Compiles native Debian package: `quiet-paper-<version>-amd64.deb` via [`linux/packaging/build_deb.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_deb.sh).
   - Compiles native AppImage: `Quiet_Paper-<version>-x86_64.AppImage` via [`linux/packaging/build_appimage.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_appimage.sh).
   - Prepares and uploads Flatpak staging bundle with desktop entries, metainfo, and 256x256 / 512x512 icons via [`linux/packaging/build_flatpak.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_flatpak.sh).
4. **`build-flatpak`**:
   - Executes inside the official privileged container: `ghcr.io/flathub-infra/flatpak-github-actions:gnome-47`.
   - Downloads staged release bundle and compiles `quiet-paper-<version>-x86_64.flatpak` via `flatpak/flatpak-github-actions/flatpak-builder@v6` against [`linux/packaging/com.blackpiratex.quietpaper.yml`](file:///home/dog/git/quitepaper/linux/packaging/com.blackpiratex.quietpaper.yml).
   - Uses preinstalled GNOME 47 runtimes without multi-gigabyte network overhead or host sandboxing restrictions.
5. **`publish-release`**:
   - Downloads all artifacts from Android, Linux, and Flatpak jobs.
   - Publishes to GitHub Releases via `softprops/action-gh-release@v2` attaching all 9 binaries with automated changelog release notes.

### Packaging Scripts & Files
- **[`linux/packaging/build_deb.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_deb.sh)**: Generates complete Debian packaging directory tree (`opt/quitepaper/`, `usr/bin/quitepaper` symlink, desktop files, icons, `DEBIAN/control`, `postinst`, and `postrm` icon cache triggers) and builds via `dpkg-deb --root-owner-group`.
- **[`linux/packaging/com.blackpiratex.quietpaper.yml`](file:///home/dog/git/quitepaper/linux/packaging/com.blackpiratex.quietpaper.yml)**: FreeDesktop/GNOME 47 Flatpak manifest granting Wayland, X11, PulseAudio, DRI, Secret Service (`org.freedesktop.secrets`), and document filesystem permissions.
- **[`linux/packaging/build_flatpak.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_flatpak.sh)**: Staging and local compilation helper for Flatpak distribution.
- **[`linux/packaging/quietpaper.spec`](file:///home/dog/git/quitepaper/linux/packaging/quietpaper.spec)**: Parameterized RPM spec supporting dynamic version override (`%{app_version}`).
- **[`linux/packaging/build_appimage.sh`](file:///home/dog/git/quitepaper/linux/packaging/build_appimage.sh)**: Updated to accept dynamic version arguments and output versioned AppImages.
- **[`.github/workflows/build_linux.yml`](file:///home/dog/git/quitepaper/.github/workflows/build_linux.yml)**: Updated push/PR testing workflow to validate Debian package compilation alongside RPM, AppImage, and tarball builds.

---

## 234. Release Version Bump to 1.6.2 (Build 20) (October 2026)

### Overview
Bumped the official application version from `1.6.1+19` to `1.6.2+20` across the application codebase, packaging specs, and landing site. The build number increments `versionCode` to `20`, ensuring Android package manager and the in-app update checker recognize the build as an upgrade.

### Updated Locations
- [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml#L19): `version: 1.6.1+19` → `version: 1.6.2+20`.
- [`lib/core/version/app_version_provider.dart`](file:///home/dog/git/quitepaper/lib/core/version/app_version_provider.dart): Fallbacks and doc comments updated to `'1.6.2'`.
- [`lib/main.dart`](file:///home/dog/git/quitepaper/lib/main.dart#L31): Startup `PackageInfo` fallback updated to `'1.6.2'`.
- [`lib/core/location/location_service.dart`](file:///home/dog/git/quitepaper/lib/core/location/location_service.dart#L19): Default `_appVersion` updated to `'1.6.2'`.
- [`lib/core/device/device_info_service.dart`](file:///home/dog/git/quitepaper/lib/core/device/device_info_service.dart#L28): Default `appVersion` updated to `'1.6.2'`.
- [`lib/core/backup/backup_service.dart`](file:///home/dog/git/quitepaper/lib/core/backup/backup_service.dart#L25): Default constructor `appVersion` updated to `'1.6.2'`.
- [`lib/core/journal/application/weather_service.dart`](file:///home/dog/git/quitepaper/lib/core/journal/application/weather_service.dart#L30): Default `User-Agent` updated to `QuitePaper/1.6.2`.
- [`lib/features/export/application/exporters/qpnote_exporter.dart`](file:///home/dog/git/quitepaper/lib/features/export/application/exporters/qpnote_exporter.dart#L12): Default `_appVersion` updated to `'1.6.2'`.
- [`linux/packaging/quietpaper.spec`](file:///home/dog/git/quitepaper/linux/packaging/quietpaper.spec#L1): Default `%define app_version 1.6.2`.
- [`linux/com.blackpiratex.quietpaper.metainfo.xml`](file:///home/dog/git/quitepaper/linux/com.blackpiratex.quietpaper.metainfo.xml#L32): Added 1.6.2 release entry.
- Landing site & changelog:
  - [`public/index.html`](file:///home/dog/git/quitepaper/public/index.html) & [`backend/public/index.html`](file:///home/dog/git/quitepaper/backend/public/index.html): Hero badge and footer updated to `v1.6.2`.
  - [`public/changelog.html`](file:///home/dog/git/quitepaper/public/changelog.html) & [`backend/public/changelog.html`](file:///home/dog/git/quitepaper/backend/public/changelog.html): Added 1.6.2 release notes and footer meta.
  - [`public/privacy.html`](file:///home/dog/git/quitepaper/public/privacy.html), [`backend/public/privacy.html`](file:///home/dog/git/quitepaper/backend/public/privacy.html), [`public/terms.html`](file:///home/dog/git/quitepaper/public/terms.html), [`backend/public/terms.html`](file:///home/dog/git/quitepaper/backend/public/terms.html): Footers updated to `v1.6.2`.

---

## 235. Fix: Zero-Knowledge OCR Sync Foreign Key Constraint Failure and Defensive Note Pull Pagination (October 2026)

### 1. Problem & Context
On a new Android device (and any secondary device), users experienced:
1. Notes stopping at 50 notes during initial cloud sync.
2. Serverless backend logging unhandled 500 errors on `POST /api/v1/sync/ocr/push`:
   ```
   [API 500 UNHANDLED ERROR] POST /api/v1/sync/ocr/push LibsqlError: SQLITE_CONSTRAINT: SQLite error: FOREIGN KEY constraint failed
       at async pushOcrPages (backend/src/sync/syncService.ts:1665:7)
       at async handleApiRequest (backend/src/api/handler.ts:407:26)
   ```

### 2. Root Cause Analysis
- **Decoupling Disconnect**:
  - In [`backend/migrations/015_ocr_sync_and_conflicts_schema.sql`](file:///home/dog/git/quitepaper/backend/migrations/015_ocr_sync_and_conflicts_schema.sql) and [`005_ocr_and_document_source_schema.sql`](file:///home/dog/git/quitepaper/backend/migrations/005_ocr_and_document_source_schema.sql), `attachment_ocr_pages` and `document_ocr_pages` were created with `FOREIGN KEY (attachment_id) REFERENCES attachments(id)` and `FOREIGN KEY (document_id) REFERENCES documents(id)`.
  - In Quiet Paper's zero-knowledge sync model, OCR text is end-to-end encrypted sidecar metadata synced directly over Turso SQLite control plane. Media binary files are uploaded asynchronously to Cloudinary, and rows in `attachments` / `documents` are only confirmed after upload.
  - On a new device or when local OCR runs on queued attachments, `_pushDirtyOcrPages()` in Step 2d pushes dirty OCR pages *before* binary uploads in Step 5.
  - Because `attachments(id)` had not been confirmed on Turso, `INSERT INTO attachment_ocr_pages` failed SQLite foreign key enforcement and crashed the endpoint with 500.
  - This 500 failure left OCR pages dirty on the client, causing retries on every subsequent sync cycle to crash again.
  - Furthermore, in [`lib/core/sync/sync_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart), `while (hasMore)` pulls notes in batches of 50. If cursor advancement stagnated or pagination encountered empty batches, sync would halt at the 50-note boundary.

### 3. Architectural Fix & Implementation
1. **Database Migration 016 ([`backend/migrations/016_remove_ocr_foreign_keys.sql`](file:///home/dog/git/quitepaper/backend/migrations/016_remove_ocr_foreign_keys.sql))**:
   - Recreated `attachment_ocr_pages` and `document_ocr_pages` without foreign keys to `attachments(id)` or `documents(id)`, mirroring the pattern of `document_annotations` (migration 013) and `attachment_references` (migration 007).
   - Preserved `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`.
2. **Backend Migration Runner ([`backend/src/db/migrate.ts`](file:///home/dog/git/quitepaper/backend/src/db/migrate.ts))**:
   - Updated `INITIAL_SCHEMA_SQL` and added Migration 016 block in `runMigrations(db)` to migrate live databases safely.
3. **Explicit Cleanup & Garbage Collection**:
   - Added explicit deletion of `attachment_ocr_pages` and `attachment_references` when attachments are deleted in [`backend/src/sync/syncService.ts`](file:///home/dog/git/quitepaper/backend/src/sync/syncService.ts) and [`backend/src/gc/destructionJobProcessor.ts`](file:///home/dog/git/quitepaper/backend/src/gc/destructionJobProcessor.ts).
4. **Backend Test Decoupling ([`backend/tests/ocr_sync.test.ts`](file:///home/dog/git/quitepaper/backend/tests/ocr_sync.test.ts))**:
   - Removed artificial pre-confirmation of media files and verified that OCR pages push and pull independently of Cloudinary upload states.
5. **Defensive Note Pull Pagination ([`lib/core/sync/sync_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart))**:
   - Guarded `while (hasMore)` note pulling with: `if (pullResponse.changes.isEmpty || pullResponse.cursor <= currentCursor) hasMore = false;` to guarantee deterministic pagination termination.

### 4. Verification & Quality Gates
- `npm test`: 19 test files, 122 tests passing (100%).
- `npm run build`: Clean TypeScript compilation with 0 errors.
- `flutter analyze`: **0 issues, 0 warnings**.
- `flutter test test/sync/ test/notes/notes_query_database_test.dart`: **85 / 85 tests passing**.

---

## 236. First-Run Onboarding, Interactive Coach Marks & Settings Replay (October 2026)

### Overview
Implemented the complete, calm, editorial first-run onboarding experience, interactive coach marks tour, and settings replay for Quiet Paper. The implementation adheres strictly to Quiet Paper's aesthetic philosophy (warm paper tones, zero noisy modals, restrained transitions, and total respect for user privacy) without modifying backend APIs, database schemas, or sync wire formats.

### Architecture & Components

1. **State Management & Persistence (`lib/features/onboarding/application/onboarding_provider.dart`)**:
   - `OnboardingKeys`:
     - `onboarding_completed_v1` (`bool`): Tracks whether the user has finished or skipped onboarding.
     - `onboarding_tour_seen_v1` (`bool`): Tracks whether the 3-step coach mark tour has been shown or dismissed.
   - `OnboardingStatusNotifier`: StateNotifier exposing `OnboardingStatus` (`completed`, `tourSeen`, `isLoaded`).
   - Methods:
     - `complete()`: Persists `completed = true`.
     - `markTourSeen()`: Persists `tourSeen = true`.
     - `clearTourSeen()`: Resets `tourSeen = false` (for replay).
     - `finishWithTour()`: Sets `completed = true, tourSeen = false` (triggers coach marks).
     - `finishWithoutTour()`: Sets `completed = true, tourSeen = true` (skips coach marks).
   - `onboardingStatusProvider`: Auto-loaded Riverpod provider using `sharedPreferencesProvider`.

2. **App Root Gating (`lib/app/app_root.dart`)**:
   - Acts as top-level gate in `lib/app/app.dart`.
   - While SharedPreferences loads: renders `SizedBox.shrink()` tinted to theme background (no white flash).
   - If `!status.completed`: renders `OnboardingScreen`.
   - If `status.completed`: renders `NotesScreen(showOnboardingTour: !status.tourSeen)`.

3. **Carousel Flow (`lib/features/onboarding/presentation/onboarding_screen.dart`)**:
   - 8-page `PageView` with smooth 320ms curve transitions (`Curves.easeOutCubic`).
   - Top bar (48dp): Back chevron (pages 2-8), progress dots, Skip text button.
   - Bottom bar (72dp): Dynamic primary action button and secondary link ("Skip the tour").
   - Keyboard navigation: Left/Right arrows, PageUp/PageDown, Enter (advance), Escape (back/skip).
   - Responsive page layout (`OnboardingPageLayout`):
     - Screen width >= 760dp (Tablet/Desktop): 2-column split (visual left 420dp max, text right 480dp max).
     - Screen width < 760dp (Phone): Stacked vertical layout wrapped in `SingleChildScrollView`.
   - Responsive scaling: All vignettes wrapped in `FittedBox(fit: BoxFit.scaleDown)` and `ExcludeSemantics` guaranteeing zero overflow even on 320x568 dp screens (e.g., iPhone SE 1st gen).
   - Pages & Canonical Copy:
     - **Page 1: Welcome**: Eyebrow: `WELCOME TO QUIET PAPER`, Title: `A quiet place to think.`, Subtitle: `No clutter, no noise. Just your thoughts on warm paper.`, Visual: `WelcomeVignette`, Actions: `Restore a backup` · `Sign in` · `Create account`. Primary: `Start writing`.
     - **Page 2: Privacy**: Eyebrow: `PRIVATE BY DEFAULT`, Title: `Your words. Your business.`, Footnote: `No account needed to start.`, Visual: `PrivacyVignette`. Primary: `Next`.
     - **Page 3: Voice**: Eyebrow: `VOICE FIRST`, Title: `Speak your mind. We'll write it down.`, Footnote: `Models stay on device. Zero data sent to the cloud.`, Visual: `VoiceVignette`. Primary: `Next`.
     - **Page 4: Simplicity**: Eyebrow: `ONE LIST, ONE WAY`, Title: `Folders belong in filing cabinets.`, Footnote: `Organize when you feel like it. Or never.`, Visual: `SimplicityVignette`. Primary: `Next`.
     - **Page 5: OCR**: Eyebrow: `PAPER TO PAPERLESS`, Title: `Search the text inside your photos.`, Footnote: `Processed completely offline with Apple Vision / Google ML Kit.`, Visual: `OcrVignette`. Primary: `Next`.
     - **Page 6: Sync**: Eyebrow: `SYNC WHEN YOU'RE READY`, Title: `Quietly synced. Cryptographically sealed.`, Footnote: `Already have an account? Sign in`, Visual: `SyncVignette`. Primary: `Next`.
     - **Page 7: Personalize**: Eyebrow: `MAKE IT YOURS`, Title: `A desk that feels like yours.`, Interactive controls:
       - Paper style: Classic Paper (`classic_paper`) vs Warm Paper (`warm_paper`).
       - Appearance: System (`system`), Light (`light`), Dark (`dark`).
       - Sample notes: "Load 5 sample notes" (checks Drift database, inserts sample notes, or displays "Your desk already has notes." if notes exist). Primary: `Next`.
     - **Page 8: Ready**: Eyebrow: `ALL SET`, Title: `Your desk is clear.`, Subtitle: `Start with a blank page or let us show you around.`, Visual: `ReadyVignette`. Primary: `Show me around` (launches coach marks), Secondary: `Skip the tour, let's write` (lands on desk).

4. **Success Screen (`lib/features/onboarding/presentation/widgets/onboarding_success_page.dart`)**:
   - Replaces carousel when user signs in or restores a backup from the Welcome or Sync pages.
   - Sync variant: "You're signed in. End-to-end sync is active for `<email>`."
   - Restore variant: "Your backup is home. We put back `<N>` notes and their tags."
   - Primary button: `Continue to Quiet Paper`.

5. **Interactive Coach Marks (`lib/features/onboarding/presentation/coach_marks/onboarding_coach_marks.dart`)**:
   - Spotlight overlay on `NotesScreen` with darkened backdrop (`#000000` with 60% opacity) and smooth rounded cutout around target elements.
   - 3-step sequence:
     - **Step 1: Sidebar** (targets menu button): "All your notes, one drawer." / "Tags, archive, trash, and settings live here. Swipe from the left edge anytime to open."
     - **Step 2: Search** (targets search bar / pull-down): "Find anything in milliseconds." / "Search titles, note text, and even words inside attached photos. Or pull down on the list to reveal."
     - **Step 3: Create** (targets FAB / compose button): "Your first note is one tap away." / "Tap + to start writing. Everything saves automatically as you type."
   - Controls: "Next" / "Create my first note" (primary), "Skip tour" (secondary).
   - Tapping "Create my first note" automatically creates a blank note via `notesRepositoryProvider`, opens `EditorScreen(showFirstNoteTips: true)`, and completes the tour.

6. **First Note Editor Tips (`lib/features/onboarding/presentation/widgets/first_note_tips_card.dart`)**:
   - Unobtrusive card docked at the top of the note editor for the user's first created note.
   - Title: `A few quiet tricks` with "Got it" dismissal button.
   - Tips:
     - `• No save button—everything saves as you type.`
     - `• Type #tag anywhere to organize.`
     - `• Skip the title? The first line becomes it.`

7. **Settings Replay Entry Point (`lib/features/settings/presentation/about_app_screen.dart`)**:
   - Added `WELCOME TOUR` group under the About screen with `Show welcome tour` row (`Icons.explore_outlined`).
   - Resets `tourSeen = false` and opens `OnboardingScreen(isReplay: true)` with an explicit close button (`Icons.close_rounded`) in the top bar.

8. **Testing Suite**:
   - `test/onboarding/onboarding_provider_test.dart`: 7 unit tests covering defaults, completion, tourSeen persistence, reset, and reloading.
   - `test/onboarding/onboarding_screen_test.dart`: 10 widget/integration tests covering page advancement, skipping, theme switching, sample notes loading/idempotency, auth link navigation, success screens, and 320x568 small-phone overflow validation.
   - `test/onboarding/coach_marks_test.dart`: 5 tests covering 3 coach mark steps, skipping, first note creation, editor tips card display and dismissal, and missing-target fallback safety.
   - `test/settings/about_app_screen_test.dart`: 2 tests verifying "Show welcome tour" row exists and launches replay.
   - `test/sync/sync_screens_test.dart` & `test/widget_test.dart`: Updated to accommodate onboarding root gating.

### Verification & Quality Gates
- `flutter analyze`: **0 issues, 0 warnings** (clean).
- `flutter test`: **2,381 / 2,381 tests passing** (100% pass rate across the full test suite).

---

## 237. Note Reconciliation & Pruned Sync Log Recovery on Fresh Devices (October 2026)

### 1. Problem Statement & Root Cause
- When signing in on a new device (e.g. Android after iOS/desktop usage), notes stopped syncing after downloading ~50 notes, with the sync engine reporting "All notes synced" even though the user had hundreds of notes on the server.
- **Root Cause**: The Turso `sync_changes` table functions as a transient delta log. Incremental changelog entries are regularly garbage collected by `runGarbageCollection()` up to `safeSyncBoundaryRevision` (`min(last_acknowledged_revision)` across known active devices).
- When a fresh device enrolled with `cursor = 0`, it requested deltas starting from 0. `sync_changes` only held recent delta entries (e.g., the last 50 revisions). Revisions preceding the safe sync boundary had been purged from `sync_changes`, although the durable `notes` table retained every active note.
- `pullChanges(cursor: 0, limit: 50)` downloaded the 50 remaining entries and returned `hasMore: false`. The client engine concluded that all server changes were pulled, terminating the sync with most notes missing locally.

### 2. Architectural Solution: Total Note Check & Manifest Reconciliation

#### Backend Endpoints (`backend/src/sync/syncService.ts`, `backend/src/api/handler.ts`, `backend/src/validation/schemas.ts`)
1. **Server Total Note Count in Pull Response**:
   - Added `serverTotalNotes: number` to `PullResponse` and `pullSyncChanges()`, computing `COUNT(*)` from `notes WHERE user_id = ? AND is_deleted = 0`.
2. **Notes Manifest (`GET /api/v1/sync/notes/manifest`)**:
   - Returns a lightweight array of all non-deleted notes (`id`, `revision`, `updated_at`, `trashed`, `archived`) along with summary counts (`totalCount`, `activeCount`, `trashedCount`) queried directly from the durable `notes` table.
   - Bandwidth-efficient: A 1,000-note manifest is ~50KB and executes in ~20ms.
3. **Fetch Missing Notes (`POST /api/v1/sync/notes/fetch-missing`)**:
   - Accepts `{ noteIds: string[] }` (1 to 100 IDs) validated via `fetchMissingNotesSchema`.
   - Directly queries `notes` by `id IN (...)` and maps them into canonical `PullChangeItem` format, bypassing `sync_changes` entirely.

#### Client Synchronization Engine (`lib/core/sync/sync_engine.dart`, `lib/core/sync/sync_api_client.dart`, `lib/core/sync/sync_models.dart`)
1. **Reconciliation Step (`Step 3b: _reconcileNotesWithServer`)**:
   - Executed immediately following the standard changelog pull loop in `syncNow()`.
   - Calls `apiClient.getNotesManifest()`.
   - Fetches all local note IDs and revisions from `_db.notesDao.getAllNotes()`.
   - Compares manifest items against local SQLite notes to identify any note ID missing locally or where `manifest.revision > local.serverRevision`.
   - Requests missing notes in chunks of 50 via `apiClient.fetchMissingNotes(...)`.
   - Decrypts ciphertexts using Argon2id / XChaCha20-Poly1305 with the user's master key, executes 3-way merge conflict detection against dirty local drafts, prefetches web snapshot metadata if referenced, and persists them into SQLite.
   - Advances `currentCursor = max(currentCursor, manifestMaxRev)`.
2. **Factored Ingestion Helper (`_applyPulledNoteChange`)**:
   - Standardized note application logic between incremental pull loop and reconciliation batching to guarantee consistent decryption, conflict detection, and metadata caching.
3. **Mock & API Client Compatibility**:
   - Added default no-op methods to `SyncApiClient` interface for `getNotesManifest()` and `fetchMissingNotes()` so legacy test mocks and alternate client implementations compile without `NoSuchMethodError`.

### 3. Verification & Quality Gates
- `cd backend && npm test`: 19 test files, 123 tests passing (100%).
- `cd backend && npm run build`: 0 TypeScript compilation errors.
- `flutter analyze`: **0 issues, 0 warnings** (clean).
- `flutter test test/sync/sync_engine_test.dart test/sync/tag_sync_test.dart`: All unit and integration tests passing, including reconciliation of missing notes omitted by `sync_changes`.

---

## 238. Paginated Notes Collection State Mutex & Table Update Race Protection (October 2026)

### 1. Problem Statement & Root Cause
- **Symptoms**: On accounts with large collections (>800 notes), after syncing completed successfully, scrolling down on the notes list displayed an infinite loading spinner (`CircularProgressIndicator`) and froze. Scrolling further failed to load more notes. Closing and reopening the app did not resolve the freeze if background synchronization or OCR metadata updates fired during initial scrolling.
- **Root Cause**:
  1. In `NotesCollectionNotifier.loadMore()`, `state = state.copyWith(loadingMore: true)` was set before awaiting `_repository.executeNotesQuery(...)`.
  2. Drift's `_tableSubscription` listened directly to database updates across `notesTable`, `noteTagsTable`, `attachmentsTable`, and `documentsTable` with no debounce.
  3. When background sync or OCR page writes updated the database in batches, `_tableSubscription` fired `refresh()` repeatedly.
  4. `refresh()` bumped `_activeGeneration = state.generation + 1`.
  5. When the asynchronous Drift query in `loadMore()` returned, it executed:
     ```dart
     if (_activeGeneration != gen) return;
     ```
     This early return skipped state updating **without resetting `loadingMore: false`**. Furthermore, `refresh()` only reset `initialLoading: false, isRefreshing: false` and never reset `loadingMore: false`.
  6. Consequently, `state.loadingMore` remained permanently locked at `true`. `NotesLoadingMoreIndicator` rendered the loading animation indefinitely, and subsequent scroll notifications were rejected by the `if (state.loadingMore) return;` guard.
  7. When `refresh()` executed, it used `state.query.resetPagination()`, which reset `limit: 40`, collapsing the user's visible notes from 80 or 120 back down to 40 items and snapping their scroll position.

### 2. Implementation Details

1. **Guaranteed Mutex Release via `finally` (`lib/features/notes/application/notes_query_provider.dart`)**:
   - Wrapped `loadMore()` execution in a `try ... catch ... finally` block.
   - In `finally`: `if (mounted) state = state.copyWith(loadingMore: false);` guarantees that `loadingMore` is cleared upon completion, early generation exit, or query failure.
   - Added explicit `loadingMore: false` reset in `_loadInitial()` and `refresh()`.

2. **Debounced Database Table Updates (`Debouncer`)**:
   - Introduced a 350ms `Debouncer` on `_tableSubscription` in `NotesCollectionNotifier`:
     ```dart
     _tableDebouncer.run(() {
       if (mounted) refresh();
     });
     ```
   - In `dispose()`, `_tableDebouncer.dispose()` cancels any pending timers cleanly.
   - Prevents rapid bursts of table modifications during sync batches or OCR backfills from flooding the query notifier with dozens of redundant `refresh()` calls.

3. **Scroll Depth & Loaded Count Preservation during Refresh**:
   - Updated `NotesQuery.maxBatchSize` from 100 to 250 in `lib/features/notes/domain/notes_query.dart`.
   - In `refresh()`, calculated dynamic refresh batch limit:
     ```dart
     final refreshLimit = math
         .max(state.notes.length, state.query.limit)
         .clamp(state.query.limit, NotesQuery.maxBatchSize);
     final refreshQuery = state.query
         .copyWith(limit: refreshLimit)
         .resetPagination(newGeneration: gen);
     ```
   - Retained the original batch size in `state.query` (40) so subsequent `loadMore()` calls continue requesting standard 40-item pages without exponential growth.
   - Prevents scroll position jumping and keeps the user's currently viewed depth intact when background data changes occur.

4. **Keyset Pagination Empty-Progress Guard**:
   - Added `hasValidProgress` check in `loadMore()`:
     ```dart
     final hasValidProgress = uniqueNewNotes.isNotEmpty ||
         (result.nextCursor != null && result.nextCursor != state.cursor);
     ```
   - If a subsequent page yields zero unique new notes and the cursor does not advance, `hasMore` is set to `false`, eliminating infinite re-query loops on boundary collisions.

### 3. Verification & Quality Gates
- **Automated Tests (`test/notes/notes_pagination_race_test.dart`)**:
  - `Race condition between loadMore and table updates never freezes loadingMore at true`: Simulates in-flight `loadMore()` interrupted by Drift table update, confirming `loadingMore: false` and continuous pagination.
  - `Multi-page pagination smoothly loads 100 notes without duplicates`: Confirms 3 consecutive keyset pages across 100 seeded notes with zero ID collisions.
  - `Debounced refresh preserves loaded note count and scroll depth`: Confirms that updating a note in the background after loading 80 items preserves 80 items on refresh.
- `flutter analyze`: **0 issues, 0 warnings** (clean).
- `flutter test test/notes/notes_pagination_race_test.dart test/notes/notes_query_database_test.dart test/sync/sync_engine_test.dart`: All 25 tests passing.

---

## 239. Optimization: Defer Local Attachment Analysis to On-Demand Page Open & Eliminate Startup Freeze (October 2026)

### Overview
Addressed a 5–10 second delay experienced on cold app launches caused by eager attachment and reference analysis:
1. **Cold Launch Reference Projection Sync**: On startup, `SyncEngine.syncNow()` debounced 700ms and ran Step 6 ("Reference Projection Sync"), which previously performed an unconstrained `getAllNotesRaw()` query to deserialize every note's markdown body into memory on the main isolate, running two RegExp scans over every note and making a network call to `syncReferences`.
2. **Local Breakdown Overhead**: Post-sync and auth listeners in `CloudStorageNotifier.fetchQuota()` triggered `calculateLocalBreakdown()`, querying all raw attachment and document entities.
3. **Heavy Analysis on Page Open**: In `StorageManagementService.getLocalStorageAssets()`, full note texts were being loaded into memory to compute parent-note relationships and references.

### Implementation Details
1. **SyncEngine Scoped Reference Projection**:
   - In [`lib/core/sync/sync_engine.dart`](file:///home/dog/git/quitepaper/lib/core/sync/sync_engine.dart), Step 6 in `syncNow()` now only computes and uploads references for notes modified and pushed during the active sync session (`dirtyNotes`). On cold start or clean syncs, Step 6 is skipped entirely (0 ms, 0 queries, 0 HTTP requests).
   - Added `syncAllReferences()` to `SyncEngine` for on-demand execution when full remote reconciliation is required (e.g. before Garbage Collection maintenance).

2. **Storage Management Service & Database Optimizations**:
   - In [`lib/core/database/app_database.dart`](file:///home/dog/git/quitepaper/lib/core/database/app_database.dart):
     - Added `getNotesWithAssetReferences()`: queries only notes where `content.like('%qp://%')`, avoiding loading the entire note database.
     - Added `getNoteTitlesMap()`: lightweight projected column query (`id`, `title`) avoiding large note body deserialization.
     - Added `getStorageBreakdownMetrics()`: executes lightweight column projections for calculating storage metrics without hydrating all class entities.
   - In [`lib/core/storage/storage_management_service.dart`](file:///home/dog/git/quitepaper/lib/core/storage/storage_management_service.dart):
     - In `getLocalStorageAssets()`, switched to `database.getNoteTitlesMap()` and `database.getNotesWithAssetReferences()`.
     - In `runDryRunGc()` and `runGarbageCollection()`, invoke `syncEngine?.syncAllReferences()` prior to remote cleanup.
   - In [`lib/core/storage/cloud_storage_provider.dart`](file:///home/dog/git/quitepaper/lib/core/storage/cloud_storage_provider.dart):
     - Replaced manual row iteration in `calculateLocalBreakdown()` with `database.getStorageBreakdownMetrics()`.

### Verification & Quality Gates
- **Automated Tests**:
  - Added test in [`test/sync/storage_lifecycle_sync_test.dart`](file:///home/dog/git/quitepaper/test/sync/storage_lifecycle_sync_test.dart): `SyncEngine cold-start sync skips reference projection when no notes are dirty`.
  - Storage & Assets tests: `flutter test test/storage/` (all 43 tests passing).
  - Sync test suite: `flutter test test/sync/` (all 76 tests passing).
  - Full test suite: `flutter test` (**2386/2386 tests passed**).
- **Static Analysis**: `flutter analyze` reported **0 issues, 0 warnings**.

---

## 240. Architecture: Dedicated Checklist Widget in Visual Editor (WYSIWYG) (October 2026)

### Overview
Addressed cursor positioning and newline continuation bugs when interacting with checklists in Quiet Paper's Visual Editor (`EditorEditingStyle.wysiwyg`). Previously:
1. Checklists were embedded inside `RichTextEditor`'s continuous `TextField` as inline `WidgetSpan`s using a placeholder character (`\uFFFC`). This caused the cursor to land before the checkbox or separated by strange whitespace gaps because Flutter's `RenderEditable` positions caret offsets at index 0 before the `WidgetSpan`.
2. When typing a checklist item and pressing Enter, the newline insertion via the text input channel mutated the document while `_isInternalUpdate` was active, causing `_syncFromDocument()` to abort. As a result, the second line lacked `\uFFFC`, either placing the caret before the checkbox on the new line (Scenario 2) or converting the new line back into a paragraph upon typing (Scenario 1) because the line lacked the expected `\uFFFC` prefix.

### Implementation Details
1. **Dedicated Checklist Widget (`RichChecklistEditor`)**:
   - Created [`lib/features/editor/presentation/widgets/rich_checklist_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_checklist_editor.dart).
   - Renders each `ChecklistItemBlock` as a dedicated, baseline-aligned `Row` with:
     - Left: Phosphor icon checkbox (`square` / `checkSquare`) wrapped in a `GestureDetector`.
     - Right: An `Expanded` `TextField` using a custom `_ChecklistItemTextController` that renders rich inline spans (bold, italic, strike, link) and strikethrough styling when completed.
   - The caret is physically constrained inside the task's `TextField`, guaranteeing that it can never be positioned before or across the checkbox.
   - Enter key handling:
     - On a non-empty item: calls `controller.handleEnterAt(...)`, inserting a new `ChecklistItemBlock` below and cleanly focusing the new item's text field with a brand new checkbox widget.
     - On an empty item: converts the item to a standard `ParagraphBlock`, smoothly exiting checklist mode.
   - Backspace key handling:
     - At offset 0 of an empty item: removes the item and focuses the preceding item or converts to a paragraph.
     - At offset 0 of an item with text: merges text into the preceding checklist item.
   - Arrow keys: Up/Down arrow navigation between adjacent checklist items.

2. **Segmented Visual Layout (`RichEditorSurface`)**:
   - In [`lib/features/editor/presentation/widgets/rich_editor_surface.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_editor_surface.dart), updated `build()` to recognize `ChecklistItemBlock`s as dedicated visual widget blocks.
   - Collects contiguous `ChecklistItemBlock`s and renders them via `RichChecklistEditor`, while routing standard text blocks (Paragraphs, Headings, Bullets, Ordered Lists, Quotes) to `RichTextEditor`.

3. **Clean Up `RichTextEditor`**:
   - In [`lib/features/editor/presentation/widgets/rich_text_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/rich_text_editor.dart), removed all `\uFFFC` placeholder string manipulations, `prefixForBlock(ChecklistItemBlock)`, and inline `WidgetSpan` checkbox rendering. `RichTextEditor` is now 100% pure `TextSpan`s.
   - `QuietSuperEditor` and `MarkdownEditor` (source mode) remain completely untouched.

### Verification & Quality Gates
- **Automated Tests**:
  - [`test/editor/rich_text_checklist_editor_test.dart`](file:///home/dog/git/quitepaper/test/editor/rich_text_checklist_editor_test.dart): 9 comprehensive integration tests covering initial checklist toggle, text entry without placeholder characters, physical caret isolation, Scenario 1 persistence, Scenario 2 caret positioning, Enter exit to paragraph, Backspace deletion, and checkbox toggle.
  - All 584 editor tests in `test/editor/` pass.
- **Static Analysis**: `flutter analyze` reported **0 issues, 0 warnings**.











---

## 241. Architecture: Super Editor Native Code Block with Live Syntax Highlighting & Line Numbers (October 2026)

### Overview
Integrated a first-class, Super Editor-native code block component (`QuietCodeBlockComponent`) into Quiet Paper's Super Editor mode (`EditorEditingStyle.superEditor`). Previously, Super Editor rendered code blocks as unbordered, plain paragraphs with no background, no header bar, no language selector, no copy button, and no syntax highlighting. Furthermore, stock markdown parsing and serialization dropped the code language tag (e.g. ````dart), losing syntax formatting on note round-trips.

### Key Architectural & UI Enhancements
1. **Editorial Card Container & Header Bar**:
   - Styled to match Quiet Paper's Bear Notes aesthetic: warm surface background (`colors.surface`), subtle border (`colors.divider`), and rounded corners (`AppRadii.borderMd`).
   - Top editorial header bar with:
     - Interactive language pill displaying the uppercase language name (`DART`, `PYTHON`, `SQL`, or `PLAIN TEXT`), with dropdown chevron. Tapping opens `LanguageSelectorSheet` to switch language across dozens of supported programming languages.
     - 1-tap Copy button (`QuietIconButton`) with animated checkmark feedback (`Copied!`) and clipboard synchronization.
   - Hairline divider (`Divider(height: 1.0, color: colors.divider.withValues(alpha: 0.6))`).

2. **Proxy Document Component with Subtle Line Numbers & Soft Text Wrapping**:
   - Created [`lib/features/editor/presentation/widgets/super_editor/quiet_code_block_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_code_block_component.dart).
   - Extends `StatefulWidget` with `ProxyDocumentComponent<QuietCodeBlockComponent>, ProxyTextComposable` wrapping `TextComponent`.
   - Soft text wrapping: long lines wrap naturally within the card width.
   - Subtle line numbers in a left gutter (`_LineNumberGutter` & `_LineNumberPainter`) separated by a vertical hairline. Line numbers query `DocumentComponent.getOffsetForPosition` to align with the first visual baseline of each logical line (continuation lines have no line number, matching modern code editor conventions). Line numbers are outside the selectable text area, avoiding stray numbers on copy.
   - Caret Alignment: Overrides `getCaretForPosition` translating by `_getOffsetFromChild(Offset.zero)` to account for header bar height, gutter width, and internal padding with pixel-perfect caret placement.

3. **Live Syntax Highlighting Without Undo Stack Pollution**:
   - Computes tokens reactively using `SyntaxHighlighter` and `SyntaxLanguageResolver`.
   - Generates presentation-only `AttributedText` decorated with `NamedAttribution('syntax_<type>')` fed to `TextComponent`.
   - The authoritative `ParagraphNode.text` in Super Editor remains pure plaintext, ensuring syntax highlighting does **not** pollute the undo/redo history stack while delivering instantaneous, zero-latency token highlighting.

4. **Language Tag Round-Tripping & Markdown Shortcuts**:
   - `promoteQuietCodeBlockNodes(document, markdown)`: Scans markdown with `MarkdownCodeBlockParser` and attaches parsed fence languages to `node.metadata['language']`.
   - `QuietCodeBlockNodeSerializer`: Implements `DocumentNodeMarkdownSerializer` for `ParagraphNode` with `blockType == codeAttribution`, writing ````<language>\n<code>\n````.
   - `handleCodeBlockFenceNewlineRequest`: EditRequestHandler that intercepts Enter when a paragraph consists solely of a fence (e.g. ````, ````dart, `~~~python`), converting it directly into a code block with that language.
   - `CodeBlockConversionReaction`: EditReaction that converts ```` or ````lang followed by space into a code block.
   - Double Enter at the end of a code block exits to a new paragraph via Super Editor's built-in `InsertNewlineInCodeBlockAtCaretCommand`.

5. **Controller Integration**:
   - Updated `QuietSuperEditorController.insertCodeBlock({String? language})` to set `language` in metadata.
   - Added `QuietSuperEditorController.setCodeBlockLanguage(nodeId, language)` to support programmatic language updates.

### Verification & Quality Gates
- **Automated Tests**:
  - Added [`test/editor/quiet_code_block_test.dart`](file:///home/dog/git/quitepaper/test/editor/quiet_code_block_test.dart) (9 tests):
    - Language extraction and promotion from markdown fences.
    - Fenced serialization with language.
    - Full round-trip preservation of code and languages.
    - Markdown shortcut conversion on Enter (`handleCodeBlockFenceNewlineRequest`).
    - Markdown shortcut conversion on Space (`CodeBlockConversionReaction`).
    - Component rendering with language pill, copy button, and line numbers.
    - Copy button clipboard functionality with mock method channel.
    - Controller code block insertion and dynamic language changes.
  - Test suites: `flutter test test/editor/quiet_code_block_test.dart` and `flutter test test/editor/quiet_super_editor_test.dart` (37/37 passing).
- **Static Analysis**: `flutter analyze` reported **0 issues, 0 warnings**.

---

## 242. Architecture: Smart Todolist in SuperEditor with Optical Alignment, Placeholders, Auto-Sorting & Collapsible Done Items (October 2026)

### Overview
Significantly enhanced the checklist / to-do list editing experience in Quiet Paper's Super Editor (`EditorEditingStyle.superEditor`). Prior to this overhaul, Super Editor treated task nodes as raw, independent checklist items with misaligned checkboxes (floating too high above the text baseline and caret), no hint text on empty items, no automated sorting on completion, and no grouping or folding for completed tasks.

### Key Architectural & UI Enhancements
1. **Dynamic Optical Checkbox & Caret Alignment**:
   - In [`QuietTaskComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart), dynamically calculates the optical top padding based on font metrics: `((fontSize * lineHeight) - checkboxSize) / 2`.
   - For standard 18sp body text with 1.6 line-height (28.8px line box), this precisely positions the 20x20 checkbox with 4.4px top inset, aligning the checkbox square with the font's cap/x-height, baseline, and the Super Editor blinking caret across all user-selected font sizes and line heights.

2. **Empty Todo Placeholder (`New task...`)**:
   - When a to-do is empty (`widget.viewModel.text.isEmpty`), renders an `IgnorePointer` placeholder displaying `'New task...'` layered behind `TextComponent` via a `Stack`.
   - Inherits the exact same typography and line height via `_computeStyles({})`, ensuring zero jitter and pixel-identical vertical alignment with the caret.
   - Instantly disappears upon entering any character, and seamlessly reappears if text is cleared.

3. **Contiguous Task Range Discovery & Auto-Sorting on Check / Uncheck**:
   - Created [`SmartTaskController`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/smart_task_controller.dart):
     - `findTaskBlocks`: Discovers isolated contiguous runs of `TaskNode`s in the document (bounded by headings, paragraphs, tables, code blocks, or attachments).
     - `calculateDestinationIndex`:
       - **On Check**: Calculates the end index of the contiguous task block (`endIndex`) and moves the checked item to the bottom of the block.
       - **On Uncheck**: Calculates the insertion position immediately following all other active tasks (`startIndex + otherActiveCount`), moving the unchecked task to the bottom of the active/uncompleted tasks.
     - Preserves full undo/redo history using Super Editor's native command pipeline (`ChangeTaskCompletionRequest` & `MoveNodeRequest`).

4. **Smart Auto-Collapse for Completed Items (> 3 Done Items)**:
   - When a contiguous checklist block accumulates more than 3 completed tasks (`completedCount > 3`), all completed items automatically collapse under a clean editorial summary row:
     `✓ N completed items  ›`
   - Tapping the summary row smoothly expands the items (`✓ N completed items  ▾`), rendering all completed items inline with strike-through and checked boxes, fully selectable and editable.
   - Tapping again toggles back to collapsed state.
   - **Auto-Uncollapse**: If items are deleted or unchecked so that the completed count drops to $\le 3$, the section automatically uncollapses and displays all items inline.
   - **Super Editor Layout Stability**: Completed tasks remain native `TaskNode`s in the `MutableDocument`. Collapsed items render zero-height proxy components that fulfill Super Editor's `ProxyDocumentComponent` contract without disrupting caret hit-testing or layout calculations.

5. **Smooth Completion Animation & Animated Expand/Collapse**:
   - Immediate visual feedback: upon tapping the checkbox, the box instantly fills with the accent checkmark and strikethrough strikes the text.
   - Graceful dwell & fade: over 250ms, `AnimatedOpacity(opacity: 0.35)` allows the user to see the completed state before executing the document reordering.
   - Summary header and collapsible items utilize `SizeChangedLayoutNotifier` and `AnimatedSize(duration: 250ms, curve: Curves.easeInOut)` for smooth folding and expanding.

6. **Ghost Caret & Toolbar Active-State Bugfix**:
   - In [`SmartTaskController`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/smart_task_controller.dart), explicitly clears `composer.selection` when a focused task is completed or collapsed, preventing `DefaultCaretOverlayBuilder` from painting a floating ghost caret in empty space.
   - In [`QuietTaskComponent`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart), overrides `getRectForPosition` to return `Rect.zero` and `getPositionAtOffset` to return `null` for collapsed/hidden tasks.
   - Clears selection whenever expanding/collapsing to ensure the formatting toolbar's checklist button `[✓]` does not mistakenly stay active when resting on hidden completed tasks.

7. **SuperEditor Integration**:
   - Integrated `SmartTaskController` into [`QuietSuperEditor`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart) with stateful listener lifecycle management.

### Verification & Quality Gates
- **Automated Tests**:
  - Added [`test/editor/smart_task_super_editor_test.dart`](file:///home/dog/git/quitepaper/test/editor/smart_task_super_editor_test.dart) (12 tests):
    - `SmartTaskController` block discovery and isolation.
    - Destination index calculations for check and uncheck.
    - Default collapse (> 3) and interactive expansion toggling.
    - Empty task placeholder `'New task...'` rendering and suppression.
    - Dynamic optical top padding calculation.
    - Auto-sort to bottom of checklist on check.
    - Auto-sort to bottom of active items on uncheck.
    - Immediate visual feedback with 250ms smooth dwell animation.
    - Caret selection clearing on focused task check and `Rect.zero` protection.
    - Auto-collapse when $> 3$ completed and interactive expand/collapse toggle.
    - Auto-uncollapse when completed items drop to 3.
  - Test suites: `flutter test test/editor/smart_task_super_editor_test.dart test/editor/quiet_super_editor_test.dart` (42/42 passing).
- **Static Analysis**: `flutter analyze` reported **0 issues, 0 warnings**.

---

## 243. Bugfix: Markdown Task List Boundary Isolation & Paragraph Strikethrough Prevention (October 2026)

### Problem Description & Root Cause
When writing a standard text paragraph immediately following a task/checklist item in SuperEditor (e.g. typing notes directly beneath the to-do list), the paragraph would mistakenly receive strikethrough styling and collapse inside the completed items block upon saving/re-opening the note, despite rendering correctly in Markdown Preview.

**Root Cause**:
1. Under the CommonMark / GitHub Flavored Markdown specification, any text line immediately following a list item without an intervening blank line (`\n\n`) is parsed as a lazy multiline continuation of the preceding list item.
2. SuperEditor's default `serializeDocumentToMarkdown` joins adjacent nodes with only a single newline (`\n`). As a result, a completed `TaskNode` (`- [x] item 5`) followed by a `ParagraphNode` (`new thins`) serialized to:
   ```text
   - [x] item 5
   new thins
   hey thanks
   ```
3. Upon re-opening the document, `deserializeMarkdownToDocument` parsed `new thins\nhey thanks` directly into the preceding `TaskNode("item 5\nnew thins\nhey thanks")`. Because the task node was completed (`[x]`), the entire block (including the paragraph text) was styled with `lineThrough` and folded into the collapsed completed items list!

### Solution & Implementation
1. **QuietTaskNodeSerializer**:
   - Added `QuietTaskNodeSerializer` in [`lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_task_component.dart) extending `NodeTypedDocumentNodeMarkdownSerializer<TaskNode>`.
   - Checks whether the task node is followed by a non-task node (such as `ParagraphNode`). If so, appends a trailing newline (`\n`), ensuring that when `serializeDocumentToMarkdown` joins nodes with `\n`, a full blank line (`\n\n`) is produced between the checklist and the following block.
   - Registered `QuietTaskNodeSerializer()` in `QuietSuperEditor.customNodeSerializers` in [`lib/features/editor/presentation/widgets/quiet_super_editor.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/quiet_super_editor.dart).

2. **Pre-Deserialization Normalization**:
   - In `normalizeMarkdownForSuperEditor` ([`lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart`](file:///home/dog/git/quitepaper/lib/features/editor/presentation/widgets/super_editor/quiet_image_component.dart)), added regex detection for task/list items (`RegExp(r'^\s*([-*+](\s+\[[ xX]\]|\s+)|\d+\.\s+)')`).
   - When a task or list item is immediately followed by a non-list line without an empty line, automatically writes a double newline (`\n\n`) to cleanly terminate the list block before the paragraph line is deserialized.

### Verification
- Added regression tests in [`test/editor/smart_task_super_editor_test.dart`](file:///home/dog/git/quitepaper/test/editor/smart_task_super_editor_test.dart):
  - `paragraphs following a completed task list are not merged, struck through, or collapsed`: Verifies that paragraphs following a completed task list remain distinct `ParagraphNode`s, are rendered outside the completed collapse header, and do not receive `strikethroughAttribution`.
  - `QuietTaskNodeSerializer outputs blank line before following non-task node`: Verifies serialization produces `\n\n` boundary separation.
- Ran `flutter test test/editor/smart_task_super_editor_test.dart test/editor/quiet_super_editor_test.dart` (42/42 passed).
- Ran `flutter analyze` (0 issues, 0 warnings).

---

## 244. Performance Audit & Optimization: Syncfusion PDF Viewer Lag Elimination & 60 FPS Architectural Hardening (November 2026)

### 1. Problem Description & Root Causes
Users reported that the document PDF viewer (`DocumentViewerScreen`) suffered from severe visual lag, input stutter, gesture delays, and dropped frames during viewing, panning, and zooming. A deep forensic audit of `DocumentViewerScreen`, `syncfusion_flutter_pdfviewer`, and native PDFium rendering identified 6 compound bottlenecks:

1. **12x Zoom Tiling Explosion**:
   - `kPdfViewerMaxZoomLevel` was previously set to `12.0` (1200%).
   - Syncfusion computes tile scale as $\text{zoomLevel} \times \text{DPR}$. On high-DPI displays ($\text{DPR} \ge 2.0$), this requested native tile rendering at $24\times$ to $36\times$ resolution.
   - On Linux (`syncfusion_pdfviewer_linux`), `FPDF_RenderPageBitmap` runs **synchronously on the GTK main engine thread**, generating 30–50MB raw RGBA buffers and freezing the UI thread for 1.0–2.5 seconds on each gesture completion.
2. **Unvirtualized Continuous Mode Page Layout**:
   - Continuous scroll mode generates a `PdfPageView` widget for every single page in the document in a single unvirtualized `Column` wrapped in an `InteractiveScrollViewer`.
3. **Synchronous Main-Isolate Pure-Dart Text Extraction**:
   - For all pages entering the $3 \times 3$ viewport window, Syncfusion's `PdfTextExtractor.extractText()` synchronously parsed content streams, font descriptors, and glyph tables on the main UI isolate.
4. **Default `PdfInteractionMode.selection` Contention**:
   - With `interactionMode` defaulting to `selection`, pointer moves triggered text hit-testing on every frame and contested with pan gestures in the Flutter `GestureArena`. On desktop, dragging selected text instead of smoothly panning the document.
5. **Double-Tap Zoom Input Slop Delay**:
   - `enableDoubleTapZooming: true` forced Flutter's gesture arena to hold pointer events for $\sim$300ms waiting for double-tap disambiguation before recognizing pan/scroll.
6. **Annotation Mutation Rebuild Cascades & Missing Repaint Boundary**:
   - Adding or editing annotations invoked `setState(() => _isDirty = true)`, rebuilding the entire `DocumentViewerScreen` and `SfPdfViewer` mid-gesture without a `RepaintBoundary` isolating raster caches.

### 2. Architectural Solution & Enhancements
1. **Calibrated 5x Max Zoom Ceiling**:
   - Changed `kPdfViewerMaxZoomLevel = 5.0;` (500% magnification).
   - Keeps rasterized tile image memory strictly bounded, completely eliminating multi-megabyte buffer generation and main-thread freezes while providing razor-sharp legibility.
2. **Dynamic Interaction Mode**:
   - Configured `interactionMode: _effectiveInteractionMode`.
   - Defaults to `PdfInteractionMode.pan` for lag-free 60 FPS scrolling, panning, and desktop mouse dragging without continuous text hit-test contention.
   - Long-press text selection remains fully functional via `pdfviewer_canvas.dart`'s `_longPressRecognizer`.
   - Dynamically switches to `PdfInteractionMode.selection` when markup annotation tools (Highlight, Underline, Strikethrough, Squiggly) are activated.
3. **Configurable Page Layout Modes (Continuous vs. Single Page View)**:
   - Added `_pageLayoutMode = PdfPageLayoutMode.continuous` with a dynamic layout switcher in the Document Options overflow menu (`⋮`).
   - Users can seamlessly switch between **Continuous Scroll** and **Single Page View** (paginated swipe with zero off-screen page or multi-page text extraction overhead).
4. **Eliminated 300ms Double-Tap Touch Latency**:
   - Set `enableDoubleTapZooming: false`. Pan and scroll gestures now respond instantaneously on touch contact without waiting for double-tap timeouts, while zoom controls remain available via the Floating Quick-Zoom Pill and pinch-to-zoom.
5. **Repaint Isolation (`RepaintBoundary`)**:
   - Wrapped `SfPdfViewer` in a dedicated `RepaintBoundary`, decoupling canvas rendering from AppBar and overlay updates.
6. **Decoupled Dirty State via `ValueNotifier<bool>`**:
   - Replaced full-screen `setState` on annotation mutations with `_isDirtyNotifier`.
   - `PopScope` and the AppBar Save button listen in isolation, allowing continuous drawing and marking without widget tree rebuilds.
   - Fixed `_cachedPdfSource` memoization when annotations are saved.

### 3. Verification
- **Automated Tests**:
  - `flutter test test/documents/document_viewer_zoom_test.dart`: All 7 tests passing.
  - `flutter test test/documents/document_service_test.dart`: All 11 tests passing.
- **Static Analysis**:
  - `flutter analyze`: **0 issues, 0 warnings**.

---

## 245. Editor Design Polish: Centered Toolbar, Centered Title, Full-Width Far-Edge Scrollbar & Adaptive Multi-Column Properties Card (November 2026)

### 1. Overview & Motivation
When both the notes list and sidebar are minimized (or on expansive wide desktop monitors), the editor surface previously exhibited four visual and layout shortcomings:
1. **Left-Biased Formatting Toolbar**: The top-docked toolbar pill groups were packed strictly to the left edge of the screen via an unbounded `ListView`, leaving massive unbalanced white space to the right.
2. **Left-Biased Document Heading**: The note title (e.g. "November 1, 2026") sat left-aligned while the top bar brand header sat centered, producing an optical imbalance.
3. **Scrollbar Drifting Inwards on Narrow/Medium Paragraph Widths**: Wrapping the entire scrollable widget (`SingleChildScrollView` and `QuietMarkdownPreview`) inside a centered `ConstrainedBox(maxWidth: paragraphWidth)` caused Flutter desktop's native scrollbar to paint along the middle of the screen (at $x \approx 540\text{px}$ or $720\text{px}$) rather than resting at the right viewport window boundary.
4. **Single-Column Stacking in YAML Frontmatter Card**: Properties (Created, Moment, Mood, Weather, Location, Activities, Tags) always stacked vertically in a single column even on 4K or ultrawide displays, needlessly elongating the document header before the user reached the body text.

### 2. Architectural Design & Implementation

#### A. Horizontally Centered Formatting Toolbar (`formatting_toolbar.dart`)
- Replaced the left-aligned `ListView` with a `LayoutBuilder` driving a `SingleChildScrollView(scrollDirection: Axis.horizontal)`.
- Applied `ConstrainedBox(constraints: BoxConstraints(minWidth: constraints.maxWidth - padding))` around `Center(child: Row(mainAxisSize: MainAxisSize.min, children: [...]))`.
- **Responsive Guarantee**: On wide monitors where toolbar button groups fit easily, they are perfectly centered. When the viewport narrows below the toolbar's intrinsic width, the row smoothly scrolls from left to right with pointer scroll wheel support preserved.

#### B. Pinned Screen-Edge Scrollbar & Centered Note Surface (`editor_screen.dart`, `markdown_preview.dart`)
- Relocated `SingleChildScrollView` and `QuietMarkdownPreview` to the root viewport level, spanning 100% of the display width.
- Pushed `Align(alignment: Alignment.topCenter)` and `ConstrainedBox(constraints: BoxConstraints(maxWidth: typography.paragraphWidth.maxWidth))` **inside** the scroll view around the content column (Title, Properties Card, Document Body).
- Wrapped scrollables in `ScrollConfiguration(behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false))` so Flutter desktop's default scrollbar is suppressed and `IntelligentHeadingScrollbar` acts as the sole, interactive scrollbar pinned cleanly to the viewport's far right edge.
- Empty margins outside the centered text column remain interactive and kinetic mouse-wheel scrollable.
- Applied identical viewport-spanning and centered chunk item wrapping to `QuietMarkdownPreview`.

#### C. Centered Document Title (`editor_screen.dart`, `markdown_preview.dart`)
- Added `textAlign: TextAlign.center` to the note title `TextField` in `EditorScreen`.
- Added `textAlign: TextAlign.center` to the note title header `Text` widget in `QuietMarkdownPreview`.

#### D. Adaptive Multi-Column Properties Card (`frontmatter_properties_section.dart`, `markdown_preview.dart`)
- In `FrontmatterPropertiesSection` and `QuietFrontmatterCard`, partitioned properties into:
  - **Compact Fields**: `Author`, `Created`, `Moment`, `Mood`, `Weather`, `Source`.
  - **Wide / Multi-Line Fields**: `Location`, `Activities`, `Tags`, `Description`.
- Integrated `LayoutBuilder`:
  - When card width $< 560\text{px}$ (e.g. `narrow` paragraph width of $540\text{px}$ or compact mobile windows): retains 1-column vertical stacking.
  - When card width $\ge 560\text{px}$ (e.g. `medium` $720\text{px}$ and `full` paragraph width on wide screens): renders compact fields in 2-column rows (`Row(children: [Expanded(child: item1), SizedBox(width: AppSpacing.md), Expanded(child: item2)])`), while wide fields (`Location`, `Activities`, `Tags`, `Description`) span the full card width underneath.
- Added `Flexible` containers and `maxLines: 1, overflow: TextOverflow.ellipsis` safeguards to chip badges and weather status to eliminate `RenderFlex` overflow during layout transitions.

### 3. File Inventory
- **Modified**:
  - `lib/features/editor/presentation/widgets/formatting_toolbar.dart`: Centered layout builder and horizontal row container.
  - `lib/features/editor/presentation/editor_screen.dart`: Title center alignment, root full-width scrollable, inner constrained column, and scrollbar suppression.
  - `lib/core/markdown/markdown_preview.dart`: Title center alignment, chunk item width constraints, and 2-column frontmatter card.
  - `lib/features/editor/presentation/widgets/frontmatter_properties_section.dart`: Responsive 2-column grid for compact properties and overflow protection.
  - `test/editor/formatting_toolbar_test.dart`: Added widget test for centered toolbar buttons on wide displays.
  - `test/editor/frontmatter_properties_section_test.dart`: Added widget tests for 2-column layout ($\ge 560\text{px}$) and 1-column fallback ($< 560\text{px}$).
  - `test/editor/editor_scrollbar_test.dart`: Added widget test for centered title in editor and preview modes.
  - `test/editor/desktop_toolbar_and_shortcuts_test.dart`: Updated toolbar finder from `ListView` to `SingleChildScrollView`.
  - `test/editor/typewriter_scrolling_test.dart`: Updated vertical scrollable predicate for typewriter coordinator.

### 4. Verification & Quality Gates
- **Static Analysis**: `flutter analyze` (**0 issues, 0 warnings**).
- **Automated Tests**: `flutter test` across all 2415 tests in the repository (**2415/2415 passing, 0 failures**).

---

## 246. Feature: PDF Document Viewer Collapsible Page Thumbnail Sidebar with Permanent Encrypted Cache (November 2026)

### 1. Context & Motivation
On large screens (Linux desktop, macOS, Windows, and tablet displays $\ge 768\text{dp}$), navigating multi-page PDF documents solely via continuous scrolling or numeric pagination dialogs is slow and lacks visual context. Users requested a dedicated collapsible thumbnail preview sidebar at the left-hand side of the PDF viewer (`DocumentViewerScreen`) that:
1. Loads page thumbnails extremely fast.
2. Persists a permanent cache in storage so closing and reopening the app does not invalidate the cache.
3. Completely satisfies Quiet Paper's strict zero-knowledge encryption invariant by encrypting cached thumbnail files client-side with the user's Master Key (`XChaCha20-Poly1305`).
4. Remembers the user's collapsed/expanded state preference in `SharedPreferences`.

### 2. Architectural Design & Implementation Details

#### A. 3-Tier Thumbnail Cache Hierarchy (`PdfThumbnailService`)
Created `lib/core/documents/pdf_thumbnail_service.dart`:
- **Tier 1 (In-Memory)**: Decoded PNG bitmaps stored in `Map<String, Map<int, Uint8List>>` for sub-millisecond instant page switching.
- **Tier 2 (Permanent Encrypted Disk Cache)**: Cached on disk at `~/.local/share/quitepaper/pdf_thumbnails/<documentId>/page_<pageIndex>.qpthumb`. Each thumbnail is encrypted client-side using `DocumentCrypto.encryptDocument` with the user's Master Key and authenticated associated data (`quietpaper:document:<docId>:thumb:<pageIndex>:v1`). Subsequent app launches decrypt thumbnails on-the-fly without running rasterization.
- **Tier 3 (Low-DPI Lazy Rasterization)**: When not cached, rendered on-demand at `36.0 DPI` via `PdfPageRenderer.renderSinglePage`. 36 DPI yields crisp 120dp thumbnails in 5–15ms and produces compact 10–25 KB payloads.
- **Concurrent Request Deduplication**: In-flight generation promises are deduplicated across identical `(documentId, pageIndex)` keys via `Completer` sharing to prevent duplicate rasterization passes.
- **Self-Healing Decryption Recovery**: If a disk thumbnail fails authentication or MAC verification, it is automatically removed and re-rendered freshly.
- **Lifecycle Cascade Cleanup**: Tied directly into `DocumentService.deleteDocument` and `DocumentService.purgeLocalDocument` to ensure zero orphaned disk thumbnails when documents are removed. Invalidation hooks also clear stale thumbnails when user annotations are saved or reverted.

#### B. Collapsible Thumbnail Sidebar (`PdfThumbnailSidebar`)
Created `lib/core/documents/presentation/widgets/pdf_thumbnail_sidebar.dart`:
- Built with `ListView.builder` for virtualized lazy page rendering.
- Active page is highlighted with an accent border (`colors.accent`, 2px) and elevation glow.
- Auto-scroll synchronization: Listens to `selectedPageIndexListenable` (`_selectedPageIndexNotifier`) and smoothly brings the thumbnail into view whenever the user scrolls or jumps pages in `SfPdfViewer`.
- 1-tap navigation: Tapping any thumbnail triggers `jumpToPage(index + 1)`.

#### C. Responsive Viewer Integration & Split-Handle UI (`DocumentViewerScreen`)
Updated `lib/core/documents/presentation/document_viewer_screen.dart`:
- **Screen Classification**: Evaluates `PlatformLayoutHelper.isDesktop(context) || MediaQuery.of(context).size.width >= 768.0`. Small mobile devices hide the sidebar and keep 100% viewport width for document content.
- **Preference Persistence**: Reads and writes `setting_pdf_thumbnail_sidebar_open` in `SharedPreferences`. Automatically defaults to open on wide screens ($\ge 900\text{dp}$).
- **Dual Collapse Triggers**:
  - AppBar action icon button (`Icons.view_sidebar` / `Icons.view_sidebar_outlined`).
  - Interactive tactile chevron divider handle (`Icons.chevron_left` / `Icons.chevron_right`) anchored between the sidebar and the main viewer.
- **Smooth Width Animation**: `AnimatedContainer` (200ms `Curves.easeInOut`, 140dp width) ensures seamless, fluid collapsing and expanding without PDF rendering stutter.

### 3. File Inventory
- **New Files**:
  - `lib/core/documents/pdf_thumbnail_service.dart`: 3-tier thumbnail service with encrypted disk persistence.
  - `lib/core/documents/presentation/widgets/pdf_thumbnail_sidebar.dart`: Collapsible thumbnail sidebar widget.
  - `test/documents/pdf_thumbnail_service_test.dart`: Unit tests for caching, encryption, deduplication, and cascade deletion.
  - `test/documents/document_viewer_thumbnail_test.dart`: Widget tests for large screen detection, toggle actions, and phone hiding.
- **Modified Files**:
  - `lib/core/documents/document_service.dart`: Injected `PdfThumbnailService` into constructor and deletion cascade.
  - `lib/core/documents/document_provider.dart`: Registered `pdfThumbnailServiceProvider` and wired into `documentServiceProvider`.
  - `lib/core/documents/presentation/document_viewer_screen.dart`: Integrated sidebar layout, collapse handle, preference storage, and AppBar toggle.
  - `handoff/ocr-and-documents.md`: Documented thumbnail sidebar and 3-tier caching architecture.

### 4. Verification & Quality Gates
- **Static Analysis**: `flutter analyze` (**0 issues, 0 warnings**).
- **Targeted Document Tests**: All 25 tests passed across `pdf_thumbnail_service_test.dart`, `document_viewer_thumbnail_test.dart`, `document_viewer_zoom_test.dart`, and `document_service_test.dart` (**25/25 passing, 0 failures**).

---

## 247. Redesign: Tags Browser Screen ("Pure Bear List" Aesthetic) (November 2026)

### 1. Context & Motivation
Quiet Paper's previous Tag Browser interface featured heavy rounded-square background containers behind row icons, duplicate `#` signifiers (both an icon and a text prefix), repetitive vertical three-dot (`⋮`) action menus cluttering the right margin of every row, and boxed chevron buttons. Users requested a warm, breathable, editorial single-column tag index redesign strictly adhering to the "Pure Bear List" aesthetic from Bear Notes.

### 2. Architectural Design & Implementation Details

#### A. Zero Hardcoded Colors — Strict App Theme Token Mapping
All visual roles are mapped strictly to Quiet Paper's semantic tokens in `AppColors`:
- **Canvas Background**: `colors.background`
- **Elevated Surfaces (Search bar, pills, menus)**: `colors.surfaceSecondary` and `colors.surface`
- **Primary Text**: `colors.textPrimary`
- **Secondary / Muted Text (Ledger note counts, inactive icons)**: `colors.textSecondary`
- **Tertiary / Dimmed Text (Default `#` glyph, subtitles, search placeholder)**: `colors.textTertiary`
- **Zero-Count Text**: `colors.textDisabled` so empty tags visually recede
- **Primary Accent (`+ New` pill button, active filters, pin indicators)**: `colors.accent`
- **Soft Accent Container**: `colors.accentSoft`
- **Dividers & Hierarchy Thread Line**: `colors.divider` and `colors.borderSubtle`

#### B. Streamlined Masthead & Editorial Header
- **Editorial Typography**: Rendered `Tags` masthead in Newsreader serif (`GoogleFonts.newsreader`, 30–32sp, font weight 600, tracking -0.6) with automatic serif fallback.
- **Inline Count Badge**: Placed total tag count inline next to the `Tags` title in a compact rounded pill using `colors.surfaceSecondary`, `colors.borderSubtle`, and tabular figures.
- **Sort Indicator**: Right-aligned sort indicator label (e.g. `Sorted A–Z` or `Sorted by notes`) in italic serif, supporting quick sort toggling.
- **Top Actions**: Clean, uncrowded toolbar with drawer/sidebar toggle on the left, and hierarchy `Tree` pill button, `Sort and filter tags` button, and signature carmine `+ New` pill button on the right.
- **Integrated Soft-Inset Search Bar & Filter Chips**: Integrated search input (`Filter X tags or #journal/...`) with clear button and horizontal scrollable quick filter chips (`All`, `Pinned`, `TagCons`, `With Notes`, `Unused`).

#### C. Row Architecture & "Single Signifier" Iconography
- **Eliminated Double Signifier**: Removed heavy rounded-square background boxes. Rows now never render both an icon AND a duplicate `#` prefix on the label string.
- **Fixed 28px Left Icon Slot**:
  - Tags with a custom TagCon icon render the clean single-weight icon directly in the left slot.
  - Standard tags without a custom icon render an editorial, slightly italicized `#` glyph in the slot.
  - Tag label displays clean leaf name without duplicate `#`.
- **Right Margin De-cluttering**: Removed repetitive `⋮` buttons so note counts form a clean, scannable ledger right margin with monospace tabular figures (`FontFeature.tabularFigures()`).
- **Contextual Actions Trigger**: Wired up long-press on row body and tap on left icon slot to trigger the tag action sheet / popover (`_showTagOptions`), preserving all tag operations (Open, Add nested tag, Pin/Unpin, Rename, Change icon, Change color, Merge into, Delete).

#### D. Nested Hierarchy & Vertical Thread Guide Line
- **Inline Disclosure Chevron**: Replaced the large boxed chevron with a compact, rotating inline chevron (`PhosphorIconsRegular.caretRight` rotating 90° on expand) placed immediately after the parent tag's name.
- **Vertical Thread Line**: When expanded, child tags are smoothly animated (`AnimatedSize`, `Curves.easeInOutCubic`) and connected to their parent via a delicate 1.0px vertical thread line (`border: Border(left: BorderSide(color: colors.divider))`) along the left indentation channel. Supports arbitrary recursive nesting depth.

### 3. File Inventory
- **Modified Files**:
  - `lib/features/tags/presentation/widgets/tag_browser_view.dart`: Complete redesign of header, search bar, row architecture, tree hierarchy widget, and tag options sheet.
  - `test/tags/tag_ui_test.dart`: Updated widget tests to test single signifier names, left icon tap popovers, and search filtering.
  - `test/tags/tag_hierarchy_ui_test.dart`: Updated hierarchy tests for clean tag names, inline chevron expansion, and combined compact menu.
  - `test/tags/tag_workspace_navigation_test.dart`: Updated 3-pane workspace integration tests.
  - `handoff/tags-and-search.md`: Added reference link to Section 247.
  - `handoff/latest-logs.md`: Appended Section 247 documentation log.

### 4. Verification & Quality Gates
- **Static Analysis**: `flutter analyze` (**0 issues, 0 warnings, 0 errors**).
- **Targeted Tests**: All 31 tests passed across `tag_ui_test.dart`, `tag_hierarchy_ui_test.dart`, and `tag_workspace_navigation_test.dart` (**31/31 passing, 0 failures**).

---

## 248. Automatic Year Tagging for Today's Journal Entry (`#journal/<year>`) & Default Settings Toggle (November 2026)

### 1. Overview & Motivation
When users open **Today** under the **JOURNAL** section in the navigation sidebar, Quiet Paper opens or creates today's canonical daily note (`YYYY-MM-DD`). To facilitate structured long-term organization and take advantage of the Bear Notes-style nested tag hierarchy (e.g. `#journal/2026`), entries now automatically receive the current calendar year tag derived dynamically from the device clock (`DateTime.now().year`). 

Users who prefer untagged journal entries can disable this behavior at any time under **Settings > Default Settings > JOURNAL**.

### 2. Architecture & Implementation

#### A. Settings & State Management
- **Domain Model ([`lib/features/settings/domain/default_settings.dart`](file:///home/dog/git/quitepaper/lib/features/settings/domain/default_settings.dart))**:
  - Added `autoTagTodayJournal` boolean property (defaults to `true`).
  - Updated `copyWith`, value equality (`operator ==`), and `hashCode`.
- **Notifier & Persistence ([`lib/features/settings/application/default_settings_provider.dart`](file:///home/dog/git/quitepaper/lib/features/settings/application/default_settings_provider.dart))**:
  - Added SharedPreferences key `setting_auto_tag_today_journal`.
  - Added `setAutoTagTodayJournal(bool value)` to update in-memory state and persist asynchronously.
- **UI Toggle ([`lib/features/settings/presentation/default_settings_screen.dart`](file:///home/dog/git/quitepaper/lib/features/settings/presentation/default_settings_screen.dart))**:
  - Placed an editorial switch row in the **JOURNAL** group card with icon `PhosphorIconsRegular.tag`, title `"Auto-tag today's entry"`, and subtitle `"Automatically apply #journal/<year> tag when opening Today from sidebar"`.

#### B. Journal Service & Note Synchronization
- **Tag Application Engine ([`lib/features/journal/application/journal_service.dart`](file:///home/dog/git/quitepaper/lib/features/journal/application/journal_service.dart))**:
  - Implemented `ensureYearTagApplied(Note note, int year)`:
    - Normalizes the target tag as `journal/$year`.
    - Returns early if the note already contains the tag (idempotent, prevents duplicate sync revisions).
    - If YAML frontmatter is present on the journal note, synchronizes `tags: [..., 'journal/<year>']` via `FrontmatterEditorHelper.updateTags`.
    - Persists the updated note via `_repository.saveNote(updatedNote, preserveEmptyTags: true)` so the tag is written to SQLite `tagsTable` and `noteTagsTable`.
  - Updated `openOrCreateTodayFlow` and `openOrCreateEntryFlow` to accept `bool autoTagYear = false` and optional `int? tagYear`. If `autoTagYear` is enabled, applies the year tag before navigating to the editor (or after restoring from Trash if the note was previously trashed).

#### C. Sidebar Navigation Integration
- **Sidebar Today Handler ([`lib/features/sidebar/presentation/sidebar_view.dart`](file:///home/dog/git/quitepaper/lib/features/sidebar/presentation/sidebar_view.dart))**:
  - On tapping **Today**, reads `ref.read(defaultSettingsProvider).autoTagTodayJournal` and forwards `autoTagYear: autoTag` to `journalService.openOrCreateTodayFlow(context, isTablet: isCollapsible, autoTagYear: autoTag)`.

### 3. File Inventory
- **Modified Source Files**:
  - `lib/features/settings/domain/default_settings.dart`
  - `lib/features/settings/application/default_settings_provider.dart`
  - `lib/features/settings/presentation/default_settings_screen.dart`
  - `lib/features/journal/application/journal_service.dart`
  - `lib/features/sidebar/presentation/sidebar_view.dart`
- **Modified Test Files**:
  - `test/settings/default_settings_test.dart`: Added domain, persistence, and widget tests for `autoTagTodayJournal`.
  - `test/journal/journal_service_test.dart`: Added unit and widget tests for `ensureYearTagApplied` and `openOrCreateTodayFlow`.
  - `test/journal/sidebar_journal_widget_test.dart`: Added widget tests for tapping Today with auto-tagging enabled vs disabled.
- **Documentation**:
  - `handoff/journal-and-audio.md`: Documented feature and linked reference.
  - `handoff/latest-logs.md`: Appended Section 248.

### 4. Verification & Quality Gates
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings**).
- **Automated Tests**:
  - `test/settings/default_settings_test.dart` (**15/15 passing**).
  - `test/journal/journal_service_test.dart` (**8/8 passing**).
  - `test/journal/sidebar_journal_widget_test.dart` (**5/5 passing**).
  - Full test suite: `flutter test` (**2,428/2,428 passing**).

---

## 249. Redesign: Sidebar Navigation Drawer ("Quiet Paper" Editorial Bear Aesthetic) (November 2026)

### 1. Context & Motivation
Quiet Paper's previous sidebar navigation drawer suffered from excessive vertical row height and padding across `LIBRARY` and `JOURNAL`, pushing the `TAGS` hierarchy down so only 1–2 tags were visible above the fold on mobile screens. Furthermore, the tag tree in the drawer used legacy rounded-square background containers, repetitive boxed chevron expand buttons, and stacked `Sync` and `Settings` as two tall individual rows at the bottom.

This refactor brings a warm, literary Bear Notes aesthetic to the **Quiet Paper** sidebar while unifying its `TAGS` section with the **"Pure Bear List"** design language introduced in Section 247.

### 2. Architectural Design & Implementation Details

#### A. Zero Hardcoded Colors — Strict App Theme Token Mapping
All visual elements are mapped strictly to existing semantic tokens in `AppColors`:
- **Drawer Surface Background**: `colors.sidebarBackground`
- **Elevated / Pill Surface**: `colors.surfaceSecondary` (or `colors.sidebarSelected` for active rows and search bar)
- **Primary Text**: `colors.textPrimary` (Newsreader masthead, active labels, primary row labels)
- **Secondary / Muted Text**: `colors.textSecondary` (inactive items, note counts, section header subtitles, settings gear)
- **Tertiary / Dimmed Text**: `colors.textTertiary` (subtitles, search placeholder, default `#` glyph, relative timestamps)
- **Zero-Count Text**: `colors.textDisabled`
- **Primary Accent**: `colors.accent` (quick compose icon, active row icon tint, Today 6px indicator dot, cloud check icon, `All X ↗` link)
- **Soft Accent Container**: `colors.accentSoft` (quick compose button, sync icon box)
- **Dividers & Hierarchy Thread Line**: `colors.divider` and `colors.borderSubtle`

#### B. Three-Zone Flex Architecture
1. **Pinned Top Header**:
   - **Literary Masthead**: "Quiet Paper" set in Newsreader serif (`GoogleFonts.newsreader`, 22sp, font-weight 600, letter spacing -0.4) reflecting a literary publication masthead.
   - **Quick-Compose Button**: Soft accent container (`colors.accentSoft`, 32x32) with a carmine pencil icon (`PhosphorIconsRegular.pencilSimple`) for one-tap note creation.
   - **Tactile Search Pill**: Compact 38px pill in `colors.surfaceSecondary` with `PhosphorIconsRegular.magnifyingGlass`, placeholder "Search notes...", and a right-aligned `'/'` keyboard shortcut badge.
2. **Scrollable Middle Navigation**:
   - **Calibrated Vertical Rhythm**: Navigation rows tightened to 36–38px height (`padding: 7px 10px`, `border-radius: 9px`), allowing 5+ tags to sit comfortably above the footer fold without scrolling.
   - **Aligned 22px Fixed Icon Slot**: Every navigation row across `LIBRARY`, `JOURNAL`, and `TAGS` uses a fixed 22px width container so all text labels align along a single crisp vertical axis.
   - **Journal Section Polish**: Header features italic Newsreader "Daily" subtitle; `Today` row features a 6px circular indicator dot in `colors.accent`.
3. **Cohesive "Pure Bear List" TAGS Tree**:
   - **Header Actions**: Features `All ${tags.length} ↗` accent link on the right alongside `PhosphorIconsRegular.slidersHorizontal` to open the Tag Browser.
   - **Elimination of Boxed Chevrons**: Replaced large boxed chevron buttons with an inline disclosure chevron (`PhosphorIconsRegular.caretRight` rotating 90° on expand via `AnimatedRotation`).
   - **Single Signifier Iconography**: Custom TagCon icons render directly in the 22px slot without background boxes; standard tags render an editorial italic `#` glyph in Newsreader serif.
   - **1px Vertical Thread Guide Line**: Sub-tags under expanded parents animate smoothly with `AnimatedSize` and connect via a delicate 1.0px vertical thread line along the left indentation channel (`margin: EdgeInsets.only(left: 21.0)`).
4. **Unified Pinned Bottom Footer (`Sync` + `Settings`)**:
   - Replaced the stacked 2-row layout with a single consolidated pinned bar separated by a 1px hairline border (`colors.divider`).
   - **Left Interactive Sync Area**: 34x34 rounded accent container with cloud icon (rotating transition when syncing), `Sync` title + relative timestamp (`DateFormatter.formatRelative`), and user email (`hi@sudipx.in`), with conflict alerts rendered when pending.
   - **Right Action Button (`Settings`)**: 34x34 rounded container with gear icon (`PhosphorIconsRegular.gearSix`), tooltip, and accessibility semantics.

### 3. File Inventory
- **Modified Files**:
  - `lib/features/sidebar/presentation/sidebar_view.dart`: Literary masthead, quick-compose button, search pill with shortcut badge, calibrated vertical rhythm, recursive `_buildTagTreeNode` with 1px vertical thread guide line, and unified footer bar.
  - `lib/features/sidebar/presentation/widgets/sidebar_item.dart`: Calibrated row height (36–38px), 22px fixed left icon container, tabular monospace figures for ledger note counts.
  - `lib/features/sidebar/presentation/widgets/sidebar_sync_tile.dart`: Compact sync tile layout supporting `trailing` action button and soft accent icon container.
  - `HANDOFF.md`: Updated quick index.
  - `handoff/latest-logs.md`: Appended Section 249 documentation log.

### 4. Verification & Quality Gates
- **Static Analysis**: `flutter analyze` (**0 issues found, 0 warnings, 0 errors**).
- **Automated Tests**:
  - `test/sidebar/sidebar_sync_tile_test.dart` (**6/6 passing**).
  - `test/sidebar/sidebar_smart_views_test.dart` (**3/3 passing**).
  - `test/journal/sidebar_journal_widget_test.dart` (**5/5 passing**).
  - `test/tags/tag_hierarchy_ui_test.dart` (**15/15 passing**).
  - `test/widget_test.dart` (**16/16 passing**).
  - Full test suite: `flutter test` (**2,428/2,428 passing**).





