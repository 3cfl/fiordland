pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

Singleton {
    id: root

    readonly property string mode: Config.appearance.mode === "light" ? "light" : "dark"
    readonly property list<string> variants: ["scheme-tonal-spot", "scheme-expressive", "scheme-content", "scheme-fidelity", "scheme-vibrant", "scheme-neutral", "scheme-monochrome", "scheme-rainbow", "scheme-fruit-salad"]
    readonly property string variant: variants.indexOf(Config.appearance.variant) >= 0 ? Config.appearance.variant : "scheme-tonal-spot"
    readonly property string liveDir: (Quickshell.env("XDG_STATE_HOME")?.startsWith("/") ? Quickshell.env("XDG_STATE_HOME") : Config.home + "/.local/state") + "/kereru"
    property bool liveReady: false
    property string liveImage: ""
    property string liveKey: ""
    readonly property bool live: liveImage !== ""
    readonly property string source: live ? liveImage : Wallpapers.current
    readonly property bool fromWallpaper: Config.appearance.scheme === "wallpaper" && (live || !Wallpapers.isDefault)
    readonly property string key: fromWallpaper ? (live ? `kereru:${liveKey}|${variant}` : `${Wallpapers.current}|${variant}`) : "fjord"
    property var override: null
    property var cache: ({})
    property string cachedKey: ""
    property bool stateLoaded: Config.demo
    readonly property bool generating: gen.running

    Binding {
        target: Colours
        property: "light"
        value: root.mode === "light"
    }

    Binding {
        target: Colours
        property: "scheme"
        value: root.override ?? (root.cachedKey === root.key && root.key !== "fjord" ? (root.cache[root.mode] ?? null) : null)
    }

    onKeyChanged: refresh()
    onStateLoadedChanged: refresh()

    function refresh(): void {
        if (!stateLoaded || !Config.loaded)
            return;
        if (key === "fjord" || cachedKey === key) {
            Qt.callLater(root.pushBorders);
            return;
        }
        gen.targetKey = key;
        gen.command = ["matugen", "image", source, "-t", variant, "-m", mode, "--json", "hex", "--dry-run", "--source-color-index", "0"];
        gen.running = true;
    }

    function camel(name: string): string {
        return name.replace(/_([a-z])/g, (m, c) => c.toUpperCase());
    }

    function extract(json: var, which: string): var {
        const out = {};
        let colors = json.colors ?? json;
        if (colors.dark && colors.light && typeof colors.dark === "object" && !colors.dark.color)
            colors = colors[which];
        for (const raw of Object.keys(colors)) {
            const name = camel(raw);
            if (Colours.roles.indexOf(name) < 0)
                continue;
            let v = colors[raw];
            if (v && typeof v === "object")
                v = v[which]?.color ?? v[which] ?? v.default?.color ?? v.color;
            if (typeof v === "string" && /^#[0-9a-fA-F]{6}/.test(v))
                out[name] = v.slice(0, 7);
        }
        return Object.keys(out).length >= 10 ? out : null;
    }

    function readLive(text: string): void {
        let image = "";
        let key = "";
        try {
            const s = JSON.parse(text);
            const expected = root.liveDir + "/colors.png";
            if (s && s.playing === true && s.image === expected && typeof s.key === "string" && s.key.length > 0 && s.key.length <= 4096 && s.key.indexOf("\n") < 0) {
                image = expected;
                key = s.key;
            }
        } catch (e) {}
        root.liveKey = key;
        root.liveImage = image;
    }

    function pushBorders(): void {
        Hypr.setBorders(Colours.primary, Colours.tertiary, Colours.outlineVariant);
    }

    Process {
        id: gen

        property string targetKey

        onExited: {
            if (targetKey !== root.key)
                Qt.callLater(root.refresh);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const a = text.indexOf("{");
                const b = text.lastIndexOf("}");
                if (a < 0 || b <= a)
                    return;
                try {
                    const json = JSON.parse(text.slice(a, b + 1));
                    const dark = root.extract(json, "dark");
                    const light = root.extract(json, "light");
                    if (!dark && !light)
                        return;
                    root.cache = { dark: dark ?? light, light: light ?? dark };
                    root.cachedKey = gen.targetKey;
                    state.setText(JSON.stringify({ key: root.cachedKey, dark: root.cache.dark, light: root.cache.light }));
                    Qt.callLater(root.pushBorders);
                } catch (e) {
                    console.warn("crest: could not read matugen output");
                }
            }
        }
    }

    FileView {
        id: state

        path: Config.demo || !Config.dirsReady ? "" : Config.stateDir + "/scheme.json"
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (s.key && s.dark && s.light) {
                    root.cache = { dark: s.dark, light: s.light };
                    root.cachedKey = s.key;
                }
            } catch (e) {
                console.warn("crest: ignoring unreadable scheme state");
            }
            root.stateLoaded = true;
        }
        onLoadFailed: root.stateLoaded = true
    }

    Process {
        running: !Config.demo
        command: ["mkdir", "-p", "-m", "700", root.liveDir]
        onExited: root.liveReady = true
    }

    FileView {
        id: liveState

        path: root.liveReady ? root.liveDir + "/colors.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.readLive(text())
        onLoadFailed: root.readLive("")
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.refresh();
        }
    }

    Connections {
        target: Colours

        function onLightChanged(): void {
            Qt.callLater(root.pushBorders);
        }
    }
}
