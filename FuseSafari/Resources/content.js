// Fuse in Safari.
//  1. Every page you read is remembered (URL, title, visible text, selection).
//  2. Folding the phone is the command: when the viewport collapses to the cover display,
//     the two pages you had side by side are fused in the background and the result is
//     drawn right here, as a sheet inside the page. Nothing to tap.
(function () {
  if (window.top !== window) return;   // main frame only

  function grab() {
    const text = (document.body && document.body.innerText || "").replace(/\s+\n/g, "\n").replace(/[ \t]+/g, " ").trim().slice(0, 6000);
    const selection = (window.getSelection && window.getSelection().toString() || "").trim().slice(0, 2000);
    return { kind: "visit", url: location.href, title: document.title || location.hostname, text: text, selection: selection };
  }

  let timer = null;
  function send() {
    clearTimeout(timer);
    timer = setTimeout(() => { try { browser.runtime.sendMessage(grab()); } catch (e) {} }, 500);
  }
  if (document.readyState === "complete") send(); else window.addEventListener("load", send);
  document.addEventListener("selectionchange", send);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) send(); });

  // --- Fold detection -------------------------------------------------------------------
  // Track the largest viewport this page has had. A sudden collapse (>30 %) is the fold to
  // the cover display; growing back is the unfold. The Device Posture API is used when present.
  let maxArea = 0, folded = false, lastFuseAt = 0, busy = false;
  function area() { return (window.innerWidth || 0) * (window.innerHeight || 0); }
  function check() {
    const a = area();
    if (a > maxArea) maxArea = a;
    const collapsed = maxArea > 0 && a < maxArea * 0.7;
    if (collapsed && !folded) { folded = true; onFold(); }
    else if (!collapsed && folded) { folded = false; }
  }
  window.addEventListener("resize", () => setTimeout(check, 120));
  if (window.matchMedia) {
    try {
      const mq = window.matchMedia("(device-posture: folded)");
      if (mq && typeof mq.addEventListener === "function") mq.addEventListener("change", (e) => { if (e.matches) onFold(); });
    } catch (e) {}
  }
  setTimeout(check, 800);

  async function onFold() {
    const now = Date.now();
    if (busy || now - lastFuseAt < 15000) return;
    busy = true; lastFuseAt = now;
    showSheet("Fusing", "Reading both pages…", "", true);
    try {
      try { await browser.runtime.sendMessage(grab()); } catch (e) {}
      const r = await browser.runtime.sendMessage({ kind: "fold", url: location.href, title: document.title });
      if (r && r.ok) showSheet(r.title || "Fused", r.summary || "", r.text || "", false);
      else showSheet("Couldn't fuse", (r && r.error) || "Try again.", "", false);
    } catch (e) {
      showSheet("Couldn't fuse", String(e && e.message || e), "", false);
    } finally { busy = false; }
  }

  // --- The sheet ---------------------------------------------------------------------------
  let sheet = null;
  function showSheet(title, summary, text, working) {
    if (!sheet) {
      sheet = document.createElement("div");
      sheet.id = "fuse-sheet";
      sheet.setAttribute("style", [
        "position:fixed", "left:12px", "right:12px", "bottom:12px", "z-index:2147483647",
        "max-height:62vh", "display:flex", "flex-direction:column",
        "background:rgba(255,255,255,0.96)", "color:#111", "border-radius:22px",
        "box-shadow:0 12px 40px rgba(0,0,0,0.22), 0 0 0 0.5px rgba(0,0,0,0.08)",
        "font-family:-apple-system,system-ui", "-webkit-backdrop-filter:saturate(180%) blur(20px)", "backdrop-filter:saturate(180%) blur(20px)",
        "transform:translateY(120%)", "transition:transform 0.45s cubic-bezier(0.2,0.9,0.2,1)"
      ].join(";"));
      if (window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches) {
        sheet.style.background = "rgba(28,28,30,0.96)"; sheet.style.color = "#fff";
      }
      sheet.innerHTML =
        '<div style="display:flex;align-items:center;gap:10px;padding:14px 16px 6px">' +
          '<div style="width:22px;height:22px;flex:0 0 auto"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="12" r="6.5"/><circle cx="15" cy="12" r="6.5"/></svg></div>' +
          '<div id="fuse-title" style="font-size:17px;font-weight:600;flex:1;letter-spacing:-0.2px"></div>' +
          '<div id="fuse-close" style="width:28px;height:28px;border-radius:14px;background:rgba(120,120,128,0.16);display:flex;align-items:center;justify-content:center;font-size:15px">&#x2715;</div>' +
        '</div>' +
        '<div id="fuse-summary" style="padding:0 16px 8px;font-size:15px;line-height:1.35;opacity:0.9"></div>' +
        '<div id="fuse-text" style="margin:0 16px 16px;padding:12px 14px;border-radius:14px;background:rgba(120,120,128,0.12);font-size:14px;line-height:1.4;white-space:pre-wrap;overflow:auto;display:none"></div>';
      document.documentElement.appendChild(sheet);
      sheet.querySelector("#fuse-close").addEventListener("click", () => { sheet.style.transform = "translateY(120%)"; });
      requestAnimationFrame(() => requestAnimationFrame(() => { sheet.style.transform = "translateY(0)"; }));
    } else {
      sheet.style.transform = "translateY(0)";
    }
    sheet.querySelector("#fuse-title").textContent = title;
    sheet.querySelector("#fuse-summary").textContent = summary;
    const t = sheet.querySelector("#fuse-text");
    t.textContent = text; t.style.display = text ? "block" : "none";
    sheet.querySelector("#fuse-title").style.opacity = working ? 0.6 : 1;
  }

  // The popup asks the page for its content when the user taps a half.
  browser.runtime.onMessage.addListener((m, s, respond) => { if (m && m.kind === "grab") { respond(grab()); return true; } });
})();
