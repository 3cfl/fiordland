pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

Item {
    id: root

    property var window: null
    readonly property alias leftIsland: left
    readonly property alias centreIsland: centre
    readonly property alias rightIsland: right

    implicitHeight: 44

    SystemClock {
        id: clock

        precision: Config.bar.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    Island {
        id: left

        anchors.left: parent.left
        padding: 6
        spacing: 10

        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            ExprShape {
                id: logo

                anchors.fill: parent
                shape: logoArea.containsMouse || Panels.launcher ? "sunny" : "cookie9"
                color: Colours.primary
                rotation: logoArea.containsMouse ? 30 : 0

                Behavior on rotation {
                    SpringFast {}
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "landscape"
                size: 18
                fill: 1
                color: Colours.fgPrimary
            }

            MouseArea {
                id: logoArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("launcher")
            }
        }

        Workspaces {
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            width: 2
            height: 1
        }
    }

    Island {
        id: centre

        anchors.horizontalCenter: parent.horizontalCenter
        padding: 6
        spacing: 2

        property bool held: false
        readonly property bool want: Config.bar.showStats

        function sync(): void {
            if (want && !held)
                SysStats.acquire();
            else if (!want && held)
                SysStats.release();
            held = want;
        }

        onWantChanged: sync()
        Component.onCompleted: sync()
        Component.onDestruction: if (held)
            SysStats.release()

        Segment {
            id: mediaSeg

            visible: Config.bar.showMedia && Media.available && Media.title !== ""
            active: Panels.dashboard && Panels.dashboardTab === "media"
            leftPad: 4
            onClicked: mouse => mouse.button === Qt.MiddleButton ? Media.toggle() : Panels.openDashboard("media")

            Item {
                width: 28
                height: 28
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: Colours.tertiaryContainer
                    visible: coverImg.status !== Image.Ready
                }

                Icon {
                    anchors.centerIn: parent
                    visible: coverImg.status !== Image.Ready
                    name: "music_note"
                    size: 16
                    fill: 1
                    color: Colours.fgTertiaryContainer
                }

                ClippingRectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    visible: coverImg.status === Image.Ready

                    Image {
                        id: coverImg

                        anchors.fill: parent
                        source: Media.art
                        sourceSize.width: 64
                        sourceSize.height: 64
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 200)
                text: Media.title
                role: "labelL"
                color: Colours.fgSurface
            }

            Bars {
                anchors.verticalCenter: parent.verticalCenter
                playing: Media.playing
            }
        }

        Divider {
            visible: mediaSeg.visible
        }

        Segment {
            active: Panels.dashboard && Panels.dashboardTab === "home"
            leftPad: 12
            rightPad: 12
            onClicked: Panels.openDashboard("home")

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, Config.bar.use24h ? (Config.bar.showSeconds ? "HH:mm:ss" : "HH:mm") : (Config.bar.showSeconds ? "h:mm:ss ap" : "h:mm ap"))
                role: "titleM"
                emphasis: true
                elide: Text.ElideNone
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, "ddd d MMM").toLowerCase()
                role: "bodyM"
                color: Colours.fgSurfaceVariant
                elide: Text.ElideNone
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.count > 0 && !Notifs.dnd
                width: 7
                height: 7
                radius: 3.5
                color: Colours.tertiary
            }
        }

        Divider {
            visible: statsSeg.visible
        }

        Segment {
            id: statsSeg

            visible: Config.bar.showStats
            active: Panels.dashboard && Panels.dashboardTab === "system"
            leftPad: 6
            rightPad: 6
            spacing: 4
            onClicked: Panels.openDashboard("system")

            Repeater {
                model: [
                    { label: "cpu", v: () => SysStats.cpu, c: Colours.primary },
                    { label: "ram", v: () => SysStats.memory, c: Colours.tertiary }
                ]

                Item {
                    id: stat

                    required property var modelData

                    width: 30
                    height: 30
                    anchors.verticalCenter: parent.verticalCenter

                    WavyRing {
                        anchors.fill: parent
                        value: stat.modelData.v()
                        color: stat.modelData.c
                        trackColor: Colours.alpha(stat.modelData.c, 0.18)
                        thickness: 3
                        amplitude: 0.8
                        waves: 8
                        animating: false
                    }

                    Txt {
                        anchors.centerIn: parent
                        text: Math.round(stat.modelData.v() * 100)
                        role: "labelS"
                        font.pixelSize: 10
                        emphasis: true
                        color: Colours.fgSurface
                        elide: Text.ElideNone
                    }
                }
            }
        }

        Divider {
            visible: Capture.recording
        }

        Segment {
            visible: Capture.recording
            leftPad: 10
            rightPad: 10
            onClicked: Capture.stop()

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                radius: 5
                color: Colours.error

                SequentialAnimation on opacity {
                    running: Capture.recording && !Motion.reduced
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.3
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 700
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Txt {
                anchors.verticalCenter: parent.verticalCenter
                text: Media.fmt(Capture.elapsed)
                role: "labelL"
                emphasis: true
                color: Colours.error
                elide: Text.ElideNone
            }
        }
    }

    component Divider: Rectangle {
        anchors.verticalCenter: parent?.verticalCenter
        width: 1
        height: 18
        color: Colours.alpha(Colours.outlineVariant, 0.8)
    }

    component Segment: Item {
        id: seg

        property bool active: false
        property int leftPad: 10
        property int rightPad: 10
        property alias spacing: segRow.spacing
        default property alias items: segRow.data

        signal clicked(var mouse)

        anchors.verticalCenter: parent?.verticalCenter
        width: segRow.implicitWidth + leftPad + rightPad
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: seg.active ? Colours.secondaryContainer : "transparent"

            Behavior on color {
                ColorEase {}
            }
        }

        StateLayer {
            radius: 16
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => seg.clicked(mouse)
        }

        Row {
            id: segRow

            x: seg.leftPad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component Bars: Row {
        id: bars

        property bool playing: false

        spacing: 2
        height: 14

        Repeater {
            model: 3

            Rectangle {
                id: bar

                required property int index
                property real level: 0.4

                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                height: 4 + level * 10
                color: Colours.primary

                SequentialAnimation on level {
                    running: bars.playing && bars.visible && !Motion.reduced
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 1
                        duration: 380 + bar.index * 110
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 0.15
                        duration: 420 + bar.index * 90
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    Island {
        id: right

        anchors.right: parent.right
        padding: 6
        spacing: 4

        Row {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.bar.showTray && tray.count > 0
            spacing: 2

            Repeater {
                id: tray

                model: Config.demo ? [] : SystemTray.items

                Item {
                    id: trayItem

                    required property SystemTrayItem modelData

                    width: 30
                    height: 30

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 18
                        source: trayItem.modelData.icon
                        asynchronous: true
                    }

                    StateLayer {
                        radius: 15
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            const item = trayItem.modelData;
                            if (mouse.button === Qt.MiddleButton)
                                item.secondaryActivate();
                            else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu && root.window) {
                                    const p = trayItem.mapToItem(null, 0, trayItem.height + 8);
                                    item.display(root.window, p.x, p.y);
                                }
                            } else
                                item.activate();
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.bar.showTray && tray.count > 0
            width: 1
            height: 18
            color: Colours.outlineVariant
        }

        Rectangle {
            id: status

            anchors.verticalCenter: parent.verticalCenter
            width: statusRow.implicitWidth + 20
            height: 32
            radius: 16
            color: Panels.quicksettings ? Colours.secondaryContainer : "transparent"

            Behavior on color {
                ColorEase {}
            }

            StateLayer {
                radius: 16
                onClicked: Panels.toggle("quicksettings")
                onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
            }

            Row {
                id: statusRow

                anchors.centerIn: parent
                spacing: 10

                Icon {
                    name: Net.icon
                    size: 19
                    fill: 1
                    color: Colours.fgSurface
                }

                Icon {
                    visible: Bt.enabled
                    name: Bt.connected.length > 0 ? "bluetooth_connected" : "bluetooth"
                    size: 19
                    color: Colours.fgSurface
                }

                Icon {
                    name: Audio.icon
                    size: 19
                    fill: 1
                    color: Colours.fgSurface
                }

                Row {
                    visible: Power.hasBattery
                    spacing: 3

                    Icon {
                        name: Power.icon
                        size: 20
                        fill: 1
                        color: Power.level < 0.15 && !Power.charging ? Colours.error : Colours.fgSurface
                    }

                    Txt {
                        visible: Config.bar.batteryPercent
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Power.level * 100) + "%"
                        role: "labelM"
                        elide: Text.ElideNone
                    }
                }
            }
        }

        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: Panels.dashboard && Panels.dashboardTab === "home" ? Colours.secondaryContainer : "transparent"

                StateLayer {
                    radius: 16
                    onClicked: Panels.openDashboard("home")
                }
            }

            Icon {
                anchors.centerIn: parent
                name: Notifs.dnd ? "notifications_off" : (Notifs.count > 0 ? "notifications_unread" : "notifications")
                size: 19
                fill: Notifs.count > 0 ? 1 : 0
                color: Colours.fgSurface
            }

            Rectangle {
                visible: Notifs.count > 0 && !Notifs.dnd
                x: 18
                y: 4
                width: Math.max(14, badge.implicitWidth + 6)
                height: 14
                radius: 7
                color: Colours.tertiary

                Txt {
                    id: badge

                    anchors.centerIn: parent
                    text: Notifs.count > 9 ? "9+" : Notifs.count
                    role: "labelS"
                    font.pixelSize: 9
                    color: Colours.fgTertiary
                    elide: Text.ElideNone
                }
            }
        }

        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: 32
            icon: "power_settings_new"
            iconSize: 18
            onClicked: Panels.toggle("session")
        }
    }
}
