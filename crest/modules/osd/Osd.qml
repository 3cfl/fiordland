pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import "../common"

Scope {
    id: root

    property string kind: "volume"
    property bool shown: false
    property bool armed: false

    function show(k: string): void {
        if (!armed)
            return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hide

        interval: 1400
        onTriggered: root.shown = false
    }

    Connections {
        target: Audio

        function onChanged(): void {
            root.show("volume");
        }
    }

    Connections {
        target: Brightness

        function onChanged(): void {
            root.show("brightness");
        }
    }

    Popout {
        name: "osd"
        edge: "bottom"
        offset: 48
        open: root.shown
        interactive: false
        content: OsdContent {
            icon: root.kind === "volume" ? Audio.icon : "light_mode"
            value: root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
            label: root.kind === "volume" && Audio.muted ? "off" : ""
        }
    }
}
