pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool enabled: Config.nightLight.enabled
    readonly property int temperature: Math.max(2500, Math.min(6000, Config.nightLight.temperature))

    function toggle(): void {
        Config.nightLight.enabled = !Config.nightLight.enabled;
    }

    Process {
        running: root.enabled && !Config.demo && Config.loaded
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
}
