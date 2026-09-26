const $ = (id) => document.getElementById(id);
let lastText = "";

async function native(payload) {
  return browser.runtime.sendMessage(Object.assign({ kind: "status" }, payload));
}

async function refreshStatus() {
  // Ask the current tab to report itself first, so the page you are on is always the newest.
  try {
    const tabs = await browser.tabs.query({ active: true, currentWindow: true });
    if (tabs[0]) { const page = await browser.tabs.sendMessage(tabs[0].id, { kind: "grab" }); if (page) await browser.runtime.sendMessage(page); }
  } catch (e) {}
  const s = await native({ kind: "status" });
  const box = $("pages");
  box.innerHTML = "";
  const pages = (s && s.pages) || [];
  if (pages.length === 0) {
    box.innerHTML = '<div class="row muted">Read two pages in Safari, then come back.</div>';
  } else {
    for (const p of pages) {
      const row = document.createElement("div"); row.className = "row";
      row.innerHTML = '<span class="dot"></span><span class="t"></span>';
      row.querySelector(".t").textContent = p.title || p.url;
      box.appendChild(row);
    }
    if (pages.length === 1) {
      const row = document.createElement("div"); row.className = "row muted"; row.textContent = "Open one more page to fuse with this."; box.appendChild(row);
    }
  }
  $("fuse").disabled = pages.length < 2;
  if (s && s.hasKey === false) { $("err").style.display = "block"; $("err").textContent = "Open Fuse once so it can share its key with Safari."; }
}

async function fuse() {
  $("err").style.display = "none";
  $("result").style.display = "none";
  const b = $("fuse"); b.disabled = true; b.textContent = "Fusing…";
  try {
    const r = await native({ kind: "fuse", instruction: $("instruction").value });
    if (!r || !r.ok) throw new Error((r && r.error) || "Couldn't fuse.");
    $("rtitle").textContent = r.title || "Fused";
    $("rsummary").textContent = r.summary || "";
    $("rtext").textContent = r.text || "";
    lastText = [r.title, r.summary, r.text].filter(Boolean).join("\n\n");
    $("result").style.display = "block";
    b.textContent = "Done";
  } catch (e) {
    $("err").textContent = e.message; $("err").style.display = "block";
    b.textContent = "Fuse these"; b.disabled = false;
  }
}

$("fuse").addEventListener("click", fuse);
$("again").addEventListener("click", () => { $("fuse").textContent = "Fuse these"; $("fuse").disabled = false; fuse(); });
$("copy").addEventListener("click", async () => { try { await navigator.clipboard.writeText(lastText); $("copy").textContent = "Copied"; } catch (e) {} });
refreshStatus();
