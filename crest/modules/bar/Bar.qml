import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: win

    required property ShellScreen modelData

    screen: modelData
    color: "transparent"
    WlrLayershell.namespace: "crest-bar"
    WlrLayershell.layer: WlrLayer.Top
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 8 + content.implicitHeight + 28
    exclusiveZone: 8 + content.implicitHeight

    mask: Region {
        Region {
            item: content.leftIsland
            radius: 22
        }

        Region {
            item: content.centreIsland
            radius: 22
        }

        Region {
            item: content.mediaIsland.visible ? content.mediaIsland : null
            radius: 22
        }

        Region {
            item: content.rightIsland
            radius: 22
        }
    }

    BarContent {
        id: content

        window: win
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.leftMargin: 12
        anchors.rightMargin: 12
    }
}
