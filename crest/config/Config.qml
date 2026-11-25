pragma Singleton

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

            property JsonObject appearance: JsonObject {
                property string mode: "dark"
                property string scheme: "wallpaper"
                property string variant: "scheme-tonal-spot"
                property bool transparency: true
            }

            property JsonObject bar: JsonObject {
                property int workspaces: 5
                property bool showSeconds: false
                property bool batteryPercent: true
                property bool showMedia: true
                property bool use24h: true
                property bool showTray: true
            }

            property JsonObject performance: JsonObject {
                property string lowEnd: "auto"
            }

            property JsonObject wallpaper: JsonObject {
                property string path: ""
                property string folder: ""
            }

            property JsonObject notifications: JsonObject {
                property bool dnd: false
                property int timeout: 6000
            }

            property JsonObject nightLight: JsonObject {
                property bool enabled: false
                property int temperature: 4500
            }

            property JsonObject lock: JsonObject {
                property bool fingerprint: false
                property int idleMinutes: 10
                property bool lockBeforeSleep: true
            }

            property JsonObject launcher: JsonObject {
                property var usage: ({})
            }
        }
    }
}
