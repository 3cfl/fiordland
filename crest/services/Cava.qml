pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property int users: 0
    property int bars: 64
    property var values: []
    property bool available: false
    readonly property bool running: proc.running

    readonly property string conf: `[general]
bars = ${bars}
framerate = 60
autosens = 1
[input]
method = pipewire
source = auto
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59
frame_delimiter = 10
channels = mono
[smoothing]
noise_reduction = 70
`

    function acquire(): void {
        users++;
        if (!available)
            probe.running = true;
    }

    function release(): void {
        users = Math.max(0, users - 1);
        if (users === 0)
            values = [];
    }

    Process {
        id: probe

        running: !Config.demo
        command: ["sh", "-c", "command -v cava"]
        onExited: code => root.available = code === 0
    }

    Process {
        id: proc

        running: root.available && root.users > 0
        command: ["sh", "-c", 'f="$1/cava.conf"; printf "%s" "$2" > "$f"; exec cava -p "$f"', "sh", Config.cacheDir, root.conf]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < root.bars; i++)
                    out.push(Math.min(1, (parseInt(parts[i]) || 0) / 1000));
                root.values = out;
            }
        }
    }
}
