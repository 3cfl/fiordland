(() => {
const $ = id => document.getElementById(id);
const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;

document.querySelectorAll(".copy").forEach(b => b.addEventListener("click", async () => {
  const text = document.querySelector(b.dataset.copy).textContent.trim();
  try { await navigator.clipboard.writeText(text); b.textContent = "Copied"; } catch { b.textContent = "Select it"; }
  setTimeout(() => (b.textContent = "Copy"), 1600);
}));

fetch("/iso/latest.json", { cache: "no-cache" }).then(r => r.ok ? r.json() : null).then(d => {
  if (!d) return;
  document.querySelectorAll("[data-iso]").forEach(a => (a.href = "/iso/" + d.file));
  if ($("dl-sum")) $("dl-sum").textContent = d.sha256;
  if ($("dl-meta")) $("dl-meta").textContent = `x86_64 · ${(d.size / 1e9).toFixed(1)} GB · ${d.date.replaceAll("-", ".")}`;
  if ($("dl-ver")) $("dl-ver").textContent = d.date.replaceAll("-", ".");
}).catch(() => {});

document.querySelectorAll("[data-blur]").forEach(el => {
  const words = el.textContent.trim().split(/\s+/);
  el.textContent = "";
  words.forEach((w, i) => {
    const s = document.createElement("span");
    s.className = "w";
    s.textContent = w;
    s.style.setProperty("--i", i);
    el.append(s, i < words.length - 1 ? " " : "");
  });
});

const seen = new IntersectionObserver(es => es.forEach(e => {
  if (e.isIntersecting) { e.target.classList.add("in"); seen.unobserve(e.target); }
}), { rootMargin: "0px 0px -12% 0px" });
document.querySelectorAll("[data-blur], .rise").forEach(el => (reduce ? el.classList.add("in") : seen.observe(el)));

const cards = [...document.querySelectorAll(".card")];
if (cards.length && matchMedia("(hover: hover)").matches) {
  let raf = 0, px = -1e4, py = -1e4;
  const paint = () => {
    raf = 0;
    for (const c of cards) {
      const r = c.getBoundingClientRect();
      const x = px - r.left, y = py - r.top;
      const dx = Math.max(r.left - px, 0, px - r.right);
      const dy = Math.max(r.top - py, 0, py - r.bottom);
      const near = Math.max(0, 1 - Math.hypot(dx, dy) / 220);
      c.style.setProperty("--x", x + "px");
      c.style.setProperty("--y", y + "px");
      c.style.setProperty("--near", near.toFixed(3));
      c.style.setProperty("--hot", dx === 0 && dy === 0 ? 1 : 0);
    }
  };
  addEventListener("pointermove", e => {
    px = e.clientX; py = e.clientY;
    if (!raf) raf = requestAnimationFrame(paint);
  }, { passive: true });
  document.documentElement.addEventListener("pointerleave", () => {
    px = py = -1e4;
    if (!raf) raf = requestAnimationFrame(paint);
  });
}

document.querySelectorAll(".tabs").forEach(tabs => {
  const btns = [...tabs.querySelectorAll("[role=tab]")];
  const pill = tabs.querySelector(".pill");
  const panels = btns.map(b => $(b.getAttribute("aria-controls")));
  const place = b => {
    pill.style.setProperty("--l", b.offsetLeft + "px");
    pill.style.setProperty("--w", b.offsetWidth + "px");
  };
  const pick = (b, focus) => {
    btns.forEach((x, i) => {
      const on = x === b;
      x.setAttribute("aria-selected", on);
      x.tabIndex = on ? 0 : -1;
      panels[i].hidden = !on;
    });
    place(b);
    if (focus) b.focus();
  };
  btns.forEach((b, i) => {
    b.addEventListener("click", () => pick(b));
    b.addEventListener("keydown", e => {
      const d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (d) pick(btns[(i + d + btns.length) % btns.length], true);
    });
  });
  const cur = btns.find(b => b.getAttribute("aria-selected") === "true") || btns[0];
  requestAnimationFrame(() => { place(cur); tabs.classList.add("ready"); });
  new ResizeObserver(() => place(btns.find(b => b.getAttribute("aria-selected") === "true"))).observe(tabs);
});
})();
