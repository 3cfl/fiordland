import QtQuick
import qs.components
import qs.theme

Glass {
    id: root

    property int padding: 8
    default property alias items: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: 44
    radius: height / 2
    shadowBlur: 18
    shadowOffset: 4
    shadowStrength: 0.28

    Behavior on implicitWidth {
        SpringDefault {}
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        x: root.padding
        spacing: 4
    }
}
