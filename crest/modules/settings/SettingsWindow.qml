pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.theme

FloatingWindow {
    id: win

    signal finished

    title: "crest settings"
    implicitWidth: 880
    implicitHeight: 620
    minimumSize: Qt.size(720, 520)
    color: Colours.surface
    visible: true

    onVisibleChanged: {
        if (!visible)
            finished();
    }

    SettingsContent {
        anchors.fill: parent
        onCloseRequested: win.visible = false
    }
}
