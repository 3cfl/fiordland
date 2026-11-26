pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme
import "../notifications"

ColumnLayout {
    id: root

    spacing: 16

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 14

        Avatar {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            source: Account.face
            initial: Account.displayName
            shape: "cookie9"

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.openSettings("account")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Txt {
                Layout.fillWidth: true
                text: `${Account.greeting}, ${Account.displayName.split(" ")[0].toLowerCase()}`
                role: "headlineS"
            }

            Txt {
                Layout.fillWidth: true
                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toLowerCase() + (Power.hasBattery ? `  ·  battery ${Math.round(Power.level * 100)}%` : "")
                role: "bodyM"
                color: Colours.fgSurfaceVariant
            }
        }

        IconButton {
            size: 40
            iconSize: 20
            icon: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
            checkable: true
            checked: Notifs.dnd
            onClicked: Notifs.dnd = !Notifs.dnd
        }

        IconButton {
            size: 40
            iconSize: 20
            icon: "clear_all"
            variant: "tonal"
            visible: Notifs.count > 0
            onClicked: Notifs.clear()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 4
        spacing: 12

        ColumnLayout {
            Layout.preferredWidth: 300
            Layout.maximumWidth: 300
            Layout.alignment: Qt.AlignTop
            spacing: 12

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cal.implicitHeight + 24
                radius: Style.rLgInc
                color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

                MonthGrid {
                    id: cal

                    x: 12
                    y: 12
                    width: parent.width - 24
                    date: clock.date
                }
            }

            Rectangle {
                id: np

                Layout.fillWidth: true
                implicitHeight: 72
                visible: Media.available
                radius: Style.rLgInc
                color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

                ClippingRectangle {
                    id: npArt

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48
                    height: 48
                    radius: Style.rMd
                    color: Colours.tertiaryContainer

                    Icon {
                        anchors.centerIn: parent
                        visible: npImg.status !== Image.Ready
                        name: "music_note"
                        size: 22
                        fill: 1
                        color: Colours.fgTertiaryContainer
                    }

                    Image {
                        id: npImg

                        anchors.fill: parent
                        source: Media.art
                        sourceSize.width: 96
                        sourceSize.height: 96
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                StateLayer {
                    radius: np.radius
                    onClicked: Panels.dashboardTab = "media"
                }

                ColumnLayout {
                    anchors.left: npArt.right
                    anchors.leftMargin: 12
                    anchors.right: npPlay.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Txt {
                        Layout.fillWidth: true
                        text: Media.title || "unknown track"
                        role: "titleS"
                    }

                    Txt {
                        Layout.fillWidth: true
                        text: Media.artist || Media.identity.toLowerCase()
                        role: "bodyS"
                        color: Colours.fgSurfaceVariant
                    }
                }

                IconButton {
                    id: npPlay

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    variant: "filled"
                    icon: Media.playing ? "pause" : "play_arrow"
                    onClicked: Media.toggle()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 420
            radius: Style.rLgInc
            color: Colours.alpha(Colours.surfaceContainerHighest, 0.5)

            RowLayout {
                id: head

                x: 18
                y: 14
                width: parent.width - 36
                height: 28

                Txt {
                    Layout.fillWidth: true
                    text: "notifications"
                    role: "titleM"
                }

                Rectangle {
                    visible: Notifs.count > 0
                    implicitWidth: countTxt.implicitWidth + 16
                    implicitHeight: 22
                    radius: 11
                    color: Colours.primaryContainer

                    Txt {
                        id: countTxt

                        anchors.centerIn: parent
                        text: Notifs.count
                        role: "labelM"
                        color: Colours.fgPrimaryContainer
                        elide: Text.ElideNone
                    }
                }
            }

            Flickable {
                id: flick

                x: 8
                y: head.y + head.height + 10
                width: parent.width - 16
                height: parent.height - y - 8
                visible: Notifs.count > 0
                contentHeight: list.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: list

                    width: flick.width
                    spacing: 6

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
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 14
                visible: Notifs.count === 0
                spacing: 10

                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 84

                    ExprShape {
                        anchors.fill: parent
                        shape: "puffy"
                        color: Colours.secondaryContainer
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: Notifs.dnd ? "notifications_off" : "notifications"
                        size: 34
                        fill: 1
                        color: Colours.fgSecondaryContainer
                    }
                }

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: "all caught up"
                    role: "titleM"
                }

                Txt {
                    Layout.alignment: Qt.AlignHCenter
                    text: Notifs.dnd ? "do not disturb is on" : "new notifications will show up here"
                    role: "bodyM"
                    color: Colours.fgSurfaceVariant
                }
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
                    Layout.preferredWidth: 1
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
                    Layout.preferredWidth: 1
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
