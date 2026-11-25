# Quiet Paper Web Clipper for Linux

Save the page already open in Chrome/Chromium, Brave, Edge, Vivaldi, Firefox,
or LibreWolf directly to the Linux `qp` CLI. The extension reads the live DOM,
including content available after signing in. It never requests the page again,
uses a reader proxy, or transfers cookies or browser credentials to the CLI.

Choose **Article**, **Whole page**, or **Selected text**, edit the title, optionally
add comma-separated tags, then **Save web clip**. The existing web clip Markdown
converter preserves headings, links, lists, tables, quotes, and code. Notes include
source/author/date metadata, `clipped` and domain tags (for example,
`web/example-com`), history, search entries,
and the normal sync queue. The desktop app can be closed while clipping.

This version saves text and remote image links. It does not archive image bytes,
stylesheets, or an HTML snapshot. Images may still need the original login, and
are not available offline. Only content currently loaded in the top-level DOM is
captured: scroll/expand the article first if necessary. Embedded frames, shadow
DOM, browser settings, extension stores, PDFs, and content not accessible to your
current session are outside this capture path.

## Build and load

From the repository root, using the repository's Flutter/Dart SDK:

```sh
dart build cli -t bin/qp.dart -o build/browser-extension/cli
python3 extensions/browser/manage.py build
```

The native CLI must be compiled from this branch; an older installed `qp` does
not have the `browser-host` command. Keep the compiled executable in a stable
location, together with its sibling `lib/` directory of native assets, or rerun
registration after moving the bundle. No Python packages or Node
dependencies are required to build/install the extension.

- **Chrome family (120+):** open `chrome://extensions` (or the browser's extensions
  page), enable Developer mode, choose **Load unpacked**, and select
  `extensions/browser/dist/chrome`. Copy the extension ID from that page or the
  popup's **Connection setup** disclosure.
- **Firefox (140+) / LibreWolf:** open `about:debugging#/runtime/this-firefox`,
  choose **Load Temporary Add-on**, and select
  `extensions/browser/dist/firefox/manifest.json`. The fixed add-on ID is
  `web-clipper@quietpaper.app`. Temporary add-ons disappear on browser restart;
  a permanent Firefox release requires Mozilla signing. ZIPs in `dist` are
  build artifacts, not signed store releases.

Register the host for your user (replace the Chrome ID; omit `--chrome-id` for a
Firefox-only setup):

```sh
python3 extensions/browser/manage.py install \
  --qp "$PWD/build/browser-extension/cli/bundle/bin/qp" \
  --chrome-id abcdefghijklmnopabcdefghijklmnop
```

You can repeat `--chrome-id` for multiple browser installs. Registration writes
Chrome-family manifests under `$XDG_CONFIG_HOME` (default `~/.config`), Firefox
under `~/.mozilla/native-messaging-hosts`, and LibreWolf under
`~/.librewolf/native-messaging-hosts`. A private launcher lives under
`$XDG_DATA_HOME/quietpaper/browser-host` (default `~/.local/share`). No sudo is
needed. Other Chromium forks/custom user-data directories can use
`--manifest-dir /absolute/path/to/NativeMessagingHosts`. `--db` optionally selects
a separate notebook; normally leave it unset to share the desktop database.
Rerunning installation replaces the previous allowlist: pass every Chrome ID
you want to retain. Sandboxed browsers need additional setup; the Brave Flatpak
procedure below has been checked on this device. Other sandboxed packages remain
unverified.

Reload the extension after registration. Open a webpage, click the extension,
and save a clip. The success message means the local database transaction has
completed. Cloud upload is handled by the desktop app's normal sync when it runs,
or explicitly through `qp sync`. No login, password prompt, or cloud connection
is needed for a local capture.

To remove registration, delete `app.quietpaper.web_clipper.json` from the browser
directories listed above and the `quietpaper/browser-host` launcher directory.
This leaves notes and your notebook untouched.

## Brave installed through Flatpak

Brave Flatpak cannot normally see an external CLI or the desktop notebook. Keep
the extension and the complete CLI bundle inside its private app data instead:

- Extension: `~/.var/app/com.brave.Browser/data/quietpaper/web-clipper/`.
- CLI bundle: `~/.var/app/com.brave.Browser/data/quietpaper/cli/`, retaining both
  `bin/qp` and `lib/libsqlite3.so`.
- Private executable launcher:
  `~/.var/app/com.brave.Browser/data/quietpaper/browser-host/launch`. It must run
  the bundled `qp --db /absolute/path/to/desktop/quiet_paper.sqlite browser-host`.
- Native host manifest:
  `~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/NativeMessagingHosts/app.quietpaper.web_clipper.json`.
  Use the same native host schema described above: `name`, `description`, the
  launcher's absolute `path`, `type: "stdio"`, and `allowed_origins` containing
  `chrome-extension://YOUR_EXTENSION_ID/`. Paths in the manifest cannot use `~`.

Load the unpacked extension from its private data path and use its actual ID in
the allowlist. The general installer does not perform these Flatpak-specific
copies or grant notebook access. For the canonical desktop database, grant the
directory so SQLite can also create its WAL and shared-memory sidecar files:

```sh
flatpak override --user \
  --filesystem="$HOME/.local/share/com.blackpiratex.quietpaper" com.brave.Browser
```

**Completely quit and reopen Brave** after adding this grant. Existing browser
processes retain their previous sandbox permissions. The explicit `--db` path is
essential: otherwise the CLI's XDG default would select a different notebook
inside Brave's private data directory. The CLI runs inside the sandbox; this
setup does not grant permission to launch arbitrary host commands.

On this device, the installed launcher was checked from a fresh Brave Flatpak
process with a native protocol ping, notebook-directory access checks, and a
synthetic clip saved to a temporary notebook. These terminal checks leave real
notes untouched; the first browser save still needs the full restart above.

## Implementation and checks

The only extension permissions are `activeTab`, `scripting`, and
`nativeMessaging`. Page access is granted when you click the extension; there
are no persistent host permissions, network acquisition code, content scripts
running on every page, cookies, telemetry, or listening local HTTP servers.
Active content, forms, hidden elements, and non-web URLs are removed. Treat
visible article content as private if you save an authenticated page: it becomes
part of your normal local notebook and encrypted cloud sync, like any other note.

Shared sources live in `shared/`; browser-specific MV3 manifests live in
`manifests/`. The browser selects and sanitizes the loaded DOM. `qp browser-host`
validates the bounded capture and sanitizes it again, then calls the shared
`HtmlToMarkdownConverter` and transactional `CliDatabase.createNote`. It does not
use `scanUrl`, `scanPayload` (which probes images), or snapshot generation (which
can acquire CSS). Native messages use a native-endian four-byte length prefix and
UTF-8 JSON, following [Chrome native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)
and [Firefox native messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging).
Capture frames are limited to 8 MiB; responses contain a small success/error
object, never page content. Stdout is exclusively framed JSON.

```sh
flutter analyze
flutter test test/cli/cli_browser_host_test.dart test/cli/cli_runner_test.dart \
  test/web_clipper/web_clipper_service_test.dart
python3 -m unittest discover -s extensions/browser/tests -p 'test_*.py'
node --test extensions/browser/tests/background.test.cjs

# Shared publisher fixture: article-only output in Firefox and Android's scanner
flutter test test/web_clipper/article_content_regression_test.dart
QP_FIREFOX_CHECK=1 python3 -m unittest discover -s extensions/browser/tests \
  -p test_article_capture_firefox.py

# Optional live Firefox fixture and offline native CLI integration (isolated profile)
QP_FIREFOX_CHECK=1 \
QP_BROWSER_CLI="$PWD/build/browser-extension/cli/bundle/bin/qp" \
python3 -m unittest discover -s extensions/browser/tests -p test_capture_firefox.py
```

Manual browser acceptance: sign in to an article, disconnect the network after
it loads, clip it, and verify its unique text with `qp show <id> --raw`. Repeat
with whole-page and selected-text modes. Check missing-host and restricted-page
errors, then reopen the desktop app and confirm the source metadata and tags.
