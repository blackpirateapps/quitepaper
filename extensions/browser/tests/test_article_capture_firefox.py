"""Real DOM regression for the same fixture used by Android scanner tests.

QP_FIREFOX_CHECK=1 python3 -m unittest discover -s extensions/browser/tests \
  -p test_article_capture_firefox.py
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import queue
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT.parents[1] / "test/fixtures/web_clipper/hindu_article.html"


@unittest.skipUnless(os.environ.get("QP_FIREFOX_CHECK") == "1", "opt-in live Firefox check")
class ArticleCaptureTest(unittest.TestCase):
    def test_publisher_body_and_embedded_noise_in_all_capture_modes(self):
        results = queue.Queue()
        fixture = FIXTURE.read_text()
        capture = (ROOT / "shared/capture.js").read_text()
        runner = """
        window.addEventListener('load', () => {
          const send = window.fetch.bind(window);
          window.fetch = () => { throw Error('Capture attempted a fetch'); };
          window.XMLHttpRequest = function() { throw Error('Capture attempted XHR'); };
          let result;
          try {
            const article = quietPaperCapture({mode:'article'});
            const page = quietPaperCapture({mode:'page'});
            const range = document.createRange();
            range.selectNodeContents(document.querySelector('#schemaDiv > p'));
            window.getSelection().removeAllRanges();
            window.getSelection().addRange(range);
            const selection = quietPaperCapture({mode:'selection'});
            window.getSelection().removeAllRanges();
            // The actual publisher page has no semantic main/article root.
            document.querySelector('main').replaceWith(...document.querySelector('main').childNodes);
            const noMain = quietPaperCapture({mode:'article'});
            // Schema.org article bodies must also beat recommendation modules.
            const prose = document.querySelector('#schemaDiv');
            prose.className = '';
            prose.setAttribute('itemprop', 'articleBody');
            document.querySelector('#content-body-71735766').className = '';
            const schema = quietPaperCapture({mode:'article'});
            // A short semantic article still wins over a large main wrapper.
            document.body.innerHTML = '<main><article><p>Short complete article.</p>' +
              '<div class="most-popular article-content"><p>POPULAR_NOISE</p></div>' +
              '</article><div><p>' + 'Outside content. '.repeat(100) + '</p></div></main>';
            const semantic = quietPaperCapture({mode:'article'});
            result = {article,page,selection,noMain,schema,semantic};
          } catch(e) { result = {error:e.stack}; }
          send('/result', {method:'POST',body:JSON.stringify(result)});
        });
        """
        fixture = fixture.replace("</head>", f"<script>{capture}</script><script>{runner}</script></head>")

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                if self.path != "/":
                    self.send_response(404)
                    self.end_headers()
                    return
                data = fixture.encode()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)

            def do_POST(self):
                results.put(json.loads(self.rfile.read(int(self.headers["Content-Length"]))))
                self.send_response(204)
                self.end_headers()

        with tempfile.TemporaryDirectory(prefix="qp-article-check-") as temp:
            server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
            threading.Thread(target=server.serve_forever, daemon=True).start()
            profile = Path(temp) / "profile"
            profile.mkdir()
            with (Path(temp) / "firefox.log").open("w+") as log:
                process = subprocess.Popen([
                    shutil.which("firefox"), "--headless", "--no-remote",
                    "--profile", str(profile), f"http://127.0.0.1:{server.server_port}/",
                ], stdout=log, stderr=log)
                try:
                    try:
                        result = results.get(timeout=40)
                    except queue.Empty:
                        log.seek(0)
                        self.fail("Firefox capture timed out: " + log.read()[-3000:])
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
        for name in ("article", "noMain", "schema"):
            with self.subTest(mode=name):
                html = result[name]["html"]
                for text in ("Police suspended a constable", "Constable denies the allegation",
                             "Most Popular is also a phrase", "FINAL_ARTICLE_PARAGRAPH",
                             "Article photograph caption.", "/article-photo.jpg", "/news/background"):
                    self.assertIn(text, html)
                for text in ("_NOISE", "HIDDEN_DUPLICATE_ARTICLE", "SIDEBAR_FAKE_ARTICLE",
                             "/popular.jpg", "Navigation noise"):
                    self.assertNotIn(text, html)
        self.assertIn("OUTSIDE_POPULAR_NOISE", result["page"]["html"])
        self.assertIn("INLINE_AD_NOISE", result["page"]["html"])
        self.assertIn("Police suspended a constable", result["selection"]["html"])
        self.assertNotIn("FINAL_ARTICLE_PARAGRAPH", result["selection"]["html"])
        self.assertIn("Short complete article.", result["semantic"]["html"])
        self.assertNotIn("POPULAR_NOISE", result["semantic"]["html"])
        self.assertNotIn("Outside content.", result["semantic"]["html"])


if __name__ == "__main__":
    unittest.main()
