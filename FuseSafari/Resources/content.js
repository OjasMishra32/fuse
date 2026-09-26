// Fuse follows you: every page you read is remembered (URL, title, visible text, selection).
(function () {
  function grab() {
    const text = (document.body && document.body.innerText || "").replace(/\s+\n/g, "\n").replace(/[ \t]+/g, " ").trim().slice(0, 6000);
    const selection = (window.getSelection && window.getSelection().toString() || "").trim().slice(0, 2000);
    return { kind: "visit", url: location.href, title: document.title || location.hostname, text: text, selection: selection };
  }
  let timer = null;
  function send() {
    clearTimeout(timer);
    timer = setTimeout(() => { try { browser.runtime.sendMessage(grab()); } catch (e) {} }, 600);
  }
  if (document.readyState === "complete") send(); else window.addEventListener("load", send);
  document.addEventListener("selectionchange", send);
  document.addEventListener("visibilitychange", () => { if (!document.hidden) send(); });
  // The popup asks the page for its content when the user taps a half.
  browser.runtime.onMessage.addListener((m, s, respond) => { if (m && m.kind === "grab") { respond(grab()); return true; } });
})();
