//@ pragma Env QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

ShellRoot {
    settings.watchFiles: false

    Component.onCompleted: Perf.apply()

    FloatingWindow {
        title: "crest-greeter"
        color: "black"
        visible: true
        implicitWidth: 1280
        implicitHeight: 800

        GreeterContent {
            anchors.fill: parent
        }
    }
}
