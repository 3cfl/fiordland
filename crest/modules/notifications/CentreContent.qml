pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services
import qs.theme

Glass {
    id: root

    implicitWidth: 440
    implicitHeight: column.implicitHeight + 32
    radius: Style.rXl

    Behavior on implicitHeight {
        SpringDefault {}
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        id: column

        x: 16
        y: 16
        width: parent.width - 32
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Txt {
                    text: Qt.formatDateTime(clock.date, "dddd").toLowerCase()
                    role: "labelL"
                    color: Colours.primary
                }

                Txt {
                    text: Qt.formatDateTime(clock.date, "d MMMM").toLowerCase()
                    role: "headlineM"
                }
            }

            Item {
                Layout.preferredWidth: 56
                Layout.preferredHeight: 56

                ExprShape {
                    anchors.fill: parent
                    shape: "sunny"
                    color: Colours.tertiaryContainer
                }

                Txt {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "d")
                    role: "titleL"
                    color: Colours.fgTertiaryContainer
                }
            }
        }

        MonthGrid {
            Layout.fillWidth: true
            date: clock.date
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colours.outlineVariant
            opacity: 0.6
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            spacing: 8

            Txt {
                Layout.fillWidth: true
                text: Notifs.count > 0 ? `notifications · ${Notifs.count}` : "notifications"
                role: "titleM"
            }

            Icon {
                name: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                size: 20
                color: Colours.fgSurfaceVariant
            }

            Switch {
                checked: Notifs.dnd
                onToggled: on => Notifs.dnd = on
            }

            PillButton {
                visible: Notifs.count > 0
                size: 36
                variant: "tonal"
                icon: "clear_all"
                text: "clear"
                onClicked: Notifs.clear()
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(list.implicitHeight, 460)
            visible: Notifs.count > 0
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: parent.width
                spacing: 8

                Repeater {
                    model: Notifs.list

                    NotifCard {
                        required property var modelData

                        width: list.width
                        entry: modelData
                        glass: false
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.bottomMargin: 12
            visible: Notifs.count === 0
            spacing: 10

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72

                ExprShape {
                    anchors.fill: parent
                    shape: "puffy"
                    color: Colours.secondaryContainer
                }

                Icon {
                    anchors.centerIn: parent
                    name: "notifications_paused"
                    size: 32
                    color: Colours.fgSecondaryContainer
                }
            }

            Txt {
                Layout.alignment: Qt.AlignHCenter
                text: "you're all caught up"
                role: "bodyL"
                color: Colours.fgSurfaceVariant
            }
        }
    }

    component MonthGrid: ColumnLayout {
        id: grid

        property date date
        property int offset: 0
        readonly property date shown: new Date(date.getFullYear(), date.getMonth() + offset, 1)
        readonly property int lead: (shown.getDay() + 6) % 7
        readonly property int days: new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate()

        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 8

            Txt {
                Layout.fillWidth: true
                text: Qt.formatDate(grid.shown, "MMMM yyyy").toLowerCase()
                role: "titleS"
            }

            IconButton {
                size: 32
                icon: "chevron_left"
                onClicked: grid.offset--
            }

            IconButton {
                size: 32
                icon: "chevron_right"
                onClicked: grid.offset++
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 2
            columnSpacing: 2

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]

                Txt {
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    role: "labelM"
                    color: Colours.fgSurfaceVariant
                }
            }

            Repeater {
                model: 42

                Item {
                    id: day

                    required property int index
                    readonly property int number: index - grid.lead + 1
                    readonly property bool inMonth: number >= 1 && number <= grid.days
                    readonly property bool today: inMonth && grid.offset === 0 && number === grid.date.getDate()

                    visible: index < 35 || grid.lead + grid.days > 35
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    ExprShape {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        visible: day.today
                        shape: "cookie9"
                        color: Colours.primary
                    }

                    Txt {
                        anchors.centerIn: parent
                        visible: day.inMonth
                        text: day.number
                        role: day.today ? "labelL" : "bodyM"
                        color: day.today ? Colours.fgPrimary : Colours.fgSurface
                    }
                }
            }
        }
    }
}
