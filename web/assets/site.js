const $ = id => document.getElementById(id);

document.querySelectorAll(".copy").forEach(b => b.addEventListener("click", async () => {
  const text = document.querySelector(b.dataset.copy).textContent.trim();
  try { await navigator.clipboard.writeText(text); b.textContent = "copied"; } catch { b.textContent = "select it"; }
  setTimeout(() => (b.textContent = "copy"), 1600);
}));

fetch("/iso/latest.json", { cache: "no-cache" }).then(r => r.ok ? r.json() : null).then(d => {
  if (!d) return;
  const url = "/iso/" + d.file;
  $("dl-top").href = url;
  $("dl-sum").textContent = d.sha256;
  $("dl-meta").textContent = `x86_64 · ${(d.size / 1e9).toFixed(1)} GB · ${d.date}`;
}).catch(() => {});
