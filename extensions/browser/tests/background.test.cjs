const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");

const source = fs.readFileSync(path.join(__dirname, "../shared/background.js"), "utf8");

function harness({ captureError, nativeError, html = "<p>Private session text</p>" } = {}) {
  let listener;
  const calls = [];
  const api = {
    scripting: {
      executeScript: async (options) => {
        calls.push(options);
        if (options.files) return [];
        return [{ result: captureError ? { error: captureError } : { capture: {
          url: "https://example.com/private", title: "Original", html,
        } } }];
      },
    },
    runtime: {
      id: "test-extension",
      getURL: (file) => `extension://test/${file}`,
      onMessage: { addListener: (fn) => { listener = fn; } },
      sendNativeMessage: async (host, payload) => {
        calls.push({ host, payload });
        if (nativeError) throw new Error(nativeError);
        return { ok: true, id: "note-id", title: payload.title };
      },
    },
  };
  vm.runInNewContext(source, { chrome: api, TextEncoder });
  const sender = { id: api.runtime.id, url: api.runtime.getURL("popup.html") };
  const message = { action: "clip-tab", tabId: 7, mode: "article", title: "Edited", tags: ["reading"] };
  const run = (overrides = {}) => new Promise((resolve) => listener({ ...message, ...overrides }, sender, resolve));
  return { calls, listener, sender, message, run };
}

test("captures the loaded tab and sends the DOM to qp", async () => {
  const h = harness();
  const result = await h.run();
  assert.equal(result.ok, true);
  assert.equal(h.calls[0].target.tabId, 7);
  assert.equal(h.calls[0].files[0], "capture.js");
  assert.equal(h.calls[2].host, "app.quietpaper.web_clipper");
  assert.equal(h.calls[2].payload.html, "<p>Private session text</p>");
  assert.equal(h.calls[2].payload.title, "Edited");
  assert.equal(h.calls[2].payload.version, 1);
});

test("page or foreign extension messages cannot invoke the native host", () => {
  const h = harness();
  assert.equal(h.listener(h.message, { ...h.sender, url: "https://example.com" }, () => {}), false);
  assert.equal(h.listener(h.message, { ...h.sender, id: "foreign" }, () => {}), false);
  assert.equal(h.calls.length, 0);
});

test("selection errors do not save a partial note", async () => {
  const h = harness({ captureError: "Select some page text first" });
  const result = await h.run({ mode: "selection" });
  assert.equal(result.ok, false);
  assert.match(result.error, /Select some/);
  assert.equal(h.calls.length, 2);
});

test("oversized captures fail before native messaging", async () => {
  const h = harness({ html: "é".repeat(4 * 1024 * 1024) });
  const result = await h.run();
  assert.equal(result.ok, false);
  assert.match(result.error, /8 MiB/);
  assert.equal(h.calls.length, 2);
});

test("native-host failure includes setup guidance", async () => {
  const h = harness({ nativeError: "Host not found" });
  const result = await h.run();
  assert.equal(result.ok, false);
  assert.match(result.error, /Install the Linux native host/);
});
