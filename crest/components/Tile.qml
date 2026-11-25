pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.theme

Item {
    id: root

    property string icon
    property string label
    property string sublabel
    property bool active: false
    property bool details: false
    readonly property color fg: active ? Colours.fgPrimary : Colours.fgSurface

    signal clicked
    signal secondaryClicked

    implicitWidth: 168
    implicitHeight: 68

    Rectangle {
        id: bg

        anchors.fill: parent
        color: root.active ? Colours.primary : Colours.alpha(Colours.surfaceContainerHighest, 0.85)
        radius: area.pressed ? Style.rMd : (root.active ? height / 2 : Style.rLgInc)

        Behavior on radius {
            SpringFast {}
        }

        Behavior on color {
            ColorEase {
                duration: Motion.durMedium
            }
        }

        StateLayer {
            id: area

            radius: bg.radius
            tint: root.fg
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => mouse.button === Qt.RightButton ? root.secondaryClicked() : root.clicked()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 16
            spacing: 12

            Icon {
                name: root.icon
                size: 24
                fill: root.active ? 1 : 0
                color: root.fg
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    Layout.fillWidth: true
                    text: root.label
                    role: "titleS"
                    color: root.fg
                }

                Txt {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.sublabel
                    role: "bodyS"
                    color: root.fg
                    opacity: 0.8
                }
            }

            Rectangle {
                visible: root.details
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: Colours.alpha(root.fg, detailArea.containsMouse ? 0.16 : 0.08)

                Icon {
                    anchors.centerIn: parent
                    name: "chevron_right"
                    size: 20
                    color: root.fg
                }

                MouseArea {
                    id: detailArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.secondaryClicked()
                }
            }
        }
    }
}
