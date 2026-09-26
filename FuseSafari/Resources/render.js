// Shared renderer for fused results. Used by the popup and by the in-page sheet (content.js).
// Everything the model produced is inserted with textContent; never raw innerHTML.
(function (global) {
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function el(tag, cls, text) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (text != null && text !== "") n.textContent = String(text);
    return n;
  }
  function add(parent, tag, cls, text) { const n = el(tag, cls, text); parent.appendChild(n); return n; }
  function str(v) { return v == null ? "" : (typeof v === "string" ? v : (typeof v === "object" ? JSON.stringify(v) : String(v))); }
  function arr(v) { return Array.isArray(v) ? v : (v == null ? [] : [v]); }

  // --- CSS ------------------------------------------------------------------------------
  // `scope` is a selector prefix (e.g. "#fuse-sheet") so the sheet's styles never leak into the page.
  function css(scope) {
    const S = scope ? scope + " " : "";
    const R = scope || ":root";
    return `
${R}{--fr-label:rgba(0,0,0,0.9);--fr-secondary:rgba(60,60,67,0.6);--fr-fill:rgba(120,120,128,0.12);--fr-fill2:rgba(120,120,128,0.2);--fr-sep:rgba(60,60,67,0.29);--fr-accent:#0a7aff;--fr-red:#ff3b30;--fr-green:#34c759;--fr-red-bg:rgba(255,59,48,0.10);--fr-green-bg:rgba(52,199,89,0.12);}
@media (prefers-color-scheme: dark){${R}{--fr-label:rgba(255,255,255,0.92);--fr-secondary:rgba(235,235,245,0.6);--fr-fill:rgba(120,120,128,0.18);--fr-fill2:rgba(120,120,128,0.28);--fr-sep:rgba(84,84,88,0.65);--fr-red-bg:rgba(255,69,58,0.16);--fr-green-bg:rgba(48,209,88,0.16);}}
${S}.fr{font-family:-apple-system,system-ui,"SF Pro Text",sans-serif;color:var(--fr-label);font-size:15px;line-height:1.35;-webkit-font-smoothing:antialiased}
${S}.fr *{box-sizing:border-box;margin:0;padding:0;font-family:inherit;color:inherit;line-height:inherit;text-align:left}
${S}.fr-title{font-size:17px;font-weight:600;letter-spacing:-0.2px;margin:0 16px 4px}
${S}.fr-summary{font-size:15px;font-weight:400;color:var(--fr-secondary);margin:0 16px 12px}
${S}.fr-section{font-size:13px;font-weight:600;color:var(--fr-secondary);text-transform:uppercase;letter-spacing:0.3px;margin:14px 16px 6px}
${S}.fr-card{background:var(--fr-fill);border-radius:14px;margin:0 16px 12px;padding:11px 14px}
${S}.fr-card-head{font-size:15px;font-weight:600;letter-spacing:-0.2px;margin-bottom:6px}
${S}.fr-list{background:var(--fr-fill);border-radius:14px;margin:0 16px 12px;padding:0 0 0 14px;overflow:hidden}
${S}.fr-row{display:flex;align-items:flex-start;gap:12px;padding:10px 14px 10px 0;min-height:44px}
${S}.fr-row + .fr-row{border-top:0.5px solid var(--fr-sep)}
${S}.fr-row-body{flex:1;min-width:0}
${S}.fr-label{font-size:13px;color:var(--fr-secondary);margin-bottom:1px}
${S}.fr-value{font-size:15px;white-space:pre-wrap;word-break:break-word}
${S}.fr-name{font-size:15px;font-weight:600;letter-spacing:-0.2px}
${S}.fr-note{font-size:13px;color:var(--fr-secondary);margin-top:2px;white-space:pre-wrap}
${S}.fr-kv{display:flex;flex-direction:column;gap:1px;margin-top:8px}
${S}.fr-kv:first-of-type{margin-top:0}
${S}.fr-time{font-size:13px;color:var(--fr-secondary);font-variant-numeric:tabular-nums;flex:0 0 58px;padding-top:2px}
${S}.fr-circle{width:20px;height:20px;border-radius:50%;border:1.5px solid var(--fr-secondary);flex:0 0 auto;margin-top:1px}
${S}.fr-check{width:20px;height:20px;border-radius:50%;background:var(--fr-green);flex:0 0 auto;position:relative;margin-top:1px}
${S}.fr-check::after{content:"";position:absolute;left:7px;top:3.5px;width:4px;height:9px;border:solid #fff;border-width:0 2px 2px 0;transform:rotate(45deg)}
${S}.fr-cross{width:20px;height:20px;border-radius:50%;background:var(--fr-red);flex:0 0 auto;position:relative;margin-top:1px}
${S}.fr-cross::before,${S}.fr-cross::after{content:"";position:absolute;left:9px;top:5px;width:2px;height:10px;background:#fff;border-radius:1px;transform:rotate(45deg)}
${S}.fr-cross::after{transform:rotate(-45deg)}
${S}.fr-letter{width:24px;height:24px;border-radius:12px;background:var(--fr-fill2);font-size:13px;font-weight:600;display:flex;align-items:center;justify-content:center;flex:0 0 auto}
${S}.fr-letter.on{background:var(--fr-green);color:#fff}
${S}.fr-chev{width:8px;height:8px;border-right:1.5px solid var(--fr-secondary);border-top:1.5px solid var(--fr-secondary);transform:rotate(45deg);flex:0 0 auto;margin:6px 4px 0 0}
${S}.fr-num{width:26px;height:26px;border-radius:8px;background:var(--fr-fill2);font-size:13px;font-weight:600;display:flex;align-items:center;justify-content:center;flex:0 0 auto}
${S}.fr-tile{width:52px;flex:0 0 auto;border-radius:12px;background:var(--fr-fill2);text-align:center;padding:6px 0 5px}
${S}.fr-tile .m{font-size:11px;font-weight:600;color:var(--fr-red);text-transform:uppercase;letter-spacing:0.4px;text-align:center}
${S}.fr-tile .d{font-size:22px;font-weight:600;letter-spacing:-0.4px;line-height:1.1;text-align:center}
${S}.fr-pre{white-space:pre-wrap;font-size:15px;word-break:break-word}
${S}.fr-code{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:12.5px;line-height:1.45;white-space:pre;overflow-x:auto;-webkit-overflow-scrolling:touch}
${S}.fr-card.red{background:var(--fr-red-bg)}
${S}.fr-card.green{background:var(--fr-green-bg)}
${S}.fr-strike{text-decoration:line-through;color:var(--fr-red);white-space:pre-wrap}
${S}.fr-score{font-size:28px;font-weight:600;letter-spacing:-0.5px;line-height:1}
${S}.fr-pills{display:flex;flex-wrap:wrap;gap:6px;margin:0 16px 12px}
${S}.fr-pill{font-size:13px;padding:5px 10px;border-radius:999px;background:var(--fr-fill)}
${S}.fr-ul{padding-left:18px;margin:2px 0 6px}
${S}.fr-ul li{margin:2px 0}
${S}.fr-md h3{font-size:15px;font-weight:600;letter-spacing:-0.2px;margin:8px 0 4px}
${S}.fr-md h4{font-size:15px;font-weight:600;margin:6px 0 2px}
${S}.fr-md p{margin:0 0 8px;white-space:pre-wrap}
${S}.fr-md ul,${S}.fr-md ol{padding-left:20px;margin:0 0 8px}
${S}.fr-md li{margin:2px 0}
${S}.fr-md code{font-family:ui-monospace,"SF Mono",Menlo,monospace;font-size:13px;background:var(--fr-fill2);padding:1px 4px;border-radius:4px}
${S}.fr-next .fr-row{align-items:center;cursor:pointer}
${S}.fr-next .fr-row:active{background:var(--fr-fill2)}
${S}.fr-next .fr-row-body{font-size:15px}
`;
  }

  // --- Typed renderers ------------------------------------------------------------------
  function renderTable(a, out) {
    if (a.title) add(out, "div", "fr-section", a.title);
    const cols = arr(a.columns).map(str);
    arr(a.rows).forEach((row) => {
      const cells = arr(row).map(str);
      const card = add(out, "div", "fr-card");
      add(card, "div", "fr-card-head", cells[0] || "");
      for (let i = 1; i < Math.max(cells.length, cols.length); i++) {
        if (!cells[i]) continue;
        const kv = add(card, "div", "fr-kv");
        add(kv, "div", "fr-label", cols[i] || "");
        add(kv, "div", "fr-value", cells[i]);
      }
    });
    if (a.note) add(out, "div", "fr-note", a.note).style.margin = "0 16px 12px";
  }

  function renderChecklist(a, out) {
    if (a.title) add(out, "div", "fr-section", a.title);
    const list = add(out, "div", "fr-list");
    arr(a.items).forEach((it) => {
      const item = typeof it === "string" ? { text: it } : (it || {});
      const row = add(list, "div", "fr-row");
      add(row, "span", "fr-circle");
      const b = add(row, "div", "fr-row-body");
      add(b, "div", "fr-value", str(item.text || item.title));
      if (item.detail) add(b, "div", "fr-note", item.detail);
    });
  }

  function renderItinerary(a, out) {
    if (a.destination) add(out, "div", "fr-section", a.destination);
    arr(a.days).forEach((day, i) => {
      add(out, "div", "fr-section", day.title || ("Day " + (i + 1)));
      const list = add(out, "div", "fr-list");
      arr(day.stops).forEach((s) => {
        const row = add(list, "div", "fr-row");
        add(row, "div", "fr-time", s.time || "");
        const b = add(row, "div", "fr-row-body");
        add(b, "div", "fr-name", s.name || "");
        if (s.note) add(b, "div", "fr-note", s.note);
      });
    });
    const tips = arr(a.tips);
    if (tips.length) {
      add(out, "div", "fr-section", "Tips");
      const list = add(out, "div", "fr-list");
      tips.forEach((t) => { const row = add(list, "div", "fr-row"); add(row, "div", "fr-row-body fr-value", str(t)); });
    }
  }

  function fmtDate(s) {
    const d = new Date(str(s));
    if (isNaN(d.getTime())) return null;
    return d;
  }
  function renderEvent(a, out) {
    const card = add(out, "div", "fr-card");
    card.style.display = "flex"; card.style.gap = "12px"; card.style.alignItems = "flex-start";
    const tile = add(card, "div", "fr-tile");
    const start = fmtDate(a.start), end = fmtDate(a.end);
    if (start) {
      add(tile, "div", "m", start.toLocaleDateString([], { month: "short" }));
      add(tile, "div", "d", String(start.getDate()));
    } else {
      add(tile, "div", "m", "Date");
      add(tile, "div", "d", "?");
    }
    const b = add(card, "div", "fr-row-body");
    add(b, "div", "fr-name", a.title || "Event");
    let when = "";
    if (a.all_day) when = start ? start.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" }) + ", all day" : "All day";
    else if (start) {
      when = start.toLocaleDateString([], { weekday: "short", month: "short", day: "numeric" }) + ", " + start.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
      if (end) when += " to " + end.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
    } else when = str(a.start);
    add(b, "div", "fr-note", when);
    if (a.location) add(b, "div", "fr-note", a.location);
    if (a.notes) { const n = add(out, "div", "fr-card"); add(n, "div", "fr-pre", a.notes); }
  }

  function renderEmail(a, out) {
    const list = add(out, "div", "fr-list");
    const to = arr(a.to).map(str).join(", ");
    [["To", to], ["Subject", str(a.subject)]].forEach(([k, v]) => {
      if (!v) return;
      const row = add(list, "div", "fr-row");
      const b = add(row, "div", "fr-row-body");
      add(b, "div", "fr-label", k);
      add(b, "div", "fr-value", v);
    });
    const card = add(out, "div", "fr-card");
    add(card, "div", "fr-pre", str(a.body));
  }

  function renderQuiz(a, out) {
    if (a.title) add(out, "div", "fr-section", a.title);
    arr(a.questions).forEach((q, qi) => {
      const card = add(out, "div", "fr-card");
      add(card, "div", "fr-card-head", (qi + 1) + ". " + str(q.prompt || q.question));
      const ans = Number(q.answer_index);
      arr(q.choices || q.options).forEach((c, ci) => {
        const row = add(card, "div", "fr-row");
        row.style.minHeight = "0"; row.style.padding = "5px 0"; row.style.alignItems = "center";
        const on = ci === ans;
        add(row, "span", "fr-letter" + (on ? " on" : ""), String.fromCharCode(65 + ci));
        add(row, "div", "fr-row-body fr-value", str(c));
        if (on) add(row, "span", "fr-check");
      });
      if (q.explanation) add(card, "div", "fr-note", q.explanation);
    });
  }

  function renderSlides(a, out) {
    if (a.title) add(out, "div", "fr-section", a.title);
    arr(a.slides).forEach((s, i) => {
      const card = add(out, "div", "fr-card");
      const head = add(card, "div", "fr-row");
      head.style.minHeight = "0"; head.style.padding = "0 0 6px"; head.style.alignItems = "center";
      add(head, "span", "fr-num", String(i + 1));
      add(head, "div", "fr-row-body fr-name", s.title || "");
      const bullets = arr(s.bullets || s.points);
      if (bullets.length) { const ul = add(card, "ul", "fr-ul"); bullets.forEach((b) => add(ul, "li", "fr-value", str(b))); }
      if (s.notes) add(card, "div", "fr-note", s.notes);
    });
  }

  function renderCode(a, out) {
    const meta = [a.filename, a.language].filter(Boolean).map(str).join("  ");
    if (meta) add(out, "div", "fr-section", meta);
    const card = add(out, "div", "fr-card");
    add(card, "pre", "fr-code", str(a.code));
    if (a.explanation) { const n = add(out, "div", "fr-card"); add(n, "div", "fr-pre", a.explanation); }
  }

  function renderDiff(a, out) {
    if (a.title) add(out, "div", "fr-section", a.title);
    arr(a.changes).forEach((c) => {
      const o = add(out, "div", "fr-card red"); o.style.marginBottom = "6px";
      add(o, "div", "fr-strike", str(c.original));
      const r = add(out, "div", "fr-card green"); r.style.marginBottom = c.reason ? "4px" : "12px";
      add(r, "div", "fr-pre", str(c.revised));
      if (c.reason) add(out, "div", "fr-note", c.reason).style.margin = "0 16px 12px";
    });
    if (a.verdict) { add(out, "div", "fr-section", "Verdict"); const v = add(out, "div", "fr-card"); add(v, "div", "fr-pre", str(a.verdict)); }
  }

  function renderGrade(a, out) {
    const top = add(out, "div", "fr-card");
    top.style.display = "flex"; top.style.alignItems = "baseline"; top.style.gap = "10px";
    const score = a.score;
    add(top, "div", "fr-score", score == null ? "?" : (typeof score === "number" && score <= 1 && score > 0 ? Math.round(score * 100) + "%" : str(score)));
    add(top, "div", "fr-label", "Score");
    const items = arr(a.items);
    if (items.length) {
      const list = add(out, "div", "fr-list");
      items.forEach((it) => {
        const row = add(list, "div", "fr-row");
        add(row, "span", it.correct ? "fr-check" : "fr-cross");
        const b = add(row, "div", "fr-row-body");
        add(b, "div", "fr-value", str(it.question));
        if (it.your_answer) add(b, "div", "fr-note", "You said: " + str(it.your_answer));
        if (it.feedback) add(b, "div", "fr-note", it.feedback);
      });
    }
    const weak = arr(a.weaknesses).map(str).filter(Boolean);
    if (weak.length) { add(out, "div", "fr-section", "Weak spots"); const p = add(out, "div", "fr-pills"); weak.forEach((w) => add(p, "span", "fr-pill", w)); }
    const next = arr(a.next_steps).map(str).filter(Boolean);
    if (next.length) {
      add(out, "div", "fr-section", "Next steps");
      const list = add(out, "div", "fr-list");
      next.forEach((n) => { const row = add(list, "div", "fr-row"); add(row, "span", "fr-circle"); add(row, "div", "fr-row-body fr-value", n); });
    }
  }

  // Minimal markdown: escape first, then only our own tags are introduced.
  function inline(s) {
    return esc(s)
      .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
      .replace(/`([^`]+)`/g, "<code>$1</code>");
  }
  function markdownHTML(md) {
    const lines = str(md).replace(/\r/g, "").split("\n");
    let html = "", list = null, para = [];
    const flushPara = () => { if (para.length) { html += "<p>" + para.map(inline).join("\n") + "</p>"; para = []; } };
    const closeList = () => { if (list) { html += "</" + list + ">"; list = null; } };
    for (const raw of lines) {
      const line = raw.trimEnd();
      let m;
      if ((m = /^(#{1,6})\s+(.*)$/.exec(line))) { flushPara(); closeList(); html += (m[1].length <= 2 ? "<h3>" : "<h4>") + inline(m[2]) + (m[1].length <= 2 ? "</h3>" : "</h4>"); }
      else if ((m = /^\s*[-*]\s+(.*)$/.exec(line))) { flushPara(); if (list !== "ul") { closeList(); list = "ul"; html += "<ul>"; } html += "<li>" + inline(m[1]) + "</li>"; }
      else if ((m = /^\s*\d+[.)]\s+(.*)$/.exec(line))) { flushPara(); if (list !== "ol") { closeList(); list = "ol"; html += "<ol>"; } html += "<li>" + inline(m[1]) + "</li>"; }
      else if (line.trim() === "") { flushPara(); closeList(); }
      else { closeList(); para.push(line); }
    }
    flushPara(); closeList();
    return html;
  }
  function renderMarkdown(md, out) {
    const card = add(out, "div", "fr-card");
    const box = add(card, "div", "fr-md");
    box.innerHTML = markdownHTML(md);
  }

  function renderBody(r, out) {
    const a = r.artifact || {};
    const type = r.type || a.type || "markdown";
    try {
      switch (type) {
        case "table": return renderTable(a, out);
        case "checklist": return renderChecklist(a, out);
        case "itinerary": return renderItinerary(a, out);
        case "event": return renderEvent(a, out);
        case "email": return renderEmail(a, out);
        case "quiz": return renderQuiz(a, out);
        case "slides": return renderSlides(a, out);
        case "code": return renderCode(a, out);
        case "diff": return renderDiff(a, out);
        case "grade": return renderGrade(a, out);
        case "markdown": if (a.markdown) return renderMarkdown(a.markdown, out); break;
      }
    } catch (e) { /* fall through to plain text */ }
    if (r.text) renderMarkdown(r.text, out);
  }

  // Builds the whole result view. opts.onFollowUp(text) is called when a "Next" row is tapped.
  function render(r, opts) {
    opts = opts || {};
    const root = el("div", "fr");
    add(root, "div", "fr-title", r.title || "Fused");
    if (r.summary) add(root, "div", "fr-summary", r.summary);
    renderBody(r, root);
    const follow = arr(r.followUps).map(str).filter(Boolean);
    if (follow.length && opts.onFollowUp) {
      add(root, "div", "fr-section", "Next");
      const list = add(root, "div", "fr-list fr-next");
      follow.forEach((f) => {
        const row = add(list, "div", "fr-row");
        add(row, "div", "fr-row-body", f);
        add(row, "span", "fr-chev");
        row.addEventListener("click", () => opts.onFollowUp(f));
      });
    }
    return root;
  }

  function plainText(r) {
    return [r.title, r.summary, r.text].filter(Boolean).join("\n\n");
  }

  global.FuseRender = { css, render, esc, plainText };
})(typeof window !== "undefined" ? window : this);
