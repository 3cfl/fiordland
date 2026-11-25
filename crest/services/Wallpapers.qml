pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string bundled: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property string system: "/usr/share/fiordland/wallpaper.png"
    property bool systemExists: false
    readonly property string fallback: systemExists ? system : bundled
    readonly property string current: Config.demo ? bundled : (Config.wallpaper.path || fallback)
    readonly property bool isDefault: current === bundled || current === system
    readonly property var folders: {
        const home = Config.home;
        const dirs = [home + "/Pictures/Wallpapers", home + "/Pictures/wallpapers", home + "/Pictures", "/usr/share/backgrounds", "/usr/share/fiordland"];
        const extra = Quickshell.env("CREST_WALLPAPER_DIR");
        if (extra)
            dirs.unshift(extra);
        if (Config.wallpaper.folder)
            dirs.unshift(Config.wallpaper.folder);
        return dirs;
    }
    property list<string> found: []
    readonly property list<string> all: {
        const list = [root.fallback];
        for (const f of found)
            if (list.indexOf(f) < 0)
                list.push(f);
        return list;
    }
    readonly property bool scanning: scanner.running

    function set(path: string): void {
        if (!path || path.indexOf("\n") >= 0)
            return;
        Config.wallpaper.path = path === root.fallback ? "" : path;
    }

    function scan(): void {
        scanner.running = true;
    }

    Process {
        running: !Config.demo
        command: ["test", "-r", root.system]
        onExited: code => root.systemExists = code === 0
    }

    Process {
        id: scanner

        command: ["find", "-L", ...root.folders, "-maxdepth", "2", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.found = text.split("\n").filter(l => l.length > 0).sort().slice(0, 300)
        }
    }
}
