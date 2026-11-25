pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    property int memoryMb: 0
    property bool softwareGpu: false
    readonly property bool demo: Quickshell.env("CREST_DEMO") === "1"
    readonly property bool softwareBackend: (Quickshell.env("QT_QUICK_BACKEND") ?? "") === "software"
    readonly property bool lowEnd: softwareGpu || (memoryMb > 0 && memoryMb < 3800)

    onLowEndChanged: apply()
    Component.onCompleted: apply()

    function apply(): void {
        Style.blur = !lowEnd;
        Style.shadows = !lowEnd && !softwareBackend;
        Style.effects = !lowEnd && !softwareBackend;
        Motion.reduced = lowEnd;
    }

    FileView {
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const m = text().match(/MemTotal:\s+(\d+)/);
            if (m)
                root.memoryMb = Math.round(parseInt(m[1]) / 1024);
        }
    }

    Process {
        running: !root.demo
        command: ["sh", "-c", "for d in /sys/class/drm/card*/device/driver; do [ -e \"$d\" ] && basename \"$(readlink -f \"$d\")\"; done; [ -n \"${LIBGL_ALWAYS_SOFTWARE:-}\" ] && echo llvmpipe; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const soft = ["simpledrm", "bochs-drm", "bochs", "qxl", "cirrus", "cirrus-qemu", "vboxvideo", "virtio_gpu", "virtio-pci", "hyperv_drm", "efifb", "vesafb", "llvmpipe"];
                const drivers = text.split("\n").map(s => s.trim()).filter(s => s);
                root.softwareGpu = drivers.length === 0 || drivers.every(d => soft.indexOf(d) >= 0);
            }
        }
    }
}
