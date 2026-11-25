/* global browser, chrome */
const extensionApi = globalThis.browser ?? chrome;
const nativeHost = "app.quietpaper.web_clipper";

async function clipTab(message) {
  if (!Number.isInteger(message.tabId) || !["article", "page", "selection"].includes(message.mode)) {
    throw new Error("Invalid capture request.");
  }
  await extensionApi.scripting.executeScript({ target: { tabId: message.tabId }, files: ["capture.js"] });
  const results = await extensionApi.scripting.executeScript({
    target: { tabId: message.tabId },
    func: (options) => {
      try { return { capture: globalThis.quietPaperCapture(options) }; }
      catch (error) { return { error: error.message }; }
    },
    args: [{ mode: message.mode }],
  });
  const result = results[0]?.result;
  if (!result || result.error) throw new Error(result?.error || "Could not read this page.");
  const payload = {
    ...result.capture,
    version: 1,
    action: "clip",
    title: message.title?.trim() || result.capture.title,
    tags: message.tags,
  };
  if (new TextEncoder().encode(JSON.stringify(payload)).length > 8 * 1024 * 1024) {
    throw new Error("This page exceeds 8 MiB. Clip a selection instead.");
  }
  try {
    return await extensionApi.runtime.sendNativeMessage(nativeHost, payload);
  } catch (error) {
    throw new Error(`Cannot reach the Quiet Paper CLI. Install the Linux native host and check its extension ID. ${error.message}`);
  }
}

extensionApi.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== extensionApi.runtime.id ||
      sender.url !== extensionApi.runtime.getURL("popup.html") ||
      message?.action !== "clip-tab") return false;
  // Keeping the response channel open lets a capture finish if the popup closes.
  clipTab(message).then(sendResponse, (error) => sendResponse({ ok: false, error: error.message }));
  return true;
});
