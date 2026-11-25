pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    readonly property bool lua: !demo && Hyprland.usingLua
    readonly property int activeId: demo ? 2 : (Hyprland.focusedWorkspace?.id ?? 1)
    readonly property var workspaces: demo ? [] : Hyprland.workspaces.values
    readonly property var toplevels: demo ? [] : Hyprland.toplevels.values
    readonly property var occupied: {
        if (demo)
            return { "1": 2, "2": 3, "4": 1 };
        const map = {};
        for (const ws of workspaces) {
            if (ws.id > 0)
                map[String(ws.id)] = ws.toplevels.values.length;
        }
        return map;
    }
    readonly property bool fullscreen: !demo && (Hyprland.focusedWorkspace?.hasFullscreen ?? false)
    readonly property string activeTitle: demo ? "kitty" : (Hyprland.activeToplevel?.title ?? "")

    function workspace(id: int): void {
        const n = Math.round(id);
        if (demo || !(n >= 1 && n <= 99))
            return;
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "${n}" })` : `workspace ${n}`);
    }

    function relative(step: int): void {
        if (demo)
            return;
        const s = step > 0 ? "+1" : "-1";
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "r${s}" })` : `workspace r${s}`);
    }

    function focusWindow(address: string): void {
        if (demo || !/^[0-9a-fA-F]+$/.test(address))
            return;
        Hyprland.dispatch(lua ? `hl.dsp.focus({ window = "address:0x${address}" })` : `focuswindow address:0x${address}`);
    }

    function apply(luaChunks: list<string>, keywords: list<string>): void {
        if (demo)
            return;
        if (lua) {
            for (const chunk of luaChunks)
                Quickshell.execDetached(["hyprctl", "eval", chunk]);
        } else {
            Quickshell.execDetached(["hyprctl", "--batch", keywords.map(k => `keyword ${k}`).join(";")]);
        }
    }

    function hex(c: color): string {
        const h = v => Math.round(v * 255).toString(16).padStart(2, "0");
        return h(c.r) + h(c.g) + h(c.b);
    }

    function setBorders(active: color, accent: color, inactive: color): void {
        const a = hex(active);
        const b = hex(accent);
        const i = hex(inactive);
        apply([`hl.config({ general = { col = { active_border = { colors = { "rgba(${a}ee)", "rgba(${b}ee)" }, angle = 45 }, inactive_border = "rgba(${i}aa)" } } })`], [`general:col.active_border rgba(${a}ee) rgba(${b}ee) 45deg`, `general:col.inactive_border rgba(${i}aa)`]);
    }

    function setLowEnd(on: bool): void {
        const v = on ? "false" : "true";
        const n = on ? "0" : "1";
        apply([`hl.config({ decoration = { blur = { enabled = ${v} }, shadow = { enabled = ${v} } }, animations = { enabled = ${v} } })`], [`decoration:blur:enabled ${n}`, `decoration:shadow:enabled ${n}`, `animations:enabled ${n}`]);
    }
}
