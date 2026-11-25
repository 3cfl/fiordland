pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/fuzzy.js" as Fuzzy

Singleton {
    id: root

    property bool wanted: false
    property var entries: []
    readonly property bool ready: entries.length > 0

    function load(): void {
        wanted = true;
    }

    function query(text: string, limit: int): var {
        if (!ready)
            return [];
        const q = text.trim();
        if (!q)
            return entries.slice(0, limit);
        return Fuzzy.rank(entries, q, [[e => e.name, 1], [e => e.group, 0.3]], limit).map(r => r.item);
    }

    function copy(e: var): void {
        if (!e?.char)
            return;
        Quickshell.execDetached(["wl-copy", "--", e.char]);
    }

    FileView {
        path: root.wanted ? Quickshell.shellPath("assets/emoji.tsv") : ""
        printErrors: false
        onLoaded: {
            const out = [];
            for (const line of text().split("\n")) {
                const cols = line.split("\t");
                if (cols.length >= 2 && cols[0])
                    out.push({ char: cols[0], name: cols[1], group: cols[2] ?? "" });
            }
            root.entries = out;
        }
    }
}
