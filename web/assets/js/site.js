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
  const ver = ((d.file.match(/^fiordland-(.+)-x86_64\.iso$/) || [])[1]) || d.date.replaceAll("-", ".");
  document.querySelectorAll("[data-iso]").forEach(a => (a.href = "/iso/" + d.file));
  if ($("dl-sum")) $("dl-sum").textContent = d.sha256;
  if ($("dl-meta")) $("dl-meta").textContent = `x86_64 · ${(d.size / 1e9).toFixed(1)} GB · ${ver}`;
  if ($("dl-ver")) $("dl-ver").textContent = ver;
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
const mlist = $("mirror-list");
if (mlist) {
  const CONT = {
    NA: "US CA MX GT BZ SV HN NI CR PA CU JM HT DO BS BB TT GL PR BM KY AG DM GD KN LC VC",
    SA: "BR AR CL CO PE VE EC BO PY UY GY SR",
    EU: "GB IE FR DE ES PT IT NL BE LU CH AT DK NO SE FI IS PL CZ SK HU RO BG GR HR SI RS BA ME MK AL UA BY MD LT LV EE RU CY MT AD MC LI SM",
    AS: "CN JP KR KP IN PK BD LK NP BT MM TH VN LA KH MY SG ID PH TW HK MO MN KZ UZ TM KG TJ AF IR IQ SY LB IL JO SA AE QA KW BH OM YE TR GE AM AZ BN",
    AF: "EG ZA NG KE ET GH TZ UG DZ MA TN LY SD SN CI CM AO MZ ZM ZW BW NA MG RW",
    OC: "AU NZ FJ PG NC PF WS TO"
  };
  const continentOf = code => Object.keys(CONT).find(k => CONT[k].split(" ").includes(code)) || "";
  const load = u => fetch(u, { cache: "no-store" }).then(r => (r.ok ? r.json() : null)).catch(() => null);
  Promise.all([load("/mirrors/mirrors.json"), load("/mirrors/status.json"), load("/mirrors/whoami")]).then(([list, status, who]) => {
    mlist.textContent = "";
    const rows = list?.mirrors || [];
    if (!rows.length) { mlist.textContent = "No mirrors listed yet."; return; }
    const checks = status?.mirrors || {};
    const country = /^[A-Z]{2}$/.test(who?.country || "") ? who.country : "";
    const continent = continentOf(country);
    const rank = m => {
      const s = checks[m.url.replace(/\/$/, "")];
      const near = country && m.country === country ? 0 : continent && m.continent === continent ? 1 : 2;
      return [s?.ok ? 0 : 1, near, s?.ms || 0, m.primary ? 0 : 1];
    };
    const ordered = rows.map(m => ({ m, r: rank(m) })).sort((x, y) => { for (let i = 0; i < 4; i++) if (x.r[i] !== y.r[i]) return x.r[i] - y.r[i]; return 0; });
    ordered.forEach(({ m, r }, index) => {
      const url = m.url.replace(/\/$/, "");
      const s = checks[url];
      const row = document.createElement("div");
      row.className = "mrow" + (index === 0 && s?.ok && country ? " best" : "");
      const dot = document.createElement("span");
      dot.className = "dot " + (s ? (s.ok ? "ok" : "bad") : "idle");
      dot.setAttribute("role", "img");
      dot.setAttribute("aria-label", s ? (s.ok ? "Up" : "Down") : "Unknown");
      const info = document.createElement("div");
      info.className = "minfo";
      const name = document.createElement("strong");
      name.textContent = m.name + (m.primary ? " (primary)" : "");
      if (index === 0 && s?.ok && country) {
        const tag = document.createElement("em");
        tag.textContent = r[1] === 0 ? "Closest to you" : r[1] === 1 ? "Nearest region" : "Best available";
        name.append(tag);
      }
      const sub = document.createElement("span");
      const lag = s?.ok ? (s.lag < 60 ? "up to date" : `${Math.round(s.lag / 60)} min behind`) : s ? "down" : "not checked yet";
      sub.textContent = [m.location, m.sponsor && `hosted by ${m.sponsor}`, lag].filter(Boolean).join(" · ");
      info.append(name, sub);
      const links = document.createElement("div");
      links.className = "mlinks";
      for (const [label, path] of [["Repo", "/repo/x86_64/"], ["ISO", "/iso/fiordland-latest.iso"]]) {
        const a = document.createElement("a");
        a.href = url + path;
        a.textContent = label;
        links.append(a);
      }
      row.append(dot, info, links);
      mlist.append(row);
    });
    const where = $("mirror-where");
    if (where) where.textContent = country ? `Sorted by distance to ${country} (from your connection, nothing is stored).` : "Sorted by status.";
  });
}
})();
