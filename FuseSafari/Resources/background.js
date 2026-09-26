// Relay page visits and "put on a half" requests to the native handler.
browser.runtime.onMessage.addListener((message, sender, sendResponse) => {
  const payload = Object.assign({ kind: "visit" }, message);
  if (!payload.url && sender && sender.tab && sender.tab.url) payload.url = sender.tab.url;
  browser.runtime.sendNativeMessage("application.id", payload).then((reply) => {
    sendResponse(reply || { ok: true });
  }).catch(() => sendResponse({ ok: false }));
  return true;
});
