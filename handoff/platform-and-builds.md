# Quiet Paper — Multi-Platform, CI/CD & Build Pipelines

> Part of the Quiet Paper Handoff Documentation. See [INDEX.md](INDEX.md) for the master guide.

---

## 1. Multi-Platform Targets & Considerations

Quiet Paper is architected to run seamlessly across Android, Linux, iOS, macOS, and Windows.

### Android
- **Multi-Architecture Builds**: Releases generate split APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) to minimize download sizes, alongside universal bundles.
- **Scoped Storage**: Full compatibility with Android 11+ Scoped Storage requirements for backup creation and file importing.
- **Home-Screen Quick Capture Widget**: Enables 1-tap note creation and audio recording from the home screen ([`lib/features/quick_capture/`](file:///home/dog/git/quitepaper/lib/features/quick_capture/)).

### Linux Desktop
- **Packaging Formats**: GitHub Release pipelines automatically build and package:
  - **DEB** (Debian/Ubuntu)
  - **RPM** (Fedora/RHEL/openSUSE)
  - **AppImage** (Universal Linux binary)
  - **Flatpak** (Sandboxed distribution)
- **GStreamer Dependencies**: Audio playback and voice recording depend on `gstreamer1.0-plugins-base` and `gstreamer1.0-plugins-good`.
- **Headless & Keyring Resiliency**: If SecretService / KDE Wallet is unavailable or headless, [`LinuxSecureStorageFallback`](file:///home/dog/git/quitepaper/lib/core/crypto/key_manager.dart) provides an encrypted local key vault without crashing.
- **Native File Sharing (`shareXFiles`)**: Resolves upstream `share_plus` Linux limitation (`UnimplementedError`) via [`QuietPaperLinuxSharePlugin`](file:///home/dog/git/quitepaper/lib/core/sharing/quiet_paper_linux_share.dart), using XDG Desktop Portal `OpenURI` (`ask: true`), `gio open`, `xdg-open`, `FileManager1.ShowItems`, `xdg-email`, and `mailto:` fallbacks.
- **Native Command-Line Interface (`qp`)**: Standalone, AOT-compiled native CLI binary (`bin/qp.dart` $\rightarrow$ `/usr/bin/qp`) providing sub-15ms terminal interaction for note listing, creation, and modification with external editors (`nvim`, `vim`, `nano`, `$EDITOR`), full-text search, and SQLite WAL concurrent access. Installed alongside the desktop GUI in DEB, RPM, and AppImage packages (under `/opt/quitepaper/bin/qp` with stripping disabled to protect the Dart AOT snapshot payload).

### Desktop Adaptive UI
- **Spotlight Command Palette**: `Cmd/Ctrl + K` triggers an adaptive modal palette for jumping between notes, tags, and commands.
- **Keyboard Navigation**: Full keyboard shortcut support for formatting, indenting, tag selection, and note navigation.

---

## 2. CI/CD Workflows & Release Pipelines

All seven `subosito/flutter-action` setup steps across the six workflows pin
**Flutter 3.47.2** (Dart 3.13.2), matching local analysis and test validation.
Keep these `flutter-version` values aligned when upgrading. An SDK upgrade must
pass analysis, code generation and the full test suite before changing the pins.
The moving `stable` channel selected Flutter 3.50.0 on November 12, 2026, which
introduced Material library deprecation diagnostics across existing app/tests.
Migration to the extracted Material package is future SDK upgrade work.

Workflows are defined in [`.github/workflows/`](file:///home/dog/git/quitepaper/.github/workflows/):
- **Android APK Pipeline** (`build_apk.yml`): Builds signed production APKs for all architectures with ProGuard rules applied.
- **Linux Release Pipeline**: Compiles native Linux binaries and packages them into DEB, RPM, AppImage, and Flatpak formats.
- **Automated CI Build Numbers**: Build numbers are dynamically computed from the total Git commit count (`git rev-list --count HEAD`), guaranteeing monotonically increasing build identifiers without manual bumps.

---

## 3. App Version Bump Checklist

Current release: **1.6.4+22**. When bumping the app release version:

1. Update `pubspec.yaml` (`version: X.Y.Z+BUILD`) and increment the build suffix.
   Android's `android/app/build.gradle.kts`, iOS/macOS bundle metadata, and normal
   Windows builds read Flutter's version. CI overrides the build number with the
   Git commit count.
2. Synchronize runtime fallbacks in `lib/main.dart`,
   `lib/core/version/app_version_provider.dart`, the backup, device and location
   services, weather HTTP user agent, update service/dialog defaults, and
   `qpnote_exporter.dart`. Update
   `lib/core/cli/cli_runner.dart` and version-format test examples as well.
3. Update `linux/packaging/quietpaper.spec`, add a release to
   `linux/com.blackpiratex.quietpaper.metainfo.xml`, and synchronize the fallback
   numeric/string versions in `windows/runner/Runner.rc`.
4. Update badges and footers in both `public/` and `backend/public/`, and prepend
   matching changelog entries. Refresh CI manual-input examples and preserve
   historical release entries.
5. Update `HANDOFF.md` and append release details and validation to
   `handoff/latest-logs.md`. Search tracked files for the previous version to
   catch additional defaults; preserve dependency versions, unrelated protocol
   versions, and archived documentation. The backend API entry point currently
   has no hardcoded application-version header.

---

## 4. First-Run Onboarding & Coach Marks

The onboarding system in [`lib/features/onboarding/`](file:///home/dog/git/quitepaper/lib/features/onboarding/) provides:
- **Interactive Coach Marks**: Highlights essential features (editor toolbar, tags, cloud sync, paper calendar) on first app launch.
- **Settings Replay**: Users can re-trigger the onboarding tutorial at any time from Settings.
- **State Persistence**: Flag stored in `SharedPreferences` to ensure coach marks only display once per install.

---

## Key References & Logs
- Dart AOT CLI Binary & Packaging: [Latest Logs, Section 264](latest-logs.md#264-native-linux-cli-implementation-qp--offline-first-terminal-notes-external-editor-integration-and-sqlite-wal-concurrency-november-2026)
- Dart AOT CLI RPM & Packaging Fix: [Latest Logs, Section 265](latest-logs.md#265-rpm--linux-packaging-fix-for-dart-aot-cli-binary-qp-november-2026)
- Dart AOT CLI Database Path Alignment: [Latest Logs, Section 266](latest-logs.md#266-linux-cli-database-path-alignment-with-desktop-gui-november-2026)
- Dart AOT CLI Frontmatter & Title Fix: [Latest Logs, Section 267](latest-logs.md#267-linux-cli-qp-edit-frontmatter--note-title-parsing-fix-november-2026)
- Linux Native File Sharing (`shareXFiles`): [Latest Logs, Section 262](latest-logs.md#262-linux-desktop-file-sharing-implementation-xdg-desktop-portal-openuri--multi-tier-fallbacks-november-2026)
- Linux Packaging (DEB, RPM, AppImage, Flatpak): [Latest Logs, Section 233](latest-logs.md#233-multi-platform-github-release-workflow-linux-packages-rpm-deb-appimage-flatpak-october-2026)
- Linux GStreamer Resolution: [Latest Logs, Section 224](latest-logs.md#224-linux-app-build-pipeline--gstreamer-dependency-resolution-october-2026)
- Android Quick Capture Widget: [Latest Logs, Section 221](latest-logs.md#221-android-quick-capture--home-screen-widget-october-2026)
- First-Run Onboarding & Coach Marks: [Latest Logs, Section 236](latest-logs.md#236-first-run-onboarding-interactive-coach-marks--settings-replay-october-2026)
- Automated CI Build Numbers: [Latest Logs, Section 133](latest-logs.md#133-automated-ci-build-numbers-git-commit-count--dynamic-runtime-version-resolution)
- App Version Bump Checklist: [Historical Logs v1.0–v1.4, Section 17](archive/logs-v1.0-v1.4.md#17-app-version-bump-checklist)

## Linux CLI image attachments

`qp` can import images without launching Flutter or GTK:

```bash
qp attach <note-id-or-title> photo.png screenshot.jpg
qp attach <note> --clipboard
qp new "Meeting" --attach whiteboard.jpg
qp edit <note> --base-dir ~/Pictures
qp attachments <note>
qp attachments <note> open <attachment-id>
qp sync                    # retry pending local note/image uploads
qp sync <note>             # retry a particular note
```

`new` and `edit` automatically import local Markdown image destinations, including
angle-bracket paths with spaces, balanced parentheses and image reference
definitions. Relative paths use the invocation directory unless `--base-dir` is
specified. Code examples, frontmatter and remote URLs are excluded. Imported paths
become `qp://asset/<UUID>` references. `--attach` is repeatable; `--clipboard` and
`--compress` also work with `new` and `edit`. Binary stdin and URL downloads are
not import sources; piped Markdown remains supported.

Original PNG/JPEG/GIF/WebP/AVIF bytes are preserved by default (10 MiB limit).
Explicit `--compress` converts supported still images to JPEG at quality 85 with
a maximum dimension of 2560 pixels; animation/unsupported decoding is rejected
rather than silently flattened. Compression input is capped at 100 MiB.

The CLI uses the desktop app's QPA1 encryption format and attachment table. It
reads existing credentials through `secret-tool` (Linux Secret Service) or the
app's encrypted fallback store next to the database. It never exports keys or
rewrites the desktop credential store. When only wrapped key data is available,
an interactive invocation prompts for the encryption password; scripts fail
clearly. Initial account/notebook setup still happens in the desktop app. A
headless session needs access to that user's keyring or encrypted fallback files.
Custom databases use credentials beside the selected database; keyring access is
limited to the configured default database.

After saves, CLI sync attempts to upload encrypted images and the encrypted note,
then records attachment references. Offline/authentication/quota failures retain
local data for `qp sync` or desktop sync. Remote conflicts remain pending for the
desktop merge UI. CLI sync is an **upload/retry operation**, not a replacement for
the desktop pull/merge engine; it does not advance the desktop pull cursor.
OCR remains queued for the desktop app. `QP_API_URL` can override the backend.
A successful local save exits 0 even if upload is pending; explicit `qp sync`
exits 1 when any requested note cannot upload.

Image imports and note/history/search/queue changes commit together. Failed
imports roll back the database and remove staged ciphertext, preserving the
original edited Markdown in `<database-directory>/cli-drafts/` (directory 0700,
files 0600). Concurrent edits detected before saving also produce recovery drafts.

Clipboard images require `wl-clipboard` on Wayland or `xclip` on X11 and use the
clipboard of the machine running `qp`. Keyring access requires `secret-tool`
(`libsecret-tools` on Debian/Ubuntu). Opening an image uses `xdg-open`, requires a
locally downloaded image and an interactive terminal, and removes its private
temporary plaintext copy when you press Enter after closing the viewer.

## Email import entry points

Settings → Backup & Import → Import Email selects multiple `.eml` files; the
all-files action handles generic extensions. Desktop Ctrl+Shift+I opens the picker;
Ctrl/Cmd+Shift+P opens searchable import commands. Linux file associations and
workspace/editor drops route into the same confirmation screen. No extra Flatpak
filesystem grants were added: portal paths are kept intact, and denied drops
report an error with picker fallback. desktop_drop exposes no hover file metadata,
so email-specific recognition happens on drop rather than assuming every drag is
email. Native debug compilation is verified; distro package installation and
physical file-manager/sandbox replay require the packaging tools and test hosts.

Android incoming email uses `IncomingShareReceiver` to normalize SEND/MULTIPLE/VIEW
into the existing Dart ShareIntentHandler. It streams ContentResolver data with
bounds while grants are live, stages private temporary copies and removes them
on acknowledgment or next-start recovery. The plugin receives sanitized Android
intents to avoid its extra unbounded copy. No broad binary VIEW handler or new
storage permission was added. Request IDs and serial routing prevent duplicate
previews and protect active capture drafts. Shared text exposes Save as Email;
URL-only shares retain clipping. The GitHub debug APK compiles; physical chooser,
provider permission and Activity lifecycle replay remains unverified without a
device. Existing NDK/KGP warnings are documented in engineering log 339.
