import QtQuick
import Caelestia.Config
import qs.services

Item {
    id: root

    property string icon: "landscape"
    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3onSurface

    implicitWidth: 32
    implicitHeight: 32

    MaterialIcon {
        anchors.centerIn: parent
        text: root.icon
        color: root.topColour
        fill: 1
        fontStyle: Tokens.font.icon.size(Math.max(1, Math.min(root.width, root.height) * 0.62)).build()
    }
}
