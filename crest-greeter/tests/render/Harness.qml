pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import Quickshell
import qs.services
import qs.theme

ShellRoot {
    id: root

    readonly property string out: Quickshell.env("CREST_RENDER_OUT") || "."
    property int index: -1
    property var scene: ({})
    readonly property var scenes: [
        { name: "greeter", w: 1440, h: 900 },
        { name: "greeter-failed", w: 1440, h: 900, failed: true },
        { name: "greeter-sessions", w: 1440, h: 900, sessions: true },
        { name: "greeter-busy", w: 1440, h: 900, busy: true },
        { name: "greeter-narrow", w: 820, h: 1000 }
    ]

    function next(): void {
        index++;
        if (index >= scenes.length) {
            console.log("render: done");
            Qt.quit();
            return;
        }
        scene = scenes[index];
        Login.cancel();
        win.width = scene.w;
        win.height = scene.h;
        loader.active = false;
        loader.active = true;
        if (scene.failed) {
            Login.state = "failed";
            Login.message = "that's not it, try again";
        } else if (scene.busy) {
            Login.state = "busy";
        }
        settle.restart();
    }

    Component.onCompleted: {
        Perf.apply();
        Qt.callLater(next);
    }

    Timer {
        interval: 120000
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
        color: "black"

        Loader {
            id: loader

            anchors.fill: parent
            active: false

            sourceComponent: GreeterContent {
                sessionsOpen: root.scene.sessions === true
            }
        }
    }
}
