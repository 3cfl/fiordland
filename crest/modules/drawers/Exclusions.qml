pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    StyledWindow {
        screen: root.screen
        name: "border-exclusion"
        anchors.top: true
        exclusiveZone: root.bar.exclusiveZone
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}
