pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    property int current: 0
    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property var actions: [
        { id: "lock", icon: "lock", label: "lock", shape: "cookie9" },
        { id: "suspend", icon: "bedtime", label: "sleep", shape: "clover4" },
        { id: "logout", icon: "logout", label: "log out", shape: "puffy" },
        { id: "reboot", icon: "restart_alt", label: "restart", shape: "softburst" },
        { id: "poweroff", icon: "power_settings_new", label: "shut down", shape: "sunny" }
    ]

    signal done

    focus: true
    Keys.onLeftPressed: current = (current + actions.length - 1) % actions.length
    Keys.onRightPressed: current = (current + 1) % actions.length
    Keys.onTabPressed: current = (current + 1) % actions.length
    Keys.onReturnPressed: run(actions[current].id)
    Keys.onEnterPressed: run(actions[current].id)
    Keys.onEscapePressed: done()

    function run(id: string): void {
        done();
        Session.run(id);
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.done()
    }

    Glass {
        anchors.centerIn: parent
        implicitWidth: column.implicitWidth + 64
        implicitHeight: column.implicitHeight + 56
        width: implicitWidth
        height: implicitHeight
        radius: Style.rXxl

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: column

            anchors.centerIn: parent
            spacing: 28

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.user ? `see you soon, ${root.user}` : "see you soon"
                    role: "headlineS"
                }

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: Session.uptime ? `up for ${Session.uptime}` : ""
                    visible: text !== ""
                    role: "bodyM"
                    color: Colours.fgSurfaceVariant
                }
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Repeater {
                    model: root.actions

                    Item {
                        id: btn

                        required property var modelData
                        required property int index
                        readonly property bool selected: root.current === index

                        width: 104
                        height: 136

                        Item {
                            id: face

                            width: 104
                            height: 104
                            scale: area.pressed ? 0.92 : (btn.selected ? 1.04 : 1)

                            Behavior on scale {
                                SpringFast {}
                            }

                            ExprShape {
                                anchors.fill: parent
                                shape: btn.selected ? btn.modelData.shape : "circle"
                                color: btn.selected ? (btn.modelData.id === "poweroff" ? Colours.error : Colours.primary) : Colours.alpha(Colours.surfaceContainerHighest, 0.9)
                                rotation: btn.selected ? 18 : 0

                                Behavior on rotation {
                                    SpringDefault {}
                                }
                            }

                            Icon {
                                anchors.centerIn: parent
                                name: btn.modelData.icon
                                size: 36
                                fill: btn.selected ? 1 : 0
                                color: btn.selected ? (btn.modelData.id === "poweroff" ? Colours.fgError : Colours.fgPrimary) : Colours.fgSurface
                            }

                            MouseArea {
                                id: area

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.current = btn.index
                                onClicked: root.run(btn.modelData.id)
                            }
                        }

                        Txt {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: btn.modelData.label
                            role: "labelL"
                            color: btn.selected ? Colours.fgSurface : Colours.fgSurfaceVariant
                        }
                    }
                }
            }
        }
    }
}
