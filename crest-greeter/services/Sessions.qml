pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool demo: Quickshell.env("CREST_DEMO") === "1"
    property bool hasStartx: false
    property var list: demo ? [
        { id: "hyprland", name: "Hyprland", exec: ["Hyprland"], type: "wayland", desktop: "Hyprland" },
        { id: "plasma", name: "Plasma (Wayland)", exec: ["startplasma-wayland"], type: "wayland", desktop: "KDE" },
        { id: "xfce", name: "Xfce Session", exec: ["startxfce4"], type: "x11", desktop: "XFCE" }
    ] : []

    function find(id: string): var {
        for (const s of list)
            if (s.id === id)
                return s;
        return null;
    }

    function splitExec(exec: string): var {
        const argv = [];
        let cur = "";
        let quoted = false;
        let has = false;
        for (let i = 0; i < exec.length; i++) {
            const c = exec[i];
            if (quoted) {
                if (c === "\\" && i + 1 < exec.length) {
                    cur += exec[++i];
                } else if (c === "\"") {
                    quoted = false;
                } else {
                    cur += c;
                }
            } else if (c === "\"") {
                quoted = true;
                has = true;
            } else if (c === " " || c === "\t") {
                if (has || cur !== "")
                    argv.push(cur);
                cur = "";
                has = false;
            } else {
                cur += c;
            }
        }
        if (has || cur !== "")
            argv.push(cur);
        return argv.filter(a => !/^%[fFuUdDnNickvm]$/.test(a)).map(a => a.replace(/%%/g, "%"));
    }

    function parse(text: string): void {
        const files = {};
        for (const line of text.split("\n")) {
            if (line === "startx")
                hasStartx = true;
            const m = line.match(/^(\/usr\/share\/(wayland-sessions|xsessions)\/([^/:]+)\.desktop):(Name|Exec|NoDisplay|Hidden|DesktopNames)=(.*)$/);
            if (!m)
                continue;
            const f = files[m[1]] ?? (files[m[1]] = { id: m[3], type: m[2] === "xsessions" ? "x11" : "wayland" });
            if (f[m[4]] === undefined)
                f[m[4]] = m[5].trim();
        }
        const out = [];
        const seen = {};
        for (const path of Object.keys(files).sort()) {
            const f = files[path];
            if (!f.Name || !f.Exec || f.NoDisplay === "true" || f.Hidden === "true")
                continue;
            if (f.type === "x11" && !hasStartx)
                continue;
            const exec = splitExec(f.Exec);
            if (exec.length === 0)
                continue;
            const key = `${f.type}:${f.id}`;
            if (seen[key])
                continue;
            seen[key] = true;
            out.push({
                id: f.type === "x11" ? `x11-${f.id}` : f.id,
                name: f.Name,
                exec: exec,
                type: f.type,
                desktop: (f.DesktopNames ?? "").split(";")[0] || f.id
            });
        }
        out.sort((a, b) => (a.type === b.type ? a.name.localeCompare(b.name) : a.type === "wayland" ? -1 : 1));
        list = out;
    }

    Process {
        running: !root.demo
        command: ["sh", "-c", "command -v startx >/dev/null 2>&1 && echo startx; find /usr/share/wayland-sessions /usr/share/xsessions -maxdepth 1 -name '*.desktop' -type f -exec grep -H -E '^(Name|Exec|NoDisplay|Hidden|DesktopNames)=' {} + 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
}
