pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.config
import qs.services
import qs.theme
import "modules/bar"
import "modules/quicksettings"
import "modules/notifications"

ShellRoot {
    id: root

    readonly property string out: Quickshell.env("CREST_RENDER_OUT") || "."
    property int index: -1
    readonly property var scenes: [
        { name: "bar", w: 1440, h: 72, comp: barScene, light: false },
        { name: "quicksettings", w: 460, h: 760, comp: qsScene, light: false },
        { name: "quicksettings-light", w: 460, h: 760, comp: qsScene, light: true },
        { name: "notification", w: 440, h: 200, comp: notifScene, light: false }
    ]

    function next(): void {
        index++;
        if (index >= scenes.length) {
            console.log("render: done");
            Qt.quit();
            return;
        }
        const s = scenes[index];
        Config.appearance.mode = s.light ? "light" : "dark";
        win.width = s.w;
        win.height = s.h;
        loader.sourceComponent = null;
        loader.sourceComponent = s.comp;
        settle.restart();
    }

    Component.onCompleted: {
        Perf.lowEnd;
        Scheme.mode;
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

        interval: 1600
        onTriggered: {
            const name = root.scenes[root.index].name;
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
            sourceSize.width: 96
            fillMode: Image.PreserveAspectCrop
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            color: Colours.alpha(Colours.scrim, Colours.light ? 0 : 0.15)
        }

        Loader {
            id: loader

            anchors.fill: parent
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
        id: notifScene

        Item {
            NotifCard {
                x: 24
                y: 24
                width: parent.width - 48
                entry: Notifs.list[0]
            }
        }
    }
}
