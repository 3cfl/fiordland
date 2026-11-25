pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool demo: Config.demo
    property bool available: demo
    property real value: demo ? 0.7 : 0
    property int max: 0

    signal changed

    function refresh(): void {
        if (!demo)
            reader.running = true;
    }

    function set(v: real): void {
        const val = Math.max(0.01, Math.min(1, v));
        value = val;
        changed();
        if (demo || !available)
            return;
        writer.command = ["brightnessctl", "-q", "-c", "backlight", "set", `${Math.round(val * 100)}%`];
        writer.running = true;
    }

    function step(dir: int): void {
        set(value + (dir > 0 ? 0.05 : -0.05));
    }

    Component.onCompleted: refresh()

    Process {
        id: reader

        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",");
                if (parts.length >= 5) {
                    const cur = parseInt(parts[2]);
                    const max = parseInt(parts[4]);
                    if (max > 0) {
                        root.max = max;
                        root.value = cur / max;
                        root.available = true;
                    }
                }
            }
        }
    }

    Process {
        id: writer
    }
}
