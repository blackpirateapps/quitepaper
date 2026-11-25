"""Opt-in live DOM/offline CLI check using a disposable headless Firefox profile.

QP_FIREFOX_CHECK=1 QP_BROWSER_CLI=/absolute/path/to/qp python3 -m unittest \
  discover -s extensions/browser/tests -p test_capture_firefox.py
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import json
import os
from pathlib import Path
import queue
import select
import shutil
import sqlite3
import struct
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.environ.get("QP_FIREFOX_CHECK") == "1", "opt-in live Firefox check")
class LiveCaptureTest(unittest.TestCase):
    def test_authenticated_live_dom_without_network_then_native_cli_save(self):
        results = queue.Queue()
        requests = []
        script = (ROOT / "shared/capture.js").read_text()
        fixture = """<!doctype html><html><head><title>Signed-in reading</title>
          <base href="/stories/"><meta name="author" content="Private Writer">
          <style>.private-hidden { display:none; }</style></head><body>
          <nav>Navigation noise</nav><aside>Whole page sidebar</aside>
          <article><h1>Private article</h1><p id="live">Placeholder</p>
          <p><a href="related">Related</a><img src="/photo.png" alt="Photo"></p>
          <p class="private-hidden">CSS_HIDDEN_SECRET</p>
          <div hidden>HIDDEN_SECRET</div><form>FORM_SECRET<input value="password"></form>
          <pre><code class="language-js">const a = 1;</code></pre>
          <p><a href="file:///etc/passwd">Unsafe file link</a></p></article>
          <script>CAPTURE_SCRIPT</script><script>
          window.addEventListener('load', () => {
            document.querySelector('#live').textContent = 'Authenticated live DOM café ☕';
            const originalFetch = window.fetch;
            window.fetch = () => { throw Error('Capture attempted a fetch'); };
            window.XMLHttpRequest = function() { throw Error('Capture attempted XHR'); };
            let result;
            try {
              const article = quietPaperCapture({mode:'article'});
              const page = quietPaperCapture({mode:'page'});
              const range = document.createRange();
              range.selectNodeContents(document.querySelector('#live'));
              window.getSelection().removeAllRanges();
              window.getSelection().addRange(range);
              const selection = quietPaperCapture({mode:'selection'});
              window.getSelection().removeAllRanges();
              let selectionError;
              try { quietPaperCapture({mode:'selection'}); } catch(e) { selectionError = e.message; }
              result = {article,page,selection,selectionError};
            } catch(e) { result = {error: e.stack}; }
            originalFetch('/result', {method:'POST',body:JSON.stringify(result)});
          });
          </script></body></html>""".replace("CAPTURE_SCRIPT", script)

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                requests.append(self.path)
                if self.path == "/":
                    self.send_response(302)
                    self.send_header("Set-Cookie", "session=authenticated; Path=/; HttpOnly")
                    self.send_header("Location", "/private")
                    self.end_headers()
                    return
                if self.path == "/private" and "session=authenticated" in self.headers.get("Cookie", ""):
                    data = fixture.encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                if self.path == "/photo.png":
                    data = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1sAAAAASUVORK5CYII=")
                    self.send_response(200)
                    self.send_header("Content-Type", "image/png")
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                self.send_response(404)
                self.end_headers()

            def do_POST(self):
                if self.path != "/result":
                    self.send_response(404)
                    self.end_headers()
                    return
                results.put(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                self.send_response(204)
                self.end_headers()

        with tempfile.TemporaryDirectory(prefix="qp-browser-check-") as temp:
            root = Path(temp)
            profile = root / "profile"
            profile.mkdir()
            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            env = {**os.environ, "HOME": temp, "XDG_CACHE_HOME": str(root / "cache"), "MOZ_CRASHREPORTER_DISABLE": "1"}
            with (root / "firefox.log").open("w") as log:
                process = subprocess.Popen([shutil.which("firefox"), "--headless", "--no-remote", "--profile", str(profile), f"http://127.0.0.1:{server.server_port}/"], env=env, stdout=log, stderr=log)
                try:
                    try:
                        result = results.get(timeout=40)
                        # Allow accidental asynchronous clone-image loads to
                        # reach the fixture so the request-count check sees them.
                        threading.Event().wait(0.3)
                    except queue.Empty:
                        self.fail("Firefox capture timed out: " + (root / "firefox.log").read_text()[-3000:])
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(timeout=5)
                    server.shutdown()
                    server.server_close()
            self.assertNotIn("error", result)
            article = result["article"]
            self.assertIn("Authenticated live DOM café ☕", article["html"])
            self.assertEqual(article["author"], "Private Writer")
            self.assertIn(f'http://127.0.0.1:{server.server_port}/stories/related', article["html"])
            for secret in ("HIDDEN_SECRET", "CSS_HIDDEN_SECRET", "FORM_SECRET", "file:", "<script", "Navigation noise", "Whole page sidebar"):
                self.assertNotIn(secret, article["html"])
            self.assertIn("Whole page sidebar", result["page"]["html"])
            self.assertIn("Authenticated live DOM", result["selection"]["html"])
            self.assertNotIn("Private article", result["selection"]["html"])
            self.assertIn("Select some page text", result["selectionError"])
            self.assertEqual(requests.count("/private"), 1)
            self.assertEqual(requests.count("/photo.png"), 1, requests)

            # Server is now closed. Saving must only use the DOM already captured.
            cli = os.environ.get("QP_BROWSER_CLI")
            if not cli:
                self.fail("Set QP_BROWSER_CLI to the newly built native qp for the offline save check.")
            db_path = root / "notebook.sqlite"
            payload = {**article, "version": 1, "action": "clip", "tags": ["private-reading"]}
            raw = json.dumps(payload).encode()
            process = subprocess.Popen([cli, "--db", str(db_path), "browser-host"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                ping = json.dumps({"version": 1, "action": "ping"}).encode()
                process.stdin.write(struct.pack("@I", len(ping)) + ping)
                process.stdin.flush()
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], "Host must reply without waiting for stdin EOF")
                length = struct.unpack("@I", process.stdout.read(4))[0]
                self.assertTrue(json.loads(process.stdout.read(length))["ok"])
                stdout, stderr = process.communicate(struct.pack("@I", len(raw)) + raw, timeout=15)
                self.assertEqual(process.returncode, 0, stderr.decode())
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait(timeout=5)
            length = struct.unpack("@I", stdout[:4])[0]
            response = json.loads(stdout[4:4 + length])
            self.assertTrue(response["ok"], response)
            self.assertEqual(len(stdout), length + 4, "stdout must contain only framed JSON")
            with sqlite3.connect(db_path) as db:
                content = db.execute("SELECT content FROM notes WHERE id=?", [response["id"]]).fetchone()[0]
                self.assertIn("Authenticated live DOM café ☕", content)
                self.assertIn("```js", content)
                self.assertEqual(db.execute("SELECT COUNT(*) FROM sync_queue").fetchone()[0], 1)


if __name__ == "__main__":
    unittest.main()
