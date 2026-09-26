const $ = (id) => document.getElementById(id);
let lastResult = null;
let styleInjected = false;

async function native(payload) {
  return browser.runtime.sendMessage(Object.assign({ kind: "status" }, payload));
}

function ensureStyle() {
  if (styleInjected) return;
  styleInjected = true;
  const s = document.createElement("style");
  s.textContent = window.FuseRender.css("");
  document.head.appendChild(s);
}

async function refreshStatus() {
  // Ask the current tab to report itself first, so the page you are on is always the newest.
  try {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (tabs[0]) { const page = await browser.tabs.sendMessage(tabs[0].id, { kind: "grab" }); if (page) await browser.runtime.sendMessage(page); }
  } catch (e) {}
  const s = await native({ kind: "status" });
  const box = $("pages");
  box.textContent = "";
  const pages = (s && s.pages) || [];
  if (pages.length === 0) {
    const row = document.createElement("div"); row.className = "row muted"; row.textContent = "Read two pages in Safari, then come back."; box.appendChild(row);
  } else {
    for (const p of pages) {
      const row = document.createElement("div"); row.className = "row";
      const dot = document.createElement("span"); dot.className = "dot";
      const t = document.createElement("span"); t.className = "t"; t.textContent = p.title || p.url;
      row.appendChild(dot); row.appendChild(t);
      box.appendChild(row);
    }
    if (pages.length === 1) {
      const row = document.createElement("div"); row.className = "row muted"; row.textContent = "Open one more page to fuse with this."; box.appendChild(row);
    }
  }
  $("fuse").disabled = pages.length < 2;
  if (s && s.hasKey === false) { $("err").style.display = "block"; $("err").textContent = "Open Fuse once so it can share its key with Safari."; }
}

function setBusy(busy) {
  const b = $("fuse");
  b.disabled = busy;
  b.classList.toggle("busy", busy);
  $("fuse-label").textContent = busy ? "Fusing" : "Fuse these";
}

function showResult(r) {
  ensureStyle();
  lastResult = r;
  const box = $("result");
  box.textContent = "";
  box.appendChild(window.FuseRender.render(r, { onFollowUp: (text) => fuse(text) }));
  document.body.classList.add("done");
  $("body").scrollTop = 0;
  $("copy").textContent = "Copy";
}

async function fuse(instruction) {
  $("err").style.display = "none";
  document.body.classList.remove("done");
  const text = typeof instruction === "string" ? instruction : $("instruction").value;
  if (typeof instruction === "string") $("instruction").value = instruction;
  setBusy(true);
  try {
    const r = await native({ kind: "fuse", instruction: text });
    if (!r || !r.ok) throw new Error((r && r.error) || "Couldn't fuse.");
    showResult(r);
  } catch (e) {
    $("err").textContent = e.message; $("err").style.display = "block";
  } finally {
    setBusy(false);
  }
}

$("fuse").addEventListener("click", () => fuse());
$("instruction").addEventListener("keydown", (e) => { if (e.key === "Enter" && !$("fuse").disabled) fuse(); });
$("again").addEventListener("click", () => { document.body.classList.remove("done"); $("body").scrollTop = 0; });
$("copy").addEventListener("click", async () => {
  if (!lastResult) return;
  try { await navigator.clipboard.writeText(window.FuseRender.plainText(lastResult)); $("copy").textContent = "Copied"; } catch (e) {}
});
refreshStatus();
