import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

MODULE = Path(__file__).resolve().parents[1] / "manage.py"
spec = importlib.util.spec_from_file_location("manage", MODULE)
manage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manage)


class ExtensionBuildAndInstallTest(unittest.TestCase):
    def test_builds_both_mv3_variants_with_only_click_access(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "build"
            manage.build(output)
            for browser in ("chrome", "firefox"):
                manifest = json.loads((output / browser / "manifest.json").read_text())
                self.assertEqual(manifest["manifest_version"], 3)
                self.assertEqual(set(manifest["permissions"]), {"activeTab", "scripting", "nativeMessaging"})
                self.assertNotIn("host_permissions", manifest)
                with zipfile.ZipFile(output / f"quiet-paper-{browser}.zip") as archive:
                    self.assertIn("capture.js", archive.namelist())
                    self.assertIn("popup.html", archive.namelist())
                    self.assertEqual(json.loads(archive.read("manifest.json")), manifest)
            chrome = json.loads((output / "chrome/manifest.json").read_text())
            firefox = json.loads((output / "firefox/manifest.json").read_text())
            self.assertIn("service_worker", chrome["background"])
            self.assertIn("scripts", firefox["background"])
            self.assertEqual(firefox["browser_specific_settings"]["gecko"]["id"], manage.FIREFOX_ID)

    def test_installer_allowlists_and_launcher_preserve_quoted_paths(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            # These names would execute shell code if not quoted correctly.
            qp = root / "qp $(touch MUST_NOT_EXIST) 'quoted'"
            qp.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            qp.chmod(0o700)
            database = root / "notebook 'private' $name.sqlite"
            env = {"HOME": str(root), "XDG_CONFIG_HOME": str(root / "config"), "XDG_DATA_HOME": str(root / "data")}
            with patch.dict(os.environ, env):
                manage.install(str(qp), ["a" * 32, "b" * 32], manage.FIREFOX_ID, [], str(database))
            chrome_path = root / "config/chromium/NativeMessagingHosts" / f"{manage.HOST}.json"
            firefox_path = root / ".mozilla/native-messaging-hosts" / f"{manage.HOST}.json"
            chrome, firefox = [json.loads(p.read_text()) for p in (chrome_path, firefox_path)]
            self.assertEqual(chrome["allowed_origins"], [f"chrome-extension://{'a' * 32}/", f"chrome-extension://{'b' * 32}/"])
            self.assertNotIn("allowed_extensions", chrome)
            self.assertEqual(firefox["allowed_extensions"], [manage.FIREFOX_ID])
            self.assertNotIn("allowed_origins", firefox)
            launcher = Path(chrome["path"])
            self.assertEqual(launcher.stat().st_mode & 0o777, 0o700)
            self.assertEqual(chrome_path.stat().st_mode & 0o777, 0o600)
            result = subprocess.run([str(launcher), "--version"], cwd=temp, capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout.splitlines(), ["--db", str(database), "browser-host"])
            self.assertFalse((root / "MUST_NOT_EXIST").exists())

    def test_invalid_extension_id_does_not_install(self):
        with tempfile.TemporaryDirectory() as temp, patch.dict(os.environ, {"HOME": temp}):
            with self.assertRaises(ValueError):
                manage.install("/bin/true", ["../../bad"], manage.FIREFOX_ID, [], None)
            self.assertFalse((Path(temp) / ".local").exists())


if __name__ == "__main__":
    unittest.main()
