// Fuse in Safari.
//  1. Every page you read is remembered (URL, title, visible text, selection), plus the photo
//     when the page is mainly showing one (an image opened on its own, an image viewer, a photo
//     page). Two remembered photos, say one person on each half, fold into one fused photo.
//  2. Folding the phone is the command: when the display collapses, the two pages you had
//     open are fused in the background and the result is drawn right here, as a sheet inside
//     the page. Nothing to tap.
(function () {
  if (window.top !== window) return;   // main frame only
  const R = window.FuseRender;

  // Same rules as PageImage.detectionScript in the app. Keep them in sync.
  const MIN_COVERAGE = 0.3;

  function primaryImage() {
    const vw = window.innerWidth || document.documentElement.clientWidth;
    const vh = window.innerHeight || document.documentElement.clientHeight;
    if (!vw || !vh) return null;
    if ((document.contentType || "").indexOf("image/") === 0) {
      const only = document.images[0];
      return { src: location.href, alt: "", width: only ? only.naturalWidth : 0, height: only ? only.naturalHeight : 0, coverage: 1 };
    }
    let best = null, bestArea = 0;
    for (const img of document.images) {
      if (!img.complete || img.naturalWidth < 256 || img.naturalHeight < 256) continue;
      const r = img.getBoundingClientRect();
      const w = Math.min(r.right, vw) - Math.max(r.left, 0);
      const h = Math.min(r.bottom, vh) - Math.max(r.top, 0);
      if (w <= 0 || h <= 0 || w * h <= bestArea) continue;
      const cs = window.getComputedStyle(img);
      if (cs.visibility === "hidden" || cs.display === "none" || parseFloat(cs.opacity) < 0.2) continue;
      best = img; bestArea = w * h;
    }
    if (!best) return null;
    const coverage = bestArea / (vw * vh);
    if (coverage < MIN_COVERAGE) return null;
    let src = best.currentSrc || best.src || "";
    if (src.indexOf("blob:") === 0) {
      try {
        const c = document.createElement("canvas");
        c.width = best.naturalWidth; c.height = best.naturalHeight;
        c.getContext("2d").drawImage(best, 0, 0);
        src = c.toDataURL("image/jpeg", 0.92);
      } catch (e) { return null; }
    }
    if (!src || (src.indexOf("data:") === 0 && src.length > 6000000)) return null;
    return { src: src, alt: (best.alt || best.title || "").slice(0, 300), width: best.naturalWidth, height: best.naturalHeight, coverage: Math.round(coverage * 100) / 100 };
  }

  function grab() {
    const text = (document.body && document.body.innerText || "").replace(/\s+\n/g, "\n").replace(/[ \t]+/g, " ").trim().slice(0, 6000);
    const selection = (window.getSelection && window.getSelection().toString() || "").trim().slice(0, 2000);
    let image = null;
    try { image = primaryImage(); } catch (e) {}
    return { kind: "visit", url: location.href, title: document.title || location.hostname, text: text, selection: selection, image: image };
  }

  let timer = null;
  let lastImage = "";
  function send() {
    clearTimeout(timer);
    timer = setTimeout(() => {
      try {
        const page = grab();
        lastImage = page.image ? page.image.src : "";
        browser.runtime.sendMessage(page);
      } catch (e) {}
    }, 500);
  }

  // Tapping into an image viewer, swiping a gallery or scrolling to a photo changes what is on
  // screen without a page load: resend only when the photo in view actually changed.
  let watch = null;
  function watchImage() {
    clearTimeout(watch);
    watch = setTimeout(() => {
      let src = "";
      try { const img = primaryImage(); src = img ? img.src : ""; } catch (e) {}
      if (src !== lastImage) send();
    }, 900);
  }
  if (document.readyState === "complete") send(); else window.addEventListener("load", send);
  document.addEventListener("selectionchange", send);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) send(); });
  window.addEventListener("scroll", watchImage, { passive: true });
  document.addEventListener("click", watchImage, true);
  document.addEventListener("load", watchImage, true);   // images finishing loading (capture phase)

  // --- Fold detection -------------------------------------------------------------------
  // The fold is any of: the viewport collapsing by more than 30 % from the largest size this
  // page has had, the physical screen size changing from the largest seen, the Device Posture
  // API reporting "folded", or an orientation flip while the page is visible.
  let maxArea = 0, maxScreen = 0, folded = false, lastFuseAt = 0, busy = false;
  let orientation = null;
  function area() { return (window.innerWidth || 0) * (window.innerHeight || 0); }
  function screenArea() { return ((screen && screen.width) || 0) * ((screen && screen.height) || 0); }
  function orient() { return (window.innerWidth || 0) >= (window.innerHeight || 0) ? "l" : "p"; }
  function postureFolded() {
    try { return !!(window.matchMedia && window.matchMedia("(device-posture: folded)").matches); } catch (e) { return false; }
  }
  function check(reason) {
    const a = area(), s = screenArea(), o = orient();
    if (orientation === null) orientation = o;
    const collapsed = maxArea > 0 && a < maxArea * 0.7;
    const screenChanged = maxScreen > 0 && s > 0 && s !== maxScreen;
    const flipped = reason === "resize" && o !== orientation && document.visibilityState === "visible";
    const posture = postureFolded();
    if (a > maxArea) maxArea = a;
    if (s > maxScreen) maxScreen = s;
    orientation = o;
    const isFold = collapsed || screenChanged || posture || flipped;
    if (isFold && !folded) { folded = true; onFold(); }
    else if (!isFold && folded) { folded = false; }
  }
  window.addEventListener("resize", () => setTimeout(() => check("resize"), 120));
  window.addEventListener("orientationchange", () => setTimeout(() => check("orientation"), 200));
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "visible") setTimeout(() => check("visible"), 150); });
  if (window.matchMedia) {
    try {
      const mq = window.matchMedia("(device-posture: folded)");
      if (mq && typeof mq.addEventListener === "function") mq.addEventListener("change", (e) => { if (e.matches) check("posture"); });
    } catch (e) {}
  }
  setTimeout(() => check("load"), 800);

  async function onFold() {
    const now = Date.now();
    if (busy || now - lastFuseAt < 15000) return;
    busy = true; lastFuseAt = now;
    showSheet({ state: "working", pages: [{ title: document.title || location.hostname }] });
    try {
      try { await browser.runtime.sendMessage(grab()); } catch (e) {}
      try {
        const s = await browser.runtime.sendMessage({ kind: "status" });
        if (s && s.pages && s.pages.length) showSheet({ state: "working", pages: s.pages, photos: !!s.photos });
      } catch (e) {}
      const r = await browser.runtime.sendMessage({ kind: "fold", url: location.href, title: document.title });
      if (r && r.ok) showSheet({ state: "result", result: r });
      else showSheet({ state: "error", message: (r && r.error) || "Try again." });
    } catch (e) {
      showSheet({ state: "error", message: String(e && e.message || e) });
    } finally { busy = false; }
  }

  async function refuse(instruction) {
    if (busy) return;
    busy = true;
    showSheet({ state: "working", pages: [], instruction: instruction });
    try {
      const r = await browser.runtime.sendMessage({ kind: "fuse", instruction: instruction });
      if (r && r.ok) showSheet({ state: "result", result: r });
      else showSheet({ state: "error", message: (r && r.error) || "Try again." });
    } catch (e) {
      showSheet({ state: "error", message: String(e && e.message || e) });
    } finally { busy = false; }
  }

  // --- The sheet ---------------------------------------------------------------------------
  let sheet = null, body = null, head = null;
  const SHEET_CSS = `
#fuse-sheet{position:fixed;left:8px;right:8px;bottom:max(8px, env(safe-area-inset-bottom));z-index:2147483647;max-height:62vh;display:flex;flex-direction:column;
  background:rgba(249,249,249,0.97);color:rgba(0,0,0,0.9);border-radius:22px;
  box-shadow:0 12px 40px rgba(0,0,0,0.22),0 0 0 0.5px rgba(0,0,0,0.08);
  font-family:-apple-system,system-ui,"SF Pro Text",sans-serif;font-size:15px;line-height:1.35;
  -webkit-backdrop-filter:saturate(180%) blur(24px);backdrop-filter:saturate(180%) blur(24px);
  transform:translateY(calc(100% + 24px));transition:transform 0.55s cubic-bezier(0.32,0.72,0,1);
  -webkit-font-smoothing:antialiased;text-align:left;letter-spacing:normal;text-transform:none}
@media (prefers-color-scheme: dark){#fuse-sheet{background:rgba(28,28,30,0.97);color:rgba(255,255,255,0.92);box-shadow:0 12px 40px rgba(0,0,0,0.5),0 0 0 0.5px rgba(255,255,255,0.12)}}
#fuse-sheet.in{transform:translateY(0)}
#fuse-sheet *{box-sizing:border-box;margin:0;padding:0;font-family:inherit;color:inherit;line-height:inherit;text-align:left;letter-spacing:normal;text-transform:none;font-size:inherit}
#fuse-sheet .fs-grab{width:36px;height:5px;border-radius:3px;background:rgba(120,120,128,0.4);margin:8px auto 0;flex:0 0 auto}
#fuse-sheet .fs-head{display:flex;align-items:center;gap:10px;padding:10px 16px 8px;flex:0 0 auto}
#fuse-sheet .fs-logo{width:22px;height:22px;flex:0 0 auto;color:#0a7aff}
#fuse-sheet .fs-name{font-size:17px;font-weight:600;letter-spacing:-0.2px;flex:1;min-width:0;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#fuse-sheet .fs-spin{width:16px;height:16px;border-radius:50%;border:2px solid rgba(120,120,128,0.3);border-top-color:rgba(120,120,128,0.9);animation:fuse-spin 0.8s linear infinite;flex:0 0 auto}
@keyframes fuse-spin{to{transform:rotate(360deg)}}
#fuse-sheet .fs-close{width:28px;height:28px;border-radius:14px;background:rgba(120,120,128,0.16);position:relative;flex:0 0 auto;cursor:pointer}
#fuse-sheet .fs-close::before,#fuse-sheet .fs-close::after{content:"";position:absolute;left:13px;top:7px;width:2px;height:14px;border-radius:1px;background:currentColor;opacity:0.7;transform:rotate(45deg)}
#fuse-sheet .fs-close::after{transform:rotate(-45deg)}
#fuse-sheet .fs-body{overflow-y:auto;-webkit-overflow-scrolling:touch;padding:0 0 16px;flex:1 1 auto;min-height:0}
#fuse-sheet .fs-pages{background:var(--fr-fill);border-radius:14px;margin:4px 16px 12px;padding:0 0 0 14px;overflow:hidden}
#fuse-sheet .fs-page{display:flex;align-items:center;gap:10px;min-height:44px;padding-right:14px}
#fuse-sheet .fs-page + .fs-page{border-top:0.5px solid var(--fr-sep)}
#fuse-sheet .fs-dot{width:8px;height:8px;border-radius:4px;background:#0a7aff;flex:0 0 auto}
#fuse-sheet .fs-thumb{width:32px;height:32px;border-radius:7px;object-fit:cover;flex:0 0 auto;background:var(--fr-fill)}
#fuse-sheet .fs-page-t{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;min-width:0;font-size:15px}
#fuse-sheet .fs-hint{font-size:13px;color:var(--fr-secondary);margin:0 16px 4px}
#fuse-sheet .fs-err{font-size:15px;color:#ff3b30;margin:4px 16px 8px}
`;

  function ensureSheet() {
    if (sheet) return;
    sheet = document.createElement("div");
    sheet.id = "fuse-sheet";
    const style = document.createElement("style");
    style.textContent = SHEET_CSS + (R ? R.css("#fuse-sheet") : "");
    sheet.appendChild(style);
    const grab = document.createElement("div"); grab.className = "fs-grab"; sheet.appendChild(grab);
    head = document.createElement("div"); head.className = "fs-head";
    head.innerHTML =
      '<div class="fs-logo"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2"><circle cx="9" cy="12" r="6.5"/><circle cx="15" cy="12" r="6.5"/></svg></div>' +
      '<div class="fs-name"></div><div class="fs-spin" style="display:none"></div><div class="fs-close" role="button" aria-label="Close"></div>';
    sheet.appendChild(head);
    body = document.createElement("div"); body.className = "fs-body"; sheet.appendChild(body);
    document.documentElement.appendChild(sheet);
    head.querySelector(".fs-close").addEventListener("click", () => sheet.classList.remove("in"));
    requestAnimationFrame(() => requestAnimationFrame(() => sheet.classList.add("in")));
  }

  function showSheet(s) {
    ensureSheet();
    sheet.classList.add("in");
    const name = head.querySelector(".fs-name"), spin = head.querySelector(".fs-spin");
    body.textContent = "";
    if (s.state === "working") {
      name.textContent = "Fusing";
      spin.style.display = "block";
      const pages = (s.pages || []).slice(0, 2);
      if (pages.length) {
        const list = document.createElement("div"); list.className = "fs-pages";
        for (const p of pages) {
          const row = document.createElement("div"); row.className = "fs-page";
          let mark;
          if (p.thumb) { mark = document.createElement("img"); mark.className = "fs-thumb"; mark.alt = ""; mark.src = p.thumb; }
          else { mark = document.createElement("span"); mark.className = "fs-dot"; }
          const t = document.createElement("span"); t.className = "fs-page-t"; t.textContent = p.title || p.url || "";
          row.appendChild(mark); row.appendChild(t); list.appendChild(row);
        }
        body.appendChild(list);
      }
      const hint = document.createElement("div"); hint.className = "fs-hint";
      hint.textContent = s.instruction ? s.instruction
        : (s.photos ? "Fusing these two photos into one. This takes about a minute." : "Folding these two pages into one");
      body.appendChild(hint);
    } else if (s.state === "result" && R) {
      name.textContent = "Fuse";
      spin.style.display = "none";
      body.appendChild(R.render(s.result, { onFollowUp: (text) => refuse(text) }));
    } else {
      name.textContent = "Couldn't fuse";
      spin.style.display = "none";
      const err = document.createElement("div"); err.className = "fs-err";
      err.textContent = s.message || (s.result && s.result.summary) || "Try again.";
      body.appendChild(err);
    }
    body.scrollTop = 0;
  }

  // The popup asks the page for its content when the user taps a half.
  browser.runtime.onMessage.addListener((m, s, respond) => { if (m && m.kind === "grab") { respond(grab()); return true; } });
})();
