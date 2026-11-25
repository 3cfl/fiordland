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
    readonly property alias mediaIsland: media
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
        id: media

        anchors.right: centre.left
        anchors.rightMargin: 8
        visible: Config.bar.showMedia && Media.available && Media.title !== ""
        padding: 6
        spacing: 8

        Item {
            width: 32
            height: 32
            anchors.verticalCenter: parent.verticalCenter

            ExprShape {
                id: disc

                anchors.fill: parent
                shape: "cookie12"
                color: Colours.tertiaryContainer

                RotationAnimator on rotation {
                    running: Media.playing && media.visible && !Motion.reduced
                    from: 0
                    to: 360
                    duration: 9000
                    loops: Animation.Infinite
                }
            }

            Icon {
                anchors.centerIn: parent
                name: Media.playing ? "graphic_eq" : "music_note"
                size: 18
                fill: 1
                color: Colours.fgTertiaryContainer
            }
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 220)
            text: Media.artist ? `${Media.title} · ${Media.artist}` : Media.title
            role: "labelL"
            color: Colours.fgSurface
        }

        Item {
            width: 4
            height: 1
        }

        MouseArea {
            parent: media
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => mouse.button === Qt.MiddleButton ? Media.toggle() : Panels.toggle("quicksettings")
        }
    }

    Island {
        id: centre

        anchors.horizontalCenter: parent.horizontalCenter
        padding: 18
        spacing: 10

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, Config.bar.use24h ? (Config.bar.showSeconds ? "HH:mm:ss" : "HH:mm") : (Config.bar.showSeconds ? "h:mm:ss ap" : "h:mm ap"))
            role: "titleM"
            emphasis: true
            elide: Text.ElideNone
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: 4
            radius: 2
            color: Colours.primary
        }

        Txt {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            role: "bodyM"
            color: Colours.fgSurfaceVariant
            elide: Text.ElideNone
        }

        MouseArea {
            parent: centre
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: Panels.toggle("notifications")
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
                        size: 19
                        fill: 1
                        rotation: 90
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
                color: Panels.notifications ? Colours.secondaryContainer : "transparent"

                StateLayer {
                    radius: 16
                    onClicked: Panels.toggle("notifications")
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
