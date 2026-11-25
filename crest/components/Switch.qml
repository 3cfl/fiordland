pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

Item {
    id: root

    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 52
    implicitHeight: 32
    opacity: enabled ? 1 : 0.38

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Colours.primary : Colours.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Colours.outline

        Behavior on color {
            ColorEase {}
        }
    }

    Rectangle {
        id: thumb

        readonly property real d: area.pressed ? 28 : (root.checked ? 24 : 16)

        width: d
        height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - 4 - d : 4 + (24 - d) / 2
        color: root.checked ? Colours.fgPrimary : Colours.outline

        Behavior on x {
            SpringFast {}
        }

        Behavior on d {
            SpringFast {}
        }

        Behavior on color {
            ColorEase {}
        }

        Icon {
            anchors.centerIn: parent
            name: "check"
            size: 16
            opacity: root.checked ? 1 : 0
            color: Colours.fgPrimaryContainer
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
