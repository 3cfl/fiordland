pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import "../utils/fuzzy.js" as Fuzzy

Singleton {
    id: root

    readonly property var demoApps: [
        { id: "firefox", name: "Firefox", genericName: "Web Browser", icon: "firefox", comment: "Browse the web", keywords: [] },
        { id: "kitty", name: "kitty", genericName: "Terminal", icon: "kitty", comment: "Fast GPU terminal", keywords: ["shell"] },
        { id: "thunar", name: "Thunar", genericName: "File Manager", icon: "org.xfce.thunar", comment: "Browse your files", keywords: [] },
        { id: "mousepad", name: "Mousepad", genericName: "Text Editor", icon: "org.xfce.mousepad", comment: "Write plain text", keywords: ["notes"] },
        { id: "crest-settings", name: "Settings", genericName: "crest settings", icon: "preferences-system", comment: "Appearance, bar and wallpaper", keywords: [] },
        { id: "kuaka", name: "kuaka", genericName: "Updates", icon: "system-software-update", comment: "Keep Fiordland up to date", keywords: [] },
        { id: "tawaki", name: "tawaki", genericName: "Software", icon: "system-software-install", comment: "Find and install apps", keywords: [] }
    ]
    readonly property var entries: Config.demo ? demoApps : dedupe(DesktopEntries.applications.values)
    readonly property var usage: Config.launcher.usage ?? {}

    function dedupe(list: var): var {
        const seen = {};
        const out = [];
        for (const e of list) {
            if (!e || e.noDisplay)
                continue;
            const cmd = (e.command ?? []).filter(a => !/^%[a-zA-Z]$/.test(a)).join(" ");
            const keys = [`id:${e.id}`, cmd ? `cmd:${cmd}` : `name:${e.name}`];
            if (keys.some(k => seen[k]))
                continue;
            for (const k of keys)
                seen[k] = true;
            out.push(e);
        }
        return out;
    }

    function query(text: string, limit: int): var {
        const fields = [[e => e.name, 1], [e => e.genericName, 0.75], [e => e.keywords, 0.6], [e => e.comment, 0.35]];
        if (!text.trim())
            return entries.slice().sort((a, b) => ((usage[b.id] ?? 0) - (usage[a.id] ?? 0)) || a.name.localeCompare(b.name)).slice(0, limit);
        const ranked = Fuzzy.rank(entries, text, fields, 0);
        for (const r of ranked)
            r.score += Math.min(60, (usage[r.item.id] ?? 0) * 4);
        ranked.sort((a, b) => b.score - a.score);
        return ranked.slice(0, limit).map(r => r.item);
    }

    function launch(entry: var): void {
        if (Config.demo || !entry)
            return;
        const u = Object.assign({}, usage);
        u[entry.id] = (u[entry.id] ?? 0) + 1;
        Config.launcher.usage = u;
        if (entry.runInTerminal) {
            const term = Quickshell.env("TERMINAL") || "kitty";
            Quickshell.execDetached({
                command: [term, "-e", ...entry.command],
                workingDirectory: entry.workingDirectory || Config.home
            });
        } else {
            entry.execute();
        }
    }
}
