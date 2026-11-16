#!/usr/bin/env python3
"""Build browser bundles and register the Linux qp native messaging host.

Uses the Python standard library only. Installation is per user, without sudo.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parent
HOST = "app.quietpaper.web_clipper"
FIREFOX_ID = "web-clipper@quietpaper.app"
CHROMIUM_DIRS = (
    "google-chrome", "google-chrome-beta", "google-chrome-unstable",
    "chromium", "BraveSoftware/Brave-Browser", "microsoft-edge", "vivaldi",
)


def build(destination):
    destination = destination.resolve()
    for browser in ("chrome", "firefox"):
        target = destination / browser
        target.mkdir(parents=True, exist_ok=True)
        for source in (ROOT / "shared").iterdir():
            shutil.copyfile(source, target / source.name)
        shutil.copyfile(ROOT / "manifests" / f"{browser}.json", target / "manifest.json")
        archive = destination / f"quiet-paper-{browser}.zip"
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
            for source in sorted(target.iterdir()):
                if source.is_file():
                    bundle.write(source, source.name)
        print(f"Built {target} and {archive}")


def install(qp, chrome_ids, firefox_id, extra_dirs, database):
    if not sys.platform.startswith("linux"):
        raise ValueError("Native host installation currently supports Linux only.")
    executable = Path(qp).expanduser().resolve()
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError(f"qp must be an executable file: {executable}")
    if any(not re.fullmatch(r"[a-p]{32}", extension_id) for extension_id in chrome_ids):
        raise ValueError("Chrome extension IDs must contain 32 letters from a to p.")
    if not firefox_id or any(c in firefox_id for c in "\r\n\0"):
        raise ValueError("Invalid Firefox extension ID.")
    if extra_dirs and not chrome_ids:
        raise ValueError("--manifest-dir requires at least one --chrome-id.")

    home = Path.home()
    config = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    data = Path(os.environ.get("XDG_DATA_HOME", home / ".local/share"))
    if not config.is_absolute() or not data.is_absolute():
        raise ValueError("XDG_CONFIG_HOME and XDG_DATA_HOME must be absolute paths.")
    host_dir = data / "quietpaper/browser-host"
    host_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    launcher = host_dir / "launch"
    arguments = [str(executable)]
    if database:
        arguments.extend(["--db", str(Path(database).expanduser().resolve())])
    arguments.append("browser-host")
    # Browser-provided origin arguments are intentionally not forwarded to qp.
    launcher.write_text("#!/bin/sh\nexec " + shlex.join(arguments) + "\n")
    launcher.chmod(0o700)
    common = {"name": HOST, "description": "Quiet Paper Linux web clipper",
              "path": str(launcher), "type": "stdio"}
    manifests = []
    if chrome_ids:
        chrome = {**common, "allowed_origins": [f"chrome-extension://{i}/" for i in chrome_ids]}
        manifests.extend((config / directory / "NativeMessagingHosts", chrome)
                         for directory in CHROMIUM_DIRS)
        manifests.extend((Path(directory).expanduser().resolve(), chrome) for directory in extra_dirs)
    firefox = {**common, "allowed_extensions": [firefox_id]}
    manifests.extend((home / directory / "native-messaging-hosts", firefox)
                     for directory in (".mozilla", ".librewolf"))
    for directory, manifest in manifests:
        directory.mkdir(parents=True, exist_ok=True)
        path = directory / f"{HOST}.json"
        path.write_text(json.dumps(manifest, indent=2) + "\n")
        path.chmod(0o600)
        print(f"Registered {path}")
    print(f"Host executable: {executable}")
    print("Reload the extension, then open an article and click Save web clip.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    builder = commands.add_parser("build", help="Build Chrome/Firefox directories and ZIPs")
    builder.add_argument("--output", type=Path, default=ROOT / "dist")
    installer = commands.add_parser("install", help="Register a compiled qp for this Linux user")
    installer.add_argument("--qp", required=True, help="Absolute path to the newly compiled qp")
    installer.add_argument("--chrome-id", action="append", default=[], help="Extension ID from chrome://extensions (repeatable)")
    installer.add_argument("--firefox-id", default=FIREFOX_ID)
    installer.add_argument("--manifest-dir", action="append", default=[], help="Extra Chromium-family NativeMessagingHosts directory")
    installer.add_argument("--db", help="Optional database override, normally omit this")
    args = parser.parse_args()
    try:
        if args.command == "build":
            build(args.output)
        else:
            install(args.qp, args.chrome_id, args.firefox_id, args.manifest_dir, args.db)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Error: {error}\n")


if __name__ == "__main__":
    main()
