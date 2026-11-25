.pragma library

const boundary = /[\s\-_.\/]/;

function score(query, text) {
    const q = String(query || "").toLowerCase().trim();
    const t = String(text || "").toLowerCase();
    if (!q)
        return 1;
    if (!t)
        return -1;
    const idx = t.indexOf(q);
    if (idx === 0)
        return 1000 - t.length;
    if (idx > 0)
        return (boundary.test(t[idx - 1]) ? 800 : 600) - idx - t.length * 0.1;
    let s = 0;
    let ti = 0;
    let prev = -2;
    let first = -1;
    for (const ch of q) {
        if (ch === " ")
            continue;
        const f = t.indexOf(ch, ti);
        if (f < 0)
            return -1;
        if (first < 0)
            first = f;
        s += 10;
        if (f === prev + 1)
            s += 15;
        if (f === 0 || boundary.test(t[f - 1]))
            s += 20;
        s -= Math.min(f - ti, 10);
        prev = f;
        ti = f + 1;
    }
    return Math.max(1, s - first);
}

function rank(items, query, fields, limit) {
    const q = String(query || "").trim();
    const out = [];
    for (const item of items) {
        let best = -1;
        for (const field of fields) {
            const values = [].concat(field[0](item) || []);
            for (const v of values) {
                const sc = score(q, v);
                if (sc > 0)
                    best = Math.max(best, sc * field[1]);
            }
        }
        if (best > 0)
            out.push({ item: item, score: best });
    }
    out.sort((a, b) => b.score - a.score);
    return out.slice(0, limit || out.length);
}
