/* global browser, chrome */
const api = globalThis.browser ?? chrome;
const form = document.querySelector("#clip-form");
const save = document.querySelector("#save");
const status = document.querySelector("#status");
let tabId;
document.querySelector("#extension-id").textContent = api.runtime.id;

function showStatus(text, error = false) {
  status.textContent = text;
  status.dataset.error = String(error);
}

save.disabled = true;
api.tabs.query({ active: true, currentWindow: true }).then(([tab]) => {
  if (!tab || !/^https?:\/\//.test(tab.url || "")) {
    showStatus("Open an HTTP or HTTPS webpage to clip it. Browser settings and extension store pages cannot be captured.", true);
    return;
  }
  tabId = tab.id;
  document.querySelector("#title").value = tab.title || "";
  save.disabled = false;
}).catch((error) => showStatus(error.message, true));

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  if (save.disabled) return;
  save.disabled = true;
  showStatus("Saving the loaded page…");
  try {
    const response = await api.runtime.sendMessage({
      action: "clip-tab",
      tabId,
      mode: document.querySelector("#mode").value,
      title: document.querySelector("#title").value,
      tags: document.querySelector("#tags").value.split(",").map((tag) => tag.trim().replace(/^#/, "")).filter(Boolean),
    });
    if (!response?.ok) throw new Error(response?.error || "The clip could not be saved.");
    showStatus(`Saved “${response.title}” locally. Quiet Paper will sync it when the desktop app runs.`);
    save.textContent = "Saved";
  } catch (error) {
    showStatus(error.message, true);
    save.disabled = false;
  }
});
