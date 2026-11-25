pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services
import qs.theme
import "modules/bar"
import "modules/launcher"
import "modules/lock"
import "modules/notifications"
import "modules/osd"
import "modules/overview"
import "modules/quicksettings"
import "modules/session"
import "modules/settings"
import "modules/wallpaper"

ShellRoot {
    id: root

    readonly property string out: Quickshell.env("CREST_RENDER_OUT") || "."
    property int index: -1
    property var scene: ({})
    readonly property var scenes: [
        { name: "bar", w: 1440, h: 76, comp: barScene },
        { name: "bar-light", w: 1440, h: 76, comp: barScene, light: true },
        { name: "launcher", w: 720, h: 640, comp: launcherScene, seed: "" },
        { name: "launcher-calc", w: 720, h: 300, comp: launcherScene, seed: "=2^10/4 + sqrt(9)" },
        { name: "launcher-emoji", w: 720, h: 560, comp: launcherScene, seed: ":heart" },
        { name: "quicksettings", w: 460, h: 780, comp: qsScene },
        { name: "quicksettings-light", w: 460, h: 780, comp: qsScene, light: true },
        { name: "notification-centre", w: 500, h: 900, comp: centreScene },
        { name: "notification-popup", w: 460, h: 160, comp: popupScene },
        { name: "osd", w: 400, h: 110, comp: osdScene },
        { name: "session", w: 1280, h: 720, comp: sessionScene },
        { name: "lock", w: 1280, h: 800, comp: lockScene },
        { name: "lock-failed", w: 1280, h: 800, comp: lockScene, failed: true },
        { name: "wallpaper", w: 1060, h: 360, comp: wallpaperScene },
        { name: "settings", w: 880, h: 620, comp: settingsScene, page: "appearance" },
        { name: "settings-performance", w: 880, h: 620, comp: settingsScene, page: "performance" },
        { name: "overview", w: 1440, h: 810, comp: overviewScene }
    ]

    function next(): void {
        index++;
        if (index >= scenes.length) {
            console.log("render: done");
            Qt.quit();
            return;
        }
        scene = scenes[index];
        Config.appearance.mode = scene.light ? "light" : "dark";
        win.width = scene.w;
        win.height = scene.h;
        loader.sourceComponent = null;
        loader.sourceComponent = scene.comp;
        settle.restart();
    }

    Component.onCompleted: {
        Perf.lowEnd;
        Scheme.mode;
        Emoji.load();
        Qt.callLater(next);
    }

    Timer {
        interval: 200000
        running: true
        onTriggered: {
            console.error("render: hard timeout");
            Qt.exit(3);
        }
    }

    Timer {
        id: settle

        interval: 1800
        onTriggered: {
            const name = root.scene.name;
            win.contentItem.grabToImage(result => {
                const ok = result.saveToFile(`${root.out}/crest-${name}.png`);
                console.log(`render: ${name} ${ok ? "ok" : "failed"}`);
                root.next();
            });
        }
    }

    Window {
        id: win

        visible: true
        color: Colours.surface

        Image {
            anchors.fill: parent
            source: Quickshell.shellPath("assets/wallpaper.webp")
            sourceSize.width: 120
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.scrim, Colours.light ? 0 : 0.2)
        }

        Loader {
            id: loader

            anchors.fill: parent
        }
    }

    QtObject {
        id: fakeAuth

        property string state: root.scene.failed ? "failed" : ""
        property string message: root.scene.failed ? "that's not it, try again" : ""
        property bool fprintReady: false

        signal failed
        signal succeeded

        function submit(password: string): void {
        }
    }

    Component {
        id: barScene

        Item {
            BarContent {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
            }
        }
    }

    Component {
        id: launcherScene

        Item {
            LauncherContent {
                x: (parent.width - width) / 2
                y: 24
                width: implicitWidth
                seed: root.scene.seed
            }
        }
    }

    Component {
        id: qsScene

        Item {
            QuickSettingsContent {
                x: 24
                y: 16
                width: parent.width - 48
            }
        }
    }

    Component {
        id: centreScene

        Item {
            CentreContent {
                x: 24
                y: 16
                width: parent.width - 48
            }
        }
    }

    Component {
        id: popupScene

        Item {
            NotifCard {
                x: 20
                y: 20
                width: parent.width - 40
                entry: Notifs.list[1]
            }
        }
    }

    Component {
        id: osdScene

        Item {
            OsdContent {
                anchors.centerIn: parent
                icon: "volume_up"
                value: 0.62
            }
        }
    }

    Component {
        id: sessionScene

        Item {
            Rectangle {
                anchors.fill: parent
                color: Colours.alpha(Colours.scrim, 0.4)
            }

            SessionContent {
                anchors.fill: parent
                current: 1
            }
        }
    }

    Component {
        id: lockScene

        LockContent {
            auth: fakeAuth
        }
    }

    Component {
        id: wallpaperScene

        Item {
            WallpaperContent {
                x: 30
                y: 24
                width: parent.width - 60
            }
        }
    }

    Component {
        id: settingsScene

        SettingsContent {
            page: root.scene.page
        }
    }

    Component {
        id: overviewScene

        Item {
            Rectangle {
                anchors.fill: parent
                color: Colours.alpha(Colours.scrim, 0.4)
            }

            OverviewContent {
                anchors.fill: parent
            }
        }
    }
}
