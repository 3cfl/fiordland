pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool demo: Quickshell.env("CREST_DEMO") === "1"
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/crest"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/crest"
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || home + "/.cache") + "/crest"
    property bool dirsReady: false
    readonly property bool loaded: demo || file.loaded

    property alias appearance: adapter.appearance
    property alias bar: adapter.bar
    property alias performance: adapter.performance
    property alias wallpaper: adapter.wallpaper
    property alias notifications: adapter.notifications
    property alias nightLight: adapter.nightLight
    property alias lock: adapter.lock
    property alias launcher: adapter.launcher
    property alias capture: adapter.capture
    property alias clipboard: adapter.clipboard
    property alias media: adapter.media
    property alias binds: adapter.binds

    Process {
        running: !root.demo
        command: ["mkdir", "-p", root.configDir, root.stateDir, root.cacheDir]
        onExited: root.dirsReady = true
    }

    FileView {
        id: file

        path: root.dirsReady ? root.configDir + "/config.json" : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property AppearanceOptions appearance: AppearanceOptions {}

            property BarOptions bar: BarOptions {}

            property PerformanceOptions performance: PerformanceOptions {}

            property WallpaperOptions wallpaper: WallpaperOptions {}

            property NotificationsOptions notifications: NotificationsOptions {}

            property NightLightOptions nightLight: NightLightOptions {}

            property LockOptions lock: LockOptions {}

            property LauncherOptions launcher: LauncherOptions {}

            property CaptureOptions capture: CaptureOptions {}

            property ClipboardOptions clipboard: ClipboardOptions {}

            property MediaOptions media: MediaOptions {}

            property BindsOptions binds: BindsOptions {}
        }
    }

    component AppearanceOptions: JsonObject {
        property string mode: "dark"
        property string scheme: "wallpaper"
        property string variant: "scheme-tonal-spot"
        property bool transparency: true
        property bool terminal: true
        property bool apps: true
    }

    component BarOptions: JsonObject {
        property int workspaces: 5
        property bool showSeconds: false
        property bool batteryPercent: true
        property bool showMedia: true
        property bool use24h: true
        property bool showTray: true
        property bool showStats: true
    }

    component PerformanceOptions: JsonObject {
        property string lowEnd: "auto"
    }

    component WallpaperOptions: JsonObject {
        property string path: ""
        property string folder: ""
    }

    component NotificationsOptions: JsonObject {
        property bool dnd: false
        property int timeout: 6000
    }

    component NightLightOptions: JsonObject {
        property bool enabled: false
        property int temperature: 4500
    }

    component LockOptions: JsonObject {
        property bool fingerprint: false
        property int idleMinutes: 10
        property bool lockBeforeSleep: true
    }

    component LauncherOptions: JsonObject {
        property var usage: ({})
    }

    component CaptureOptions: JsonObject {
        property string mode: "region"
        property bool audio: false
    }

    component MediaOptions: JsonObject {
        property bool lyrics: true
        property bool showLyrics: true
    }

    component BindsOptions: JsonObject {
        property var overrides: ({})
    }

    component ClipboardOptions: JsonObject {
        property bool enabled: true
        property int keep: 200
    }
}
