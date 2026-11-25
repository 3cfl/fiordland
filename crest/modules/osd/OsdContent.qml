pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

Glass {
    id: root

    property string icon: "volume_up"
    property real value: 0.5
    property string label: ""

    implicitWidth: 340
    implicitHeight: 64
    radius: height / 2

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 22
        spacing: 14

        Item {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44

            ExprShape {
                anchors.fill: parent
                shape: root.value > 0.66 ? "sunny" : root.value > 0.33 ? "cookie9" : "circle"
                color: Colours.primary
            }

            Icon {
                anchors.centerIn: parent
                name: root.icon
                size: 22
                fill: 1
                color: Colours.fgPrimary
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 14

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Colours.secondaryContainer
            }

            Rectangle {
                id: bar

                height: parent.height
                width: Math.max(height, parent.width * Math.max(0, Math.min(1, root.value)))
                radius: height / 2
                color: Colours.primary

                Behavior on width {
                    SpringFast {}
                }
            }
        }

        Txt {
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
            text: root.label || Math.round(root.value * 100)
            role: "titleS"
            elide: Text.ElideNone
        }
    }
}
