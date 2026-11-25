pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

Rectangle {
    id: root

    property string page: Panels.settingsPage
    readonly property var pages: [
        { id: "appearance", icon: "palette", label: "look" },
        { id: "bar", icon: "toolbar", label: "bar" },
        { id: "performance", icon: "speed", label: "speed" },
        { id: "wallpaper", icon: "wallpaper", label: "wallpaper" },
        { id: "about", icon: "info", label: "about" }
    ]

    signal closeRequested

    color: Colours.surface
    focus: true
    Keys.onEscapePressed: closeRequested()

    RowLayout {
        anchors.fill: parent
        spacing: 0

        ColumnLayout {
            Layout.preferredWidth: 96
            Layout.fillHeight: true
            Layout.topMargin: 28
            spacing: 12

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                Layout.bottomMargin: 16

                ExprShape {
                    anchors.fill: parent
                    shape: "sunny"
                    color: Colours.primaryContainer
                }

                Icon {
                    anchors.centerIn: parent
                    name: "landscape"
                    fill: 1
                    size: 24
                    color: Colours.fgPrimaryContainer
                }
            }

            Repeater {
                model: root.pages

                Item {
                    id: nav

                    required property var modelData
                    readonly property bool selected: root.page === modelData.id

                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 60

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2
                        width: nav.selected ? 56 : 32
                        height: 32
                        radius: 16
                        color: nav.selected ? Colours.secondaryContainer : "transparent"

                        Behavior on width {
                            SpringFast {}
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: nav.modelData.icon
                            size: 22
                            fill: nav.selected ? 1 : 0
                            color: nav.selected ? Colours.fgSecondaryContainer : Colours.fgSurfaceVariant
                        }
                    }

                    Txt {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 38
                        text: nav.modelData.label
                        role: "labelM"
                        color: nav.selected ? Colours.fgSurface : Colours.fgSurfaceVariant
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.page = nav.modelData.id
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 12
            Layout.bottomMargin: 12
            Layout.rightMargin: 12
            radius: Style.rXl
            color: Colours.surfaceContainerLow

            Flickable {
                anchors.fill: parent
                anchors.margins: 28
                contentHeight: pageCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: pageCol

                    width: parent.width
                    spacing: 8

                    Txt {
                        Layout.bottomMargin: 12
                        text: ({ appearance: "look and feel", bar: "the bar", performance: "speed", wallpaper: "wallpaper", about: "about crest" })[root.page] ?? ""
                        role: "headlineM"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "appearance"
                        spacing: 8

                        SettingRow {
                            title: "theme"
                            subtitle: "dark is easier on the eyes at night"

                            Segmented {
                                options: [{ id: "dark", icon: "dark_mode", label: "dark" }, { id: "light", icon: "light_mode", label: "light" }]
                                current: Config.appearance.mode === "light" ? "light" : "dark"
                                onPicked: id => Config.appearance.mode = id
                            }
                        }

                        SettingRow {
                            title: "colours from wallpaper"
                            subtitle: "off uses the fiordland blues"

                            Switch {
                                checked: Config.appearance.scheme === "wallpaper"
                                onToggled: on => Config.appearance.scheme = on ? "wallpaper" : "fiordland"
                            }
                        }

                        SettingRow {
                            title: "colour style"
                            subtitle: "how strongly the wallpaper tints the shell"
                            enabled: Config.appearance.scheme === "wallpaper"

                            Segmented {
                                size: 36
                                options: [{ id: "scheme-tonal-spot", label: "calm" }, { id: "scheme-expressive", label: "expressive" }, { id: "scheme-vibrant", label: "vibrant" }]
                                current: Config.appearance.variant
                                onPicked: id => Config.appearance.variant = id
                            }
                        }

                        SettingRow {
                            title: "transparency"
                            subtitle: "glass panels with blur behind them"

                            Switch {
                                checked: Config.appearance.transparency
                                onToggled: on => Config.appearance.transparency = on
                            }
                        }

                        SettingRow {
                            title: "night light"
                            subtitle: NightLight.enabled ? `${NightLight.temperature} K` : "warmer colours in the evening"

                            Switch {
                                checked: NightLight.enabled
                                onToggled: NightLight.toggle()
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "bar"
                        spacing: 8

                        SettingRow {
                            title: "workspaces shown"

                            Segmented {
                                size: 36
                                options: [{ id: "4", label: "4" }, { id: "5", label: "5" }, { id: "7", label: "7" }, { id: "10", label: "10" }]
                                current: String(Config.bar.workspaces)
                                onPicked: id => Config.bar.workspaces = parseInt(id)
                            }
                        }

                        SettingRow {
                            title: "24 hour clock"

                            Switch {
                                checked: Config.bar.use24h
                                onToggled: on => Config.bar.use24h = on
                            }
                        }

                        SettingRow {
                            title: "show seconds"

                            Switch {
                                checked: Config.bar.showSeconds
                                onToggled: on => Config.bar.showSeconds = on
                            }
                        }

                        SettingRow {
                            title: "battery percentage"

                            Switch {
                                checked: Config.bar.batteryPercent
                                onToggled: on => Config.bar.batteryPercent = on
                            }
                        }

                        SettingRow {
                            title: "now playing"
                            subtitle: "song title next to the clock"

                            Switch {
                                checked: Config.bar.showMedia
                                onToggled: on => Config.bar.showMedia = on
                            }
                        }

                        SettingRow {
                            title: "tray icons"

                            Switch {
                                checked: Config.bar.showTray
                                onToggled: on => Config.bar.showTray = on
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "performance"
                        spacing: 8

                        SettingRow {
                            title: "low-end mode"
                            subtitle: "turns off blur, shadows and most motion"

                            Segmented {
                                size: 36
                                options: [{ id: "auto", label: "auto" }, { id: "on", label: "on" }, { id: "off", label: "off" }]
                                current: Config.performance.lowEnd
                                onPicked: id => Config.performance.lowEnd = id
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            radius: Style.rLg
                            color: Perf.lowEnd ? Colours.tertiaryContainer : Colours.surfaceContainerHigh

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 20
                                anchors.rightMargin: 20
                                spacing: 16

                                Icon {
                                    name: Perf.lowEnd ? "eco" : "bolt"
                                    size: 28
                                    fill: 1
                                    color: Perf.lowEnd ? Colours.fgTertiaryContainer : Colours.primary
                                }

                                Txt {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    text: Perf.lowEnd ? (Perf.mode === "auto" ? `low-end mode is on because of ${Perf.reason}` : "low-end mode is on") : "full effects are on"
                                    role: "bodyL"
                                    color: Perf.lowEnd ? Colours.fgTertiaryContainer : Colours.fgSurface
                                }
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            wrapMode: Text.Wrap
                            text: `memory ${Perf.memoryMb > 0 ? (Perf.memoryMb / 1024).toFixed(1) + " GB" : "unknown"} · graphics ${Perf.softwareGpu ? "software" : "hardware"}`
                            role: "bodyM"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "wallpaper"
                        spacing: 16

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width * 9 / 16
                            Layout.maximumHeight: 320
                            radius: Style.rXl
                            color: Colours.surfaceContainerHighest
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: Wallpapers.current
                                sourceSize.width: 720
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        RowLayout {
                            spacing: 8

                            PillButton {
                                icon: "photo_library"
                                text: "pick a wallpaper"
                                onClicked: {
                                    root.closeRequested();
                                    Panels.show("wallpaper");
                                }
                            }

                            PillButton {
                                variant: "tonal"
                                icon: "restart_alt"
                                text: "use the default"
                                onClicked: Wallpapers.set(Wallpapers.fallback)
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: "crest looks in ~/Pictures/Wallpapers, ~/Pictures and /usr/share/backgrounds."
                            role: "bodyM"
                            color: Colours.fgSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.page === "about"
                        spacing: 12

                        RowLayout {
                            spacing: 20

                            Item {
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 88

                                ExprShape {
                                    anchors.fill: parent
                                    shape: "cookie9"
                                    color: Colours.primary
                                }

                                Icon {
                                    anchors.centerIn: parent
                                    name: "landscape"
                                    size: 44
                                    fill: 1
                                    color: Colours.fgPrimary
                                }
                            }

                            ColumnLayout {
                                spacing: 2

                                Txt {
                                    text: "crest 1"
                                    role: "headlineS"
                                }

                                Txt {
                                    text: "the fiordland desktop shell"
                                    role: "bodyL"
                                    color: Colours.fgSurfaceVariant
                                }
                            }
                        }

                        Txt {
                            Layout.fillWidth: true
                            Layout.topMargin: 8
                            wrapMode: Text.Wrap
                            text: "Built on Quickshell. Inspired by Caelestia, end-4 and illogical-impulse. Free software under the GPL-3.0."
                            role: "bodyL"
                        }
                    }
                }
            }
        }
    }

    component SettingRow: Rectangle {
        id: row

        property string title
        property string subtitle
        default property alias trailing: slot.data

        Layout.fillWidth: true
        implicitHeight: Math.max(68, slot.childrenRect.height + 24)
        radius: Style.rLg
        color: Colours.surfaceContainerHigh
        opacity: enabled ? 1 : 0.5

        ColumnLayout {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Txt {
                Layout.fillWidth: true
                text: row.title
                role: "titleM"
            }

            Txt {
                Layout.fillWidth: true
                visible: text !== ""
                text: row.subtitle
                role: "bodyM"
                color: Colours.fgSurfaceVariant
            }
        }

        Item {
            id: slot

            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
