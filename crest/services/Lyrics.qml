pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    property int users: 0
    readonly property bool active: users > 0 && Config.media.lyrics && Media.available
    readonly property string rawTitle: Media.title
    readonly property string rawArtist: Media.artist
    readonly property string album: Config.demo ? "" : (Media.player?.trackAlbum ?? "")
    readonly property real duration: Media.length
    readonly property var track: clean(rawTitle, rawArtist)
    readonly property string key: track.title ? `${track.artist}\u0001${track.title}` : ""
    property string loadedKey: ""
    property string status: "idle"
    property var lines: []
    property string plain: ""
    property bool synced: lines.length > 0
    property real position: 0
    property int current: -1
    property var cache: ({})
    property var order: []
    property var request: null

    function acquire(): void {
        users++;
    }

    function release(): void {
        users = Math.max(0, users - 1);
    }

    function clean(title: string, artist: string): var {
        let t = (title ?? "").trim();
        let a = (artist ?? "").replace(/\s*-\s*Topic$/i, "").replace(/VEVO$/i, "").trim();
        const noise = /\s*[\(\[][^\)\]]*(official|video|audio|lyric|visuali[sz]er|remaster|\bhd\b|\b4k\b|\bmv\b|explicit|clean|live at|music video)[^\)\]]*[\)\]]/gi;
        t = t.replace(noise, "").replace(/\s*\|.*$/, "").trim();
        const dash = t.match(/^(.+?)\s+[-–—]\s+(.+)$/);
        if (dash && (!a || Media.identity.toLowerCase().match(/chrom|firefox|brave|edge|vivaldi|browser/) || dash[1].toLowerCase().includes(a.toLowerCase()))) {
            a = dash[1].trim();
            t = dash[2].trim();
        }
        t = t.replace(/\s+(feat\.?|ft\.?)\s.*$/i, "").trim();
        a = a.split(/\s*(,|&|\bfeat\.?|\bft\.?|\bx\b)\s*/i)[0].trim();
        return { title: t, artist: a };
    }

    function parse(lrc: string): var {
        const out = [];
        for (const raw of (lrc ?? "").split("\n")) {
            const stamps = [];
            let rest = raw;
            let m;
            while ((m = rest.match(/^\s*\[(\d+):(\d+(?:\.\d+)?)\]/))) {
                stamps.push(Number(m[1]) * 60 + Number(m[2]));
                rest = rest.slice(m[0].length);
            }
            const text = rest.trim();
            for (const s of stamps)
                out.push({ time: s, text });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function store(k: string, entry: var): void {
        const c = cache;
        c[k] = entry;
        let o = order.filter(x => x !== k).concat([k]);
        while (o.length > 60)
            delete c[o.shift()];
        order = o;
        cache = c;
    }

    function apply(entry: var): void {
        lines = entry?.lines ?? [];
        plain = entry?.plain ?? "";
        status = entry ? (entry.instrumental ? "instrumental" : (lines.length > 0 || plain ? "ready" : "none")) : "none";
        current = -1;
        Qt.callLater(tick);
    }

    function pick(results: var): var {
        if (!Array.isArray(results) || results.length === 0)
            return null;
        const want = duration;
        const score = r => {
            let s = 0;
            if (r.syncedLyrics)
                s += 100;
            else if (r.plainLyrics)
                s += 40;
            if (r.instrumental)
                s += 10;
            if (want > 0 && r.duration > 0) {
                const d = Math.abs(r.duration - want);
                s += d <= 2 ? 60 : d <= 6 ? 30 : d <= 15 ? 5 : -40;
            }
            if (track.artist && (r.artistName ?? "").toLowerCase().includes(track.artist.toLowerCase()))
                s += 25;
            if ((r.trackName ?? "").toLowerCase() === track.title.toLowerCase())
                s += 20;
            return s;
        };
        const best = results.slice().sort((a, b) => score(b) - score(a))[0];
        return score(best) >= 60 ? best : null;
    }

    function entryFrom(r: var): var {
        if (!r)
            return null;
        return { lines: r.syncedLyrics ? parse(r.syncedLyrics).filter((l, i, arr) => l.text !== "" || (i > 0 && arr[i - 1].text !== "")) : [], plain: r.plainLyrics ?? "", instrumental: !!r.instrumental };
    }

    function get(url: string, done: var): void {
        if (request)
            request.abort();
        const xhr = new XMLHttpRequest();
        request = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || request !== xhr)
                return;
            request = null;
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {}
            done(xhr.status, body);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "crest-shell (fiordland)");
        xhr.send();
    }

    function fetch(): void {
        const k = key;
        if (!active || !k || Config.demo)
            return;
        if (cache[k] !== undefined) {
            loadedKey = k;
            apply(cache[k]);
            return;
        }
        status = "loading";
        lines = [];
        plain = "";
        current = -1;
        const t = track;
        const q = (o) => Object.keys(o).filter(x => o[x] !== "" && o[x] !== undefined).map(x => `${x}=${encodeURIComponent(o[x])}`).join("&");
        const search = () => {
            const params = t.artist ? { track_name: t.title, artist_name: t.artist } : { q: t.title };
            get(`https://lrclib.net/api/search?${q(params)}`, (code, body) => {
                if (key !== k)
                    return;
                if (code === 0) {
                    status = "offline";
                    return;
                }
                const entry = entryFrom(pick(body));
                store(k, entry);
                loadedKey = k;
                apply(entry);
            });
        };
        if (t.artist && duration > 0) {
            get(`https://lrclib.net/api/get?${q({ track_name: t.title, artist_name: t.artist, album_name: album, duration: Math.round(duration) })}`, (code, body) => {
                if (key !== k)
                    return;
                if (body && (body.syncedLyrics || body.instrumental)) {
                    const entry = entryFrom(body);
                    store(k, entry);
                    loadedKey = k;
                    apply(entry);
                } else {
                    search();
                }
            });
        } else {
            search();
        }
    }

    function retry(): void {
        const c = cache;
        delete c[key];
        cache = c;
        fetch();
    }

    function tick(): void {
        Media.player?.positionChanged();
        sync();
    }

    function sync(): void {
        position = Media.position;
        const l = lines;
        if (l.length === 0) {
            current = -1;
            return;
        }
        const p = position + 0.25;
        let lo = 0;
        let hi = l.length - 1;
        let idx = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (l[mid].time <= p) {
                idx = mid;
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        if (idx !== current)
            current = idx;
    }

    onKeyChanged: {
        status = key ? "idle" : "none";
        lines = [];
        plain = "";
        current = -1;
        debounce.restart();
    }
    onActiveChanged: if (active && loadedKey !== key)
        debounce.restart()

    Timer {
        id: debounce

        interval: 700
        onTriggered: root.fetch()
    }

    Timer {
        running: root.active && root.lines.length > 0 && Media.playing
        interval: 150
        repeat: true
        onTriggered: root.tick()
    }

    Connections {
        target: Media

        function onPositionChanged(): void {
            if (root.active && root.lines.length > 0)
                Qt.callLater(root.sync);
        }
    }
}
