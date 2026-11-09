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

Workflows are defined in [`.github/workflows/`](file:///home/dog/git/quitepaper/.github/workflows/):
- **Android APK Pipeline** (`build_apk.yml`): Builds signed production APKs for all architectures with ProGuard rules applied.
- **Linux Release Pipeline**: Compiles native Linux binaries and packages them into DEB, RPM, AppImage, and Flatpak formats.
- **Automated CI Build Numbers**: Build numbers are dynamically computed from the total Git commit count (`git rev-list --count HEAD`), guaranteeing monotonically increasing build identifiers without manual bumps.

---

## 3. App Version Bump Checklist

When bumping the app release version, synchronize all 5 canonical locations:
1. [`pubspec.yaml`](file:///home/dog/git/quitepaper/pubspec.yaml): `version: X.Y.Z+BUILD`
2. `android/app/build.gradle`: `versionName` and `versionCode` (if not reading from Flutter)
3. `lib/core/version/version_info.dart`: Hardcoded fallback runtime version constants
4. `backend/src/api/index.ts`: API compatibility version headers
5. Documentation / Release notes in `handoff/latest-logs.md`

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
- Linux Native File Sharing (`shareXFiles`): [Latest Logs, Section 262](latest-logs.md#262-linux-desktop-file-sharing-implementation-xdg-desktop-portal-openuri--multi-tier-fallbacks-november-2026)
- Linux Packaging (DEB, RPM, AppImage, Flatpak): [Latest Logs, Section 233](latest-logs.md#233-multi-platform-github-release-workflow-linux-packages-rpm-deb-appimage-flatpak-october-2026)
- Linux GStreamer Resolution: [Latest Logs, Section 224](latest-logs.md#224-linux-app-build-pipeline--gstreamer-dependency-resolution-october-2026)
- Android Quick Capture Widget: [Latest Logs, Section 221](latest-logs.md#221-android-quick-capture--home-screen-widget-october-2026)
- First-Run Onboarding & Coach Marks: [Latest Logs, Section 236](latest-logs.md#236-first-run-onboarding-interactive-coach-marks--settings-replay-october-2026)
- Automated CI Build Numbers: [Latest Logs, Section 133](latest-logs.md#133-automated-ci-build-numbers-git-commit-count--dynamic-runtime-version-resolution)
- App Version Bump Checklist: [Historical Logs v1.0–v1.4, Section 17](archive/logs-v1.0-v1.4.md#17-app-version-bump-checklist)
