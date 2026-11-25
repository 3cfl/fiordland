import QtQuick
import qs.theme

MouseArea {
    id: root

    property color tint: Colours.onSurface
    property real radius: 0
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomLeftRadius: radius
    property real bottomRightRadius: radius

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.tint
        opacity: root.pressed ? 0.12 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            Ease {
                duration: Motion.durShort
            }
        }
    }
}
