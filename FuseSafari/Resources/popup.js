async function activeTab() {
  const tabs = await browser.tabs.query({ active: true, currentWindow: true });
  return tabs[0];
}
async function stage(side) {
  const tab = await activeTab();
  let page = { url: tab.url, title: tab.title, text: "", selection: "" };
  try { const got = await browser.tabs.sendMessage(tab.id, { kind: "grab" }); if (got) page = got; } catch (e) {}
  await browser.runtime.sendMessage(Object.assign({}, page, { kind: "stage", side: side }));
  const b = document.getElementById(side); b.textContent = "Done"; b.className = "done";
  setTimeout(() => window.close(), 500);
}
activeTab().then(t => { document.getElementById("title").textContent = t.title || t.url; });
document.getElementById("left").addEventListener("click", () => stage("left"));
document.getElementById("right").addEventListener("click", () => stage("right"));
