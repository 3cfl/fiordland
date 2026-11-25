pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

Singleton {
    id: root

    property int memoryMb: 0
    property bool softwareGpu: false
    property bool probed: false
    readonly property bool softwareBackend: (Quickshell.env("QT_QUICK_BACKEND") ?? "") === "software"
    readonly property bool autoLow: softwareGpu || (memoryMb > 0 && memoryMb < 3800)
    readonly property string mode: Config.performance.lowEnd
    readonly property bool lowEnd: mode === "on" || (mode === "auto" && autoLow)
    readonly property string reason: softwareGpu ? "software rendering" : (memoryMb > 0 && memoryMb < 3800) ? "less than 4 GB of memory" : ""

    onLowEndChanged: apply()

    function apply(): void {
        Style.blur = !lowEnd && Config.appearance.transparency;
        Style.shadows = !lowEnd && !softwareBackend;
        Style.effects = !lowEnd && !softwareBackend;
        Motion.reduced = lowEnd;
        if (probed)
            Hypr.setLowEnd(lowEnd);
    }

    Connections {
        target: Config.appearance

        function onTransparencyChanged(): void {
            root.apply();
        }
    }

    Component.onCompleted: apply()

    FileView {
        path: "/proc/meminfo"
        onLoaded: {
            const m = text().match(/MemTotal:\s+(\d+)/);
            if (m)
                root.memoryMb = Math.round(parseInt(m[1]) / 1024);
        }
    }

    Process {
        running: !Config.demo
        command: ["sh", "-c", "for d in /sys/class/drm/card*/device/driver; do [ -e \"$d\" ] && basename \"$(readlink -f \"$d\")\"; done; [ -n \"${LIBGL_ALWAYS_SOFTWARE:-}\" ] && echo llvmpipe; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const soft = ["simpledrm", "bochs-drm", "bochs", "qxl", "cirrus", "cirrus-qemu", "vboxvideo", "virtio_gpu", "virtio-pci", "hyperv_drm", "efifb", "vesafb", "llvmpipe"];
                const drivers = text.split("\n").map(s => s.trim()).filter(s => s);
                root.softwareGpu = drivers.length === 0 || drivers.every(d => soft.indexOf(d) >= 0);
                root.probed = true;
                if (root.lowEnd)
                    Hypr.setLowEnd(true);
            }
        }
    }
}
