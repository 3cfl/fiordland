pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string hyprDir: (Quickshell.env("XDG_CONFIG_HOME") || Config.home + "/.config") + "/hypr"
    readonly property string overridePath: hyprDir + "/crest-binds.lua"
    readonly property var overrides: Config.binds.overrides ?? {}
    property var defaults: []
    readonly property var list: defaults.map(b => {
        const o = root.overrides[b.keys];
        return Object.assign({}, b, {
            current: o === undefined ? b.keys : o,
            changed: o !== undefined,
            disabled: o === ""
        });
    })

    readonly property var crestNames: ({
            launcherTap: "app launcher (tap super)",
            launcher: "app launcher",
            overview: "workspace overview",
            quicksettings: "quick settings",
            notifications: "notifications",
            clearNotifs: "clear notifications",
            lock: "lock screen",
            session: "power menu",
            settings: "settings",
            wallpaper: "wallpaper picker",
            emoji: "emoji picker",
            dashboard: "dashboard",
            clipboard: "clipboard history",
            capture: "screenshot menu",
            screenshotRegion: "screenshot a region",
            screenshotScreen: "screenshot the screen",
            recordRegion: "record a region",
            volumeUp: "volume up",
            volumeDown: "volume down",
            volumeMute: "mute",
            brightnessUp: "brightness up",
            brightnessDown: "brightness down",
            mediaToggle: "play / pause",
            mediaNext: "next track",
            mediaPrev: "previous track",
            mediaStop: "stop playback"
        })

    function pretty(keys: string): var {
        return keys.split("+").map(k => k.trim()).filter(k => k !== "").map(k => {
            const map = { SUPER: "super", SUPER_L: "super", SHIFT: "shift", CTRL: "ctrl", CONTROL: "ctrl", ALT: "alt", RETURN: "enter", ESCAPE: "esc", PERIOD: ".", SPACE: "space", TAB: "tab", Print: "print", left: "←", right: "→", up: "↑", down: "↓", mouse_down: "scroll down", mouse_up: "scroll up", "mouse:272": "left drag", "mouse:273": "right drag" };
            if (map[k] !== undefined)
                return map[k];
            if (k.startsWith("XF86"))
                return k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2").toLowerCase();
            return k.length === 1 ? k.toUpperCase() : k.toLowerCase();
        }).filter((k, i, a) => a.indexOf(k) === i);
    }

    function describe(disp: string, vars: var): var {
        let m = disp.match(/^crest\("(\w+)"\)$/);
        if (m)
            return { label: crestNames[m[1]] ?? m[1], group: /volume|brightness|media/.test(m[1]) ? "media & hardware" : /screenshot|record|capture/i.test(m[1]) ? "capture" : "shell" };
        m = disp.match(/^hl\.dsp\.exec_cmd\((\w+)\)$/);
        if (m)
            return { label: ({ terminal: "terminal", files: "file manager", browser: "web browser" })[m[1]] ?? `run ${vars[m[1]] ?? m[1]}`, group: "apps" };
        m = disp.match(/^hl\.dsp\.exec_cmd\("(.*)"\)$/);
        if (m) {
            const c = m[1];
            if (/SOURCE@ toggle/.test(c))
                return { label: "mute microphone", group: "media & hardware" };
            if (/wpctl|brightnessctl|playerctl/.test(c))
                return { label: c.replace(/@DEFAULT_AUDIO_\w+@/, "").replace(/\s+/g, " "), group: "media & hardware" };
            if (/grim/.test(c))
                return { label: "screenshot", group: "capture" };
            return { label: `run ${c}`, group: "apps" };
        }
        const dir = (disp.match(/direction = "(\w+)"/) ?? [])[1];
        if (disp.includes("window.close"))
            return { label: "close window", group: "windows" };
        if (disp.includes("fullscreen"))
            return { label: disp.includes("maximized") ? "maximize window" : "fullscreen", group: "windows" };
        if (disp.includes("window.float"))
            return { label: "toggle floating", group: "windows" };
        if (disp.includes("togglesplit"))
            return { label: "toggle split", group: "windows" };
        if (disp.includes("cycle_next"))
            return { label: disp.includes("next = false") ? "previous window" : "next window", group: "windows" };
        if (disp.includes("window.move") && dir)
            return { label: `move window ${dir}`, group: "windows" };
        if (disp.includes("window.drag"))
            return { label: "drag window", group: "windows" };
        if (disp.includes("window.resize"))
            return { label: "resize window", group: "windows" };
        if (disp.includes("focus") && dir)
            return { label: `focus ${dir}`, group: "windows" };
        if (disp.includes("previous"))
            return { label: "last workspace", group: "workspaces" };
        if (disp.includes("r+1"))
            return { label: "next workspace", group: "workspaces" };
        if (disp.includes("r-1"))
            return { label: "previous workspace", group: "workspaces" };
        return { label: disp.replace(/^hl\.dsp\./, ""), group: "other" };
    }

    function splitTop(text: string): var {
        const out = [];
        let depth = 0, quote = "", cur = "";
        for (const ch of text) {
            if (quote) {
                cur += ch;
                if (ch === quote)
                    quote = "";
                continue;
            }
            if (ch === '"' || ch === "'") {
                quote = ch;
                cur += ch;
                continue;
            }
            if ("({[".includes(ch))
                depth++;
            if (")}]".includes(ch))
                depth--;
            if (ch === "," && depth === 0) {
                out.push(cur.trim());
                cur = "";
                continue;
            }
            cur += ch;
        }
        if (cur.trim() !== "")
            out.push(cur.trim());
        return out;
    }

    function parse(text: string): void {
        const vars = {};
        const re = /^local (\w+) = "([^"]*)"/gm;
        let m;
        while ((m = re.exec(text)) !== null)
            vars[m[1]] = m[2];
        const crested = vars.shell === "crest";
        const stack = [];
        const out = [];
        const seen = {};
        let started = false;
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            if (line.startsWith("hl.bind("))
                started = true;
            if (!started)
                continue;
            if (/^if not crested then$/.test(line)) {
                stack.push("nocrest");
                continue;
            }
            if (/^if crested then$/.test(line)) {
                stack.push("crest");
                continue;
            }
            if (/^(if|for|while)\b.*\b(then|do)$/.test(line) || /^(local )?function\b/.test(line) && !/\bend\b/.test(line)) {
                stack.push("other");
                continue;
            }
            if (line === "else") {
                const top = stack.pop();
                stack.push(top === "crest" ? "nocrest" : top === "nocrest" ? "crest" : "other");
                continue;
            }
            if (line === "end" || line === "end)") {
                stack.pop();
                continue;
            }
            const active = stack.every(s => s === "other" || (s === "crest") === crested);
            if (!active || !line.startsWith("hl.bind(") || !line.endsWith(")"))
                continue;
            const args = splitTop(line.slice(8, -1));
            if (args.length < 2)
                continue;
            if (/\.\. key\b/.test(args[0])) {
                const shifted = args[0].includes("SHIFT");
                if (!seen[args[0]]) {
                    seen[args[0]] = true;
                    out.push({ keys: shifted ? "SUPER + SHIFT + 1-0" : "SUPER + 1-0", label: shifted ? "move window to workspace" : "go to workspace", group: "workspaces", fixed: true, disp: "", opts: "" });
                }
                continue;
            }
            const keys = args[0].replace(/\bmod\s*\.\.\s*"/, `"${vars.mod ?? "SUPER"}`).replace(/^"|"$/g, "");
            if (keys.includes('"'))
                continue;
            const d = describe(args[1], vars);
            const disp = args[1].replace(/^crest\("(\w+)"\)$/, 'hl.dsp.global("crest:$1")').replace(/\((terminal|files|browser)\)/, (all, v) => `(${JSON.stringify(vars[v] ?? v)})`);
            const entry = { keys, label: d.label, group: d.group, fixed: false, disp, opts: args[2] ?? "" };
            if (seen[keys])
                continue;
            seen[keys] = true;
            out.push(entry);
        }
        defaults = out;
    }

    function normalize(keys: string): string {
        return keys.split("+").map(k => k.trim()).filter(k => k).join(" + ");
    }

    function conflict(keys: string, except: string): var {
        const n = normalize(keys).toUpperCase();
        return list.find(b => b.keys !== except && !b.disabled && normalize(b.current).toUpperCase() === n) ?? null;
    }

    function setBind(orig: string, keys: string): void {
        const o = Object.assign({}, overrides);
        if (keys === orig)
            delete o[orig];
        else
            o[orig] = keys === "" ? "" : normalize(keys);
        Config.binds.overrides = o;
        write(o);
    }

    function reset(orig: string): void {
        setBind(orig, orig);
    }

    function resetAll(): void {
        Config.binds.overrides = {};
        write({});
    }

    function write(o: var): void {
        const lines = [];
        for (const b of defaults) {
            if (b.fixed || o[b.keys] === undefined)
                continue;
            lines.push(`hl.unbind(${JSON.stringify(b.keys)})`);
            if (o[b.keys] !== "")
                lines.push(`hl.bind(${JSON.stringify(o[b.keys])}, ${b.disp}${b.opts ? ", " + b.opts : ""})`);
        }
        writer.command = ["sh", "-c", 'printf "%s\\n" "$2" > "$1" && hyprctl reload >/dev/null', "sh", overridePath, lines.join("\n")];
        writer.running = true;
    }

    function refresh(): void {
        source.reload();
    }

    FileView {
        id: source

        path: Config.demo ? "" : root.hyprDir + "/hyprland.lua"
        printErrors: false
        onLoaded: root.parse(text())
    }

    Process {
        id: writer
    }

    IpcHandler {
        target: "binds"

        function list(): string {
            return root.list.map(b => `${b.current}\t${b.label}`).join("\n");
        }

        function set(orig: string, keys: string): void {
            root.setBind(orig, keys);
        }

        function reset(orig: string): void {
            root.reset(orig);
        }

        function resetAll(): void {
            root.resetAll();
        }
    }
}
